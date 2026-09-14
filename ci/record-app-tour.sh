#!/bin/bash
#
# Genera una grabación de video automatizada en alta resolución recorriendo
# todas las pantallas, componentes y flujos de CasiListo en el simulador de iOS.
#
# Uso:
#   ci/record-app-tour.sh                              # Grabación por defecto (iPhone 17 Pro, modo claro)
#   ci/record-app-tour.sh --appearance dark            # En modo oscuro
#   ci/record-app-tour.sh --device "iPhone 17 Pro Max" # En otro dispositivo
#   ci/record-app-tour.sh --out ~/Desktop/demo.mp4     # Ruta de salida personalizada
#   ci/record-app-tour.sh --open                       # Abre el video en QuickTime al finalizar
#   ci/record-app-tour.sh --skip-build                 # Reutiliza el binario ya compilado
#

set -uo pipefail

readonly SCHEME="CasiListo"
readonly TEST_TARGET="CasiListoUITests/VideoTourTests/testRecordFullTour"
readonly PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

OUTPUT_FILE=""
DEVICE="iPhone 17 Pro"
APPEARANCE="light"
CODEC="h264"
OPEN_WHEN_DONE=0
SKIP_BUILD=0

usage() {
    sed -n '2,14p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --out)         OUTPUT_FILE="$2"; shift 2 ;;
        --device)      DEVICE="$2"; shift 2 ;;
        --appearance)  APPEARANCE="$2"; shift 2 ;;
        --codec)       CODEC="$2"; shift 2 ;;
        --skip-build)  SKIP_BUILD=1; shift ;;
        --open)        OPEN_WHEN_DONE=1; shift ;;
        -h|--help)     usage 0 ;;
        *) echo "Opción desconocida: $1" >&2; usage 1 ;;
    esac
done

if [[ -z "$OUTPUT_FILE" ]]; then
    mkdir -p "$PROJECT_ROOT/build/videos"
    TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
    OUTPUT_FILE="$PROJECT_ROOT/build/videos/casilisto-tour-${APPEARANCE}-${TIMESTAMP}.mp4"
else
    mkdir -p "$(dirname "$OUTPUT_FILE")"
fi

if ! xcrun --find simctl > /dev/null 2>&1; then
    echo "error: no se encontró simctl. Configura Xcode mediante xcode-select." >&2
    exit 1
fi

echo "============================================================"
echo "   CasiListo · Grabación Automatizada de Video Tour"
echo "============================================================"
echo "Dispositivo:  $DEVICE"
echo "Apariencia:   $APPEARANCE"
echo "Códec:        $CODEC"
echo "Salida:       $OUTPUT_FILE"
echo "============================================================"

# 1. Buscar y arrancar el simulador
echo "▶ Preparando simulador..."
UDID="$(xcrun simctl list devices available | grep -F "$DEVICE (" | head -n 1 | grep -oE '[0-9A-F-]{36}')"

if [[ -z "$UDID" ]]; then
    echo "error: no se encontró ningún simulador disponible con el nombre '$DEVICE'." >&2
    exit 1
fi

xcrun simctl boot "$UDID" > /dev/null 2>&1 || true
xcrun simctl bootstatus "$UDID" -b > /dev/null 2>&1

# 2. Configuración estética del simulador (Barra de estado impecable para video)
echo "▶ Configurando barra de estado y apariencia ($APPEARANCE)..."
xcrun simctl ui "$UDID" appearance "$APPEARANCE" > /dev/null 2>&1 || true
xcrun simctl status_bar "$UDID" override \
    --time "9:41" \
    --batteryState charged \
    --batteryLevel 100 \
    --cellularBars 4 \
    --wifiBars 3 > /dev/null 2>&1 || true

cleanup() {
    echo "▶ Limpiando estado del simulador..."
    xcrun simctl status_bar "$UDID" clear > /dev/null 2>&1 || true
    if [[ -n "${RECORD_PID:-}" ]] && kill -0 "$RECORD_PID" 2>/dev/null; then
        kill -INT "$RECORD_PID" 2>/dev/null || true
        wait "$RECORD_PID" 2>/dev/null || true
    fi
}
trap cleanup EXIT INT TERM

# 3. Compilación si es necesaria
BUILD_PRODUCTS_DIR=""
BUILD_DIR_LOOKUP="$(xcodebuild -project "$PROJECT_ROOT/CasiListo.xcodeproj" -scheme "$SCHEME" -destination "id=$UDID" -showBuildSettings 2>/dev/null | grep -E "^\s*BUILT_PRODUCTS_DIR =" | head -n 1 | awk '{print $3}')"

if [[ -n "$BUILD_DIR_LOOKUP" && -d "$BUILD_DIR_LOOKUP" ]]; then
    BUILD_PRODUCTS_DIR="$BUILD_DIR_LOOKUP"
fi

if [[ $SKIP_BUILD -eq 0 || -z "$BUILD_PRODUCTS_DIR" ]]; then
    echo "▶ Compilando app y tests (build-for-testing)..."
    xcodebuild build-for-testing \
        -project "$PROJECT_ROOT/CasiListo.xcodeproj" \
        -scheme "$SCHEME" \
        -destination "id=$UDID" \
        CODE_SIGN_IDENTITY="-" \
        CODE_SIGNING_REQUIRED=YES \
        -quiet

    BUILD_PRODUCTS_DIR="$(xcodebuild -project "$PROJECT_ROOT/CasiListo.xcodeproj" -scheme "$SCHEME" -destination "id=$UDID" -showBuildSettings 2>/dev/null | grep -E "^\s*BUILT_PRODUCTS_DIR =" | head -n 1 | awk '{print $3}')"
fi

# 4. Firma ad-hoc preventiva de dylibs (evita aborto por Team ID en iOS 27)
echo "▶ Verificando firmas ad-hoc para el simulador..."
if [[ -n "$BUILD_PRODUCTS_DIR" && -d "$BUILD_PRODUCTS_DIR" ]]; then
    find "$BUILD_PRODUCTS_DIR" -name "*.dylib" -exec codesign --force --sign - {} + 2>/dev/null || true
    if [[ -d "$BUILD_PRODUCTS_DIR/CasiListo.app" ]]; then
        codesign --force --deep --sign - "$BUILD_PRODUCTS_DIR/CasiListo.app" 2>/dev/null || true
    fi
    if [[ -d "$BUILD_PRODUCTS_DIR/CasiListoUITests-Runner.app" ]]; then
        codesign --force --deep --sign - "$BUILD_PRODUCTS_DIR/CasiListoUITests-Runner.app" 2>/dev/null || true
    fi
fi

# 5. Localizar archivo .xctestrun
XCTESTRUN_FILE="$(find "$BUILD_PRODUCTS_DIR" -name "*.xctestrun" 2>/dev/null | head -n 1)"

# 6. Iniciar grabación de video en segundo plano
echo "▶ Iniciando captura de video en vivo..."
rm -f "$OUTPUT_FILE"
xcrun simctl io "$UDID" recordVideo --codec="$CODEC" --force "$OUTPUT_FILE" &
RECORD_PID=$!
sleep 2

# 7. Ejecutar el tour automatizado
echo "▶ Recorriendo la app y grabando pantallas..."
TEST_LOG="$PROJECT_ROOT/build/videos/_last_tour.log"
mkdir -p "$(dirname "$TEST_LOG")"

TEST_STATUS=0
if [[ -n "$XCTESTRUN_FILE" && -f "$XCTESTRUN_FILE" ]]; then
    TEST_RUNNER_VIDEO_APPEARANCE="$APPEARANCE" \
    xcodebuild test-without-building \
        -xctestrun "$XCTESTRUN_FILE" \
        -destination "id=$UDID" \
        -only-testing:"$TEST_TARGET" > "$TEST_LOG" 2>&1 || TEST_STATUS=$?
else
    TEST_RUNNER_VIDEO_APPEARANCE="$APPEARANCE" \
    xcodebuild test \
        -project "$PROJECT_ROOT/CasiListo.xcodeproj" \
        -scheme "$SCHEME" \
        -destination "id=$UDID" \
        -only-testing:"$TEST_TARGET" \
        -parallel-testing-enabled NO > "$TEST_LOG" 2>&1 || TEST_STATUS=$?
fi

# 8. Pausa de cortesía final y cierre de la grabación
sleep 2
echo "▶ Finalizando archivo de video..."
if kill -0 "$RECORD_PID" 2>/dev/null; then
    kill -INT "$RECORD_PID" 2>/dev/null || true
    wait "$RECORD_PID" 2>/dev/null || true
    unset RECORD_PID
fi

# Esperar a que el contenedor MP4 termine de escribir metadatos
sleep 2

if [[ $TEST_STATUS -ne 0 ]]; then
    echo "⚠️ La suite de prueba tuvo advertencias o fallos. Revisa el log: $TEST_LOG"
fi

if [[ -f "$OUTPUT_FILE" && -s "$OUTPUT_FILE" ]]; then
    SIZE="$(du -h "$OUTPUT_FILE" | awk '{print $1}')"
    echo "============================================================"
    echo "✓ Video generado con éxito:"
    echo "  Ruta:    $OUTPUT_FILE"
    echo "  Tamaño:  $SIZE"
    echo "============================================================"

    if [[ $OPEN_WHEN_DONE -eq 1 ]]; then
        echo "▶ Abriendo video con el reproductor por defecto..."
        open "$OUTPUT_FILE"
    fi
else
    echo "error: No se pudo generar el archivo de video en $OUTPUT_FILE" >&2
    exit 1
fi

#!/bin/bash
#
# Captura pantallas de longitud completa (full-length) de CasiListo utilizando SwiftUI ImageRenderer.
#
# No está limitada por la resolución física de la pantalla del simulador: genera imágenes PNG
# de alta resolución con la totalidad del contenido vertical de cada pantalla.
#
# Uso:
#   ci/capture-full-screenshots.sh                         # Ambas apariencias (claro y oscuro)
#   ci/capture-full-screenshots.sh --appearances light     # Solo modo claro
#   ci/capture-full-screenshots.sh --appearances dark      # Solo modo oscuro
#   ci/capture-full-screenshots.sh --out ~/Desktop/capturas # Carpeta de salida personalizada
#   ci/capture-full-screenshots.sh --open                  # Abre la carpeta al finalizar
#
# Tiempo estimado de ejecución: ~5-15 segundos.

set -uo pipefail

readonly SCHEME="CasiListo"
readonly TEST_TARGET="CasiListoTests/FullLengthScreenshotTests"
readonly PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

OUTPUT_DIR="$PROJECT_ROOT/build/screenshots-full"
DEVICE="iPhone 17 Pro"
APPEARANCES="light,dark"
OPEN_WHEN_DONE=0

usage() {
    sed -n '2,14p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --out)         OUTPUT_DIR="$2"; shift 2 ;;
        --device)      DEVICE="$2"; shift 2 ;;
        --appearances) APPEARANCES="$2"; shift 2 ;;
        --open)        OPEN_WHEN_DONE=1; shift ;;
        -h|--help)     usage 0 ;;
        *) echo "Opción desconocida: $1" >&2; usage 1 ;;
    esac
done

if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode-beta.app ]]; then
    export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
fi

if ! xcrun --find simctl > /dev/null 2>&1; then
    echo "error: no se encontró simctl. Define DEVELOPER_DIR apuntando a tu Xcode." >&2
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

# Asegurar que el simulador esté disponible y arrancado
echo "▶ Verificando simulador $DEVICE..."
xcrun simctl boot "$DEVICE" 2>/dev/null || true
xcrun simctl bootstatus "$DEVICE" -b >/dev/null 2>&1 || true

echo "▶ Generando capturas de longitud completa (full-length) con ImageRenderer..."
echo "  Destino: $OUTPUT_DIR"
echo "  Apariencias: $APPEARANCES"

STARTED_AT=$SECONDS
log_file="/tmp/casilisto-full-screenshots.log"

# xcodebuild solo reenvía variables al runner cuando llevan TEST_RUNNER_; el
# proceso de tests recibe SCREENSHOT_DIR y SCREENSHOT_APPEARANCE sin el prefijo.
if TEST_RUNNER_SCREENSHOT_DIR="$OUTPUT_DIR" \
   TEST_RUNNER_SCREENSHOT_APPEARANCE="$APPEARANCES" \
   xcodebuild \
       -project "$PROJECT_ROOT/CasiListo.xcodeproj" \
       -scheme "$SCHEME" \
       -destination "platform=iOS Simulator,name=$DEVICE" \
       -only-testing:"$TEST_TARGET" \
       test < /dev/null > "$log_file" 2>&1; then
    ELAPSED=$((SECONDS - STARTED_AT))
    echo
    echo "✓ Capturas generadas con éxito en ${ELAPSED}s"
    echo
    echo "Archivos generados:"
    find "$OUTPUT_DIR" -type f -name "*.png" | sort | while read -r img; do
        dims="$(sips -g pixelWidth -g pixelHeight "$img" 2>/dev/null | awk '/pixel/ {printf "%s ", $2}' | awk '{print $1 "x" $2 "px"}')"
        size="$(du -h "$img" | awk '{print $1}')"
        rel="${img#"$OUTPUT_DIR/"}"
        printf "  - %-36s %12s (%s)\n" "$rel" "$dims" "$size"
    done

    if [[ $OPEN_WHEN_DONE -eq 1 ]]; then
        open "$OUTPUT_DIR"
    fi
else
    echo "✗ Falló la generación de capturas. Log: $log_file" >&2
    grep -E "error:|XCTAssert|failed -" "$log_file" | head -10 | sed 's/^/    /' >&2
    exit 1
fi

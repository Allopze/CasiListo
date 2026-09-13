#!/bin/bash
#
# Captura el estado visual de CasiListo recorriendo una matriz de variantes.
#
# Cada combinación de dispositivo × apariencia × tamaño de texto es una corrida
# completa de ScreenshotCaptureTests, que deja los PNG en su propia carpeta:
#
#   <salida>/<dispositivo>/<apariencia>/<tamaño-texto>/*.png
#
# Uso:
#   ci/capture-screenshots.sh                      # matriz por defecto (2 corridas)
#   ci/capture-screenshots.sh --full               # + Pro Max y texto XXL (8 corridas)
#   ci/capture-screenshots.sh --devices "iPhone 17 Pro"
#   ci/capture-screenshots.sh --os 26.0            # verificar el piso declarado
#   ci/capture-screenshots.sh --appearances light --text-sizes default
#   ci/capture-screenshots.sh --out ~/Desktop/capturas
#
# Cada corrida tarda unos 3-4 minutos: --full son ~30 minutos.

set -uo pipefail

readonly SCHEME="CasiListo"
readonly TEST_TARGET="CasiListoUITests/ScreenshotCaptureTests"
readonly PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

OUTPUT_DIR="$PROJECT_ROOT/build/screenshots"
DEVICES="iPhone 17 Pro"
OS_VERSION="latest"
APPEARANCES="light,dark"
TEXT_SIZES="default"
KEEP_GOING=0

usage() {
    sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --out)         OUTPUT_DIR="$2"; shift 2 ;;
        --devices)     DEVICES="$2"; shift 2 ;;
        --os)          OS_VERSION="$2"; shift 2 ;;
        --appearances) APPEARANCES="$2"; shift 2 ;;
        --text-sizes)  TEXT_SIZES="$2"; shift 2 ;;
        --full)
            DEVICES="iPhone 17 Pro,iPhone 17 Pro Max"
            APPEARANCES="light,dark"
            TEXT_SIZES="default,xxl"
            shift ;;
        --keep-going)  KEEP_GOING=1; shift ;;
        -h|--help)     usage 0 ;;
        *) echo "Opción desconocida: $1" >&2; usage 1 ;;
    esac
done

# Xcode 26 vive en Xcode-beta en esta máquina; sin esto xcrun no encuentra simctl.
if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode-beta.app ]]; then
    export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
fi

if ! xcrun --find simctl > /dev/null 2>&1; then
    echo "error: no se encontró simctl. Define DEVELOPER_DIR apuntando a tu Xcode." >&2
    exit 1
fi

slug() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]\{1,\}/-/g; s/^-//; s/-$//'
}

# Separa por comas y recorta espacios. Devuelve en el arreglo global SPLIT, no
# por stdout: "iPhone 17 Pro" tiene espacios y un `for` sobre $(...) lo partiría
# en tres dispositivos inexistentes.
SPLIT=()
split_csv() {
    SPLIT=()
    local raw part
    IFS=',' read -ra raw <<< "$1"
    for part in "${raw[@]}"; do
        part="${part#"${part%%[![:space:]]*}"}"
        part="${part%"${part##*[![:space:]]}"}"
        [[ -n "$part" ]] && SPLIT+=("$part")
    done
}

# Los simuladores que no existen se detectan antes de empezar: enterarse a los
# 20 minutos de que el nombre del iPad estaba mal no le sirve a nadie.
split_csv "$DEVICES";     DEVICE_LIST=("${SPLIT[@]}")
split_csv "$APPEARANCES"; APPEARANCE_LIST=("${SPLIT[@]}")
split_csv "$TEXT_SIZES";  TEXT_SIZE_LIST=("${SPLIT[@]}")

AVAILABLE="$(xcrun simctl list devices available)"

# `simctl list devices available` agrupa por runtime bajo cabeceras
# «-- iOS 26.0 --». Buscar el nombre a secas ignora esa sección: con dos
# runtimes instalados validaba un dispositivo que no existe en la versión
# pedida, y más abajo booteaba el simulador equivocado mientras xcodebuild
# arrancaba otro, dejando capturas en la apariencia contraria sin ningún error.
runtime_section() {
    if [[ "$OS_VERSION" == "latest" ]]; then
        printf '%s\n' "$AVAILABLE"
    else
        awk -v want="-- iOS $OS_VERSION --" '
            /^-- / { inside = ($0 == want); next }
            inside { print }
        ' <<< "$AVAILABLE"
    fi
}

SECTION="$(runtime_section)"
if [[ -z "${SECTION//[[:space:]]/}" ]]; then
    echo "error: no hay ningún simulador con iOS $OS_VERSION instalado." >&2
    grep -oE "^-- iOS [0-9.]+" <<< "$AVAILABLE" | sed 's/^-- /  - /' >&2
    exit 1
fi

MISSING=()
for device in "${DEVICE_LIST[@]}"; do
    grep -qF "    $device (" <<< "$SECTION" || MISSING+=("$device")
done

if [[ ${#MISSING[@]} -gt 0 ]]; then
    echo "error: estos simuladores no están disponibles en iOS $OS_VERSION:" >&2
    printf '  - %s\n' "${MISSING[@]}" >&2
    echo "Disponibles:" >&2
    grep -oE "^    (iPhone|iPad)[^(]*" <<< "$SECTION" | sed 's/^    /  - /; s/ $//' >&2
    exit 1
fi

LOG_DIR="$OUTPUT_DIR/_logs"
mkdir -p "$LOG_DIR"

TOTAL=0
FAILED=0
STARTED_AT=$SECONDS

for device in "${DEVICE_LIST[@]}"; do
    for appearance in "${APPEARANCE_LIST[@]}"; do
        for text_size in "${TEXT_SIZE_LIST[@]}"; do
            TOTAL=$((TOTAL + 1))
            variant="$(slug "$device")/ios-$(slug "$OS_VERSION")/$appearance/$text_size"
            variant_dir="$OUTPUT_DIR/$variant"
            log_file="$LOG_DIR/$(slug "$device")-ios-$(slug "$OS_VERSION")-$appearance-$text_size.log"

            rm -rf "$variant_dir"
            mkdir -p "$variant_dir"

            echo "▶ $device · iOS $OS_VERSION · $appearance · texto $text_size"

            # La app fuerza su propio esquema, pero las hojas modales se presentan
            # fuera de esa jerarquía y siguen al sistema. Sin fijar también la
            # apariencia del simulador, salen con el modo de la corrida anterior.
            udid="$(grep -F "    $device (" <<< "$SECTION" | head -1 \
                    | grep -oE '[0-9A-F-]{36}')"
            if [[ -n "$udid" ]]; then
                xcrun simctl boot "$udid" > /dev/null 2>&1
                xcrun simctl bootstatus "$udid" -b > /dev/null 2>&1
                xcrun simctl ui "$udid" appearance "$appearance" > /dev/null 2>&1
            fi

            if [[ "$OS_VERSION" == "latest" ]]; then
                destination="platform=iOS Simulator,name=$device"
            else
                destination="platform=iOS Simulator,name=$device,OS=$OS_VERSION"
            fi

            # TEST_RUNNER_ es obligatorio: xcodebuild no propaga variables sueltas
            # al proceso del runner, les quita ese prefijo al reenviarlas.
            if TEST_RUNNER_SCREENSHOT_DIR="$variant_dir" \
               TEST_RUNNER_SCREENSHOT_APPEARANCE="$appearance" \
               TEST_RUNNER_SCREENSHOT_TEXT_SIZE="$text_size" \
               xcodebuild \
                   -project "$PROJECT_ROOT/CasiListo.xcodeproj" \
                   -scheme "$SCHEME" \
                   -destination "$destination" \
                   -only-testing:"$TEST_TARGET" \
                   test < /dev/null > "$log_file" 2>&1
            then
                echo "  ✓ $(ls -1 "$variant_dir" | wc -l | tr -d ' ') capturas en $variant"
            else
                FAILED=$((FAILED + 1))
                echo "  ✗ falló. Log: $log_file"
                grep -E "error:|XCTAssert|Failed to tap" "$log_file" | sort -u | head -5 | sed 's/^/    /'
                [[ $KEEP_GOING -eq 1 ]] || { echo "Abortando (usa --keep-going para continuar)."; exit 1; }
            fi
        done
    done
done

ELAPSED=$((SECONDS - STARTED_AT))
echo
echo "$((TOTAL - FAILED))/$TOTAL variantes en $((ELAPSED / 60))m $((ELAPSED % 60))s"
echo "Capturas: $OUTPUT_DIR"
[[ $FAILED -eq 0 ]] || exit 1

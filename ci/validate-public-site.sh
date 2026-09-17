#!/usr/bin/env bash
# Valida el sitio publicado y las redirecciones de zona que no puede probar
# `npm test` sobre `dist/`.
#
# Uso:
#   ci/validate-public-site.sh
#   PUBLIC_OLD_SITE_URL=https://casilisto-privacy.pages.dev ci/validate-public-site.sh

set -euo pipefail

readonly BASE_URL="${PUBLIC_SITE_URL:-https://casilisto.lat}"
readonly OLD_SITE_URL="${PUBLIC_OLD_SITE_URL:-}"
readonly WWW_URL="${PUBLIC_WWW_URL:-}"

if [[ ! "$BASE_URL" =~ ^https://[^/]+$ ]]; then
    echo "PUBLIC_SITE_URL debe ser un origen https sin slash final: $BASE_URL" >&2
    exit 2
fi

headers_for() {
    curl --fail --silent --show-error --location --max-time 20 --retry 2 --head "$1"
}

status_for() {
    headers_for "$1" | awk 'toupper($1) ~ /^HTTP\// { status = $2 } END { print status }'
}

assert_status() {
    local url="$1"
    local expected="$2"
    local actual
    actual="$(status_for "$url")"
    if [[ "$actual" != "$expected" ]]; then
        echo "FALLA $url: esperaba HTTP $expected, recibió ${actual:-sin respuesta}" >&2
        exit 1
    fi
    echo "OK    $url -> HTTP $actual"
}

for path in / /privacy/ /support/ /robots.txt /sitemap.xml; do
    assert_status "$BASE_URL$path" 200
done

not_found_body="$(mktemp)"
trap 'rm -f "$not_found_body"' EXIT
not_found_status="$(curl --silent --show-error --max-time 20 --retry 2 --output "$not_found_body" --write-out '%{http_code}' "$BASE_URL/esta-ruta-no-existe")"
if [[ "$not_found_status" != "404" ]] || ! grep -Fq "No encontramos esa página" "$not_found_body"; then
    echo "FALLA $BASE_URL/esta-ruta-no-existe: esperaba HTTP 404 con página legible (recibió $not_found_status)" >&2
    exit 1
fi
echo "OK    ruta inexistente -> HTTP 404 legible"

security_headers="$(headers_for "$BASE_URL/")"
for header in strict-transport-security x-content-type-options content-security-policy; do
    if ! grep -Eqi "^${header}:" <<<"$security_headers"; then
        echo "FALLA $BASE_URL/: falta la cabecera ${header}" >&2
        exit 1
    fi
done
echo "OK    cabeceras de seguridad presentes"

http_url="${BASE_URL/https:\/\//http://}"
http_headers="$(curl --silent --show-error --max-time 20 --retry 2 --head --max-redirs 0 "$http_url" || true)"
http_status="$(awk 'toupper($1) ~ /^HTTP\// { status = $2 } END { print status }' <<<"$http_headers")"
http_location="$(awk 'tolower($1) == "location:" { print $2 }' <<<"$http_headers" | tr -d '\r')"
if [[ "$http_status" != "301" && "$http_status" != "308" ]] || [[ "$http_location" != "$BASE_URL/" && "$http_location" != "$BASE_URL" ]]; then
    echo "FALLA $http_url: debe redirigir permanentemente a $BASE_URL/ (recibió HTTP ${http_status:-sin respuesta}, Location ${http_location:-ausente})" >&2
    exit 1
fi
echo "OK    HTTP -> HTTPS ($http_status)"

check_hostname_redirect() {
    local source="$1"
    local label="$2"
    local redirect_headers
    redirect_headers="$(curl --silent --show-error --max-time 20 --retry 2 --head --max-redirs 0 "$source" || true)"
    local status
    status="$(awk 'toupper($1) ~ /^HTTP\// { value = $2 } END { print value }' <<<"$redirect_headers")"
    local location
    location="$(awk 'tolower($1) == "location:" { print $2 }' <<<"$redirect_headers" | tr -d '\r')"
    if [[ "$status" != "301" && "$status" != "308" ]] || [[ "$location" != "$BASE_URL"* ]]; then
        echo "FALLA $label: debe redirigir a $BASE_URL (recibió HTTP ${status:-sin respuesta}, Location ${location:-ausente})" >&2
        exit 1
    fi
    echo "OK    $label -> $location ($status)"
}

if [[ -n "$WWW_URL" ]]; then
    check_hostname_redirect "$WWW_URL" "www"
fi

if [[ -n "$OLD_SITE_URL" ]]; then
    check_hostname_redirect "$OLD_SITE_URL" "dominio anterior"
fi

echo "Validación pública completada."

#!/usr/bin/env bash
set -euo pipefail

output_directory="${1:-artifacts}"
mkdir -p "$output_directory"

plutil -lint CasiListo/PrivacyInfo.xcprivacy
plutil -lint CasiListoWidget/PrivacyInfo.xcprivacy
plutil -p CasiListo/PrivacyInfo.xcprivacy > "$output_directory/privacy-manifest-app.txt"
plutil -p CasiListoWidget/PrivacyInfo.xcprivacy > "$output_directory/privacy-manifest-widget.txt"

grep -Fq '"NSPrivacyTracking" => false' "$output_directory/privacy-manifest-app.txt"
grep -Fq '"NSPrivacyTracking" => false' "$output_directory/privacy-manifest-widget.txt"
grep -Fq '"CA92.1"' "$output_directory/privacy-manifest-app.txt"
grep -Fq '"1C8F.1"' "$output_directory/privacy-manifest-app.txt"
grep -Fq '"1C8F.1"' "$output_directory/privacy-manifest-widget.txt"

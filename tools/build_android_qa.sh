#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:?Set GODOT_BIN to Godot 4.7.2 stable}"
ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:?Set ANDROID_SDK_ROOT to the Android SDK}"
BUILD_TOOLS="${ANDROID_SDK_ROOT}/build-tools/36.0.0"
APKSIGNER="${BUILD_TOOLS}/apksigner"
AAPT2="${BUILD_TOOLS}/aapt2"
FINAL_APK="${PROJECT_ROOT}/build/ODRAVETH-Stage6-QA-v0.6.1.apk"
TEMP_APK="${PROJECT_ROOT}/build/.ODRAVETH-Stage6-QA-v0.6.1.tmp.apk"

[[ -x "${GODOT_BIN}" ]] || { echo "Godot executable not found: ${GODOT_BIN}" >&2; exit 1; }
[[ -x "${APKSIGNER}" ]] || { echo "apksigner 36.0.0 not found: ${APKSIGNER}" >&2; exit 1; }
[[ -x "${AAPT2}" ]] || { echo "aapt2 36.0.0 not found: ${AAPT2}" >&2; exit 1; }

mkdir -p "${PROJECT_ROOT}/build"
rm -f "${TEMP_APK}" "${TEMP_APK}.idsig"
trap 'rm -f "${TEMP_APK}" "${TEMP_APK}.idsig"' EXIT

"${GODOT_BIN}" --headless --path "${PROJECT_ROOT}" --export-debug "Android QA" "${TEMP_APK}"

python3 - "${TEMP_APK}" <<'PY'
import sys
import zipfile

path = sys.argv[1]
with zipfile.ZipFile(path) as archive:
    broken = archive.testzip()
    if broken is not None:
        raise SystemExit(f"Corrupt APK entry: {broken}")
    names = set(archive.namelist())
    required = {
        "AndroidManifest.xml",
        "lib/arm64-v8a/libgodot_android.so",
        "lib/armeabi-v7a/libgodot_android.so",
        "lib/x86/libgodot_android.so",
        "lib/x86_64/libgodot_android.so",
    }
    missing = sorted(required - names)
    if missing:
        raise SystemExit(f"APK is missing required entries: {missing}")
PY

SIGNATURE_OUTPUT="$("${APKSIGNER}" verify --verbose "${TEMP_APK}")"
[[ "${SIGNATURE_OUTPUT}" == *"Verified using v2 scheme (APK Signature Scheme v2): true"* \
    || "${SIGNATURE_OUTPUT}" == *"Verified using v3 scheme (APK Signature Scheme v3): true"* ]]

BADGING="$("${AAPT2}" dump badging "${TEMP_APK}")"
[[ "${BADGING}" == *"name='com.example.odraveth.qa'"* ]]
[[ "${BADGING}" == *"versionCode='7'"* ]]
[[ "${BADGING}" == *"versionName='0.6.1-qa'"* ]]
[[ "${BADGING}" == *"minSdkVersion:'24'"* ]]
[[ "${BADGING}" == *"targetSdkVersion:'36'"* ]]

mv -f "${TEMP_APK}" "${FINAL_APK}"
rm -f "${FINAL_APK}.idsig"
trap - EXIT
sha256sum "${FINAL_APK}"

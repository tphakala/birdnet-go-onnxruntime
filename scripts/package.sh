#!/usr/bin/env bash
# Package ORT build output into a release archive with metadata.
# Usage: ./scripts/package.sh <platform> <arch> <ort-version> <build-number> [ort-commit]
# Example: ./scripts/package.sh linux x64 1.25.1 1 abc123def
#
# Reads libraries from build/<platform>-<arch>/
# Writes archive to dist/

set -euo pipefail

PLATFORM="${1:?Usage: $0 <platform> <arch> <ort-version> <build-number> [ort-commit]}"
ARCH="${2:?}"
ORT_VERSION="${3:?}"
BUILD_NUMBER="${4:?}"
ORT_COMMIT="${5:-unknown}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

TAG="v${ORT_VERSION}-${BUILD_NUMBER}"
ARTIFACT_NAME="onnxruntime-${PLATFORM}-${ARCH}-${TAG}"
BUILD_INPUT="${REPO_ROOT}/build/${PLATFORM}-${ARCH}"
STAGING="${REPO_ROOT}/dist/${ARTIFACT_NAME}"
DIST_DIR="${REPO_ROOT}/dist"

if [ ! -d "$BUILD_INPUT" ]; then
    echo "Error: build output not found at $BUILD_INPUT"
    exit 1
fi

# ORT source directory (for license files)
ORT_SRC="${REPO_ROOT}/onnxruntime"

# Create staging directory
rm -rf "$STAGING"
mkdir -p "$STAGING/lib"
cp "$BUILD_INPUT"/* "$STAGING/lib/"

# Include ORT license files in the archive (required by MIT license)
if [ -f "$ORT_SRC/LICENSE" ]; then
    cp "$ORT_SRC/LICENSE" "$STAGING/LICENSE"
fi
if [ -f "$ORT_SRC/ThirdPartyNotices.txt" ]; then
    cp "$ORT_SRC/ThirdPartyNotices.txt" "$STAGING/ThirdPartyNotices.txt"
fi

# Compute per-library checksums and sizes
libraries_json="["
first=true
for lib in "$STAGING/lib"/*; do
    name=$(basename "$lib")
    size=$(stat --format="%s" "$lib" 2>/dev/null || stat -f "%z" "$lib")
    sha=$(sha256sum "$lib" | cut -d' ' -f1)
    if [ "$first" = true ]; then
        first=false
    else
        libraries_json+=","
    fi
    libraries_json+=$(printf '\n    {"name": "%s", "size": %s, "sha256": "%s"}' "$name" "$size" "$sha")
done
libraries_json+=$'\n  ]'

# Detect EPs from library names
eps_json="{"
eps_json+='"CPU": {"library": null}'

if ls "$STAGING/lib"/*providers_openvino* >/dev/null 2>&1; then
    openvino_lib=$(basename "$STAGING/lib"/*providers_openvino*)
    openvino_ver="${OPENVINO_VERSION:-unknown}"
    eps_json+=","
    eps_json+=$(printf '\n    "OpenVINO": {"library": "%s", "sdk_version": "%s", "runtime_deps": {"linux_packages": ["intel-opencl-icd"], "user_groups": ["render", "video"], "notes": "Install OpenVINO runtime from Intel APT repo or download from intel.com"}}' "$openvino_lib" "$openvino_ver")
fi

if ls "$STAGING/lib"/*providers_dml* >/dev/null 2>&1; then
    dml_lib=$(basename "$STAGING/lib"/*providers_dml*)
    eps_json+=","
    eps_json+=$(printf '\n    "DirectML": {"library": "%s", "runtime_deps": {"notes": "Requires DirectX 12 compatible GPU and Windows 10 1903+"}}' "$dml_lib")
fi

eps_json+=$'\n  }'

# Build date
build_date=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
runner="${GITHUB_RUNNER_NAME:-local}"

# Write metadata
cat > "$STAGING/metadata.json" <<METADATA
{
  "ort_version": "${ORT_VERSION}",
  "build_number": ${BUILD_NUMBER},
  "tag": "${TAG}",
  "platform": "${PLATFORM}",
  "arch": "${ARCH}",
  "execution_providers": ${eps_json},
  "build_info": {
    "build_date": "${build_date}",
    "runner": "${runner}",
    "ort_commit": "${ORT_COMMIT}"
  },
  "libraries": ${libraries_json}
}
METADATA

# Create archive
mkdir -p "$DIST_DIR"
if [ "$PLATFORM" = "win" ]; then
    archive_name="${ARTIFACT_NAME}.zip"
    (cd "$DIST_DIR" && 7z a -tzip "$archive_name" "$ARTIFACT_NAME")
else
    archive_name="${ARTIFACT_NAME}.tar.gz"
    tar -czf "$DIST_DIR/$archive_name" -C "$DIST_DIR" "$ARTIFACT_NAME"
fi

# Create checksums file (separate from archive, uploaded alongside it)
archive_sha=$(sha256sum "$DIST_DIR/$archive_name" | cut -d' ' -f1)
echo "$archive_sha  $archive_name" > "$DIST_DIR/${ARTIFACT_NAME}.sha256"

echo "Archive: $DIST_DIR/$archive_name"
echo "SHA256:  $archive_sha"
echo "archive_path=$DIST_DIR/$archive_name" >> "${GITHUB_OUTPUT:-/dev/null}"
echo "archive_name=$archive_name" >> "${GITHUB_OUTPUT:-/dev/null}"
echo "archive_sha256=$archive_sha" >> "${GITHUB_OUTPUT:-/dev/null}"

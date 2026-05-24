#!/usr/bin/env bash
# Build ONNX Runtime with OpenVINO EP for Linux x86_64.
# Usage: ./scripts/build-linux-x64.sh <ort-version>
# Expects: OpenVINO SDK installed, python3, cmake, ninja-build available.

set -euo pipefail

ORT_VERSION="${1:?Usage: $0 <ort-version>}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ORT_SRC="${REPO_ROOT}/onnxruntime"
BUILD_DIR="${ORT_SRC}/build/Linux-x64"
OUTPUT_DIR="${REPO_ROOT}/build/linux-x64"

# Find OpenVINO cmake config directory
find_openvino_dir() {
    local dir
    for dir in /usr/lib/cmake/openvino* /opt/intel/openvino*/runtime/cmake; do
        if [ -d "$dir" ]; then
            echo "$dir"
            return
        fi
    done
    echo ""
}

OPENVINO_DIR=$(find_openvino_dir)
if [ -z "$OPENVINO_DIR" ]; then
    echo "Error: OpenVINO SDK not found. Install from Intel APT repo:"
    echo "  apt-get install openvino-toolkit-2025.4"
    exit 1
fi
echo "Found OpenVINO at: $OPENVINO_DIR"

# Clone or update ORT source
if [ ! -d "$ORT_SRC" ]; then
    echo "Cloning ONNX Runtime v${ORT_VERSION}..."
    git clone --depth 1 --branch "v${ORT_VERSION}" \
        https://github.com/microsoft/onnxruntime.git "$ORT_SRC"
else
    echo "ORT source already present at $ORT_SRC"
fi

# Determine parallelism (limit to avoid OOM on CI runners with 7GB RAM)
PARALLEL=${BUILD_PARALLEL:-4}
echo "Building with --parallel $PARALLEL"

# Build
cd "$ORT_SRC"
python3 tools/ci_build/build.py \
    --build_dir "$BUILD_DIR" \
    --config Release \
    --parallel "$PARALLEL" \
    --build_shared_lib \
    --use_openvino GPU \
    --skip_tests \
    --cmake_generator Ninja \
    --cmake_extra_defines \
        OpenVINO_DIR="$OPENVINO_DIR" \
        onnxruntime_BUILD_UNIT_TESTS=OFF \
        onnxruntime_DISABLE_GENERATION_OPS=ON \
    --compile_no_warning_as_error

# Collect output
mkdir -p "$OUTPUT_DIR"
cp "$BUILD_DIR/Release/libonnxruntime.so.${ORT_VERSION}" "$OUTPUT_DIR/"
cp "$BUILD_DIR/Release/libonnxruntime_providers_openvino.so" "$OUTPUT_DIR/"
cp "$BUILD_DIR/Release/libonnxruntime_providers_shared.so" "$OUTPUT_DIR/"

echo "Build complete. Output in $OUTPUT_DIR:"
ls -lh "$OUTPUT_DIR/"

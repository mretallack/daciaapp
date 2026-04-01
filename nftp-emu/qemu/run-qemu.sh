#!/bin/bash
# Run the NNG SDK under QEMU ARM64 user-mode emulation.
# Usage: ./run-qemu.sh [xs_data_dir]
#
# Prerequisites:
#   - qemu-aarch64-static at /tmp/qemu-aarch64-static
#   - Android sysroot at /tmp/qemu_android/
#   - SDK libs at /tmp/qemu_android/data/libs/
#   - XS data at /tmp/qemu_android/data/xs_extract/data/
#
# Setup (one-time):
#   1. Download QEMU: curl -sL https://github.com/multiarch/qemu-user-static/releases/latest/download/qemu-aarch64-static -o /tmp/qemu-aarch64-static && chmod +x /tmp/qemu-aarch64-static
#   2. Install Android 29 arm64 system image: sdkmanager "system-images;android-29;default;arm64-v8a"
#   3. Extract linker64, bionic libs, ICU from system image (see README)
#   4. Compile harness: aarch64-linux-android29-clang -o harness_arm64 harness.c -ldl

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
QROOT=/tmp/qemu_android
QEMU=/tmp/qemu-aarch64-static
XS_DIR="${1:-/data/xs_extract/data}"

if [ ! -x "$QEMU" ]; then
    echo "ERROR: qemu-aarch64-static not found at $QEMU"
    exit 1
fi

if [ ! -d "$QROOT/system/lib64" ]; then
    echo "ERROR: Android sysroot not set up at $QROOT"
    exit 1
fi

exec "$QEMU" -L "$QROOT" \
    -E LD_LIBRARY_PATH=/data/libs:/system/lib64 \
    "$QROOT/data/harness" "$XS_DIR"

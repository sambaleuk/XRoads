#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CACHE_ROOT="${REPO_ROOT}/.build/cache"
SWIFT_CACHE="${CACHE_ROOT}/swiftpm"
CLANG_CACHE="${CACHE_ROOT}/clang"

mkdir -p "${SWIFT_CACHE}" "${CLANG_CACHE}"

export SWIFTPM_MODULECACHE_PATH="${SWIFT_CACHE}"
export CLANG_MODULE_CACHE_PATH="${CLANG_CACHE}"
export MODULECACHE_DIR="${CLANG_CACHE}"

cd "${REPO_ROOT}"

echo "→ Using SwiftPM cache: ${SWIFTPM_MODULECACHE_PATH}"
echo "→ Using Clang cache: ${CLANG_CACHE}"

swift build --disable-sandbox "$@"

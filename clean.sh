#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "==> Cleaning MacRight build caches..."

clean_path() {
    local path="$1"
    if [ -e "$path" ]; then
        rm -rf -- "$path"
        echo "Removed: ${path#$PROJECT_DIR/}"
    fi
}

clean_path "$PROJECT_DIR/build"
clean_path "$PROJECT_DIR/DerivedData"
clean_path "$PROJECT_DIR/.build"
clean_path "$PROJECT_DIR/Scripts/__pycache__"

echo "==> Clean complete."

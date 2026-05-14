#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

python3 -m venv .venv-build
source .venv-build/bin/activate
python -m pip install --upgrade pip
pip install . pyinstaller

rm -rf build dist
pyinstaller --onefile \
  --name omniscan \
  --collect-data sherlock_project \
  omniscan/__main__.py

mkdir -p dist/release
cp dist/omniscan dist/release/omniscan-macos-arm64

echo "Built: dist/release/omniscan-macos-arm64"

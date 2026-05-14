#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

python3 -m venv .venv-build
source .venv-build/bin/activate
python -m pip install --upgrade pip
pip install . pyinstaller holehe httpx

rm -rf build dist
pyinstaller --onefile \
  --name omniscan \
  --collect-data sherlock_project \
  --collect-data holehe \
  omniscan/__main__.py

mkdir -p dist/release
cp dist/omniscan dist/release/omniscan-linux-x86_64

echo "Built: dist/release/omniscan-linux-x86_64"

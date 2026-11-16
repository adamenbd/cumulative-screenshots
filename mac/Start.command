#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 -m venv .venv-mac
.venv-mac/bin/python -m pip install -r mac/requirements.txt
exec .venv-mac/bin/python mac/main.py

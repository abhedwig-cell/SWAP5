#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
python3 research/ahl/ahl25a_model3_source_inventory.py | tee "${1:-/tmp/ahl25a_inventory.json}"

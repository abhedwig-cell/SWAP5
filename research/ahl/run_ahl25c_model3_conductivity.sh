#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
PYTHONPATH=research/ahl python3 research/ahl/ahl25c_model3_conductivity.py | tee "${1:-/tmp/ahl25c_result.json}"
grep -q '"status": "PASS"' "${1:-/tmp/ahl25c_result.json}"

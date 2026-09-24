#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)";cd "$ROOT"
PYTHONPATH=research/ahl python3 research/ahl/ahl26e_pdi_novap_k.py | tee "${1:-/tmp/ahl26e.json}"
grep -q '"status": "PASS"' "${1:-/tmp/ahl26e.json}"

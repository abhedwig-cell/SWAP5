#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
python3 research/pdi_vt/f_pdi_vt02_direct_gate.py | tee "${1:-/tmp/f_pdi_vt02.json}"
grep -q '"status": "PASS"' "${1:-/tmp/f_pdi_vt02.json}"

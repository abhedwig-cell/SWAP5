#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
PYTHONPATH=research/ahl python3 research/ahl/ahl26c_pdi_retention.py | tee "${1:-/tmp/ahl26c.json}"
grep -q '"status": "PASS"' "${1:-/tmp/ahl26c.json}"

#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
python3 research/ahl/ahl26b_pdi_transform_diagnosis.py | tee "${1:-/tmp/ahl26b.json}"
grep -q '"status": "LEGACY_TRANSFORM_REJECTED"' "${1:-/tmp/ahl26b.json}"

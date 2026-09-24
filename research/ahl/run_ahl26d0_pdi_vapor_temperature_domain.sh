#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)";cd "$ROOT"
python3 research/ahl/ahl26d0_pdi_vapor_temperature_domain.py | tee "${1:-/tmp/ahl26d0.json}"

#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
PYTHONPATH=research/ahl python3 research/ahl/ahl22_fallback_indicator_diagnostic.py | tee "${1:-/tmp/ahl22_result.json}"

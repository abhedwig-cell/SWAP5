#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
python3 tests/fpe/guard_fpe_timearch04_source.py
python3 tests/fpe/run_fpe_timearch04_scheduler.py

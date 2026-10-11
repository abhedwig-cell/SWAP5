#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
WU05A9_ONLY=1 WU05_MIGMAC02=1 bash tests/fpm/run_ppa_wu05a9_top_input.sh

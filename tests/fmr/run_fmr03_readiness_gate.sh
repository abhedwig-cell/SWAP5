#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

# Preserve the complete qualified F-MR02 shared-postimage regression chain.
bash tests/fmr/run_fmr02_gate.sh

# Qualify the fail-closed readiness/admission decision itself. This does not
# qualify or admit a serialized or parallel physical reference backend.
python3 tools/fmr/fmr03_readiness_gate.py

echo 'F-MR03_FAIL_CLOSED_READINESS_GATE PASS'

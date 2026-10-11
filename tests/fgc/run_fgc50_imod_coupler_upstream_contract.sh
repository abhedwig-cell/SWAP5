#!/usr/bin/env bash
set -euo pipefail

: "${FGC50_IMOD_COUPLER_ROOT:?FGC50_IMOD_COUPLER_ROOT must point to the pinned upstream checkout}"
: "${FGC50_IMOD_COUPLER_SHA:?FGC50_IMOD_COUPLER_SHA must contain the pinned upstream SHA}"

python3 tests/fgc/test_fgc50_imod_coupler_upstream_contract.py

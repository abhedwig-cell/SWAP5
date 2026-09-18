#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
python3 tests/fvq/test_fvq124_fgc49d_independent.py
git diff --check --   src/runtime/mod_modflow6_linear_response_backend.f90   src/runtime/mod_fmr_groundwater_application_context.f90   src/adapter/mod_fmr_groundwater_application_c_api.f90   src/adapter/fmr_groundwater_application_runtime.py   tests/fvq/test_fvq124_fgc49d_independent.py
echo 'F-VQ124 F-GC49D INDEPENDENT GATE PASS'

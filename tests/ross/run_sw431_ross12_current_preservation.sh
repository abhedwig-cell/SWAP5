#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
fail(){ echo "SW431_ROSS_CURRENT_PRESERVATION_FAIL $*" >&2; exit 1; }

# Current-canonical owner preservation, not a replay of the superseded
# F-ROSS12 six-material adapter oracle. The latter fails on the admitted
# F-ROSS13/F-ROSS22 kernel successor even without any HYD/HYST modifications.
# Preserve the modern RossFast owner and interface byte-for-byte, then execute
# its current 36-material source-level physical oracle under O0 and O2.
declare -A pins=(
  [src/solver/mod_soil_water_solver_contract.f90]=7b16c3fcf58179f1491104a1dce3279010b4178a
  [src/runtime/mod_rossfast_d3r_execution_policy.f90]=a39a636d01f373ae6ef0dc3ac0e1e25b6522fda9
  [src/runtime/mod_rossfast_d3r_model_binding.f90]=5442fd7e7a2f392c9b796cd17c76b17977259f22
  [src/solver/mod_rossfast_d3r_table_kernel.f90]=438ee46e012e9eb183b8f2532437e2fe56aa18ed
  [src/solver/mod_rossfast_d3r_table_provider.f90]=ac997bf06c56a37080d1c8db69b6d4208f4b75ca
  [src/solver/mod_rossfast_d3r_soil_water_solver.f90]=2b134c36097aed2a44a56bfe8e2194b15aa063aa
  [src/runtime/mod_fmr_rossfast_solver_selection_binding.f90]=cca61af52bde3eed12b756547277cc2776589648
)
for source in "${!pins[@]}"; do
  [[ "$(git rev-parse "HEAD:$source")" == "${pins[$source]}" ]] || fail "current canonical owner drift $source"
done
echo "SW431_ROSS_CURRENT_CANONICAL_OWNER_BLOB_IDENTITY=PASS"
bash tests/ross/run_ross13_36_material_production_envelope.sh
echo "SW431_ROSS_CURRENT_36_MATERIAL_O0_O2_PRESERVATION=PASS"

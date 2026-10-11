#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

CANONICAL="e9bb0e0f8da05f18b440b39e1a7b5a841d54aecb"
GC20_BLOB="d62ecba039d9bef178acde6900b81e9d5b0931eb"
GC22_BLOB="b8ac03e810c73519b433f7851c6fd143ba26676a"
GC21_BLOB="fa2a5a45d558fbaaea242438915cdb7420b6503c"

# F-GC23 owner work is reconciled on the exact current canonical prerequisite set.
git merge-base --is-ancestor "$CANONICAL" HEAD

test "$(git rev-parse HEAD:src/runtime/mod_groundwater_tile_aggregation.f90)" = "$GC20_BLOB"
test "$(git rev-parse HEAD:src/runtime/mod_groundwater_accuracy_binding.f90)" = "$GC22_BLOB"
test "$(git rev-parse HEAD:src/runtime/mod_groundwater_predictor_corrector_window.f90)" = "$GC21_BLOB"

mapfile -t changed_src < <(git diff --name-only "$CANONICAL..HEAD" -- 'src/**')
test "${#changed_src[@]}" -eq 1
test "${changed_src[0]}" = "src/runtime/mod_groundwater_coupling_response.f90"

while IFS= read -r path; do
  case "$path" in
    src/runtime/mod_groundwater_coupling_response.f90|tests/fgc/test_fgc23_whole_window_response_tangent.f90|tests/fgc/run_fgc23_whole_window_response_tangent.sh|.github/workflows/fgc23-whole-window-response-tangent.yml|integration/f-gc/F-GC23_*) ;;
    *) echo "FGC23_SCOPE_FAIL unexpected path: $path" >&2; exit 20 ;;
  esac
done < <(git diff --name-only "$CANONICAL..HEAD")

python3 - <<'PY'
from pathlib import Path
s=Path('src/runtime/mod_groundwater_coupling_response.f90').read_text()
low=s.lower()
for forbidden in ['modflow', 'finite_difference', 'secant', 'groundwater_commit', 'groundwater_prepare', 'ledger%commit', 'advance_interval']:
    assert forbidden not in low, forbidden
for required in [
    'accepted_bottom_exchange_derivative',
    'SW_STEP_CONTROL_BOTTOM_HEAD',
    'groundwater_response%status /= GW_RESPONSE_OK',
    'swap_direction%origin_t0',
    'swap_direction%accepted_t1',
    'groundwater_response%origin_revision /= lineage%groundwater_origin_revision',
    'groundwater_response%candidate_revision /= lineage%candidate_revision',
    'swap_direction%additional_full_nonlinear_solves /= 0',
    'jacobian = 1.0_real64 - dh_groundwater_dh_swap',
    'corrector_h = predictor_h_swap_m - predictor_head_residual_m / jacobian'
]:
    assert required in s, required
assert 'covers_requested_interval' not in s
assert 'LOCAL_TERMINAL' not in s
print('FGC23_STATIC_CONTRACT_AUDIT=PASS')
print('FGC23_NO_STRUCTURAL_FD_NORMAL_PATH=PASS')
print('FGC23_NO_GROUNDWATER_COMMIT_OR_LEDGER_OWNERSHIP=PASS')
PY

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

compile_and_run() {
  local opt="$1"
  local out="$2"
  local dir="$work/$opt"
  mkdir -p "$dir"
  gfortran "-$opt" -std=f2008 -Wall -Wextra -fcheck=all -ffpe-trap=invalid,zero,overflow \
    -J"$dir" -I"$dir" \
    src/solver/mod_soil_water_accepted_step_direction_contract.f90 \
    src/transaction/mod_accepted_trajectory_directional_sensitivity.f90 \
    src/transaction/mod_accepted_trajectory_directional_publication.f90 \
    src/runtime/mod_groundwater_coupling_contract.f90 \
    src/runtime/mod_groundwater_exchange_service_contract.f90 \
    src/runtime/mod_groundwater_response_sensitivity_contract.f90 \
    src/runtime/mod_groundwater_coupling_response.f90 \
    tests/fgc/test_fgc23_whole_window_response_tangent.f90 \
    -o "$dir/test_fgc23"
  "$dir/test_fgc23" > "$out"
}

compile_and_run O0 "$work/o0.txt"
compile_and_run O2 "$work/o2.txt"
diff -u "$work/o0.txt" "$work/o2.txt"

for marker in \
  FGC23_ACCEPTED_ONLY_COMPOSITION \
  FGC23_REJECTED_RETRY_ZERO_CONTRIBUTION \
  FGC23_EXACT_WINDOW_AND_ORIGIN_PROVENANCE \
  FGC23_BOTTOM_HEAD_CONTROL_ONLY \
  FGC23_WHOLE_WINDOW_FIVE_POINT_FD_REFERENCE \
  FGC23_ONE_CORRECTOR_RESIDUAL_CONTRACTION \
  FGC23_NO_EXTRA_FULL_NONLINEAR_SOLVE \
  FGC23_UNAVAILABLE_NONSMOOTH_FAIL_CLOSED \
  FGC23_STALE_GROUNDWATER_RESPONSE_FAIL_CLOSED \
  FGC23_ILL_CONDITIONED_FAIL_CLOSED \
  FGC23_INPUT_CARRIERS_UNCHANGED \
  FGC23_DETERMINISTIC_RESPONSE \
  FGC23_OWNER_ORACLE; do
  grep -q "^${marker}=PASS$" "$work/o0.txt"
done

cat "$work/o0.txt"
echo "FGC23_CURRENT_CANONICAL=PASS:$CANONICAL"
echo "FGC23_GC20_SOURCE_IDENTITY=PASS:$GC20_BLOB"
echo "FGC23_GC22_SOURCE_IDENTITY=PASS:$GC22_BLOB"
echo "FGC23_FGC21_MASS_COMMIT_ROLLBACK_SOURCE_IDENTITY=PASS:$GC21_BLOB"
echo 'FGC23_SCOPE_ALLOWLIST=PASS'
echo 'FGC23_O0_O2_IDENTITY=PASS'
echo 'FGC23_DECISION=OWNER_QUALIFIED_PENDING_INDEPENDENT_QUALIFICATION'

#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

CANONICAL="e9bb0e0f8da05f18b440b39e1a7b5a841d54aecb"
OWNER_QUALIFIED="20edbe2bfcecca24541fa2885fe9ff4e8c1fb172"
OWNER_CHECKPOINT="a5660705ab8564026a344c37d09e386acdee0df2"
FVQ95_CHECKPOINT="da64ffb1f4cd5105e2809a02ddae02f50a9c853b"
FGC23_BLOB="645141676536ae8289b9d52433798a965c7baa04"
GC20_BLOB="d62ecba039d9bef178acde6900b81e9d5b0931eb"
GC22_BLOB="b8ac03e810c73519b433f7851c6fd143ba26676a"
GC21_BLOB="fa2a5a45d558fbaaea242438915cdb7420b6503c"

for ancestor in "$CANONICAL" "$OWNER_QUALIFIED" "$OWNER_CHECKPOINT" "$FVQ95_CHECKPOINT"; do
  git merge-base --is-ancestor "$ancestor" HEAD
done

test "$(git rev-parse HEAD:src/runtime/mod_groundwater_coupling_response.f90)" = "$FGC23_BLOB"
test "$(git rev-parse HEAD:src/runtime/mod_groundwater_tile_aggregation.f90)" = "$GC20_BLOB"
test "$(git rev-parse HEAD:src/runtime/mod_groundwater_accuracy_binding.f90)" = "$GC22_BLOB"
test "$(git rev-parse HEAD:src/runtime/mod_groundwater_predictor_corrector_window.f90)" = "$GC21_BLOB"

mapfile -t changed_src < <(git diff --name-only "$CANONICAL..HEAD" -- 'src/**')
test "${#changed_src[@]}" -eq 1
test "${changed_src[0]}" = "src/runtime/mod_groundwater_coupling_response.f90"

while IFS= read -r path; do
  case "$path" in
    src/runtime/mod_groundwater_coupling_response.f90|tests/fgc/test_fgc23_whole_window_response_tangent.f90|tests/fgc/run_fgc23_whole_window_response_tangent.sh|.github/workflows/fgc23-whole-window-response-tangent.yml|integration/f-gc/F-GC23_*|qualification/test_fvq95_fgc23_whole_window_response_tangent.f90|qualification/run_fvq95_fgc23_whole_window_response_tangent.sh|qualification/F-VQ95_*|.github/workflows/f-vq95-fgc23-whole-window-response-tangent.yml|qualification/run_fci85_fgc23_canonical_admission.sh|qualification/F-CI85_*|.github/workflows/f-ci85-fgc23-canonical-admission.yml) ;;
    *) echo "FCI85_SCOPE_FAIL unexpected path: $path" >&2; exit 20 ;;
  esac
done < <(git diff --name-only "$CANONICAL..HEAD")

python3 - <<'PY'
from pathlib import Path
s=Path('src/runtime/mod_groundwater_coupling_response.f90').read_text()
low=s.lower()
for required in [
    'accepted_bottom_exchange_derivative',
    'SW_STEP_CONTROL_BOTTOM_HEAD',
    'swap_direction%origin_t0',
    'swap_direction%accepted_t1',
    'groundwater_response%origin_revision /= lineage%groundwater_origin_revision',
    'groundwater_response%candidate_revision /= lineage%candidate_revision',
    'swap_direction%additional_full_nonlinear_solves /= 0',
    'jacobian = 1.0_real64 - dh_groundwater_dh_swap',
    'corrector_h = predictor_h_swap_m - predictor_head_residual_m / jacobian'
]:
    assert required in s, required
for forbidden in ['covers_requested_interval', 'LOCAL_TERMINAL', 'finite_difference', 'secant', 'modflow', 'advance_interval', 'groundwater_commit', 'ledger%commit']:
    assert forbidden not in s and forbidden.lower() not in low, forbidden
print('FCI85_STATIC_CONTRACT_AUDIT=PASS')
print('FCI85_ONLY_ONE_PRODUCTION_SOURCE_DELTA=PASS')
print('FCI85_NO_STRUCTURAL_FD_OR_SCOPE_UPGRADE=PASS')
PY

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

compile_common() {
  local opt="$1" test_source="$2" exe="$3" out="$4" dir="$5"
  mkdir -p "$dir"
  gfortran "-$opt" -std=f2008 -Wall -Wextra -ffree-line-length-none -fcheck=all -ffpe-trap=invalid,zero,overflow \
    -J"$dir" -I"$dir" \
    src/solver/mod_soil_water_accepted_step_direction_contract.f90 \
    src/transaction/mod_accepted_trajectory_directional_sensitivity.f90 \
    src/transaction/mod_accepted_trajectory_directional_publication.f90 \
    src/runtime/mod_groundwater_coupling_contract.f90 \
    src/runtime/mod_groundwater_exchange_service_contract.f90 \
    src/runtime/mod_groundwater_response_sensitivity_contract.f90 \
    src/runtime/mod_groundwater_coupling_response.f90 \
    "$test_source" -o "$dir/$exe"
  "$dir/$exe" > "$out"
}

compile_common O0 tests/fgc/test_fgc23_whole_window_response_tangent.f90 owner "$work/owner_o0.txt" "$work/owner_o0"
compile_common O2 tests/fgc/test_fgc23_whole_window_response_tangent.f90 owner "$work/owner_o2.txt" "$work/owner_o2"
diff -u "$work/owner_o0.txt" "$work/owner_o2.txt"
grep -q '^FGC23_OWNER_ORACLE=PASS$' "$work/owner_o0.txt"

compile_common O0 qualification/test_fvq95_fgc23_whole_window_response_tangent.f90 fvq95 "$work/fvq_o0.txt" "$work/fvq_o0"
compile_common O2 qualification/test_fvq95_fgc23_whole_window_response_tangent.f90 fvq95 "$work/fvq_o2.txt" "$work/fvq_o2"
diff -u "$work/fvq_o0.txt" "$work/fvq_o2.txt"
grep -q '^FVQ95_INDEPENDENT_ORACLE=PASS$' "$work/fvq_o0.txt"

cat "$work/owner_o0.txt"
cat "$work/fvq_o0.txt"
echo "FCI85_CANONICAL_BASE=PASS:$CANONICAL"
echo "FCI85_OWNER_QUALIFIED_SOURCE=PASS:$OWNER_QUALIFIED"
echo "FCI85_OWNER_CHECKPOINT=PASS:$OWNER_CHECKPOINT"
echo "FCI85_FVQ95_CHECKPOINT=PASS:$FVQ95_CHECKPOINT"
echo "FCI85_FGC23_SOURCE_BLOB=PASS:$FGC23_BLOB"
echo "FCI85_GC20_SOURCE_IDENTITY=PASS:$GC20_BLOB"
echo "FCI85_GC22_SOURCE_IDENTITY=PASS:$GC22_BLOB"
echo "FCI85_FGC21_MASS_COMMIT_ROLLBACK_SOURCE_IDENTITY=PASS:$GC21_BLOB"
echo 'FCI85_OWNER_O0_O2_IDENTITY=PASS'
echo 'FCI85_INDEPENDENT_O0_O2_IDENTITY=PASS'
echo 'FCI85_DECISION=QUALIFIED_FOR_FAST_FORWARD_CANONICAL_ADMISSION'

#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

CANONICAL="e9bb0e0f8da05f18b440b39e1a7b5a841d54aecb"
QUALIFIED_SOURCE="20edbe2bfcecca24541fa2885fe9ff4e8c1fb172"
QUALIFY_CHECKPOINT="a5660705ab8564026a344c37d09e386acdee0df2"
FGC23_BLOB="645141676536ae8289b9d52433798a965c7baa04"
GC20_BLOB="d62ecba039d9bef178acde6900b81e9d5b0931eb"
GC22_BLOB="b8ac03e810c73519b433f7851c6fd143ba26676a"
GC21_BLOB="fa2a5a45d558fbaaea242438915cdb7420b6503c"

# Independent qualification may add evidence only. The immutable owner source is fixed.
git merge-base --is-ancestor "$CANONICAL" HEAD
git merge-base --is-ancestor "$QUALIFIED_SOURCE" HEAD
git merge-base --is-ancestor "$QUALIFY_CHECKPOINT" HEAD

test "$(git rev-parse HEAD:src/runtime/mod_groundwater_coupling_response.f90)" = "$FGC23_BLOB"
test "$(git rev-parse HEAD:src/runtime/mod_groundwater_tile_aggregation.f90)" = "$GC20_BLOB"
test "$(git rev-parse HEAD:src/runtime/mod_groundwater_accuracy_binding.f90)" = "$GC22_BLOB"
test "$(git rev-parse HEAD:src/runtime/mod_groundwater_predictor_corrector_window.f90)" = "$GC21_BLOB"

mapfile -t changed_src < <(git diff --name-only "$QUALIFIED_SOURCE..HEAD" -- 'src/**')
test "${#changed_src[@]}" -eq 0

while IFS= read -r path; do
  case "$path" in
    integration/f-gc/F-GC23_QUALIFY_CHECKPOINT.json|qualification/test_fvq95_fgc23_whole_window_response_tangent.f90|qualification/run_fvq95_fgc23_whole_window_response_tangent.sh|qualification/F-VQ95_*|.github/workflows/f-vq95-fgc23-whole-window-response-tangent.yml) ;;
    *) echo "FVQ95_SCOPE_FAIL unexpected post-qualified-source path: $path" >&2; exit 20 ;;
  esac
done < <(git diff --name-only "$QUALIFIED_SOURCE..HEAD")

python3 - <<'PY'
from pathlib import Path
s=Path('src/runtime/mod_groundwater_coupling_response.f90').read_text()
low=s.lower()
assert 'accepted_bottom_exchange_derivative' in s
assert 'SW_STEP_CONTROL_BOTTOM_HEAD' in s
assert 'jacobian = 1.0_real64 - dh_groundwater_dh_swap' in s
assert 'corrector_h = predictor_h_swap_m - predictor_head_residual_m / jacobian' in s
assert 'covers_requested_interval' not in s
assert 'LOCAL_TERMINAL' not in s
for forbidden in ['finite_difference', 'secant', 'modflow', 'advance_interval', 'groundwater_commit', 'ledger%commit']:
    assert forbidden not in low, forbidden
print('FVQ95_IMMUTABLE_SOURCE_AUDIT=PASS')
print('FVQ95_NO_STRUCTURAL_FD_NORMAL_PATH=PASS')
print('FVQ95_NO_SCOPE_UPGRADE_OR_LOCAL_RELABEL=PASS')
PY

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

compile_and_run() {
  local opt="$1"
  local out="$2"
  local dir="$work/$opt"
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
    qualification/test_fvq95_fgc23_whole_window_response_tangent.f90 \
    -o "$dir/test_fvq95"
  "$dir/test_fvq95" > "$out"
}

compile_and_run O0 "$work/o0.txt"
compile_and_run O2 "$work/o2.txt"
diff -u "$work/o0.txt" "$work/o2.txt"

for marker in \
  FVQ95_ACCEPTED_WHOLE_WINDOW_ONLY \
  FVQ95_REJECTED_RETRY_ZERO_CONTRIBUTION \
  FVQ95_GENERIC_WINDOW_PROVENANCE \
  FVQ95_BOTTOM_HEAD_CONTROL_SCOPE \
  FVQ95_NONLINEAR_FIVE_POINT_FD_REFERENCE \
  FVQ95_ONE_CORRECTOR_NONLINEAR_CONTRACTION \
  FVQ95_UNAVAILABLE_NONSMOOTH_FAIL_CLOSED \
  FVQ95_STALE_RESPONSE_FAIL_CLOSED \
  FVQ95_NO_STRUCTURAL_FULL_SOLVE \
  FVQ95_INPUTS_NOT_MUTATED \
  FVQ95_DETERMINISTIC \
  FVQ95_INDEPENDENT_ORACLE; do
  grep -q "^${marker}=PASS$" "$work/o0.txt"
done

cat "$work/o0.txt"
echo "FVQ95_CANONICAL_DEPENDENCY=PASS:$CANONICAL"
echo "FVQ95_QUALIFIED_SOURCE=PASS:$QUALIFIED_SOURCE"
echo "FVQ95_FGC23_SOURCE_BLOB=PASS:$FGC23_BLOB"
echo "FVQ95_GC20_SOURCE_IDENTITY=PASS:$GC20_BLOB"
echo "FVQ95_GC22_SOURCE_IDENTITY=PASS:$GC22_BLOB"
echo "FVQ95_FGC21_MASS_COMMIT_ROLLBACK_SOURCE_IDENTITY=PASS:$GC21_BLOB"
echo 'FVQ95_ZERO_PRODUCTION_DELTA_AFTER_OWNER_QUALIFICATION=PASS'
echo 'FVQ95_O0_O2_IDENTITY=PASS'
echo 'FVQ95_DECISION=INDEPENDENTLY_QUALIFIED_PENDING_CANONICAL_ADMISSION'

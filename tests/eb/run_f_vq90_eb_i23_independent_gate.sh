#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

fail() { echo "F_VQ90_FAIL $*" >&2; exit 190; }

OWNER="94832bb80534c2edb324c1c9e0cbb54df3678246"
CANONICAL="3ff0f42299767d5ad5f07d031698dfcf7969ed0d"
QUAL_BRANCH="qualification/f-vq90-eb-i23-sensible-boundary-runtime-independent-qualification"
MODULE="src/runtime/mod_eb_i23_sensible_boundary_runtime.f90"
OWNER_TEST="tests/eb/test_eb_i23_sensible_boundary_runtime_materialization.f90"
OWNER_CONTRACT="tests/eb/EB-I23_CONTRACT.md"
OWNER_GATE="tests/eb/run_eb_i23_sensible_boundary_runtime_materialization_gate.sh"
QUAL_GATE="tests/eb/run_f_vq90_eb_i23_independent_gate.sh"
QUAL_WORKFLOW=".github/workflows/f-vq90-eb-i23-independent.yml"
STATUS="qualification/F-VQ90_STATUS.json"

# Independent qualification is bound to the exact green owner head and the
# dependency surface against which that head was qualified.
git fetch -q origin integration/f-ci-canonical
LIVE="$(git rev-parse origin/integration/f-ci-canonical)"
[[ "$LIVE" == "$CANONICAL" ]] || fail "live canonical moved: $LIVE != $CANONICAL"
[[ "$(git merge-base "$OWNER" HEAD)" == "$OWNER" ]] || fail 'qualification branch is not descended from exact owner head'

# Owner-owned evidence must remain immutable on the qualification branch.
declare -A OWNER_BLOBS=(
  [$MODULE]=35dda86ca51bd91040af0672a43e2961c8db64fd
  [$OWNER_TEST]=e9fde2d51d2c8cb76ae2def4b7e4a3acaf356d4a
  [$OWNER_CONTRACT]=56bfd4f1350e569e6f651ca4ada13550af93f986
  [$OWNER_GATE]=fb14542ecccb4b731c12134e069976e968f1e3f3
)
for path in "${!OWNER_BLOBS[@]}"; do
  [[ "$(git rev-parse "$OWNER:$path")" == "${OWNER_BLOBS[$path]}" ]] || fail "owner blob mismatch $path"
  [[ "$(git rev-parse "HEAD:$path")" == "${OWNER_BLOBS[$path]}" ]] || fail "qualification mutated owner evidence $path"
done

echo "F_VQ90_OWNER_HEAD_GUARD=PASS owner=$OWNER canonical=$CANONICAL"

# Current canonical dependencies inherited by EB-I23 must still be byte-identical.
declare -A DEPENDENCY_BLOBS=(
  [src/process/mod_restricted_soil_temperature.f90]=fa4e1d7b48d3515e6569c9080d497178c25c4e85
  [src/process/mod_soil_temperature_contract.f90]=baa13df3975de2c699b0ec910477bcfa9b47f15e
  [src/runtime/mod_fmr_serialized_reference_backend.f90]=3506b453ba6a00111d182f29db8cbfb288001854
  [src/runtime/mod_fmr_serialized_multiswap_runtime.f90]=1aa2454048d0e480becaee34f596f20f1a7bd66e
  [src/process/mod_liquid_water_sensible_enthalpy.f90]=2247370ee34fac73a0e2d0b9fa15e171467aded3
  [src/process/mod_whole_column_sensible_energy_accounting.f90]=c00efd8cdb4de947de16e1d32ae4c9f4d0590850
)
for path in "${!DEPENDENCY_BLOBS[@]}"; do
  [[ "$(git rev-parse "$LIVE:$path")" == "${DEPENDENCY_BLOBS[$path]}" ]] || fail "dependency drift $path"
done
echo 'F_VQ90_DEPENDENCY_SURFACE_GUARD=PASS'

# Qualification branch may add only its own independent evidence/status.
while IFS= read -r path; do
  case "$path" in
    "$QUAL_GATE"|"$QUAL_WORKFLOW"|"$STATUS") ;;
    *) fail "qualification mutated out-of-scope path: $path" ;;
  esac
done < <(git diff --name-only "$OWNER" HEAD)
echo 'F_VQ90_QUALIFICATION_ONLY_DELTA=PASS'

# Replay the exact immutable owner head in a detached worktree. This establishes
# that the owner evidence is reproducible independently of the qualification delta.
OWNER_TREE="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-fvq90-owner-${GITHUB_RUN_ID:-local}-$$"
MUTANT_TREE="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-fvq90-mutant-${GITHUB_RUN_ID:-local}-$$"
cleanup() {
  git worktree remove --force "$OWNER_TREE" >/dev/null 2>&1 || true
  git worktree remove --force "$MUTANT_TREE" >/dev/null 2>&1 || true
}
trap cleanup EXIT

git worktree add --detach "$OWNER_TREE" "$OWNER" >/dev/null
(
  cd "$OWNER_TREE"
  bash tests/eb/run_eb_i23_sensible_boundary_runtime_materialization_gate.sh
)
echo 'F_VQ90_EXACT_OWNER_REPLAY=PASS'

# Create a separate disposable owner worktree for adversarial mutation tests.
git worktree add --detach "$MUTANT_TREE" "$OWNER" >/dev/null

run_expected_failure() {
  local label="$1"
  local expected="$2"
  local log="$MUTANT_TREE/fvq90-${label}.log"
  set +e
  (cd "$MUTANT_TREE" && bash tests/eb/run_eb_i23_sensible_boundary_runtime_materialization_gate.sh) >"$log" 2>&1
  local rc=$?
  set -e
  [[ $rc -ne 0 ]] || { cat "$log" >&2; fail "$label mutant unexpectedly qualified"; }
  grep -Fq "$expected" "$log" || { cat "$log" >&2; fail "$label mutant failed for unexpected reason"; }
  echo "F_VQ90_${label^^}_MUTANT_REJECTED=PASS"
  git -C "$MUTANT_TREE" checkout -- "$MODULE"
}

# Attack 1: reverse the already-qualified F-PM07B/FMR39 residual convention.
python3 - "$MUTANT_TREE/$MODULE" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
s = p.read_text()
old = """accounting_identity = observation%soil_temperature_storage_change_j_cm2 - &\n           observation%soil_temperature_boundary_energy_j_cm2 - observation%soil_temperature_energy_residual_j_cm2"""
new = """accounting_identity = observation%soil_temperature_boundary_energy_j_cm2 - &\n           observation%soil_temperature_storage_change_j_cm2 - observation%soil_temperature_energy_residual_j_cm2"""
if s.count(old) != 1:
    raise SystemExit('residual mutation anchor mismatch')
p.write_text(s.replace(old, new))
PY
run_expected_failure "residual_sign" "top conductive accepted materialization"

# Attack 2: erase bottom-donor availability by allowing the initialized zero
# energy value to become a supposedly known bottom advective result.
python3 - "$MUTANT_TREE/$MODULE" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
s = p.read_text()
old = "if (bottom_available .and. ieee_is_finite(bottom_energy)) then"
new = "if (ieee_is_finite(bottom_energy)) then"
if s.count(old) != 1:
    raise SystemExit('bottom availability mutation anchor mismatch')
p.write_text(s.replace(old, new))
PY
run_expected_failure "missing_as_zero" "missing bottom donor is not zero energy"

# Attack 3: broaden conductive publication beyond the owned single-substep
# observation. The owner static gate must reject this before runtime evidence.
python3 - "$MUTANT_TREE/$MODULE" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
s = p.read_text()
old = "output%accepted_substeps == 1"
new = "output%accepted_substeps >= 1"
if s.count(old) != 1:
    raise SystemExit('substep mutation anchor mismatch')
p.write_text(s.replace(old, new))
PY
run_expected_failure "multisubstep_broadening" "single-substep thermal safety gate missing"

# Attack 4: fabricate a top mass-carried term without a qualified donor source.
python3 - "$MUTANT_TREE/$MODULE" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
s = p.read_text()
old = "boundary%top_advective_available = .false."
new = "boundary%top_advective_available = .true."
if s.count(old) != 1:
    raise SystemExit('top advective mutation anchor mismatch')
p.write_text(s.replace(old, new))
PY
run_expected_failure "top_advective_broadening" "top advective fail-closed projection missing"

echo 'F_VQ90_INDEPENDENT_QUALIFICATION=PASS'
echo "F_VQ90_QUALIFIED_OWNER=$OWNER"
echo "F_VQ90_BRANCH=$QUAL_BRANCH"
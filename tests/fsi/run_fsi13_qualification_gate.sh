#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FSI12_HEAD="3dacdb03503a5ac5f6ce3fe86a55612e9b08a46d"
BUILD="${TMPDIR:-/tmp}/swap5-fsi13-qualification-$$"
REG="$BUILD/fsi12"
mkdir -p "$BUILD"
cleanup() {
  if git -C "$ROOT" worktree list --porcelain | grep -Fq "worktree $REG"; then
    git -C "$ROOT" worktree remove --force "$REG" >/dev/null 2>&1 || true
  fi
  rm -rf "$BUILD"
}
trap cleanup EXIT
cd "$ROOT"

OWNER="$ROOT/integration/f-si/F-SI13_BOTTOM_BOUNDARY_CONTRACT.json"
HEADCALC="$ROOT/src/legacy/b1_10_port/headcalc.f90"
ADAPTER="$ROOT/src/adapter/mod_reference_richards_legacy_binding.f90"

changed_src="$(git diff --name-only "$FSI12_HEAD"...HEAD -- src | sort)"
expected_src=$'src/adapter/mod_reference_richards_legacy_binding.f90\nsrc/legacy/b1_10_port/headcalc.f90'
if [[ "$changed_src" != "$expected_src" ]]; then
  echo 'F-SI13_SCOPE FAIL unexpected production-source delta:' >&2
  printf '%s\n' "$changed_src" >&2
  exit 1
fi
for path in \
  src/runtime/mod_a23bu_worker_execution_context.f90 \
  src/transaction/mod_transaction_reference.f90 \
  src/solver/mod_soil_water_solver_contract.f90 \
  src/solver/mod_reference_richards_workspace.f90 \
  src/solver/mod_reference_richards_state_binding.f90 \
  src/solver/mod_b110_default_mvg_provider.f90 \
  src/solver/mod_b110_source_sink_provider.f90 \
  src/solver/mod_b110_root_sink_provider.f90; do
  [[ "$(git rev-parse "$FSI12_HEAD:$path")" == "$(git rev-parse "HEAD:$path")" ]] || {
    echo "F-SI13_PROTECTED_SOURCE FAIL changed $path" >&2; exit 1; }
done

python3 - "$OWNER" "$HEADCALC" "$ADAPTER" <<'PY'
import json,pathlib,sys
owner=json.loads(pathlib.Path(sys.argv[1]).read_text())
h=pathlib.Path(sys.argv[2]).read_text().lower()
a=pathlib.Path(sys.argv[3]).read_text().lower()
assert owner['basis']['fsi12_qualification_artifact_head']=='3dacdb03503a5ac5f6ce3fe86a55612e9b08a46d'
assert owner['basis']['fkt_fsi_boundary_blob']=='ee1a153c30bbae9416ce08414e8b56049d3d14db'
assert owner['basis']['shared_fkt_type_change_required'] is False
assert owner['implementation_contract']['formula_change'] is False
assert owner['implementation_contract']['policy_change'] is False
assert owner['implementation_contract']['transaction_change'] is False
for token in [
    'legacy_swbotb => swbotb',
    'integer                          :: swbotb, swkimpl, swkmean, maxit, maxbacktr',
    'swbotb = legacy_swbotb',
    "if (.not. present(boundary_conditions)) error stop 'headcalc: explicit boundary conditions required'",
    'swbotb = boundary_conditions%bottom_mode']:
    assert token in h, token
for token in [
    'if (request%boundary%bottom_mode /= 7 .and. request%boundary%bottom_mode /= -2) then',
    "route = 'legacy-bottom-mode-deferred'"]:
    assert token in a, token
assert 'legacy-bottom-mode-mismatch' not in a
print('F-SI13_STATIC_BOTTOM_MODE_BINDING PASS')
PY

bash tests/fsi/run_fsi13_bottom_mode_authority_gate.sh
echo 'F-SI13_REQUEST_BOTTOM_MODE_AUTHORITY PASS'

bash tests/fsi/run_fsi13_bottom_mode_reject_gate.sh
echo 'F-SI13_UNSUPPORTED_BOTTOM_MODE_REJECTION PASS'

bash tests/fsi/run_fsi13_legacy_direct_identity_gate.sh
echo 'F-SI13_LEGACY_DIRECT_COMPATIBILITY PASS'

# The swkimpl=1 request hold remains executable on the current adapter.
bash tests/fsi/run_fsi11_swkimpl1_reject_gate.sh >/dev/null
echo 'F-SI13_SWKIMPL1_HOLD PRESERVED'

# Exact F-SI12 qualification, evaluated in its own pinned source tree.
git worktree add --detach "$REG" "$FSI12_HEAD" >/dev/null
(
  cd "$REG"
  bash tests/fsi/run_fsi12_qualification_gate.sh >/dev/null
)
git worktree remove --force "$REG" >/dev/null
echo 'F-SI13_FSI12_PINNED_REGRESSION PASS'

bash tests/fci/run_fci03_gate.sh >/dev/null
echo 'F-SI13_FKT_BOUNDARY_REGRESSION PASS'

echo 'F-SI13_EXPLICIT_BOTTOM_MODE_FREE_DRAINAGE QUALIFIED_CANDIDATE'
echo 'F-SI13_BOTTOM_MODES_1_3_5_8_9 NOT_ADMITTED'
echo 'F-SI13_SWKIMPL1 NOT_ADMITTED'
echo 'F-SI13_MACROPORE NOT_ADMITTED'
echo 'F-SI13_PARALLEL_REFERENCE_BACKEND NOT_ADMITTED'
echo 'F-SI13_QUALIFICATION_GATE PASS'

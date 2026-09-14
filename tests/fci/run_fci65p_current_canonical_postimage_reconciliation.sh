#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-fci65p-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail(){ echo "FCI65P_POSTIMAGE_GATE_FAIL $*" >&2; exit 165; }

PRE="0b7ad240c005d84373b06ee5304edde779cf6e34"
ADMISSION="5f03312d38c74786c60eea50dad8a6695edca247"
POSTIMAGE="24b02660a7924323d1587b4adf77a160c9ef7d04"
POSTIMAGE_TREE="fd14037490b62750e133eacb3d429de2b06f7f9a"
OWNER="194487ec18374ef6097e3dd687038e326f818be8"
VQ86="0fea1f7a17ccff9f41b4d2dee71feab526313a01"
FGC21_OWNER="1da854e4dd2d45fe388ee2a1ef3bd67c76d3d73f"
VQ_ORACLE_SHA="c6a4fa3855924125a966356a737703bee65df5bd66c84af4c0df6de8ffc6c144"
CANONICAL_WORKFLOW=".github/workflows/fci-canonical.yml"
STATUS="integration/f-ci/F-CI65P_STATUS.json"
VQ_TEST="tests/qualification/fvq86/test_fvq86_fgc24_independent.f90"

declare -A BLOBS=(
  [src/runtime/mod_groundwater_coupled_restart.f90]=0596933ff3ae89c61ab7a0913189a4fa3179e50b
  [src/runtime/mod_groundwater_exchange_service_contract.f90]=e99ae052fccd9992b76c12a91422a987dce059e2
  [src/runtime/mod_groundwater_interface_mass_ledger.f90]=a867e04b088f61f686f693d07e470c3e9c33bdec
)

for object in "$PRE" "$ADMISSION" "$POSTIMAGE" "$OWNER" "$VQ86" "$FGC21_OWNER"; do
  git cat-file -e "$object^{commit}" || fail "missing authority $object"
done
[[ "$(git rev-parse "$POSTIMAGE^1")" == "$PRE" ]] || fail 'postimage first parent mismatch'
[[ "$(git rev-parse "$POSTIMAGE^2")" == "$ADMISSION" ]] || fail 'postimage second parent mismatch'
[[ "$(git rev-list --parents -n1 "$POSTIMAGE" | awk '{print NF-1}')" -eq 2 ]] || fail 'F-CI65 promotion is not a true two-parent merge'
[[ "$(git rev-parse "$POSTIMAGE^{tree}")" == "$POSTIMAGE_TREE" ]] || fail 'postimage tree mismatch'
[[ "$(git rev-parse "$ADMISSION^{tree}")" == "$POSTIMAGE_TREE" ]] || fail 'promoted tree differs from exact final green F-CI65 tree'
git merge-base --is-ancestor "$POSTIMAGE" HEAD || fail 'reconciliation is not descended from admitted postimage'
LIVE="$(git ls-remote origin refs/heads/integration/f-ci-canonical | awk '{print $1}')"
[[ "$LIVE" == "$POSTIMAGE" ]] || fail "live canonical drift expected=$POSTIMAGE actual=$LIVE"
echo 'FCI65P_TRUE_TWO_PARENT_PROMOTION_AND_LIVE_POSTIMAGE_LOCK=PASS'

for path in "${!BLOBS[@]}"; do
  blob="${BLOBS[$path]}"
  [[ "$(git rev-parse "$POSTIMAGE:$path")" == "$blob" ]] || fail "postimage blob mismatch $path"
  [[ "$(git rev-parse "$VQ86:$path")" == "$blob" ]] || fail "F-VQ86 authority blob mismatch $path"
  [[ "$(git rev-parse "HEAD:$path")" == "$blob" ]] || fail "reconciliation source drift $path"
done
[[ -z "$(git diff --name-only "$POSTIMAGE..HEAD" -- src reference)" ]] || fail 'F-CI65P changes production/reference source'
echo 'FCI65P_EXACT_THREE_CANONICAL_POSTIMAGE_BLOBS=PASS'

allowed=(
  .github/workflows/fci-canonical.yml
  .github/workflows/fci65p-current-canonical-postimage-reconciliation.yml
  integration/f-ci/F-CI65P_STATUS.json
  tests/fci/run_fci65p_current_canonical_postimage_reconciliation.sh
)
mapfile -t changed < <(git diff --name-only "$POSTIMAGE..HEAD")
for path in "${changed[@]}"; do
  ok=0
  for candidate in "${allowed[@]}"; do
    [[ "$path" == "$candidate" ]] && ok=1 && break
  done
  [[ "$ok" -eq 1 ]] || fail "unexpected reconciliation path: $path"
done
echo 'FCI65P_RECONCILIATION_SCOPE_ALLOWLIST=PASS'

grep -Fq "AUTH=$POSTIMAGE" "$CANONICAL_WORKFLOW" || fail 'moving-current authority not advanced to F-CI65 postimage'
! grep -Fq 'AUTH=52d66ba612096184327f58a076ef22bd0119e237' "$CANONICAL_WORKFLOW" || fail 'stale F-CI64 moving-current authority remains active'
for path in "${!BLOBS[@]}"; do
  grep -Fq "$path" "$CANONICAL_WORKFLOW" || fail "F-CI65 source absent from moving dependency surface: $path"
done
grep -Fq 'FCI64_MOVING_ENERGY_LEDGER_OWNED_RECEIPT_PRESERVATION=PASS' "$CANONICAL_WORKFLOW" || fail 'F-CI64 moving preservation marker lost'
grep -Fq 'FCI65_MOVING_FGC24_COUPLED_RESTART_PRESERVATION=PASS' "$CANONICAL_WORKFLOW" || fail 'F-CI65 moving preservation marker absent'
echo 'FCI65P_MOVING_CURRENT_AUTHORITY_RECONCILIATION=PASS'

python3 - "$ADMISSION" "$VQ86" "$STATUS" <<'PY'
import json, pathlib, subprocess, sys
admission, vq, status_path = sys.argv[1:]
def at(commit, path):
    return json.loads(subprocess.check_output(['git','show',f'{commit}:{path}'], text=True))
a=at(admission,'integration/f-ci/F-CI65_STATUS.json')
v=at(vq,'qualification/F-VQ86_STATUS.json')
assert a['decision']=='QUALIFIED_F_CI65_READY_FOR_CANONICAL_PROMOTION'
assert a['ready_for_canonical_promotion'] is True
assert a['canonical_admission'] is False
assert a['postimage_reconciled'] is False
assert a['architecture_invariants']=='30_OF_30_NO_ADVERSE_ADMISSION_DELTA'
assert a['qualification_evidence']['owner_true_process_split_replay']=='PASS'
assert a['qualification_evidence']['independent_fvq86_oracle_O0_O2_identity']=='PASS'
assert a['qualification_evidence']['independent_oracle_sha256']=='c6a4fa3855924125a966356a737703bee65df5bd66c84af4c0df6de8ffc6c144'
assert v['decision']=='QUALIFIED_FOR_F_CI_ADMISSION_REVIEW'
assert v['workflow']['conclusion']=='success'
if pathlib.Path(status_path).exists():
    s=json.loads(pathlib.Path(status_path).read_text())
    assert s['decision']=='QUALIFIED_F_CI65P_CURRENT_CANONICAL_POSTIMAGE_RECONCILIATION'
    assert s['production_canonical_admitted'] is True
    assert s['postimage_reconciled'] is True
    assert s['moving_current_preservation_reconciled'] is True
    assert s['groundwater_coupling_v1_complete'] is False
print('FCI65P_FCI65_AND_FVQ86_AUTHORITY_RECONCILIATION=PASS')
PY

bash tests/fgc/run_fgc24_coupled_restart_split_process_gate.sh >"$BUILD/owner.log" 2>&1 || { cat "$BUILD/owner.log" >&2; fail 'owner split-process replay failed'; }
for marker in \
  'FGC24_TRUE_PROCESS_SPLIT_EQUIVALENCE_O0=PASS' \
  'FGC24_TRUE_PROCESS_SPLIT_EQUIVALENCE_O2=PASS' \
  'FGC24_O0_O2_SIGNATURE_IDENTITY=PASS' \
  'F-GC24 COUPLED RESTART SPLIT-PROCESS GATE PASS'; do
  grep -Fq "$marker" "$BUILD/owner.log" || fail "missing owner marker: $marker"
done
echo 'FCI65P_OWNER_PROMOTED_SPLIT_PROCESS_REPLAY=PASS'

python3 - "$FGC21_OWNER" "$BUILD/fgc21_fixture.f90" <<'PY'
from pathlib import Path
import subprocess,sys
text=subprocess.check_output(['git','show',f'{sys.argv[1]}:tests/fgc/test_fgc21_restricted_predictor_corrector_window.f90'],text=True)
marker='\nprogram test_fgc21_restricted_predictor_corrector_window\n'
assert text.count(marker)==1
Path(sys.argv[2]).write_text(text.split(marker,1)[0]+'\n')
PY
python3 - "$BUILD/fgc24_fixture.f90" <<'PY'
from pathlib import Path
import sys
text=Path('tests/fgc/test_fgc24_coupled_restart_split_process.f90').read_text()
marker='\nprogram test_fgc24_coupled_restart_split_process\n'
assert text.count(marker)==1
Path(sys.argv[1]).write_text(text.split(marker,1)[0]+'\n')
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -Wno-error=compare-reals -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
SOURCES=(
  src/transaction/mod_transaction_reference.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/kernel/mod_kernel_transactions.f90
  src/kernel/mod_kernel_committed_persistence.f90
  src/runtime/mod_groundwater_coupling_contract.f90
  src/runtime/mod_groundwater_coupling_policy.f90
  src/runtime/mod_groundwater_exchange_service_contract.f90
  src/runtime/mod_groundwater_interface_mass_ledger.f90
  src/runtime/mod_groundwater_swap_forcing_adapter.f90
  src/runtime/mod_groundwater_predictor_corrector_window.f90
  src/runtime/mod_groundwater_coupled_restart.f90
)
for opt in 0 2; do
  dir="$BUILD/o$opt"; mkdir -p "$dir"; : >"$dir/compiler.txt"
  if ! gfortran "${COMMON[@]}" -O"$opt" -J "$dir" -I "$dir" \
      "${SOURCES[@]}" "$BUILD/fgc21_fixture.f90" "$BUILD/fgc24_fixture.f90" "$VQ_TEST" \
      -o "$dir/test" 2>"$dir/compiler.txt"; then
    cat "$dir/compiler.txt" >&2; fail "independent oracle compile O$opt"
  fi
  if grep -E 'Warning:' "$dir/compiler.txt" | grep -v -F '[-Wcompare-reals]'; then
    cat "$dir/compiler.txt" >&2; fail "unexpected non-compare-real warning O$opt"
  fi
  "$dir/test" oracle >"$dir/oracle.log" 2>&1 || { cat "$dir/oracle.log" >&2; fail "independent oracle O$opt"; }
  for marker in \
    'FVQ86_PREPARED_RESERVATION_FAIL_CLOSED=PASS' \
    'FVQ86_PROVENANCE_AND_LAYOUT_PREPUBLICATION_REJECTION=PASS' \
    'FVQ86_ADAPTER_REJECTION_LOCAL_ATOMICITY=PASS' \
    'FVQ86_COMMITTED_RESTORE_EXACTLY_ONCE=PASS' \
    'FVQ86_TRANSIENT_TOKEN_NONRESURRECTION=PASS' \
    'FVQ86_EXACT_INTERFACE_MASS_RESTORE=PASS'; do
    grep -Fq "$marker" "$dir/oracle.log" || fail "missing independent marker O$opt: $marker"
  done
  if "$dir/test" postcondition >"$dir/postcondition.log" 2>&1; then
    fail "fail-hard postcondition unexpectedly returned success O$opt"
  fi
  grep -Fq 'groundwater restart adapter success violated time provenance postcondition' "$dir/postcondition.log" || fail "wrong fail-hard postcondition O$opt"
  echo "FCI65P_INDEPENDENT_PROMOTED_ORACLE_O${opt}=PASS"
done
cmp "$BUILD/o0/oracle.log" "$BUILD/o2/oracle.log" || fail 'independent promoted oracle O0/O2 drift'
actual_sha="$(sha256sum "$BUILD/o0/oracle.log" | awk '{print $1}')"
[[ "$actual_sha" == "$VQ_ORACLE_SHA" ]] || fail "independent oracle hash drift expected=$VQ_ORACLE_SHA actual=$actual_sha"
echo 'FCI65P_INDEPENDENT_PROMOTED_ORACLE_O0_O2_IDENTITY=PASS'
echo "FCI65P_INDEPENDENT_ORACLE_SHA256=$actual_sha"

[[ "$(git rev-parse "$POSTIMAGE^{tree}")" == "$POSTIMAGE_TREE" ]] || fail 'promoted tree changed during gate'
git diff --quiet "$POSTIMAGE..HEAD" -- src reference || fail 'postimage reconciliation mutated production/reference source'
git diff --check "$POSTIMAGE..HEAD"
echo 'FCI65P_ARCHITECTURE_INVARIANTS=30_OF_30_NO_ADVERSE_POSTIMAGE_RECONCILIATION_DELTA'
echo "FCI65P_EXACT_HEAD=$(git rev-parse HEAD)"
echo 'F-CI65P CURRENT-CANONICAL POSTIMAGE RECONCILIATION GATE PASS'

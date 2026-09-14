#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-fci65-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail(){ echo "FCI65_GATE_FAIL $*" >&2; exit 65; }

CANONICAL="0b7ad240c005d84373b06ee5304edde779cf6e34"
CANONICAL_TREE="ea409fe3740cf51a58da856f37bf11d656f83b8d"
OWNER_CLOSEOUT="194487ec18374ef6097e3dd687038e326f818be8"
OWNER_SOURCE="ed919a7039fb446d2248d4faeedbfc3d6735b962"
VQ86="0fea1f7a17ccff9f41b4d2dee71feab526313a01"
FGC21_OWNER="1da854e4dd2d45fe388ee2a1ef3bd67c76d3d73f"
OWNER_BRANCH="work/f-gc24-coupled-restart-split-run-replay-composition"
VQ_BRANCH="qualification/f-vq86-fgc24-coupled-restart-independent-qualification"

RESTART="src/runtime/mod_groundwater_coupled_restart.f90"
SERVICE="src/runtime/mod_groundwater_exchange_service_contract.f90"
LEDGER="src/runtime/mod_groundwater_interface_mass_ledger.f90"
RESTART_BLOB="0596933ff3ae89c61ab7a0913189a4fa3179e50b"
SERVICE_BLOB="e99ae052fccd9992b76c12a91422a987dce059e2"
LEDGER_BLOB="a867e04b088f61f686f693d07e470c3e9c33bdec"
OWNER_RUNNER="tests/fgc/run_fgc24_coupled_restart_split_process_gate.sh"
OWNER_TEST="tests/fgc/test_fgc24_coupled_restart_split_process.f90"
OWNER_RUNNER_BLOB="74b84ec9188b275b0ea359e4b1c16ea24265d889"
OWNER_TEST_BLOB="65d30d471f3b1fbc3ed68ff7505fa9b2d93f3e29"
VQ_TEST="tests/qualification/fvq86/test_fvq86_fgc24_independent.f90"
VQ_TEST_BLOB="eef61fd86e7388cdc06e359b31802f797fb97322"
OWNER_SIGNATURE="09dc47b31a1da67e0596f0a48d218abade183141126e089f99aa0456b904b432"
VQ_ORACLE_SHA="c6a4fa3855924125a966356a737703bee65df5bd66c84af4c0df6de8ffc6c144"

git fetch -q origin \
  "+refs/heads/integration/f-ci-canonical:refs/remotes/origin/integration/f-ci-canonical" \
  "+refs/heads/${OWNER_BRANCH}:refs/remotes/origin/${OWNER_BRANCH}" \
  "+refs/heads/${VQ_BRANCH}:refs/remotes/origin/${VQ_BRANCH}"

live="$(git ls-remote origin refs/heads/integration/f-ci-canonical | awk '{print $1}')"
[[ "$live" == "$CANONICAL" ]] || fail "live canonical drifted: $live"
[[ "$(git rev-parse origin/integration/f-ci-canonical)" == "$CANONICAL" ]] || fail 'fetched canonical mismatch'
[[ "$(git rev-parse "$CANONICAL^{tree}")" == "$CANONICAL_TREE" ]] || fail 'canonical tree mismatch'
[[ "$(git rev-parse "origin/${VQ_BRANCH}")" == "$VQ86" ]] || fail 'F-VQ86 authority branch drift'
git cat-file -e "$OWNER_CLOSEOUT^{commit}" || fail 'owner closeout commit unavailable'
git cat-file -e "$OWNER_SOURCE^{commit}" || fail 'owner source commit unavailable'
git cat-file -e "$VQ86^{commit}" || fail 'F-VQ86 commit unavailable'
git cat-file -e "$FGC21_OWNER^{commit}" || fail 'F-GC21 owner fixture commit unavailable'
git merge-base --is-ancestor "$OWNER_CLOSEOUT" "origin/${OWNER_BRANCH}" || fail 'owner branch no longer contains pinned closeout'
git merge-base --is-ancestor "$OWNER_SOURCE" "$OWNER_CLOSEOUT" || fail 'owner closeout no longer contains qualified source'
[[ "$(git merge-base "$CANONICAL" HEAD)" == "$CANONICAL" ]] || fail 'qualification head is not rooted in frozen canonical'
echo 'FCI65_AUTHORITY_AND_LIVE_CANONICAL_LOCK=PASS'

expected_src=$'src/runtime/mod_groundwater_coupled_restart.f90\nsrc/runtime/mod_groundwater_exchange_service_contract.f90\nsrc/runtime/mod_groundwater_interface_mass_ledger.f90'
changed_src="$(git diff --name-only "$CANONICAL..HEAD" -- src | LC_ALL=C sort)"
[[ "$changed_src" == "$expected_src" ]] || { printf '%s\n' "$changed_src" >&2; fail 'production delta is not exactly the three qualified F-GC24 files'; }
[[ -z "$(git diff --name-only "$CANONICAL..HEAD" -- reference)" ]] || fail 'reference source changed'
for spec in "$RESTART:$RESTART_BLOB" "$SERVICE:$SERVICE_BLOB" "$LEDGER:$LEDGER_BLOB"; do
  path="${spec%%:*}"; blob="${spec##*:}"
  [[ "$(git rev-parse "HEAD:$path")" == "$blob" ]] || fail "qualified HEAD blob drift: $path"
  [[ "$(git rev-parse "$OWNER_SOURCE:$path")" == "$blob" ]] || fail "qualified owner-source blob drift: $path"
done
[[ "$(git rev-parse "HEAD:$OWNER_RUNNER")" == "$OWNER_RUNNER_BLOB" ]] || fail 'owner runner postimage drift'
[[ "$(git rev-parse "HEAD:$OWNER_TEST")" == "$OWNER_TEST_BLOB" ]] || fail 'owner test postimage drift'
[[ "$(git rev-parse "$OWNER_SOURCE:$OWNER_RUNNER")" == "$OWNER_RUNNER_BLOB" ]] || fail 'owner runner authority drift'
[[ "$(git rev-parse "$OWNER_SOURCE:$OWNER_TEST")" == "$OWNER_TEST_BLOB" ]] || fail 'owner test authority drift'
[[ "$(git rev-parse "HEAD:$VQ_TEST")" == "$VQ_TEST_BLOB" ]] || fail 'independent oracle postimage drift'
[[ "$(git rev-parse "$VQ86:$VQ_TEST")" == "$VQ_TEST_BLOB" ]] || fail 'F-VQ86 independent oracle authority drift'
git diff --check "$CANONICAL..HEAD"
echo 'FCI65_EXACT_THREE_FILE_PRODUCTION_POSTIMAGE=PASS'

python3 - "$OWNER_CLOSEOUT" "$VQ86" <<'PY'
import json, subprocess, sys
owner, vq = sys.argv[1:]
def read(commit, path):
    return json.loads(subprocess.check_output(['git','show',f'{commit}:{path}'], text=True))
o=read(owner,'integration/f-gc/F-GC24_COUPLED_RESTART_SPLIT_RUN_REPLAY_CLOSEOUT.json')
v=read(vq,'qualification/F-VQ86_STATUS.json')
assert o['work_unit']=='F-GC24'
assert o['qualified_source_head']['sha']=='ed919a7039fb446d2248d4faeedbfc3d6735b962'
assert o['owner_decision']['status']=='QUALIFIED_COUPLED_RESTART_SPLIT_RUN_REPLAY_COMPOSITION_READY_FOR_INDEPENDENT_QUALIFICATION'
assert o['scope']['canonical_admission_in_scope'] is False
assert v['work_unit']=='F-VQ86'
assert v['decision']=='QUALIFIED_FOR_F_CI_ADMISSION_REVIEW'
assert v['owner_authority']['owner_closeout_head']=='194487ec18374ef6097e3dd687038e326f818be8'
assert v['qualified_source_blobs']['src/runtime/mod_groundwater_coupled_restart.f90']=='0596933ff3ae89c61ab7a0913189a4fa3179e50b'
assert v['qualified_source_blobs']['src/runtime/mod_groundwater_exchange_service_contract.f90']=='e99ae052fccd9992b76c12a91422a987dce059e2'
assert v['qualified_source_blobs']['src/runtime/mod_groundwater_interface_mass_ledger.f90']=='a867e04b088f61f686f693d07e470c3e9c33bdec'
print('FCI65_OWNER_AND_INDEPENDENT_AUTHORITIES=PASS')
PY

python3 - <<'PY'
import json, pathlib
p=json.load(open('integration/f-ci/F-CI65_PRE_REGISTRATION.json'))
a=json.load(open('integration/f-ci/F-CI65_ARCHITECTURE_AUDIT.json'))
assert p['work_unit']=='F-CI65'
assert p['canonical_base']['sha']=='0b7ad240c005d84373b06ee5304edde779cf6e34'
assert p['canonical_base']['tree']=='ea409fe3740cf51a58da856f37bf11d656f83b8d'
assert p['recomposition']['production_defect_established'] is False
assert p['recomposition']['canonical_delta_overlaps_F_GC24_src'] is False
assert len(p['production_scope'])==3
assert p['scope_guards']['new_mass_tolerance'] is False
assert p['scope_guards']['new_kernel_io'] is False
assert p['scope_guards']['groundwater_coupling_v1_complete_claim'] is False
assert a['work_unit']=='F-CI65'
assert len(a['invariants'])==30
assert [x['id'] for x in a['invariants']]==list(range(1,31))
assert all(x['assessment']=='NO_ADVERSE_ADMISSION_DELTA' for x in a['invariants'])
assert a['overall']=='30_OF_30_NO_ADVERSE_ADMISSION_DELTA'
assert a['canonical_admission'] is False
if pathlib.Path('integration/f-ci/F-CI65_STATUS.json').exists():
    s=json.load(open('integration/f-ci/F-CI65_STATUS.json'))
    assert s['work_unit']=='F-CI65'
    assert s['decision']=='QUALIFIED_F_CI65_READY_FOR_CANONICAL_PROMOTION'
    assert s['canonical_admission'] is False
    assert s['postimage_reconciled'] is False
print('FCI65_GOVERNANCE_AND_30_INVARIANTS=PASS')
PY

python3 - <<'PY'
from pathlib import Path
restart=Path('src/runtime/mod_groundwater_coupled_restart.f90').read_text().lower()
service=Path('src/runtime/mod_groundwater_exchange_service_contract.f90').read_text().lower()
ledger=Path('src/runtime/mod_groundwater_interface_mass_ledger.f90').read_text().lower()
record=restart.split('type, public :: groundwater_coupled_restart_record_t',1)[1].split('end type groundwater_coupled_restart_record_t',1)[0]
for forbidden in ('checkpoint','candidate','prepared','newton','jacobian','path','file_unit'):
    assert forbidden not in record, forbidden
assert 'class(transaction_state_t), allocatable :: swap_physical_state' in record
assert 'type(groundwater_committed_restart_record_t) :: groundwater' in record
assert 'type(groundwater_interface_mass_restart_record_t) :: ledger' in record
assert 'type(groundwater_coupling_origin_t) :: origin' in record
ledger_record=ledger.split('type, public :: groundwater_interface_mass_restart_record_t',1)[1].split('end type groundwater_interface_mass_restart_record_t',1)[0]
assert 'committed_swap_outward_exchange_m' in ledger_record
assert 'committed_exchange_count' in ledger_record
for forbidden in ('trial_exchange_m','prepared_generation','prepared_active'):
    assert forbidden not in ledger_record, forbidden
assert 'procedure, public :: restart_quiescent' in service
assert restart.count('service%restart_quiescent()') >= 2
assert "error stop 'groundwater restart adapter success violated quiescent postcondition'" in restart
assert "error stop 'groundwater restart adapter success violated time provenance postcondition'" in restart
for forbidden in ('.swp','midnight','86400','modflow'):
    assert forbidden not in restart, forbidden
compact=restart.replace(' ','')
for forbidden in ('open(','read(','write('):
    assert forbidden not in compact, forbidden
print('FCI65_COMMITTED_ONLY_QUIESCENCE_AND_NO_IO_STATIC_AUDIT=PASS')
PY

bash "$OWNER_RUNNER" >"$BUILD/owner.log" 2>&1 || { cat "$BUILD/owner.log" >&2; fail 'owner split-process replay failed'; }
for marker in \
  'FGC24_TRUE_PROCESS_SPLIT_EQUIVALENCE_O0=PASS' \
  'FGC24_TRUE_PROCESS_SPLIT_EQUIVALENCE_O2=PASS' \
  'FGC24_O0_O2_SIGNATURE_IDENTITY=PASS' \
  'F-GC24 COUPLED RESTART SPLIT-PROCESS GATE PASS'; do
  grep -Fq "$marker" "$BUILD/owner.log" || fail "missing owner replay marker: $marker"
done
grep -Fq "FGC24_SIGNATURE_SHA256_O0=$OWNER_SIGNATURE" "$BUILD/owner.log" || fail 'owner O0 signature drift'
grep -Fq "FGC24_SIGNATURE_SHA256_O2=$OWNER_SIGNATURE" "$BUILD/owner.log" || fail 'owner O2 signature drift'
echo 'FCI65_OWNER_TRUE_PROCESS_SPLIT_REPLAY=PASS'

python3 - "$FGC21_OWNER" "$BUILD/fgc21_fixture.f90" <<'PY'
from pathlib import Path
import subprocess, sys
commit=sys.argv[1]; out=Path(sys.argv[2])
text=subprocess.check_output(['git','show',f'{commit}:tests/fgc/test_fgc21_restricted_predictor_corrector_window.f90'], text=True)
marker='\nprogram test_fgc21_restricted_predictor_corrector_window\n'
assert text.count(marker)==1
out.write_text(text.split(marker,1)[0]+'\n')
PY
python3 - "$OWNER_CLOSEOUT" "$BUILD/fgc24_fixture.f90" <<'PY'
from pathlib import Path
import subprocess, sys
commit=sys.argv[1]; out=Path(sys.argv[2])
text=subprocess.check_output(['git','show',f'{commit}:tests/fgc/test_fgc24_coupled_restart_split_process.f90'], text=True)
marker='\nprogram test_fgc24_coupled_restart_split_process\n'
assert text.count(marker)==1
out.write_text(text.split(marker,1)[0]+'\n')
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
  dir="$BUILD/vq-o$opt"; mkdir -p "$dir"; : >"$dir/compiler.txt"
  if ! gfortran "${COMMON[@]}" -O"$opt" -J "$dir" -I "$dir" \
      "${SOURCES[@]}" "$BUILD/fgc21_fixture.f90" "$BUILD/fgc24_fixture.f90" \
      "$VQ_TEST" -o "$dir/test" 2>"$dir/compiler.txt"; then
    cat "$dir/compiler.txt" >&2; fail "independent oracle compile O$opt"
  fi
  if grep -E 'Warning:' "$dir/compiler.txt" | grep -v -F '[-Wcompare-reals]'; then
    cat "$dir/compiler.txt" >&2; fail "unexpected independent-oracle warning O$opt"
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
  echo "FCI65_INDEPENDENT_FVQ86_ORACLE_O${opt}=PASS"
done
cmp "$BUILD/vq-o0/oracle.log" "$BUILD/vq-o2/oracle.log" || fail 'independent oracle O0/O2 drift'
actual_sha="$(sha256sum "$BUILD/vq-o0/oracle.log" | awk '{print $1}')"
[[ "$actual_sha" == "$VQ_ORACLE_SHA" ]] || fail "independent oracle hash drift: $actual_sha"
echo 'FCI65_INDEPENDENT_FVQ86_ORACLE_O0_O2_IDENTITY=PASS'
echo "FCI65_INDEPENDENT_ORACLE_SHA256=$actual_sha"
echo 'F-CI65 F-GC24 CURRENT-CANONICAL ADMISSION GATE PASS'

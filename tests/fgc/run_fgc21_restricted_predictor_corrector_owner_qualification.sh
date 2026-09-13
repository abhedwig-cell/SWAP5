#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

RESTART=2a0db2524fba6e258316ce82630c60ea1c9c673a
IMPLEMENTATION=0ba31e5e6ab6702dfd6ddc76aba71e7162d80947
GOVERNANCE=09ef05c60c5e45af218980001c8ad8ec30da2e9e
FGC17_BLOB=fc598d14eabafcb025bb55621f7b00d6d1816f10
FGC18_OWNER=cfa4e9dcd9a283d85ade316651d34cac93958a4a
FGC18_BLOB=f0fc25592624360802713a9487813d119e7dc4e9
FGC19_OWNER=3bf3fec344ee67dd56f5f54b293b3a0a47214efb
FGC19_BLOB=d37f1926dafde9d941939cf4147d799cb7478bfc
FGC21P1_R1=15028b926a5bbe9b82086a62168708451d165ecb
FVQ63=0926552c9db8658014920fd6710fac4277bcffe0
ORCH=src/runtime/mod_groundwater_predictor_corrector_window.f90
ADAPTER=src/runtime/mod_groundwater_swap_forcing_adapter.f90
FMR_ADAPTER=src/runtime/mod_fmr_groundwater_head_forcing_adapter.f90
OWNER_TEST=tests/fgc/test_fgc21_restricted_predictor_corrector_window.f90

# Frozen restart and implementation lineage.
git merge-base --is-ancestor "$RESTART" HEAD
git merge-base --is-ancestor "$IMPLEMENTATION" HEAD
test "$(git rev-parse "$IMPLEMENTATION:$ORCH")" = "$(git rev-parse "HEAD:$ORCH")"
test "$(git rev-parse "$IMPLEMENTATION:$ADAPTER")" = "$(git rev-parse "HEAD:$ADAPTER")"
test "$(git rev-parse "$IMPLEMENTATION:$FMR_ADAPTER")" = "$(git rev-parse "HEAD:$FMR_ADAPTER")"
test "$(git rev-parse "$IMPLEMENTATION:$OWNER_TEST")" = "$(git rev-parse "HEAD:$OWNER_TEST")"
test "$(git rev-parse HEAD:src/runtime/mod_groundwater_coupling_contract.f90)" = "$FGC17_BLOB"
test "$(git rev-parse HEAD:src/runtime/mod_groundwater_exchange_service_contract.f90)" = "$FGC18_BLOB"
test "$(git rev-parse HEAD:src/runtime/mod_groundwater_interface_mass_ledger.f90)" = "$FGC19_BLOB"
git cat-file -e "$GOVERNANCE^{commit}"
git cat-file -e "$FGC21P1_R1^{commit}"
git cat-file -e "$FVQ63^{commit}"
echo 'FGC21_AUTHORITY_LOCKS=PASS'

allowed=(
  integration/f-gc/F-GC21_PRE_REGISTRATION.json
  "$ORCH"
  "$ADAPTER"
  "$FMR_ADAPTER"
  "$OWNER_TEST"
  tests/fgc/run_fgc21_restricted_predictor_corrector_owner_qualification.sh
  .github/workflows/fgc21-restricted-predictor-corrector-owner-qualification.yml
  integration/f-gc/F-GC21_ARCHITECTURE_AUDIT.json
  integration/f-gc/F-GC21_STATUS.json
)
mapfile -t changed < <(git diff --name-only "$RESTART..HEAD")
for path in "${changed[@]}"; do
  ok=0
  for candidate in "${allowed[@]}"; do [[ "$path" == "$candidate" ]] && ok=1 && break; done
  [[ "$ok" -eq 1 ]] || { echo "FGC21_SCOPE_FAIL unexpected path: $path" >&2; exit 20; }
done
echo 'FGC21_SCOPE_ALLOWLIST=PASS'

python3 - <<'PY'
from pathlib import Path
p=Path('src/runtime/mod_groundwater_predictor_corrector_window.f90').read_text()
a=Path('src/runtime/mod_groundwater_swap_forcing_adapter.f90').read_text()
f=Path('src/runtime/mod_fmr_groundwater_head_forcing_adapter.f90').read_text()
low='\n'.join([p,a,f]).lower()
for forbidden in ['.swp','midnight','headcalc%','file unit','open(','read(','write(']:
    assert forbidden not in low, forbidden
for forbidden in ['modflow','86400']:
    assert forbidden not in p.lower(), ('orchestrator',forbidden)
assert 'checkpoint=swap_checkpoint' in p
assert p.count('checkpoint=swap_checkpoint') == 2
assert 'call rollback_swap_candidate(executor, predictor_swap_candidate' in p
assert 'call ledger%stage_exchange' in p
assert 'call groundwater_prepare_candidate' in p
assert 'call ledger%prepare_trial' in p
assert 'publication_preflight' in p
assert 'call executor%commit_candidate' in p
assert 'call groundwater_commit_prepared' in p
assert 'call ledger%commit_prepared' in p
assert 'error stop \'F-GC21 atomic publication invariant:' in p
assert 'error stop \'F-GC21 hard mass invariant:' in p
assert 'abs(result%residual%flux_residual_m_per_s) > 0.0_real64' in p
assert 'qbot_mean_cm_per_day = -exchange_cm / duration_day' in p
assert 'pair_groundwater_flux_from_swap' in p
assert 'result%corrector_swap_outward_exchange_cm * CM_TO_M' in p
assert 'ledger%has_identity()' in p
assert 'ledger%has_active_trial()' in p
assert 'ledger%has_prepared_trial()' in p
# All recoverable F-GC21 failures occur before the first successful SWAP publication.
pos_swap=p.index('call executor%commit_candidate')
pos_gw=p.index('call groundwater_commit_prepared')
pos_ledger=p.index('call ledger%commit_prepared')
assert pos_swap < pos_gw < pos_ledger
post=p[pos_gw:]
assert 'call fail_result' not in post
assert 'error stop' in post
# Stage/prepare defensive branches explicitly clean both physical candidates before returning.
stage=p[p.index('call ledger%stage_exchange'):p.index('call groundwater_prepare_candidate')]
assert 'discard_corrector_candidates' in stage and 'GW_PC_LEDGER_STAGE_FAILED' in stage
prep=p[p.index('call ledger%prepare_trial'):p.index('call make_next_origin')]
assert 'groundwater_abort_prepared' in prep and 'rollback_swap_candidate' in prep
assert 'GW_PC_LEDGER_PREPARE_FAILED' in prep
# Concrete FMR adapter uses the typed F-GC17 datum conversion; it never reads solver-private head arrays.
assert 'interface_head_m_to_swap_pressure_head_cm' in f
assert 'typed_forcing%bottom_head = pressure_head_cm' in f
for forbidden in ['pressure_head(','headcalc','hnew','hold']:
    assert forbidden not in f.lower(), forbidden
print('FGC21_STATIC_TRANSACTION_ORDER=PASS')
print('FGC21_LEDGER_REJECT_CLEANUP_STATIC=PASS')
print('FGC21_TYPED_HEAD_ADAPTER_STATIC=PASS')
print('FGC21_NO_HIDDEN_IO_CALENDAR_MODFLOW=PASS')
PY

BUILD="${TMPDIR:-/tmp}/swap5-fgc21-owner-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -Wno-error=compare-reals -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
SOURCES=(
  src/transaction/mod_transaction_reference.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/kernel/mod_kernel_transactions.f90
  src/runtime/mod_groundwater_coupling_contract.f90
  src/runtime/mod_groundwater_coupling_policy.f90
  src/runtime/mod_groundwater_exchange_service_contract.f90
  src/runtime/mod_groundwater_interface_mass_ledger.f90
  src/runtime/mod_groundwater_swap_forcing_adapter.f90
  src/runtime/mod_groundwater_predictor_corrector_window.f90
)
compile_and_run() {
  local opt="$1" test_src="$2" tag="$3" out="$4"
  local dir="$BUILD/${tag}-o${opt}"
  mkdir -p "$dir"
  : > "$dir/compiler.txt"
  gfortran "${COMMON[@]}" -O"$opt" -J "$dir" -I "$dir" \
    "${SOURCES[@]}" "$test_src" -o "$dir/test" 2>"$dir/compiler.txt"
  if grep -E 'Warning:' "$dir/compiler.txt" | grep -v -F '[-Wcompare-reals]'; then
    echo "FGC21_UNEXPECTED_WARNING_${tag}_O${opt}" >&2
    cat "$dir/compiler.txt" >&2
    exit 21
  fi
  "$dir/test" > "$out" 2>&1 || { cat "$out" >&2; exit 22; }
}

compile_and_run 0 "$OWNER_TEST" owner "$BUILD/owner-o0.txt"
compile_and_run 2 "$OWNER_TEST" owner "$BUILD/owner-o2.txt"
diff -u "$BUILD/owner-o0.txt" "$BUILD/owner-o2.txt"
grep -q '^F-GC21 OWNER HARNESS PASS$' "$BUILD/owner-o0.txt"
echo 'FGC21_BASE_OWNER_O0_O2_IDENTITY=PASS'

# Reproducibly derive temporary fault-injection variants from the byte-pinned owner test.
python3 - "$OWNER_TEST" "$BUILD" <<'PY'
from pathlib import Path
import sys
src=Path(sys.argv[1]).read_text(); out=Path(sys.argv[2])
old_use=("       run_restricted_groundwater_coupling_window, GW_PC_OK, GW_PC_NOT_CONVERGED, GW_PC_INVALID_ORIGIN, &\n"
         "       GW_PC_PREDICTOR_GROUNDWATER_FAILED")
new_use=("       run_restricted_groundwater_coupling_window, GW_PC_OK, GW_PC_NOT_CONVERGED, GW_PC_INVALID_ORIGIN, &\n"
         "       GW_PC_PREDICTOR_GROUNDWATER_FAILED, GW_PC_INVALID_REQUEST, GW_PC_PREDICTOR_SWAP_FAILED, &\n"
         "       GW_PC_CORRECTOR_SWAP_FAILED, GW_PC_CORRECTOR_GROUNDWATER_FAILED, GW_PC_GROUNDWATER_PREPARE_FAILED")
assert src.count(old_use)==1
base=src.replace(old_use,new_use)

def block(text,name):
    a=f"  subroutine {name}(failures)\n"; b=f"  end subroutine {name}\n"
    i=text.index(a); j=text.index(b,i)+len(b)
    return i,j,text[i:j]
def rewrite(name,repls,model_fail=None):
    text=base
    if model_fail is not None:
        text=text.replace('    integer :: advance_count = 0\n',
                          '    integer :: advance_count = 0\n    integer :: fail_advance_number = 0\n',1)
        needle='    self%advance_count = self%advance_count + 1\n    if (.not. self%configured .or. t1 <= t0) return\n'
        repl=('    self%advance_count = self%advance_count + 1\n'
              '    if (self%fail_advance_number > 0 .and. self%advance_count >= self%fail_advance_number) return\n'
              '    if (.not. self%configured .or. t1 <= t0) return\n')
        assert text.count(needle)==1; text=text.replace(needle,repl,1)
    i,j,b=block(text,name)
    for old,new in repls:
        assert b.count(old)==1,(name,old,b.count(old)); b=b.replace(old,new,1)
    text=text[:i]+b+text[j:]
    return text

variants={
'invalid-request': rewrite('test_stale_origin_fails_before_trials',[
 ('    origin%swap_revision = 99_int64','    window%t1 = window%t0'),
 ('result%status == GW_PC_INVALID_ORIGIN','result%status == GW_PC_INVALID_REQUEST')]),
'corrector-groundwater': rewrite('test_predictor_groundwater_rejection_is_fail_closed',[
 ('groundwater%fail_trial_number = 1','groundwater%fail_trial_number = 2'),
 ('GW_PC_PREDICTOR_GROUNDWATER_FAILED','GW_PC_CORRECTOR_GROUNDWATER_FAILED'),
 ('model%advance_count == 1','model%advance_count == 2'),
 ('groundwater%trial_count == 0','groundwater%trial_count == 1')]),
'groundwater-prepare': rewrite('test_predictor_groundwater_rejection_is_fail_closed',[
 ('groundwater%fail_trial_number = 1','groundwater%fail_prepare = .true.'),
 ('GW_PC_PREDICTOR_GROUNDWATER_FAILED','GW_PC_GROUNDWATER_PREPARE_FAILED'),
 ('model%advance_count == 1','model%advance_count == 2'),
 ('groundwater%trial_count == 0','groundwater%trial_count == 2')]),
'predictor-swap': rewrite('test_predictor_groundwater_rejection_is_fail_closed',[
 ('groundwater%fail_trial_number = 1','model%fail_advance_number = 1'),
 ('GW_PC_PREDICTOR_GROUNDWATER_FAILED','GW_PC_PREDICTOR_SWAP_FAILED'),
 ('model%advance_count == 1','model%advance_count >= 1')],model_fail=1),
'corrector-swap': rewrite('test_predictor_groundwater_rejection_is_fail_closed',[
 ('groundwater%fail_trial_number = 1','model%fail_advance_number = 2'),
 ('GW_PC_PREDICTOR_GROUNDWATER_FAILED','GW_PC_CORRECTOR_SWAP_FAILED'),
 ('model%advance_count == 1','model%advance_count >= 2'),
 ('groundwater%trial_count == 0','groundwater%trial_count == 1')],model_fail=2),
}
for name,text in variants.items():
    (out/f'{name}.f90').write_text(text)
print('FGC21_TEMPORARY_FAILURE_VARIANTS_DERIVED=PASS')
PY

for variant in invalid-request corrector-groundwater groundwater-prepare predictor-swap corrector-swap; do
  compile_and_run 0 "$BUILD/$variant.f90" "$variant" "$BUILD/$variant-o0.txt"
  compile_and_run 2 "$BUILD/$variant.f90" "$variant" "$BUILD/$variant-o2.txt"
  diff -u "$BUILD/$variant-o0.txt" "$BUILD/$variant-o2.txt"
  grep -q '^F-GC21 OWNER HARNESS PASS$' "$BUILD/$variant-o0.txt"
  echo "FGC21_FAILURE_VARIANT_${variant^^}=PASS"
done

# Re-run the frozen P1 exact accepted whole-window exchange regression against current source.
git show "$FGC21P1_R1:tests/fgc/test_fgc21p1_exact_bottom_interface_result.f90" > "$BUILD/test_p1.f90"
for opt in 0 2; do
  dir="$BUILD/p1-o$opt"; mkdir -p "$dir"
  gfortran "${COMMON[@]}" -O"$opt" -J "$dir" -I "$dir" \
    src/transaction/mod_transaction_reference.f90 \
    src/runtime/mod_canonical_contracts.f90 \
    src/runtime/mod_canonical_interval_runtime.f90 \
    "$BUILD/test_p1.f90" -o "$dir/test" 2>"$dir/compiler.txt"
  if grep -E 'Warning:' "$dir/compiler.txt" | grep -v -F '[-Wcompare-reals]'; then cat "$dir/compiler.txt" >&2; exit 23; fi
  "$dir/test" > "$BUILD/p1-o$opt.txt"
done
diff -u "$BUILD/p1-o0.txt" "$BUILD/p1-o2.txt"
grep -Eq '^[[:space:]]*FGC21P1_EXACT_BOTTOM_INTERFACE_RESULT_TEST PASS$' "$BUILD/p1-o0.txt"
echo 'FGC21_P1_EXACT_EXCHANGE_REGRESSION=PASS'

# Re-run admitted prepared-handle ownership/replay/exhaustion components against current production blobs.
git show "$FGC18_OWNER:tests/fgc/test_fgc18r_prepared_commit.f90" > "$BUILD/test_fgc18r.f90"
for opt in 0 2; do
  dir="$BUILD/fgc18r-o$opt"; mkdir -p "$dir"
  gfortran "${COMMON[@]}" -O"$opt" -J "$dir" -I "$dir" \
    src/runtime/mod_groundwater_coupling_contract.f90 \
    src/runtime/mod_groundwater_exchange_service_contract.f90 \
    "$BUILD/test_fgc18r.f90" -o "$dir/test" 2>"$dir/compiler.txt"
  "$dir/test" > "$BUILD/fgc18r-o$opt.txt"
done
diff -u "$BUILD/fgc18r-o0.txt" "$BUILD/fgc18r-o2.txt"
for marker in FGC18R_STALE_PREPARE_REJECTED FGC18R_COPIED_ABORT_REPLAY_REJECTED FGC18R_COPIED_COMMIT_REPLAY_REJECTED FGC18R_REVISION_INT64_BOUNDARY_FAIL_CLOSED FGC18R_NO_RECOVERABLE_FINAL_COMMIT_STATUS; do
  grep -q "^${marker}=PASS$" "$BUILD/fgc18r-o0.txt"
done
echo 'FGC21_GROUNDWATER_PREPARED_COMPONENT_REGRESSION=PASS'

git show "$FGC19_OWNER:tests/fgc/test_fgc19r_r1_prepared_ledger_provenance.f90" > "$BUILD/test_fgc19r.f90"
for opt in 0 2; do
  dir="$BUILD/fgc19r-o$opt"; mkdir -p "$dir"
  gfortran "${COMMON[@]}" -O"$opt" -J "$dir" -I "$dir" \
    src/runtime/mod_groundwater_coupling_contract.f90 \
    src/runtime/mod_groundwater_interface_mass_ledger.f90 \
    "$BUILD/test_fgc19r.f90" -o "$dir/test" 2>"$dir/compiler.txt"
  "$dir/test" > "$BUILD/fgc19r-o$opt.txt"
done
diff -u "$BUILD/fgc19r-o0.txt" "$BUILD/fgc19r-o2.txt"
for marker in FGC19R_R1_EXPLICIT_LEDGER_IDENTITY FGC19R_R1_FOREIGN_HANDLE_REJECTION FGC19R_R1_SAME_LEDGER_REPLAY_REJECTION FGC19R_R1_ABORT_MASS_PRESERVATION FGC19R_R1_EXACT_ACTION_REACTION; do
  grep -q "^${marker}=PASS$" "$BUILD/fgc19r-o0.txt"
done
# Exhaustion is guarded before prepared publication in the admitted production source.
grep -Fq 'self%committed_exchange_count >= huge(self%committed_exchange_count)' src/runtime/mod_groundwater_interface_mass_ledger.f90
grep -Fq 'self%preparation_generation >= huge(self%preparation_generation)' src/runtime/mod_groundwater_interface_mass_ledger.f90
grep -Fq 'safe_revision_successor' src/runtime/mod_groundwater_exchange_service_contract.f90
echo 'FGC21_LEDGER_PREPARED_COMPONENT_REGRESSION=PASS'
echo 'FGC21_EXHAUSTION_PREFLIGHT_GUARDS=PASS'

python3 - <<'PY'
import json
p='integration/f-gc/F-GC21_ARCHITECTURE_AUDIT.json'
d=json.load(open(p))
assert d['overall']=='30_OF_30_NO_ADVERSE_DELTA_OWNER_RESTRICTED_PC_ORCHESTRATOR'
assert d['mass_conservation']=='HARD_EXACT_ACTION_REACTION_AND_ACCEPTED_EXCHANGE_LEDGER'
assert [x['id'] for x in d['invariants']]==list(range(1,31))
assert all(x['status']=='PASS' for x in d['invariants'])
PY
echo 'FGC21_ARCHITECTURE_30_OF_30=PASS'

cat "$BUILD/owner-o0.txt"
echo "FGC21_OWNER_OUTPUT_SHA256=$(sha256sum "$BUILD/owner-o0.txt" | cut -d' ' -f1)"
echo 'FGC21_OWNER_QUALIFICATION_GATE PASS'

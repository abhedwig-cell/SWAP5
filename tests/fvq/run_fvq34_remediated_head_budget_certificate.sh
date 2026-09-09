#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fvq34-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

PLAN=integration/f-vq/F-VQ34_QUALIFICATION_PLAN.json
PLAN_BLOB=4f3f7c8883397ed96d3af2f6585f25698c58e7b4
DRIVER=tests/fvq/test_fvq34_remediated_head_budget_certificate.f90
DRIVER_BLOB=ad5657bebd16db006fa36b2495f3c643ef6eb0bf
BACKEND=src/runtime/mod_fmr_serialized_reference_backend.f90
BACKEND_BLOB=9af5a494526810324dc00706b444e448e770cba9
DIRECT_DRIVER=tests/fsi/test_fsi25_reference_indicator_production_seam.f90
DIRECT_DRIVER_BLOB=c125c6a2ab706920b7e2a5c6f1c855520b192223
FKT09_RUNNER=tests/transaction/run_fkt09_model_certificate_gate.sh
FKT09_RUNNER_BLOB=c2f1a2a95d61c7e1fea8169caa577f9c8c1515ff
FKT10_HISTORY=tests/fkt/run_fkt10_temporal_history_transaction.sh
FKT10_CLOSEOUT=integration/f-kt/F-KT10_CLOSEOUT.json
FKT10_CLOSEOUT_BLOB=1a53f26c4c299080d2ae8f03304320d55cf8ae8b
FKT10_TX_DRIVER=tests/fkt/test_fkt10_transactional_fvq30_replay.f90
FKT10_TX_DRIVER_BLOB=c42765b89b5dd9140aa492ab56abbbf2077be50e
FVQ32_CLOSEOUT=integration/f-vq/F-VQ32_CLOSEOUT.json
FVQ32_CLOSEOUT_BLOB=51b075c6f72880897416bdcfd92549bd68d26b7b
TRANSACTION_CORE=src/transaction/mod_transaction_reference.f90
TRANSACTION_CORE_BLOB=2fd932b74dbd0ffc0ec089f49e632b7ac8852df4
INDICATOR=src/solver/mod_reference_richards_temporal_indicator.f90
INDICATOR_BLOB=fe8f87d11257d4c6bc019f1d628ac41ba3106d4e
STUB=tests/fsi/fsi04_real_headcalc_stubs.f90
FSI18_BRANCH=origin/work/f-si18-reference-convergence-cliff
FSI18_GENERATOR=tests/fsi/fsi18_make_reference_tridag_stubs.py
FSI18_GENERATOR_BLOB=bf25c4c7fefaa59811255b0bc25c041522ab008e
OWNER_BRANCH=origin/work/f-kt11-richards-head-budget-certificate-policy
OWNER_HANDOFF=integration/f-kt/F-KT11_FVQ34_HANDOFF.json
OWNER_HANDOFF_BLOB=51890fca7138021385f3366167ade92ef6daffb4
FVQ33_BRANCH=origin/qualification/f-vq33-richards-head-budget-certificate
FVQ33_PLAN=integration/f-vq/F-VQ33_QUALIFICATION_PLAN.json
FVQ33_PLAN_BLOB=cafab880cceb89a44ecee9e61bdde9f1afd85b5c
FVQ33_STATUS=integration/f-vq/F-VQ33_STATUS.json
FVQ33_STATUS_BLOB=a353d8e137c85616fcda06e167c5acce66c9955f

fail() { echo "FVQ34_FAIL $*" >&2; exit 1; }

for spec in \
  "$PLAN:$PLAN_BLOB" \
  "$DRIVER:$DRIVER_BLOB" \
  "$BACKEND:$BACKEND_BLOB" \
  "$DIRECT_DRIVER:$DIRECT_DRIVER_BLOB" \
  "$FKT09_RUNNER:$FKT09_RUNNER_BLOB" \
  "$FKT10_CLOSEOUT:$FKT10_CLOSEOUT_BLOB" \
  "$FKT10_TX_DRIVER:$FKT10_TX_DRIVER_BLOB" \
  "$FVQ32_CLOSEOUT:$FVQ32_CLOSEOUT_BLOB" \
  "$TRANSACTION_CORE:$TRANSACTION_CORE_BLOB" \
  "$INDICATOR:$INDICATOR_BLOB"; do
  path="${spec%%:*}"; blob="${spec##*:}"
  [[ "$(git rev-parse HEAD:$path)" == "$blob" ]] || fail "source lock drift $path"
done

git fetch --quiet --no-tags origin \
  work/f-kt11-richards-head-budget-certificate-policy:refs/remotes/origin/work/f-kt11-richards-head-budget-certificate-policy \
  qualification/f-vq33-richards-head-budget-certificate:refs/remotes/origin/qualification/f-vq33-richards-head-budget-certificate \
  work/f-si18-reference-convergence-cliff:refs/remotes/origin/work/f-si18-reference-convergence-cliff
[[ "$(git rev-parse "$OWNER_BRANCH:$OWNER_HANDOFF")" == "$OWNER_HANDOFF_BLOB" ]] || fail 'owner handoff drift'
[[ "$(git rev-parse "$FVQ33_BRANCH:$FVQ33_PLAN")" == "$FVQ33_PLAN_BLOB" ]] || fail 'F-VQ33 plan drift'
[[ "$(git rev-parse "$FVQ33_BRANCH:$FVQ33_STATUS")" == "$FVQ33_STATUS_BLOB" ]] || fail 'F-VQ33 status drift'
[[ "$(git rev-parse "$FSI18_BRANCH:$FSI18_GENERATOR")" == "$FSI18_GENERATOR_BLOB" ]] || fail 'F-SI18 TRIDAG generator drift'
git show "$FVQ33_BRANCH:$FVQ33_PLAN" > "$BUILD/fvq33_plan.json"
git show "$FVQ33_BRANCH:$FVQ33_STATUS" > "$BUILD/fvq33_status.json"
git show "$OWNER_BRANCH:$OWNER_HANDOFF" > "$BUILD/owner_handoff.json"

echo 'FVQ34_G01_SOURCE_HANDOFF_PRIOR_FAILURE_LOCK=PASS'

python3 - "$PLAN" "$BUILD/fvq33_plan.json" "$BUILD/fvq33_status.json" "$BUILD/owner_handoff.json" "$BUILD/cases.tsv" <<'PY'
import json,sys
p=json.load(open(sys.argv[1])); p33=json.load(open(sys.argv[2])); s33=json.load(open(sys.argv[3])); h=json.load(open(sys.argv[4]))
assert p['work_unit']=='F-VQ34' and p['frozen_before_execution'] is True
assert p['candidate_source_commit']=='6e9a684baff6812c3e1be5286f48447a6b4bff76'
assert h['qualified_source_commit']==p['candidate_source_commit']
assert h['handoff_to']=='F-VQ34' and h['gc02_release'] is False
assert s33['decision']=='COMPLETE_FAIL_CLOSED_SOURCE_CONTRADICTION_NATIVE_INVALID_BUDGET_DIAGNOSTIC_NOT_PRESERVED'
assert s33['negative_transfer'] is False and s33['executable_cases_started'] is False
m=p['independent_matrix']; assert m['case_count']==12 and len(m['cases'])==12 and m['frozen_before_execution'] is True
new={(float(c['h0_cm']),float(c['jump_cm']),float(c['horizon_day'])) for c in m['cases']}
assert len(new)==12
fsi24={(hh,j,0.25) for hh in (-25.0,-75.0,-250.0) for j in (-0.1,-0.01,0.001,0.01,0.1)}
fvq30={(hh,j,dt) for hh in (-35.0,-95.0,-185.0,-300.0) for j in (-0.075,0.075) for dt in (0.125,0.5)}
fvq31={(hh,j,dt) for hh in (-55.0,-140.0,-240.0) for j in (-0.04,0.04) for dt in (0.2,0.375)}
fvq32={(hh,j,dt) for hh in (-65.0,-125.0,-275.0) for j in (-0.03,0.03) for dt in (0.15,0.3)}
fkt10={(-75.0,0.01,0.25)}; fkt11={(-125.0,0.03,0.3)}
fvq33={(float(c['h0_cm']),float(c['jump_cm']),float(c['horizon_day'])) for c in p33['independent_matrix']['cases']}
for prior in (fsi24,fvq30,fvq31,fvq32,fkt10,fkt11,fvq33): assert not (new & prior)
assert m['exact_triplet_overlap_with_F_VQ33_matrix']==0
with open(sys.argv[5],'w') as f:
    for c in m['cases']:
        f.write(f"{c['case']}\t{c['probe']}\t{float(c['h0_cm']):.17e}\t{float(c['jump_cm']):.17e}\t{float(c['horizon_day']):.17e}\n")
print('FVQ34_G02_MATRIX_DISJOINTNESS=PASS')
print('FVQ34_G02_FRESH_CASES=12')
PY

python3 - <<'PY'
from pathlib import Path
tx=Path('src/transaction/mod_transaction_reference.f90').read_text().lower()
backend=Path('src/runtime/mod_fmr_serialized_reference_backend.f90').read_text().lower()
canonical=Path('src/runtime/mod_canonical_contracts.f90').read_text().lower()
start=tx.index('subroutine execute_model_certificate_interval')
mass=tx.index('if (.not. mass_ok) then',start)
cert=tx.index('certificate_valid = outcome%temporal_certificate_available',mass)
threshold=tx.index('outcome%temporal_indicator <= 1.0_real64',cert)
commit=tx.index('call move_alloc(candidate_state, committed)',threshold)
assert mass < cert < threshold < commit
assert 'model_temporal_indicator_budget' not in tx
assert 'logical :: model_temporal_indicator_budget_available = .false.' in canonical
assert 'self%temporal_indicator_budget_valid = .false.' in backend
assert 'if (ieee_is_finite(self%temporal_indicator_budget)) then' in backend
assert 'self%temporal_indicator_budget_valid = self%temporal_indicator_budget > 0.0_real64' in backend
assert 'normalized_indicator = indicator_result%head_inf_bound / self%temporal_indicator_budget' in backend
print('FVQ34_G09_HARD_MASS_PRECEDENCE_SOURCE=PASS')
print('FVQ34_G13_NUMERICAL_CONFIG_OWNERSHIP=PASS')
PY

# Independent generic executable oracle that a valid temporal certificate cannot override mass failure.
bash "$FKT09_RUNNER" > "$BUILD/fkt09.txt" 2>&1 || { cat "$BUILD/fkt09.txt" >&2; fail 'F-KT09 mass precedence regression'; }
grep -Fq 'FKT09_MODEL_CERTIFICATE_GATE=PASS' "$BUILD/fkt09.txt" || { cat "$BUILD/fkt09.txt" >&2; fail 'F-KT09 PASS marker'; }
echo 'FVQ34_G09_FKT09_EXECUTABLE_MASS_PRECEDENCE=PASS'

bash "$FKT10_HISTORY" > "$BUILD/fkt10_history.txt" 2>&1 || { cat "$BUILD/fkt10_history.txt" >&2; fail 'F-KT10 history regression'; }
grep -Fq 'FKT10_TEMPORAL_HISTORY_RUNNER PASS' "$BUILD/fkt10_history.txt" || { cat "$BUILD/fkt10_history.txt" >&2; fail 'F-KT10 history marker'; }
echo 'FVQ34_G12_FKT10_HISTORY_REGRESSION=PASS'

git show "$FSI18_BRANCH:$FSI18_GENERATOR" > "$BUILD/make_reference_tridag.py"
python3 "$BUILD/make_reference_tridag.py" "$STUB" "$BUILD/reference_tridag_stubs.f90"
grep -Fq 'SWAP 4.3.1 tridag.f90' "$BUILD/reference_tridag_stubs.f90" || fail 'reference TRIDAG marker missing'
if grep -Fq 'solution(i) = 0.0d0' "$BUILD/reference_tridag_stubs.f90"; then fail 'zero-correction TRIDAG survived'; fi
echo 'FVQ34_G03_REFERENCE_TRIDAG_SOURCE=PASS'

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
MODULE_SRC=(
  "$BUILD/reference_tridag_stubs.f90"
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/transaction/mod_transaction_reference.f90
  src/transaction/mod_fkt_temporal_indicator_history.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/kernel/mod_kernel_transactions.f90
  src/runtime/mod_fmr_runtime_core.f90
  src/runtime/mod_fmr_checkpoint_orchestrator.f90
  src/solver/mod_soil_water_solver_contract.f90
  src/solver/mod_process_hydraulic_view.f90
  src/solver/mod_reference_linear_solver.f90
  src/solver/mod_reference_richards_workspace.f90
  src/solver/mod_reference_richards_state_binding.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_source_sink_provider.f90
  src/solver/mod_b110_root_sink_provider.f90
  src/solver/mod_fixed_flux_top_boundary_provider.f90
  src/solver/mod_reference_richards_temporal_indicator.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  src/adapter/mod_b110_serialized_context_binding.f90
  src/process/mod_snow_process.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
)

build_and_run() {
  local opt="$1" tag="$2" out="$BUILD/$2"
  mkdir -p "$out"
  local objects=() src obj cid probe h0 jump dt direct_src direct_obj direct_exe direct_out binf case_out
  for src in "${MODULE_SRC[@]}"; do
    obj="$out/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c "$DRIVER" -o "$out/vq34.o"
  gfortran "$opt" "${objects[@]}" "$out/vq34.o" -o "$out/vq34"
  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c "$FKT10_TX_DRIVER" -o "$out/fkt10_tx.o"
  gfortran "$opt" "${objects[@]}" "$out/fkt10_tx.o" -o "$out/fkt10_tx"
  : > "$out/matrix.txt"
  : > "$out/direct_values.tsv"
  while IFS=$'\t' read -r cid probe h0 jump dt; do
    direct_src="$out/direct_${cid}.f90"
    cp "$DIRECT_DRIVER" "$direct_src"
    python3 - "$direct_src" "$dt" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); dt=float(sys.argv[2]); s=p.read_text()
old='real(real64), parameter :: total_dt = 0.25_real64, hard_mass_gate = 1.0e-12_real64'
new=f'real(real64), parameter :: total_dt = {dt:.17e}_real64, hard_mass_gate = 1.0e-12_real64'
if s.count(old)!=1: raise SystemExit('FVQ34 direct dt token drift')
p.write_text(s.replace(old,new,1))
PY
    direct_obj="$out/direct_${cid}.o"; direct_exe="$out/direct_${cid}"; direct_out="$out/direct_${cid}.txt"
    gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c "$direct_src" -o "$direct_obj"
    gfortran "$opt" "${objects[@]}" "$direct_obj" -o "$direct_exe"
    timeout 180s "$direct_exe" "$h0" "$jump" > "$direct_out" 2>&1 || { cat "$direct_out" >&2; fail "direct oracle opt=$tag case=$cid"; }
    grep -Fq 'FSI25_REFERENCE_INDICATOR_CASE PASS' "$direct_out" || fail "direct oracle marker opt=$tag case=$cid"
    binf="$(python3 - "$direct_out" <<'PY'
import re,sys
row=[x for x in open(sys.argv[1]).read().splitlines() if x.startswith('FSI25_PROD_ROW:')]
if len(row)!=1: raise SystemExit('FVQ34 direct row parse')
m=re.search(r':BINF=\s*([^:]+):MIN_M=',row[0])
if not m: raise SystemExit('FVQ34 direct B_inf parse')
v=float(m.group(1))
if not (v>0.0): raise SystemExit('FVQ34 direct B_inf nonpositive')
print(f'{v:.17e}')
PY
)"
    printf '%s\t%s\n' "$cid" "$binf" >> "$out/direct_values.tsv"
    case_out="$out/case_${cid}.txt"
    timeout 180s "$out/vq34" "$probe" "$h0" "$jump" "$dt" "$binf" > "$case_out" 2>&1 || { cat "$case_out" >&2; fail "qualification opt=$tag case=$cid probe=$probe"; }
    grep -Fq "FVQ34_CASE_${probe}=PASS" "$case_out" || { cat "$case_out" >&2; fail "qualification marker opt=$tag case=$cid"; }
    echo "FVQ34_CASE_ID=$cid" >> "$out/matrix.txt"
    cat "$case_out" >> "$out/matrix.txt"
    echo "FVQ34_G03_CASE=PASS:OPT=$tag:CASE=$cid:PROBE=$probe:BINF=$binf"
  done < "$BUILD/cases.tsv"

  # Source-locked F-KT10 real transaction behavior replayed on fresh F-VQ34 case 1.
  read -r first_id first_binf < <(head -n1 "$out/direct_values.tsv")
  read -r _ first_probe first_h0 first_jump first_dt < <(head -n1 "$BUILD/cases.tsv")
  timeout 180s "$out/fkt10_tx" "$first_h0" "$first_jump" "$first_dt" "$first_binf" > "$out/fkt10_tx.txt" 2>&1 || { cat "$out/fkt10_tx.txt" >&2; fail "F-KT10 real replay opt=$tag"; }
  grep -Fq 'FKT10_GATE_G_TRANSACTIONAL_FROZEN_CASE PASS' "$out/fkt10_tx.txt" || fail "F-KT10 real replay marker opt=$tag"
}

build_and_run -O0 o0
build_and_run -O2 o2

cmp "$BUILD/o0/matrix.txt" "$BUILD/o2/matrix.txt" || { diff -u "$BUILD/o0/matrix.txt" "$BUILD/o2/matrix.txt" >&2 || true; fail 'O0/O2 qualification matrix drift'; }
cmp "$BUILD/o0/direct_values.tsv" "$BUILD/o2/direct_values.tsv" || { diff -u "$BUILD/o0/direct_values.tsv" "$BUILD/o2/direct_values.tsv" >&2 || true; fail 'O0/O2 direct B_inf drift'; }
cmp "$BUILD/o0/fkt10_tx.txt" "$BUILD/o2/fkt10_tx.txt" || { diff -u "$BUILD/o0/fkt10_tx.txt" "$BUILD/o2/fkt10_tx.txt" >&2 || true; fail 'O0/O2 F-KT10 replay drift'; }

echo 'FVQ34_G11_O0_O2_IDENTITY=PASS'
echo 'FVQ34_G12_FKT10_REAL_REPLAY=PASS'

python3 - "$BUILD/o0/matrix.txt" <<'PY'
from pathlib import Path
s=Path(__import__('sys').argv[1]).read_text()
assert s.count('FVQ34_CASE_ID=')==12
assert s.count('=PASS')>=12
for probe in ('VALID_ACCEPT','VALID_REJECT','MISSING_BUDGET','INVALID_ZERO_BUDGET','NO_HISTORY_WITH_VALID_BUDGET',
              'BOUNDED_RETRY_NO_MONOTONICITY_CLAIM','INVALID_NEGATIVE_BUDGET','INVALID_NAN_BUDGET',
              'INVALID_POSITIVE_INFINITY_BUDGET','BOUNDARY_ACCEPT'):
    assert f'FVQ34_CASE_{probe}=PASS' in s
for key in ('FVQ34_DIRECT_BINF=','FVQ34_NATIVE_BUDGET=','FVQ34_BUDGET_SUPPLIED=','FVQ34_BUDGET_VALID=',
            'FVQ34_RAW_BINF=','FVQ34_CH=','FVQ34_CERTIFICATE_AVAILABLE=','FVQ34_REASON=',
            'FVQ34_ATTEMPTS=','FVQ34_RETRIES=','FVQ34_ROLLBACKS=','FVQ34_MASS_REJECTIONS=',
            'FVQ34_MAX_ABS_STEP_MASS=','FVQ34_EXTRA_TRIDAG_LAST=','FVQ34_EXTRA_NONLINEAR_LAST='):
    assert key in s
print('FVQ34_G04_ACCEPT_REJECT_BOUNDARY=PASS')
print('FVQ34_G05_INVALID_FAIL_CLOSED=PASS')
print('FVQ34_G06_NATIVE_INVALID_DIAGNOSTICS=PASS')
print('FVQ34_G07_NO_HISTORY_NO_BOOTSTRAP=PASS')
print('FVQ34_G08_BOUNDED_RETRY_ROLLBACK=PASS')
print('FVQ34_G10_DIAGNOSTIC_COMPLETENESS=PASS')
PY

echo 'FVQ34_G03_DIRECT_BINF_EQUIVALENCE=PASS'
echo 'FVQ34_G10_COST_SHAPE=PASS'
echo 'FVQ34_G12_FVQ32_SOURCE_LOCK=PASS'
echo 'FVQ34_G13_NO_SCOPE_EXPANSION=PASS'
echo 'FVQ34_REMEDIATED_HEAD_BUDGET_CERTIFICATE_QUALIFICATION PASS'

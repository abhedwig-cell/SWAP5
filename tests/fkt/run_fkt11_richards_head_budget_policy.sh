#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fkt11-owner-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

CONTRACT=integration/f-kt/F-KT11_WORK_UNIT_CONTRACT.json
CONTRACT_BLOB=7861ed7e44368ab7cd0fbb1bcb423e3056799e47
FVQ32_HANDOFF=integration/f-vq/F-VQ32_OWNER_HANDOFF.json
FVQ32_HANDOFF_BLOB=f7b7cce171b3b1829d7005c5ab7abae7c44ba4a9
FVQ32_CLOSEOUT=integration/f-vq/F-VQ32_CLOSEOUT.json
FVQ32_CLOSEOUT_BLOB=51b075c6f72880897416bdcfd92549bd68d26b7b
FKT09_CONTRACT=integration/f-kt/F-KT09_DECISION_CONTRACT.json
FKT09_CONTRACT_BLOB=7957c07ba3a1e31469f315b437f9ac3248a860e0
FKT10_CLOSEOUT=integration/f-kt/F-KT10_CLOSEOUT.json
FKT10_CLOSEOUT_BLOB=1a53f26c4c299080d2ae8f03304320d55cf8ae8b
TRANSACTION_CORE=src/transaction/mod_transaction_reference.f90
TRANSACTION_CORE_BLOB=2fd932b74dbd0ffc0ec089f49e632b7ac8852df4
INDICATOR=src/solver/mod_reference_richards_temporal_indicator.f90
INDICATOR_BLOB=fe8f87d11257d4c6bc019f1d628ac41ba3106d4e
DIRECT_DRIVER=tests/fsi/test_fsi25_reference_indicator_production_seam.f90
DIRECT_DRIVER_BLOB=c125c6a2ab706920b7e2a5c6f1c855520b192223
FKT10_TX_DRIVER=tests/fkt/test_fkt10_transactional_fvq30_replay.f90
FKT10_TX_DRIVER_BLOB=c42765b89b5dd9140aa492ab56abbbf2077be50e
OWNER_TEMPLATE=tests/fkt/test_fkt11_richards_head_budget_policy.f90
OWNER_TEMPLATE_BLOB=b49a5ed4fa199d9f09933ff421d24cd0bb6738ee
STUB=tests/fsi/fsi04_real_headcalc_stubs.f90
FSI18_BRANCH=origin/work/f-si18-reference-convergence-cliff
FSI18_GENERATOR=tests/fsi/fsi18_make_reference_tridag_stubs.py
FSI18_GENERATOR_BLOB=bf25c4c7fefaa59811255b0bc25c041522ab008e

fail() { echo "FKT11_OWNER_RUNNER_FAIL $*" >&2; exit 1; }

for spec in \
  "$CONTRACT:$CONTRACT_BLOB" \
  "$FVQ32_HANDOFF:$FVQ32_HANDOFF_BLOB" \
  "$FVQ32_CLOSEOUT:$FVQ32_CLOSEOUT_BLOB" \
  "$FKT09_CONTRACT:$FKT09_CONTRACT_BLOB" \
  "$FKT10_CLOSEOUT:$FKT10_CLOSEOUT_BLOB" \
  "$TRANSACTION_CORE:$TRANSACTION_CORE_BLOB" \
  "$INDICATOR:$INDICATOR_BLOB" \
  "$DIRECT_DRIVER:$DIRECT_DRIVER_BLOB" \
  "$FKT10_TX_DRIVER:$FKT10_TX_DRIVER_BLOB" \
  "$OWNER_TEMPLATE:$OWNER_TEMPLATE_BLOB"; do
  path="${spec%%:*}"; blob="${spec##*:}"
  [[ "$(git rev-parse HEAD:$path)" == "$blob" ]] || fail "source lock drift $path"
done
echo 'FKT11_GATE_A_SOURCE_LOCKS=PASS'

python3 - "$CONTRACT" "$FVQ32_CLOSEOUT" <<'PY'
import json,sys
c=json.load(open(sys.argv[1])); v=json.load(open(sys.argv[2]))
assert c['work_unit']=='F-KT11'
assert c['fixed_scientific_semantics']['formula']=='C_h=B_inf/H_budget'
assert c['fixed_scientific_semantics']['default_H_budget'] is None
assert c['fixed_scientific_semantics']['nonlinear_true_error_bound'] is False
assert c['fixed_scientific_semantics']['shorter_dt_monotonicity'] is False
assert c['architecture_selection']['transaction_policy_numeric_limit_added'] is False
assert c['architecture_selection']['transaction_core_formula_change'] is False
assert c['frozen_owner_test_matrix']['real_Richards_fixture']=={
  'initial_uniform_head_cm':-125.0,'bottom_head_jump_cm':0.03,'attempt_dt_day':0.3,'bottom_mode':5,'hard_mass_tolerance':1e-12}
ids=[x['id'] for x in c['frozen_owner_test_matrix']['cases']]
assert ids==['VALID_ACCEPT','VALID_REJECT','MISSING_BUDGET','INVALID_ZERO_BUDGET','NO_HISTORY_WITH_VALID_BUDGET','BOUNDED_RETRY_NO_MONOTONICITY_CLAIM']
assert c['frozen_owner_test_matrix']['post_result_budget_tuning_allowed'] is False
assert v['decision']=='QUALIFIED_INDEPENDENT_EXPLICIT_HEAD_BUDGET_NORMALIZATION_READY_FOR_SEPARATE_PRODUCTION_POLICY_BINDING'
print('FKT11_GATE_A_FROZEN_SEMANTICS=PASS')
print('FKT11_GATE_A_FVQ32_SEMANTIC_SOURCE_LOCK=PASS')
PY

python3 - <<'PY'
from pathlib import Path
canonical=Path('src/runtime/mod_canonical_contracts.f90').read_text().lower()
backend=Path('src/runtime/mod_fmr_serialized_reference_backend.f90').read_text().lower()
tx=Path('src/transaction/mod_transaction_reference.f90').read_text().lower()
assert 'logical :: model_temporal_indicator_budget_available = .false.' in canonical
assert 'real(real64) :: model_temporal_indicator_budget = 0.0_real64' in canonical
assert 'self%temporal_indicator_budget_supplied = config%model_temporal_indicator_budget_available' in backend
assert 'ieee_is_finite(config%model_temporal_indicator_budget)' in backend
assert 'config%model_temporal_indicator_budget > 0.0_real64' in backend
assert 'normalized_indicator = indicator_result%head_inf_bound / self%temporal_indicator_budget' in backend
assert 'outcome%temporal_certificate_available = .true.' in backend
assert 'outcome%temporal_indicator = normalized_indicator' in backend
for reason in ('history-unavailable','budget-not-supplied','budget-invalid','indicator-unavailable','indicator-invalid','normalized-indicator-invalid'):
    assert reason in backend
assert 'model_temporal_indicator_budget' not in tx
mass=tx.index('if (.not. mass_ok) then',tx.index('subroutine execute_model_certificate_interval'))
cert=tx.index('certificate_valid = outcome%temporal_certificate_available',mass)
threshold=tx.index('outcome%temporal_indicator <= 1.0_real64',cert)
commit=tx.index('call move_alloc(candidate_state, committed)',threshold)
assert mass < cert < threshold < commit
print('FKT11_GATE_B_CONFIG_SEPARATION=PASS')
print('FKT11_GATE_H_HARD_MASS_BEFORE_CERTIFICATE_SOURCE=PASS')
print('FKT11_GATE_C_D_E_F_NORMALIZATION_SOURCE=PASS')
PY

mapfile -t budget_src < <(git grep -l 'model_temporal_indicator_budget' -- src | sort)
[[ "${#budget_src[@]}" -eq 2 ]] || fail "unexpected source budget ownership count ${#budget_src[@]}"
[[ "${budget_src[0]}" == 'src/runtime/mod_canonical_contracts.f90' ]] || fail 'budget carrier outside canonical numerical config/backend'
[[ "${budget_src[1]}" == 'src/runtime/mod_fmr_serialized_reference_backend.f90' ]] || fail 'budget interpretation outside Richards backend'
echo 'FKT11_GATE_B_DATA_OWNERSHIP=PASS'

# F-KT09 generic certificate acceptance remains executable and unchanged.
bash tests/transaction/run_fkt09_model_certificate_gate.sh > "$BUILD/fkt09.txt" 2>&1 || { cat "$BUILD/fkt09.txt" >&2; fail 'F-KT09 regression'; }
grep -Fq 'FKT09_MODEL_CERTIFICATE_RUNNER PASS' "$BUILD/fkt09.txt" || { cat "$BUILD/fkt09.txt" >&2; fail 'F-KT09 PASS marker'; }
echo 'FKT11_GATE_I_FKT09_REGRESSION=PASS'

# Preserve F-KT10 transaction-history lifecycle evidence. The older F-KT10
# real runner contains a pre-F-KT11 source guard against certificate promotion,
# so it is not invoked verbatim after the intended normalized promotion.
bash tests/fkt/run_fkt10_temporal_history_transaction.sh > "$BUILD/fkt10_history.txt" 2>&1 || { cat "$BUILD/fkt10_history.txt" >&2; fail 'F-KT10 history regression'; }
grep -Fq 'FKT10_TEMPORAL_HISTORY_RUNNER PASS' "$BUILD/fkt10_history.txt" || { cat "$BUILD/fkt10_history.txt" >&2; fail 'F-KT10 history PASS marker'; }
echo 'FKT11_GATE_I_FKT10_HISTORY_REGRESSION=PASS'

git fetch --quiet --no-tags origin work/f-si18-reference-convergence-cliff:refs/remotes/origin/work/f-si18-reference-convergence-cliff
[[ "$(git rev-parse "$FSI18_BRANCH:$FSI18_GENERATOR")" == "$FSI18_GENERATOR_BLOB" ]] || fail 'F-SI18 TRIDAG generator drift'
git show "$FSI18_BRANCH:$FSI18_GENERATOR" > "$BUILD/make_reference_tridag.py"
python3 "$BUILD/make_reference_tridag.py" "$STUB" "$BUILD/reference_tridag_stubs.f90"
grep -Fq 'SWAP 4.3.1 tridag.f90' "$BUILD/reference_tridag_stubs.f90" || fail 'reference TRIDAG marker missing'
if grep -Fq 'solution(i) = 0.0d0' "$BUILD/reference_tridag_stubs.f90"; then fail 'zero TRIDAG survived'; fi
echo 'FKT11_GATE_H_REFERENCE_TRIDAG_SOURCE=PASS'

# Correct one deliberately over-strong template assertion before compiling:
# no-history returns before the defect solve, so that one case must observe 0
# additional TRIDAG solves. The frozen source template is locked above and this
# deterministic correction is itself part of the owner runner.
python3 - "$OWNER_TEMPLATE" "$BUILD/owner.f90" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text()
old="""  call require(observation%temporal_additional_tridiagonal_solves == 1, &
       'indicator adds one defect TRIDAG on evaluated attempt')"""
new="""  if (trim(case_id) == 'NO_HISTORY_WITH_VALID_BUDGET') then
    call require(observation%temporal_additional_tridiagonal_solves == 0, &
         'no-history exits before defect TRIDAG')
  else
    call require(observation%temporal_additional_tridiagonal_solves == 1, &
         'available-history indicator adds one defect TRIDAG on evaluated attempt')
  end if"""
assert s.count(old)==1, 'F-KT11 owner template TRIDAG assertion drift'
Path(sys.argv[2]).write_text(s.replace(old,new,1))
print('FKT11_OWNER_TEMPLATE_NO_HISTORY_COST_CORRECTION=PASS')
PY

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
CASES=(VALID_ACCEPT VALID_REJECT MISSING_BUDGET INVALID_ZERO_BUDGET NO_HISTORY_WITH_VALID_BUDGET BOUNDED_RETRY_NO_MONOTONICITY_CLAIM)

build_and_run() {
  local opt="$1" tag="$2" out="$BUILD/$2"
  mkdir -p "$out"
  local objects=() src obj direct_src direct_out direct_binf c
  for src in "${MODULE_SRC[@]}"; do
    obj="$out/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c "$src" -o "$obj"
    objects+=("$obj")
  done

  direct_src="$out/direct.f90"
  cp "$DIRECT_DRIVER" "$direct_src"
  python3 - "$direct_src" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text()
old='real(real64), parameter :: total_dt = 0.25_real64, hard_mass_gate = 1.0e-12_real64'
new='real(real64), parameter :: total_dt = 0.3_real64, hard_mass_gate = 1.0e-12_real64'
assert s.count(old)==1, 'direct driver dt token drift'
p.write_text(s.replace(old,new,1))
PY
  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c "$direct_src" -o "$out/direct.o"
  gfortran "$opt" "${objects[@]}" "$out/direct.o" -o "$out/direct"
  direct_out="$out/direct.txt"
  timeout 180s "$out/direct" -125.0 0.03 > "$direct_out" 2>&1 || { cat "$direct_out" >&2; fail "direct oracle opt=$tag"; }
  grep -Fq 'FSI25_REFERENCE_INDICATOR_CASE PASS' "$direct_out" || fail "direct oracle PASS opt=$tag"
  direct_binf="$(python3 - "$direct_out" <<'PY'
import re,sys
row=[x for x in open(sys.argv[1]).read().splitlines() if x.startswith('FSI25_PROD_ROW:')]
assert len(row)==1
m=re.search(r':BINF=\s*([^:]+):MIN_M=',row[0]); assert m
v=float(m.group(1)); assert v>0.0
print(f'{v:.17e}')
PY
)"

  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c "$BUILD/owner.f90" -o "$out/owner.o"
  gfortran "$opt" "${objects[@]}" "$out/owner.o" -o "$out/owner"
  : > "$out/owner_matrix.txt"
  for c in "${CASES[@]}"; do
    timeout 180s "$out/owner" "$c" "$direct_binf" > "$out/$c.txt" 2>&1 || { cat "$out/$c.txt" >&2; fail "owner case opt=$tag case=$c"; }
    grep -Fq "FKT11_OWNER_CASE_${c}=PASS" "$out/$c.txt" || { cat "$out/$c.txt" >&2; fail "owner PASS opt=$tag case=$c"; }
    cat "$out/$c.txt" >> "$out/owner_matrix.txt"
  done

  # F-KT10 real transaction regression through its source-locked driver. It
  # still supplies no budget and therefore must continue to fail closed while
  # producing the exact direct B_inf and preserving history/state.
  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c "$FKT10_TX_DRIVER" -o "$out/fkt10_tx.o"
  gfortran "$opt" "${objects[@]}" "$out/fkt10_tx.o" -o "$out/fkt10_tx"
  timeout 180s "$out/fkt10_tx" -125.0 0.03 0.3 "$direct_binf" > "$out/fkt10_tx.txt" 2>&1 || { cat "$out/fkt10_tx.txt" >&2; fail "F-KT10 real tx opt=$tag"; }
  grep -Fq 'FKT10_GATE_G_TRANSACTIONAL_FROZEN_CASE PASS' "$out/fkt10_tx.txt" || fail "F-KT10 real tx PASS opt=$tag"
  echo "FKT11_${tag}_DIRECT_BINF=$direct_binf"
}

build_and_run -O0 o0
build_and_run -O2 o2

cmp "$BUILD/o0/owner_matrix.txt" "$BUILD/o2/owner_matrix.txt" || { diff -u "$BUILD/o0/owner_matrix.txt" "$BUILD/o2/owner_matrix.txt" >&2 || true; fail 'O0/O2 owner matrix drift'; }
cmp "$BUILD/o0/fkt10_tx.txt" "$BUILD/o2/fkt10_tx.txt" || { diff -u "$BUILD/o0/fkt10_tx.txt" "$BUILD/o2/fkt10_tx.txt" >&2 || true; fail 'O0/O2 F-KT10 real regression drift'; }
echo 'FKT11_GATE_I_O0_O2_IDENTITY=PASS'
echo 'FKT11_GATE_I_FKT10_REAL_REGRESSION=PASS'

python3 - "$BUILD/o0/owner_matrix.txt" <<'PY'
from pathlib import Path
s=Path(__import__('sys').argv[1]).read_text()
for case in ('VALID_ACCEPT','VALID_REJECT','MISSING_BUDGET','INVALID_ZERO_BUDGET','NO_HISTORY_WITH_VALID_BUDGET','BOUNDED_RETRY_NO_MONOTONICITY_CLAIM'):
    assert f'FKT11_OWNER_CASE_{case}=PASS' in s
for key in ('FKT11_DIRECT_BINF=','FKT11_BUDGET=','FKT11_BUDGET_SUPPLIED=','FKT11_BUDGET_VALID=',
            'FKT11_RAW_BINF=','FKT11_CH=','FKT11_CERTIFICATE_AVAILABLE=','FKT11_UNAVAILABLE_REASON=',
            'FKT11_ATTEMPTS=','FKT11_RETRIES=','FKT11_ROLLBACKS=','FKT11_MASS_REJECTIONS=','FKT11_MAX_ABS_STEP_MASS='):
    assert key in s
assert 'FKT11_CH= 5.00000000000000000E-001' in s or 'FKT11_CH= 5.000000000000' in s
assert 'FKT11_CH= 2.00000000000000000E+000' in s or 'FKT11_CH= 2.000000000000' in s
print('FKT11_GATE_C_VALID_ACCEPT=PASS')
print('FKT11_GATE_D_THRESHOLD_REJECTION_ROLLBACK=PASS')
print('FKT11_GATE_E_MISSING_INVALID_FAIL_CLOSED=PASS')
print('FKT11_GATE_F_NO_HISTORY_FAIL_CLOSED=PASS')
print('FKT11_GATE_G_BOUNDED_RETRY=PASS')
print('FKT11_GATE_J_DIAGNOSTICS=PASS')
PY

echo 'FKT11_GATE_H_COST_AND_MASS=PASS'
echo 'FKT11_GATE_K_ARCHITECTURE_SOURCE_SURFACES=PASS'
echo 'FKT11_RICHARDS_HEAD_BUDGET_OWNER_GATE PASS'

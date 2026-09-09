#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fkt11-invalid-budget-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

REMEDIATION=integration/f-kt/F-KT11_DIAGNOSTIC_REMEDIATION.json
BACKEND=src/runtime/mod_fmr_serialized_reference_backend.f90
BACKEND_BLOB=9af5a494526810324dc00706b444e448e770cba9
OWNER_TEMPLATE=tests/fkt/test_fkt11_richards_head_budget_policy.f90
OWNER_TEMPLATE_BLOB=b49a5ed4fa199d9f09933ff421d24cd0bb6738ee
DIRECT_DRIVER=tests/fsi/test_fsi25_reference_indicator_production_seam.f90
DIRECT_DRIVER_BLOB=c125c6a2ab706920b7e2a5c6f1c855520b192223
STUB=tests/fsi/fsi04_real_headcalc_stubs.f90
FSI18_BRANCH=origin/work/f-si18-reference-convergence-cliff
FSI18_GENERATOR=tests/fsi/fsi18_make_reference_tridag_stubs.py
FSI18_GENERATOR_BLOB=bf25c4c7fefaa59811255b0bc25c041522ab008e

fail() { echo "FKT11_INVALID_BUDGET_REMEDIATION_FAIL $*" >&2; exit 1; }

[[ "$(git rev-parse HEAD:$BACKEND)" == "$BACKEND_BLOB" ]] || fail 'remediated backend blob drift'
[[ "$(git rev-parse HEAD:$OWNER_TEMPLATE)" == "$OWNER_TEMPLATE_BLOB" ]] || fail 'owner template drift'
[[ "$(git rev-parse HEAD:$DIRECT_DRIVER)" == "$DIRECT_DRIVER_BLOB" ]] || fail 'direct driver drift'
python3 - "$REMEDIATION" <<'PY'
import json,sys
r=json.load(open(sys.argv[1]))
assert r['work_unit']=='F-KT11'
assert r['previous_owner_matrix_remains_immutable'] is True
assert [x['id'] for x in r['supplemental_owner_cases']]==[
  'INVALID_NEGATIVE_BUDGET','INVALID_NAN_BUDGET','INVALID_POSITIVE_INFINITY_BUDGET']
assert r['remediation_contract']['normalization_uses_budget_only_when_valid'] is True
assert r['remediation_contract']['no_clamp'] is True
assert r['remediation_contract']['no_floor'] is True
assert r['remediation_contract']['no_abs'] is True
assert r['remediation_contract']['no_default'] is True
print('FKT11_REMEDIATION_CONTRACT_LOCK=PASS')
PY
python3 - <<'PY'
from pathlib import Path
s=Path('src/runtime/mod_fmr_serialized_reference_backend.f90').read_text()
assert 'self%temporal_indicator_budget_valid = .false.' in s
assert 'if (self%temporal_indicator_budget_supplied) then' in s
assert 'self%temporal_indicator_budget = config%model_temporal_indicator_budget' in s
assert 'if (ieee_is_finite(self%temporal_indicator_budget)) then' in s
assert 'self%temporal_indicator_budget_valid = self%temporal_indicator_budget > 0.0_real64' in s
assert 'normalized_indicator = indicator_result%head_inf_bound / self%temporal_indicator_budget' in s
print('FKT11_REMEDIATION_NAN_SAFE_SOURCE=PASS')
print('FKT11_REMEDIATION_NORMALIZATION_GUARD_UNCHANGED=PASS')
PY

git fetch --quiet --no-tags origin work/f-si18-reference-convergence-cliff:refs/remotes/origin/work/f-si18-reference-convergence-cliff
[[ "$(git rev-parse "$FSI18_BRANCH:$FSI18_GENERATOR")" == "$FSI18_GENERATOR_BLOB" ]] || fail 'F-SI18 TRIDAG generator drift'
git show "$FSI18_BRANCH:$FSI18_GENERATOR" > "$BUILD/make_reference_tridag.py"
python3 "$BUILD/make_reference_tridag.py" "$STUB" "$BUILD/reference_tridag_stubs.f90"
grep -Fq 'SWAP 4.3.1 tridag.f90' "$BUILD/reference_tridag_stubs.f90" || fail 'reference TRIDAG marker missing'

python3 - "$OWNER_TEMPLATE" "$BUILD/remediation_owner.f90" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text()
s=s.replace('use, intrinsic :: ieee_arithmetic, only: ieee_is_finite',
            'use, intrinsic :: ieee_arithmetic, only: ieee_is_finite, ieee_value, ieee_quiet_nan, ieee_positive_inf',1)
old_cost="""  call require(observation%temporal_additional_tridiagonal_solves == 1, &
       'indicator adds one defect TRIDAG on evaluated attempt')"""
new_cost="""  if (trim(case_id) == 'NO_HISTORY_WITH_VALID_BUDGET') then
    call require(observation%temporal_additional_tridiagonal_solves == 0, &
         'no-history exits before defect TRIDAG')
  else
    call require(observation%temporal_additional_tridiagonal_solves == 1, &
         'available-history indicator adds one defect TRIDAG on evaluated attempt')
  end if"""
assert s.count(old_cost)==1
s=s.replace(old_cost,new_cost,1)
config_marker="""  case ('NO_HISTORY_WITH_VALID_BUDGET')
    budget = 2.0_real64*expected_binf"""
config_insert="""  case ('INVALID_NEGATIVE_BUDGET')
    budget = -abs(expected_binf)
    expected_c = 0.0_real64
    config%model_temporal_indicator_budget_available = .true.
    config%model_temporal_indicator_budget = budget
  case ('INVALID_NAN_BUDGET')
    budget = ieee_value(0.0_real64, ieee_quiet_nan)
    expected_c = 0.0_real64
    config%model_temporal_indicator_budget_available = .true.
    config%model_temporal_indicator_budget = budget
  case ('INVALID_POSITIVE_INFINITY_BUDGET')
    budget = ieee_value(0.0_real64, ieee_positive_inf)
    expected_c = 0.0_real64
    config%model_temporal_indicator_budget_available = .true.
    config%model_temporal_indicator_budget = budget
""" + config_marker
assert s.count(config_marker)==1
s=s.replace(config_marker,config_insert,1)
post_marker="""  case ('NO_HISTORY_WITH_VALID_BUDGET')
    call require(.not. result%completed .and. .not. candidate%ready(), 'no-history origin rejects')"""
post_insert="""  case ('INVALID_NEGATIVE_BUDGET','INVALID_NAN_BUDGET','INVALID_POSITIVE_INFINITY_BUDGET')
    call require(.not. result%completed .and. .not. candidate%ready(), 'invalid supplied budget rejects')
    call require(observation%temporal_head_budget_supplied .and. .not. observation%temporal_head_budget_valid, &
         'invalid budget remains supplied but invalid')
    call require(same_real_bits(observation%temporal_head_budget,budget), &
         'native invalid supplied budget preserved bitwise for diagnostics')
    call require(.not. observation%temporal_certificate_available, 'invalid budget certificate unavailable')
    call require(trim(observation%temporal_certificate_unavailable_reason) == 'budget-invalid', 'invalid budget reason')
    call require(diagnostics%temporal_certificate_unavailable_rejections == 1 .and. diagnostics%temporal_rejections == 1, &
         'invalid budget unavailable rejection counted')
    actual_binf = observation%temporal_head_inf_bound
    call require(close_to(actual_binf,expected_binf), 'invalid budget still exposes raw B_inf')
    call assert_rejected_state_unchanged(committed,fp_before,revision_before,time_before,history_before,history_available_before)

""" + post_marker
assert s.count(post_marker)==1
s=s.replace(post_marker,post_insert,1)
Path(sys.argv[2]).write_text(s)
print('FKT11_REMEDIATION_DRIVER_MATERIALIZED=PASS')
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
CASES=(INVALID_NEGATIVE_BUDGET INVALID_NAN_BUDGET INVALID_POSITIVE_INFINITY_BUDGET)

build_and_run() {
  local opt="$1" tag="$2" out="$BUILD/$2"
  mkdir -p "$out"
  local objects=() src obj direct_src direct_binf c
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
assert s.count(old)==1
p.write_text(s.replace(old,new,1))
PY
  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c "$direct_src" -o "$out/direct.o"
  gfortran "$opt" "${objects[@]}" "$out/direct.o" -o "$out/direct"
  timeout 180s "$out/direct" -125.0 0.03 > "$out/direct.txt" 2>&1 || { cat "$out/direct.txt" >&2; fail "direct oracle $tag"; }
  direct_binf="$(python3 - "$out/direct.txt" <<'PY'
import re,sys
row=[x for x in open(sys.argv[1]).read().splitlines() if x.startswith('FSI25_PROD_ROW:')]
assert len(row)==1
m=re.search(r':BINF=\s*([^:]+):MIN_M=',row[0]); assert m
v=float(m.group(1)); assert v>0.0
print(f'{v:.17e}')
PY
)"
  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c "$BUILD/remediation_owner.f90" -o "$out/remediation.o"
  gfortran "$opt" "${objects[@]}" "$out/remediation.o" -o "$out/remediation"
  : > "$out/matrix.txt"
  for c in "${CASES[@]}"; do
    timeout 180s "$out/remediation" "$c" "$direct_binf" > "$out/$c.txt" 2>&1 || { cat "$out/$c.txt" >&2; fail "case $tag $c"; }
    grep -Fq "FKT11_OWNER_CASE_${c}=PASS" "$out/$c.txt" || { cat "$out/$c.txt" >&2; fail "PASS $tag $c"; }
    grep -Fq 'FKT11_BUDGET_SUPPLIED=T' "$out/$c.txt" || fail "supplied diag $tag $c"
    grep -Fq 'FKT11_BUDGET_VALID=F' "$out/$c.txt" || fail "validity diag $tag $c"
    grep -Fq 'FKT11_CERTIFICATE_AVAILABLE=F' "$out/$c.txt" || fail "certificate diag $tag $c"
    grep -Fq 'FKT11_UNAVAILABLE_REASON=budget-invalid' "$out/$c.txt" || fail "reason diag $tag $c"
    cat "$out/$c.txt" >> "$out/matrix.txt"
  done
}

build_and_run -O0 o0
build_and_run -O2 o2
cmp "$BUILD/o0/matrix.txt" "$BUILD/o2/matrix.txt" || { diff -u "$BUILD/o0/matrix.txt" "$BUILD/o2/matrix.txt" >&2 || true; fail 'O0/O2 invalid-budget diagnostic drift'; }

echo 'FKT11_REMEDIATION_INVALID_NEGATIVE=PASS'
echo 'FKT11_REMEDIATION_INVALID_NAN=PASS'
echo 'FKT11_REMEDIATION_INVALID_POSITIVE_INFINITY=PASS'
echo 'FKT11_REMEDIATION_NATIVE_VALUE_PRESERVATION=PASS'
echo 'FKT11_REMEDIATION_O0_O2_IDENTITY=PASS'
echo 'FKT11_INVALID_BUDGET_DIAGNOSTIC_REMEDIATION PASS'

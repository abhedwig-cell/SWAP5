#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fpe06-pre-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

PROTOCOL=integration/f-pe/F-PE06_MEASUREMENT_PROTOCOL.json
PROTOCOL_BLOB=82014f10ef446a44784cb5ad2b8418b7c4e36c29
CORRECTION=integration/f-pe/F-PE06_MEASUREMENT_PROTOCOL_CORRECTION_01.json
CORRECTION_BLOB=9419441824831b9129cafed1b45be198b3c102b4
DRIVER=tests/fpe/test_fpe06_temporal_certificate_cost.f90
DRIVER_BLOB=fda2917afb9cd68ee0c1abf6de1a89352a6cee67
PLAN=integration/f-vq/F-VQ34_QUALIFICATION_PLAN.json
PLAN_BLOB=4f3f7c8883397ed96d3af2f6585f25698c58e7b4
BACKEND=src/runtime/mod_fmr_serialized_reference_backend.f90
BACKEND_BLOB=9af5a494526810324dc00706b444e448e770cba9
HISTORY=src/transaction/mod_fkt_temporal_indicator_history.f90
HISTORY_BLOB=78884becbfa2fdaba74726608f9e37a303ae4c58
TRANSACTION=src/transaction/mod_transaction_reference.f90
TRANSACTION_BLOB=2fd932b74dbd0ffc0ec089f49e632b7ac8852df4
INDICATOR=src/solver/mod_reference_richards_temporal_indicator.f90
INDICATOR_BLOB=fe8f87d11257d4c6bc019f1d628ac41ba3106d4e
LINEAR=src/solver/mod_reference_linear_solver.f90
LINEAR_BLOB=b292d284e5549049eac1c80df4cc30008154eb96
SOLVER_CONTRACT=src/solver/mod_soil_water_solver_contract.f90
SOLVER_CONTRACT_BLOB=dc7b14a06f64c8ab0af9747f707b3394a5f5cbe0
CANONICAL=src/runtime/mod_canonical_contracts.f90
CANONICAL_BLOB=c06aa869a0bd479df4c7d6e1d0b4f5c07a207144
KERNEL=src/kernel/mod_kernel_transactions.f90
KERNEL_BLOB=63994d8ea6d0a40611574484ececf99e86379783
CHECKPOINT=src/runtime/mod_fmr_checkpoint_orchestrator.f90
CHECKPOINT_BLOB=232875e7192f995930c102609cee08dc8938c86a
STUB=tests/fsi/fsi04_real_headcalc_stubs.f90
FSI18_BRANCH=origin/work/f-si18-reference-convergence-cliff
FSI18_GENERATOR=tests/fsi/fsi18_make_reference_tridag_stubs.py
FSI18_GENERATOR_BLOB=bf25c4c7fefaa59811255b0bc25c041522ab008e

fail() { echo "FPE06_PRE_FAIL $*" >&2; exit 1; }

for spec in \
  "$PROTOCOL:$PROTOCOL_BLOB" \
  "$CORRECTION:$CORRECTION_BLOB" \
  "$DRIVER:$DRIVER_BLOB" \
  "$PLAN:$PLAN_BLOB" \
  "$BACKEND:$BACKEND_BLOB" \
  "$HISTORY:$HISTORY_BLOB" \
  "$TRANSACTION:$TRANSACTION_BLOB" \
  "$INDICATOR:$INDICATOR_BLOB" \
  "$LINEAR:$LINEAR_BLOB" \
  "$SOLVER_CONTRACT:$SOLVER_CONTRACT_BLOB" \
  "$CANONICAL:$CANONICAL_BLOB" \
  "$KERNEL:$KERNEL_BLOB" \
  "$CHECKPOINT:$CHECKPOINT_BLOB"; do
  path="${spec%%:*}"; blob="${spec##*:}"
  [[ "$(git rev-parse HEAD:$path)" == "$blob" ]] || fail "source lock drift $path"
done

echo 'FPE06_PRE_G01_SOURCE_LOCK=PASS'
echo 'FPE06_PRE_G01_PROTOCOL_CORRECTION_01=PASS'

python3 - "$PLAN" "$BUILD/cases.tsv" <<'PY'
import json,sys
p=json.load(open(sys.argv[1]))
m=p['independent_matrix']
assert m['case_count']==12 and len(m['cases'])==12
with open(sys.argv[2],'w') as f:
    for c in m['cases']:
        f.write(f"{c['case']}\t{float(c['h0_cm']):.17e}\t{float(c['jump_cm']):.17e}\t{float(c['horizon_day']):.17e}\n")
print('FPE06_PRE_G02_FROZEN_CASES=12')
PY

git fetch --quiet --no-tags origin \
  work/f-si18-reference-convergence-cliff:refs/remotes/origin/work/f-si18-reference-convergence-cliff
[[ "$(git rev-parse "$FSI18_BRANCH:$FSI18_GENERATOR")" == "$FSI18_GENERATOR_BLOB" ]] || fail 'F-SI18 TRIDAG generator drift'
git show "$FSI18_BRANCH:$FSI18_GENERATOR" > "$BUILD/make_reference_tridag.py"
python3 "$BUILD/make_reference_tridag.py" "$STUB" "$BUILD/reference_tridag_stubs.f90"
grep -Fq 'SWAP 4.3.1 tridag.f90' "$BUILD/reference_tridag_stubs.f90" || fail 'reference TRIDAG marker missing'
if grep -Fq 'solution(i) = 0.0d0' "$BUILD/reference_tridag_stubs.f90"; then fail 'zero-correction TRIDAG survived'; fi
echo 'FPE06_PRE_G03_REFERENCE_TRIDAG_SOURCE=PASS'

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
  local objects=() src obj cid h0 jump dt case_out
  for src in "${MODULE_SRC[@]}"; do
    obj="$out/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c "$DRIVER" -o "$out/fpe06.o"
  gfortran "$opt" "${objects[@]}" "$out/fpe06.o" -o "$out/fpe06"
  : > "$out/matrix.txt"
  while IFS=$'\t' read -r cid h0 jump dt; do
    case_out="$out/${cid}.txt"
    timeout 180s "$out/fpe06" "$h0" "$jump" "$dt" > "$case_out" 2>&1 || { cat "$case_out" >&2; fail "execution opt=$tag case=$cid"; }
    grep -Fq 'FPE06_PRETIMING_EQUIVALENCE=PASS' "$case_out" || { cat "$case_out" >&2; fail "PASS marker opt=$tag case=$cid"; }
    grep -Fq 'FPE06_A_HEADCALC=3' "$case_out" || fail "A headcalc topology opt=$tag case=$cid"
    grep -Fq 'FPE06_B_HEADCALC=3' "$case_out" || fail "B headcalc topology opt=$tag case=$cid"
    grep -Fq 'FPE06_B_DEFECT_TRIDAG_PER_ADVANCE=1' "$case_out" || fail "per-advance defect TRIDAG opt=$tag case=$cid"
    grep -Fq 'FPE06_B_DEFECT_TRIDAG_AGGREGATE=3' "$case_out" || fail "aggregate defect TRIDAG opt=$tag case=$cid"
    grep -Fq 'FPE06_B_EXTRA_NONLINEAR_PER_ADVANCE=0' "$case_out" || fail "extra nonlinear opt=$tag case=$cid"
    printf '%s\tPASS\n' "$cid" >> "$out/matrix.txt"
  done < "$BUILD/cases.tsv"
  [[ "$(wc -l < "$out/matrix.txt")" -eq 12 ]] || fail "matrix count opt=$tag"
  echo "FPE06_PRE_${tag}_CASES=12"
  echo "FPE06_PRE_${tag}=PASS"
}

build_and_run -O0 O0
build_and_run -O2 O2

diff -u "$BUILD/O0/matrix.txt" "$BUILD/O2/matrix.txt" >/dev/null || fail 'O0/O2 matrix identity'
echo 'FPE06_PRE_G04_O0_O2_MATRIX_IDENTITY=PASS'
echo 'FPE06_PRETIMING_RUNNER=PASS'

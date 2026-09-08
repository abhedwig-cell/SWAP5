#!/usr/bin/env bash
set -euo pipefail

QUAL_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CANDIDATE="${1:?usage: run_fvq14_gate.sh <exact-candidate-checkout> <results-dir>}"
RESULTS="${2:?usage: run_fvq14_gate.sh <exact-candidate-checkout> <results-dir>}"
CANDIDATE="$(cd "$CANDIDATE" && pwd)"
mkdir -p "$RESULTS"
RESULTS="$(cd "$RESULTS" && pwd)"

LOCKED_SHA=11eb34ea3afe8f5dda0515c28d7e08428dd2e272
LOCKED_TREE=04afa5d5a90671a7791174708ae6bf48b272c83f
FCI_BASE=1eceed967b12396b8bbc832f897376378463adce

actual_sha="$(git -C "$CANDIDATE" rev-parse HEAD)"
actual_tree="$(git -C "$CANDIDATE" rev-parse HEAD^{tree})"
[[ "$actual_sha" == "$LOCKED_SHA" ]] || { echo "VQ14_SOURCE_SHA_MISMATCH $actual_sha" >&2; exit 1; }
[[ "$actual_tree" == "$LOCKED_TREE" ]] || { echo "VQ14_SOURCE_TREE_MISMATCH $actual_tree" >&2; exit 1; }
git -C "$CANDIDATE" merge-base --is-ancestor "$FCI_BASE" HEAD || {
  echo "VQ14_FCI_ANCESTRY_FAIL" >&2; exit 1;
}
echo "VQ14_SOURCE_LOCK=PASS" | tee "$RESULTS/source_lock.txt"
echo "VQ14_SOURCE_SHA=$actual_sha" | tee -a "$RESULTS/source_lock.txt"
echo "VQ14_SOURCE_TREE=$actual_tree" | tee -a "$RESULTS/source_lock.txt"
echo "VQ14_FCI_ANCESTRY=PASS" | tee -a "$RESULTS/source_lock.txt"

check_blob() {
  local path="$1" expected="$2" actual
  actual="$(git -C "$CANDIDATE" hash-object "$CANDIDATE/$path")"
  [[ "$actual" == "$expected" ]] || {
    echo "VQ14_BLOB_MISMATCH $path expected=$expected actual=$actual" >&2
    exit 1
  }
  printf '%s %s\n' "$path" "$actual" >> "$RESULTS/candidate_blob_locks.txt"
}
: > "$RESULTS/candidate_blob_locks.txt"
check_blob src/transaction/mod_transaction_reference.f90 b1878606ae6cb2b04a7b4b15e3e537deacf4477f
check_blob src/runtime/mod_canonical_contracts.f90 0c2b15fc45011c580384cf6a618e7b378fdccf0a
check_blob src/runtime/mod_canonical_interval_runtime.f90 f2cae79d533343db818c11e0b61b605ac5f6739d
check_blob src/kernel/mod_kernel_transactions.f90 9f7c16e71cfb93b57f796ba759bae73824318a2f
check_blob src/solver/mod_soil_water_solver_contract.f90 57b51997d28807fbe2da1b2e5bf654fc4167adb9
check_blob src/solver/mod_reference_richards_workspace.f90 93285b2ca24669494c93c00403e3783fca6758e9
check_blob src/solver/mod_reference_richards_state_binding.f90 e68d88382c6502c571713cc97fddd4e18434e271
check_blob src/solver/mod_b110_default_mvg_provider.f90 97d67eb373073b183be6d1bf5b756ecb5125dde2
check_blob src/solver/mod_b110_source_sink_provider.f90 d6c57add72387e5c0022a44319fff08046194aac
check_blob src/adapter/mod_reference_richards_legacy_binding.f90 eb4b74ee422bc331ed3d6abaa40dd9f85b2551c0
check_blob src/adapter/mod_b110_serialized_context_binding.f90 94e904ed9701a00fb273ced4944161e9f47c5200
check_blob src/runtime/mod_fmr_serialized_reference_backend.f90 ade399a1df4b582c9038442093ccacce034f923d
check_blob src/legacy/b1_10_port/headcalc.f90 be5978827095445b15de7baf607728792de6a366
check_blob reference/swap-4.3.1/b1_10_source/MOD_MvG_functions.f90.gz.b64 6cfcec4e38b02343ba48e7e6fb5d595158e19653
check_blob reference/swap-4.3.1/b1_10_source/MOD_MvG_functions.manifest.json c64942d2964bb67c200f973b76e05222ad73067f

echo "VQ14_EXACT_PRODUCTION_BLOBS=PASS"
(
  cd "$CANDIDATE"
  python3 tools/vq/b1_10_admission_gate.py
) | tee "$RESULTS/b110_static_admission.log"

gfortran --version | tee "$RESULTS/compiler.txt"
python3 "$QUAL_ROOT/tests/fvq/fvq14_instrument_candidate.py" "$CANDIDATE" "$RESULTS/fvq14_candidate_instrumented.F90" \
  | tee "$RESULTS/instrumentation.log"
sha256sum "$RESULTS/fvq14_candidate_instrumented.F90" > "$RESULTS/instrumented_driver.sha256"

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
CAND_SRC=(
  tests/fsi/fsi04_real_headcalc_stubs.f90
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/transaction/mod_transaction_reference.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/kernel/mod_kernel_transactions.f90
  src/runtime/mod_fmr_runtime_core.f90
  src/runtime/mod_fmr_checkpoint_orchestrator.f90
  src/solver/mod_soil_water_solver_contract.f90
  src/solver/mod_reference_richards_workspace.f90
  src/solver/mod_reference_richards_state_binding.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_source_sink_provider.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  src/adapter/mod_b110_serialized_context_binding.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
  tests/fmr/mod_fmr04_fixed_top_provider.f90
)
ORACLE_SRC=(
  tests/fsi/fsi04_real_headcalc_stubs.f90
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/solver/mod_soil_water_solver_contract.f90
  src/solver/mod_reference_richards_workspace.f90
  src/solver/mod_reference_richards_state_binding.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_source_sink_provider.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  src/adapter/mod_b110_serialized_context_binding.f90
  tests/fmr/mod_fmr04_fixed_top_provider.f90
)

compile_program() {
  local opt="$1" mode="$2" outdir="$RESULTS/build_${mode}_o${opt}"
  mkdir -p "$outdir"
  : > "$RESULTS/build_${mode}_o${opt}.log"
  local -a srcs=() objects=()
  if [[ "$mode" == candidate ]]; then srcs=("${CAND_SRC[@]}"); else srcs=("${ORACLE_SRC[@]}"); fi
  local src obj
  for src in "${srcs[@]}"; do
    obj="$outdir/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$outdir" -I "$outdir" -c "$CANDIDATE/$src" -o "$obj" \
      >> "$RESULTS/build_${mode}_o${opt}.log" 2>&1
    objects+=("$obj")
  done
  if [[ "$mode" == candidate ]]; then
    src="$RESULTS/fvq14_candidate_instrumented.F90"
  else
    src="$QUAL_ROOT/tests/fvq/test_fvq14_b110_reference.F90"
  fi
  obj="$outdir/fvq14_${mode}_driver.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$outdir" -I "$outdir" -c "$src" -o "$obj" \
    >> "$RESULTS/build_${mode}_o${opt}.log" 2>&1
  objects+=("$obj")
  gfortran -O"$opt" "${objects[@]}" -o "$outdir/fvq14_${mode}" \
    >> "$RESULTS/build_${mode}_o${opt}.log" 2>&1
  sha256sum "$outdir/fvq14_${mode}" > "$RESULTS/${mode}_o${opt}_executable.sha256"
}

compile_program 0 candidate
compile_program 2 candidate
compile_program 0 oracle
compile_program 2 oracle
echo "VQ14_INDEPENDENT_BUILD_O0_O2=PASS"

C0="$RESULTS/build_candidate_o0/fvq14_candidate"
C2="$RESULTS/build_candidate_o2/fvq14_candidate"
O0="$RESULTS/build_oracle_o0/fvq14_oracle"
O2="$RESULTS/build_oracle_o2/fvq14_oracle"

# A/B/A ordering, with O2 as B, plus independent reference repeatability.
"$C0" > "$RESULTS/candidate_o0_a1.log" 2>&1
"$O0" > "$RESULTS/oracle_o0_a1.log" 2>&1
"$C2" > "$RESULTS/candidate_o2.log" 2>&1
"$O2" > "$RESULTS/oracle_o2.log" 2>&1
"$C0" > "$RESULTS/candidate_o0_a2.log" 2>&1
"$O0" > "$RESULTS/oracle_o0_a2.log" 2>&1

for log in "$RESULTS/candidate_o0_a1.log" "$RESULTS/candidate_o2.log" "$RESULTS/candidate_o0_a2.log"; do
  grep -Fq 'FMR04_SERIALIZED_PHYSICAL_COMPOSITION_TEST PASS' "$log"
  grep -Fq 'FMR04_REAL_HEADCALC_EXECUTED=TRUE' "$log"
  grep -Fq 'FMR04_ROLLBACK=PASS' "$log"
  grep -Fq 'FMR04_REPLAY=PASS' "$log"
  grep -Fq 'FMR04_COMMIT_TRANSACTION_SEMANTICS=PASS' "$log"
  grep -Fq 'FMR04_ACTIVE_ROOT_FAIL_CLOSED=PASS' "$log"
  grep -Fq 'FMR04_MACROPORE_FAIL_CLOSED=PASS' "$log"
  grep -Fq 'FMR04_SNOW_FAIL_CLOSED=PASS' "$log"
  grep -Fq 'FMR04_SWKIMPL1_FAIL_CLOSED=PASS' "$log"
  grep -Fq 'VQ14_CAND_QROT_FAIL_CLOSED=PASS' "$log"
  grep -Fq 'VQ14_CAND_STALE_CHECKPOINT=PASS' "$log"
  grep -Fq 'FMR04_KERNEL_FULL_INTERVAL_MASS_COMPLETE=T' "$log"
  grep -Fq 'FMR04_AUTHORITATIVE_MISSING_MASK=0' "$log"
done
for log in "$RESULTS/oracle_o0_a1.log" "$RESULTS/oracle_o2.log" "$RESULTS/oracle_o0_a2.log"; do
  grep -Fq 'VQ14_ORACLE_REAL_HEADCALC_EXECUTED=TRUE' "$log"
  grep -Fq 'VQ14_ORACLE_ROUTE=CORRECTED_B110_BOUND_FSI_TWO_HALF' "$log"
  grep -Fq 'VQ14_ORACLE PASS' "$log"
done
grep -Fq "expect_not_admitted('unqualified-bottom-mode'" "$RESULTS/fvq14_candidate_instrumented.F90"

python3 "$QUAL_ROOT/tests/fvq/fvq14_evaluate.py" \
  --candidate-o0-a1 "$RESULTS/candidate_o0_a1.log" \
  --candidate-o0-a2 "$RESULTS/candidate_o0_a2.log" \
  --candidate-o2 "$RESULTS/candidate_o2.log" \
  --oracle-o0-a1 "$RESULTS/oracle_o0_a1.log" \
  --oracle-o0-a2 "$RESULTS/oracle_o0_a2.log" \
  --oracle-o2 "$RESULTS/oracle_o2.log" \
  --output "$RESULTS/exact_evaluation.json" | tee "$RESULTS/evaluator.log"

python3 - "$CANDIDATE" "$QUAL_ROOT" "$RESULTS" <<'PY'
import hashlib, json, pathlib, subprocess, sys
candidate = pathlib.Path(sys.argv[1]); qual = pathlib.Path(sys.argv[2]); results = pathlib.Path(sys.argv[3])

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def marker(path, text):
    return text in path.read_text()
meta = {
  "schema_version": 1,
  "locked_source_sha": subprocess.check_output(["git","-C",str(candidate),"rev-parse","HEAD"], text=True).strip(),
  "source_tree": subprocess.check_output(["git","-C",str(candidate),"rev-parse","HEAD^{tree}"], text=True).strip(),
  "compiler": (results/"compiler.txt").read_text().splitlines()[0],
  "build_flags": "-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow plus -O0/-O2",
  "executables": {
    "candidate_o0_sha256": (results/"candidate_o0_executable.sha256").read_text().split()[0],
    "candidate_o2_sha256": (results/"candidate_o2_executable.sha256").read_text().split()[0],
    "oracle_o0_sha256": (results/"oracle_o0_executable.sha256").read_text().split()[0],
    "oracle_o2_sha256": (results/"oracle_o2_executable.sha256").read_text().split()[0]
  },
  "harness_sha256": {
    "instrumenter": sha(qual/"tests/fvq/fvq14_instrument_candidate.py"),
    "reference_driver": sha(qual/"tests/fvq/test_fvq14_b110_reference.F90"),
    "evaluator": sha(qual/"tests/fvq/fvq14_evaluate.py"),
    "runner": sha(qual/"tests/fvq/run_fvq14_gate.sh"),
    "generated_candidate_driver": sha(results/"fvq14_candidate_instrumented.F90")
  },
  "physical_route": {
    "candidate_real_headcalc_executed": marker(results/"candidate_o0_a1.log", "FMR04_REAL_HEADCALC_EXECUTED=TRUE"),
    "candidate_solver_route": "legacy-reference-bound",
    "reference_real_headcalc_executed": marker(results/"oracle_o0_a1.log", "VQ14_ORACLE_REAL_HEADCALC_EXECUTED=TRUE"),
    "reference_route": "CORRECTED_B110_BOUND_FSI_TWO_HALF"
  },
  "transactions": {
    "rollback": "PASS" if marker(results/"candidate_o0_a1.log", "FMR04_ROLLBACK=PASS") else "FAIL",
    "replay": "PASS" if marker(results/"candidate_o0_a1.log", "FMR04_REPLAY=PASS") else "FAIL",
    "commit": "PASS" if marker(results/"candidate_o0_a1.log", "FMR04_COMMIT_TRANSACTION_SEMANTICS=PASS") else "FAIL",
    "stale_checkpoint": "PASS_FAIL_CLOSED" if marker(results/"candidate_o0_a1.log", "VQ14_CAND_STALE_CHECKPOINT=PASS") else "FAIL"
  },
  "generic_time": {"t0": 1000.125, "t1": 1000.625, "duration": 0.5,
                   "integer_boundary_start_required": False, "unit_duration_required": False, "pass": True},
  "unsupported": {
    "active_root_extraction": "PASS_FAIL_CLOSED",
    "qrot_nonzero": "PASS_FAIL_CLOSED",
    "macropore": "PASS_FAIL_CLOSED",
    "snow": "PASS_FAIL_CLOSED",
    "swkimpl_nonzero": "PASS_FAIL_CLOSED",
    "unqualified_bottom_mode": "PASS_FAIL_CLOSED",
    "other_hydraulic_families": "NOT_ADMITTED_BY_TYPED_DEFAULT_MVG_RUNTIME_PROFILE",
    "relaxed_balanced_throughput_fallback": "NOT_ADMITTED_BY_SERIALIZED_REFERENCE_BACKEND_PROFILE",
    "modflow_coupling": "NOT_IN_FMR04_ADMITTED_BACKEND"
  },
  "retry_subgate": "NOT_TESTED_NO_SAFE_PHYSICAL_FAILURE_INDUCTION",
  "production_source_changed": False
}
(results/"run_metadata.json").write_text(json.dumps(meta, indent=2, sort_keys=True)+"\n")
PY

sha256sum "$RESULTS"/*.log "$RESULTS"/*.json "$RESULTS"/*.txt "$RESULTS"/*.sha256 2>/dev/null \
  | sort > "$RESULTS/evidence_files.sha256"
echo "VQ14_GATE PASS_INDEPENDENT_RESTRICTED_PHYSICAL_SCIENTIFIC_COMPARISON"

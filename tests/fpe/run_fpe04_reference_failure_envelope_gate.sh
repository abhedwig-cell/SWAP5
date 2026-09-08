#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fpe04-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

check_blob() {
  local path="$1" expected="$2" actual
  actual="$(git hash-object "$path")"
  [[ "$actual" == "$expected" ]] || {
    echo "FPE04_BLOB_MISMATCH $path expected=$expected actual=$actual" >&2
    exit 1
  }
}

check_blob src/kernel/mod_kernel_transactions.f90 af42c7d51ef545e20c76d3000f1ed1493690d68e
check_blob src/runtime/mod_fmr_serialized_multiswap_runtime.f90 940fa6deb461443dd7b5993038a9a2fbbb434e36
check_blob src/runtime/mod_fmr_serialized_reference_backend.f90 ade399a1df4b582c9038442093ccacce034f923d
check_blob src/adapter/mod_reference_richards_legacy_binding.f90 eb4b74ee422bc331ed3d6abaa40dd9f85b2551c0
check_blob src/legacy/b1_10_port/headcalc.f90 be5978827095445b15de7baf607728792de6a366
check_blob src/solver/mod_soil_water_solver_contract.f90 57b51997d28807fbe2da1b2e5bf654fc4167adb9
check_blob src/solver/mod_reference_richards_workspace.f90 93285b2ca24669494c93c00403e3783fca6758e9
check_blob src/solver/mod_reference_richards_state_binding.f90 e68d88382c6502c571713cc97fddd4e18434e271
check_blob src/solver/mod_b110_default_mvg_provider.f90 97d67eb373073b183be6d1bf5b756ecb5125dde2
check_blob src/solver/mod_b110_source_sink_provider.f90 d6c57add72387e5c0022a44319fff08046194aac
check_blob src/transaction/mod_transaction_reference.f90 b1878606ae6cb2b04a7b4b15e3e537deacf4477f
check_blob src/runtime/mod_canonical_contracts.f90 0c2b15fc45011c580384cf6a618e7b378fdccf0a
check_blob src/runtime/mod_canonical_interval_runtime.f90 f2cae79d533343db818c11e0b61b605ac5f6739d
check_blob tests/fsi/fsi04_real_headcalc_stubs.f90 23c00e4a188e88bc36ef95cbe4faaacdd6aad639
check_blob tests/fmr/mod_fmr04_fixed_top_provider.f90 942c56e3ba2b1739506e1d5b0ac889e6fd163ea7

echo 'FPE04_EXACT_REFERENCE_SOURCE_PREIMAGE=PASS'

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
MODULE_SRC=(
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
  src/runtime/mod_fmr_serialized_multiswap_runtime.f90
  tests/fmr/mod_fmr04_fixed_top_provider.f90
)

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  objects=()
  for src in "${MODULE_SRC[@]}"; do
    obj="$OUT/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fpe/test_fpe04_reference_failure_envelope.f90 -o "$OUT/test_fpe04.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test_fpe04.o" -o "$OUT/fpe04_reference_failure_envelope"
  "$OUT/fpe04_reference_failure_envelope" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; exit 1; }
  grep -Fq 'FPE04_REFERENCE_FAILURE_ENVELOPE CHARACTERIZATION_PASS' "$OUT/output.txt"
  grep -Fq 'FPE04_REPLAY_DETERMINISM=PASS' "$OUT/output.txt"
  grep -Fq 'FPE04_TRANSACTION_MASS_SAFETY=PASS' "$OUT/output.txt"
  grep -Fq 'FPE04_FAIL_CLOSED_PRE_SOLVER=1' "$OUT/output.txt"
  grep -Fq 'FPE04_BALANCED=DEFINED_NOT_ADMITTED' "$OUT/output.txt"
  grep -Fq 'FPE04_THROUGHPUT=DEFINED_NOT_ADMITTED' "$OUT/output.txt"
  grep -Fq 'FPE04_FALLBACK=DEFINED_NOT_ADMITTED' "$OUT/output.txt"
  echo "FPE04_O${opt}_EXECUTABLE_SHA256=$(sha256sum "$OUT/fpe04_reference_failure_envelope" | cut -d' ' -f1)"
  echo "FPE04_O${opt}_OUTPUT_SHA256=$(sha256sum "$OUT/output.txt" | cut -d' ' -f1)"
  echo "FPE04_O${opt}=PASS"
done

cat "$BUILD/o0/output.txt"
if cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"; then
  echo 'FPE04_O0_O2_OUTPUT_IDENTITY=PASS'
else
  echo 'FPE04_O0_O2_OUTPUT_IDENTITY=FAIL'
  diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" | head -200 || true
  exit 1
fi

echo 'FPE04_REFERENCE_FAILURE_ENVELOPE_GATE=PASS_CHARACTERIZATION_ONLY'

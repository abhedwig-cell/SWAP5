#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fkt22-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"
fail(){ echo "FKT22_QUALIFICATION_FAIL $*" >&2; exit 1; }

# F-KT22 is an exposure/composition capability.  It inherits the exact F-KT21
# trajectory mathematics and must not silently modify its numerical primitives.
[[ "$(git rev-parse HEAD:src/transaction/mod_accepted_trajectory_directional_sensitivity.f90)" == 95381d3124b185aa0fbafd1ea3da6179a841deda ]] || fail 'F-KT21 trajectory composer drift'
[[ "$(git rev-parse HEAD:src/transaction/mod_accepted_trajectory_directional_publication.f90)" == 31bc721f333a77c52f6530b357af44c627f44629 ]] || fail 'F-KT21 publication drift'
[[ "$(git rev-parse HEAD:src/transaction/mod_transaction_reference.f90)" == d5a71a526efaebd82054580c3186f8e3545db331 ]] || fail 'transaction core drift'

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
run_one(){
  local opt="$1"
  local tag="$2"
  local out="$BUILD/$tag"
  mkdir -p "$out"

  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c src/transaction/mod_transaction_reference.f90 -o "$out/transaction.o"
  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c src/runtime/mod_canonical_contracts.f90 -o "$out/contracts.o"
  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c src/runtime/mod_canonical_interval_runtime.f90 -o "$out/runtime.o"
  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c src/kernel/mod_kernel_transactions.f90 -o "$out/kernel.o"

  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c tests/fkt/test_fkt22_canonical_directional_response.f90 -o "$out/canonical_test.o"
  gfortran "$opt" "$out/transaction.o" "$out/contracts.o" "$out/runtime.o" "$out/canonical_test.o" -o "$out/test_fkt22_canonical"
  "$out/test_fkt22_canonical" | tee "$out/canonical_output.txt"

  grep -Fq 'FKT22_CANONICAL_DIRECTIONAL_RESPONSE PASS' "$out/canonical_output.txt" || fail "canonical response PASS missing $tag"
  grep -Fq 'FKT22_MULTI_TRANSACTION_WHOLE_WINDOW=PASS' "$out/canonical_output.txt" || fail "multi-transaction marker missing $tag"
  grep -Fq 'FKT22_FAILURE_NO_PUBLICATION=PASS' "$out/canonical_output.txt" || fail "failure publication marker missing $tag"
  grep -Fq 'FKT22_OUTER_LIFECYCLE_ONCE=PASS' "$out/canonical_output.txt" || fail "outer lifecycle marker missing $tag"

  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c tests/fkt/test_fkt22_kernel_directional_response.f90 -o "$out/kernel_test.o"
  gfortran "$opt" "$out/transaction.o" "$out/contracts.o" "$out/runtime.o" "$out/kernel.o" "$out/kernel_test.o" -o "$out/test_fkt22_kernel"
  "$out/test_fkt22_kernel" | tee "$out/kernel_output.txt"

  grep -Fq 'FKT22_KERNEL_DIRECTIONAL_RESPONSE PASS' "$out/kernel_output.txt" || fail "kernel response PASS missing $tag"
  grep -Fq 'FKT22_KERNEL_REQUEST_FORWARDING=PASS' "$out/kernel_output.txt" || fail "kernel request marker missing $tag"
  grep -Fq 'FKT22_KERNEL_RESULT_MAPPING=PASS' "$out/kernel_output.txt" || fail "kernel result marker missing $tag"

  cat "$out/canonical_output.txt" "$out/kernel_output.txt" | grep '^FKT22_' > "$out/stable.txt"
  echo "FKT22_OPT_PASS=$tag"
}

run_one -O0 o0
run_one -O2 o2
cmp "$BUILD/o0/stable.txt" "$BUILD/o2/stable.txt" || fail 'O0/O2 marker drift'

# B1.10 must override the generic lifecycle explicitly and use only the already
# qualified F-KT21 immutable publication.  This guards architecture ownership;
# executable B1.10 compilation is exercised by the broader repository gates.
grep -Fq 'procedure :: begin_directional_response => b1_10_begin_canonical_directional_response' src/adapter/mod_b1_10_reference_model.f90 || fail 'B1.10 begin override missing'
grep -Fq 'procedure :: finish_directional_response => b1_10_finish_canonical_directional_response' src/adapter/mod_b1_10_reference_model.f90 || fail 'B1.10 finish override missing'
grep -Fq 'call publish_accepted_trajectory_direction' src/adapter/mod_b1_10_reference_model.f90 || fail 'F-KT21 immutable publication not reused'
grep -Fq 'canonical-window-provenance-mismatch' src/adapter/mod_b1_10_reference_model.f90 || fail 'whole-window provenance guard missing'
grep -Fq 'call self%configure_trajectory_direction(.false.' src/adapter/mod_b1_10_reference_model.f90 || fail 'worker scratch cleanup missing'

# Preserve F-CI66 optional execution-policy selector on the composition branch.
grep -Fq 'canonical_subinterval_target_selector' src/runtime/mod_canonical_interval_runtime.f90 || fail 'F-CI66 selector missing'
grep -Fq 'transaction_policy%max_retries = min(config%transaction%max_retries, max_retries_cap)' src/runtime/mod_canonical_interval_runtime.f90 || fail 'F-CI66 retry tightening missing'

# Kernel exposure must be additive: old calls remain valid, while an explicit
# optional request is forwarded to canonical and the immutable response is
# copied into kernel_result_t for GC and other coupling owners.
grep -Fq 'type(canonical_directional_response_t) :: directional_response' src/kernel/mod_kernel_transactions.f90 || fail 'kernel result carrier missing'
grep -Fq 'type(canonical_directional_response_request_t), intent(in), optional :: directional_request' src/kernel/mod_kernel_transactions.f90 || fail 'kernel optional request missing'
grep -Fq 'directional_request=directional_request' src/kernel/mod_kernel_transactions.f90 || fail 'kernel request forwarding missing'
grep -Fq 'result%directional_response = runtime_result%directional_response' src/kernel/mod_kernel_transactions.f90 || fail 'kernel result mapping missing'

# Re-run inherited F-KT21 owner qualification unchanged.  F-KT22 may expose the
# result but may not weaken the underlying accepted-trajectory authority.
bash tests/fkt/run_fkt21_qualification.sh > "$BUILD/fkt21.txt"
grep -Fq 'FKT21_QUALIFICATION PASS' "$BUILD/fkt21.txt" || fail 'inherited F-KT21 gate failed'

echo 'FKT22_KERNEL_CARRIER=PASS'
echo 'FKT22_FCI66_PRESERVATION=PASS'
echo 'FKT22_FKT21_INHERITED_GATE=PASS'
echo 'FKT22_O0_O2_GATE=PASS'
echo 'FKT22_QUALIFICATION PASS'

#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fkt22p-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"
fail(){ echo "FKT22P_QUALIFICATION_FAIL $*" >&2; exit 1; }

# F-KT22P is composition only. Pin the already-qualified generic carrier and
# trajectory primitives; any drift requires upstream requalification rather
# than silently widening this production-exposure capability.
[[ "$(git rev-parse HEAD:src/transaction/mod_transaction_reference.f90)" == d5a71a526efaebd82054580c3186f8e3545db331 ]] || fail 'transaction core drift'
[[ "$(git rev-parse HEAD:src/runtime/mod_canonical_contracts.f90)" == 6fece30153ac5e10cc8290e920f9eb78be7f863e ]] || fail 'F-KT22 contract drift'
[[ "$(git rev-parse HEAD:src/runtime/mod_canonical_interval_runtime.f90)" == 936ce68f9708a23292d08bf03f2b8f181570298d ]] || fail 'F-KT22 canonical runtime drift'
[[ "$(git rev-parse HEAD:src/kernel/mod_kernel_transactions.f90)" == ea4c0cf15144e898ef6cf4b2abea4e27121cbbd8 ]] || fail 'F-KT22 kernel carrier drift'
[[ "$(git rev-parse HEAD:src/transaction/mod_accepted_trajectory_directional_sensitivity.f90)" == 95381d3124b185aa0fbafd1ea3da6179a841deda ]] || fail 'F-KT21 trajectory composer drift'
[[ "$(git rev-parse HEAD:src/transaction/mod_accepted_trajectory_directional_publication.f90)" == 31bc721f333a77c52f6530b357af44c627f44629 ]] || fail 'F-KT21 publication drift'
[[ "$(git rev-parse HEAD:src/runtime/mod_fmr_checkpoint_orchestrator.f90)" == 71929ce646773bbf941dd986381c0f6804511147 ]] || fail 'FMR forwarding seam drift'

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
  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c src/runtime/mod_fmr_checkpoint_orchestrator.f90 -o "$out/fmr.o"
  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c tests/fkt22p/test_fkt22p_fmr_directional_forwarding.f90 -o "$out/test.o"
  gfortran "$opt" "$out/transaction.o" "$out/contracts.o" "$out/runtime.o" "$out/kernel.o" "$out/fmr.o" "$out/test.o" -o "$out/test_fkt22p"
  "$out/test_fkt22p" | tee "$out/output.txt"

  grep -Fq 'FKT22P_FMR_DIRECTIONAL_FORWARDING PASS' "$out/output.txt" || fail "forwarding PASS missing $tag"
  grep -Fq 'FKT22P_REQUEST_FORWARDING=PASS' "$out/output.txt" || fail "request forwarding missing $tag"
  grep -Fq 'FKT22P_WHOLE_WINDOW_RESULT=PASS' "$out/output.txt" || fail "whole-window result missing $tag"
  grep -Fq 'FKT22P_LEGACY_PATH_IDENTITY=PASS' "$out/output.txt" || fail "legacy identity missing $tag"
  grep -Fq 'FKT22P_TRIAL_ONLY_NO_PUBLICATION=PASS' "$out/output.txt" || fail "trial-only marker missing $tag"
  grep '^FKT22P_' "$out/output.txt" > "$out/stable.txt"
  echo "FKT22P_OPT_PASS=$tag"
}

run_one -O0 o0
run_one -O2 o2
cmp "$BUILD/o0/stable.txt" "$BUILD/o2/stable.txt" || fail 'O0/O2 marker drift'

# The production seam must remain additive and optional.
grep -Fq 'type(canonical_directional_response_request_t), intent(in), optional :: directional_request' src/runtime/mod_fmr_checkpoint_orchestrator.f90 || fail 'optional directional request missing'
grep -Fq 'result, candidate_state, diagnostics, checkpoint, directional_request)' src/runtime/mod_fmr_checkpoint_orchestrator.f90 || fail 'directional request not forwarded'

# Current-canonical F-CI66 execution-policy semantics are part of the pinned
# carrier blob and must remain present in the composed production runtime.
grep -Fq 'canonical_subinterval_target_selector' src/runtime/mod_canonical_interval_runtime.f90 || fail 'F-CI66 selector missing'
grep -Fq 'transaction_policy%max_retries = min(config%transaction%max_retries, max_retries_cap)' src/runtime/mod_canonical_interval_runtime.f90 || fail 'F-CI66 retry tightening missing'

echo 'FKT22P_GENERIC_KT22_INHERITED=PASS'
echo 'FKT22P_FCI66_PRESERVATION=PASS'
echo 'FKT22P_O0_O2_GATE=PASS'
echo 'FKT22P_QUALIFICATION PASS'

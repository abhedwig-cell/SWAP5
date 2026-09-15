#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fkt21-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"
fail(){ echo "FKT21_QUALIFICATION_FAIL $*" >&2; exit 1; }

# Exact F-SI37 owner-qualified primitive dependency.
[[ "$(git rev-parse HEAD:src/solver/mod_soil_water_accepted_step_direction_contract.f90)" == 52698b1ad2350bf787862a053a49c7c73c3358f0 ]] || fail 'F-SI37 direction contract drift'
[[ "$(git rev-parse HEAD:src/solver/mod_b110_default_mvg_directional_provider.f90)" == b1e794d2f0e661a2abb14280a59175e1cf1d5724 ]] || fail 'F-SI37 constitutive directional provider drift'
[[ "$(git rev-parse HEAD:src/adapter/mod_b110_dynamic_top_boundary_directional_adapter.f90)" == 0a957376b9a9fdea00ab6009f129803fb5341e4a ]] || fail 'F-SI37 dynamic-top directional adapter drift'
[[ "$(git rev-parse HEAD:src/adapter/mod_reference_richards_accepted_step_directional_service.f90)" == ef395ac3fb0cf6f347031bf2081a74b74b5167ae ]] || fail 'F-SI37 accepted-step service drift'

# F-KT21 composes around the canonical transaction engine; it does not replace
# or silently alter generic transaction acceptance semantics.
[[ "$(git rev-parse HEAD:src/transaction/mod_transaction_reference.f90)" == d5a71a526efaebd82054580c3186f8e3545db331 ]] || fail 'canonical transaction core drift'

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
run_one(){
  local opt="$1"
  local tag="$2"
  local out="$BUILD/$tag"
  mkdir -p "$out"

  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c src/solver/mod_soil_water_accepted_step_direction_contract.f90 -o "$out/contract.o"
  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c src/transaction/mod_accepted_trajectory_directional_sensitivity.f90 -o "$out/trajectory.o"
  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c src/transaction/mod_accepted_trajectory_directional_publication.f90 -o "$out/publication.o"

  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c tests/fkt/test_fkt21_accepted_trajectory_direction.f90 -o "$out/test.o"
  gfortran "$opt" "$out/contract.o" "$out/trajectory.o" "$out/test.o" -o "$out/test_fkt21"
  "$out/test_fkt21" | tee "$out/output.txt"
  grep -Fq 'FKT21_ACCEPTED_TRAJECTORY_DIRECTION PASS' "$out/output.txt" || fail "PASS marker missing $tag"
  grep -Fq 'FKT21_MODE2_MODE5=PASS' "$out/output.txt" || fail "mode marker missing $tag"
  grep -Fq 'FKT21_WHOLE_TRAJECTORY_CENTERED_FD=PASS' "$out/output.txt" || fail "FD marker missing $tag"
  grep -Fq 'FKT21_REJECT_RETRY=PASS' "$out/output.txt" || fail "retry marker missing $tag"
  grep -Fq 'FKT21_RETRY_EXHAUSTION_NO_PUBLICATION=PASS' "$out/output.txt" || fail "retry exhaustion marker missing $tag"
  grep -Fq 'FKT21_UNAVAILABLE_STEP_FAIL_CLOSED=PASS' "$out/output.txt" || fail "unavailable marker missing $tag"
  grep -Fq 'FKT21_STALE_CROSS_CANDIDATE_REJECTED=PASS' "$out/output.txt" || fail "stale marker missing $tag"
  grep -Fq 'FKT21_NON_DAY_ALIGNED_INTERVAL=PASS' "$out/output.txt" || fail "generic time marker missing $tag"
  grep -Fq 'FKT21_EXCHANGE_DERIVATIVE_ACCUMULATION=PASS' "$out/output.txt" || fail "exchange accumulation marker missing $tag"
  grep -Fq 'FKT21_BOUNDED_COST=PASS' "$out/output.txt" || fail "cost marker missing $tag"

  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c tests/fkt/test_fkt21_provenance.f90 -o "$out/provenance.o"
  gfortran "$opt" "$out/contract.o" "$out/trajectory.o" "$out/provenance.o" -o "$out/test_fkt21_provenance"
  "$out/test_fkt21_provenance" | tee "$out/provenance_output.txt"
  grep -Fq 'FKT21_PROVENANCE_HARDENING PASS' "$out/provenance_output.txt" || fail "provenance PASS marker missing $tag"
  grep -Fq 'FKT21_CROSS_CANDIDATE_GENERATION=PASS' "$out/provenance_output.txt" || fail "cross-candidate marker missing $tag"
  grep -Fq 'FKT21_STEP_ENDPOINT_TOKEN_BINDING=PASS' "$out/provenance_output.txt" || fail "endpoint binding marker missing $tag"
  grep -Fq 'FKT21_NONMONOTONE_GENERATION_REJECTED=PASS' "$out/provenance_output.txt" || fail "generation marker missing $tag"

  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c tests/fkt/test_fkt21_publication_identity.f90 -o "$out/publication_test.o"
  gfortran "$opt" "$out/contract.o" "$out/trajectory.o" "$out/publication.o" "$out/publication_test.o" -o "$out/test_fkt21_publication"
  "$out/test_fkt21_publication" | tee "$out/publication_output.txt"
  grep -Fq 'FKT21_PUBLICATION_IDENTITY PASS' "$out/publication_output.txt" || fail "publication PASS marker missing $tag"
  grep -Fq 'FKT21_ON_OFF_PHYSICAL_IDENTITY=PASS' "$out/publication_output.txt" || fail "ON/OFF identity marker missing $tag"
  grep -Fq 'FKT21_TYPED_RESULT_PROVENANCE=PASS' "$out/publication_output.txt" || fail "typed result marker missing $tag"
  grep -Fq 'FKT21_UNAVAILABLE_PHYSICAL_VALID=PASS' "$out/publication_output.txt" || fail "unavailable physical-valid marker missing $tag"
  grep -Fq 'FKT21_REJECTED_DERIVATIVE_ZERO=PASS' "$out/publication_output.txt" || fail "rejected derivative marker missing $tag"
  grep -Fq 'FKT21_MASS_NEUTRALITY=PASS' "$out/publication_output.txt" || fail "mass-neutrality marker missing $tag"

  # Real worker acceptance lifecycle: a task-2 retry drops pending direction;
  # the existing SoilWater task-3 boundary promotes exactly one accepted step.
  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c src/runtime/mod_a23bu_worker_execution_context.f90 -o "$out/worker.o"
  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c tests/fkt/test_fkt21_worker_acceptance_binding.f90 -o "$out/worker_test.o"
  gfortran "$opt" "$out/contract.o" "$out/trajectory.o" "$out/worker.o" "$out/worker_test.o" -o "$out/test_fkt21_worker"
  "$out/test_fkt21_worker" | tee "$out/worker_output.txt"
  grep -Fq 'FKT21_WORKER_RETRY_DISCARD=PASS' "$out/worker_output.txt" || fail "worker retry discard missing $tag"
  grep -Fq 'FKT21_TASK3_ACCEPT_BINDING=PASS' "$out/worker_output.txt" || fail "task3 accept marker missing $tag"
  grep -Fq 'FKT21_WORKER_ACCEPTANCE_BINDING PASS' "$out/worker_output.txt" || fail "worker binding PASS missing $tag"

  # Immutable accepted-result publication must be bound to exactly one accepted
  # transaction and the same accepted [t0,t1] provenance.
  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c src/transaction/mod_transaction_reference.f90 -o "$out/transaction.o"
  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c src/transaction/mod_accepted_trajectory_transaction_binding.f90 -o "$out/tx_binding.o"
  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c tests/fkt/test_fkt21_transaction_binding.f90 -o "$out/tx_binding_test.o"
  gfortran "$opt" "$out/contract.o" "$out/trajectory.o" "$out/publication.o" "$out/transaction.o" "$out/tx_binding.o" "$out/tx_binding_test.o" -o "$out/test_fkt21_tx_binding"
  "$out/test_fkt21_tx_binding" | tee "$out/tx_binding_output.txt"
  grep -Fq 'FKT21_ACCEPTED_TRANSACTION_BINDING=PASS' "$out/tx_binding_output.txt" || fail "accepted transaction binding missing $tag"
  grep -Fq 'FKT21_SHORTENED_INTERVAL_NOT_RELABELLED=PASS' "$out/tx_binding_output.txt" || fail "shortened interval marker missing $tag"
  grep -Fq 'FKT21_RETRY_EXHAUSTION_TRANSACTION_NO_PUBLICATION=PASS' "$out/tx_binding_output.txt" || fail "transaction retry exhaustion marker missing $tag"
  grep -Fq 'FKT21_TRANSACTION_PROVENANCE_MISMATCH_REJECTED=PASS' "$out/tx_binding_output.txt" || fail "transaction provenance marker missing $tag"
  grep -Fq 'FKT21_TRANSACTION_INTERVAL_GUARD=PASS' "$out/tx_binding_output.txt" || fail "transaction interval guard missing $tag"
  grep -Fq 'FKT21_TRANSACTION_BINDING PASS' "$out/tx_binding_output.txt" || fail "transaction binding PASS missing $tag"

  echo "FKT21_OPT_PASS=$tag"
}
run_one -O0 o0
run_one -O2 o2

{
  grep '^FKT21_' "$BUILD/o0/output.txt"
  grep '^FKT21_' "$BUILD/o0/provenance_output.txt"
  grep '^FKT21_' "$BUILD/o0/publication_output.txt"
  grep '^FKT21_' "$BUILD/o0/worker_output.txt"
  grep '^FKT21_' "$BUILD/o0/tx_binding_output.txt"
} > "$BUILD/o0/stable.txt"
{
  grep '^FKT21_' "$BUILD/o2/output.txt"
  grep '^FKT21_' "$BUILD/o2/provenance_output.txt"
  grep '^FKT21_' "$BUILD/o2/publication_output.txt"
  grep '^FKT21_' "$BUILD/o2/worker_output.txt"
  grep '^FKT21_' "$BUILD/o2/tx_binding_output.txt"
} > "$BUILD/o2/stable.txt"
cmp "$BUILD/o0/stable.txt" "$BUILD/o2/stable.txt" || fail 'O0/O2 marker drift'

# Production-seam ownership guards. These do not replace executable tests; they
# ensure later refactors cannot silently detach the qualified primitive from the
# existing physical acceptance/retry and outer transaction boundaries.
grep -Fq 'a23bu_accept_pending_trajectory_step(worker)' src/legacy/b1_10_port/soilwater.f90 || fail 'SoilWater task3 trajectory acceptance binding missing'
grep -Fq 'call a23bu_discard_unaccepted_trajectory_step(worker)' src/adapter/mod_b110_production_soil_water_task2.f90 || fail 'task2 retry discard binding missing'
grep -Fq 'call solve_with_accepted_step_direction' src/adapter/mod_b110_production_soil_water_task2.f90 || fail 'F-SI37 production step-direction service binding missing'
grep -Fq 'call stage_trajectory_step_result' src/adapter/mod_b110_production_soil_water_task2.f90 || fail 'task2 trajectory staging missing'
grep -Fq 'request%request_interface_sensitivity = sensitivity_route_admitted .and. .not. trajectory_requested' src/adapter/mod_b110_production_soil_water_task2.f90 || fail 'local-terminal/trajectory semantic exclusion missing'
grep -Fq 'trajectory_generation_counter' src/adapter/mod_b1_10_reference_model.f90 || fail 'monotone trajectory generation missing'
grep -Fq 'capture_attempt_context => b1_10_reference_capture_attempt_context' src/adapter/mod_b1_10_reference_model.f90 || fail 'outer attempt-context trajectory capture missing'
grep -Fq 'call self%prepare_trajectory_segment(t0, t1)' src/adapter/mod_b1_10_recoverable_reference_model.f90 || fail 'recoverable trajectory preparation missing'
grep -Fq 'call self%finalize_trajectory_segment(t1)' src/adapter/mod_b1_10_recoverable_reference_model.f90 || fail 'recoverable trajectory finalization missing'
grep -Fq 'call execute_reference_interval' src/adapter/mod_b1_10_accepted_trajectory_transaction_executor.f90 || fail 'atomic transaction executor missing'
grep -Fq 'call bind_accepted_trajectory_to_transaction' src/adapter/mod_b1_10_accepted_trajectory_transaction_executor.f90 || fail 'accepted transaction publication binding missing'

# Composition code may not introduce production finite-difference solves or
# persistent SAVE state. F-SI37 uses one accepted factorization backsolve only.
if grep -Eiq 'finite.?difference|perturb.*solve' src/transaction/mod_accepted_trajectory_directional_sensitivity.f90 src/transaction/mod_accepted_trajectory_directional_publication.f90 src/transaction/mod_accepted_trajectory_transaction_binding.f90; then fail 'FD production construction detected'; fi
if grep -Eiq 'save[[:space:]]*::|save[[:space:]]+[a-zA-Z_]' src/transaction/mod_accepted_trajectory_directional_sensitivity.f90 src/transaction/mod_accepted_trajectory_directional_publication.f90 src/transaction/mod_accepted_trajectory_transaction_binding.f90 src/adapter/mod_b1_10_accepted_trajectory_transaction_executor.f90; then fail 'persistent SAVE state detected'; fi

echo 'FKT21_REAL_ACCEPTANCE_BINDING=PASS'
echo 'FKT21_O0_O2_GATE=PASS'
echo 'FKT21_QUALIFICATION PASS'

#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-pub-me-d2-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail() { echo "PUB_ME_D2_GATE_FAIL $*" >&2; exit 1; }

EXECUTION_BASE=dba238b4b20551dcc36e9121ffe25f19a5b1ac0e
DESIGN_HEAD=b2ebe5825b3c54d9d4eaefe44c33f4c859fa20aa
DESIGN_BLOB=61f7133f19cc900971aa454b7bdb16a254468eda
DESIGN_PATH=docs/publications/PUB-ME_D1_D6_PREREGISTERED_EXPERIMENT_MATRIX.md
CHECKPOINT=docs/publications/PUB-ME_D2_EXECUTION_CHECKPOINT.md
TEST=tests/publication/test_pub_me_d2_retry_accounting.f90

for path in "$CHECKPOINT" "$TEST" tests/publication/run_pub_me_d2_retry_accounting.sh; do
  [[ -f "$path" ]] || fail "missing D2 workunit file $path"
done

git diff --check "$EXECUTION_BASE"...HEAD -- "$CHECKPOINT" "$TEST"   tests/publication/run_pub_me_d2_retry_accounting.sh || fail 'D2 diff check'
[[ -z "$(git diff --name-only "$EXECUTION_BASE"...HEAD -- src reference)" ]] ||   fail 'D2 changed production/reference source'

git fetch --quiet --no-tags origin "$DESIGN_HEAD" || fail 'cannot fetch preregistered design authority'
actual_design_blob="$(git rev-parse "$DESIGN_HEAD:$DESIGN_PATH" 2>/dev/null || true)"
[[ "$actual_design_blob" == "$DESIGN_BLOB" ]] ||   fail "preregistered D1-D6 design blob drift: $actual_design_blob"

echo "PUB_ME_D2_PREREGISTRATION_HEAD=$DESIGN_HEAD"
echo "PUB_ME_D2_PREREGISTRATION_BLOB=$actual_design_blob"
echo 'PUB_ME_D2_PREREGISTRATION_BINDING=PASS'

TX=src/transaction/mod_transaction_reference.f90
STEPDIR=src/solver/mod_soil_water_accepted_step_direction_contract.f90
TRAJ=src/transaction/mod_accepted_trajectory_directional_sensitivity.f90
TRAJPUB=src/transaction/mod_accepted_trajectory_directional_publication.f90
CONTRACTS=src/runtime/mod_canonical_contracts.f90
WORKER=src/runtime/mod_a23bu_worker_execution_context.f90
TRIAL=src/adapter/mod_b1_10_trial_mass.f90
INTERVAL=src/adapter/mod_b1_10_interval_seam.f90
BASE=src/adapter/mod_b1_10_transaction_binding.f90
MASS=src/adapter/mod_b1_10_mass_seam.f90
TEMPORAL=src/adapter/mod_b1_10_temporal_characterization.f90
FCI12_EXEC=src/adapter/mod_b1_10_physical_interval_executor.f90
FCI12_REF=src/adapter/mod_b1_10_reference_model.f90
STATUS=src/adapter/mod_b1_10_trial_status.f90
FCI13_EXEC=src/adapter/mod_b1_10_recoverable_interval_executor.f90
FCI13_REF=src/adapter/mod_b1_10_recoverable_reference_model.f90
POLICY=src/adapter/mod_b1_10_reference_temporal_policy.f90
MODEL=src/adapter/mod_b1_10_reference_policy_candidate_model.f90
STUBS=tests/fci/fci14_reference_policy_stubs.f90

for opt in 0 2; do
  O="$BUILD/o$opt"
  DEP_FLAGS=(-O"$opt" -std=f2008 -Wall -Wextra -Werror -Wno-error=compare-reals -fcheck=all -fbacktrace -ffree-line-length-none -J "$O" -I "$O")
  TEST_FLAGS=(-O"$opt" -std=f2008 -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffree-line-length-none -J "$O" -I "$O")

  gfortran "${DEP_FLAGS[@]}" -c "$TX" -o "$O/transaction.o"
  gfortran "${DEP_FLAGS[@]}" -c "$STEPDIR" -o "$O/stepdir.o"
  gfortran "${DEP_FLAGS[@]}" -c "$TRAJ" -o "$O/trajectory.o"
  gfortran "${DEP_FLAGS[@]}" -c "$TRAJPUB" -o "$O/trajectory_publication.o"
  gfortran "${DEP_FLAGS[@]}" -c "$CONTRACTS" -o "$O/contracts.o"
  gfortran "${DEP_FLAGS[@]}" -c "$WORKER" -o "$O/worker.o"
  gfortran "${DEP_FLAGS[@]}" -c "$TRIAL" -o "$O/trial_mass.o"
  gfortran "${DEP_FLAGS[@]}" -c "$INTERVAL" -o "$O/interval.o"
  gfortran "${DEP_FLAGS[@]}" -c "$STUBS" -o "$O/stubs.o"
  gfortran "${DEP_FLAGS[@]}" -c "$BASE" -o "$O/base_binding.o"
  gfortran "${DEP_FLAGS[@]}" -c "$MASS" -o "$O/mass_seam.o"
  gfortran "${DEP_FLAGS[@]}" -c "$TEMPORAL" -o "$O/temporal.o"
  gfortran "${DEP_FLAGS[@]}" -c "$FCI12_EXEC" -o "$O/fci12_executor.o"
  gfortran "${DEP_FLAGS[@]}" -c "$FCI12_REF" -o "$O/fci12_reference.o"
  gfortran "${DEP_FLAGS[@]}" -c "$STATUS" -o "$O/status.o"
  gfortran "${DEP_FLAGS[@]}" -c "$FCI13_EXEC" -o "$O/fci13_executor.o"
  gfortran "${DEP_FLAGS[@]}" -c "$FCI13_REF" -o "$O/fci13_reference.o"
  gfortran "${DEP_FLAGS[@]}" -c "$POLICY" -o "$O/policy.o"
  gfortran "${DEP_FLAGS[@]}" -c "$MODEL" -o "$O/model.o"
  gfortran "${TEST_FLAGS[@]}" -c "$TEST" -o "$O/test.o"

  gfortran -O"$opt" -o "$O/test_d2"     "$O/transaction.o" "$O/stepdir.o" "$O/trajectory.o" "$O/trajectory_publication.o" "$O/contracts.o" "$O/worker.o" "$O/trial_mass.o" "$O/interval.o"     "$O/stubs.o" "$O/base_binding.o" "$O/mass_seam.o" "$O/temporal.o"     "$O/fci12_executor.o" "$O/fci12_reference.o" "$O/status.o" "$O/fci13_executor.o"     "$O/fci13_reference.o" "$O/policy.o" "$O/model.o" "$O/test.o"

  if ! "$O/test_d2" > "$O/output.txt" 2>&1; then
    cat "$O/output.txt" >&2
    fail "D2 experiment O$opt"
  fi

  for marker in     'PUB_ME_D2_CLEAN_TEMPORAL_REJECTIONS=1'     'PUB_ME_D2_MUTANT_TEMPORAL_REJECTIONS=1'     'PUB_ME_D2_B2_RETRY_ENTRY_DETECTED=T'     'PUB_ME_D2_RETRY_ACCOUNTING_EXPERIMENT=PASS'; do
    grep -Fq "$marker" "$O/output.txt" || {
      cat "$O/output.txt" >&2
      fail "missing O$opt marker $marker"
    }
  done

  classification="$(grep -F 'PUB_ME_D2_CLASSIFICATION=' "$O/output.txt" | tail -1 | cut -d= -f2)"
  case "$classification" in
    EARLIER_DETECTION|UNIQUE_DETECTION|NO_INCREMENTAL_VALUE|STRUCTURAL_PREVENTION) ;;
    *) cat "$O/output.txt" >&2; fail "unexpected D2 classification $classification" ;;
  esac

  cat "$O/output.txt"
  echo "PUB_ME_D2_O${opt}=PASS"
done

cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || {
  diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true
  fail 'D2 O0/O2 semantic drift'
}

echo "PUB_ME_D2_O0_O2_SHA256=$(sha256sum "$BUILD/o0/output.txt" | awk '{print $1}')"
echo 'PUB_ME_D2_GATE=PASS'

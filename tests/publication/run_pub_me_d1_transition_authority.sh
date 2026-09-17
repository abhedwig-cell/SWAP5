#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-pub-me-d1-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail() { echo "PUB_ME_D1_GATE_FAIL $*" >&2; exit 1; }

EXECUTION_BASE=d0a41c39d7ff95db99bcf8360ac9b474fdf164d7
DESIGN_HEAD=b2ebe5825b3c54d9d4eaefe44c33f4c859fa20aa
DESIGN_BLOB=61f7133f19cc900971aa454b7bdb16a254468eda
DESIGN_PATH=docs/publications/PUB-ME_D1_D6_PREREGISTERED_EXPERIMENT_MATRIX.md
POSITIVE=tests/publication/test_pub_me_d1_clone_isolation.f90
NEGATIVE=tests/publication/test_pub_me_d1_illegal_write_through.f90
CHECKPOINT=docs/publications/PUB-ME_D1_EXECUTION_CHECKPOINT.md

for path in "$POSITIVE" "$NEGATIVE" "$CHECKPOINT" tests/publication/run_pub_me_d1_transition_authority.sh; do
  [[ -f "$path" ]] || fail "missing D1 workunit file $path"
done

git diff --check "$EXECUTION_BASE"...HEAD -- "$POSITIVE" "$NEGATIVE" "$CHECKPOINT" \
  tests/publication/run_pub_me_d1_transition_authority.sh || fail 'D1 diff check'
[[ -z "$(git diff --name-only "$EXECUTION_BASE"...HEAD -- src reference)" ]] || \
  fail 'D1 workunit changed production/reference source'

# Bind execution to the immutable preregistration. The design branch is not an
# ancestor of current canonical, so fetch the exact object explicitly without
# merging it into the execution branch.
git fetch --quiet --no-tags origin "$DESIGN_HEAD" || fail 'cannot fetch preregistered design authority'
actual_design_blob="$(git rev-parse "$DESIGN_HEAD:$DESIGN_PATH" 2>/dev/null || true)"
[[ "$actual_design_blob" == "$DESIGN_BLOB" ]] || \
  fail "preregistered D1-D6 design blob drift: $actual_design_blob"
echo "PUB_ME_D1_PREREGISTRATION_HEAD=$DESIGN_HEAD"
echo "PUB_ME_D1_PREREGISTRATION_BLOB=$actual_design_blob"
echo 'PUB_ME_D1_PREREGISTRATION_BINDING=PASS'

# P0: replay the exact current-canonical post-solver rejection control. Its
# direct committed-state identity assertion is recorded as a B2 observation,
# not silently counted as part of B1.
CONTROL_OUT="$BUILD/p0-control.txt"
if ! bash tests/publication/run_pub_p1e02_postsolver_rollback.sh > "$CONTROL_OUT" 2>&1; then
  cat "$CONTROL_OUT" >&2
  fail 'P0 clean post-solver rejection control'
fi
for marker in \
  'PUB_P1E02_POSTSOLVER_COMMITTED_STATE_IDENTITY=PASS' \
  'PUB_P1E02_REJECTED_TRANSFER_EXCLUSION=PASS' \
  'PUB_P1E02_PRODUCTION_POSTSOLVER_ROLLBACK=PASS' \
  'PUB_P1E02_POSTSOLVER_ROLLBACK_GATE=PASS'; do
  grep -Fq "$marker" "$CONTROL_OUT" || { cat "$CONTROL_OUT" >&2; fail "P0 missing marker $marker"; }
done
headcalc_calls="$(grep -F 'PUB_P1E02_HEADCALC_CALLS_BEFORE_REJECTION=' "$CONTROL_OUT" | tail -1 | cut -d= -f2)"
[[ -n "$headcalc_calls" && "$headcalc_calls" -ge 3 ]] || fail 'P0 did not execute full/two-half physical trajectories'
echo "PUB_ME_D1_P0_HEADCALC_CALLS=$headcalc_calls"
echo 'PUB_ME_D1_P0_REAL_POSTSOLVER_REJECTION=PASS'

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
MODULE_SRC=(
  src/transaction/mod_transaction_reference.f90
  src/solver/mod_soil_water_accepted_step_direction_contract.f90
  src/transaction/mod_accepted_trajectory_directional_sensitivity.f90
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/transaction/mod_accepted_trajectory_directional_publication.f90
  src/transaction/mod_fkt_temporal_indicator_history.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/kernel/mod_kernel_transactions.f90
)

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  objects=()
  for source in "${MODULE_SRC[@]}"; do
    [[ -f "$source" ]] || fail "missing compile source $source"
    obj="$OUT/$(basename "${source%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$source" -o "$obj"
    objects+=("$obj")
  done

  # P2: public snapshots are writable by the caller but must be deep clones.
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$POSITIVE" -o "$OUT/clone.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/clone.o" -o "$OUT/clone"
  if ! "$OUT/clone" > "$OUT/clone-output.txt" 2>&1; then
    cat "$OUT/clone-output.txt" >&2
    fail "P2 clone-isolation O$opt"
  fi
  grep -Fq 'PUB_ME_D1_PUBLIC_SNAPSHOT_CLONE_ISOLATION=PASS' "$OUT/clone-output.txt" || {
    cat "$OUT/clone-output.txt" >&2
    fail "P2 missing clone-isolation marker O$opt"
  }

  # P1: a consumer attempting direct write-through to the authoritative
  # physical component must fail to compile because the component is private.
  if gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$NEGATIVE" \
      -o "$OUT/illegal.o" > "$OUT/illegal-stdout.txt" 2> "$OUT/illegal-stderr.txt"; then
    fail "P1 illegal committed-state write-through compiled at O$opt"
  fi
  grep -Fqi 'physical_state' "$OUT/illegal-stderr.txt" || {
    cat "$OUT/illegal-stderr.txt" >&2
    fail "P1 compile rejection did not identify physical_state at O$opt"
  }
  grep -Fqi 'private' "$OUT/illegal-stderr.txt" || {
    cat "$OUT/illegal-stderr.txt" >&2
    fail "P1 compile rejection was not caused by private authority boundary at O$opt"
  }

  cat "$OUT/clone-output.txt"
  echo "PUB_ME_D1_P1_PRIVATE_WRITE_THROUGH_O${opt}=PASS"
  echo "PUB_ME_D1_P2_CLONE_ISOLATION_O${opt}=PASS"
done

cmp -s "$BUILD/o0/clone-output.txt" "$BUILD/o2/clone-output.txt" || {
  diff -u "$BUILD/o0/clone-output.txt" "$BUILD/o2/clone-output.txt" >&2 || true
  fail 'P2 O0/O2 clone-isolation output drift'
}

echo "PUB_ME_D1_P2_O0_O2_SHA256=$(sha256sum "$BUILD/o0/clone-output.txt" | awk '{print $1}')"
echo 'PUB_ME_D1_STRUCTURAL_PREVENTION_EVIDENCE=PASS'
echo 'PUB_ME_D1_TRANSITION_AUTHORITY_GATE=PASS'

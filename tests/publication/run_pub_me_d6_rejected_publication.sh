#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-pub-me-d6-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail(){ echo "PUB_ME_D6_GATE_FAIL $*" >&2; exit 1; }

EXECUTION_BASE=d67a96fd576dcd1c5a30eb766c5aa1a503e10cf0
DESIGN_HEAD=b2ebe5825b3c54d9d4eaefe44c33f4c859fa20aa
DESIGN_BLOB=61f7133f19cc900971aa454b7bdb16a254468eda
DESIGN_PATH=docs/publications/PUB-ME_D1_D6_PREREGISTERED_EXPERIMENT_MATRIX.md
CHECKPOINT=docs/publications/PUB-ME_D6_EXECUTION_CHECKPOINT.md
TEST=tests/publication/test_pub_me_d6_rejected_publication.f90
RUNNER=tests/publication/run_pub_me_d6_rejected_publication.sh

for path in "$CHECKPOINT" "$TEST" "$RUNNER"; do
  [[ -f "$path" ]] || fail "missing D6 workunit file $path"
done

git diff --check "$EXECUTION_BASE"...HEAD -- "$CHECKPOINT" "$TEST" "$RUNNER" || fail 'D6 diff check'
[[ -z "$(git diff --name-only "$EXECUTION_BASE"...HEAD -- src reference)" ]] || fail 'D6 changed production/reference source'

git fetch --quiet --no-tags origin "$DESIGN_HEAD" || fail 'cannot fetch preregistered design authority'
actual_design_blob="$(git rev-parse "$DESIGN_HEAD:$DESIGN_PATH" 2>/dev/null || true)"
[[ "$actual_design_blob" == "$DESIGN_BLOB" ]] || fail "preregistered D1-D6 design blob drift: $actual_design_blob"

echo "PUB_ME_D6_PREREGISTRATION_HEAD=$DESIGN_HEAD"
echo "PUB_ME_D6_PREREGISTRATION_BLOB=$actual_design_blob"
echo 'PUB_ME_D6_PREREGISTRATION_BINDING=PASS'

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
MODULE_SRC=(
  src/transaction/mod_transaction_reference.f90
  src/solver/mod_soil_water_accepted_step_direction_contract.f90
  src/transaction/mod_accepted_trajectory_directional_sensitivity.f90
  src/transaction/mod_accepted_trajectory_directional_publication.f90
  src/transaction/mod_accepted_trajectory_transaction_binding.f90
)

run_one(){
  local opt="$1"
  local tag="$2"
  local out="$BUILD/$tag"
  local objects=()

  for source in "${MODULE_SRC[@]}"; do
    [[ -f "$source" ]] || fail "missing compile source $source"
    local obj="$out/$(basename "${source%.*}").o"
    local extra=()
    if [[ "$source" == "src/transaction/mod_transaction_reference.f90" ]]; then
      extra=(-Wno-error=compare-reals)
    fi
    gfortran "${COMMON[@]}" "${extra[@]}" -O"$opt" -J "$out" -I "$out" -c "$source" -o "$obj"
    objects+=("$obj")
  done

  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$TEST" -o "$out/test.o"
  gfortran -O"$opt" "${objects[@]}" "$out/test.o" -o "$out/test"

  if ! "$out/test" > "$out/output.txt" 2>&1; then
    cat "$out/output.txt" >&2
    fail "D6 execution $tag"
  fi

  grep -Fq 'PUB_ME_D6_ACCEPTED_CONTROL=PASS' "$out/output.txt" || fail "accepted control missing $tag"
  grep -Fq 'PUB_ME_D6_REJECTED_CONTROL_ZERO_PUBLICATION=PASS' "$out/output.txt" || fail "rejected control missing $tag"
  grep -Fq 'PUB_ME_D6_B2_PREEMISSION_AUTHORITY=DETECTED' "$out/output.txt" || fail "B2 marker missing $tag"
  grep -Fq 'PUB_ME_D6_PHYSICAL_STATE_UNCHANGED=PASS' "$out/output.txt" || fail "physical control missing $tag"
  grep -Eq '^PUB_ME_D6_CLASSIFICATION=(STRUCTURAL_PREVENTION|NO_INCREMENTAL_VALUE|EARLIER_DETECTION|UNIQUE_DETECTION|D6_AUTHORITY_FAILURE|INCONCLUSIVE_CLEAN_CONTROL_FAILURE)$' "$out/output.txt" || {
    cat "$out/output.txt" >&2
    fail "invalid D6 classification $tag"
  }
  grep -Fq 'PUB_ME_D6_REJECTED_PUBLICATION_EXPERIMENT=PASS' "$out/output.txt" || fail "D6 PASS marker missing $tag"

  cat "$out/output.txt"
  echo "PUB_ME_D6_${tag^^}=PASS"
}

run_one 0 o0
run_one 2 o2

cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || {
  diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true
  fail 'D6 O0/O2 semantic drift'
}

echo "PUB_ME_D6_O0_O2_SHA256=$(sha256sum "$BUILD/o0/output.txt" | awk '{print $1}')"
echo 'PUB_ME_D6_GATE=PASS'

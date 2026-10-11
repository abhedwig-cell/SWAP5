#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-pub-me-d3-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail(){ echo "PUB_ME_D3_GATE_FAIL $*" >&2; exit 1; }

EXECUTION_BASE=863f236596129d0ede3e975526553ea7f0a969ed
DESIGN_HEAD=b2ebe5825b3c54d9d4eaefe44c33f4c859fa20aa
DESIGN_BLOB=61f7133f19cc900971aa454b7bdb16a254468eda
DESIGN_PATH=docs/publications/PUB-ME_D1_D6_PREREGISTERED_EXPERIMENT_MATRIX.md
CHECKPOINT=docs/publications/PUB-ME_D3_EXECUTION_CHECKPOINT.md
TEST=tests/publication/test_pub_me_d3_origin_authority.f90

for path in "$CHECKPOINT" "$TEST" tests/publication/run_pub_me_d3_origin_authority.sh; do
  [[ -f "$path" ]] || fail "missing D3 workunit file $path"
done

git diff --check "$EXECUTION_BASE"...HEAD -- "$CHECKPOINT" "$TEST"   tests/publication/run_pub_me_d3_origin_authority.sh || fail 'D3 diff check'
[[ -z "$(git diff --name-only "$EXECUTION_BASE"...HEAD -- src reference)" ]] ||   fail 'D3 changed production/reference source'

git fetch --quiet --no-tags origin "$DESIGN_HEAD" || fail 'cannot fetch preregistered design authority'
actual_design_blob="$(git rev-parse "$DESIGN_HEAD:$DESIGN_PATH" 2>/dev/null || true)"
[[ "$actual_design_blob" == "$DESIGN_BLOB" ]] ||   fail "preregistered D1-D6 design blob drift: $actual_design_blob"

echo "PUB_ME_D3_PREREGISTRATION_HEAD=$DESIGN_HEAD"
echo "PUB_ME_D3_PREREGISTRATION_BLOB=$actual_design_blob"
echo 'PUB_ME_D3_PREREGISTRATION_BINDING=PASS'

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)

run_one(){
  local opt="$1"
  local tag="$2"
  local out="$BUILD/$tag"
  mkdir -p "$out"

  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c src/solver/mod_soil_water_accepted_step_direction_contract.f90 -o "$out/step_contract.o"
  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c src/transaction/mod_accepted_trajectory_directional_sensitivity.f90 -o "$out/trajectory.o"
  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c src/transaction/mod_accepted_trajectory_directional_publication.f90 -o "$out/publication.o"
  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c src/transaction/mod_transaction_reference.f90 -o "$out/transaction.o"
  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c src/runtime/mod_canonical_contracts.f90 -o "$out/contracts.o"
  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c src/runtime/mod_canonical_interval_runtime.f90 -o "$out/runtime.o"
  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c src/kernel/mod_kernel_transactions.f90 -o "$out/kernel.o"

  gfortran "${COMMON[@]}" -Werror "$opt" -J "$out" -I "$out" -c "$TEST" -o "$out/test.o"
  gfortran "$opt" "$out/step_contract.o" "$out/trajectory.o" "$out/publication.o" "$out/transaction.o"     "$out/contracts.o" "$out/runtime.o" "$out/kernel.o" "$out/test.o" -o "$out/test_d3"

  "$out/test_d3" > "$out/output.txt" 2>&1 || {
    cat "$out/output.txt" >&2
    fail "D3 execution $tag"
  }

  for marker in     'PUB_ME_D3_CLEAN_COMMIT=PASS'     'PUB_ME_D3_LINEAGE_MISMATCH_STRUCTURAL_PREVENTION=PASS'     'PUB_ME_D3_STALE_REVISION_STRUCTURAL_PREVENTION=PASS'     'PUB_ME_D3_TIME_ORIGIN_STRUCTURAL_PREVENTION=PASS'     'PUB_ME_D3_CLASSIFICATION=STRUCTURAL_PREVENTION'     'PUB_ME_D3_ORIGIN_AUTHORITY_EXPERIMENT=PASS'; do
    grep -Fq "$marker" "$out/output.txt" || {
      cat "$out/output.txt" >&2
      fail "missing $tag marker $marker"
    }
  done

  cat "$out/output.txt"
  echo "PUB_ME_D3_${tag^^}=PASS"
}

run_one -O0 o0
run_one -O2 o2

cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || {
  diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true
  fail 'D3 O0/O2 semantic drift'
}

echo "PUB_ME_D3_O0_O2_SHA256=$(sha256sum "$BUILD/o0/output.txt" | awk '{print $1}')"
echo 'PUB_ME_D3_GATE=PASS'

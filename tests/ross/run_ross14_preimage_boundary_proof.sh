#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-ross14-preimage-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail() { echo "F_ROSS14_PREIMAGE_GATE_FAIL $*" >&2; exit 1; }

MODEL_BINDING=src/runtime/mod_rossfast_d3r_model_binding.f90
MODEL_BINDING_BLOB=5442fd7e7a2f392c9b796cd17c76b17977259f22
TEST=tests/ross/test_ross14_preimage_boundary_proof.f90

test "$(git rev-parse HEAD:$MODEL_BINDING)" = "$MODEL_BINDING_BLOB" || fail 'preimage model binding drift'
grep -Fq 'ROSSFAST_D3R_BOUNDARY_ENVELOPE_FRACTION = 0.02_real64' "$MODEL_BINDING" || fail 'legacy boundary fraction missing'

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -fopenmp -ffpe-trap=invalid,zero,overflow)
MODULE_SRC=(
  src/transaction/mod_transaction_reference.f90
  src/solver/mod_soil_water_accepted_step_direction_contract.f90
  src/transaction/mod_accepted_trajectory_directional_sensitivity.f90
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/transaction/mod_accepted_trajectory_directional_publication.f90
  src/transaction/mod_fkt_temporal_indicator_history.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_rossfast_d3r_execution_policy.f90
  src/runtime/mod_rossfast_d3r_model_binding.f90
)

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  objects=()
  for source in "${MODULE_SRC[@]}"; do
    obj="$OUT/$(basename "${source%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$source" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$TEST" -o "$OUT/test.o"
  gfortran -fopenmp -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; fail "runtime O$opt"; }
  for marker in     'F_ROSS14_PREIMAGE_DRYING_ACCEPT_COUNT=108'     'F_ROSS14_PREIMAGE_NOMINAL_ACCEPT_COUNT=108'     'F_ROSS14_PREIMAGE_WETTING_REJECT_COUNT=108'     'F_ROSS14_PREIMAGE_BOUNDARY_PROOF=PASS'; do
    grep -Fq "$marker" "$OUT/output.txt" || { cat "$OUT/output.txt" >&2; fail "missing marker $marker O$opt"; }
  done
  cat "$OUT/output.txt"
  echo "F_ROSS14_PREIMAGE_O${opt}=PASS"
done

cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || {
  diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true
  fail 'O0/O2 preimage proof drift'
}

echo "F_ROSS14_PREIMAGE_O0_O2_SHA256=$(sha256sum "$BUILD/o0/output.txt" | awk '{print $1}')"
echo 'F_ROSS14_PREIMAGE_BOUNDARY_GATE=PASS'

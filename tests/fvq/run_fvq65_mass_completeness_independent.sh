#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-/tmp}/fvq65-mass-${GITHUB_RUN_ID:-local}"
rm -rf "$BUILD"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

BASE=c19a04721a05c6a00ba264e7477969807dcb258f
COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -Wno-error=compare-reals -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
fail() { echo "FVQ65_MASS_GATE_FAIL:$*" >&2; exit 1; }

run_candidate() {
  local opt="$1"
  local out="$BUILD/candidate-o$opt"
  mkdir -p "$out"
  gfortran "${COMMON[@]}" -O"$opt" -J"$out" -I"$out" -c src/transaction/mod_transaction_reference.f90 -o "$out/tx.o"
  gfortran "${COMMON[@]}" -O"$opt" -J"$out" -I"$out" -c tests/fvq/mod_fvq65_mass_attack_support.f90 -o "$out/support.o"
  gfortran "${COMMON[@]}" -O"$opt" -J"$out" -I"$out" -c tests/fvq/test_fvq65_mass_fail_closed.f90 -o "$out/test.o"
  gfortran "${COMMON[@]}" -O"$opt" "$out/tx.o" "$out/support.o" "$out/test.o" -o "$out/test"
  "$out/test" > "$out/output.txt" 2>&1 || { cat "$out/output.txt" >&2; fail "candidate O$opt execution"; }
  grep -Fq 'FVQ65_EXTERNAL_REJECTION_MATRIX_CASES=PASS:14' "$out/output.txt" || fail "candidate O$opt external matrix"
  grep -Fq 'FVQ65_CERTIFICATE_REJECTION_MATRIX_CASES=PASS:9' "$out/output.txt" || fail "candidate O$opt certificate matrix"
  grep -Fq 'FVQ65_COMPLETE_EXTERNAL_ACCEPTS=PASS' "$out/output.txt" || fail "candidate O$opt external positive control"
  grep -Fq 'FVQ65_COMPLETE_CERTIFICATE_ACCEPTS=PASS' "$out/output.txt" || fail "candidate O$opt certificate positive control"
  grep -Fq 'FVQ65_EXTERNAL_RETRY_RECOVERY_FROM_COMMITTED_ORIGIN=PASS' "$out/output.txt" || fail "candidate O$opt external retry recovery"
  grep -Fq 'FVQ65_CERTIFICATE_RETRY_RECOVERY_FROM_COMMITTED_ORIGIN=PASS' "$out/output.txt" || fail "candidate O$opt certificate retry recovery"
  grep -Fq 'FVQ65_INDEPENDENT_MASS_COMPLETENESS_ATTACK_MATRIX=PASS' "$out/output.txt" || fail "candidate O$opt final marker"
}

run_candidate 0
run_candidate 2
cmp "$BUILD/candidate-o0/output.txt" "$BUILD/candidate-o2/output.txt" || fail 'candidate O0/O2 oracle identity'
echo 'FVQ65_CANDIDATE_FAIL_CLOSED_O0_O2_IDENTITY=PASS'

# Independently reproduce the exact pre-remediation defect against the frozen
# current-canonical source. The witness source is qualification-owned; no
# F-KT18 owner test is used here.
git show "$BASE:src/transaction/mod_transaction_reference.f90" > "$BUILD/canonical_tx.f90"
run_canonical_witness() {
  local opt="$1"
  local out="$BUILD/canonical-o$opt"
  mkdir -p "$out"
  gfortran "${COMMON[@]}" -O"$opt" -J"$out" -I"$out" -c "$BUILD/canonical_tx.f90" -o "$out/tx.o"
  gfortran "${COMMON[@]}" -O"$opt" -J"$out" -I"$out" -c tests/fvq/mod_fvq65_mass_attack_support.f90 -o "$out/support.o"
  gfortran "${COMMON[@]}" -O"$opt" -J"$out" -I"$out" -c tests/fvq/test_fvq65_canonical_gap_witness.f90 -o "$out/witness.o"
  gfortran "${COMMON[@]}" -O"$opt" "$out/tx.o" "$out/support.o" "$out/witness.o" -o "$out/witness"
  "$out/witness" > "$out/output.txt" 2>&1 || { cat "$out/output.txt" >&2; fail "canonical witness O$opt execution"; }
  grep -Fq 'FVQ65_CANONICAL_EXTERNAL_INCOMPLETE_LEDGER_ACCEPTANCE_REPRODUCED=PASS' "$out/output.txt" || fail "canonical O$opt external witness"
  grep -Fq 'FVQ65_CANONICAL_CERTIFICATE_MISSING_MASK_ACCEPTANCE_REPRODUCED=PASS' "$out/output.txt" || fail "canonical O$opt certificate witness"
  grep -Fq 'FVQ65_CURRENT_CANONICAL_GAP_WITNESS=PASS' "$out/output.txt" || fail "canonical O$opt final witness"
}

run_canonical_witness 0
run_canonical_witness 2
cmp "$BUILD/canonical-o0/output.txt" "$BUILD/canonical-o2/output.txt" || fail 'canonical witness O0/O2 identity'
echo 'FVQ65_CURRENT_CANONICAL_GAP_REPRODUCED_O0_O2=PASS'
echo 'FVQ65_INDEPENDENT_MASS_GATE=PASS'

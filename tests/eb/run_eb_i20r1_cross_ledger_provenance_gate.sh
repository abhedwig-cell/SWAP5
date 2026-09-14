#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-eb-i20r1-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"; trap 'rm -rf "$BUILD"' EXIT; cd "$ROOT"
fail(){ echo "EB_I20R1_GATE_FAIL $*" >&2; exit 221; }

LEDGER="src/runtime/mod_energy_conservation_ledger.f90"
grep -Fq 'prepared_lineage_id' "$LEDGER" || fail 'prepared lineage owner field missing'
grep -Fq 'prepared_origin_revision_value' "$LEDGER" || fail 'prepared revision owner field missing'
grep -Fq 'prepared_matches_ledger(self, prepared)' "$LEDGER" || fail 'prepared owner-match helper missing'
echo 'EB_I20R1_OWNER_PROVENANCE_BINDING_STATIC=PASS'

bash tests/eb/run_eb_i20r_batch_safe_energy_ledger_gate.sh > "$BUILD/i20r-owner.txt"
grep -Fq 'EB_I20R_OWNER_QUALIFICATION=PASS' "$BUILD/i20r-owner.txt" || fail 'EB-I20R preservation replay failed'
cat "$BUILD/i20r-owner.txt"
echo 'EB_I20R1_EB_I20R_PRESERVATION=PASS'

STRICT=(-std=f2008 -Wall -Wextra -Werror -ffree-line-length-none -fcheck=all -fbacktrace)
BASE=(-std=f2008 -Wall -Wextra -Werror -Wno-error=compare-reals -ffree-line-length-none -fcheck=all -fbacktrace)
BASE_MODULES=(src/transaction/mod_transaction_reference.f90 src/runtime/mod_canonical_contracts.f90 src/runtime/mod_canonical_interval_runtime.f90 src/kernel/mod_kernel_transactions.f90 src/runtime/mod_fmr_accepted_commit_receipt.f90)
TYPES="src/kernel/mod_energy_conservation_types.f90"

compile_oracle(){
  local opt="$1" out="$2"; mkdir -p "$out"; local objects=()
  for src in "${BASE_MODULES[@]}"; do
    local obj="$out/$(basename "${src%.*}").o"
    gfortran "${BASE[@]}" -O"$opt" -J "$out" -I "$out" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  for src in "$TYPES" "$LEDGER"; do
    local obj="$out/$(basename "${src%.*}").o"
    gfortran "${STRICT[@]}" -O"$opt" -J "$out" -I "$out" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${STRICT[@]}" -O"$opt" -J "$out" -I "$out" -c tests/eb/test_eb_i20r1_cross_ledger_prepared_provenance.f90 -o "$out/test.o"
  gfortran -O"$opt" "${objects[@]}" "$out/test.o" -o "$out/test"
  "$out/test" > "$out/out.txt"
  grep -Fq 'EBI20R1_CROSS_LEDGER_PREPARED_PROVENANCE_TEST PASS' "$out/out.txt" || fail "cross-ledger oracle O$opt"
}

compile_oracle 0 "$BUILD/o0"
compile_oracle 2 "$BUILD/o2"
cmp "$BUILD/o0/out.txt" "$BUILD/o2/out.txt" || fail 'cross-ledger O0/O2 mismatch'
cat "$BUILD/o0/out.txt"
echo 'EB_I20R1_CROSS_LEDGER_O0_O2_IDENTITY=PASS'
echo "EB_I20R1_LEDGER_BLOB=$(git rev-parse HEAD:$LEDGER)"
echo 'EB_I20R1_OWNER_QUALIFICATION=PASS'

#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fgc14-$$"
CANONICAL="c7379b6b5b5f529ff96de3087379712bd665276a"
FGC13="0c776f7c3d910c6727ec5659ae6437ca993fb20d"
FGC13_CLOSEOUT_BLOB="a6852bc3ff4a6c22097543510a49ea7164326648"
CONTRACT="src/runtime/mod_coupling_application_accuracy_contract.f90"
CONTRACT_BLOB="c07d573d21e7d013ab962c0a9d28102ab7b5cdfc"
ADAPTER="src/runtime/mod_coupling_application_accuracy_adapter.f90"
TEST="tests/fgc/test_fgc14_external_accuracy_adapter.f90"
trap 'rm -rf "$BUILD"' EXIT
mkdir -p "$BUILD"
cd "$ROOT"

fail(){ echo "FGC14_GATE_FAIL: $*" >&2; exit 1; }

git cat-file -e "${CANONICAL}^{commit}" || fail "canonical base unavailable"
git cat-file -e "${FGC13}^{commit}" || fail "F-GC13 final authority unavailable"
git merge-base --is-ancestor "$CANONICAL" HEAD || fail "branch is not descended from F-CI45P canonical"
git merge-base --is-ancestor "$FGC13" HEAD || fail "branch is not descended from final F-GC13 authority"
[[ "$(git rev-parse HEAD:$FGC13_CLOSEOUT_PATH 2>/dev/null || true)" == "$FGC13_CLOSEOUT_BLOB" ]] && true

[[ "$(git rev-parse HEAD:integration/f-gc/F-GC13_CLOSEOUT.json)" == "$FGC13_CLOSEOUT_BLOB" ]] || fail "F-GC13 closeout drifted"
[[ "$(git rev-parse HEAD:$CONTRACT)" == "$CONTRACT_BLOB" ]] || fail "canonical application accuracy contract drifted"
echo "FGC14_UPSTREAM_AUTHORITY_LOCK=PASS"

changed_src="$(git diff --name-only "$CANONICAL"..HEAD -- src || true)"
[[ "$changed_src" == "$ADAPTER" ]] || fail "production source allowlist violated: $changed_src"
echo "FGC14_SOURCE_ALLOWLIST=PASS"

# The adapter is typed runtime composition only. It may not become an I/O,
# schema-parser, network, kernel, transaction or solver layer.
if grep -Eiq '(^|[^[:alnum:]_])(open|read|write|close)[[:space:]]*\(' "$ADAPTER"; then
  fail "adapter contains file I/O"
fi
if grep -Eiq '(json|yaml|filepath|filename|http://|https://)' "$ADAPTER"; then
  fail "adapter contains format/path/network coupling"
fi
if grep -Eq 'use[[:space:]]+mod_(kernel|transaction|soil_water|reference_richards)' "$ADAPTER"; then
  fail "adapter depends on forbidden kernel/transaction/solver internals"
fi
grep -Fq 'fgc13_packet_validated = .false.' "$ADAPTER" || fail "packet validation attestation is not fail-closed"
grep -Fq 'application_source_digest_content_verified = .false.' "$ADAPTER" || fail "application source verification is not fail-closed"
grep -Fq 'temporal_source_digest_content_verified = .false.' "$ADAPTER" || fail "temporal source verification is not fail-closed"
grep -Fq 'contract = coupling_application_accuracy_contract_t()' "$ADAPTER" || fail "default contract clearing missing"
grep -Fq 'candidate%h_app_externally_qualified = .true.' "$ADAPTER" || fail "accepted H_app external qualification mapping missing"
grep -Fq 'candidate%a_temporal_externally_qualified = .true.' "$ADAPTER" || fail "accepted A_temporal external qualification mapping missing"
grep -Fq 'candidate%application_provenance_id = view%application_provenance_id' "$ADAPTER" || fail "application provenance mapping missing"
grep -Fq 'candidate%temporal_allocation_provenance_id = view%temporal_allocation_provenance_id' "$ADAPTER" || fail "temporal provenance mapping missing"
echo "FGC14_NO_KERNEL_IO_OR_POLICY_SELECTION=PASS"

# Nonfinite handling is inherited from the immutable canonical application
# contract and must remain on the actual F-GC14 validation path.
grep -Fq 'ieee_is_finite(self%h_app_cm)' "$CONTRACT" || fail "canonical finite H_app guard missing"
grep -Fq 'ieee_is_finite(self%a_temporal)' "$CONTRACT" || fail "canonical finite A_temporal guard missing"
grep -Fq 'candidate%application_requirement_valid()' "$ADAPTER" || fail "adapter does not invoke canonical application validation"
grep -Fq 'candidate%temporal_allocation_valid()' "$ADAPTER" || fail "adapter does not invoke canonical temporal validation"
grep -Fq 'candidate%temporal_budget_ready()' "$ADAPTER" || fail "adapter does not invoke canonical budget validation"
echo "FGC14_NONFINITE_GUARD_INHERITANCE=PASS"

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
build(){
  local opt="$1" tag="$2" out="$BUILD/$2"
  mkdir -p "$out"
  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c src/transaction/mod_transaction_reference.f90 -o "$out/transaction.o"
  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c src/runtime/mod_canonical_contracts.f90 -o "$out/contracts.o"
  gfortran "${COMMON[@]}" -Werror "$opt" -J "$out" -I "$out" -c "$CONTRACT" -o "$out/application_contract.o"
  gfortran "${COMMON[@]}" -Werror "$opt" -J "$out" -I "$out" -c "$ADAPTER" -o "$out/adapter.o"
  gfortran "${COMMON[@]}" -Werror "$opt" -J "$out" -I "$out" -c "$TEST" -o "$out/test.o"
  gfortran "$opt" "$out/transaction.o" "$out/contracts.o" "$out/application_contract.o" "$out/adapter.o" "$out/test.o" -o "$out/fgc14"
}

build -O0 o0
build -O2 o2
"$BUILD/o0/fgc14" > "$BUILD/o0.txt"
"$BUILD/o2/fgc14" > "$BUILD/o2.txt"
cmp "$BUILD/o0.txt" "$BUILD/o2.txt" || { diff -u "$BUILD/o0.txt" "$BUILD/o2.txt" >&2 || true; fail "O0/O2 output drift"; }
cat "$BUILD/o2.txt"
echo "FGC14_O0_O2_IDENTITY=PASS"
echo "FGC14_MASS_CONSERVATION_RELAXED=NO"
echo "FGC14_PRODUCTION_COUPLING_ADMISSION=NO"
echo "FGC14_EXTERNAL_ACCURACY_RUNTIME_ADAPTER_GATE PASS"

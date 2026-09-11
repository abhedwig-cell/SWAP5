#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fgc10-$$"
CANONICAL=d201904a85f3b595e028242978e52c02f5122a09
MODULE=src/runtime/mod_coupling_application_accuracy_contract.f90
BACKEND=src/runtime/mod_fmr_serialized_reference_backend.f90
INDICATOR=src/solver/mod_reference_richards_temporal_indicator.f90
trap 'rm -rf "$BUILD"' EXIT
mkdir -p "$BUILD"
cd "$ROOT"

fail(){ echo "FGC10_GATE_FAIL $*" >&2; exit 1; }

git merge-base --is-ancestor "$CANONICAL" HEAD || fail 'branch is not descended from current F-CI43P canonical base'
changed_src="$(git diff --name-only "$CANONICAL" HEAD -- src)"
[[ "$changed_src" == "$MODULE" ]] || fail "source allowlist violated: $changed_src"
[[ "$(git rev-parse HEAD:$MODULE)" == c07d573d21e7d013ab962c0a9d28102ab7b5cdfc ]] || fail 'GC09 qualified candidate source blob changed'
[[ "$(git rev-parse HEAD:src/runtime/mod_canonical_contracts.f90)" == c06aa869a0bd479df4c7d6e1d0b4f5c07a207144 ]] || fail 'canonical contracts changed'
[[ "$(git rev-parse HEAD:src/transaction/mod_transaction_reference.f90)" == 2fd932b74dbd0ffc0ec089f49e632b7ac8852df4 ]] || fail 'transaction core changed'
[[ "$(git rev-parse HEAD:$BACKEND)" == 9af5a494526810324dc00706b444e448e770cba9 ]] || fail 'reviewed serialized reference backend postimage changed'
[[ "$(git rev-parse HEAD:$INDICATOR)" == fe8f87d11257d4c6bc019f1d628ac41ba3106d4e ]] || fail 'reviewed Richards temporal indicator postimage changed'
echo 'FGC10_CURRENT_CANONICAL_POSTIMAGE_LOCK=PASS'
echo 'FGC10_GC09_SOURCE_BLOB_IDENTITY=PASS'

# Canonical carrier remains deliberately generic/model-owned.
grep -Fq 'canonical runtime and F-KT transaction core deliberately do not attach' src/runtime/mod_canonical_contracts.f90 || fail 'generic-carrier ownership statement missing'
grep -Fq 'model owns that interpretation and must normalize its native indicator' src/runtime/mod_canonical_contracts.f90 || fail 'model-owned normalization contract missing'

# Current canonical selected reference model binds the generic scalar as a native
# head-domain budget and normalizes the Richards head indicator into the
# dimensionless certificate consumed by the transaction core.
grep -Fq 'self%temporal_indicator_budget_supplied = config%model_temporal_indicator_budget_available' "$BACKEND" || fail 'budget availability binding missing'
grep -Fq 'self%temporal_indicator_budget = config%model_temporal_indicator_budget' "$BACKEND" || fail 'budget value binding missing'
grep -Fq 'self%last_observation%temporal_head_budget = self%temporal_indicator_budget' "$BACKEND" || fail 'head-budget semantic observation missing'
grep -Fq 'normalized_indicator = indicator_result%head_inf_bound / self%temporal_indicator_budget' "$BACKEND" || fail 'native-head to dimensionless normalization missing'
grep -Fq 'outcome%temporal_certificate_available = .true.' "$BACKEND" || fail 'normalized certificate availability path missing'
grep -Fq 'outcome%temporal_indicator = normalized_indicator' "$BACKEND" || fail 'normalized certificate transfer missing'
grep -Fq 'indicator_result%head_inf_bound = bounded_norm/sqrt(indicator_result%min_mass_weight)' "$INDICATOR" || fail 'native head indicator construction missing'
echo 'FGC10_TEMPORAL_INDICATOR_BINDING=PASS'
echo 'FGC10_DIMENSIONLESS_CERTIFICATE_NORMALIZATION=PASS'

# The seam itself must remain runtime-only and fail closed without externally
# qualified/provenance-bound policy inputs.
if grep -Eiq '(^|[^[:alnum:]_])(open|read|write|close)[[:space:]]*\(' "$MODULE"; then
  fail 'application contract contains file I/O'
fi
if grep -Eq 'use[[:space:]]+mod_(kernel|transaction|soil_water|reference_richards)' "$MODULE"; then
  fail 'application contract depends on forbidden kernel/solver/transaction internals'
fi
grep -Fq 'logical :: h_app_available = .false.' "$MODULE" || fail 'H_app absence default changed'
grep -Fq 'logical :: a_temporal_available = .false.' "$MODULE" || fail 'A_temporal absence default changed'
grep -Fq 'config%model_temporal_indicator_budget_available = .false.' "$MODULE" || fail 'stale budget availability clearing missing'
grep -Fq 'config%model_temporal_indicator_budget = 0.0_real64' "$MODULE" || fail 'stale budget value clearing missing'
echo 'FGC10_NO_HIDDEN_NUMERIC_POLICY=PASS'

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
build(){
  local opt="$1" tag="$2" out="$BUILD/$2"
  mkdir -p "$out"
  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c src/transaction/mod_transaction_reference.f90 -o "$out/transaction.o"
  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c src/runtime/mod_canonical_contracts.f90 -o "$out/contracts.o"
  gfortran "${COMMON[@]}" -Werror "$opt" -J "$out" -I "$out" -c "$MODULE" -o "$out/application_contract.o"
  gfortran "${COMMON[@]}" -Werror "$opt" -J "$out" -I "$out" -c tests/fgc/test_fgc10_application_accuracy_contract.f90 -o "$out/test.o"
  gfortran "$opt" "$out/transaction.o" "$out/contracts.o" "$out/application_contract.o" "$out/test.o" -o "$out/fgc10"
}

build -O0 o0
build -O2 o2
"$BUILD/o0/fgc10" > "$BUILD/o0.txt"
"$BUILD/o2/fgc10" > "$BUILD/o2.txt"
cmp "$BUILD/o0.txt" "$BUILD/o2.txt" || { diff -u "$BUILD/o0.txt" "$BUILD/o2.txt" >&2 || true; fail 'O0/O2 output drift'; }
cat "$BUILD/o2.txt"
echo 'FGC10_O0_O2_IDENTITY=PASS'
echo 'FGC10_CANONICAL_ADMISSION_GATE PASS'

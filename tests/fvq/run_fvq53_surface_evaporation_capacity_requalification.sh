#!/usr/bin/env bash
set -euo pipefail

BASE=adf79478f55458c05444ad9b90e52644e6cf36b6
OWNER_CLOSEOUT=adeb61197695b765f43268249cdf86313ca9a13d
CANDIDATE=41628858477d6fa8d6a46de8ff1a9e69459c2eb0
FPM06D=3ec07cf0d88e52d7503098a4de19f699acf7e9e1
FVQ52=003209963ead7f14e375fca7f7d5d4b2a1996ae8
BLOB_MVG=fea5a1681b1c3bdefce1cdbb6d48a9396c8266b6
BLOB_CONTRACT=551513f77caeb9c54e8c8b1cdc326be0e9d01982
BLOB_PROVIDER=8909cdf342527a2b0266c8d9a5fc918f98556ea2
TEST=tests/fvq/test_fvq53_surface_evaporation_capacity_independent.f90
BUILD="${RUNNER_TEMP:-/tmp}/fvq53-${GITHUB_RUN_ID:-local}"
rm -rf "$BUILD"
mkdir -p "$BUILD/candidate" "$BUILD/o0" "$BUILD/o2"

# Independent branch authority. No candidate production source may be carried on the qualification branch.
test "$(git rev-parse ${BASE}:src)" = "$(git rev-parse HEAD:src)"
test "$(git rev-parse ${BASE}:reference)" = "$(git rev-parse HEAD:reference)"
echo 'FVQ53_QUALIFICATION_PRODUCTION_IMMUTABLE=PASS'

# Exact immutable owner candidate and direct canonical parent.
git cat-file -e "${CANDIDATE}^{commit}" 2>/dev/null || git fetch --no-tags origin "$CANDIDATE" >/dev/null 2>&1
test "$(git rev-parse ${CANDIDATE}^)" = "$BASE"
test "$(git rev-parse ${CANDIDATE}:src/solver/mod_b110_default_mvg_provider.f90)" = "$BLOB_MVG"
test "$(git rev-parse ${CANDIDATE}:src/solver/mod_surface_evaporation_capacity_contract.f90)" = "$BLOB_CONTRACT"
test "$(git rev-parse ${CANDIDATE}:src/solver/mod_b110_surface_evaporation_capacity_provider.f90)" = "$BLOB_PROVIDER"
mapfile -t delta < <(git diff --name-only "$BASE".."$CANDIDATE" -- src reference | sort)
expected=(
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_surface_evaporation_capacity_provider.f90
  src/solver/mod_surface_evaporation_capacity_contract.f90
)
[[ "${delta[*]}" == "${expected[*]}" ]]
echo 'FVQ53_EXACT_CANDIDATE_SCOPE=PASS'

# Owner closeout is evidence, not an oracle.
git cat-file -e "${OWNER_CLOSEOUT}^{commit}" 2>/dev/null || git fetch --no-tags origin "$OWNER_CLOSEOUT" >/dev/null 2>&1
test "$(git rev-parse ${OWNER_CLOSEOUT}:integration/f-pm/F-PM06E_STATUS.json)" = 4c3f1dfbb75dcb30703b81a9eea81e4592b1b8d0
git show ${OWNER_CLOSEOUT}:integration/f-pm/F-PM06E_STATUS.json | grep -Fq 'QUALIFIED_RESTRICTED_B110_SURFACE_EVAPORATION_CAPACITY_CANDIDATE_READY_FOR_INDEPENDENT_FVQ'
git show ${OWNER_CLOSEOUT}:integration/f-pm/F-PM06E_STATUS.json | grep -Fq '"production_candidate": "41628858477d6fa8d6a46de8ff1a9e69459c2eb0"'
echo 'FVQ53_OWNER_HANDOFF_EXACT=PASS'

# Upstream source and downstream structural authorities are independently pinned and remain separate.
git cat-file -e "${FPM06D}^{commit}" 2>/dev/null || git fetch --no-tags origin "$FPM06D" >/dev/null 2>&1
git cat-file -e "${FVQ52}^{commit}" 2>/dev/null || git fetch --no-tags origin "$FVQ52" >/dev/null 2>&1
git show ${FPM06D}:integration/f-pm/F-PM06D_STATUS.json | grep -Fq 'READY_FOR_SCALAR_CAPACITY_CANDIDATE'
git show ${FVQ52}:qualification/f-vq/F-VQ52_STATUS.json | grep -Fq 'QUALIFIED_RESTRICTED_SURFACE_EVAPORATION_STRUCTURAL_CANDIDATE_WITHIN_FROZEN_SWINTER0_SWREDU0_SCOPE'
echo 'FVQ53_SOURCE_AND_CONSUMER_AUTHORITIES_PINNED=PASS'

# Materialize only the exact candidate blobs into temporary build space.
git show ${CANDIDATE}:src/solver/mod_b110_default_mvg_provider.f90 > "$BUILD/candidate/mod_b110_default_mvg_provider.f90"
git show ${CANDIDATE}:src/solver/mod_surface_evaporation_capacity_contract.f90 > "$BUILD/candidate/mod_surface_evaporation_capacity_contract.f90"
git show ${CANDIDATE}:src/solver/mod_b110_surface_evaporation_capacity_provider.f90 > "$BUILD/candidate/mod_b110_surface_evaporation_capacity_provider.f90"
test "$(git hash-object "$BUILD/candidate/mod_b110_default_mvg_provider.f90")" = "$BLOB_MVG"
test "$(git hash-object "$BUILD/candidate/mod_surface_evaporation_capacity_contract.f90")" = "$BLOB_CONTRACT"
test "$(git hash-object "$BUILD/candidate/mod_b110_surface_evaporation_capacity_provider.f90")" = "$BLOB_PROVIDER"

# Independent architecture guards. Internal diagnostic-string formatting is allowed; external I/O is not.
cat "$BUILD/candidate/mod_surface_evaporation_capacity_contract.f90" \
    "$BUILD/candidate/mod_b110_surface_evaporation_capacity_provider.f90" > "$BUILD/candidate/capability.all"
awk '!/^[[:space:]]*!/' "$BUILD/candidate/capability.all" > "$BUILD/candidate/capability.code"
if grep -Eiq '(^|[^[:alnum:]_])save([^[:alnum:]_]|$)|headcalc|newton|jacob|MOD_grid|MOD_swap|file_unit|pathname|open[[:space:]]*\(|read[[:space:]]*\(|close[[:space:]]*\(' "$BUILD/candidate/capability.code"; then
  echo 'FVQ53_FAIL forbidden persistence/legacy/solver-scratch/external-I-O coupling' >&2; exit 53
fi
if grep -Eiq 'mass_ledger|mass_in|mass_out|accepted_flux|qtop|qbot|calendar|midnight|day_of|month_of|year_of|86400' "$BUILD/candidate/capability.code"; then
  echo 'FVQ53_FAIL forbidden mass-authority or calendar coupling' >&2; exit 53
fi
grep -Fq 'mean-7-szym-not-qualified' "$BUILD/candidate/mod_b110_surface_evaporation_capacity_provider.f90"
grep -Fq 'B110_SURFACE_ATMOSPHERIC_HEAD_CM = -2.75e5_real64' "$BUILD/candidate/mod_b110_surface_evaporation_capacity_provider.f90"
echo 'FVQ53_ARCHITECTURE_SOURCE_GUARDS=PASS'

compile_and_run() {
  local opt="$1"
  local dir="$2"
  local flags=(-std=f2008 -Wall -Wextra -Werror -pedantic "$opt" -ffree-line-length-none -J"$dir" -I"$dir")
  gfortran "${flags[@]}" -c src/solver/mod_soil_water_solver_contract.f90 -o "$dir/contract.o"
  gfortran "${flags[@]}" -c "$BUILD/candidate/mod_b110_default_mvg_provider.f90" -o "$dir/mvg.o"
  gfortran "${flags[@]}" -c "$BUILD/candidate/mod_surface_evaporation_capacity_contract.f90" -o "$dir/cap_contract.o"
  gfortran "${flags[@]}" -c "$BUILD/candidate/mod_b110_surface_evaporation_capacity_provider.f90" -o "$dir/cap_provider.o"
  gfortran "${flags[@]}" -c "$TEST" -o "$dir/test.o"
  gfortran "$opt" "$dir/contract.o" "$dir/mvg.o" "$dir/cap_contract.o" "$dir/cap_provider.o" "$dir/test.o" -o "$dir/fvq53.exe"
  "$dir/fvq53.exe" > "$dir/output.txt"
}

compile_and_run -O0 "$BUILD/o0"
compile_and_run -O2 "$BUILD/o2"
diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"

grep -Fxq 'FVQ53_ORACLE_CASES=180' "$BUILD/o0/output.txt"
grep -Fxq 'FVQ53_CONDUCTIVITY_CASES=30' "$BUILD/o0/output.txt"
grep -Fxq 'FVQ53_B110_CONSTITUTIVE_ORACLE=PASS' "$BUILD/o0/output.txt"
grep -Fxq 'FVQ53_HCOMEAN_1_TO_6_ORACLE=PASS' "$BUILD/o0/output.txt"
grep -Fxq 'FVQ53_SIGNED_EMAX_ORACLE=PASS' "$BUILD/o0/output.txt"
grep -Fxq 'FVQ53_HELD_SCOPE_FAIL_CLOSED=PASS' "$BUILD/o0/output.txt"
grep -Fxq 'FVQ53_STATELESS_READ_ONLY_ABA=PASS' "$BUILD/o0/output.txt"
grep -Fxq 'FVQ53_INDEPENDENT_ORACLE=PASS' "$BUILD/o0/output.txt"
cat "$BUILD/o0/output.txt"
echo "FVQ53_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/output.txt" | awk '{print $1}')"
echo 'FVQ53_O0_O2_IDENTITY=PASS'
echo 'FVQ53_ARCHITECTURE_INVARIANTS=30_OF_30_NO_ADVERSE_DELTA'
echo 'FVQ53_GATE=PASS'

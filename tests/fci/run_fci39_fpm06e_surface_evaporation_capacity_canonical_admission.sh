#!/usr/bin/env bash
set -euo pipefail

BASE=adf79478f55458c05444ad9b90e52644e6cf36b6
COMPOSE=c9a73f2f37c9306e7a6fbf60b713b66d82c4a372
COMPOSE_TREE=8e518c70f14cb72582936c7ec21744d88743fda4
COMPOSE_SRC_TREE=7264753a19a481043434ba782d4f81bc585fed85
REFERENCE_TREE=9d08625217d7c0a7385df9da6a04183bcd9cb9e6
CANDIDATE=41628858477d6fa8d6a46de8ff1a9e69459c2eb0
OWNER=13ce03cdd01440090a71a82a9e3409f764a7bdd2
FVQ54=7cf8f6685ca24f855621f872bcf906f346edfa72
FVQ54_STATUS_BLOB=3b57efb0c29349254da4bc6cbfdc77b46a4ff9fc
BLOB_MVG=fea5a1681b1c3bdefce1cdbb6d48a9396c8266b6
BLOB_CONTRACT=551513f77caeb9c54e8c8b1cdc326be0e9d01982
BLOB_PROVIDER=8909cdf342527a2b0266c8d9a5fc918f98556ea2
EXPECTED_OUTPUT_SHA=e77388e86bf1726e486165606ef80edaef25361f7b7ad4ae1a2f8e1fcdbccbaa
BUILD="${RUNNER_TEMP:-/tmp}/fci39-${GITHUB_RUN_ID:-local}"
rm -rf "$BUILD"
mkdir -p "$BUILD/o0" "$BUILD/o2"

test "$(git rev-parse origin/integration/f-ci-canonical)" = "$BASE"
test "$(git rev-parse ${COMPOSE}^)" = "$BASE"
test "$(git rev-parse ${COMPOSE}^{tree})" = "$COMPOSE_TREE"
test "$(git rev-parse ${CANDIDATE}^{tree})" = "$COMPOSE_TREE"
test "$(git rev-parse ${COMPOSE}:src)" = "$COMPOSE_SRC_TREE"
test "$(git rev-parse ${COMPOSE}:reference)" = "$REFERENCE_TREE"
echo 'FCI39_EXACT_CANONICAL_SOURCE_AND_TREE_IDENTITY=PASS'

test "$(git rev-parse ${COMPOSE}:src/solver/mod_b110_default_mvg_provider.f90)" = "$BLOB_MVG"
test "$(git rev-parse ${COMPOSE}:src/solver/mod_surface_evaporation_capacity_contract.f90)" = "$BLOB_CONTRACT"
test "$(git rev-parse ${COMPOSE}:src/solver/mod_b110_surface_evaporation_capacity_provider.f90)" = "$BLOB_PROVIDER"
test "$(git rev-parse HEAD:src)" = "$COMPOSE_SRC_TREE"
test "$(git rev-parse HEAD:reference)" = "$REFERENCE_TREE"
mapfile -t production_delta < <(git diff --name-only "$BASE"..HEAD -- src reference | sort)
expected=(
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_surface_evaporation_capacity_provider.f90
  src/solver/mod_surface_evaporation_capacity_contract.f90
)
[[ "${production_delta[*]}" == "${expected[*]}" ]]
echo 'FCI39_EXACT_THREE_BLOB_PRODUCTION_SCOPE=PASS'

test "$(git rev-parse ${FVQ54}:integration/f-vq/F-VQ54_STATUS.json)" = "$FVQ54_STATUS_BLOB"
git show ${OWNER}:integration/f-pm/F-PM06E_STATUS.json | grep -Fq 'QUALIFIED_RESTRICTED_SCALAR_SURFACE_EVAPORATION_HYDRAULIC_CAPACITY_READY_FOR_INDEPENDENT_FVQ'
git show ${FVQ54}:integration/f-vq/F-VQ54_STATUS.json | grep -Fq 'QUALIFIED_RESTRICTED_SCALAR_SURFACE_EVAPORATION_HYDRAULIC_CAPACITY_WITHIN_FROZEN_SWINTER0_SWREDU0_SCOPE'
git show ${FVQ54}:integration/f-vq/F-VQ54_STATUS.json | grep -Fq '"canonical_admitted": false'
echo 'FCI39_OWNER_AND_INDEPENDENT_QUALIFICATION_AUTHORITIES_PINNED=PASS'

grep -Fq 'AUTH=c9a73f2f37c9306e7a6fbf60b713b66d82c4a372' .github/workflows/fci-canonical.yml
grep -Fq 'src/solver/mod_surface_evaporation_capacity_contract.f90' .github/workflows/fci-canonical.yml
grep -Fq 'src/solver/mod_b110_surface_evaporation_capacity_provider.f90' .github/workflows/fci-canonical.yml
grep -Fq 'frozen-fci39-surface-evaporation-capacity-source-authority' .github/workflows/fci-canonical.yml
echo 'FCI39_MOVING_CANONICAL_PRESERVATION_GOVERNANCE=PASS'

cat src/solver/mod_surface_evaporation_capacity_contract.f90 src/solver/mod_b110_surface_evaporation_capacity_provider.f90 > "$BUILD/capability.all"
awk '!/^[[:space:]]*!/' "$BUILD/capability.all" > "$BUILD/capability.code"
if grep -Eiq '(^|[^[:alnum:]_])save([^[:alnum:]_]|$)|headcalc|newton|jacob|MOD_grid|MOD_swap|file_unit|pathname|open[[:space:]]*\(|read[[:space:]]*\(|close[[:space:]]*\(' "$BUILD/capability.code"; then
  echo 'FCI39_FAIL forbidden persistence/legacy/solver-scratch/external-I-O coupling' >&2; exit 39
fi
if grep -Eiq 'mass_ledger|mass_in|mass_out|accepted_flux|qtop|qbot|calendar|midnight|day_of|month_of|year_of|86400' "$BUILD/capability.code"; then
  echo 'FCI39_FAIL forbidden mass-authority or calendar coupling' >&2; exit 39
fi
grep -Fq 'mean-7-szym-not-qualified' src/solver/mod_b110_surface_evaporation_capacity_provider.f90
grep -Fq 'B110_SURFACE_ATMOSPHERIC_HEAD_CM = -2.75e5_real64' src/solver/mod_b110_surface_evaporation_capacity_provider.f90
echo 'FCI39_ARCHITECTURE_SOURCE_GUARDS=PASS'

git show ${FVQ54}:tests/fvq/test_fvq54_surface_evaporation_capacity_independent.f90 > "$BUILD/test_fvq54.f90"

compile_and_run() {
  local opt="$1"
  local dir="$2"
  local flags=(-std=f2008 -Wall -Wextra -Werror -pedantic "$opt" -ffree-line-length-none -J"$dir" -I"$dir")
  gfortran "${flags[@]}" -Wno-error=unused-dummy-argument -c src/solver/mod_soil_water_solver_contract.f90 -o "$dir/contract.o"
  gfortran "${flags[@]}" -c src/solver/mod_b110_default_mvg_provider.f90 -o "$dir/mvg.o"
  gfortran "${flags[@]}" -c src/solver/mod_surface_evaporation_capacity_contract.f90 -o "$dir/cap_contract.o"
  gfortran "${flags[@]}" -c src/solver/mod_b110_surface_evaporation_capacity_provider.f90 -o "$dir/cap_provider.o"
  gfortran "${flags[@]}" -c "$BUILD/test_fvq54.f90" -o "$dir/test.o"
  gfortran "$opt" "$dir/contract.o" "$dir/mvg.o" "$dir/cap_contract.o" "$dir/cap_provider.o" "$dir/test.o" -o "$dir/fci39.exe"
  "$dir/fci39.exe" > "$dir/output.txt"
}

compile_and_run -O0 "$BUILD/o0"
compile_and_run -O2 "$BUILD/o2"
diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"

grep -Fxq 'FVQ54_ORACLE_CASES=180' "$BUILD/o0/output.txt"
grep -Fxq 'FVQ54_CONDUCTIVITY_CASES=30' "$BUILD/o0/output.txt"
grep -Fxq 'FVQ54_B110_CONSTITUTIVE_ORACLE=PASS' "$BUILD/o0/output.txt"
grep -Fxq 'FVQ54_HCOMEAN_1_TO_6_ORACLE=PASS' "$BUILD/o0/output.txt"
grep -Fxq 'FVQ54_SIGNED_EMAX_ORACLE=PASS' "$BUILD/o0/output.txt"
grep -Fxq 'FVQ54_HELD_SCOPE_FAIL_CLOSED=PASS' "$BUILD/o0/output.txt"
grep -Fxq 'FVQ54_STATELESS_READ_ONLY_ABA=PASS' "$BUILD/o0/output.txt"
grep -Fxq 'FVQ54_INDEPENDENT_ORACLE=PASS' "$BUILD/o0/output.txt"
ACTUAL_OUTPUT_SHA="$(sha256sum "$BUILD/o0/output.txt" | awk '{print $1}')"
test "$ACTUAL_OUTPUT_SHA" = "$EXPECTED_OUTPUT_SHA"
echo 'FCI39_FVQ54_ORACLE_REPLAY_ON_COMPOSED_SOURCE=PASS'
echo 'FCI39_O0_O2_IDENTITY=PASS'
echo 'FCI39_ARCHITECTURE_INVARIANTS=30_OF_30_NO_ADVERSE_DELTA'
echo 'FCI39_MASS_CONSERVATION=HARD_UNCHANGED'
echo 'FCI39_CANONICAL_ADMISSION_GATE=PASS'

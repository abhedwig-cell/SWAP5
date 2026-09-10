#!/usr/bin/env bash
set -euo pipefail

BASE=adf79478f55458c05444ad9b90e52644e6cf36b6
CANDIDATE=41628858477d6fa8d6a46de8ff1a9e69459c2eb0
FPM06D=3ec07cf0d88e52d7503098a4de19f699acf7e9e1
FVQ52=003209963ead7f14e375fca7f7d5d4b2a1996ae8

# Candidate provenance must be a one-parent production commit directly on the current canonical authority.
test "$(git rev-parse ${CANDIDATE}^)" = "$BASE"
test "$(git merge-base "$BASE" "$CANDIDATE")" = "$BASE"
echo 'FPM06E_CANONICAL_PARENT=PASS'

# Exact production delta. No runtime, process, adapter, kernel or reference materialization is admitted here.
mapfile -t actual < <(git diff --name-only "$BASE".."$CANDIDATE" -- src reference | sort)
expected=(
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_surface_evaporation_capacity_provider.f90
  src/solver/mod_surface_evaporation_capacity_contract.f90
)
if [[ "${actual[*]}" != "${expected[*]}" ]]; then
  printf 'FPM06E_FAIL production delta\nactual: %s\nexpected: %s\n' "${actual[*]}" "${expected[*]}" >&2
  exit 64
fi
for forbidden in src/runtime src/process src/adapter src/kernel reference; do
  if git diff --name-only "$BASE".."$CANDIDATE" -- "$forbidden" | grep -q .; then
    echo "FPM06E_FAIL forbidden candidate delta under $forbidden" >&2
    exit 64
  fi
done
echo 'FPM06E_RESTRICTED_PRODUCTION_DELTA=PASS'

# Exact persisted candidate blobs.
test "$(git rev-parse ${CANDIDATE}:src/solver/mod_b110_default_mvg_provider.f90)" = fea5a1681b1c3bdefce1cdbb6d48a9396c8266b6
test "$(git rev-parse ${CANDIDATE}:src/solver/mod_surface_evaporation_capacity_contract.f90)" = 551513f77caeb9c54e8c8b1cdc326be0e9d01982
test "$(git rev-parse ${CANDIDATE}:src/solver/mod_b110_surface_evaporation_capacity_provider.f90)" = 8909cdf342527a2b0266c8d9a5fc918f98556ea2
echo 'FPM06E_CANDIDATE_BLOBS=PASS'

# F-PM06D source surface remains source-bound after the newer canonical governance cycle.
test "$(git rev-parse ${BASE}:src/solver/mod_soil_water_solver_contract.f90)" = dc7b14a06f64c8ab0af9747f707b3394a5f5cbe0
test "$(git rev-parse ${BASE}:src/solver/mod_process_hydraulic_view.f90)" = d7d85fe71ced0d94b29c8d9395859ae1834f7dd6
test "$(git rev-parse ${BASE}:src/solver/mod_b110_default_mvg_provider.f90)" = 97d67eb373073b183be6d1bf5b756ecb5125dde2
test "$(git rev-parse ${BASE}:src/runtime/mod_fmr_serialized_reference_backend.f90)" = 9af5a494526810324dc00706b444e448e770cba9
git cat-file -e "${FPM06D}^{commit}" 2>/dev/null || git fetch --no-tags origin "$FPM06D" >/dev/null 2>&1
grep -Fq 'READY_FOR_SCALAR_CAPACITY_CANDIDATE' < <(git show ${FPM06D}:integration/f-pm/F-PM06D_STATUS.json)
echo 'FPM06E_FPM06D_HANDOFF=PASS'

# The independently qualified downstream structural consumer remains exact and is not copied into this candidate.
git cat-file -e "${FVQ52}^{commit}" 2>/dev/null || git fetch --no-tags origin "$FVQ52" >/dev/null 2>&1
grep -Fq 'QUALIFIED_RESTRICTED_SURFACE_EVAPORATION_STRUCTURAL_CANDIDATE_WITHIN_FROZEN_SWINTER0_SWREDU0_SCOPE' \
  < <(git show ${FVQ52}:qualification/f-vq/F-VQ52_STATUS.json)
test ! -e src/process/mod_restricted_surface_evaporation.f90
echo 'FPM06E_DOWNSTREAM_STRUCTURAL_AUTHORITY_SEPARATE=PASS'

# Guard against legacy/global coupling and accidental runtime/materialization scope growth.
CAP=src/solver/mod_b110_surface_evaporation_capacity_provider.f90
CONTRACT=src/solver/mod_surface_evaporation_capacity_contract.f90
if grep -Eiq 'MOD_grid|MOD_swap|HeadCalc|BOUNDTop|disnod|rfcp|FrArMtrx|qtop|qbot|file|path' "$CAP" "$CONTRACT"; then
  echo 'FPM06E_FAIL forbidden legacy/global/I-O dependency' >&2
  exit 64
fi
grep -Fq 'B110_SURFACE_ATMOSPHERIC_HEAD_CM = -2.75e5_real64' "$CAP"
grep -Fq 'mean-7-szym-not-qualified' "$CAP"
grep -Fq 'result%evaporation_capacity = -face_conductivity' "$CAP"
grep -Fq 'SURFACE_EVAP_CAPACITY_UNSUPPORTED_CONFIGURATION' "$CONTRACT"
echo 'FPM06E_BOUNDARY_AND_FAIL_CLOSED_SCOPE=PASS'

# Build and execute the owner qualification at O0 and O2. Output must be identical.
for opt in 0 2; do
  build="build/fpm06e/O${opt}"
  rm -rf "$build"
  mkdir -p "$build"
  flags=(-std=f2008 -ffree-line-length-none -O${opt} -J"$build" -I"$build")
  gfortran "${flags[@]}" -c src/solver/mod_soil_water_solver_contract.f90 -o "$build/contract.o"
  gfortran "${flags[@]}" -c src/solver/mod_b110_default_mvg_provider.f90 -o "$build/mvg.o"
  gfortran "${flags[@]}" -c src/solver/mod_surface_evaporation_capacity_contract.f90 -o "$build/cap_contract.o"
  gfortran "${flags[@]}" -c src/solver/mod_b110_surface_evaporation_capacity_provider.f90 -o "$build/cap_provider.o"
  gfortran "${flags[@]}" tests/fpm/test_fpm06e_restricted_surface_evaporation_capacity.f90 \
    "$build/contract.o" "$build/mvg.o" "$build/cap_contract.o" "$build/cap_provider.o" -o "$build/test_fpm06e"
  "$build/test_fpm06e" > "$build/output.txt"
  grep -Fq 'FPM06E_RESTRICTED_SURFACE_EVAPORATION_CAPACITY PASS' "$build/output.txt"
done
cmp build/fpm06e/O0/output.txt build/fpm06e/O2/output.txt
echo 'FPM06E_O0_O2_IDENTITY=PASS'

# Governance assertions: capability only, no accepted flux or mass authority, no persistent state.
DOC=integration/f-pm/F-PM06E_RESTRICTED_CAPACITY_CANDIDATE.md
AUDIT=integration/f-pm/F-PM06E_ARCHITECTURE_AUDIT.json
grep -Fq 'No top-boundary provider is changed or selected.' "$DOC"
grep -Fq 'Negative finite Emax remains signed.' "$DOC"
grep -Fq 'SWKMEAN=7 is not approximated.' "$DOC"
grep -Fq 'No persistent state is added.' "$DOC"
grep -Fq 'accepted solver top flux remains the sole water-mass authority' "$DOC"
grep -Fq '"overall": "30_OF_30_NO_ADVERSE_DELTA"' "$AUDIT"
grep -Fq '"mass_conservation": "HARD_UNCHANGED"' "$AUDIT"
echo 'FPM06E_ARCHITECTURE_INVARIANTS=30_OF_30_PASS'

echo 'FPM06E_OWNER_GATE=PASS'

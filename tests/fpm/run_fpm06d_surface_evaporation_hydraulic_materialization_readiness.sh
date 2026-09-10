#!/usr/bin/env bash
set -euo pipefail

BASE=8fa79a70a9faccaf8b63826df607a685eb75b046
FVQ52=003209963ead7f14e375fca7f7d5d4b2a1996ae8
FPM06C_CANDIDATE=c6cabe84272fef1829243e4271b2b1314233b634
FPM06C_BLOB=a213af4deec2fe854d79120899827852a57237d1

# Readiness-only: no production or reference mutation.
if git diff --name-only "$BASE"..HEAD -- src reference | grep -q .; then
  echo 'FPM06D_FAIL unexpected src/reference delta' >&2
  git diff --name-only "$BASE"..HEAD -- src reference >&2
  exit 64
fi
echo 'FPM06D_ZERO_PRODUCTION_REFERENCE_DELTA=PASS'

# Lock the exact live canonical seams used by the readiness analysis.
test "$(git rev-parse HEAD:src/solver/mod_soil_water_solver_contract.f90)" = dc7b14a06f64c8ab0af9747f707b3394a5f5cbe0
test "$(git rev-parse HEAD:src/solver/mod_process_hydraulic_view.f90)" = d7d85fe71ced0d94b29c8d9395859ae1834f7dd6
test "$(git rev-parse HEAD:src/solver/mod_b110_default_mvg_provider.f90)" = 97d67eb373073b183be6d1bf5b756ecb5125dde2
test "$(git rev-parse HEAD:src/runtime/mod_fmr_serialized_reference_backend.f90)" = 9af5a494526810324dc00706b444e448e770cba9
echo 'FPM06D_CANONICAL_SEAM_BLOBS=PASS'

VIEW=src/solver/mod_process_hydraulic_view.f90
CONTRACT=src/solver/mod_soil_water_solver_contract.f90
MVG=src/solver/mod_b110_default_mvg_provider.f90
BACKEND=src/runtime/mod_fmr_serialized_reference_backend.f90
DOC=integration/f-pm/F-PM06D_HYDRAULIC_MATERIALIZATION_READINESS.md
AUDIT=integration/f-pm/F-PM06D_ARCHITECTURE_AUDIT.json

# Existing committed/base ponding is already exposed through the accepted process view.
grep -Fq 'real(real64) :: ponding_depth = 0.0_real64' "$VIEW"
grep -Fq 'view%ponding_depth = state%ponding_depth' "$VIEW"
grep -Fq 'real(real64) :: ponding_depth = 0.0_real64' "$CONTRACT"
grep -Fq 'surface_is_ponded = base_state.ponding_depth > 1e-10 cm' "$DOC"
echo 'FPM06D_COMMITTED_BASE_PONDING_AUTHORITY=PASS'

# The current common hydraulic/process contracts deliberately have no scalar Emax capability.
if grep -Eiq 'evaporation_capacity|surface_evaporation_capacity|Emax' "$CONTRACT" "$VIEW"; then
  echo 'FPM06D_FAIL scalar evaporation-capacity capability unexpectedly already present' >&2
  exit 64
fi
echo 'FPM06D_SCALAR_EMAX_CAPABILITY_GAP_CONFIRMED=PASS'

# Current constitutive API is a full-vector evaluation and the concrete B1.10 provider carries step duration.
grep -Fq 'subroutine constitutive_evaluate_ifc' "$CONTRACT"
grep -Fq 'real(real64), intent(out) :: water_content(:), conductivity(:), capacity(:), dconductivity_dhead(:)' "$CONTRACT"
grep -Fq 'real(real64) :: step_duration = 0.0_real64' "$MVG"
grep -Fq 'if (self%step_duration <= 0.0_real64)' "$MVG"
echo 'FPM06D_FULL_VECTOR_CONSTITUTIVE_API_CONFIRMED=PASS'

# Concrete runtime already owns the physical/numerical flags that must stay out of ET.
grep -Fq 'integer :: swkmean = 1' "$BACKEND"
grep -Fq 'logical :: macropore_active = .false.' "$BACKEND"
grep -Fq 'logical :: frost_active = .false.' "$BACKEND"
grep -Fq 'real(real64) :: ponding_depth = 0.0_real64' "$BACKEND"
echo 'FPM06D_RUNTIME_HYDRAULIC_POLICY_OWNERSHIP=PASS'

# Verify the independently qualified downstream structural candidate exactly.
git cat-file -e "${FPM06C_CANDIDATE}^{commit}" 2>/dev/null || git fetch --no-tags origin "$FPM06C_CANDIDATE" >/dev/null 2>&1
test "$(git rev-parse ${FPM06C_CANDIDATE}:src/process/mod_restricted_surface_evaporation.f90)" = "$FPM06C_BLOB"
git cat-file -e "${FVQ52}^{commit}" 2>/dev/null || git fetch --no-tags origin "$FVQ52" >/dev/null 2>&1
STATUS="$(git show ${FVQ52}:qualification/f-vq/F-VQ52_STATUS.json)"
grep -Fq 'QUALIFIED_RESTRICTED_SURFACE_EVAPORATION_STRUCTURAL_CANDIDATE_WITHIN_FROZEN_SWINTER0_SWREDU0_SCOPE' <<<"$STATUS"
grep -Fq "$FPM06C_BLOB" <<<"$STATUS"
echo 'FPM06D_FVQ52_STRUCTURAL_AUTHORITY=PASS'

# Required ownership, validation, transaction, mass, time and optionality decisions must remain explicit.
grep -Fq '`Emax` is owned by soil hydraulics, not ET.' "$DOC"
grep -Fq 'The scalar `Emax` should remain signed.' "$DOC"
grep -Fq 'F-PM06D adds no mass contribution.' "$DOC"
grep -Fq 'accepted solver-returned external top flux' "$DOC"
grep -Fq 'No day boundary is required.' "$DOC"
grep -Fq 'frost inactive;' "$DOC"
grep -Fq 'macropore surface scaling inactive;' "$DOC"
grep -Fq 'no new persistent state' "$DOC"
echo 'FPM06D_MASS_TRANSACTION_TIME_OPTIONALITY_CONTRACT=PASS'

grep -Fq '"overall": "30_OF_30_NO_ADVERSE_DELTA"' "$AUDIT"
grep -Fq '"mass_conservation": "HARD_UNCHANGED"' "$AUDIT"
echo 'FPM06D_ARCHITECTURE_INVARIANTS=30_OF_30_PASS'

echo 'FPM06D_GATE=PASS'

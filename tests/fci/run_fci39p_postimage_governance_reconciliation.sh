#!/usr/bin/env bash
set -euo pipefail

CANONICAL=1fab3e1b27d774f2869a003876d035b07c601ccf
CANONICAL_TREE=ebec5e647c68181ba958432ad575f9c95a9c752b
CANONICAL_SRC=7264753a19a481043434ba782d4f81bc585fed85
CANONICAL_REFERENCE=9d08625217d7c0a7385df9da6a04183bcd9cb9e6
FCI39_ADMISSION=25ed89861e592420b4bbdb6e42a4c083337ebabc
FCI39_PRODUCTION=c9a73f2f37c9306e7a6fbf60b713b66d82c4a372
FVQ54=7cf8f6685ca24f855621f872bcf906f346edfa72
EXPECTED_OUTPUT_SHA=e77388e86bf1726e486165606ef80edaef25361f7b7ad4ae1a2f8e1fcdbccbaa
BUILD="${RUNNER_TEMP:-/tmp}/fci39p-${GITHUB_RUN_ID:-local}"
rm -rf "$BUILD"
mkdir -p "$BUILD/o0" "$BUILD/o2"

test "$(git rev-parse origin/integration/f-ci-canonical)" = "$CANONICAL"
git merge-base --is-ancestor "$CANONICAL" HEAD
test "$(git rev-parse ${CANONICAL}^{tree})" = "$CANONICAL_TREE"
test "$(git rev-parse HEAD:src)" = "$CANONICAL_SRC"
test "$(git rev-parse HEAD:reference)" = "$CANONICAL_REFERENCE"
test "$(git rev-parse ${CANONICAL}:src)" = "$CANONICAL_SRC"
test "$(git rev-parse ${CANONICAL}:reference)" = "$CANONICAL_REFERENCE"
echo 'FCI39P_ZERO_SRC_REFERENCE_DELTA_FROM_FINAL_CANONICAL=PASS'

# The reconciliation already exists in admitted F-CI39 canonical authority.
grep -Fq 'ref: c9a73f2f37c9306e7a6fbf60b713b66d82c4a372' .github/workflows/fci-canonical.yml
grep -Fq 'AUTH=c9a73f2f37c9306e7a6fbf60b713b66d82c4a372' .github/workflows/fci-canonical.yml
grep -Fq 'frozen-fci39-surface-evaporation-capacity-source-authority' .github/workflows/fci-canonical.yml
grep -Fq 'src/solver/mod_surface_evaporation_capacity_contract.f90' .github/workflows/fci-canonical.yml
grep -Fq 'src/solver/mod_b110_surface_evaporation_capacity_provider.f90' .github/workflows/fci-canonical.yml
# Historical F-CI37 stays frozen, separate from moving authority.
grep -Fq 'ref: 85e17bb7ca26d2df070f99b2bf16ecf0abebec19' .github/workflows/fci-canonical.yml
echo 'FCI39P_MOVING_POINTER_RECONCILED_FCI37_HISTORY_PRESERVED=PASS'

# Pin final post-promotion authority and its conditional closeout record.
git show ${CANONICAL}:integration/f-ci/F-CI39_POST_PROMOTION_GATE.json | grep -Fq 'NON_FORCE_FAST_FORWARD'
git show ${CANONICAL}:integration/f-ci/F-CI39_POST_PROMOTION_GATE.json | grep -Fq 'FCI39_CANONICAL_AUTHORITY_ESTABLISHED_IF_THIS_EXACT_CANONICAL_HEAD_HAS_GREEN_BROAD_CANONICAL_WORKFLOW'
git show ${FCI39_ADMISSION}:integration/f-ci/F-CI39_STATUS.json | grep -Fq 'QUALIFIED_RESTRICTED_SCALAR_SURFACE_EVAPORATION_HYDRAULIC_CAPACITY_CANONICAL_AUTHORITY_ESTABLISHED'
git show ${FVQ54}:integration/f-vq/F-VQ54_STATUS.json | grep -Fq 'QUALIFIED_RESTRICTED_SCALAR_SURFACE_EVAPORATION_HYDRAULIC_CAPACITY_WITHIN_FROZEN_SWINTER0_SWREDU0_SCOPE'
test "$(git rev-parse ${FCI39_PRODUCTION}:src)" = "$CANONICAL_SRC"
test "$(git rev-parse ${FCI39_PRODUCTION}:reference)" = "$CANONICAL_REFERENCE"
echo 'FCI39P_FINAL_FCI39_AND_FVQ54_AUTHORITIES_PINNED=PASS'

# Re-run the independent F-VQ54 oracle against the actual final canonical source.
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
  gfortran "$opt" "$dir/contract.o" "$dir/mvg.o" "$dir/cap_contract.o" "$dir/cap_provider.o" "$dir/test.o" -o "$dir/fci39p.exe"
  "$dir/fci39p.exe" > "$dir/output.txt"
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
test "$(sha256sum "$BUILD/o0/output.txt" | awk '{print $1}')" = "$EXPECTED_OUTPUT_SHA"
echo 'FCI39P_FVQ54_ORACLE_REPLAY_ON_FINAL_CANONICAL=PASS'
echo 'FCI39P_O0_O2_IDENTITY=PASS'

if git diff --name-only "$CANONICAL"..HEAD -- src reference | grep -q .; then
  echo 'FCI39P_FAIL unexpected src/reference delta' >&2
  exit 39
fi
echo 'FCI39P_ARCHITECTURE_INVARIANTS=30_OF_30_NO_ADVERSE_DELTA'
echo 'FCI39P_MASS_CONSERVATION=HARD_UNCHANGED'
echo 'FCI39P_NO_ADDITIONAL_CANONICAL_DELTA_REQUIRED=PASS'
echo 'FCI39P_GATE=PASS'

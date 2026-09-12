#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fci51-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

PREIMAGE=eba90d79010b095b6556e93bd8b77a8c28d25560
PROVIDER_BLOB=1234bcb8e3b47ebe8e67b0bac6af35e09e9056da
RATE_BLOB=5a0e8387157c5d1e1a6a94a24c19c7519c6bfcd5

git merge-base --is-ancestor "$PREIMAGE" HEAD || {
  echo 'FCI51_PREIMAGE_ANCESTRY=FAIL' >&2
  exit 1
}
echo 'FCI51_PREIMAGE_ANCESTRY=PASS'

changed_src="$(git diff --name-only "$PREIMAGE"..HEAD -- src)"
[[ "$changed_src" == "src/crop/mod_crop_et_canopy_view_provider.f90" ]] || {
  echo 'FCI51_PRODUCTION_SCOPE=FAIL' >&2
  printf '%s\n' "$changed_src" >&2
  exit 1
}
echo 'FCI51_PRODUCTION_SCOPE_SINGLE_PROVIDER=PASS'

cat > "$BUILD/expected-files.txt" <<'EOF'
.github/workflows/fci51-wof43a-current-canonical-admission.yml
.github/workflows/fvq37-fwof43a-crop-et-canopy-view-provider.yml
.github/workflows/fwof43a-crop-et-canopy-view-provider.yml
integration/f-ci/F-CI51_CANDIDATE_CONTRACT.json
integration/f-vq/F-VQ37_QUALIFICATION.json
integration/f-vq/F-VQ37_SOURCE_REDERIVATION.json
integration/f-vq/F-VQ37_STATUS.json
integration/f-wof/F-WOF43A_CANDIDATE_CONTRACT.json
integration/f-wof/F-WOF43A_QUALIFICATION_EVIDENCE.json
integration/f-wof/F-WOF43A_STATUS.json
src/crop/mod_crop_et_canopy_view_provider.f90
tests/fci/run_fci51_wof43a_current_canonical_gate.sh
tests/fvq/run_fvq37_fwof43a_crop_et_canopy_view_independent_gate.sh
tests/fvq/test_fvq37_crop_et_canopy_view_independent.f90
tests/fwof/run_fwof43a_crop_et_canopy_view_provider_gate.sh
tests/fwof/test_fwof43a_crop_et_canopy_view_provider.f90
EOF
git diff --name-only "$PREIMAGE"..HEAD | LC_ALL=C sort > "$BUILD/actual-files.txt"
LC_ALL=C sort -o "$BUILD/expected-files.txt" "$BUILD/expected-files.txt"
diff -u "$BUILD/expected-files.txt" "$BUILD/actual-files.txt" || {
  echo 'FCI51_RECOMPOSITION_ALLOWLIST=FAIL' >&2
  exit 1
}
echo 'FCI51_RECOMPOSITION_ALLOWLIST=PASS'

check_blob() {
  local path="$1" expected="$2" actual
  actual="$(git hash-object "$path")"
  [[ "$actual" == "$expected" ]] || {
    echo "FCI51_BLOB_LOCK=FAIL path=$path expected=$expected actual=$actual" >&2
    exit 1
  }
}

check_blob src/crop/mod_crop_et_canopy_view_provider.f90 "$PROVIDER_BLOB"
check_blob src/crop/mod_wofost_rate_table.f90 "$RATE_BLOB"
check_blob .github/workflows/fwof43a-crop-et-canopy-view-provider.yml a67b450167b77d0ba7d6369195a559f885bc9998
check_blob integration/f-wof/F-WOF43A_CANDIDATE_CONTRACT.json b1e637e59a00f50cfe6089491e11fffde0aec6ad
check_blob integration/f-wof/F-WOF43A_QUALIFICATION_EVIDENCE.json d6e393f1150632d0e81ce8714e78ca99ad42f5da
check_blob integration/f-wof/F-WOF43A_STATUS.json 5b60b4e183f91f41f3c1aea509d0fac87de9709b
check_blob tests/fwof/run_fwof43a_crop_et_canopy_view_provider_gate.sh 6624184cc18b92fdeed297d039f5dccd427d2512
check_blob tests/fwof/test_fwof43a_crop_et_canopy_view_provider.f90 0fda482e6d1b129accd00d56ca100971d5f763ea
check_blob .github/workflows/fvq37-fwof43a-crop-et-canopy-view-provider.yml b1bf749740e9794a09b0fe8dff38e9accc0c6736
check_blob integration/f-vq/F-VQ37_QUALIFICATION.json 90fdadb57c531f3bfe3d6020dc21ee14a3a1ce9e
check_blob integration/f-vq/F-VQ37_SOURCE_REDERIVATION.json 95b1f140b608793c58a93063e5bc0b55a9a83c36
check_blob integration/f-vq/F-VQ37_STATUS.json 3920a742176a8f22254ea12b6ac52984b5467fe6
check_blob tests/fvq/run_fvq37_fwof43a_crop_et_canopy_view_independent_gate.sh d01956b6bf88239487cef00dff93dfd783efb7df
check_blob tests/fvq/test_fvq37_crop_et_canopy_view_independent.f90 70a3e63e9fea0075197e4abf3a78ac9053ad4347
echo 'FCI51_DONOR_AND_DEPENDENCY_BLOB_LOCKS=PASS'

python3 - <<'PY'
from pathlib import Path
p = Path('src/crop/mod_crop_et_canopy_view_provider.f90').read_text().lower()
for forbidden in [
    'headcalc', 'mod_process_hydraulic_view', 'mod_root_water_uptake_process',
    'mod_reference_et_demand_process', 'mod_kernel_transactions',
    'open(', 'read(', 'write(', 't1900', 'iyear', 'calendar',
    'jacobian', 'newton', 'file=', 'unit_'
]:
    assert forbidden not in p, forbidden
assert 'allocatable' not in p
print('FCI51_ARCHITECTURE_BOUNDARY_STATIC=PASS')
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c src/crop/mod_wofost_rate_table.f90 -o "$OUT/rate.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c src/crop/mod_crop_et_canopy_view_provider.f90 -o "$OUT/provider.o"

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fwof/test_fwof43a_crop_et_canopy_view_provider.f90 -o "$OUT/owner_test.o"
  gfortran -O"$opt" "$OUT/rate.o" "$OUT/provider.o" "$OUT/owner_test.o" -o "$OUT/owner_test"
  "$OUT/owner_test" > "$OUT/owner.txt" 2>&1
  for marker in \
    'FWO43A_B110_VCOVER_FORMULA=PASS' \
    'FWO43A_B110_CF_AFGEN=PASS' \
    'FWO43A_B110_FCO2TRA_AFGEN=PASS' \
    'FWO43A_INACTIVE_DEPENDENCIES_MINIMAL=PASS' \
    'FWO43A_FAIL_CLOSED_ACTIVE_DOMAIN=PASS' \
    'FWO43A_STATELESS_A_B_A_IDENTITY=PASS' \
    'FWO43A_CROP_ET_CANOPY_VIEW_TEST PASS'; do
    grep -Fqx "$marker" "$OUT/owner.txt"
  done
  echo "FCI51_OWNER_REPLAY_O${opt}=PASS"

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fvq/test_fvq37_crop_et_canopy_view_independent.f90 -o "$OUT/independent_test.o"
  gfortran -O"$opt" "$OUT/rate.o" "$OUT/provider.o" "$OUT/independent_test.o" -o "$OUT/independent_test"
  "$OUT/independent_test" > "$OUT/independent.txt" 2>&1
  grep -Fxq 'FVQ37_INDEPENDENT_GRID_CASES=29000' "$OUT/independent.txt"
  grep -Fxq 'FVQ37_INDEPENDENT_EDGE_CASES=13' "$OUT/independent.txt"
  for marker in \
    'FVQ37_FROZEN_SOURCE_VCOVER_ORACLE=PASS' \
    'FVQ37_FROZEN_SOURCE_CF_AFGEN_ORACLE=PASS' \
    'FVQ37_FROZEN_SOURCE_FCO2TRA_ORACLE=PASS' \
    'FVQ37_FIXED_WOFOST_SEMANTIC_PARAMETER_PROFILES=PASS' \
    'FVQ37_FAIL_CLOSED_FP_TRAP_EDGES=PASS' \
    'FVQ37_INDEPENDENT_CROP_ET_CANOPY_QUALIFICATION PASS'; do
    grep -Fqx "$marker" "$OUT/independent.txt"
  done
  echo "FCI51_INDEPENDENT_REPLAY_O${opt}=PASS"
done

cmp "$BUILD/o0/owner.txt" "$BUILD/o2/owner.txt"
cmp "$BUILD/o0/independent.txt" "$BUILD/o2/independent.txt"
echo 'FCI51_OWNER_O0_O2_IDENTITY=PASS'
echo 'FCI51_INDEPENDENT_O0_O2_IDENTITY=PASS'
echo "FCI51_OWNER_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/owner.txt" | cut -d' ' -f1)"
echo "FCI51_INDEPENDENT_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/independent.txt" | cut -d' ' -f1)"
echo 'FCI51_WOF43A_CURRENT_CANONICAL_GATE PASS'

#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fvq35-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

CANDIDATE=c1bbe73cd0deced17f979a601fd6169036d7076b
changed_src="$(git diff --name-only "$CANDIDATE" -- src)"
[[ -z "$changed_src" ]] || {
  echo "FVQ35_CANDIDATE_PRODUCTION_MODIFIED" >&2
  printf '%s\n' "$changed_src" >&2
  exit 1
}
echo 'FVQ35_CANDIDATE_PRODUCTION_IMMUTABLE=PASS'

changed_owner_tests="$(git diff --name-only "$CANDIDATE" -- tests/fpm)"
[[ -z "$changed_owner_tests" ]] || {
  echo "FVQ35_OWNER_TESTS_MODIFIED" >&2
  printf '%s\n' "$changed_owner_tests" >&2
  exit 1
}
echo 'FVQ35_OWNER_TESTS_IMMUTABLE=PASS'

check_blob() {
  local path="$1" expected="$2" actual
  actual="$(git hash-object "$path")"
  [[ "$actual" == "$expected" ]] || {
    echo "FVQ35_BLOB_MISMATCH $path expected=$expected actual=$actual" >&2
    exit 1
  }
}

check_blob src/process/mod_reference_et_demand_process.f90 f5e88ec5089fd3b57ac111065fab2aa32dde0fae
check_blob src/process/mod_root_water_uptake_process.f90 e6134587cf3c0164bbe09f2f4c87aef6886aaeb3
check_blob src/crop/mod_wofost_crop_owner_state.f90 31bb390a0b70bec0a3f525f1d704a2c53890f9b4
echo 'FVQ35_CANDIDATE_AND_OWNER_SOURCE_LOCKS=PASS'

python3 - <<'PY'
from pathlib import Path
plan = Path('integration/f-vq/F-VQ35_QUALIFICATION_PLAN.json').read_text()
for required in [
    '5a095c16ec82fa544f7dd20ba568ba3a2b72906bff7dd3505af16e6722d86822',
    'etr * (1 - vcover)',
    'etr * (1 - vcover) * cfevappond',
    'etr * vcover * cf',
    'max(es0 * 0.1, 0)',
    'max(ep0 * 0.1, 0)',
    'owner_expected_literals_used_as_oracle'
]:
    assert required in plan, required
assert '"owner_expected_literals_used_as_oracle": false' in plan
print('FVQ35_FROZEN_SOURCE_REDERIVATION_LOCK=PASS')
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    src/process/mod_reference_et_demand_process.f90 -o "$OUT/mod_reference_et_demand_process.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    tests/fvq/test_fvq35_reference_et_demand_oracle.f90 -o "$OUT/test_fvq35_reference_et_demand_oracle.o"
  gfortran -O"$opt" "$OUT/mod_reference_et_demand_process.o" "$OUT/test_fvq35_reference_et_demand_oracle.o" \
    -o "$OUT/test_fvq35_reference_et_demand_oracle"
  "$OUT/test_fvq35_reference_et_demand_oracle" > "$OUT/output.txt" 2>&1 || {
    cat "$OUT/output.txt" >&2
    exit 1
  }

  for marker in \
    'FVQ35_INDEPENDENT_GRID_CASES=1700' \
    'FVQ35_INDEPENDENT_B110_EQUATION_ORACLE=PASS' \
    'FVQ35_MM_TO_CM_UNIT_CONVERSION=PASS' \
    'FVQ35_NONEMERGED_VCOVER_SEMANTICS=PASS' \
    'FVQ35_INACTIVE_CROP_FACTOR_DEPENDENCY=PASS' \
    'FVQ35_FAIL_CLOSED_ACTIVE_DOMAIN=PASS' \
    'FVQ35_STATELESS_REPLAY=PASS' \
    'FVQ35_REFERENCE_ET_SCIENTIFIC_ORACLE PASS'; do
      grep -Fq "$marker" "$OUT/output.txt"
  done
  echo "FVQ35_QUALIFICATION_O${opt}=PASS"
done

cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
echo 'FVQ35_QUALIFICATION_O0_O2_OUTPUT_IDENTITY=PASS'
cat "$BUILD/o0/output.txt"
echo "FVQ35_QUALIFICATION_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/output.txt" | cut -d' ' -f1)"
echo 'FVQ35_FPM06A_REFERENCE_ET_DEMAND_QUALIFICATION PASS'

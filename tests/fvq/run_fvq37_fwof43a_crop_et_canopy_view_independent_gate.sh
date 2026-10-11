#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fvq37-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

OWNER=df72af4d2dc5b3255777733f8a725dca20583785
PROVIDER_BLOB=1234bcb8e3b47ebe8e67b0bac6af35e09e9056da
OWNER_TEST_BLOB=0fda482e6d1b129accd00d56ca100971d5f763ea
AFGEN_BLOB=5a0e8387157c5d1e1a6a94a24c19c7519c6bfcd5

changed_src="$(git diff --name-only "$OWNER" -- src)"
if [[ -n "$changed_src" ]]; then
  echo 'FVQ37_PRODUCTION_SOURCE_CHANGED=FAIL' >&2
  printf '%s\n' "$changed_src" >&2
  exit 1
fi
echo 'FVQ37_PRODUCTION_SOURCE_UNCHANGED=PASS'

check_blob() {
  local path="$1" expected="$2" actual
  actual="$(git hash-object "$path")"
  if [[ "$actual" != "$expected" ]]; then
    echo "FVQ37_BLOB_LOCK_FAIL path=$path expected=$expected actual=$actual" >&2
    exit 1
  fi
}

check_blob src/crop/mod_crop_et_canopy_view_provider.f90 "$PROVIDER_BLOB"
check_blob tests/fwof/test_fwof43a_crop_et_canopy_view_provider.f90 "$OWNER_TEST_BLOB"
check_blob src/crop/mod_wofost_rate_table.f90 "$AFGEN_BLOB"
echo 'FVQ37_PROVIDER_SOURCE_LOCK=PASS'
echo 'FVQ37_OWNER_TEST_UNCHANGED_LOCK=PASS'
echo 'FVQ37_AFGEN_SUBSTRATE_SOURCE_LOCK=PASS'

python3 - <<'PY'
from pathlib import Path
p = Path('tests/fvq/test_fvq37_crop_et_canopy_view_independent.f90').read_text()
low = p.lower()
assert 'oracle_afgen' in low
assert 'test_fwof43a_crop_et_canopy_view_provider' not in low
assert 'run_fwof43a_crop_et_canopy_view_provider_gate' not in low
assert '29000' not in low  # count must emerge from the independent loops, not be hard-coded by the test
assert 'semantic_profile' in low
assert 'fixed-crop-compatible' in low
assert 'wofost-compatible' in low
print('FVQ37_INDEPENDENT_ORACLE_STATIC=PASS')
print('FVQ37_OWNER_TEST_NOT_REUSED=PASS')
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    src/crop/mod_wofost_rate_table.f90 -o "$OUT/mod_wofost_rate_table.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    src/crop/mod_crop_et_canopy_view_provider.f90 -o "$OUT/mod_crop_et_canopy_view_provider.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    tests/fvq/test_fvq37_crop_et_canopy_view_independent.f90 -o "$OUT/test_fvq37.o"
  gfortran -O"$opt" \
    "$OUT/mod_wofost_rate_table.o" \
    "$OUT/mod_crop_et_canopy_view_provider.o" \
    "$OUT/test_fvq37.o" \
    -o "$OUT/test_fvq37"

  "$OUT/test_fvq37" > "$OUT/output.txt" 2>&1 || {
    cat "$OUT/output.txt" >&2
    exit 1
  }

  grep -Fxq 'FVQ37_INDEPENDENT_GRID_CASES=29000' "$OUT/output.txt"
  grep -Fxq 'FVQ37_INDEPENDENT_EDGE_CASES=13' "$OUT/output.txt"
  for marker in \
    'FVQ37_FROZEN_SOURCE_VCOVER_ORACLE=PASS' \
    'FVQ37_FROZEN_SOURCE_CF_AFGEN_ORACLE=PASS' \
    'FVQ37_FROZEN_SOURCE_FCO2TRA_ORACLE=PASS' \
    'FVQ37_FIXED_WOFOST_SEMANTIC_PARAMETER_PROFILES=PASS' \
    'FVQ37_NONEMERGED_COVER_AND_INACTIVE_DEPENDENCIES=PASS' \
    'FVQ37_CO2_DISABLED_DEPENDENCY_MINIMALITY=PASS' \
    'FVQ37_AFGEN_ENDPOINT_AND_INTERPOLATION=PASS' \
    'FVQ37_FAIL_CLOSED_FP_TRAP_EDGES=PASS' \
    'FVQ37_INDEPENDENT_CROP_ET_CANOPY_QUALIFICATION PASS'; do
      grep -Fqx "$marker" "$OUT/output.txt"
  done
  echo "FVQ37_INDEPENDENT_O${opt}=PASS"
done

cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
echo 'FVQ37_INDEPENDENT_O0_O2_OUTPUT_IDENTITY=PASS'
cat "$BUILD/o0/output.txt"
echo "FVQ37_INDEPENDENT_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/output.txt" | cut -d' ' -f1)"
echo 'FVQ37_INDEPENDENT_GATE PASS'

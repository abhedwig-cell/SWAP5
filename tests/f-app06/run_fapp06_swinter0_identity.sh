#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-fapp06-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "F_APP06_FAIL $*" >&2; exit 1; }

BASE=0e68a716f655f9bba3a0962cf35ccb724b5184c3
expected_src=$'src/process/mod_pmdirect_swetr0_process.f90\nsrc/runtime/mod_fmr_pmdirect_swinter0_dynamic_top_binding.f90'
changed_src="$(git diff --name-only "$BASE" -- src | sort)"
[[ "$changed_src" == "$expected_src" ]] || { echo "$changed_src" >&2; fail "unexpected production delta"; }
echo 'F_APP06_EXACT_TWO_FILE_PRODUCTION_DELTA=PASS'

check_blob(){ local path="$1" expected="$2"; [[ "$(git hash-object "$path")" == "$expected" ]] || fail "protected blob drift $path"; }
check_blob src/process/mod_rutter_interception_process.f90 fd6ba136e02c13add1933ca6d63f25b2e7c5d822
check_blob src/runtime/mod_fmr_pmdirect_ptra_root_input_binding.f90 89d2d42e85c51d0b174d0382dabd3ec8f7417b68
check_blob src/runtime/mod_fmr_pmdirect_surface_evaporation_binding.f90 1a67d8a25727c2e821dd11e4853aa925e43cd95b
check_blob src/solver/mod_b110_dynamic_top_boundary_provider.f90 3eadae0f32aba49534cd58464e28c0af5bc9bf7d
echo 'F_APP06_PROTECTED_FAPP04_FAPP05_OWNERS=PASS'

python3 - <<'PY'
from pathlib import Path
p=Path('src/process/mod_pmdirect_swetr0_process.f90').read_text()
b=Path('src/runtime/mod_fmr_pmdirect_swinter0_dynamic_top_binding.f90').read_text()
low=(p+'\n'+b).lower()
for forbidden in ['mod_kernel_transactions','mod_canonical_contracts','headcalc','newton','jacobian','open(','read(']:
    assert forbidden not in low, forbidden
for required in [
    'apply_swinter0_identity_interval',
    'interval_result%net_rain_cm_per_day = weather%gross_rain_cm_d',
    'net_surface_irrigation_cm_per_day = gross_surface_irrigation_cm_per_day',
    'interval_result%wet_canopy_fraction = 0.0_real64',
    'interval_result%interception_rate_cm_per_day = 0.0_real64',
    'daily_result%potential_transpiration_dry_cm_per_day',
    'bound_request%precipitation_rate_cm_per_day = net_rain',
    'bound_request%irrigation_rate_cm_per_day = net_surface_irrigation_cm_per_day',
]:
    assert required in p+b, required
print('F_APP06_STATIC_IDENTITY_MAPPING=PASS')
PY

COMMON=(-std=f2008 -pedantic-errors -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
for opt in 0 2; do
  OUT="$BUILD/o$opt"; mkdir -p "$OUT"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c src/process/mod_pmdirect_swetr0_process.f90 -o "$OUT/pmdirect.o"
  gfortran "${COMMON[@]}" -Wno-error=unused-dummy-argument -O"$opt" -J "$OUT" -I "$OUT" -c src/solver/mod_soil_water_solver_contract.f90 -o "$OUT/swcontract.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c src/solver/mod_b110_default_mvg_provider.f90 -o "$OUT/mvg.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c src/process/mod_restricted_surface_evaporation.f90 -o "$OUT/evap.o"
  gfortran "${COMMON[@]}" -Wno-error=compare-reals -O"$opt" -J "$OUT" -I "$OUT" -c src/solver/mod_b110_dynamic_top_boundary_provider.f90 -o "$OUT/dyntop.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c src/runtime/mod_fmr_pmdirect_swinter0_dynamic_top_binding.f90 -o "$OUT/binding.o"
  gfortran "${COMMON[@]}" -Wno-error=compare-reals -O"$opt" -J "$OUT" -I "$OUT" -c tests/f-app06/test_swinter0_identity.f90 -o "$OUT/test06.o"
  gfortran -O"$opt" "$OUT/pmdirect.o" "$OUT/swcontract.o" "$OUT/mvg.o" "$OUT/evap.o" "$OUT/dyntop.o" "$OUT/binding.o" "$OUT/test06.o" -o "$OUT/test06"
  "$OUT/test06" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; fail "F-APP06 runtime O$opt"; }

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fapp/test_fapp03_pmdirect_swetr0_process.f90 -o "$OUT/test03.o"
  gfortran -O"$opt" "$OUT/pmdirect.o" "$OUT/test03.o" -o "$OUT/test03"
  "$OUT/test03" >> "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; fail "F-APP03 regression O$opt"; }

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/f-app05/test_hupsel_swcf2_pmdirect_daily.f90 -o "$OUT/test05.o"
  gfortran -O"$opt" "$OUT/pmdirect.o" "$OUT/test05.o" -o "$OUT/test05"
  "$OUT/test05" >> "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; fail "F-APP05 regression O$opt"; }

  for marker in     F_APP06_SWINTER0_IDENTITY=PASS     F_APP06_DYNAMIC_TOP_RAIN_IRRIGATION_MAPPING=PASS     F_APP06_DYNAMIC_TOP_OTHER_FIELDS_PRESERVED=PASS     F_APP06_FAIL_CLOSED=PASS     'F-APP03 PMdirect SWETR=0 restricted regression PASS'     F-APP05_HUPSEL_SWCF2_PMDIRECT_DAILY_PASS; do
      grep -Fq "$marker" "$OUT/output.txt" || fail "missing marker O$opt: $marker"
  done
  echo "F_APP06_O${opt}=PASS"
done
cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || { diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true; fail "O0/O2 output drift"; }
cat "$BUILD/o0/output.txt"
echo "F_APP06_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/output.txt" | awk '{print $1}')"
echo 'F_APP06_OWNER_QUALIFICATION=PASS'

FIX=tests/f-app06/fixtures/hupsel_swinter0_b111_exact.csv.gz
test "$(git hash-object "$FIX")" = 344c00d49717374a20772aa006edef720432d387 || fail "exact B1.11 fixture blob drift"
python3 - "$FIX" "$BUILD/exact.csv" <<'PY'
import hashlib,sys,zlib
data=open(sys.argv[1],"rb").read()
assert data[:3] == b"\x1f\x8b\x08"
assert data[3] == 0, "unexpected gzip flags"
# The repository blob's gzip trailer was corrupted during binary transport.
# Recover only the DEFLATE payload, then authenticate the exact raw oracle.
raw=zlib.decompress(data[10:-8], -zlib.MAX_WBITS)
assert hashlib.sha256(raw).hexdigest()=="e802cf68da69075fd91985046d2e52fcecb0ae52ffacd42b437340fc783a86a0"
open(sys.argv[2],"wb").write(raw)
PY
for opt in 0 2; do
  OUT="$BUILD/exact-o$opt"; mkdir -p "$OUT"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c src/process/mod_pmdirect_swetr0_process.f90 -o "$OUT/pmdirect.o"
  gfortran "${COMMON[@]}" -Wno-error=compare-reals -O"$opt" -J "$OUT" -I "$OUT" -c tests/f-app06/test_swinter0_exact_b111.f90 -o "$OUT/test.o"
  gfortran -O"$opt" "$OUT/pmdirect.o" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" "$BUILD/exact.csv" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; fail "3505-record oracle O$opt"; }
  grep -Fq 'F_APP06_EXACT_B111_RECORDS=3505' "$OUT/output.txt" || fail "exact record count O$opt"
  grep -Fq 'F_APP06_EXACT_3505_B111_ROUTE=PASS' "$OUT/output.txt" || fail "exact oracle marker O$opt"
done
cmp -s "$BUILD/exact-o0/output.txt" "$BUILD/exact-o2/output.txt" || { diff -u "$BUILD/exact-o0/output.txt" "$BUILD/exact-o2/output.txt" >&2 || true; fail "exact oracle O0/O2 drift"; }
cat "$BUILD/exact-o0/output.txt"
echo "F_APP06_EXACT_OUTPUT_SHA256=$(sha256sum "$BUILD/exact-o0/output.txt" | awk '{print $1}')"
echo 'F_APP06_EXHAUSTIVE_B111_QUALIFICATION=PASS'

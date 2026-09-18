#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-ppa-low02-independent-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

fail(){ echo "PPA_LOW02_INDEPENDENT_GATE_FAIL $*" >&2; exit 1; }

AUDIT="docs/audits/PPA_WU02_SOURCE_BOUND_LOWER_BOUNDARY_ENVELOPE.md"
grep -Fq '24ce2768b3804ca1744457e8a7adcf101e37a4c1390049df23179e09816957e2' "$AUDIT" || fail 'B1.11 manifest authority missing'
grep -Fq 'boundbottom.f90=5735f2b6e70408d304f6f5fa35ba659fb3422e03109630e27368933f5c10836e' "$AUDIT" || fail 'B1.11 BoundBottom identity missing'
grep -Fq 'readswap.f90' "$AUDIT" || fail 'B1.11 readswap authority missing'
grep -Fq 'At extremely dry bottom pressure head (< -1e7 cm)' "$AUDIT" || fail 'dry continuation authority missing'
grep -Fq 'sinusoid or time table' "$AUDIT" || fail 'time-law authority missing'

python3 - <<'PY'
from pathlib import Path
import json

pre = json.loads(Path("integration/audits/PPA_LOW02_TIME_PREREGISTRATION.json").read_text())
assert pre["authority"]["member_manifest_sha256"] == "24ce2768b3804ca1744457e8a7adcf101e37a4c1390049df23179e09816957e2"
assert pre["authority"]["boundbottom_sha256"] == "5735f2b6e70408d304f6f5fa35ba659fb3422e03109630e27368933f5c10836e"
assert pre["authority"]["headcalc_sha256"] == "db667598dd0a9dbc2cd651d63f0074d3051db748fa45ee460da9c61904c113f5"

adapter = Path("src/adapter/mod_b110_legacy_swbotb2_application_control.f90").read_text().lower()
backend = Path("src/runtime/mod_fmr_serialized_reference_backend.f90").read_text().lower()

assert "twopi = 8.0_real64 * atan(1.0_real64)" in adapter
assert "freq = twopi / 365.0_real64" in adapter
assert "legacy_start_t1900" in adapter
assert "legacy_end_t1900" in adapter
assert "bottom_pressure_head_cm < b110_swbotb2_dry_head_cm" in adapter
assert "effective_bottom_mode = -2" in adapter
assert "value = y_table(1)" in adapter
assert "value = y_table(size(y_table))" in adapter

# The production backend must resolve the effective control from the physical
# trial-start state and must not mutate the configured mode itself.
assert "physical_control%pressure_head(physical_control%active_nodes)" in backend
assert "request%boundary%bottom_mode = effective_bottom_mode" in backend
assert "request%boundary%bottom_flux = effective_bottom_flux" in backend
assert "self%bottom_mode =" not in backend[backend.index("subroutine fmr_serialized_advance"):backend.index("end subroutine fmr_serialized_advance")]

print("PPA_LOW02_INDEPENDENT_B111_AUTHORITY_LOCK=PASS")
print("PPA_LOW02_INDEPENDENT_BACKEND_NO_SELECTOR_MUTATION=PASS")
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" \
    -c src/adapter/mod_b110_legacy_swbotb2_application_control.f90 -o "$OUT/control.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" \
    -c tests/fvq/test_ppa_low02_time_independent.f90 -o "$OUT/test.o"
  gfortran -O"$opt" "$OUT/control.o" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" > "$OUT/output.txt" 2>&1 || {
    cat "$OUT/output.txt" >&2
    fail "runtime O$opt"
  }
  grep '^PPA_LOW02_' "$OUT/output.txt" > "$OUT/stable.txt"
  grep -Fq 'PPA-LOW02-TIME INDEPENDENT QUALIFICATION PASS' "$OUT/output.txt" || fail "missing final marker O$opt"
done

diff -u "$BUILD/o0/stable.txt" "$BUILD/o2/stable.txt"
cat "$BUILD/o0/output.txt"

git diff --check -- \
  src/adapter/mod_b110_legacy_swbotb2_application_control.f90 \
  src/runtime/mod_fmr_serialized_reference_backend.f90 \
  tests/fvq/test_ppa_low02_time_independent.f90 \
  tests/fvq/run_ppa_low02_time_independent.sh

echo 'PPA_LOW02_INDEPENDENT_O0_O2_IDENTITY=PASS'
echo 'PPA-LOW02-TIME INDEPENDENT GATE PASS'

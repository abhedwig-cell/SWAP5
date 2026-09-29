#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-atm02-$$"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

PYTHON="${PYTHON:-python3}"
"$PYTHON" - <<'PY'
from pathlib import Path
text = Path('src/adapter/mod_ppa_atm02_typed_meteo_ingestion.f90').read_text().lower()
for forbidden in ('open(', 'read(', 'filename', 'pathname', 'file_unit', 'cursor', 'line_number', 'date parser', 'calendar loop'):
    assert forbidden not in text, forbidden
assert 'source_covers_request' in text
assert 'source_record_index' in text
print('PPA_ATM02_KERNEL_IO_FREE_STATIC=PASS')
PY

COMMON=(-std=f2008 -pedantic-errors -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c src/process/mod_pmdirect_swetr0_process.f90 -o "$OUT/pmdirect.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c src/adapter/mod_ppa_atm02_typed_meteo_ingestion.f90 -o "$OUT/atm02.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fapp/test_ppa_atm02_typed_meteo_ingestion.f90 -o "$OUT/test.o"
  gfortran -O"$opt" "$OUT/pmdirect.o" "$OUT/atm02.o" "$OUT/test.o" -o "$OUT/test_atm02"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c src/adapter/mod_ppa_atm02_pmdirect_daily_binding.f90 -o "$OUT/binding.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fapp/test_ppa_atm02_pmdirect_daily_binding.f90 -o "$OUT/binding_test.o"
  gfortran -O"$opt" "$OUT/pmdirect.o" "$OUT/atm02.o" "$OUT/binding.o" "$OUT/binding_test.o" -o "$OUT/test_binding"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c src/adapter/mod_ppa_atm02_pmdirect_swinter0_binding.f90 -o "$OUT/swinter0.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fapp/test_ppa_atm02_pmdirect_swinter0_binding.f90 -o "$OUT/swinter0_test.o"
  gfortran -O"$opt" "$OUT/pmdirect.o" "$OUT/atm02.o" "$OUT/binding.o" "$OUT/swinter0.o" "$OUT/swinter0_test.o" -o "$OUT/test_swinter0"
  "$OUT/test_atm02" > "$OUT/output.txt"
  "$OUT/test_binding" >> "$OUT/output.txt"
  "$OUT/test_swinter0" >> "$OUT/output.txt"
  echo "PPA_ATM02_O${opt}=PASS"
done

"$PYTHON" - "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" <<'PY'
import pathlib
import sys
assert pathlib.Path(sys.argv[1]).read_bytes() == pathlib.Path(sys.argv[2]).read_bytes()
PY
cat "$BUILD/o0/output.txt"
echo 'PPA_ATM02_O0_O2_OUTPUT_IDENTITY=PASS'

#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT
python3 - "$BUILD" <<'PY'
from pathlib import Path
import gzip,hashlib,sys
source=Path('tests/qualification/ppa-wu05-migmac10-canonical-20261006/b111-andelst_meteo.999.gz')
data=gzip.decompress(source.read_bytes())
build=Path(sys.argv[1]);build.joinpath('weather.999').write_bytes(data)
build.joinpath('backup.999').write_bytes(data)
# Preserve all authentic input bytes for the positive production run. The
# negatives deliberately retain TAV while changing the underlying record.
lines=data.decode().splitlines(keepends=True)
for i,line in enumerate(lines):
    fields=line.split()
    if len(fields)==12 and fields[1:4]==['20','1','1999']:
        fields[5]='4.2';fields[6]='6.7'
        lines[i]=' '.join(fields)+'\n'
        break
else: raise AssertionError('missing authoritative historical record')
build.joinpath('altered.999').write_text(''.join(lines))
build.joinpath('bad.999').write_text("'ANDE-M' 20 1 1999 1 2 3 4 5 /\n")
print('CROP_FILE_WEATHER_INPUT_SHA256='+hashlib.sha256(data).hexdigest())
assert hashlib.sha256(data).hexdigest()=='ba5c1f880f6166842ed292c18fd12a142cfda4158002f9487fd1420e734e7b72'
# The admitted B110 bridge requires the linked grid and typed runtime
# geometry to agree. Declare a consistent physical 30cm qualification grid,
# as in the existing B19 current-source builder, without changing HeadCalc.
stub=Path('tests/fsi/fsi04_real_headcalc_stubs.f90').read_text()
replacements={
 '[-0.25d0, -0.75d0, -1.50d0, -2.50d0]':'[-2.5d0, -7.5d0, -15.0d0, -25.0d0]',
 '[0.50d0, 0.50d0, 1.00d0, 1.00d0]':'[5.0d0, 5.0d0, 10.0d0, 10.0d0]',
 'disnod(numnod+1) = 1.0d0':'disnod(numnod+1) = [2.5d0, 5.0d0, 7.5d0, 10.0d0, 5.0d0]',
}
for old,new in replacements.items():
    assert stub.count(old)==1
    stub=stub.replace(old,new)
build.joinpath('grid_stubs.f90').write_text(stub)
PY
mapfile -t SOURCES < <(python3 tests/support/augment_bartholomeus_backend_sources.py --all \
  tests/fsi/fsi04_real_headcalc_stubs.f90 src/runtime/mod_fmr_production_application_bootstrap.f90)
COMMON=(-std=f2008 -ffree-line-length-none -w -fopenmp -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
for opt in 0 2; do
  mkdir "$BUILD/o$opt"
  (
    cd "$BUILD/o$opt"
    for source in "${SOURCES[@]}"; do
      source_path="$ROOT/$source"
      if [[ "$source" == tests/fsi/fsi04_real_headcalc_stubs.f90 ]]; then source_path="$BUILD/grid_stubs.f90"; fi
      gfortran "${COMMON[@]}" -O"$opt" -J . -I . -c "$source_path"
    done
    gfortran "${COMMON[@]}" -O"$opt" -J . -I . \
      "$ROOT/tests/fmig431/test_crop_file_weather_production.f90" \
      "$ROOT/src/legacy/b1_10_port/headcalc.f90" ./*.o -o test
    ./test "$BUILD/weather.999" "$BUILD/altered.999" "$BUILD/bad.999" "$BUILD/backup.999" > output.txt 2>&1 || \
      { cat output.txt >&2; exit 1; }
    grep -Fx 'CROP_FILE_WEATHER_PRODUCTION=PASS' output.txt
  )
done
cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
cat "$BUILD/o0/output.txt"
echo 'CROP_FILE_WEATHER_PRODUCTION_O0_O2=PASS'

#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
build="$(mktemp -d)"
trap 'rm -rf "$build"' EXIT
python3 - "$build" <<'PY'
import base64,hashlib,io,pathlib,sys,tarfile
out=pathlib.Path(sys.argv[1])
raw=base64.b64decode(pathlib.Path('integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64').read_bytes())
with tarfile.open(fileobj=io.BytesIO(raw),mode='r:gz') as t:
    original=t.extractfile('SWAP/wofost_soil_watern.f90').read()
assert hashlib.sha256(original).hexdigest()=='b343fa9e485e60d76e2bd49067a20cd5ec328264af5d99d7cf1e4ddf07278722'
(out/'original.f90').write_bytes(original)
(out/'fixture.f90').write_text('''module MOD_texture_orgmat
use iso_fortran_env, only: real64
real(real64)::bdens(1)
end module
subroutine swap_error(a,b)
character(*),intent(in)::a,b
print *,a,b
error stop 1
end subroutine
''')
PY
for opt in 0 2; do
 mkdir -p "$build/o$opt"
 gfortran -std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all \
   -ffpe-trap=invalid,zero,overflow -O"$opt" -J "$build/o$opt" -I "$build/o$opt" \
   "$build/fixture.f90" "$build/original.f90" \
   src/process/mod_soil_n_pool_state.f90 \
   src/process/mod_b111_soil_n_storage_conversion.f90 \
   src/process/mod_b111_soil_n_transport.f90 \
   src/process/mod_b111_soil_n_mineral_owner.f90 \
   tests/nut-crop/test_mineral_gross_carrier.f90 -o "$build/o$opt/test"
 "$build/o$opt/test" > "$build/o$opt/output"
 grep -Fq 'MC_NUT01_MINERAL_GROSS_SOURCE_O0_O2=PASS' "$build/o$opt/output"
 echo "MC_NUT01_MINERAL_GROSS_CARRIER_ORIGINAL_O$opt=PASS"
done
cmp "$build/o0/output" "$build/o2/output"

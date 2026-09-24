#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/f-pdi-vt03-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"; trap 'rm -rf "$BUILD"' EXIT; cd "$ROOT"
URL="https://raw.githubusercontent.com/SWAP-model/SWAP/c22bd832ddf3e53e330a552f5e31e74f183362d1/src/soil/WC_K_models_04_11.f90"
curl -fsSL "$URL" -o "$BUILD/source.f90"
blob=$(git hash-object "$BUILD/source.f90")
[[ "$blob" == "40c5b57fb6691c1f4b51ddf76675b435ca71b589" ]] || { echo "blob mismatch $blob"; exit 2; }
python3 - "$BUILD/source.f90" "$BUILD/candidate.f90" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text()
old="Kvap = Kvap_func (WC, dabs(h), Temp) * Conv"
assert s.count(old)==4
s=s.replace(old,"Kvap = Kvap_func (WC, h, Temp) * Conv")
old_decl="real(8)                :: fKvap, Da, MgRT, Rho_sv"
assert old_decl in s
s=s.replace(old_decl,"real(8)                :: fKvap, Da, MgRT, Rho_sv, TK",1)
assert "MgRT      = MgR/(Temp+273.15d0)" in s
assert "Da        = 2.14d-5*((Temp+273.15d0)/273.15d0)**2" in s
assert "Rho_sv    = 1.0d-3*dexp(31.3716d0 - 6014.79d0/Temp - 7.92495d-3*Temp)/Temp" in s
s=s.replace("MgRT      = MgR/(Temp+273.15d0)","TK        = Temp + 273.15d0\nMgRT      = MgR/TK",1)
s=s.replace("Da        = 2.14d-5*((Temp+273.15d0)/273.15d0)**2","Da        = 2.14d-5*(TK/273.15d0)**2",1)
s=s.replace("Rho_sv    = 1.0d-3*dexp(31.3716d0 - 6014.79d0/Temp - 7.92495d-3*Temp)/Temp","Rho_sv    = 1.0d-3*dexp(31.3716d0 - 6014.79d0/TK - 7.92495d-3*TK)/TK",1)
Path(sys.argv[2]).write_text(s)
PY
gfortran -std=f2018 -ffree-line-length-none -O0 -fcheck=all -ffpe-trap=invalid,zero,overflow -Wall -Wextra -c research/pdi_vt/f_pdi_vt03_stubs.f90 -J "$BUILD" -o "$BUILD/stubs.o"
gfortran -std=f2018 -ffree-line-length-none -O0 -fcheck=all -ffpe-trap=invalid,zero,overflow -Wall -Wextra -c "$BUILD/candidate.f90" -J "$BUILD" -I "$BUILD" -o "$BUILD/pdi.o"
gfortran -std=f2018 -ffree-line-length-none -O0 -fcheck=all -ffpe-trap=invalid,zero,overflow -Wall -Wextra research/pdi_vt/f_pdi_vt03_harness.f90 "$BUILD/stubs.o" "$BUILD/pdi.o" -J "$BUILD" -I "$BUILD" -o "$BUILD/test"
"$BUILD/test" | tee "${1:-/tmp/f_pdi_vt03.txt}"

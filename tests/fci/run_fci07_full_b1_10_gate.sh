#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
: "${FCI07_B1_10_SOURCE:?Set FCI07_B1_10_SOURCE to exact reconstructed B1.10 source tree}"
: "${FCI07_TTUTIL_ROOT:?Set FCI07_TTUTIL_ROOT to TTUTIL source root}"
: "${FCI07_CASE:?Set FCI07_CASE to the Hupsel qualification case}"
BUILD="${FCI07_BUILD:-$ROOT/.fci07-full-b1-10}"
rm -rf "$BUILD"; mkdir -p "$BUILD"

PORT="$BUILD/port"
python "$ROOT/tools/fci/fci06_apply_controlled_source_port.py" \
  --source "$FCI07_B1_10_SOURCE" --output "$PORT" > "$BUILD/fci06-port.json"

GNU="$BUILD/gnu"
python - "$PORT" "$GNU" "$FCI07_TTUTIL_ROOT/ttutilprefs.f90" <<'PY'
from pathlib import Path
import shutil,sys
src,out,prefs=map(Path,sys.argv[1:])
if out.exists(): shutil.rmtree(out)
shutil.copytree(src,out)
shutil.copy2(prefs,out/'ttutilprefs.f90')
def cond_value(text):
    t=text.strip().lower().replace(' ','')
    if 'defined(multiswap)' in t or 'defined(with_sss)' in t or 'defined(with_animo)' in t: return False
    if '(linux==0)' in t or 'linux==0' in t: return False
    raise RuntimeError(f'unknown DEC conditional: {text}')
for p in out.glob('*.f90'):
    lines=p.read_text(encoding='latin1').splitlines(keepends=True); result=[]; stack=[]; active=True
    for line in lines:
        s=line.strip(); u=s.upper()
        if u.startswith('!DEC$ IF'):
            c=cond_value(s); stack.append((active,c)); active=active and c; continue
        if u.startswith('!DEC$ ELSE'):
            parent,c=stack[-1]; active=parent and not c; continue
        if u.startswith('!DEC$ END IF'):
            parent,_=stack.pop(); active=parent; continue
        if active: result.append(line)
    if stack: raise RuntimeError(f'unclosed DEC block in {p.name}')
    p.write_text(''.join(result),encoding='latin1')
PY

TT="$FCI07_TTUTIL_ROOT"; TTB="$BUILD/ttbuild"; mkdir -p "$TTB"
TTFLAGS=(-O2 -std=legacy -fallow-argument-mismatch -fno-range-check -ffixed-line-length-none -J "$TTB" -I "$TTB" -I "$TT")
gfortran "${TTFLAGS[@]}" -c "$TT/ttutilprefs.f90" -o "$TTB/ttutilprefs.o"
gfortran "${TTFLAGS[@]}" -c "$TT/rdmodulettutil.f90" -o "$TTB/rdmodulettutil.o"
gfortran "${TTFLAGS[@]}" -c "$TT/outdat.f90" -o "$TTB/outdat.o"
gfortran "${TTFLAGS[@]}" -c "$TT/ttutil.f90" -o "$TTB/ttutil.o"
for f in "$TT"/*.for "$TT"/*.f90; do
  case "$(basename "$f")" in ttutilprefs.f90|rdmodulettutil.f90|outdat.f90|ttutil.f90) continue;; esac
  gfortran "${TTFLAGS[@]}" -c "$f" -o "$TTB/$(basename "${f%.*}").o"
done
TTLIB="$BUILD/libttutil.a"; ar rcs "$TTLIB" "$TTB"/*.o

FILES=(ttutilprefs.f90 params.f90 description.f90 wofost_soil_interface.f90 interface_atmosphere.f90 arrays.f90 wofost_soil_declarations.f90 sptabulated.f90 variables.f90 WC_K_models_04_11.f90 interface_plant.f90 swap_base.f90 fixed.f90 snow.f90 wofostnut.f90 MOD_drainage.f90 temperature.f90 MOD_RIA.f90 MOD_MvG_functions.f90 irrigation.f90 MOD_meteo.f90 MOD_runon.f90 MOD_Kavg_Szym.f90 surfacewater.f90 divdra.f90 calcgwl.f90 macropore.f90 integral.f90 RWU_micro.f90 drainage.f90 timecontrol.f90 frozencond.f90 solute.f90 wofost.f90 boundtop.f90 soilwater.f90 MOD_cropdevelopment.f90 oxygenstress.f90 rootextraction.f90 swap_csv_output.f90 tillage.f90 swap.f90 MOD_out_PEARL_ANIMO.f90 tridag.f90 initialize.f90 readswap.f90 wofost_soil_watern.f90 hysteresis.f90 functions.f90 watstor.f90 macroporeoutput.f90 swapoutput.f90 wofost_soil_balancecheck.f90 wofost_soil_parameters.f90 wofost_soil_orgmatn.f90 fluxes.f90 wofost_soil_rateconstants.f90 wofost_soil_cropresidues.f90 wofost_soil_amendments.f90 macrorate.f90 headcalc.f90 management_soil.f90 boundbottom.f90)

for opt in 0 2; do
  O="$BUILD/o$opt"; mkdir -p "$O"
  gfortran -O$opt -std=f2008 -ffree-line-length-none -J "$O" -I "$O" \
    -c "$ROOT/src/runtime/mod_a23bu_worker_execution_context.f90" -o "$O/worker.o"
  BFLAGS=(-O$opt -cpp -Dlinux -std=legacy -fallow-argument-mismatch -fno-range-check -ffree-line-length-none -finit-local-zero -J "$O" -I "$O")
  for f in "${FILES[@]}"; do gfortran "${BFLAGS[@]}" -c "$GNU/$f" -o "$O/${f%.f90}.o"; done
  gfortran -O$opt -std=f2008 -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffree-line-length-none \
    -J "$O" -I "$O" -c "$ROOT/src/adapter/mod_b1_10_legacy_trial_capsule.f90" -o "$O/capsule.o"
  gfortran -O$opt -std=f2008 -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffree-line-length-none \
    -J "$O" -I "$O" -c "$ROOT/tests/fci/test_fci07_b1_10_physical_rerun.f90" -o "$O/test.o"
  objs=$(find "$O" -maxdepth 1 -name '*.o' ! -name 'test.o' -printf '%p ')
  gfortran -O$opt -o "$O/test" "$O/test.o" $objs "$TTLIB"
  for offset in 4 499; do
    C="$O/case-$offset"; rm -rf "$C"; cp -a "$FCI07_CASE" "$C"
    python - "$C/swap.swp" <<'PY'
from pathlib import Path
import re,sys
p=Path(sys.argv[1]); s=p.read_text(encoding='latin1')
s,n=re.subn(r'(?m)^\s*SWCSV\s*=\s*1\b.*$', '  SWCSV = 0                  ! F-CI07 rollback qualification', s)
if n!=1: raise SystemExit(f'SWCSV anchor changed: {n}')
p.write_text(s,encoding='latin1')
PY
    (cd "$C" && ../test "$offset" > probe.log 2>&1)
    echo "FCI07 physical rerun offset=$offset O$opt PASS"
  done
done

echo FCI07_FULL_B1_10_GATE_PASS

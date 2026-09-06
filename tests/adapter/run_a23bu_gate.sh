#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
: "${A23BU_CASE:?Set A23BU_CASE to Hupsel qualification case}"
: "${A23BU_B16_CANONICAL:?Set A23BU_B16_CANONICAL to exact B1.6 source tree}"
: "${A23BU_TTUTIL_ROOT:?Set A23BU_TTUTIL_ROOT to TTUTIL source root}"
BUILD="${A23BU_BUILD:-$ROOT/.a23bu-build}"
rm -rf "$BUILD"; mkdir -p "$BUILD"

B16_WORKER="$BUILD/B1.6-worker"
python "$ROOT/tools/a23bu_prepare_process_state_source.py" \
  --source "$A23BU_B16_CANONICAL" --output "$B16_WORKER" \
  --ttutil-prefs "$A23BU_TTUTIL_ROOT/ttutilprefs.f90" | tee "$BUILD/postimage.json"
python - "$B16_WORKER" <<'PY_AUDIT'
from pathlib import Path
import re,sys
root=Path(sys.argv[1])
for path in root.glob('*.f90'):
    text=path.read_text(encoding='latin1')
    code='\n'.join(line.split('!')[0] for line in text.splitlines())
    if re.search(r'\bfldecdt\b|\bnumbit\b|\bfldtmin\b|\bfldtreduce\b|\bfldaystart\b|\bfldayend\b',code,re.I):
        raise SystemExit(f'legacy singleton control remains active in {path.name}')
print('A23BU_SOURCE_CONTROL_AUDIT PASS')
PY_AUDIT
python - "$ROOT/src/adapter/mod_a23bu_hupsel_worker_component.f90" <<'PY_PROCESS_AUDIT'
from pathlib import Path
import re,sys
s=Path(sys.argv[1]).read_text()
# Persistent process cursor must contain only the irrigation continuation cursors.
m=re.search(r'type, public :: hupsel_irrigation_continuation_t(.*?)end type hupsel_irrigation_continuation_t',s,re.S|re.I)
if not m: raise SystemExit('irrigation continuation type missing')
frag=m.group(1)
for sym in ['irrigevent','gird','dt_irr_event','flirrigate','fl_cropcalendar','isua','cirr','nird','qssdi','qssdisum']:
    if re.search(rf'\b{sym}\b',frag,re.I): raise SystemExit(f'transient/config symbol persisted: {sym}')
for sym in ['dayfix','nirri']:
    if not re.search(rf'\b{sym}\b',frag,re.I): raise SystemExit(f'continuation cursor missing: {sym}')
if 'reset_legacy_irrigation_event_workspace' not in s:
    raise SystemExit('irrigation event workspace reset missing')
print('A23BU_PROCESS_STATE_AUDIT PASS')
PY_PROCESS_AUDIT

python - "$B16_WORKER" <<'PY_REPORT_AUDIT'
from pathlib import Path
import re,sys
root=Path(sys.argv[1])
tc=(root/'timecontrol.f90').read_text(encoding='latin1')
sw=(root/'swap.f90').read_text(encoding='latin1')
integ=(root/'integral.f90').read_text(encoding='latin1')
sol=(root/'solute.f90').read_text(encoding='latin1')
# Worker route must not use global reporting reset controls in physics/accounting routines.
for name,text in [('integral',integ),('solute',sol)]:
    code='\n'.join(line.split('!')[0] for line in text.splitlines())
    if re.search(r'\bflzerointr\b|\bflzerocumu\b',code,re.I):
        raise SystemExit(f'{name} still reads legacy reporting reset globals')
# Trial output emission is source-suppressed when worker is present.
if 'transaction trials have no legacy output emission' not in sw:
    raise SystemExit('trial output suppression marker missing')
# Qualified reference route only.
print('A23BU_REPORTING_SOURCE_AUDIT PASS')
PY_REPORT_AUDIT

TT="$A23BU_TTUTIL_ROOT"; TTB="$BUILD/ttbuild"; mkdir -p "$TTB"
TTFLAGS=(-O2 -std=legacy -fallow-argument-mismatch -fno-range-check -ffixed-line-length-none -J "$TTB" -I "$TTB" -I "$TT")
gfortran "${TTFLAGS[@]}" -c "$TT/ttutilprefs.f90" -o "$TTB/ttutilprefs.o"
gfortran "${TTFLAGS[@]}" -c "$TT/rdmodulettutil.f90" -o "$TTB/rdmodulettutil.o"
gfortran "${TTFLAGS[@]}" -c "$TT/outdat.f90" -o "$TTB/outdat.o"
gfortran "${TTFLAGS[@]}" -c "$TT/ttutil.f90" -o "$TTB/ttutil.o"
for f in "$TT"/*.for "$TT"/*.f90; do
  case "$(basename "$f")" in ttutilprefs.f90|rdmodulettutil.f90|outdat.f90|ttutil.f90) continue;; esac
  gfortran "${TTFLAGS[@]}" -c "$f" -o "$TTB/$(basename "${f%.*}").o"
done
TTLIB="$BUILD/libttutil427_gfortran.a"; ar rcs "$TTLIB" "$TTB"/*.o

FILES=(ttutilprefs.f90 params.f90 description.f90 wofost_soil_interface.f90 interface_atmosphere.f90 arrays.f90 wofost_soil_declarations.f90 sptabulated.f90 variables.f90 WC_K_models_04_11.f90 interface_plant.f90 swap_base.f90 fixed.f90 snow.f90 wofostnut.f90 MOD_drainage.f90 temperature.f90 MOD_RIA.f90 MOD_MvG_functions.f90 irrigation.f90 MOD_meteo.f90 MOD_runon.f90 MOD_Kavg_Szym.f90 surfacewater.f90 divdra.f90 calcgwl.f90 macropore.f90 integral.f90 RWU_micro.f90 drainage.f90 timecontrol.f90 frozencond.f90 solute.f90 wofost.f90 boundtop.f90 soilwater.f90 MOD_cropdevelopment.f90 oxygenstress.f90 rootextraction.f90 swap_csv_output.f90 tillage.f90 swap.f90 MOD_out_PEARL_ANIMO.f90 tridag.f90 initialize.f90 readswap.f90 wofost_soil_watern.f90 hysteresis.f90 functions.f90 watstor.f90 macroporeoutput.f90 swapoutput.f90 wofost_soil_balancecheck.f90 wofost_soil_parameters.f90 wofost_soil_orgmatn.f90 fluxes.f90 wofost_soil_rateconstants.f90 wofost_soil_cropresidues.f90 wofost_soil_amendments.f90 macrorate.f90 headcalc.f90 management_soil.f90 boundbottom.f90)

for opt in 0 2; do
  O="$BUILD/o$opt"; mkdir -p "$O"
  COMMON=(-O$opt -std=f2008 -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffree-line-length-none -J "$O" -I "$O")
  gfortran "${COMMON[@]}" -c "$ROOT/src/runtime/mod_a23bu_worker_execution_context.f90" -o "$O/mod_a23bu_worker_execution_context.o"
  BFLAGS=(-O$opt -cpp -Dlinux -std=legacy -fallow-argument-mismatch -fno-range-check -ffree-line-length-none -finit-local-zero -J "$O" -I "$O")
  for f in "${FILES[@]}"; do gfortran "${BFLAGS[@]}" -c "$B16_WORKER/$f" -o "$O/${f%.f90}.o"; done
  gfortran "${COMMON[@]}" -c "$ROOT/src/transaction/mod_transaction_reference.f90" -o "$O/mod_transaction_reference.o"
  gfortran "${COMMON[@]}" -c "$ROOT/src/adapter/mod_a23bu_hupsel_worker_component.f90" -o "$O/mod_a23bu_hupsel_worker_component.o"
  gfortran "${COMMON[@]}" -c "$ROOT/tests/adapter/test_a23bu_hupsel_worker_component.f90" -o "$O/test_a23bu.o"
  objs=$(find "$O" -maxdepth 1 -name '*.o' ! -name 'test_a23bu.o' ! -name 'mod_transaction_reference.o' ! -name 'mod_a23bu_hupsel_worker_component.o' ! -name 'mod_a23bu_worker_execution_context.o' -printf '%p ')
  gfortran -O$opt -o "$O/test_a23bu" "$O/mod_a23bu_worker_execution_context.o" "$O/mod_transaction_reference.o" "$O/mod_a23bu_hupsel_worker_component.o" "$O/test_a23bu.o" $objs "$TTLIB"
  cp -a "$A23BU_CASE" "$O/case"
  python - "$O/case/swap.swp" <<'PY'
from pathlib import Path
import sys,re
p=Path(sys.argv[1]); s=p.read_text(encoding='latin1')
s,n1=re.subn(r'(?m)^\s*SWEND\s*=\s*0\b.*$', '  SWEND = 1                  ! A23BU VQ: binary endpoint at closure', s)
s,n2=re.subn(r'(?m)^\s*SWENDTYPE\s*=\s*1\b.*$', '  SWENDTYPE = 2              ! A23BU VQ: unformatted continuation state', s)
s,n3=re.subn(r'(?m)^\s*SWCSV\s*=\s*1\b.*$', '  SWCSV = 0                  ! A23BU VQ: CSV observer disabled', s)
if n1!=1 or n2!=1 or n3!=1: raise SystemExit(f'swap.swp VQ anchors changed: {n1},{n2},{n3}')
p.write_text(s,encoding='latin1')
PY
  (cd "$O/case" && ../test_a23bu) | tee "$O/gate.log"
  sha256sum "$O/case/a23bu_worker.end" > "$O/end.sha256"
  grep -q 'A23BU_WORKER_COMPONENT_GATE PASS' "$O/gate.log"
  grep -q '4b77a52ca7c48a59a057dec036f596a8da4ebc9ede9296f7d3b36dcff528bfb9' "$O/end.sha256"
done
cmp "$BUILD/o0/gate.log" "$BUILD/o2/gate.log"

# Generic transaction regression under both optimization levels.
for opt in 0 2; do
  O="$BUILD/tx_o$opt"; mkdir -p "$O"
  gfortran -O$opt -std=f2008 -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffree-line-length-none \
    -J "$O" -I "$O" "$ROOT/src/transaction/mod_transaction_reference.f90" \
    "$ROOT/tests/transaction/test_transaction_reference.f90" -o "$O/test_tx"
  "$O/test_tx" > "$O/gate.log"
done
cmp "$BUILD/tx_o0/gate.log" "$BUILD/tx_o2/gate.log"

# Worker-context isolation: parallel context mutation without touching the serialized B1.6 backend.
for opt in 0 2; do
  O="$BUILD/worker_o$opt"; mkdir -p "$O"
  gfortran -O$opt -std=f2008 -Wall -Wextra -Werror -fcheck=all -fbacktrace -fopenmp -ffree-line-length-none \
    -J "$O" -I "$O" "$ROOT/src/runtime/mod_a23bu_worker_execution_context.f90" \
    "$ROOT/tests/runtime/test_a23bu_worker_context.f90" -o "$O/test_worker"
  OMP_NUM_THREADS=8 "$O/test_worker" > "$O/gate.log"
done
cmp "$BUILD/worker_o0/gate.log" "$BUILD/worker_o2/gate.log"

echo A23BU_GATE_PASS

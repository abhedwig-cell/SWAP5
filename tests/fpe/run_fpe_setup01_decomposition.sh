#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-setup01-${GITHUB_RUN_ID:-local}-$$"
N="${SETUP01_N:-10000}"
NREP="${SETUP01_REPS:-3}"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "FPE_SETUP01_FAIL $*" >&2; exit 1; }

python3 - "$BUILD/fixture.f90" "$N" <<'PY'
from pathlib import Path
import sys

out=Path(sys.argv[1]); n=int(sys.argv[2]); workers=4
s=Path("tests/fpe/mod_fpe_temporal08_production_live_fixture.f90").read_text()

old="""  integer, parameter :: NPART=3
  integer(int64), parameter :: TILE_ID(NPART)=[880201_int64,880202_int64,880203_int64]
  integer(int64), parameter :: LEDGER_ID(NPART)=[980201_int64,980202_int64,980203_int64]
  integer(int64), parameter :: CELL_ID(NPART)=[7001_int64,7001_int64,7002_int64]
  integer(int64), parameter :: COUPLING_ID(2)=[880301_int64,880302_int64]
  integer(int64), parameter :: GW_LINEAGE_ID(2)=[880401_int64,880402_int64]
  integer(int64), parameter :: GW_SERVICE_ID=880501_int64
  real(real64), parameter :: FRACTION(NPART)=[0.35_real64,0.65_real64,1.0_real64]
"""
new=f"""  integer, parameter :: NPART={n}
  integer, parameter :: SETUP01_WORKERS={workers}
  integer(int64), parameter :: GW_SERVICE_ID=880501_int64
"""
if old not in s: raise SystemExit("constant seam missing")
s=s.replace(old,new,1)
s=s.replace("    type(groundwater_topology_cell_t) :: cells(2)\n",
            "    type(groundwater_topology_cell_t) :: cells(NPART)\n",1)
s=s.replace("    type(groundwater_cell_area_input_t) :: areas(2)\n",
            "    type(groundwater_cell_area_input_t) :: areas(NPART)\n",1)

old="""    do i=1,NPART
      call set_tile(tiles(i),TILE_ID(i),LEDGER_ID(i),CELL_ID(i),FRACTION(i))
    end do
    call set_cell(cells(1),7001_int64,COUPLING_ID(1),GW_LINEAGE_ID(1),1,2)
    call set_cell(cells(2),7002_int64,COUPLING_ID(2),GW_LINEAGE_ID(2),2,3)
    call materialize_groundwater_topology(tiles,cells,topology,status)
    if(status/=GW_TOPOLOGY_OK .or. .not.topology%ready())return

    call make_predictor(predictors(1),tiles(1),cells(1),reference_head,1)
    call make_predictor(predictors(2),tiles(2),cells(1),reference_head,2)
    call make_predictor(predictors(3),tiles(3),cells(2),reference_head,3)
    areas(1)%groundwater_cell_id=7001_int64; areas(1)%cell_area_m2=1.0_real64
    areas(2)%groundwater_cell_id=7002_int64; areas(2)%cell_area_m2=1.0_real64
"""
new="""    do i=1,NPART
      call set_tile(tiles(i),880200_int64+int(i,int64),980200_int64+int(i,int64), &
           700000_int64+int(i,int64),1.0_real64)
      call set_cell(cells(i),700000_int64+int(i,int64),880300_int64+int(i,int64), &
           880400_int64+int(i,int64),i,i)
    end do
    call materialize_groundwater_topology(tiles,cells,topology,status)
    if(status/=GW_TOPOLOGY_OK .or. .not.topology%ready())return

    do i=1,NPART
      call make_predictor(predictors(i),tiles(i),cells(i),reference_head,1)
      areas(i)%groundwater_cell_id=cells(i)%groundwater_cell_id
      areas(i)%cell_area_m2=1.0_real64
    end do
"""
if old not in s: raise SystemExit("topology seam missing")
s=s.replace(old,new,1)
s=s.replace(
"    value%initial_time=0.0_real64\n",
"    value%initial_time=0.0_real64\n    value%groundwater_parallel_workers=SETUP01_WORKERS\n",1)
s=s.replace(
"      value%tiles(i)%tile_id=TILE_ID(i); value%tiles(i)%ledger_id=LEDGER_ID(i)\n",
"      value%tiles(i)%tile_id=880200_int64+int(i,int64); value%tiles(i)%ledger_id=980200_int64+int(i,int64)\n",1)

old_decl="    integer :: i,status\n"
new_decl="""    integer :: i,status
    integer(int64) :: tick0,tick1,tick2,tick3,tick4,tick_rate
"""
if old_decl not in s: raise SystemExit("timing declaration seam missing")
s=s.replace(old_decl,new_decl,1)

old="""    call initialize_config(config)
    call app%initialize(config,status)
    if(status/=FMR_APP_BOOT_OK .or. .not.app%ready())return

    call compute_reference_head(config%tiles(1)%parameters,config%tiles(1)%groundwater_datum,reference_head,status)
"""
new="""    call system_clock(tick0,tick_rate)
    call initialize_config(config)
    call system_clock(tick1)
    call app%initialize(config,status)
    if(status/=FMR_APP_BOOT_OK .or. .not.app%ready())return
    call system_clock(tick2)

    call compute_reference_head(config%tiles(1)%parameters,config%tiles(1)%groundwater_datum,reference_head,status)
"""
if old not in s: raise SystemExit("initialize timing seam missing")
s=s.replace(old,new,1)

old="""    call app%materialize_groundwater_context(topology,predictors,areas,handle,status)
    if(status/=FMR_APP_BOOT_OK .or. handle<=0_int64)return

    context_handle=int(handle,c_int64_t)
"""
new="""    call system_clock(tick3)
    call app%materialize_groundwater_context(topology,predictors,areas,handle,status)
    if(status/=FMR_APP_BOOT_OK .or. handle<=0_int64)return
    call system_clock(tick4)
    write(*,'(*(g0))') 'SETUP01_PHASE|N=',NPART, &
         '|CONFIG_S=',real(tick1-tick0,real64)/real(tick_rate,real64), &
         '|APP_INIT_S=',real(tick2-tick1,real64)/real(tick_rate,real64), &
         '|PRE_CONTEXT_S=',real(tick3-tick2,real64)/real(tick_rate,real64), &
         '|CONTEXT_S=',real(tick4-tick3,real64)/real(tick_rate,real64), &
         '|TOTAL_TO_CONTEXT_S=',real(tick4-tick0,real64)/real(tick_rate,real64)

    context_handle=int(handle,c_int64_t)
"""
if old not in s: raise SystemExit("context timing seam missing")
s=s.replace(old,new,1)

out.write_text(s)
PY

OUT="$BUILD/o"
mkdir -p "$OUT"
mapfile -t MODULE_SRC < <(python3 - "$BUILD/fixture.f90" <<'PY'
from pathlib import Path
import sys,re
fixture=Path(sys.argv[1]).resolve()
s=Path("tests/fpe/run_fpe_temporal08_p3_live_production.sh").read_text()
m=re.search(r'MODULE_SRC=\(\n(.*?)\n\)',s,re.S)
if not m: raise SystemExit("TEMPORAL08 module list missing")
for raw in m.group(1).splitlines():
    p=raw.strip()
    if not p: continue
    if p=="tests/fpe/mod_fpe_temporal08_production_live_fixture.f90":
        print(fixture)
    else:
        print(p)
PY
)
COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fPIC -fopenmp)
objects=()
for source in "${MODULE_SRC[@]}"; do
  obj="$OUT/$(basename "${source%.*}").o"
  gfortran "${COMMON[@]}" -O2 -J "$OUT" -I "$OUT" -c "$source" -o "$obj" || fail "compile $source"
  objects+=("$obj")
done
gfortran -shared -fopenmp -O2 "${objects[@]}" -o "$OUT/libsetup01.so" || fail "link"

cat > "$BUILD/probe.py" <<'PY'
import ctypes, os, time
from pathlib import Path

lib=ctypes.CDLL(str(Path(os.environ["SETUP01_LIB"]).resolve()))
init=lib.fpe_temporal08_fixture_initialize_c
init.restype=ctypes.c_int
init.argtypes=[ctypes.POINTER(ctypes.c_int64),ctypes.POINTER(ctypes.c_double),ctypes.POINTER(ctypes.c_double)]
close=lib.fpe_temporal08_fixture_close_c
close.restype=ctypes.c_int
close.argtypes=[]
counts=lib.fgc49d_context_counts_c
counts.restype=ctypes.c_int
counts.argtypes=[ctypes.c_int64,ctypes.POINTER(ctypes.c_int),ctypes.POINTER(ctypes.c_int)]
capture=lib.fgc49d_capture_origins_c
capture.restype=ctypes.c_int
capture.argtypes=[ctypes.c_int64]
trial=lib.fgc49d_trial_cell_heads_c
trial.restype=ctypes.c_int
trial.argtypes=[ctypes.c_int64,ctypes.c_int,ctypes.POINTER(ctypes.c_double),ctypes.POINTER(ctypes.c_double)]
tangent=lib.fgc49d_trial_response_tangents_c
tangent.restype=ctypes.c_int
tangent.argtypes=[ctypes.c_int64,ctypes.c_int,ctypes.POINTER(ctypes.c_double)]
discard=lib.fgc49d_discard_candidates_c
discard.restype=ctypes.c_int
discard.argtypes=[ctypes.c_int64]
abort=lib.fgc49d_abort_prepublication_c
abort.restype=ctypes.c_int
abort.argtypes=[ctypes.c_int64]

h=ctypes.c_int64(); a=ctypes.c_double(); b=ctypes.c_double()
t0=time.perf_counter()
if init(ctypes.byref(h),ctypes.byref(a),ctypes.byref(b))!=0: raise SystemExit("init")
t1=time.perf_counter()
nc=ctypes.c_int(); nt=ctypes.c_int()
if counts(h.value,ctypes.byref(nc),ctypes.byref(nt))!=0: raise SystemExit("counts")
n=nc.value
heads=(ctypes.c_double*n)(*([a.value]*n))
flux=(ctypes.c_double*n)()
tan=(ctypes.c_double*n)()

c0=time.perf_counter()
if capture(h.value)!=0: raise SystemExit("capture")
c1=time.perf_counter()
if trial(h.value,n,heads,flux)!=0: raise SystemExit("warm trial")
if tangent(h.value,n,tan)!=0: raise SystemExit("warm tangent")
if discard(h.value)!=0: raise SystemExit("warm discard")
c2=time.perf_counter()
print(f"SETUP01_OUTER|N={n}|INIT_CALL_S={t1-t0:.12f}|CAPTURE_S={c1-c0:.12f}|WARM_S={c2-c1:.12f}")
if abort(h.value)!=0: raise SystemExit("abort")
if close()!=0: raise SystemExit("close")
PY

: > "$BUILD/all.txt"
for rep in $(seq 1 "$NREP"); do
  OMP_DYNAMIC=FALSE OMP_NUM_THREADS=4 SETUP01_LIB="$OUT/libsetup01.so" python3 "$BUILD/probe.py" | tee -a "$BUILD/all.txt"
done

python3 - "$BUILD/all.txt" <<'PY'
import re,statistics,sys
phase=[]; outer=[]
for line in open(sys.argv[1]):
    m=re.search(r'SETUP01_PHASE\|N=(\d+)\|CONFIG_S=([^|]+)\|APP_INIT_S=([^|]+)\|PRE_CONTEXT_S=([^|]+)\|CONTEXT_S=([^|]+)\|TOTAL_TO_CONTEXT_S=(.+)',line)
    if m:
        phase.append(tuple([int(m.group(1))]+[float(m.group(i)) for i in range(2,7)]))
    m=re.search(r'SETUP01_OUTER\|N=(\d+)\|INIT_CALL_S=([^|]+)\|CAPTURE_S=([^|]+)\|WARM_S=(.+)',line)
    if m:
        outer.append(tuple([int(m.group(1))]+[float(m.group(i)) for i in range(2,5)]))
if not phase or len(phase)!=len(outer):
    raise SystemExit(f"missing setup rows phase={len(phase)} outer={len(outer)}")
n=phase[0][0]
med=lambda rows,k: statistics.median(r[k] for r in rows)
config=med(phase,1); app=med(phase,2); pre=med(phase,3); ctx=med(phase,4); total=med(phase,5)
initcall=med(outer,1); capture=med(outer,2); warm=med(outer,3)
den=max(total,1e-30)
print(f"SETUP01_SUMMARY|N={n}|CONFIG_S={config:.12f}|APP_INIT_S={app:.12f}|PRE_CONTEXT_S={pre:.12f}|CONTEXT_S={ctx:.12f}|TOTAL_TO_CONTEXT_S={total:.12f}|APP_INIT_SHARE={app/den:.6f}|CONTEXT_SHARE={ctx/den:.6f}|INIT_CALL_S={initcall:.12f}|CAPTURE_S={capture:.12f}|WARM_S={warm:.12f}")
print("FPE_SETUP01=PASS")
PY

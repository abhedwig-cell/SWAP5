#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-setup05-${GITHUB_RUN_ID:-local}-$$"
N="${SETUP05_N:-10000}"
REPS="${SETUP05_REPS:-5}"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "FPE_SETUP05_FAIL $*" >&2; exit 1; }

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
  integer, parameter :: SETUP05_WORKERS={workers}
  integer(int64), parameter :: GW_SERVICE_ID=880501_int64
"""
if old not in s: raise SystemExit("constant seam missing")
s=s.replace(old,new,1)
s=s.replace("    type(groundwater_topology_cell_t) :: cells(2)\n",
            "    type(groundwater_topology_cell_t) :: cells(NPART)\n",1)
s=s.replace("    type(groundwater_cell_area_input_t) :: areas(2)\n",
            "    type(groundwater_cell_area_input_t) :: areas(NPART)\n",1)

old_saved="""  type(fmr_production_application_bootstrap_t), save :: app, missing_seed_app
  logical, save :: initialized=.false.
"""
new_saved="""  type(fmr_production_application_bootstrap_t), save :: app, missing_seed_app
  logical, save :: initialized=.false.
  real(real64), save :: setup_config_s=0.0_real64
  real(real64), save :: setup_app_initialize_s=0.0_real64
  real(real64), save :: setup_topology_s=0.0_real64
  real(real64), save :: setup_context_materialize_s=0.0_real64
"""
if old_saved not in s: raise SystemExit("saved seam missing")
s=s.replace(old_saved,new_saved,1)

old_public="""  public :: fpe_temporal08_fixture_close_c
  public :: fpe_temporal08_missing_seed_rejected_c
"""
new_public="""  public :: fpe_temporal08_fixture_close_c
  public :: fpe_temporal08_missing_seed_rejected_c
  public :: fpe_setup05_fixture_timings_c
"""
if old_public not in s: raise SystemExit("public seam missing")
s=s.replace(old_public,new_public,1)

old_locals="""    real(real64) :: reference_head
    integer(int64) :: handle
    integer :: i,status
"""
new_locals="""    real(real64) :: reference_head
    real(real64) :: t0,t1
    integer(int64) :: handle
    integer :: i,status
"""
if old_locals not in s: raise SystemExit("locals seam missing")
s=s.replace(old_locals,new_locals,1)

old_init="""    call initialize_config(config)
    call app%initialize(config,status)
    if(status/=FMR_APP_BOOT_OK .or. .not.app%ready())return

    call compute_reference_head(config%tiles(1)%parameters,config%tiles(1)%groundwater_datum,reference_head,status)
    if(status/=MODFLOW6_BOTTOM_FACE_OK)return

    do i=1,NPART
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

    call app%materialize_groundwater_context(topology,predictors,areas,handle,status)
    if(status/=FMR_APP_BOOT_OK .or. handle<=0_int64)return
"""
new_init="""    call cpu_time(t0)
    call initialize_config(config)
    call cpu_time(t1)
    setup_config_s=t1-t0

    call cpu_time(t0)
    call app%initialize(config,status)
    call cpu_time(t1)
    setup_app_initialize_s=t1-t0
    if(status/=FMR_APP_BOOT_OK .or. .not.app%ready())return

    call cpu_time(t0)
    call compute_reference_head(config%tiles(1)%parameters,config%tiles(1)%groundwater_datum,reference_head,status)
    if(status/=MODFLOW6_BOTTOM_FACE_OK)return

    do i=1,NPART
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
    call cpu_time(t1)
    setup_topology_s=t1-t0

    call cpu_time(t0)
    call app%materialize_groundwater_context(topology,predictors,areas,handle,status)
    call cpu_time(t1)
    setup_context_materialize_s=t1-t0
    if(status/=FMR_APP_BOOT_OK .or. handle<=0_int64)return
"""
if old_init not in s: raise SystemExit("initialize seam missing")
s=s.replace(old_init,new_init,1)

s=s.replace("    value%initial_time=0.0_real64\n",
            "    value%initial_time=0.0_real64\n    value%groundwater_parallel_workers=SETUP05_WORKERS\n",1)
s=s.replace("      value%tiles(i)%tile_id=TILE_ID(i); value%tiles(i)%ledger_id=LEDGER_ID(i)\n",
            "      value%tiles(i)%tile_id=880200_int64+int(i,int64); value%tiles(i)%ledger_id=980200_int64+int(i,int64)\n",1)

insert = """
  integer(c_int) function fpe_setup05_fixture_timings_c(config_s,app_s,topology_s,context_s) &
       bind(C,name="fpe_setup05_fixture_timings_c") result(c_status)
    real(c_double), intent(out) :: config_s,app_s,topology_s,context_s
    c_status=1_c_int
    config_s=0.0_c_double; app_s=0.0_c_double; topology_s=0.0_c_double; context_s=0.0_c_double
    if(.not.initialized)return
    config_s=real(setup_config_s,c_double)
    app_s=real(setup_app_initialize_s,c_double)
    topology_s=real(setup_topology_s,c_double)
    context_s=real(setup_context_materialize_s,c_double)
    c_status=0_c_int
  end function fpe_setup05_fixture_timings_c

"""
marker="  integer(c_int) function fpe_temporal08_fixture_state_c(r1,r2,r3) &"
if marker not in s: raise SystemExit("getter insertion seam missing")
s=s.replace(marker,insert+marker,1)

out.write_text(s)
PY

cat > "$BUILD/probe.py" <<'PY'
import ctypes, os, time
from pathlib import Path

t_process=time.perf_counter()
t0=time.perf_counter()
lib=ctypes.CDLL(str(Path(os.environ["SETUP05_LIB"]).resolve()))
t1=time.perf_counter()
lib_load=t1-t0

init=lib.fpe_temporal08_fixture_initialize_c
init.restype=ctypes.c_int
init.argtypes=[ctypes.POINTER(ctypes.c_int64),ctypes.POINTER(ctypes.c_double),ctypes.POINTER(ctypes.c_double)]
timings=lib.fpe_setup05_fixture_timings_c
timings.restype=ctypes.c_int
timings.argtypes=[ctypes.POINTER(ctypes.c_double),ctypes.POINTER(ctypes.c_double),ctypes.POINTER(ctypes.c_double),ctypes.POINTER(ctypes.c_double)]
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
close=lib.fpe_temporal08_fixture_close_c
close.restype=ctypes.c_int
close.argtypes=[]

handle=ctypes.c_int64(); href1=ctypes.c_double(); href2=ctypes.c_double()
t0=time.perf_counter()
if init(ctypes.byref(handle),ctypes.byref(href1),ctypes.byref(href2)) != 0:
    raise SystemExit("fixture initialize")
t1=time.perf_counter()
init_outer=t1-t0

cfg=ctypes.c_double(); app=ctypes.c_double(); topo=ctypes.c_double(); ctx=ctypes.c_double()
if timings(ctypes.byref(cfg),ctypes.byref(app),ctypes.byref(topo),ctypes.byref(ctx)) != 0:
    raise SystemExit("timings")

nc=ctypes.c_int(); nt=ctypes.c_int()
if counts(handle.value,ctypes.byref(nc),ctypes.byref(nt)) != 0:
    raise SystemExit("counts")
n=nc.value
heads=(ctypes.c_double*n)(*([href1.value]*n))
flux=(ctypes.c_double*n)()
tan=(ctypes.c_double*n)()

t0=time.perf_counter()
if capture(handle.value) != 0: raise SystemExit("capture")
t1=time.perf_counter()
capture_s=t1-t0

t0=time.perf_counter()
if trial(handle.value,n,heads,flux) != 0: raise SystemExit("warm trial")
if tangent(handle.value,n,tan) != 0: raise SystemExit("warm tangent")
if discard(handle.value) != 0: raise SystemExit("warm discard")
t1=time.perf_counter()
warm_s=t1-t0

if abort(handle.value) != 0: raise SystemExit("abort")
if close() != 0: raise SystemExit("close")
outer_total=time.perf_counter()-t_process

print(
    f"SETUP05_ROW|N={n}|LIB_LOAD={lib_load:.12f}|INIT_OUTER={init_outer:.12f}|"
    f"CONFIG={cfg.value:.12f}|APP_INIT={app.value:.12f}|TOPOLOGY={topo.value:.12f}|"
    f"CONTEXT={ctx.value:.12f}|CAPTURE={capture_s:.12f}|WARM={warm_s:.12f}|"
    f"OUTER_TOTAL={outer_total:.12f}"
)
PY

OUT="$BUILD/o"
mkdir -p "$OUT"
mapfile -t MODULE_SRC < <(python3 - "$BUILD/fixture.f90" <<'PY'
from pathlib import Path
import sys,re
fixture=Path(sys.argv[1]).resolve()
s=Path("tests/fpe/run_fpe_temporal08_p3_live_production.sh").read_text()
m=re.search(r'MODULE_SRC=\(\n(.*?)\n\)',s,re.S)
if not m: raise SystemExit("module list missing")
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
gfortran -shared -fopenmp -O2 "${objects[@]}" -o "$OUT/libsetup05.so" || fail "link"

RESULT="$BUILD/results.txt"
: > "$RESULT"
for rep in $(seq 1 "$REPS"); do
  OMP_DYNAMIC=FALSE OMP_NUM_THREADS=4 SETUP05_LIB="$OUT/libsetup05.so" python3 "$BUILD/probe.py" | tee -a "$RESULT"
done

python3 - "$RESULT" <<'PY'
import statistics,sys
rows=[]
for line in open(sys.argv[1]):
    if not line.startswith("SETUP05_ROW|"): continue
    d={}
    for part in line.strip().split("|")[1:]:
        k,v=part.split("=",1)
        d[k]=float(v) if k!="N" else int(v)
    rows.append(d)
if not rows: raise SystemExit("no rows")
keys=["LIB_LOAD","INIT_OUTER","CONFIG","APP_INIT","TOPOLOGY","CONTEXT","CAPTURE","WARM","OUTER_TOTAL"]
med={k:statistics.median(r[k] for r in rows) for k in keys}
n=rows[0]["N"]
setup_total=med["INIT_OUTER"]+med["CAPTURE"]+med["WARM"]
internal=med["CONFIG"]+med["APP_INIT"]+med["TOPOLOGY"]+med["CONTEXT"]
print(
    f"SETUP05_SUMMARY|N={n}|LIB_LOAD={med['LIB_LOAD']:.12f}|INIT_OUTER={med['INIT_OUTER']:.12f}|"
    f"CONFIG={med['CONFIG']:.12f}|APP_INIT={med['APP_INIT']:.12f}|TOPOLOGY={med['TOPOLOGY']:.12f}|"
    f"CONTEXT={med['CONTEXT']:.12f}|CAPTURE={med['CAPTURE']:.12f}|WARM={med['WARM']:.12f}|"
    f"SETUP_TOTAL={setup_total:.12f}|INTERNAL_INIT_SUM={internal:.12f}|OUTER_TOTAL={med['OUTER_TOTAL']:.12f}"
)
families={"CONFIG":med["CONFIG"],"APP_INIT":med["APP_INIT"],"TOPOLOGY":med["TOPOLOGY"],"CONTEXT":med["CONTEXT"],"CAPTURE":med["CAPTURE"],"WARM":med["WARM"]}
winner=max(families.items(),key=lambda kv:kv[1])
share=winner[1]/setup_total if setup_total>0 else 0.0
print(f"SETUP05_DOMINANT|N={n}|FAMILY={winner[0]}|SECONDS={winner[1]:.12f}|SHARE={share:.6f}")
print("FPE_SETUP05=PASS")
PY

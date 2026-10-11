#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-multi04-p2-${GITHUB_RUN_ID:-local}-$$"
N="${MULTI04_P2_N:-1000}"
NREP="${MULTI04_P2_REPS:-5}"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "FPE_MULTI04_P2_FAIL $*" >&2; exit 1; }

# Research-only static control retains the current production context interface
# and disables only the bounded hybrid switch.
STATIC_CONTEXT="$BUILD/mod_fmr_groundwater_application_context_static.f90"
python3 - "$STATIC_CONTEXT" <<'PY'
from pathlib import Path
import sys
s=Path("src/runtime/mod_fmr_groundwater_application_context.f90").read_text()
needle="      if (self%last_static_load_ratio > FMR_GW_PARALLEL_LOAD_RATIO_THRESHOLD) then\n"
if needle not in s: raise SystemExit("hybrid switch seam missing")
s=s.replace(needle,"      if (.false.) then\n",1)
Path(sys.argv[1]).write_text(s)
PY

cat > "$BUILD/probe.py" <<'PY'
import ctypes, os, statistics, time
from pathlib import Path
lib=ctypes.CDLL(str(Path(os.environ["MULTI04_LIB"]).resolve()))
init=lib.fpe_temporal08_fixture_initialize_c
init.restype=ctypes.c_int
init.argtypes=[ctypes.POINTER(ctypes.c_int64),ctypes.POINTER(ctypes.c_double),ctypes.POINTER(ctypes.c_double)]
close=lib.fpe_temporal08_fixture_close_c; close.restype=ctypes.c_int; close.argtypes=[]
counts=lib.fgc49d_context_counts_c; counts.restype=ctypes.c_int
counts.argtypes=[ctypes.c_int64,ctypes.POINTER(ctypes.c_int),ctypes.POINTER(ctypes.c_int)]
capture=lib.fgc49d_capture_origins_c; capture.restype=ctypes.c_int; capture.argtypes=[ctypes.c_int64]
trial=lib.fgc49d_trial_cell_heads_c; trial.restype=ctypes.c_int
trial.argtypes=[ctypes.c_int64,ctypes.c_int,ctypes.POINTER(ctypes.c_double),ctypes.POINTER(ctypes.c_double)]
tangent=lib.fgc49d_trial_response_tangents_c; tangent.restype=ctypes.c_int
tangent.argtypes=[ctypes.c_int64,ctypes.c_int,ctypes.POINTER(ctypes.c_double)]
discard=lib.fgc49d_discard_candidates_c; discard.restype=ctypes.c_int; discard.argtypes=[ctypes.c_int64]
abort=lib.fgc49d_abort_prepublication_c; abort.restype=ctypes.c_int; abort.argtypes=[ctypes.c_int64]
diag=lib.fpe_multi04_schedule_diag_c; diag.restype=ctypes.c_int
diag.argtypes=[ctypes.POINTER(ctypes.c_int),ctypes.POINTER(ctypes.c_double),ctypes.POINTER(ctypes.c_double)]

handle=ctypes.c_int64(); h1=ctypes.c_double(); h2=ctypes.c_double()
if init(ctypes.byref(handle),ctypes.byref(h1),ctypes.byref(h2)) != 0: raise SystemExit("init")
nc=ctypes.c_int(); nt=ctypes.c_int()
if counts(handle.value,ctypes.byref(nc),ctypes.byref(nt)) != 0 or nc.value != nt.value or nc.value <= 0:
    raise SystemExit("counts")
if capture(handle.value) != 0: raise SystemExit("capture")
n=nc.value
heads=(ctypes.c_double*n)(*([h1.value]*n)); flux=(ctypes.c_double*n)(); tan=(ctypes.c_double*n)()
if trial(handle.value,n,heads,flux) != 0 or tangent(handle.value,n,tan) != 0: raise SystemExit("warm")
if discard(handle.value) != 0: raise SystemExit("warm discard")
times=[]; qsum=None; tsum=None
for rep in range(int(os.environ.get("MULTI04_P2_REPS","5"))):
    t0=time.perf_counter(); rc=trial(handle.value,n,heads,flux); t1=time.perf_counter()
    if rc != 0: raise SystemExit(f"trial {rep} status={rc}")
    if tangent(handle.value,n,tan) != 0: raise SystemExit("tangent")
    qs=sum(float(flux[i]) for i in range(n)); ts=sum(float(tan[i]) for i in range(n))
    if qsum is None: qsum,tsum=qs,ts
    elif qs != qsum or ts != tsum: raise SystemExit("repeat semantic drift")
    times.append(t1-t0)
    if discard(handle.value) != 0: raise SystemExit("discard")
schedule=ctypes.c_int(); sr=ctypes.c_double(); rr=ctypes.c_double()
if diag(ctypes.byref(schedule),ctypes.byref(sr),ctypes.byref(rr)) != 0: raise SystemExit("diag")
if abort(handle.value) != 0 or close() != 0: raise SystemExit("close")
print(f"MULTI04_P2|N={n}|SECONDS={statistics.median(times):.12f}|SCHEDULE={schedule.value}|STATIC_RATIO={sr.value:.12f}|SELECTED_RATIO={rr.value:.12f}|QSUM={qsum:.17e}|TSUM={tsum:.17e}")
PY

make_fixture(){
  local out="$1" workers="$2" ordering="$3"
  python3 - "$out" "$N" "$workers" "$ordering" <<'PY'
from pathlib import Path
import sys
out=Path(sys.argv[1]); n=int(sys.argv[2]); workers=int(sys.argv[3]); ordering=int(sys.argv[4])
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
  integer, parameter :: MULTI04_WORKERS={workers}
  integer, parameter :: MULTI04_ORDERING={ordering}
  integer(int64), parameter :: GW_SERVICE_ID=880501_int64
"""
if old not in s: raise SystemExit("constants")
s=s.replace(old,new,1)
s=s.replace("    type(groundwater_topology_cell_t) :: cells(2)\n","    type(groundwater_topology_cell_t) :: cells(NPART)\n",1)
s=s.replace("    type(groundwater_cell_area_input_t) :: areas(2)\n","    type(groundwater_cell_area_input_t) :: areas(NPART)\n",1)
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
      call set_tile(tiles(i),880200_int64+int(i,int64),980200_int64+int(i,int64),700000_int64+int(i,int64),1.0_real64)
      call set_cell(cells(i),700000_int64+int(i,int64),880300_int64+int(i,int64),880400_int64+int(i,int64),i,i)
    end do
    call materialize_groundwater_topology(tiles,cells,topology,status)
    if(status/=GW_TOPOLOGY_OK .or. .not.topology%ready())return
    do i=1,NPART
      call make_predictor(predictors(i),tiles(i),cells(i),reference_head,1)
      areas(i)%groundwater_cell_id=cells(i)%groundwater_cell_id; areas(i)%cell_area_m2=1.0_real64
    end do
"""
if old not in s: raise SystemExit("topology")
s=s.replace(old,new,1)
s=s.replace("    integer :: i\n    value%initial_time=0.0_real64\n","    integer :: i,klass\n    value%initial_time=0.0_real64\n    value%groundwater_parallel_workers=MULTI04_WORKERS\n",1)
s=s.replace("      value%tiles(i)%tile_id=TILE_ID(i); value%tiles(i)%ledger_id=LEDGER_ID(i)\n",
            "      value%tiles(i)%tile_id=880200_int64+int(i,int64); value%tiles(i)%ledger_id=980200_int64+int(i,int64)\n",1)
old="""      allocate(value%tiles(i)%initial_right_derivative(numnod))
      value%tiles(i)%initial_right_derivative=HISTORY_RATE
"""
new="""      allocate(value%tiles(i)%initial_right_derivative(numnod))
      if(MULTI04_ORDERING==0)then
        klass=min(3,4*(i-1)/max(1,NPART))
      else
        klass=mod(i-1,4)
      end if
      value%tiles(i)%initial_right_derivative=100.0_real64*4.0_real64**klass
"""
if old not in s: raise SystemExit("history")
s=s.replace(old,new,1)
# Research-only diagnostic bridge over the production bootstrap method.
needle="  integer(c_int) function fpe_temporal08_fixture_close_c() bind(C,name=\"fpe_temporal08_fixture_close_c\") result(c_status)\n"
bridge="""  integer(c_int) function fpe_multi04_schedule_diag_c(schedule_code,static_ratio,selected_ratio) &
       bind(C,name="fpe_multi04_schedule_diag_c") result(c_status)
    integer(c_int),intent(out)::schedule_code
    real(c_double),intent(out)::static_ratio,selected_ratio
    integer :: local_schedule,status
    real(real64) :: local_static,local_selected
    logical :: available
    c_status=1_c_int; schedule_code=-1_c_int; static_ratio=0.0_c_double; selected_ratio=0.0_c_double
    call app%groundwater_parallel_schedule_diagnostics(local_schedule,local_static,local_selected,available,status)
    if(status/=FMR_APP_BOOT_OK .or. .not.available)return
    schedule_code=int(local_schedule,c_int)
    static_ratio=real(local_static,c_double); selected_ratio=real(local_selected,c_double)
    c_status=0_c_int
  end function fpe_multi04_schedule_diag_c

"""
if needle not in s: raise SystemExit("diag bridge seam")
s=s.replace(needle,bridge+needle,1)
s=s.replace("  public :: fpe_temporal08_missing_seed_rejected_c\n","  public :: fpe_temporal08_missing_seed_rejected_c\n  public :: fpe_multi04_schedule_diag_c\n",1)
out.write_text(s)
PY
}

compile_variant(){
  local name="$1" fixture="$2" context_source="$3"
  local OUT="$BUILD/$name"; mkdir -p "$OUT"
  mapfile -t MODULE_SRC < <(python3 - "$fixture" "$context_source" <<'PY'
from pathlib import Path
import sys,re
fixture=Path(sys.argv[1]).resolve(); context=Path(sys.argv[2]).resolve()
s=Path("tests/fpe/run_fpe_temporal08_p3_live_production.sh").read_text()
m=re.search(r'MODULE_SRC=\(\n(.*?)\n\)',s,re.S)
if not m: raise SystemExit("module list")
for raw in m.group(1).splitlines():
    p=raw.strip()
    if p=="tests/fpe/mod_fpe_temporal08_production_live_fixture.f90": print(fixture)
    elif p=="src/runtime/mod_fmr_groundwater_application_context.f90": print(context)
    elif p: print(p)
PY
)
  local COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fPIC -fopenmp)
  local objects=()
  for source in "${MODULE_SRC[@]}"; do
    local obj="$OUT/$(basename "${source%.*}").o"
    gfortran "${COMMON[@]}" -O2 -J "$OUT" -I "$OUT" -c "$source" -o "$obj" || fail "compile $name $source"
    objects+=("$obj")
  done
  gfortran -shared -fopenmp -O2 "${objects[@]}" -o "$OUT/libmulti04.so" || fail "link $name"
}

CURRENT_CONTEXT="$ROOT/src/runtime/mod_fmr_groundwater_application_context.f90"
for order in 0 1; do
  for workers in 1 2 4; do
    fixture="$BUILD/fixture_o${order}_w${workers}.f90"
    make_fixture "$fixture" "$workers" "$order"
    name="hybrid_o${order}_w${workers}"
    compile_variant "$name" "$fixture" "$CURRENT_CONTEXT"
    MULTI04_LIB="$BUILD/$name/libmulti04.so" MULTI04_P2_REPS="$NREP" python3 "$BUILD/probe.py" | tee "$BUILD/$name.txt"
  done
  fixture="$BUILD/fixture_o${order}_static4.f90"
  make_fixture "$fixture" 4 "$order"
  name="static_o${order}_w4"
  compile_variant "$name" "$fixture" "$STATIC_CONTEXT"
  MULTI04_LIB="$BUILD/$name/libmulti04.so" MULTI04_P2_REPS="$NREP" python3 "$BUILD/probe.py" | tee "$BUILD/$name.txt"
done

python3 - "$BUILD" <<'PY'
from pathlib import Path
import re,sys
root=Path(sys.argv[1])
def row(path):
    txt=path.read_text()
    m=re.search(r'^MULTI04_P2\|N=(\d+)\|SECONDS=([^|]+)\|SCHEDULE=(\d+)\|STATIC_RATIO=([^|]+)\|SELECTED_RATIO=([^|]+)\|QSUM=([^|]+)\|TSUM=(.+)$',txt,re.M)
    if not m: raise SystemExit(f"missing row {path}")
    return dict(n=int(m[1]),sec=float(m[2]),schedule=int(m[3]),sr=float(m[4]),rr=float(m[5]),q=float(m[6]),t=float(m[7]))
for order in (0,1):
    h={w:row(root/f"hybrid_o{order}_w{w}.txt") for w in (1,2,4)}
    st=row(root/f"static_o{order}_w4.txt")
    q0,t0=h[1]["q"],h[1]["t"]
    for w in (2,4):
        if h[w]["q"]!=q0 or h[w]["t"]!=t0: raise SystemExit(f"semantic drift order={order} workers={w}")
    if st["q"]!=q0 or st["t"]!=t0: raise SystemExit(f"static semantic drift order={order}")
    s2=h[1]["sec"]/h[2]["sec"]; s4=h[1]["sec"]/h[4]["sec"]; vs_static=st["sec"]/h[4]["sec"]
    expected4=1 if order==0 else 2
    print(f"MULTI04_P2_SUMMARY|ORDER={order}|SCHEDULE4={h[4]['schedule']}|STATIC_RATIO4={h[4]['sr']:.6f}|SELECTED_RATIO4={h[4]['rr']:.6f}|SPEEDUP2={s2:.6f}|SPEEDUP4={s4:.6f}|HYBRID_VS_STATIC4={vs_static:.6f}|QSUM={q0:.17e}|TSUM={t0:.17e}")
    if h[4]["schedule"]!=expected4: raise SystemExit(f"wrong scheduler order={order}")
    if order==0 and h[4]["sr"]>1.20: raise SystemExit("balanced ordering predicted imbalanced")
    if order==1 and h[4]["sr"]<=1.20: raise SystemExit("adverse ordering not detected")
    if h[4]["rr"]>1.20: raise SystemExit(f"selected load ratio failed order={order}")
    if s2<1.5: raise SystemExit(f"2-worker speed gate failed order={order}: {s2}")
    if s4<2.2: raise SystemExit(f"4-worker speed gate failed order={order}: {s4}")
    if h[4]["sec"]>1.02*st["sec"]: raise SystemExit(f"no-regression gate failed order={order}")
print("FPE_MULTI04_P2_BOUNDED_HYBRID=PASS")
PY

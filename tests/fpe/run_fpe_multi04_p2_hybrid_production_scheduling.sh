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

FIXTURE="$BUILD/mod_fpe_multi04_p2_fixture.f90"
BOOT="$BUILD/mod_fmr_production_application_bootstrap.f90"
CTX_HYB="src/runtime/mod_fmr_groundwater_application_context.f90"
CTX_STATIC="$BUILD/mod_fmr_groundwater_application_context_static.f90"

cp tests/fpe/mod_fpe_temporal08_production_live_fixture.f90 "$FIXTURE"
cp src/runtime/mod_fmr_production_application_bootstrap.f90 "$BOOT"
cp src/runtime/mod_fmr_groundwater_application_context.f90 "$CTX_STATIC"

python3 - "$FIXTURE" "$BOOT" "$CTX_STATIC" "$N" <<'PY'
from pathlib import Path
import sys
fixture=Path(sys.argv[1]); boot=Path(sys.argv[2]); static=Path(sys.argv[3]); n=int(sys.argv[4])

s=fixture.read_text()
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
  integer(int64), parameter :: GW_SERVICE_ID=880501_int64
"""
if old not in s: raise SystemExit("fixture constants seam missing")
s=s.replace(old,new,1)
s=s.replace("  public :: fpe_temporal08_missing_seed_rejected_c\n",
            "  public :: fpe_temporal08_missing_seed_rejected_c\n  public :: fpe_multi04_p2_schedule_diag_c\n",1)

old_sig="""  integer(c_int) function fpe_temporal08_fixture_initialize_c(context_handle,href1,href2) &
       bind(C,name="fpe_temporal08_fixture_initialize_c") result(c_status)
    integer(c_int64_t), intent(out) :: context_handle
    real(c_double), intent(out) :: href1,href2
"""
new_sig="""  integer(c_int) function fpe_temporal08_fixture_initialize_c(context_handle,href1,href2,workers,ordering) &
       bind(C,name="fpe_temporal08_fixture_initialize_c") result(c_status)
    integer(c_int64_t), intent(out) :: context_handle
    real(c_double), intent(out) :: href1,href2
    integer(c_int), value, intent(in) :: workers, ordering
"""
if old_sig not in s: raise SystemExit("fixture init sig seam missing")
s=s.replace(old_sig,new_sig,1)
s=s.replace("    call initialize_config(config)\n    call app%initialize(config,status)\n",
            "    call initialize_config(config,int(workers),int(ordering))\n    call app%initialize(config,status)\n",1)
s=s.replace("    type(groundwater_topology_cell_t) :: cells(2)\n","    type(groundwater_topology_cell_t) :: cells(NPART)\n",1)
s=s.replace("    type(groundwater_cell_area_input_t) :: areas(2)\n","    type(groundwater_cell_area_input_t) :: areas(NPART)\n",1)

old_top="""    do i=1,NPART
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
new_top="""    do i=1,NPART
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
if old_top not in s: raise SystemExit("fixture topology seam missing")
s=s.replace(old_top,new_top,1)

s=s.replace("    call initialize_config(config)\n    do i=1,size(config%tiles)\n",
            "    call initialize_config(config,1,0)\n    do i=1,size(config%tiles)\n",1)
s=s.replace("  subroutine initialize_config(value)\n    type(fmr_production_application_config_t),intent(out)::value\n    integer :: i\n",
"""  subroutine initialize_config(value,workers,ordering)
    type(fmr_production_application_config_t),intent(out)::value
    integer,intent(in)::workers,ordering
    integer :: i,klass
    real(real64),parameter :: rates(4)=[100.0_real64,400.0_real64,1600.0_real64,6400.0_real64]
""",1)
s=s.replace("    value%initial_time=0.0_real64\n",
            "    value%initial_time=0.0_real64\n    value%groundwater_parallel_workers=workers\n",1)
s=s.replace("      value%tiles(i)%tile_id=TILE_ID(i); value%tiles(i)%ledger_id=LEDGER_ID(i)\n",
            "      value%tiles(i)%tile_id=880200_int64+int(i,int64); value%tiles(i)%ledger_id=980200_int64+int(i,int64)\n",1)
s=s.replace("      value%tiles(i)%initial_right_derivative=HISTORY_RATE\n",
"""      if(ordering==0)then
        klass=min(3,4*(i-1)/max(1,NPART))+1
      else
        klass=mod(i-1,4)+1
      end if
      value%tiles(i)%initial_right_derivative=rates(klass)
""",1)

end="end module mod_fpe_temporal08_production_live_fixture"
diag=r'''
  integer(c_int) function fpe_multi04_p2_schedule_diag_c(schedule_code,static_ratio,selected_ratio) &
       bind(C,name="fpe_multi04_p2_schedule_diag_c") result(c_status)
    integer(c_int),intent(out)::schedule_code
    real(c_double),intent(out)::static_ratio,selected_ratio
    integer :: schedule,status
    real(real64) :: sr,rr
    logical :: available
    c_status=1_c_int; schedule_code=-1_c_int; static_ratio=0.0_c_double; selected_ratio=0.0_c_double
    call app%multi04_parallel_schedule_diagnostics(schedule,sr,rr,available,status)
    if(status/=FMR_APP_BOOT_OK .or. .not.available)return
    schedule_code=int(schedule,c_int); static_ratio=real(sr,c_double); selected_ratio=real(rr,c_double)
    c_status=0_c_int
  end function fpe_multi04_p2_schedule_diag_c

'''
if end not in s: raise SystemExit("fixture end seam missing")
s=s.replace(end,diag+end,1)
fixture.write_text(s)

s=boot.read_text()
needle="    procedure, public :: copy_committed_revisions => production_application_copy_committed_revisions\n"
if needle not in s: raise SystemExit("bootstrap method seam missing")
s=s.replace(needle,needle+"    procedure, public :: multi04_parallel_schedule_diagnostics => production_application_multi04_schedule_diagnostics\n",1)
end="end module mod_fmr_production_application_bootstrap"
helper=r'''
  subroutine production_application_multi04_schedule_diagnostics(self,schedule_code,static_ratio,selected_ratio,available,status)
    class(fmr_production_application_bootstrap_t),intent(in) :: self
    integer,intent(out)::schedule_code
    real(real64),intent(out)::static_ratio,selected_ratio
    logical,intent(out)::available
    integer,intent(out)::status
    schedule_code=0; static_ratio=1.0_real64; selected_ratio=1.0_real64; available=.false.
    status=FMR_APP_BOOT_NOT_READY
    if(.not.self%ready())return
    if(.not.associated(self%active_context))return
    call self%active_context%parallel_schedule_diagnostics(schedule_code,static_ratio,selected_ratio,available)
    if(.not.available)return
    status=FMR_APP_BOOT_OK
  end subroutine production_application_multi04_schedule_diagnostics

'''
if end not in s: raise SystemExit("bootstrap end seam missing")
s=s.replace(end,helper+end,1)
boot.write_text(s)

s=static.read_text()
needle="  real(real64), parameter :: FMR_GW_PARALLEL_LOAD_RATIO_THRESHOLD = 1.20_real64\n"
if needle not in s: raise SystemExit("static threshold seam missing")
s=s.replace(needle,"  real(real64), parameter :: FMR_GW_PARALLEL_LOAD_RATIO_THRESHOLD = huge(1.0_real64)\n",1)
static.write_text(s)
PY

cat > "$BUILD/probe.py" <<'PY'
import ctypes, os, statistics, sys, time
from pathlib import Path
lib=ctypes.CDLL(str(Path(sys.argv[1]).resolve()))
workers=int(sys.argv[2]); ordering=int(sys.argv[3]); reps=int(sys.argv[4])

init=lib.fpe_temporal08_fixture_initialize_c
init.restype=ctypes.c_int
init.argtypes=[ctypes.POINTER(ctypes.c_int64),ctypes.POINTER(ctypes.c_double),ctypes.POINTER(ctypes.c_double),ctypes.c_int,ctypes.c_int]
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
diag=lib.fpe_multi04_p2_schedule_diag_c; diag.restype=ctypes.c_int
diag.argtypes=[ctypes.POINTER(ctypes.c_int),ctypes.POINTER(ctypes.c_double),ctypes.POINTER(ctypes.c_double)]

handle=ctypes.c_int64(); h1=ctypes.c_double(); h2=ctypes.c_double()
if init(ctypes.byref(handle),ctypes.byref(h1),ctypes.byref(h2),workers,ordering)!=0: raise SystemExit("init")
nc=ctypes.c_int(); nt=ctypes.c_int()
if counts(handle.value,ctypes.byref(nc),ctypes.byref(nt))!=0 or nc.value!=nt.value: raise SystemExit("counts")
if capture(handle.value)!=0: raise SystemExit("capture")
n=nc.value
heads=(ctypes.c_double*n)(*([h1.value]*n)); flux=(ctypes.c_double*n)(); tan=(ctypes.c_double*n)()

if trial(handle.value,n,heads,flux)!=0: raise SystemExit("warm trial")
if tangent(handle.value,n,tan)!=0: raise SystemExit("warm tangent")
if discard(handle.value)!=0: raise SystemExit("warm discard")

times=[]; qsum=None; tsum=None; sch=ctypes.c_int(); sr=ctypes.c_double(); rr=ctypes.c_double()
for rep in range(reps):
    a=time.perf_counter(); rc=trial(handle.value,n,heads,flux); b=time.perf_counter()
    if rc!=0: raise SystemExit(f"trial {rep}")
    if tangent(handle.value,n,tan)!=0: raise SystemExit("tangent")
    if diag(ctypes.byref(sch),ctypes.byref(sr),ctypes.byref(rr))!=0: raise SystemExit("diag")
    q=sum(float(flux[i]) for i in range(n)); t=sum(float(tan[i]) for i in range(n))
    if qsum is None: qsum,tsum=q,t
    elif q!=qsum or t!=tsum: raise SystemExit("repeat drift")
    times.append(b-a)
    if discard(handle.value)!=0: raise SystemExit("discard")
if abort(handle.value)!=0: raise SystemExit("abort")
if close()!=0: raise SystemExit("close")
print(f"MULTI04_P2|WORKERS={workers}|ORDER={ordering}|SECONDS={statistics.median(times):.12f}|SCHEDULE={sch.value}|STATIC_RATIO={sr.value:.9f}|SELECTED_RATIO={rr.value:.9f}|QSUM={qsum:.17e}|TSUM={tsum:.17e}")
PY

mapfile -t BASE_MODULES < <(python3 - <<'PY'
from pathlib import Path
import re
s=Path("tests/fpe/run_fpe_temporal08_p3_live_production.sh").read_text()
m=re.search(r'MODULE_SRC=\(\n(.*?)\n\)',s,re.S)
if not m: raise SystemExit("module list missing")
for raw in m.group(1).splitlines():
    p=raw.strip()
    if p and p!="src/adapter/mod_modflow6_fgc34_c_bridge.f90":
        print(p)
PY
)

compile_variant(){
  local name="$1" ctx="$2"
  local out="$BUILD/$name"
  mkdir -p "$out"
  local objects=()
  for source in "${BASE_MODULES[@]}"; do
    case "$source" in
      src/runtime/mod_fmr_groundwater_application_context.f90) source="$ctx" ;;
      src/runtime/mod_fmr_production_application_bootstrap.f90) source="$BOOT" ;;
      tests/fpe/mod_fpe_temporal08_production_live_fixture.f90) source="$FIXTURE" ;;
    esac
    local obj="$out/$(basename "${source%.*}").o"
    gfortran -std=f2008 -ffree-line-length-none -Wall -Wextra -fPIC -fopenmp -O2 -J "$out" -I "$out" -c "$source" -o "$obj" || fail "compile $name $source"
    objects+=("$obj")
  done
  gfortran -shared -fopenmp -O2 "${objects[@]}" -o "$out/libmulti04.so" || fail "link $name"
}
compile_variant hybrid "$CTX_HYB"
compile_variant static "$CTX_STATIC"

for order in 0 1; do
  for workers in 1 2 4; do
    python3 "$BUILD/probe.py" "$BUILD/hybrid/libmulti04.so" "$workers" "$order" "$NREP" | tee "$BUILD/hybrid_o${order}_w${workers}.txt"
  done
  python3 "$BUILD/probe.py" "$BUILD/static/libmulti04.so" 4 "$order" "$NREP" | tee "$BUILD/static_o${order}_w4.txt"
done

python3 - "$BUILD" <<'PY'
from pathlib import Path
import re,sys
b=Path(sys.argv[1])
def row(path):
    txt=path.read_text()
    m=re.search(r'^MULTI04_P2\|WORKERS=(\d+)\|ORDER=(\d+)\|SECONDS=([^|]+)\|SCHEDULE=(\d+)\|STATIC_RATIO=([^|]+)\|SELECTED_RATIO=([^|]+)\|QSUM=([^|]+)\|TSUM=(.+)$',txt,re.M)
    if not m: raise SystemExit(f"missing row {path}")
    return dict(w=int(m[1]),order=int(m[2]),sec=float(m[3]),schedule=int(m[4]),static=float(m[5]),selected=float(m[6]),q=float(m[7]),t=float(m[8]))
for order in (0,1):
    h={w:row(b/f"hybrid_o{order}_w{w}.txt") for w in (1,2,4)}
    s4=row(b/f"static_o{order}_w4.txt")
    q0,t0=h[1]["q"],h[1]["t"]
    for w in (2,4):
        if h[w]["q"]!=q0 or h[w]["t"]!=t0: raise SystemExit(f"hybrid semantic drift order={order} w={w}")
    if s4["q"]!=q0 or s4["t"]!=t0: raise SystemExit(f"static semantic drift order={order}")
    sp2=h[1]["sec"]/h[2]["sec"]; sp4=h[1]["sec"]/h[4]["sec"]; vs=s4["sec"]/h[4]["sec"]
    expected=1 if order==0 else 2
    print(f"MULTI04_P2_SUMMARY|ORDER={order}|SELECTED={h[4]['schedule']}|EXPECTED={expected}|STATIC_RATIO={h[4]['static']:.6f}|SELECTED_RATIO={h[4]['selected']:.6f}|SPEEDUP2={sp2:.6f}|SPEEDUP4={sp4:.6f}|HYBRID_VS_STATIC4={vs:.6f}|QSUM={q0:.17e}|TSUM={t0:.17e}")
    if h[4]["schedule"]!=expected: raise SystemExit(f"scheduler selection failed order={order}")
    if h[4]["selected"]>1.20: raise SystemExit(f"selected ratio failed order={order}")
    if sp2<1.5: raise SystemExit(f"2-worker gate failed order={order}: {sp2}")
    if sp4<2.2: raise SystemExit(f"4-worker gate failed order={order}: {sp4}")
    if h[4]["sec"]>1.02*s4["sec"]: raise SystemExit(f"hybrid slower than static order={order}")
print("FPE_MULTI04_P2_HYBRID_PRODUCTION_SCHEDULING=PASS")
PY

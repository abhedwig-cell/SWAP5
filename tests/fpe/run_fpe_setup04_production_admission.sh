#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-setup04-${GITHUB_RUN_ID:-local}-$$"
N="${SETUP04_N:-10000}"
NREP="${SETUP04_REPS:-3}"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "FPE_SETUP04_FAIL $*" >&2; exit 1; }

# Freeze the canonical baseline source for a paired production-candidate comparison.
BASE_SHA="4ee57d17a3793a58c792d5de9cdd0a38f9e7918a"
git show "$BASE_SHA:src/runtime/mod_fmr_production_application_bootstrap.f90" > "$BUILD/baseline_bootstrap.f90"
git show "$BASE_SHA:src/runtime/mod_fmr_groundwater_participant_registry.f90" > "$BUILD/baseline_registry.f90"

# Create one instrumented production-shaped fixture for this N.
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
  integer, parameter :: SETUP04_WORKERS={workers}
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
"    value%initial_time=0.0_real64\n    value%groundwater_parallel_workers=SETUP04_WORKERS\n",1)
s=s.replace(
"      value%tiles(i)%tile_id=TILE_ID(i); value%tiles(i)%ledger_id=LEDGER_ID(i)\n",
"      value%tiles(i)%tile_id=880200_int64+int(i,int64); value%tiles(i)%ledger_id=980200_int64+int(i,int64)\n",1)

# Phase timing around app%initialize.
old_decl="    integer :: i,status\n"
new_decl="""    integer :: i,status
    integer(int64) :: tick0,tick1,tick2,tick_rate
"""
if old_decl not in s: raise SystemExit("timing decl seam missing")
s=s.replace(old_decl,new_decl,1)
old="""    call initialize_config(config)
    call app%initialize(config,status)
    if(status/=FMR_APP_BOOT_OK .or. .not.app%ready())return
"""
new="""    call system_clock(tick0,tick_rate)
    call initialize_config(config)
    call system_clock(tick1)
    call app%initialize(config,status)
    if(status/=FMR_APP_BOOT_OK .or. .not.app%ready())return
    call system_clock(tick2)
    write(*,'(*(g0))') 'SETUP04_PHASE|N=',NPART, &
         '|CONFIG_S=',real(tick1-tick0,real64)/real(tick_rate,real64), &
         '|APP_INIT_S=',real(tick2-tick1,real64)/real(tick_rate,real64)
"""
if old not in s: raise SystemExit("timing seam missing")
s=s.replace(old,new,1)

# Add duplicate-guard probe.
public_marker="  public :: fpe_temporal08_missing_seed_rejected_c\n"
if public_marker not in s: raise SystemExit("public seam missing")
s=s.replace(public_marker,public_marker+"  public :: setup04_duplicate_guard_c\n",1)

contains_marker="contains\n\n"
guard=r'''contains

  integer(c_int) function setup04_duplicate_guard_c(kind) &
       bind(C,name="setup04_duplicate_guard_c") result(c_status)
    integer(c_int), value :: kind
    type(fmr_production_application_config_t) :: config
    type(fmr_production_application_bootstrap_t) :: probe
    integer :: local_status

    c_status=1_c_int
    call initialize_config(config)
    if(size(config%tiles)<2)return
    select case(kind)
    case(1_c_int)
      config%tiles(2)%tile_id=config%tiles(1)%tile_id
    case(2_c_int)
      config%tiles(2)%ledger_id=config%tiles(1)%ledger_id
    case default
      return
    end select
    call probe%initialize(config,local_status)
    if(local_status==FMR_APP_BOOT_OK .or. probe%ready())then
      if(probe%ready())call probe%close(local_status)
      return
    end if
    c_status=0_c_int
  end function setup04_duplicate_guard_c

'''
if contains_marker not in s: raise SystemExit("contains seam missing")
s=s.replace(contains_marker,guard,1)

out.write_text(s)
PY

cat > "$BUILD/probe.py" <<'PY'
import ctypes, os
from pathlib import Path
lib=ctypes.CDLL(str(Path(os.environ["SETUP04_LIB"]).resolve()))
init=lib.fpe_temporal08_fixture_initialize_c
init.restype=ctypes.c_int
init.argtypes=[ctypes.POINTER(ctypes.c_int64),ctypes.POINTER(ctypes.c_double),ctypes.POINTER(ctypes.c_double)]
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

h=ctypes.c_int64(); a=ctypes.c_double(); b=ctypes.c_double()
if init(ctypes.byref(h),ctypes.byref(a),ctypes.byref(b))!=0: raise SystemExit("init")
nc=ctypes.c_int(); nt=ctypes.c_int()
if counts(h.value,ctypes.byref(nc),ctypes.byref(nt))!=0: raise SystemExit("counts")
n=nc.value
heads=(ctypes.c_double*n)(*([a.value]*n))
flux=(ctypes.c_double*n)()
tan=(ctypes.c_double*n)()
if capture(h.value)!=0: raise SystemExit("capture")
if trial(h.value,n,heads,flux)!=0: raise SystemExit("trial")
if tangent(h.value,n,tan)!=0: raise SystemExit("tangent")
q=sum(float(flux[i]) for i in range(n))
t=sum(float(tan[i]) for i in range(n))
if discard(h.value)!=0: raise SystemExit("discard")
if abort(h.value)!=0: raise SystemExit("abort")
if close()!=0: raise SystemExit("close")
print(f"SETUP04_CHECK|N={n}|QSUM={q:.17e}|TSUM={t:.17e}")
print("SETUP04_PROBE=PASS")
PY

cat > "$BUILD/guard.py" <<'PY'
import ctypes, os
from pathlib import Path
lib=ctypes.CDLL(str(Path(os.environ["SETUP04_LIB"]).resolve()))
f=lib.setup04_duplicate_guard_c
f.restype=ctypes.c_int
f.argtypes=[ctypes.c_int]
for kind in (1,2):
    rc=f(kind)
    if rc!=0: raise SystemExit(f"duplicate guard failed kind={kind} rc={rc}")
print("SETUP04_DUPLICATE_GUARDS=PASS")
PY

build_variant() {
  local tag="$1"
  local bootstrap="$2"
  local registry="$3"
  local out="$BUILD/$tag"
  mkdir -p "$out"
  mapfile -t MODULE_SRC < <(python3 - "$BUILD/fixture.f90" "$bootstrap" "$registry" <<'PY'
from pathlib import Path
import sys,re
fixture=Path(sys.argv[1]).resolve()
bootstrap=None if sys.argv[2]=="BASE" else Path(sys.argv[2]).resolve()
registry=None if sys.argv[3]=="BASE" else Path(sys.argv[3]).resolve()
s=Path("tests/fpe/run_fpe_temporal08_p3_live_production.sh").read_text()
m=re.search(r'MODULE_SRC=\(\n(.*?)\n\)',s,re.S)
if not m: raise SystemExit("module list missing")
for raw in m.group(1).splitlines():
    p=raw.strip()
    if not p: continue
    if p=="tests/fpe/mod_fpe_temporal08_production_live_fixture.f90":
        print(fixture)
    elif p=="src/runtime/mod_fmr_groundwater_participant_registry.f90" and registry is not None:
        print(registry)
    elif p=="src/runtime/mod_fmr_production_application_bootstrap.f90" and bootstrap is not None:
        print(bootstrap)
    else:
        print(p)
PY
)
  COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fPIC -fopenmp)
  objects=()
  for source in "${MODULE_SRC[@]}"; do
    obj="$out/$(basename "${source%.*}").o"
    gfortran "${COMMON[@]}" -O2 -J "$out" -I "$out" -c "$source" -o "$obj" || fail "compile $tag $source"
    objects+=("$obj")
  done
  gfortran -shared -fopenmp -O2 "${objects[@]}" -o "$out/lib.so" || fail "link $tag"
}

build_variant baseline "$BUILD/baseline_bootstrap.f90" "$BUILD/baseline_registry.f90"
build_variant candidate BASE BASE

for tag in baseline candidate; do
  : > "$BUILD/$tag.txt"
  for rep in $(seq 1 "$NREP"); do
    OMP_DYNAMIC=FALSE OMP_NUM_THREADS=4 SETUP04_LIB="$BUILD/$tag/lib.so" python3 "$BUILD/probe.py" | tee -a "$BUILD/$tag.txt"
  done
  if (( N <= 1000 )); then
    SETUP04_LIB="$BUILD/$tag/lib.so" python3 "$BUILD/guard.py" | tee -a "$BUILD/$tag.txt"
  fi
done

python3 - "$N" "$BUILD/baseline.txt" "$BUILD/candidate.txt" <<'PY'
import re,statistics,sys
n=int(sys.argv[1])
def vals(path):
    rows=[]
    txt=open(path).read()
    for m in re.finditer(r'SETUP04_PHASE\|N=(\d+)\|CONFIG_S=([^|]+)\|APP_INIT_S=(.+)',txt):
        rows.append((int(m.group(1)),float(m.group(2)),float(m.group(3))))
    if not rows: raise SystemExit(f"missing timing rows {path}")
    return rows
b=vals(sys.argv[2]); c=vals(sys.argv[3])
bm=statistics.median(x[2] for x in b); cm=statistics.median(x[2] for x in c)
ratio=cm/bm; speed=bm/cm

def checks(path):
    rows=[]
    txt=open(path).read()
    for m in re.finditer(r'SETUP04_CHECK\|N=(\d+)\|QSUM=([^|]+)\|TSUM=(.+)',txt):
        rows.append((int(m.group(1)),float(m.group(2)),float(m.group(3))))
    if not rows: raise SystemExit(f"missing q/tangent rows {path}")
    return rows
bc=checks(sys.argv[2]); cc=checks(sys.argv[3])
bq=statistics.median(x[1] for x in bc); cq=statistics.median(x[1] for x in cc)
bt=statistics.median(x[2] for x in bc); ct=statistics.median(x[2] for x in cc)
if bq!=cq or bt!=ct:
    raise SystemExit(f"q/tangent identity mismatch dq={cq-bq} dt={ct-bt}")

print(f"SETUP04_SUMMARY|N={n}|BASE_APP_INIT_S={bm:.12f}|CAND_APP_INIT_S={cm:.12f}|CAND_BASE_RATIO={ratio:.6f}|SPEEDUP={speed:.6f}|QSUM={bq:.17e}|TSUM={bt:.17e}")
if n==1000 and ratio>1.10: raise SystemExit(f"N=1000 no-regression gate failed {ratio}")
if n==10000 and speed<3.0: raise SystemExit(f"N=10000 speed gate failed {speed}")
if n==40000 and speed<8.0: raise SystemExit(f"N=40000 speed gate failed {speed}")
print("FPE_SETUP04=PASS")
PY

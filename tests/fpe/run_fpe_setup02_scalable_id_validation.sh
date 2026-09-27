#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-setup02-${GITHUB_RUN_ID:-local}-$$"
N="${SETUP02_N:-10000}"
NREP="${SETUP02_REPS:-3}"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "FPE_SETUP02_FAIL $*" >&2; exit 1; }

# Build a research-only O(N log N) bootstrap source.
python3 - "$BUILD/candidate_bootstrap.f90" <<'PY'
from pathlib import Path
import sys
s=Path("src/runtime/mod_fmr_production_application_bootstrap.f90").read_text()

tile_dup="""      if (i > 1) then
        if (any(config%tiles(1:i-1)%tile_id == config%tiles(i)%tile_id)) return
      end if
"""
ledger_dup="""        if (i > 1) then
          if (any(config%tiles(1:i-1)%ledger_id == config%tiles(i)%ledger_id)) return
        end if
"""
if s.count(tile_dup)!=1 or s.count(ledger_dup)!=1:
    raise SystemExit("SETUP02 duplicate-scan seam mismatch")
s=s.replace(tile_dup,"",1)
s=s.replace(ledger_dup,"",1)

tile_insert="""    end do
    if (.not. int64_values_unique(config%tiles%tile_id)) return
    if (.not. groundwater_profile .and. .not. standalone_profile .and. .not. prescribed_qbot_profile) then
"""
old="""    end do
    if (.not. groundwater_profile .and. .not. standalone_profile .and. .not. prescribed_qbot_profile) then
"""
if old not in s: raise SystemExit("SETUP02 tile uniqueness insertion seam missing")
s=s.replace(old,tile_insert,1)

old="""      end do
    end if

    if (direct_retention_requested .and. .not. groundwater_profile) then
"""
new="""      end do
      if (.not. int64_values_unique(config%tiles%ledger_id)) return
    end if

    if (direct_retention_requested .and. .not. groundwater_profile) then
"""
if old not in s: raise SystemExit("SETUP02 ledger uniqueness insertion seam missing")
s=s.replace(old,new,1)

helper=r'''
  logical function int64_values_unique(values) result(unique)
    integer(int64), intent(in) :: values(:)
    integer(int64), allocatable :: sorted(:), workspace(:)
    integer :: n, width, left, middle, right, i, j, k

    unique = .true.
    n = size(values)
    if (n <= 1) return

    allocate(sorted(n), workspace(n))
    sorted = values

    width = 1
    do while (width < n)
      left = 1
      do while (left <= n)
        middle = min(left + width - 1, n)
        right = min(left + 2*width - 1, n)
        i = left
        j = middle + 1
        k = left
        do while (i <= middle .and. j <= right)
          if (sorted(i) <= sorted(j)) then
            workspace(k) = sorted(i)
            i = i + 1
          else
            workspace(k) = sorted(j)
            j = j + 1
          end if
          k = k + 1
        end do
        do while (i <= middle)
          workspace(k) = sorted(i)
          i = i + 1
          k = k + 1
        end do
        do while (j <= right)
          workspace(k) = sorted(j)
          j = j + 1
          k = k + 1
        end do
        left = left + 2*width
      end do
      sorted = workspace
      width = width * 2
    end do

    do i = 2, n
      if (sorted(i) == sorted(i-1)) then
        unique = .false.
        return
      end if
    end do
  end function int64_values_unique

'''
marker="end module mod_fmr_production_application_bootstrap"
if marker not in s: raise SystemExit("SETUP02 module-end seam missing")
s=s.replace(marker,helper+marker,1)
Path(sys.argv[1]).write_text(s)
PY

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
  integer, parameter :: SETUP02_WORKERS={workers}
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
"    value%initial_time=0.0_real64\n    value%groundwater_parallel_workers=SETUP02_WORKERS\n",1)
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
    write(*,'(*(g0))') 'SETUP02_PHASE|N=',NPART, &
         '|CONFIG_S=',real(tick1-tick0,real64)/real(tick_rate,real64), &
         '|APP_INIT_S=',real(tick2-tick1,real64)/real(tick_rate,real64)
"""
if old not in s: raise SystemExit("timing seam missing")
s=s.replace(old,new,1)

# Add duplicate-guard probe.
public_marker="  public :: fpe_temporal08_missing_seed_rejected_c\n"
if public_marker not in s: raise SystemExit("public seam missing")
s=s.replace(public_marker,public_marker+"  public :: setup02_duplicate_guard_c\n",1)

contains_marker="contains\n\n"
guard=r'''contains

  integer(c_int) function setup02_duplicate_guard_c(kind) &
       bind(C,name="setup02_duplicate_guard_c") result(c_status)
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
  end function setup02_duplicate_guard_c

'''
if contains_marker not in s: raise SystemExit("contains seam missing")
s=s.replace(contains_marker,guard,1)

out.write_text(s)
PY

cat > "$BUILD/probe.py" <<'PY'
import ctypes, os
from pathlib import Path
lib=ctypes.CDLL(str(Path(os.environ["SETUP02_LIB"]).resolve()))
init=lib.fpe_temporal08_fixture_initialize_c
init.restype=ctypes.c_int
init.argtypes=[ctypes.POINTER(ctypes.c_int64),ctypes.POINTER(ctypes.c_double),ctypes.POINTER(ctypes.c_double)]
close=lib.fpe_temporal08_fixture_close_c
close.restype=ctypes.c_int
close.argtypes=[]
h=ctypes.c_int64(); a=ctypes.c_double(); b=ctypes.c_double()
if init(ctypes.byref(h),ctypes.byref(a),ctypes.byref(b))!=0: raise SystemExit("init")
if close()!=0: raise SystemExit("close")
print("SETUP02_PROBE=PASS")
PY

cat > "$BUILD/guard.py" <<'PY'
import ctypes, os
from pathlib import Path
lib=ctypes.CDLL(str(Path(os.environ["SETUP02_LIB"]).resolve()))
f=lib.setup02_duplicate_guard_c
f.restype=ctypes.c_int
f.argtypes=[ctypes.c_int]
for kind in (1,2):
    rc=f(kind)
    if rc!=0: raise SystemExit(f"duplicate guard failed kind={kind} rc={rc}")
print("SETUP02_DUPLICATE_GUARDS=PASS")
PY

build_variant() {
  local tag="$1"
  local bootstrap="$2"
  local out="$BUILD/$tag"
  mkdir -p "$out"
  mapfile -t MODULE_SRC < <(python3 - "$BUILD/fixture.f90" "$bootstrap" <<'PY'
from pathlib import Path
import sys,re
fixture=Path(sys.argv[1]).resolve()
bootstrap=None if sys.argv[2]=="BASE" else Path(sys.argv[2]).resolve()
s=Path("tests/fpe/run_fpe_temporal08_p3_live_production.sh").read_text()
m=re.search(r'MODULE_SRC=\(\n(.*?)\n\)',s,re.S)
if not m: raise SystemExit("module list missing")
for raw in m.group(1).splitlines():
    p=raw.strip()
    if not p: continue
    if p=="tests/fpe/mod_fpe_temporal08_production_live_fixture.f90":
        print(fixture)
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

build_variant baseline BASE
build_variant candidate "$BUILD/candidate_bootstrap.f90"

for tag in baseline candidate; do
  : > "$BUILD/$tag.txt"
  for rep in $(seq 1 "$NREP"); do
    OMP_DYNAMIC=FALSE OMP_NUM_THREADS=4 SETUP02_LIB="$BUILD/$tag/lib.so" python3 "$BUILD/probe.py" | tee -a "$BUILD/$tag.txt"
  done
  if (( N <= 1000 )); then
    SETUP02_LIB="$BUILD/$tag/lib.so" python3 "$BUILD/guard.py" | tee -a "$BUILD/$tag.txt"
  fi
done

python3 - "$N" "$BUILD/baseline.txt" "$BUILD/candidate.txt" <<'PY'
import re,statistics,sys
n=int(sys.argv[1])
def vals(path):
    rows=[]
    txt=open(path).read()
    for m in re.finditer(r'SETUP02_PHASE\|N=(\d+)\|CONFIG_S=([^|]+)\|APP_INIT_S=(.+)',txt):
        rows.append((int(m.group(1)),float(m.group(2)),float(m.group(3))))
    if not rows: raise SystemExit(f"missing timing rows {path}")
    return rows
b=vals(sys.argv[2]); c=vals(sys.argv[3])
bm=statistics.median(x[2] for x in b); cm=statistics.median(x[2] for x in c)
ratio=cm/bm; speed=bm/cm
print(f"SETUP02_SUMMARY|N={n}|BASE_APP_INIT_S={bm:.12f}|CAND_APP_INIT_S={cm:.12f}|CAND_BASE_RATIO={ratio:.6f}|SPEEDUP={speed:.6f}")
if n==1000 and ratio>1.05: raise SystemExit(f"N=1000 no-regression gate failed {ratio}")
if n==10000 and speed<2.0: raise SystemExit(f"N=10000 speed gate failed {speed}")
if n==40000 and speed<5.0: raise SystemExit(f"N=40000 speed gate failed {speed}")
print("FPE_SETUP02=PASS")
PY

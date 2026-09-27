#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-multiproc03-${GITHUB_RUN_ID:-local}-$$"
N="${MULTIPROC03_N:-10000}"
NREP="${MULTIPROC03_REPS:-5}"
WORKERS=4
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "FPE_MULTIPROC03_FAIL $*" >&2; exit 1; }

python3 - "$BUILD/compact_context.f90" <<'PY'
from pathlib import Path
import sys
p=Path("src/runtime/mod_fmr_groundwater_application_context.f90")
s=p.read_text()

old_decl="""    integer, allocatable :: registry_status(:), owner(:), order(:), merge_workspace(:)
"""
new_decl="""    integer, allocatable :: registry_status(:), owner(:), order(:), merge_workspace(:)
    integer, allocatable :: worker_counts(:), worker_offsets(:), worker_cursor(:), worker_indices(:)
"""
if old_decl not in s:
    raise SystemExit("MULTIPROC03 declaration seam missing")
s=s.replace(old_decl,new_decl,1)

old_alloc="""      allocate(tile_heads_m(size(self%tiles)), registry_status(size(self%tiles)), owner(size(self%tiles)), &
           predicted_cost(size(self%tiles)), worker_load(self%worker_count), order(size(self%tiles)), &
           merge_workspace(size(self%tiles)))
"""
new_alloc="""      allocate(tile_heads_m(size(self%tiles)), registry_status(size(self%tiles)), owner(size(self%tiles)), &
           predicted_cost(size(self%tiles)), worker_load(self%worker_count), order(size(self%tiles)), &
           merge_workspace(size(self%tiles)), worker_counts(self%worker_count), &
           worker_offsets(self%worker_count+1), worker_cursor(self%worker_count), &
           worker_indices(size(self%tiles)))
"""
if old_alloc not in s:
    raise SystemExit("MULTIPROC03 allocation seam missing")
s=s.replace(old_alloc,new_alloc,1)

old_parallel="""!$omp parallel do default(shared) private(w,idx,participant_status,local_status) schedule(static,1) num_threads(self%worker_count)
      do w = 1, self%worker_count
        do idx = 1, size(self%tiles)
          if (owner(idx) /= w) cycle
          call self%registry%trial_from_origin_on_backend(self%participant_handles(idx), self%worker_backends(w), &
               self%window, tile_heads_m(idx), self%trials(idx), participant_status, local_status)
          registry_status(idx) = local_status
          if (local_status == FMR_GW_REGISTRY_OK .and. self%trials(idx)%valid) self%trial_valid(idx) = .true.
        end do
      end do
!$omp end parallel do
"""
new_parallel="""      worker_counts = 0
      do idx = 1, size(self%tiles)
        worker_counts(owner(idx)) = worker_counts(owner(idx)) + 1
      end do
      worker_offsets(1) = 1
      do w = 1, self%worker_count
        worker_offsets(w+1) = worker_offsets(w) + worker_counts(w)
      end do
      worker_cursor = worker_offsets(1:self%worker_count)
      do idx = 1, size(self%tiles)
        w = owner(idx)
        worker_indices(worker_cursor(w)) = idx
        worker_cursor(w) = worker_cursor(w) + 1
      end do

!$omp parallel do default(shared) private(w,j,idx,participant_status,local_status) schedule(static,1) num_threads(self%worker_count)
      do w = 1, self%worker_count
        do j = worker_offsets(w), worker_offsets(w+1)-1
          idx = worker_indices(j)
          call self%registry%trial_from_origin_on_backend(self%participant_handles(idx), self%worker_backends(w), &
               self%window, tile_heads_m(idx), self%trials(idx), participant_status, local_status)
          registry_status(idx) = local_status
          if (local_status == FMR_GW_REGISTRY_OK .and. self%trials(idx)%valid) self%trial_valid(idx) = .true.
        end do
      end do
!$omp end parallel do
"""
if old_parallel not in s:
    raise SystemExit("MULTIPROC03 parallel seam missing")
s=s.replace(old_parallel,new_parallel,1)
Path(sys.argv[1]).write_text(s)
PY

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
  integer, parameter :: MULTIPROC03_WORKERS={workers}
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
"    value%initial_time=0.0_real64\n    value%groundwater_parallel_workers=MULTIPROC03_WORKERS\n",1)
s=s.replace(
"      value%tiles(i)%tile_id=TILE_ID(i); value%tiles(i)%ledger_id=LEDGER_ID(i)\n",
"      value%tiles(i)%tile_id=880200_int64+int(i,int64); value%tiles(i)%ledger_id=980200_int64+int(i,int64)\n",1)

out.write_text(s)
PY

cat > "$BUILD/probe.py" <<'PY'
import ctypes, os, statistics, time
from pathlib import Path

lib=ctypes.CDLL(str(Path(os.environ["MULTIPROC03_LIB"]).resolve()))
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

handle=ctypes.c_int64(); href1=ctypes.c_double(); href2=ctypes.c_double()
if init(ctypes.byref(handle),ctypes.byref(href1),ctypes.byref(href2)) != 0:
    raise SystemExit("fixture initialize")
nc=ctypes.c_int(); nt=ctypes.c_int()
if counts(handle.value,ctypes.byref(nc),ctypes.byref(nt)) != 0:
    raise SystemExit("context counts")
if capture(handle.value) != 0:
    raise SystemExit("capture origins")
n=nc.value
heads=(ctypes.c_double*n)(*([href1.value]*n))
flux=(ctypes.c_double*n)()
tan=(ctypes.c_double*n)()

if trial(handle.value,n,heads,flux) != 0: raise SystemExit("warm trial")
if tangent(handle.value,n,tan) != 0: raise SystemExit("warm tangent")
if discard(handle.value) != 0: raise SystemExit("warm discard")

times=[]; q0=None; t0=None
reps=int(os.environ.get("MULTIPROC03_REPS","5"))
for rep in range(reps):
    a=time.perf_counter()
    if trial(handle.value,n,heads,flux) != 0: raise SystemExit("trial")
    b=time.perf_counter()
    if tangent(handle.value,n,tan) != 0: raise SystemExit("tangent")
    q=sum(float(flux[i]) for i in range(n))
    t=sum(float(tan[i]) for i in range(n))
    if q0 is None:
        q0,t0=q,t
    elif q!=q0 or t!=t0:
        raise SystemExit("non-deterministic output")
    times.append(b-a)
    if discard(handle.value) != 0: raise SystemExit("discard")

if abort(handle.value) != 0: raise SystemExit("abort")
if close() != 0: raise SystemExit("close")
print(f"MULTIPROC03_VARIANT|N={n}|SECONDS={statistics.median(times):.12f}|QSUM={q0:.17e}|TSUM={t0:.17e}")
PY

build_variant() {
  local tag="$1"
  local context_source="$2"
  local out="$BUILD/$tag"
  mkdir -p "$out"

  mapfile -t MODULE_SRC < <(python3 - "$BUILD/fixture.f90" "$context_source" <<'PY'
from pathlib import Path
import sys,re
fixture=Path(sys.argv[1]).resolve()
context=Path(sys.argv[2]).resolve() if sys.argv[2] != "BASE" else None
s=Path("tests/fpe/run_fpe_temporal08_p3_live_production.sh").read_text()
m=re.search(r'MODULE_SRC=\(\n(.*?)\n\)',s,re.S)
if not m: raise SystemExit("module list missing")
for raw in m.group(1).splitlines():
    p=raw.strip()
    if not p: continue
    if p=="tests/fpe/mod_fpe_temporal08_production_live_fixture.f90":
        print(fixture)
    elif p=="src/runtime/mod_fmr_groundwater_application_context.f90" and context is not None:
        print(context)
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
build_variant compact "$BUILD/compact_context.f90"

for tag in baseline compact; do
  OMP_DYNAMIC=FALSE OMP_NUM_THREADS=4 MULTIPROC03_LIB="$BUILD/$tag/lib.so" MULTIPROC03_REPS="$NREP"     python3 "$BUILD/probe.py" | tee "$BUILD/$tag.txt"
done

python3 - "$N" "$BUILD/baseline.txt" "$BUILD/compact.txt" <<'PY'
import re,sys
n=int(sys.argv[1])
def read(p):
    t=open(p).read()
    m=re.search(r'MULTIPROC03_VARIANT\|N=(\d+)\|SECONDS=([^|]+)\|QSUM=([^|]+)\|TSUM=(.+)',t)
    if not m: raise SystemExit(f"missing row {p}")
    return int(m.group(1)),float(m.group(2)),float(m.group(3)),float(m.group(4))
b=read(sys.argv[2]); c=read(sys.argv[3])
if b[0]!=n or c[0]!=n: raise SystemExit("N mismatch")
if b[2]!=c[2] or b[3]!=c[3]: raise SystemExit("semantic checksum mismatch")
ratio=c[1]/b[1]
speed=b[1]/c[1]
gain=1-ratio
print(f"MULTIPROC03_SUMMARY|N={n}|BASE_SECONDS={b[1]:.12f}|COMPACT_SECONDS={c[1]:.12f}|COMPACT_BASE_RATIO={ratio:.6f}|SPEEDUP={speed:.6f}|GAIN={gain:.6f}|QSUM={b[2]:.17e}|TSUM={b[3]:.17e}")
if n==1000 and ratio>1.02: raise SystemExit(f"N=1000 no-regression gate failed: {ratio}")
if n==10000 and speed<1.10: raise SystemExit(f"N=10000 speed gate failed: {speed}")
if n==40000 and speed<1.20: raise SystemExit(f"N=40000 speed gate failed: {speed}")
print("FPE_MULTIPROC03=PASS")
PY

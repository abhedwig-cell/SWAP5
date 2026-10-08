#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-multiproc01-${GITHUB_RUN_ID:-local}-$$"
TOTAL_N="${MULTIPROC01_N:-10000}"
ROUNDS="${MULTIPROC01_ROUNDS:-5}"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "FPE_MULTIPROC01_FAIL $*" >&2; exit 1; }

if (( TOTAL_N <= 0 || TOTAL_N % 4 != 0 )); then
  fail "MULTIPROC01_N must be positive and divisible by 4"
fi

LOGICAL_CPUS="$(python3 - <<'PY'
import os
print(os.cpu_count() or 1)
PY
)"
echo "MULTIPROC01_HOST|LOGICAL_CPUS=$LOGICAL_CPUS|TOTAL_N=$TOTAL_N|ROUNDS=$ROUNDS"

make_fixture() {
  local out="$1"
  local n="$2"
  local workers="$3"
  python3 - "$out" "$n" "$workers" <<'PY'
from pathlib import Path
import sys
out=Path(sys.argv[1]); n=int(sys.argv[2]); workers=int(sys.argv[3])
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
  integer, parameter :: MULTIPROC01_WORKERS={workers}
  integer(int64), parameter :: GW_SERVICE_ID=880501_int64
"""
if old not in s:
    raise SystemExit("constant seam missing")
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
if old not in s:
    raise SystemExit("topology seam missing")
s=s.replace(old,new,1)

s=s.replace(
"    value%initial_time=0.0_real64\n",
"    value%initial_time=0.0_real64\n    value%groundwater_parallel_workers=MULTIPROC01_WORKERS\n",1)
s=s.replace(
"      value%tiles(i)%tile_id=TILE_ID(i); value%tiles(i)%ledger_id=LEDGER_ID(i)\n",
"      value%tiles(i)%tile_id=880200_int64+int(i,int64); value%tiles(i)%ledger_id=980200_int64+int(i,int64)\n",1)

out.write_text(s)
PY
}

cat > "$BUILD/probe.py" <<'PY'
import ctypes, os, time
from pathlib import Path

lib=ctypes.CDLL(str(Path(os.environ["MULTIPROC01_LIB"]).resolve()))
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
n=nc.value
if n <= 0 or nt.value != n:
    raise SystemExit("unexpected counts")
if capture(handle.value) != 0:
    raise SystemExit("capture origins")

heads=(ctypes.c_double*n)(*([href1.value]*n))
flux=(ctypes.c_double*n)()
tan=(ctypes.c_double*n)()

# warm-up from accepted origin
if trial(handle.value,n,heads,flux) != 0:
    raise SystemExit("warm trial")
if tangent(handle.value,n,tan) != 0:
    raise SystemExit("warm tangent")
if discard(handle.value) != 0:
    raise SystemExit("warm discard")

t0=time.perf_counter()
if trial(handle.value,n,heads,flux) != 0:
    raise SystemExit("measured trial")
t1=time.perf_counter()
if tangent(handle.value,n,tan) != 0:
    raise SystemExit("measured tangent")
qsum=sum(float(flux[i]) for i in range(n))
tsum=sum(float(tan[i]) for i in range(n))
if discard(handle.value) != 0:
    raise SystemExit("measured discard")
if abort(handle.value) != 0:
    raise SystemExit("abort")
if close() != 0:
    raise SystemExit("close")
print(f"MULTIPROC01_PROCESS|N={n}|SECONDS={t1-t0:.12f}|QSUM={qsum:.17e}|TSUM={tsum:.17e}")
PY

build_variant() {
  local tag="$1"
  local n="$2"
  local workers="$3"
  local fixture="$BUILD/fixture_${tag}.f90"
  local out="$BUILD/o_${tag}"
  mkdir -p "$out"
  make_fixture "$fixture" "$n" "$workers"

  mapfile -t MODULE_SRC < <(python3 - "$fixture" <<'PY'
from pathlib import Path
import sys,re
fixture=Path(sys.argv[1]).resolve()
s=Path("tests/fpe/run_fpe_temporal08_p3_live_production.sh").read_text()
m=re.search(r'MODULE_SRC=\(\n(.*?)\n\)',s,re.S)
if not m:
    raise SystemExit("TEMPORAL08 module list missing")
for raw in m.group(1).splitlines():
    p=raw.strip()
    if not p:
        continue
    if p=="tests/fpe/mod_fpe_temporal08_production_live_fixture.f90":
        print(fixture)
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
  gfortran -shared -fopenmp -O2 "${objects[@]}" -o "$out/libmultiproc01.so" || fail "link $tag"
}

build_variant "1x4" "$TOTAL_N" 4
build_variant "2x2" "$((TOTAL_N/2))" 2
build_variant "4x1" "$((TOTAL_N/4))" 1

cat > "$BUILD/orchestrate.py" <<'PY'
import os, re, statistics, subprocess, sys, time
from pathlib import Path

build=Path(sys.argv[1])
rounds=int(sys.argv[2])
total_n=int(sys.argv[3])
logical=int(sys.argv[4])

configs=[
    ("1x4",1,4,build/"o_1x4/libmultiproc01.so"),
    ("2x2",2,2,build/"o_2x2/libmultiproc01.so"),
    ("4x1",4,1,build/"o_4x1/libmultiproc01.so"),
]
rows={}
for name,nproc,workers,lib in configs:
    times=[]
    qsums=[]
    tsums=[]
    for rep in range(rounds):
        procs=[]
        t0=time.perf_counter()
        for _ in range(nproc):
            env=os.environ.copy()
            env["MULTIPROC01_LIB"]=str(lib)
            env["OMP_DYNAMIC"]="FALSE"
            env["OMP_NUM_THREADS"]=str(workers)
            p=subprocess.Popen(
                [sys.executable,str(build/"probe.py")],
                stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,env=env)
            procs.append(p)
        q=0.0; t=0.0
        for p in procs:
            out,err=p.communicate()
            if p.returncode != 0:
                raise SystemExit(f"{name} child failed rc={p.returncode}\n{out}\n{err}")
            m=re.search(r"MULTIPROC01_PROCESS\|N=(\d+)\|SECONDS=([^|]+)\|QSUM=([^|]+)\|TSUM=(.+)",out)
            if not m:
                raise SystemExit(f"{name} missing child row: {out}")
            q += float(m.group(3))
            t += float(m.group(4))
        t1=time.perf_counter()
        times.append(t1-t0)
        qsums.append(q); tsums.append(t)
    rows[name]={
        "seconds":statistics.median(times),
        "qsum":statistics.median(qsums),
        "tsum":statistics.median(tsums),
        "nproc":nproc,
        "workers":workers,
    }

q0=rows["1x4"]["qsum"]; t0=rows["1x4"]["tsum"]
q_tol=max(1e-15,abs(q0)*1e-12)
t_tol=max(1e-15,abs(t0)*1e-12)
for name,row in rows.items():
    if abs(row["qsum"]-q0)>q_tol or abs(row["tsum"]-t0)>t_tol:
        raise SystemExit(
            f"semantic aggregate mismatch {name}: dq={row['qsum']-q0} dt={row['tsum']-t0}")

base=rows["1x4"]["seconds"]
best=None
for name,_,_,_ in configs:
    row=rows[name]
    rel=base/row["seconds"]
    throughput=total_n/row["seconds"]
    delta=(base-row["seconds"])/base
    if delta>=0.05:
        cls="PROCESS_WIN" if name!="1x4" else "BASELINE"
    elif delta<=-0.05:
        cls="THREAD_WIN" if name!="1x4" else "BASELINE"
    else:
        cls="EQUIVALENT" if name!="1x4" else "BASELINE"
    print(
        f"MULTIPROC01_SUMMARY|CONFIG={name}|PROCESSES={row['nproc']}|WORKERS_PER_PROCESS={row['workers']}|"
        f"LOGICAL_CPUS={logical}|SECONDS={row['seconds']:.12f}|RELATIVE_TO_1X4={rel:.6f}|"
        f"THROUGHPUT_COL_S={throughput:.3f}|CLASS={cls}|QSUM={row['qsum']:.17e}|TSUM={row['tsum']:.17e}")
    if best is None or row["seconds"]<best[1]:
        best=(name,row["seconds"])
print(f"MULTIPROC01_DECISION|BEST_CONFIG={best[0]}|BEST_SECONDS={best[1]:.12f}")
print("FPE_MULTIPROC01=PASS")
PY

python3 "$BUILD/orchestrate.py" "$BUILD" "$ROUNDS" "$TOTAL_N" "$LOGICAL_CPUS"

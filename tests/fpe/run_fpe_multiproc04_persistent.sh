#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-multiproc04-${GITHUB_RUN_ID:-local}-$$"
TOTAL_N="${MULTIPROC04_N:-10000}"
ROUNDS="${MULTIPROC04_ROUNDS:-7}"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "FPE_MULTIPROC04_FAIL $*" >&2; exit 1; }

if (( TOTAL_N <= 0 || TOTAL_N % 4 != 0 )); then
  fail "MULTIPROC04_N must be positive and divisible by 4"
fi

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
  integer, parameter :: MULTIPROC04_WORKERS={workers}
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
s=s.replace("    value%initial_time=0.0_real64\n",
            "    value%initial_time=0.0_real64\n    value%groundwater_parallel_workers=MULTIPROC04_WORKERS\n",1)
s=s.replace("      value%tiles(i)%tile_id=TILE_ID(i); value%tiles(i)%ledger_id=LEDGER_ID(i)\n",
            "      value%tiles(i)%tile_id=880200_int64+int(i,int64); value%tiles(i)%ledger_id=980200_int64+int(i,int64)\n",1)
out.write_text(s)
PY
}

cat > "$BUILD/worker.py" <<'PY'
import ctypes, os, sys, time
from pathlib import Path

lib=ctypes.CDLL(str(Path(os.environ["MULTIPROC04_LIB"]).resolve()))
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

# Warm once, retain accepted origin.
if trial(handle.value,n,heads,flux) != 0:
    raise SystemExit("warm trial")
if tangent(handle.value,n,tan) != 0:
    raise SystemExit("warm tangent")
if discard(handle.value) != 0:
    raise SystemExit("warm discard")

print(f"READY|N={n}", flush=True)

q0=t0=None
for raw in sys.stdin:
    cmd=raw.strip()
    if cmd=="RUN":
        a=time.perf_counter()
        if trial(handle.value,n,heads,flux) != 0:
            raise SystemExit("trial")
        b=time.perf_counter()
        if tangent(handle.value,n,tan) != 0:
            raise SystemExit("tangent")
        q=sum(float(flux[i]) for i in range(n))
        t=sum(float(tan[i]) for i in range(n))
        if q0 is None:
            q0,t0=q,t
        elif q!=q0 or t!=t0:
            raise SystemExit("non-deterministic output")
        if discard(handle.value) != 0:
            raise SystemExit("discard")
        print(f"DONE|SECONDS={b-a:.12f}|QSUM={q:.17e}|TSUM={t:.17e}", flush=True)
    elif cmd=="STOP":
        if abort(handle.value) != 0:
            raise SystemExit("abort")
        if close() != 0:
            raise SystemExit("close")
        print("STOPPED", flush=True)
        break
    else:
        raise SystemExit(f"unknown command {cmd}")
PY

build_variant() {
  local tag="$1"
  local n="$2"
  local workers="$3"
  local fixture="$BUILD/fixture_$tag.f90"
  local out="$BUILD/o_$tag"
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
  gfortran -shared -fopenmp -O2 "${objects[@]}" -o "$out/libmultiproc04.so" || fail "link $tag"
}

build_variant "1x4" "$TOTAL_N" 4
build_variant "2x2" "$((TOTAL_N/2))" 2
build_variant "4x1" "$((TOTAL_N/4))" 1

python3 - "$BUILD" "$TOTAL_N" "$ROUNDS" <<'PY'
import os, re, statistics, subprocess, sys, time
from pathlib import Path

build=Path(sys.argv[1]); total_n=int(sys.argv[2]); rounds=int(sys.argv[3])
configs=[
    ("1x4",1,4,build/"o_1x4/libmultiproc04.so"),
    ("2x2",2,2,build/"o_2x2/libmultiproc04.so"),
    ("4x1",4,1,build/"o_4x1/libmultiproc04.so"),
]
rows={}
for name,nproc,workers,lib in configs:
    procs=[]
    setup0=time.perf_counter()
    for _ in range(nproc):
        env=os.environ.copy()
        env["MULTIPROC04_LIB"]=str(lib)
        env["OMP_DYNAMIC"]="FALSE"
        env["OMP_NUM_THREADS"]=str(workers)
        p=subprocess.Popen(
            [sys.executable,str(build/"worker.py")],
            stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,
            text=True,bufsize=1,env=env)
        procs.append(p)
    for p in procs:
        line=p.stdout.readline().strip()
        if not line.startswith("READY|"):
            err=p.stderr.read()
            raise SystemExit(f"{name} failed before READY: {line}\n{err}")
    setup1=time.perf_counter()

    walls=[]; child_max=[]; qs=[]; ts=[]
    for rep in range(rounds):
        a=time.perf_counter()
        for p in procs:
            p.stdin.write("RUN\n"); p.stdin.flush()
        child=[]
        q=0.0; t=0.0
        for p in procs:
            line=p.stdout.readline().strip()
            m=re.match(r"DONE\|SECONDS=([^|]+)\|QSUM=([^|]+)\|TSUM=(.+)",line)
            if not m:
                err=p.stderr.read()
                raise SystemExit(f"{name} bad DONE: {line}\n{err}")
            child.append(float(m.group(1)))
            q += float(m.group(2)); t += float(m.group(3))
        b=time.perf_counter()
        walls.append(b-a); child_max.append(max(child)); qs.append(q); ts.append(t)

    for p in procs:
        p.stdin.write("STOP\n"); p.stdin.flush()
    for p in procs:
        line=p.stdout.readline().strip()
        if line!="STOPPED":
            raise SystemExit(f"{name} missing STOPPED: {line}")
        p.wait(timeout=30)
        if p.returncode!=0:
            raise SystemExit(f"{name} child rc={p.returncode}: {p.stderr.read()}")

    rows[name]={
        "setup":setup1-setup0,
        "wall":statistics.median(walls),
        "child":statistics.median(child_max),
        "q":statistics.median(qs),
        "t":statistics.median(ts),
        "nproc":nproc,
        "workers":workers,
    }

q0=rows["1x4"]["q"]; t0=rows["1x4"]["t"]
q_tol=max(1e-15,abs(q0)*1e-12)
t_tol=max(1e-15,abs(t0)*1e-12)
for name,row in rows.items():
    if abs(row["q"]-q0)>q_tol or abs(row["t"]-t0)>t_tol:
        raise SystemExit(f"semantic mismatch {name}")

base=rows["1x4"]["wall"]
for name,_,_,_ in configs:
    row=rows[name]
    rel=base/row["wall"]
    throughput=total_n/row["wall"]
    gain=(base-row["wall"])/base
    print(
        f"MULTIPROC04_SUMMARY|N={total_n}|CONFIG={name}|SETUP_SECONDS={row['setup']:.12f}|"
        f"PERSISTENT_WALL_SECONDS={row['wall']:.12f}|CHILD_MAX_SECONDS={row['child']:.12f}|"
        f"RELATIVE_TO_1X4={rel:.6f}|GAIN={gain:.6f}|THROUGHPUT_COL_S={throughput:.3f}|"
        f"QSUM={row['q']:.17e}|TSUM={row['t']:.17e}")

best=min(rows.items(),key=lambda kv:kv[1]["wall"])[0]
r2=base/rows["2x2"]["wall"]; r4=base/rows["4x1"]["wall"]
if total_n in (10000,40000):
    if r2>=1.10 or r4>=1.10:
        decision="PERSISTENT_PROCESS_WIN"
    elif 0.95<=r2<=1.05 and 0.95<=r4<=1.05:
        decision="PERSISTENT_EQUIVALENT"
    else:
        decision="MIXED"
else:
    decision="CHARACTERIZATION"
print(f"MULTIPROC04_DECISION|N={total_n}|BEST_CONFIG={best}|REL2X2={r2:.6f}|REL4X1={r4:.6f}|DECISION={decision}")
print("FPE_MULTIPROC04=PASS")
PY

#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-multi04-p1c-${GITHUB_RUN_ID:-local}-$$"
N="${MULTI04_P1C_N:-1000}"
NREP="${MULTI04_P1C_REPS:-5}"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "FPE_MULTI04_P1C_FAIL $*" >&2; exit 1; }

cat > "$BUILD/probe.py" <<'PY'
import ctypes, os, statistics, sys, time
from pathlib import Path

lib=ctypes.CDLL(str(Path(os.environ["MULTI04_LIB"]).resolve()))
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
if nc.value <= 0 or nt.value != nc.value:
    raise SystemExit(f"unexpected counts cells={nc.value} tiles={nt.value}")
if capture(handle.value) != 0:
    raise SystemExit("capture origins")

n=nc.value
heads=(ctypes.c_double*n)(*([href1.value]*n))
flux=(ctypes.c_double*n)()
tan=(ctypes.c_double*n)()

# One unmeasured warm-up, then return to the same accepted origin.
if trial(handle.value,n,heads,flux) != 0:
    raise SystemExit("warm trial")
if tangent(handle.value,n,tan) != 0:
    raise SystemExit("warm tangent")
if discard(handle.value) != 0:
    raise SystemExit("warm discard")

times=[]
qsum=None; tsum=None
reps=int(os.environ.get("MULTI04_P1C_REPS","5"))
for rep in range(reps):
    t0=time.perf_counter()
    rc=trial(handle.value,n,heads,flux)
    t1=time.perf_counter()
    if rc != 0:
        raise SystemExit(f"trial rep={rep} status={rc}")
    if tangent(handle.value,n,tan) != 0:
        raise SystemExit(f"tangent rep={rep}")
    qs=sum(float(flux[i]) for i in range(n))
    ts=sum(float(tan[i]) for i in range(n))
    if qsum is None:
        qsum,tsum=qs,ts
    elif qs != qsum or ts != tsum:
        raise SystemExit("non-deterministic repeated output")
    times.append(t1-t0)
    if discard(handle.value) != 0:
        raise SystemExit(f"discard rep={rep}")

if abort(handle.value) != 0:
    raise SystemExit("abort")
if close() != 0:
    raise SystemExit("close")
med=statistics.median(times)
print(f"MULTI04_P1C|N={n}|SECONDS={med:.12f}|QSUM={qsum:.17e}|TSUM={tsum:.17e}")
print("FPE_MULTI04_P1C_VARIANT=PASS")
PY

for workers in 1 2 4; do
  fixture="$BUILD/fixture_w${workers}.f90"
  python3 - "$fixture" "$N" "$workers" <<'PY'
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
  integer, parameter :: MULTI04_WORKERS={workers}
  integer(int64), parameter :: GW_SERVICE_ID=880501_int64
"""
if old not in s: raise SystemExit("constant seam missing")
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
"    value%initial_time=0.0_real64\n    value%groundwater_parallel_workers=MULTI04_WORKERS\n",1)
s=s.replace(
"      value%tiles(i)%tile_id=TILE_ID(i); value%tiles(i)%ledger_id=LEDGER_ID(i)\n",
"      value%tiles(i)%tile_id=880200_int64+int(i,int64); value%tiles(i)%ledger_id=980200_int64+int(i,int64)\n",1)

out.write_text(s)
PY

  OUT="$BUILD/o${workers}"
  mkdir -p "$OUT"
  mapfile -t MODULE_SRC < <(python3 - "$fixture" <<'PY'
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
    gfortran "${COMMON[@]}" -O2 -J "$OUT" -I "$OUT" -c "$source" -o "$obj" || fail "compile w=$workers $source"
    objects+=("$obj")
  done
  gfortran -shared -fopenmp -O2 "${objects[@]}" -o "$OUT/libmulti04.so" || fail "link w=$workers"
  MULTI04_LIB="$OUT/libmulti04.so" MULTI04_P1C_REPS="$NREP" python3 "$BUILD/probe.py" | tee "$BUILD/w${workers}.txt"
done

python3 - "$BUILD/w1.txt" "$BUILD/w2.txt" "$BUILD/w4.txt" <<'PY'
import re,sys
rows={}
for w,p in zip((1,2,4),sys.argv[1:]):
    txt=open(p).read()
    m=re.search(r'^MULTI04_P1C\|N=(\d+)\|SECONDS=([^|]+)\|QSUM=([^|]+)\|TSUM=(.+)$',txt,re.M)
    if not m: raise SystemExit(f"missing row workers={w}")
    rows[w]=(int(m.group(1)),float(m.group(2)),float(m.group(3)),float(m.group(4)))
n=rows[1][0]
if any(v[0]!=n for v in rows.values()): raise SystemExit("population mismatch")
q0,t0=rows[1][2],rows[1][3]
for w in (2,4):
    if rows[w][2]!=q0 or rows[w][3]!=t0:
        raise SystemExit(f"semantic checksum drift workers={w}")
s2=rows[1][1]/rows[2][1]
s4=rows[1][1]/rows[4][1]
print(f"MULTI04_P1C_SUMMARY|N={n}|W1_SECONDS={rows[1][1]:.12f}|W2_SECONDS={rows[2][1]:.12f}|W4_SECONDS={rows[4][1]:.12f}|SPEEDUP2={s2:.6f}|SPEEDUP4={s4:.6f}|QSUM={q0:.17e}|TSUM={t0:.17e}")
if s2 < 1.5: raise SystemExit(f"2-worker frozen speed gate failed: {s2}")
if s4 < 2.2: raise SystemExit(f"4-worker frozen speed gate failed: {s4}")
print("FPE_MULTI04_P1C_APPLICATION_CONTEXT_SCALING=PASS")
PY

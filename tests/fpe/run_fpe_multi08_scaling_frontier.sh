#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

ARTIFACT_DIR="${1:?frozen BRO artifact directory required}"
OUTDIR="${MULTI08_OUTDIR:-$ROOT/multi08-results}"
POPS="${MULTI08_POPULATIONS:-256 1024 4096 16384}"
WORKERS="${MULTI08_WORKERS:-1 2 4 8 16 24 32 48}"
REPS="${MULTI08_REPS:-5}"
mkdir -p "$OUTDIR"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-multi08-$$"
PROFILE="$BUILD/profile"
mkdir -p "$BUILD" "$PROFILE"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "F_PE_MULTI08_FAIL $*" >&2; exit 1; }

python3 tests/fpe/prepare_fpe_multi06_profile8016.py --repo-root "$ROOT" --artifact-dir "$ARTIFACT_DIR" --work-dir "$PROFILE"
python3 tests/fpe/materialize_fpe_multi06_headcalc_stubs.py --source tests/fsi/fsi04_real_headcalc_stubs.f90 --geometry-json "$PROFILE/geometry.json" --output "$BUILD/stub.f90"

# Materialize a research-only pool. Production source remains byte-untouched.
python3 - "$ROOT/src/runtime/mod_fmr_parallel_worker_pool.f90" "$BUILD/mod_fmr_parallel_worker_pool.f90" <<'PY'
from pathlib import Path
import sys
src=Path(sys.argv[1]).read_text()
old="if ((worker_count /= 2 .and. worker_count /= 4) .or. batch_size <= 0 .or. t1 <= t0 .or. &"
new="if (worker_count < 2 .or. batch_size <= 0 .or. t1 <= t0 .or. &"
if src.count(old)!=1:
    raise SystemExit("F_PE_MULTI08_FAIL research admission seam")
Path(sys.argv[2]).write_text(src.replace(old,new,1))
PY

cp tests/rom/compile_f_rom0_fortran_closure.py "$BUILD/compile.py"
python3 - "$BUILD/compile.py" "$BUILD/mod_fmr_parallel_worker_pool.f90" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); pool=Path(sys.argv[2]).resolve()
s=p.read_text()
s=s.replace('if not name.startswith(("iso_", "ieee_")):', 'if not name.startswith(("iso_", "ieee_", "omp_")):')
# Replace the production provider with the research materialization.
needle='candidates=sorted(list((root/"src").rglob("*.f90")) + list((root/"src").rglob("*.F90")))'
repl=needle+'\n    candidates=[p for p in candidates if p.name!="mod_fmr_parallel_worker_pool.f90"]+[pathlib.Path(r"'+str(pool)+'")]'
if needle not in s: raise SystemExit("F_PE_MULTI08_FAIL compiler provider seam")
p.write_text(s.replace(needle,repl,1))
PY

{
  echo "timestamp_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "git_head=$(git rev-parse HEAD)"
  echo "uname=$(uname -a)"
  echo "compiler=$(gfortran --version | head -1)"
  echo "logical_cpus=$(getconf _NPROCESSORS_ONLN 2>/dev/null || true)"
  command -v lscpu >/dev/null && lscpu || true
  echo "OMP_PROC_BIND=${OMP_PROC_BIND:-spread}"
  echo "OMP_PLACES=${OMP_PLACES:-cores}"
  echo "populations=$POPS"
  echo "workers=$WORKERS"
  echo "reps=$REPS"
} > "$OUTDIR/host.txt"

export OMP_DYNAMIC=FALSE
export OMP_PROC_BIND="${OMP_PROC_BIND:-spread}"
export OMP_PLACES="${OMP_PLACES:-cores}"
logical="$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1)"
export OMP_THREAD_LIMIT="${OMP_THREAD_LIMIT:-$logical}"

echo "population,workers,rep,seconds,completed,committed,retries,mass_fail,max_simultaneous,aggregate_mass_residual" > "$OUTDIR/results.csv"

for n in $POPS; do
  target="$BUILD/test_n${n}.f90"
  sed "s/__MULTI08_NCOL__/$n/g" tests/fpe/test_fpe_multi08_scaling_frontier.template.f90 > "$target"
  buildn="$BUILD/o$n"
  python3 "$BUILD/compile.py" --root "$ROOT" --stub "$BUILD/stub.f90" --target "$target" --external-source src/legacy/b1_10_port/headcalc.f90 --build "$buildn" --opt 2

  for w in $WORKERS; do
    if [ "$w" -gt "$OMP_THREAD_LIMIT" ]; then
      echo "MULTI08_SKIP|population=$n|workers=$w|reason=THREAD_LIMIT"
      continue
    fi
    # Warm-up on fresh process/state.
    (cd "$PROFILE" && "$buildn/rom0_test" "$w") > "$BUILD/warm.txt"
    grep -Fq 'F_PE_MULTI06=PASS' "$BUILD/warm.txt" || fail "warm n=$n w=$w"
    for rep in $(seq 1 "$REPS"); do
      raw="$BUILD/n${n}_w${w}_r${rep}.txt"
      tfile="$BUILD/time.txt"
      /usr/bin/time -f '%e' -o "$tfile" sh -c 'cd "$1" && "$2" "$3"' sh "$PROFILE" "$buildn/rom0_test" "$w" > "$raw"
      grep -Fq 'F_PE_MULTI06=PASS' "$raw" || fail "run n=$n w=$w rep=$rep"
      summary="$(grep '^MULTI06_SUMMARY|' "$raw")"
      python3 - "$n" "$w" "$rep" "$(cat "$tfile")" "$summary" >> "$OUTDIR/results.csv" <<'PY'
import sys
n,w,rep,sec,summary=sys.argv[1:]
d={}
for p in summary.split("|")[1:]:
    k,v=p.split("=",1); d[k]=v
print(",".join([n,w,rep,sec,d["completed"],d["committed"],d["retries"],d["mass_fail"],d["max_simultaneous"],d["aggregate_mass_residual"]]))
PY
    done
  done
done

python3 - "$OUTDIR/results.csv" "$OUTDIR/summary.csv" <<'PY'
import csv,statistics,sys
src,dst=sys.argv[1:]
rows=list(csv.DictReader(open(src)))
groups={}
for r in rows:
    groups.setdefault((int(r["population"]),int(r["workers"])),[]).append(r)
with open(dst,"w",newline="") as f:
    fields=["population","workers","median_seconds","min_seconds","max_seconds","speedup","efficiency","throughput_columns_s","retries","mass_fail","max_simultaneous"]
    w=csv.DictWriter(f,fieldnames=fields); w.writeheader()
    med={}
    for k,rs in groups.items(): med[k]=statistics.median(float(x["seconds"]) for x in rs)
    for (n,nw),rs in sorted(groups.items()):
        base=med.get((n,1)); m=med[(n,nw)]
        if base is None: raise SystemExit(f"missing worker1 population {n}")
        retries={x["retries"] for x in rs}; mass={x["mass_fail"] for x in rs}
        completed={x["completed"] for x in rs}; committed={x["committed"] for x in rs}
        if len(retries)!=1 or len(mass)!=1 or len(completed)!=1 or len(committed)!=1 or int(next(iter(mass)))!=0 or int(next(iter(completed)))!=n or int(next(iter(committed)))!=n:
            raise SystemExit(f"semantic drift population={n} workers={nw}")
        w.writerow(dict(population=n,workers=nw,median_seconds=f"{m:.9f}",min_seconds=f"{min(float(x['seconds']) for x in rs):.9f}",max_seconds=f"{max(float(x['seconds']) for x in rs):.9f}",speedup=f"{base/m:.6f}",efficiency=f"{base/m/nw:.6f}",throughput_columns_s=f"{n/m:.3f}",retries=next(iter(retries)),mass_fail=next(iter(mass)),max_simultaneous=max(int(x["max_simultaneous"]) for x in rs)))
print("F_PE_MULTI08_SUMMARY=PASS")
PY

echo "F_PE_MULTI08_RUN=PASS"

#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

ARTIFACT_DIR="${1:?frozen BRO artifact directory required}"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-multi06b-${GITHUB_RUN_ID:-local}"
POP="$BUILD/population"
mkdir -p "$BUILD" "$POP"
trap 'rm -rf "$BUILD"' EXIT

fail(){
  echo "F_PE_MULTI06B_FAIL $*" >&2
  exit 1
}

python3 tests/fpe/prepare_fpe_multi06b_population.py   --repo-root "$ROOT"   --artifact-dir "$ARTIFACT_DIR"   --out "$POP" | tee "$BUILD/prep.txt"
grep -Fq 'F_PE_MULTI06B_PREP=PASS' "$BUILD/prep.txt" || fail "population prep"

cp tests/rom/compile_f_rom0_fortran_closure.py "$BUILD/compile_multi06b.py"
python3 - "$BUILD/compile_multi06b.py" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1])
s=p.read_text()
old='if not name.startswith(("iso_", "ieee_")):'
new='if not name.startswith(("iso_", "ieee_", "omp_")):'
if old not in s:
    raise SystemExit("F_PE_MULTI06B_FAIL compiler intrinsic seam")
p.write_text(s.replace(old,new,1))
PY

python3 - "$POP/manifest.json" <<'PY' > "$BUILD/profiles.txt"
import json,sys
for row in json.load(open(sys.argv[1],encoding="utf-8")):
    print(int(row["profile_id"]),int(row["columns"]))
PY

while read -r pid ncol; do
  PDIR="$POP/p$pid"
  OUT="$BUILD/p$pid"
  mkdir -p "$OUT"

  python3 tests/fpe/materialize_fpe_multi06b_headcalc_stubs.py     --source tests/fsi/fsi04_real_headcalc_stubs.f90     --geometry-json "$PDIR/geometry.json"     --output "$OUT/stub.f90" | tee "$OUT/stub.txt"
  grep -Fq 'F_PE_MULTI06B_STUB=PASS' "$OUT/stub.txt" || fail "stub $pid"

  python3 "$BUILD/compile_multi06b.py"     --root "$ROOT"     --stub "$OUT/stub.f90"     --target tests/fpe/test_fpe_multi06b_population_profile.f90     --external-source src/legacy/b1_10_port/headcalc.f90     --build "$OUT/build" --opt 2
  cp "$OUT/build/rom0_test" "$OUT/rom0_test"
done < "$BUILD/profiles.txt"

export OMP_DYNAMIC=FALSE
export OMP_THREAD_LIMIT=4
export OMP_PROC_BIND=spread
export OMP_PLACES=cores

for workers in 1 2 4; do
  : > "$BUILD/w${workers}.summaries"
  : > "$BUILD/w${workers}.columns"
  start_ns="$(date +%s%N)"

  while read -r pid ncol; do
    PDIR="$POP/p$pid"
    OUT="$BUILD/p$pid"
    (
      cd "$PDIR"
      "$OUT/rom0_test" "$workers" "$ncol" "$pid"
    ) | tee "$BUILD/w${workers}_p${pid}.txt"

    grep -Fq 'F_PE_MULTI06B_PROFILE=PASS' "$BUILD/w${workers}_p${pid}.txt" || fail "workers=$workers profile=$pid"
    grep '^MULTI06B_SUMMARY|' "$BUILD/w${workers}_p${pid}.txt" >> "$BUILD/w${workers}.summaries"
    grep '^MULTI06B_COLUMN|' "$BUILD/w${workers}_p${pid}.txt"       | sed -E 's/\|workers=[0-9]+//'       >> "$BUILD/w${workers}.columns"
  done < "$BUILD/profiles.txt"

  end_ns="$(date +%s%N)"
  python3 - "$BUILD/w${workers}.summaries" "$workers" "$start_ns" "$end_ns" <<'PY'
import sys
path,workers,start_ns,end_ns=sys.argv[1],int(sys.argv[2]),int(sys.argv[3]),int(sys.argv[4])
agg={k:0 for k in ("count","completed","committed","retries","mass_fail","rejected","aggregate_retries")}
maxsim=0
profiles=0
for line in open(path,encoding="utf-8"):
    if not line.startswith("MULTI06B_SUMMARY|"): continue
    profiles+=1
    d={}
    for part in line.strip().split("|")[1:]:
        k,v=part.split("=",1); d[k]=v
    for k in agg: agg[k]+=int(d[k])
    maxsim=max(maxsim,int(d["max_simultaneous"]))
if profiles!=4: raise SystemExit(f"F_PE_MULTI06B_FAIL profile summaries={profiles}")
sec=(end_ns-start_ns)/1e9
throughput=agg["count"]/sec
print("MULTI06B_ARM|workers=%d|seconds=%.9f|throughput=%.3f|count=%d|completed=%d|committed=%d|retries=%d|mass_fail=%d|rejected=%d|aggregate_retries=%d|max_simultaneous=%d" %
      (workers,sec,throughput,agg["count"],agg["completed"],agg["committed"],agg["retries"],
       agg["mass_fail"],agg["rejected"],agg["aggregate_retries"],maxsim))
PY
done

diff -u "$BUILD/w1.columns" "$BUILD/w2.columns"
diff -u "$BUILD/w1.columns" "$BUILD/w4.columns"
echo "F_PE_MULTI06B_A1_COLUMN_IDENTITY=PASS"

python3 - "$BUILD" <<'PY'
import re,sys
from pathlib import Path
root=Path(sys.argv[1])
rows={}
for w in (1,2,4):
    # MULTI06B_ARM is printed to stdout; reconstruct from summaries + a timing sidecar is unavailable.
    # Read combined workflow capture generated below is not possible here, so recompute deterministic aggregates only.
    agg={k:0 for k in ("count","completed","committed","retries","mass_fail","rejected","aggregate_retries")}
    maxsim=0
    for line in (root/f"w{w}.summaries").read_text().splitlines():
        d={}
        for part in line.split("|")[1:]:
            k,v=part.split("=",1); d[k]=v
        for k in agg: agg[k]+=int(d[k])
        maxsim=max(maxsim,int(d["max_simultaneous"]))
    rows[w]=(agg,maxsim)

expected={"count":1024,"completed":1024,"committed":1024,"retries":1522,"mass_fail":0,"rejected":0,"aggregate_retries":1522}
for w,(agg,maxsim) in rows.items():
    if agg!=expected:
        raise SystemExit(f"F_PE_MULTI06B_FAIL frozen population mismatch workers={w} got={agg}")
    if w>1 and maxsim<2:
        raise SystemExit(f"F_PE_MULTI06B_FAIL no concurrency workers={w}")
if rows[1][0]!=rows[2][0] or rows[1][0]!=rows[4][0]:
    raise SystemExit("F_PE_MULTI06B_FAIL worker aggregate drift")
print("MULTI06B_DETERMINISTIC|count=1024|completed=1024|committed=1024|retries=1522|mass_fail=0|rejected=0")
print("F_PE_MULTI06B_A2_FROZEN_POPULATION=PASS")
PY

python3 - <<'PY'
import subprocess
base=subprocess.check_output(["git","merge-base","HEAD","origin/integration/f-ci-canonical"],text=True).strip()
src=[p for p in subprocess.check_output(["git","diff","--name-only",base+"..HEAD","--","src"],text=True).splitlines() if p]
if src:
    raise SystemExit("F_PE_MULTI06B_SOURCE_SCOPE_FAIL="+repr(src))
print("F_PE_MULTI06B_A3_SOURCE_SCOPE=PASS")
PY

echo "F_PE_MULTI06B_RUN=PASS"

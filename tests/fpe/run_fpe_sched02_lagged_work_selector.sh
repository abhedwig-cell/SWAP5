#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

ARTIFACT_DIR="${1:?frozen BRO artifact directory required}"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-sched02-${GITHUB_RUN_ID:-local}"
POP="$BUILD/profiles"
mkdir -p "$BUILD" "$POP"
trap 'rm -rf "$BUILD"' EXIT

fail(){
  echo "F_PE_SCHED02_FAIL $*" >&2
  exit 1
}

python3 tests/fpe/prepare_fpe_sched02_profiles.py   --repo-root "$ROOT"   --artifact-dir "$ARTIFACT_DIR"   --out "$POP" | tee "$BUILD/prep.txt"
grep -Fq 'F_PE_SCHED02_PREP=PASS' "$BUILD/prep.txt" || fail "profile prep"

cp tests/rom/compile_f_rom0_fortran_closure.py "$BUILD/compile_sched02.py"
python3 - "$BUILD/compile_sched02.py" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1])
s=p.read_text()
old='if not name.startswith(("iso_", "ieee_")):'
new='if not name.startswith(("iso_", "ieee_", "omp_")):'
if old not in s:
    raise SystemExit("F_PE_SCHED02_FAIL compiler intrinsic seam")
p.write_text(s.replace(old,new,1))
PY

python3 - "$POP/manifest.json" <<'PY' > "$BUILD/profiles.txt"
import json,sys
for row in json.load(open(sys.argv[1],encoding="utf-8")):
    print(int(row["profile_id"]), int(row["columns"]))
PY

while read -r pid ncols; do
  PDIR="$POP/p$pid"
  OUT="$BUILD/p$pid"
  mkdir -p "$OUT"
  python3 tests/fpe/materialize_fpe_sched02_headcalc_stubs.py     --source tests/fsi/fsi04_real_headcalc_stubs.f90     --geometry-json "$PDIR/geometry.json"     --output "$OUT/stub.f90" | tee "$OUT/stub.txt"
  grep -Fq 'F_PE_SCHED02_STUB=PASS' "$OUT/stub.txt" || fail "stub $pid"

  python3 "$BUILD/compile_sched02.py"     --root "$ROOT"     --stub "$OUT/stub.f90"     --target tests/fpe/test_fpe_sched02_lagged_work_selector.f90     --external-source src/legacy/b1_10_port/headcalc.f90     --build "$OUT/build" --opt 2
  cp "$OUT/build/rom0_test" "$OUT/rom0_test"
done < "$BUILD/profiles.txt"

export OMP_DYNAMIC=FALSE
export OMP_THREAD_LIMIT=4
export OMP_PROC_BIND=spread
export OMP_PLACES=cores

: > "$BUILD/all.txt"
while read -r pid ncols; do
  for workers in 1 2 4; do
    for rep in 1 2 3 4 5; do
      (
        cd "$POP/p$pid"
        "$BUILD/p$pid/rom0_test" "$pid" "$ncols" "$workers"
      ) | tee "$BUILD/p${pid}_w${workers}_r${rep}.txt"
      grep -Fq 'F_PE_SCHED02=PASS' "$BUILD/p${pid}_w${workers}_r${rep}.txt" || fail "pid=$pid w=$workers r=$rep"
      grep '^SCHED02_SUMMARY|' "$BUILD/p${pid}_w${workers}_r${rep}.txt"         | sed "s/^/SCHED02_OBS|REP=$rep|/" >> "$BUILD/all.txt"
    done
  done
done < "$BUILD/profiles.txt"

python3 - "$BUILD/all.txt" <<'PY'
import math,statistics,sys

rows=[]
for line in open(sys.argv[1],encoding="utf-8"):
    if not line.startswith("SCHED02_OBS|"): continue
    d={}
    for part in line.strip().split("|")[1:]:
        if "=" not in part:
            continue
        k,v=part.split("=",1); d[k]=v
    rows.append(d)

if len(rows)!=5*3*5:
    raise SystemExit(f"F_PE_SCHED02_FAIL obs={len(rows)}")

profiles=sorted({int(r["profile"]) for r in rows})
summary=[]
for pid in profiles:
    pr=[r for r in rows if int(r["profile"])==pid]
    nvals={int(r["n"]) for r in pr}
    if len(nvals)!=1: raise SystemExit(f"F_PE_SCHED02_FAIL N drift pid={pid}")
    n=next(iter(nvals))
    lag={int(r["lagged_work"]) for r in pr}
    if len(lag)!=1: raise SystemExit(f"F_PE_SCHED02_FAIL lagged work drift pid={pid}")
    lagged=next(iter(lag))
    retry_ref=None
    med={}
    for w in (1,2,4):
        wr=[r for r in pr if int(r["workers"])==w]
        if len(wr)!=5: raise SystemExit(f"F_PE_SCHED02_FAIL reps pid={pid} w={w}")
        if {int(x["a_completed"]) for x in wr}!={n} or {int(x["a_committed"]) for x in wr}!={n}:
            raise SystemExit(f"F_PE_SCHED02_FAIL A completion pid={pid} w={w}")
        if {int(x["b_completed"]) for x in wr}!={n} or {int(x["b_committed"]) for x in wr}!={n}:
            raise SystemExit(f"F_PE_SCHED02_FAIL B completion pid={pid} w={w}")
        if {int(x["b_mass_fail"]) for x in wr}!={0} or {int(x["b_rejected"]) for x in wr}!={0}:
            raise SystemExit(f"F_PE_SCHED02_FAIL B acceptance pid={pid} w={w}")
        if {x["b_mass_complete"] for x in wr}!={"T"}:
            raise SystemExit(f"F_PE_SCHED02_FAIL B mass pid={pid} w={w}")
        retries={int(x["b_retries"]) for x in wr}
        if len(retries)!=1: raise SystemExit(f"F_PE_SCHED02_FAIL B retry repeat drift pid={pid} w={w}")
        rv=next(iter(retries))
        if retry_ref is None: retry_ref=rv
        elif rv!=retry_ref: raise SystemExit(f"F_PE_SCHED02_FAIL B retry worker drift pid={pid}")
        if w>1 and max(int(x["max_simultaneous"]) for x in wr)<2:
            raise SystemExit(f"F_PE_SCHED02_FAIL concurrency pid={pid} w={w}")
        med[w]=statistics.median(float(x["seconds"]) for x in wr)
        print(f"SCHED02_MEDIAN|profile={pid}|n={n}|lagged_work={lagged}|workers={w}|seconds={med[w]:.9f}|b_retries={rv}")
    best=min(med.values())
    winner=min(w for w in (1,2,4) if med[w] <= 1.05*best)
    summary.append((lagged,pid,n,winner,best))
    print(f"SCHED02_WINNER|profile={pid}|n={n}|lagged_work={lagged}|worker={winner}|best_seconds={best:.9f}")

summary.sort()
print("SCHED02_ORDER|"+";".join(f"{lag}:{pid}:{winner}" for lag,pid,n,winner,best in summary))
winners=[x[3] for x in summary]
if any(b<a for a,b in zip(winners,winners[1:])):
    print("SCHED02_SELECTOR=NONE|reason=NON_MONOTONE_LAGGED_WORK")
    print("F_PE_SCHED02_A1_CORRECTNESS=PASS")
    print("F_PE_SCHED02_RUN=PASS")
    raise SystemExit(0)

trans=[]
for left,right in zip(summary,summary[1:]):
    if left[3]!=right[3]:
        a,b=left[0],right[0]
        t=int(round(math.sqrt(a*b)))
        trans.append((left[3],right[3],t,a,b))
parts=["SCHED02_SELECTOR"]
for wa,wb,t,a,b in trans:
    parts.append(f"T{wa}{wb}={t}")
if not trans:
    parts.append("NONE")
print("|".join(parts))
print("F_PE_SCHED02_A1_CORRECTNESS=PASS")
print("F_PE_SCHED02_A2_MONOTONE=PASS")
print("F_PE_SCHED02_RUN=PASS")
PY

python3 - <<'PY'
import subprocess
base=subprocess.check_output(
    ["git","merge-base","HEAD","origin/integration/f-ci-canonical"],text=True
).strip()
prod=[
    p for p in subprocess.check_output(
        ["git","diff","--name-only",base+"..HEAD","--","src"],text=True
    ).splitlines() if p
]
if prod:
    raise SystemExit("F_PE_SCHED02_SOURCE_SCOPE_FAIL="+repr(prod))
print("F_PE_SCHED02_A3_SOURCE_SCOPE=PASS")
PY

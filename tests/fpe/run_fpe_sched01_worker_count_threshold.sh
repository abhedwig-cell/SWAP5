#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

ARTIFACT_DIR="${1:?frozen BRO artifact directory required}"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-sched01-${GITHUB_RUN_ID:-local}"
PROFILE="$BUILD/profile"
mkdir -p "$BUILD" "$PROFILE"
trap 'rm -rf "$BUILD"' EXIT

fail(){
  echo "F_PE_SCHED01_FAIL $*" >&2
  exit 1
}

python3 tests/fpe/prepare_fpe_multi06_profile8016.py \
  --repo-root "$ROOT" \
  --artifact-dir "$ARTIFACT_DIR" \
  --work-dir "$PROFILE" | tee "$BUILD/prep.txt"
grep -Fq 'F_PE_MULTI06_PREP=PASS' "$BUILD/prep.txt" || fail "profile prep"

python3 tests/fpe/materialize_fpe_multi06_headcalc_stubs.py \
  --source tests/fsi/fsi04_real_headcalc_stubs.f90 \
  --geometry-json "$PROFILE/geometry.json" \
  --output "$BUILD/stub.f90" | tee "$BUILD/stub.txt"
grep -Fq 'F_PE_MULTI06_STUB=PASS' "$BUILD/stub.txt" || fail "stub"

cp tests/rom/compile_f_rom0_fortran_closure.py "$BUILD/compile_sched01.py"
python3 - "$BUILD/compile_sched01.py" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1])
s=p.read_text()
old='if not name.startswith(("iso_", "ieee_")):'
new='if not name.startswith(("iso_", "ieee_", "omp_")):'
if old not in s:
    raise SystemExit("F_PE_SCHED01_FAIL compiler intrinsic seam")
p.write_text(s.replace(old,new,1))
PY

for n in 256 1024 4096 16384; do
  OUT="$BUILD/n$n"
  mkdir -p "$OUT"
  python3 tests/fpe/materialize_fpe_sched01_fixture.py \
    --source tests/fpe/test_fpe_multi06_mode7_generated_worker_pool.f90 \
    --output "$OUT/test.f90" \
    --columns "$n" | tee "$OUT/materialize.txt"
  grep -Fq 'F_PE_SCHED01_FIXTURE=PASS' "$OUT/materialize.txt" || fail "fixture N=$n"

  python3 "$BUILD/compile_sched01.py" \
    --root "$ROOT" \
    --stub "$BUILD/stub.f90" \
    --target "$OUT/test.f90" \
    --external-source src/legacy/b1_10_port/headcalc.f90 \
    --build "$OUT/build" --opt 2
  cp "$OUT/build/rom0_test" "$OUT/rom0_test"
done

export OMP_DYNAMIC=FALSE
export OMP_THREAD_LIMIT=4
export OMP_PROC_BIND=spread
export OMP_PLACES=cores

: > "$BUILD/all.txt"
for n in 256 1024 4096 16384; do
  for workers in 1 2 4; do
    for rep in 1 2 3 4 5; do
      (
        cd "$PROFILE"
        "$BUILD/n$n/rom0_test" "$workers"
      ) | tee "$BUILD/n${n}_w${workers}_r${rep}.txt"
      grep -Fq 'F_PE_SCHED01=PASS' "$BUILD/n${n}_w${workers}_r${rep}.txt" || fail "N=$n W=$workers R=$rep"
      grep '^SCHED01_SUMMARY|' "$BUILD/n${n}_w${workers}_r${rep}.txt" \
        | sed "s/^/SCHED01_OBS|N=$n|REP=$rep|/" >> "$BUILD/all.txt"
    done
  done
done

python3 - "$BUILD/all.txt" <<'PY'
import math,statistics,sys

rows=[]
for line in open(sys.argv[1],encoding="utf-8"):
    if not line.startswith("SCHED01_OBS|"): continue
    d={}
    for part in line.strip().split("|")[1:]:
        k,v=part.split("=",1); d[k]=v
    rows.append(d)

expected=4*3*5
if len(rows)!=expected:
    raise SystemExit(f"F_PE_SCHED01_FAIL obs={len(rows)} expected={expected}")

by={}
for r in rows:
    key=(int(r["N"]),int(r["workers"]))
    by.setdefault(key,[]).append(r)

winner={}
med={}
for n in (256,1024,4096,16384):
    retry_ref=None
    for w in (1,2,4):
        rr=by[(n,w)]
        if len(rr)!=5:
            raise SystemExit(f"F_PE_SCHED01_FAIL repeats N={n} W={w}")
        completed={int(x["completed"]) for x in rr}
        committed={int(x["committed"]) for x in rr}
        retries={int(x["retries"]) for x in rr}
        massfail={int(x["mass_fail"]) for x in rr}
        rejected={int(x["diagnostic_rejected"]) for x in rr}
        masscomplete={x["aggregate_mass_complete"] for x in rr}
        if completed!={n} or committed!={n} or massfail!={0} or rejected!={0} or masscomplete!={"T"}:
            raise SystemExit(f"F_PE_SCHED01_FAIL correctness N={n} W={w}")
        if len(retries)!=1:
            raise SystemExit(f"F_PE_SCHED01_FAIL retry repeat drift N={n} W={w}")
        rv=next(iter(retries))
        if retry_ref is None: retry_ref=rv
        elif rv!=retry_ref:
            raise SystemExit(f"F_PE_SCHED01_FAIL retry worker drift N={n}: {retry_ref} vs {rv}")
        times=[float(x["seconds"]) for x in rr]
        med[(n,w)]=statistics.median(times)
        maxsim=max(int(x["max_simultaneous"]) for x in rr)
        if w>1 and maxsim<2:
            raise SystemExit(f"F_PE_SCHED01_FAIL concurrency N={n} W={w}")
        print(f"SCHED01_MEDIAN|N={n}|workers={w}|seconds={med[(n,w)]:.9f}|retries={rv}|max_simultaneous={maxsim}")

    best=min(med[(n,w)] for w in (1,2,4))
    admissible=[w for w in (1,2,4) if med[(n,w)] <= 1.05*best]
    winner[n]=min(admissible)
    print(f"SCHED01_WINNER|N={n}|worker={winner[n]}|best_seconds={best:.9f}")

seq=[winner[n] for n in (256,1024,4096,16384)]
if any(b<a for a,b in zip(seq,seq[1:])):
    print("SCHED01_THRESHOLD_MODEL=NONE|reason=NON_MONOTONE")
    print("F_PE_SCHED01_RUN=PASS")
    raise SystemExit(0)

def midpoint_log2(a,b):
    return int(round(math.sqrt(a*b)))

transitions=[]
sizes=(256,1024,4096,16384)
for a,b in zip(sizes,sizes[1:]):
    if winner[a]!=winner[b]:
        transitions.append((winner[a],winner[b],midpoint_log2(a,b)))

parts=["SCHED01_THRESHOLD_MODEL"]
for wa,wb,t in transitions:
    parts.append(f"T{wa}{wb}={t}")
if not transitions:
    parts.append("NONE")
print("|".join(parts))
print("F_PE_SCHED01_A1_CORRECTNESS=PASS")
print("F_PE_SCHED01_A2_MONOTONE=PASS")
print("F_PE_SCHED01_RUN=PASS")
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
    raise SystemExit("F_PE_SCHED01_SOURCE_SCOPE_FAIL="+repr(prod))
print("F_PE_SCHED01_A3_SOURCE_SCOPE=PASS")
PY

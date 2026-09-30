#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

ARTIFACT_DIR="${1:?frozen BRO artifact directory required}"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-multi07-${GITHUB_RUN_ID:-local}"
POP="$BUILD/population"
mkdir -p "$BUILD" "$POP"
trap 'rm -rf "$BUILD"' EXIT

fail(){
  echo "F_PE_MULTI07_FAIL $*" >&2
  exit 1
}

python3 tests/fpe/prepare_fpe_multi07_population.py   --repo-root "$ROOT"   --artifact-dir "$ARTIFACT_DIR"   --out "$POP" | tee "$BUILD/prep.txt"
grep -Fq 'F_PE_MULTI07_PREP=PASS' "$BUILD/prep.txt" || fail "population prep"

python3 - "$POP/manifest.json" <<'PY' > "$BUILD/profiles.txt"
import json,sys
for row in json.load(open(sys.argv[1],encoding="utf-8")):
    print(int(row["profile_id"]), int(row["columns"]))
PY

cp tests/rom/compile_f_rom0_fortran_closure.py "$BUILD/compile_multi07.py"
python3 - "$BUILD/compile_multi07.py" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1])
s=p.read_text()
old='if not name.startswith(("iso_", "ieee_")):'
new='if not name.startswith(("iso_", "ieee_", "omp_")):'
if old not in s:
    raise SystemExit("F_PE_MULTI07_FAIL compiler intrinsic seam")
p.write_text(s.replace(old,new,1))
PY

while read -r pid ncols; do
  PDIR="$POP/p$pid"
  OUT="$BUILD/p$pid"
  mkdir -p "$OUT"

  python3 tests/fpe/materialize_fpe_multi07_headcalc_stubs.py     --source tests/fsi/fsi04_real_headcalc_stubs.f90     --geometry-json "$PDIR/geometry.json"     --output "$OUT/stub.f90" | tee "$OUT/stub.txt"
  grep -Fq 'F_PE_MULTI07_STUB=PASS' "$OUT/stub.txt" || fail "stub $pid"

  python3 tests/fpe/materialize_fpe_multi07_batch_fixture.py     --source tests/fpe/test_fpe_multi06_mode7_generated_worker_pool.f90     --output "$OUT/test.f90"     --columns "$ncols"     --profile-id "$pid" | tee "$OUT/fixture.txt"
  grep -Fq 'F_PE_MULTI07_FIXTURE=PASS' "$OUT/fixture.txt" || fail "fixture $pid"

  python3 "$BUILD/compile_multi07.py"     --root "$ROOT"     --stub "$OUT/stub.f90"     --target "$OUT/test.f90"     --external-source src/legacy/b1_10_port/headcalc.f90     --build "$OUT/build" --opt 2

  cp "$OUT/build/rom0_test" "$OUT/rom0_test"
done < "$BUILD/profiles.txt"

export OMP_DYNAMIC=FALSE
export OMP_THREAD_LIMIT=4
export OMP_PROC_BIND=spread
export OMP_PLACES=cores

for workers in 1 2 4; do
  : > "$BUILD/w${workers}.summaries"
  while read -r pid ncols; do
    PDIR="$POP/p$pid"
    EXE="$BUILD/p$pid/rom0_test"
    (
      cd "$PDIR"
      "$EXE" "$workers"
    ) | tee "$BUILD/w${workers}.p${pid}.txt"
    grep -Fq 'F_PE_MULTI07=PASS' "$BUILD/w${workers}.p${pid}.txt" || fail "profile=$pid workers=$workers"
    grep '^MULTI07_SUMMARY|' "$BUILD/w${workers}.p${pid}.txt" >> "$BUILD/w${workers}.summaries"
  done < "$BUILD/profiles.txt"
done

python3 - "$BUILD/w1.summaries" "$BUILD/w2.summaries" "$BUILD/w4.summaries" <<'PY'
import sys
rows={}
for workers,path in zip((1,2,4),sys.argv[1:]):
    by_profile={}
    for line in open(path,encoding="utf-8"):
        if not line.startswith("MULTI07_SUMMARY|"):
            continue
        d={}
        for part in line.strip().split("|")[1:]:
            k,v=part.split("=",1)
            d[k]=v
        by_profile[int(d["profile"])]=d
    if len(by_profile)!=4:
        raise SystemExit(f"F_PE_MULTI07_FAIL profile rows workers={workers}: {len(by_profile)}")
    rows[workers]=by_profile

profiles=sorted(rows[1])
for pid in profiles:
    for key in ("completed","committed","retries","mass_fail","diagnostic_rejected",
                "aggregate_retries","aggregate_mass_complete","aggregate_mass_residual"):
        vals=[rows[w][pid][key] for w in (1,2,4)]
        if len(set(vals))!=1:
            raise SystemExit(f"F_PE_MULTI07_FAIL profile drift pid={pid} key={key} vals={vals}")

totals={}
for w in (1,2,4):
    totals[w]={
        "completed":sum(int(rows[w][p]["completed"]) for p in profiles),
        "committed":sum(int(rows[w][p]["committed"]) for p in profiles),
        "retries":sum(int(rows[w][p]["retries"]) for p in profiles),
        "mass_fail":sum(int(rows[w][p]["mass_fail"]) for p in profiles),
        "rejected":sum(int(rows[w][p]["diagnostic_rejected"]) for p in profiles),
        "seconds":sum(float(rows[w][p]["seconds"]) for p in profiles),
        "maxsim":max(int(rows[w][p]["max_simultaneous"]) for p in profiles),
    }
    t=totals[w]
    if t["completed"]!=1024 or t["committed"]!=1024:
        raise SystemExit(f"F_PE_MULTI07_FAIL completion workers={w}: {t}")
    if t["retries"]!=1522:
        raise SystemExit(f"F_PE_MULTI07_FAIL frozen retry authority workers={w}: {t['retries']}")
    if t["mass_fail"]!=0 or t["rejected"]!=0:
        raise SystemExit(f"F_PE_MULTI07_FAIL mass/rejection workers={w}: {t}")
    if w>1 and t["maxsim"]<2:
        raise SystemExit(f"F_PE_MULTI07_FAIL no physical concurrency workers={w}")

base=totals[1]["seconds"]
for w in (1,2,4):
    t=totals[w]
    speed=base/t["seconds"]
    throughput=1024.0/t["seconds"]
    print("MULTI07_TOTAL|workers=%d|completed=%d|committed=%d|retries=%d|mass_fail=%d|rejected=%d|seconds=%.9f|throughput=%.3f|speedup=%.6f|max_simultaneous=%d" %
          (w,t["completed"],t["committed"],t["retries"],t["mass_fail"],t["rejected"],
           t["seconds"],throughput,speed,t["maxsim"]))

print("F_PE_MULTI07_A1_FROZEN_POPULATION_IDENTITY=PASS")
print("F_PE_MULTI07_A2_WORKER_IDENTITY=PASS")
print("F_PE_MULTI07_A3_CONCURRENCY=PASS")
print("F_PE_MULTI07_RUN=PASS")
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
    raise SystemExit("F_PE_MULTI07_SOURCE_SCOPE_FAIL="+repr(prod))
print("F_PE_MULTI07_A4_SOURCE_SCOPE=PASS")
PY

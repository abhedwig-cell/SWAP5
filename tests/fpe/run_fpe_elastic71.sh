#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

ARTIFACT_DIR="${1:?frozen BRO artifact directory required}"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-elastic71-${GITHUB_RUN_ID:-local}"
POP="$BUILD/population"
mkdir -p "$BUILD" "$POP"
trap 'rm -rf "$BUILD"' EXIT

fail(){
  echo "F_PE_ELASTIC71_FAIL $*" >&2
  exit 1
}

python3 tests/fpe/prepare_fpe_elastic71_population.py   --repo-root "$ROOT"   --artifact-dir "$ARTIFACT_DIR"   --out "$POP" | tee "$BUILD/prep.txt"
grep -Fq 'F_PE_ELASTIC71_PREP=PASS' "$BUILD/prep.txt" || fail "population prep"

python3 - "$POP/manifest.json" <<'PY' > "$BUILD/profile_ids.txt"
import json,sys
for row in json.load(open(sys.argv[1],encoding="utf-8")):
    print(int(row["profile_id"]))
PY

while read -r pid; do
  PDIR="$POP/p$pid"
  OUT="$BUILD/p$pid"
  mkdir -p "$OUT"

  python3 tests/fpe/materialize_fpe_elastic71_headcalc_stubs.py     --source tests/fsi/fsi04_real_headcalc_stubs.f90     --geometry-json "$PDIR/geometry.json"     --output "$OUT/stub.f90" | tee "$OUT/stub.txt"
  grep -Fq 'F_PE_ELASTIC71_STUB=PASS' "$OUT/stub.txt" || fail "stub $pid"

  python3 tests/rom/compile_f_rom0_fortran_closure.py     --root "$ROOT"     --stub "$OUT/stub.f90"     --target tests/fpe/test_fpe_elastic71_population_profile.f90     --external-source src/legacy/b1_10_port/headcalc.f90     --build "$OUT/build" --opt 2

  cp "$OUT/build/rom0_test" "$OUT/rom0_test"
done < "$BUILD/profile_ids.txt"

python3 tests/fpe/run_fpe_elastic71_population.py   --manifest "$POP/manifest.json"   --build "$BUILD"   --population-root "$POP" | tee "$BUILD/result.txt"

grep -Fq 'F_PE_ELASTIC71=PASS' "$BUILD/result.txt" || fail "population result"

python3 - "$BUILD/result.txt" <<'PY'
import re,sys
text=open(sys.argv[1],encoding="utf-8").read()
rows=[]
for line in text.splitlines():
    if not line.startswith("ELASTIC71_ARM|"): continue
    d={}
    for p in line.split("|")[1:]:
        k,v=p.split("=",1); d[k]=v
    rows.append(d)
if len(rows)!=6:
    raise SystemExit(f"F_PE_ELASTIC71_FAIL rows={len(rows)}")
by={(float(r["budget"]),int(r["workers"])):r for r in rows}
for b in (0.01,0.20):
    base=float(by[(b,1)]["seconds"])
    for w in (1,2,4):
        r=by[(b,w)]
        speed=base/float(r["seconds"])
        print(f"ELASTIC71_SCALING|budget={b:.2f}|workers={w}|speedup={speed:.6f}|throughput={float(r['throughput']):.3f}")
for w in (1,2,4):
    ratio=float(by[(0.20,w)]["seconds"])/float(by[(0.01,w)]["seconds"])
    print(f"ELASTIC71_POLICY_RATIO|workers={w}|ratio={ratio:.6f}")
print("F_PE_ELASTIC71_SUMMARY=PASS")
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
    raise SystemExit("F_PE_ELASTIC71_SOURCE_SCOPE_FAIL="+repr(prod))
print("F_PE_ELASTIC71_SOURCE_SCOPE=PASS")
PY

echo "F_PE_ELASTIC71_RUN=PASS"

#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

ARTIFACT_DIR="${1:?frozen BRO artifact directory required}"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-pzg23-05-${GITHUB_RUN_ID:-local}"
PROFILE="$BUILD/profile"
mkdir -p "$BUILD" "$PROFILE"
trap 'rm -rf "$BUILD"' EXIT

fail(){
  echo "F_PE_PZG23_05_FAIL $*" >&2
  exit 1
}

python3 tests/fpe/prepare_fpe_pzg23_05.py   --repo-root "$ROOT"   --artifact-dir "$ARTIFACT_DIR"   --out "$PROFILE" | tee "$BUILD/prep.txt"
grep -Fq 'F_PE_PZG23_05_PREP=PASS' "$BUILD/prep.txt" || fail "profile prep"

python3 tests/fpe/materialize_fpe_multi06_headcalc_stubs.py   --source tests/fsi/fsi04_real_headcalc_stubs.f90   --geometry-json "$PROFILE/geometry.json"   --output "$BUILD/stub.f90" | tee "$BUILD/stub.txt"
grep -Fq 'F_PE_MULTI06_STUB=PASS' "$BUILD/stub.txt" || fail "stub"

python3 tests/fpe/materialize_fpe_pzg23_05_headcalc.py   --source src/legacy/b1_10_port/headcalc.f90   --output "$BUILD/headcalc_pzg23_05.f90" | tee "$BUILD/materialize_headcalc.txt"
grep -Fq 'F_PE_PZG23_05_HEADCALC_MATERIALIZE=PASS' "$BUILD/materialize_headcalc.txt" || fail "headcalc materialize"

python3 tests/rom/compile_f_rom0_fortran_closure.py   --root "$ROOT"   --stub "$BUILD/stub.f90"   --target tests/fpe/test_fpe_pzg23_05_backtracking_instrumentation.f90   --external-source "$BUILD/headcalc_pzg23_05.f90"   --build "$BUILD/o2" --opt 2

(
  cd "$PROFILE"
  "$BUILD/o2/rom0_test"
) | tee "$BUILD/result.txt"

grep -Fq 'F_PE_PZG23_05=PASS' "$BUILD/result.txt" || fail "fixture result"

python3 - "$BUILD/result.txt" <<'PY'
import math
import sys

segments={}
current=None
summaries={}

def parse(line):
    d={}
    for p in line.strip().split("|")[1:]:
        if "=" in p:
            k,v=p.split("=",1)
            d[k]=v
    return d

for line in open(sys.argv[1],encoding="utf-8"):
    line=line.strip()
    if line.startswith("PZG23_05_BEGIN_B|"):
        d=parse(line)
        current=int(d["origin"])
        segments[current]=[]
    elif line.startswith("PZG23_05_END_B|"):
        d=parse(line)
        origin=int(d["origin"])
        if current!=origin:
            raise SystemExit("F_PE_PZG23_05_FAIL segment mismatch")
        current=None
    elif line.startswith("PZG23_05_HEADCALC|") and current is not None:
        segments[current].append(parse(line))
    elif line.startswith("PZG23_05|"):
        d=parse(line)
        summaries[int(d["origin"])]=d

if set(segments)!={10,11} or set(summaries)!={10,11}:
    raise SystemExit("F_PE_PZG23_05_FAIL missing origins")

target_factor=1.0/(3.0**11)

for origin in (10,11):
    rows=segments[origin]
    if not rows:
        raise SystemExit(f"F_PE_PZG23_05_FAIL no headcalc rows origin={origin}")
    failed=[r for r in rows if r["outcome"] in ("REQUEST_DT_REDUCTION","NO_CONVERGENCE")]
    converged=[r for r in rows if r["outcome"]=="CONVERGED"]
    if not failed:
        raise SystemExit(f"F_PE_PZG23_05_FAIL no failed headcalc origin={origin}")
    if summaries[origin]["completed"]!="F":
        raise SystemExit(f"F_PE_PZG23_05_FAIL blocker not reproduced origin={origin}")

    full_exhaust=sum(int(r["exhaustions"]) for r in failed)
    terminal_exhaust=sum(r["last_iter_exhausted"]=="T" for r in failed)
    terminal_non_descent=sum(
        r["last_iter_exhausted"]=="T" and float(r["last_iter_best_ratio"])>=1.0
        for r in failed
    )
    terminal_descent=sum(
        r["last_iter_exhausted"]=="T" and float(r["last_iter_best_ratio"])<1.0
        for r in failed
    )
    min_terminal_ratio=min(float(r["last_iter_best_ratio"]) for r in failed)
    max_terminal_ratio=max(float(r["last_iter_best_ratio"]) for r in failed)
    min_terminal_factor=min(float(r["last_iter_min_factor"]) for r in failed)
    hit_full_depth=sum(
        r["last_iter_exhausted"]=="T" and float(r["last_iter_min_factor"]) <= target_factor*(1.0+1e-10)
        for r in failed
    )

    print(
        "PZG23_05_ORIGIN|origin=%d|headcalc_calls=%d|failed_calls=%d|converged_calls=%d|"
        "exhaustions=%d|terminal_exhaustions=%d|terminal_non_descent=%d|terminal_descent=%d|"
        "min_terminal_ratio=%.17e|max_terminal_ratio=%.17e|min_terminal_factor=%.17e|"
        "hit_full_depth=%d" %
        (origin,len(rows),len(failed),len(converged),full_exhaust,terminal_exhaust,
         terminal_non_descent,terminal_descent,min_terminal_ratio,max_terminal_ratio,
         min_terminal_factor,hit_full_depth)
    )

print("F_PE_PZG23_05_A1_INSTRUMENTATION=PASS")
print("F_PE_PZG23_05_RUN=PASS")
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
    raise SystemExit("F_PE_PZG23_05_SOURCE_SCOPE_FAIL="+repr(prod))
print("F_PE_PZG23_05_A2_SOURCE_SCOPE=PASS")
PY

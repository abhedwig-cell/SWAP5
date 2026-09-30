#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

ARTIFACT_DIR="${1:?frozen BRO artifact directory required}"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-pzg23-06-${GITHUB_RUN_ID:-local}"
PROFILE="$BUILD/profile"
mkdir -p "$BUILD" "$PROFILE"
trap 'rm -rf "$BUILD"' EXIT

fail(){
  echo "F_PE_PZG23_06_FAIL $*" >&2
  exit 1
}

python3 tests/fpe/prepare_fpe_pzg23_06.py   --repo-root "$ROOT"   --artifact-dir "$ARTIFACT_DIR"   --out "$PROFILE" | tee "$BUILD/prep.txt"
grep -Fq 'F_PE_PZG23_06_PREP=PASS' "$BUILD/prep.txt" || fail "profile prep"

python3 tests/fpe/materialize_fpe_multi06_headcalc_stubs.py   --source tests/fsi/fsi04_real_headcalc_stubs.f90   --geometry-json "$PROFILE/geometry.json"   --output "$BUILD/stub.f90" | tee "$BUILD/stub.txt"
grep -Fq 'F_PE_MULTI06_STUB=PASS' "$BUILD/stub.txt" || fail "stub"

python3 tests/fpe/materialize_fpe_pzg23_05_headcalc.py   --source src/legacy/b1_10_port/headcalc.f90   --output "$BUILD/headcalc_pzg23_05.f90" | tee "$BUILD/materialize05.txt"
grep -Fq 'F_PE_PZG23_05_HEADCALC_MATERIALIZE=PASS' "$BUILD/materialize05.txt" || fail "pzg23-05 materialize"

python3 tests/fpe/materialize_fpe_pzg23_06_criteria.py   --source "$BUILD/headcalc_pzg23_05.f90"   --output "$BUILD/headcalc_pzg23_06.f90" | tee "$BUILD/materialize06.txt"
grep -Fq 'F_PE_PZG23_06_HEADCALC_MATERIALIZE=PASS' "$BUILD/materialize06.txt" || fail "pzg23-06 materialize"

python3 tests/rom/compile_f_rom0_fortran_closure.py   --root "$ROOT"   --stub "$BUILD/stub.f90"   --target tests/fpe/test_fpe_pzg23_06_terminal_criterion_attribution.f90   --external-source "$BUILD/headcalc_pzg23_06.f90"   --build "$BUILD/o2" --opt 2

(
  cd "$PROFILE"
  "$BUILD/o2/rom0_test"
) | tee "$BUILD/result.txt"

grep -Fq 'F_PE_PZG23_06=PASS' "$BUILD/result.txt" || fail "fixture result"

python3 - "$BUILD/result.txt" <<'PY'
from __future__ import annotations
import statistics
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
    if line.startswith("PZG23_06_BEGIN_B|"):
        d=parse(line)
        current=int(d["origin"])
        segments[current]=[]
    elif line.startswith("PZG23_06_END_B|"):
        d=parse(line)
        origin=int(d["origin"])
        if current!=origin:
            raise SystemExit("F_PE_PZG23_06_FAIL segment mismatch")
        current=None
    elif line.startswith("PZG23_06_TERMINAL|") and current is not None:
        segments[current].append(parse(line))
    elif line.startswith("PZG23_06|"):
        d=parse(line)
        summaries[int(d["origin"])]=d

if set(segments)!={10,11} or set(summaries)!={10,11}:
    raise SystemExit("F_PE_PZG23_06_FAIL missing origins")

for origin in (10,11):
    rows=segments[origin]
    if not rows:
        raise SystemExit(f"F_PE_PZG23_06_FAIL no terminal rows origin={origin}")
    if summaries[origin]["completed"]!="F":
        raise SystemExit(f"F_PE_PZG23_06_FAIL blocker not reproduced origin={origin}")

    comp=[float(r["comp_ratio"]) for r in rows]
    total=[float(r["total_ratio"]) for r in rows]
    head=[float(r["head_ratio"]) for r in rows]
    pond=[float(r["pond_ratio"]) for r in rows if r["pond_applicable"]=="T"]

    comp_fail=sum(x>1.0 for x in comp)
    total_fail=sum(x>1.0 for x in total)
    head_fail=sum(x>1.0 for x in head)
    pond_fail=sum(x>1.0 for x in pond)

    dominant={"comp":0,"total":0,"head":0,"pond":0}
    for r in rows:
        candidates={
            "comp":float(r["comp_ratio"]),
            "total":float(r["total_ratio"]),
            "head":float(r["head_ratio"]),
        }
        if r["pond_applicable"]=="T":
            candidates["pond"]=float(r["pond_ratio"])
        mx=max(candidates.values())
        for k,v in candidates.items():
            if v==mx:
                dominant[k]+=1

    print(
        "PZG23_06_ORIGIN|origin=%d|terminal_calls=%d|"
        "comp_fail=%d|total_fail=%d|head_fail=%d|pond_fail=%d|"
        "comp_median=%.17e|comp_max=%.17e|"
        "total_median=%.17e|total_max=%.17e|"
        "head_median=%.17e|head_max=%.17e|"
        "pond_max=%.17e|dominant_comp=%d|dominant_total=%d|dominant_head=%d|dominant_pond=%d" %
        (
            origin,len(rows),comp_fail,total_fail,head_fail,pond_fail,
            statistics.median(comp),max(comp),
            statistics.median(total),max(total),
            statistics.median(head),max(head),
            max(pond) if pond else 0.0,
            dominant["comp"],dominant["total"],dominant["head"],dominant["pond"],
        )
    )

print("F_PE_PZG23_06_A1_CRITERION_CENSUS=PASS")
print("F_PE_PZG23_06_RUN=PASS")
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
    raise SystemExit("F_PE_PZG23_06_SOURCE_SCOPE_FAIL="+repr(prod))
print("F_PE_PZG23_06_A2_SOURCE_SCOPE=PASS")
PY

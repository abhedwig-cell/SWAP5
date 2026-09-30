#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

ARTIFACT_DIR="${1:?frozen BRO artifact directory required}"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-pzg23-01-${GITHUB_RUN_ID:-local}"
PROFILE="$BUILD/profile"
mkdir -p "$BUILD" "$PROFILE"
trap 'rm -rf "$BUILD"' EXIT

fail(){
  echo "F_PE_PZG23_01_FAIL $*" >&2
  exit 1
}

python3 tests/fpe/prepare_fpe_pzg23_01.py   --repo-root "$ROOT"   --artifact-dir "$ARTIFACT_DIR"   --out "$PROFILE" | tee "$BUILD/prep.txt"
grep -Fq 'F_PE_PZG23_01_PREP=PASS' "$BUILD/prep.txt" || fail "profile prep"

python3 tests/fpe/materialize_fpe_multi06_headcalc_stubs.py   --source tests/fsi/fsi04_real_headcalc_stubs.f90   --geometry-json "$PROFILE/geometry.json"   --output "$BUILD/stub.f90" | tee "$BUILD/stub.txt"
grep -Fq 'F_PE_MULTI06_STUB=PASS' "$BUILD/stub.txt" || fail "stub"

cp tests/rom/compile_f_rom0_fortran_closure.py "$BUILD/compile_pzg23_01.py"
python3 - "$BUILD/compile_pzg23_01.py" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1])
s=p.read_text()
old='if not name.startswith(("iso_", "ieee_")):'
new='if not name.startswith(("iso_", "ieee_", "omp_")):'
if old not in s:
    raise SystemExit("F_PE_PZG23_01_FAIL compiler intrinsic seam")
p.write_text(s.replace(old,new,1))
PY

python3 "$BUILD/compile_pzg23_01.py"   --root "$ROOT"   --stub "$BUILD/stub.f90"   --target tests/fpe/test_fpe_pzg23_01_second_interval_attribution.f90   --external-source src/legacy/b1_10_port/headcalc.f90   --build "$BUILD/o2" --opt 2

(
  cd "$PROFILE"
  "$BUILD/o2/rom0_test"
) | tee "$BUILD/result.txt"

grep -Fq 'F_PE_PZG23_01=PASS' "$BUILD/result.txt" || fail "fixture result"

python3 - "$BUILD/result.txt" <<'PY'
import sys
rows_a=[]
rows_b=[]
fails=[]
for line in open(sys.argv[1],encoding="utf-8"):
    if line.startswith("PZG23_A|"):
        rows_a.append(line.strip())
    elif line.startswith("PZG23_B|"):
        rows_b.append(line.strip())
    elif line.startswith("PZG23_B_FAIL|"):
        fails.append(line.strip())

if len(rows_a)!=16 or len(rows_b)!=16:
    raise SystemExit(f"F_PE_PZG23_01_FAIL row counts A={len(rows_a)} B={len(rows_b)}")

def parse(line):
    d={}
    for p in line.split("|")[1:]:
        if "=" in p:
            k,v=p.split("=",1)
            d[k]=v
    return d

A=[parse(x) for x in rows_a]
B=[parse(x) for x in rows_b]

if any(x["completed"]!="T" or x["committed"]!="T" for x in A):
    raise SystemExit("F_PE_PZG23_01_FAIL interval A incomplete")
if not fails:
    raise SystemExit("F_PE_PZG23_01_FAIL blocker not reproduced")

fail_origins=sorted(int(parse(x)["origin"]) for x in fails)
solver_like=[]
mass_like=[]
for x in B:
    if x["completed"]=="T" and x["committed"]=="T":
        continue
    if x["mass_complete"]!="T":
        mass_like.append(int(x["origin"]))
    if int(x["nonlinear"])>0 or int(x["headcalc"])>0 or int(x["linear"])>0:
        solver_like.append(int(x["origin"]))

print("PZG23_01_FAIL_ORIGINS="+",".join(map(str,fail_origins)))
print("PZG23_01_CLASS|solver_like="+",".join(map(str,sorted(set(solver_like))))+
      "|mass_like="+",".join(map(str,sorted(set(mass_like)))))
print("F_PE_PZG23_01_A1_CENSUS=PASS")
print("F_PE_PZG23_01_RUN=PASS")
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
    raise SystemExit("F_PE_PZG23_01_SOURCE_SCOPE_FAIL="+repr(prod))
print("F_PE_PZG23_01_A2_SOURCE_SCOPE=PASS")
PY

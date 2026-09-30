#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

ARTIFACT_DIR="${1:?frozen BRO artifact directory required}"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-pzg23-03-${GITHUB_RUN_ID:-local}"
PROFILE="$BUILD/profile"
mkdir -p "$BUILD" "$PROFILE"
trap 'rm -rf "$BUILD"' EXIT

fail(){
  echo "F_PE_PZG23_03_FAIL $*" >&2
  exit 1
}

python3 tests/fpe/prepare_fpe_pzg23_03.py   --repo-root "$ROOT"   --artifact-dir "$ARTIFACT_DIR"   --out "$PROFILE" | tee "$BUILD/prep.txt"
grep -Fq 'F_PE_PZG23_03_PREP=PASS' "$BUILD/prep.txt" || fail "profile prep"

python3 tests/fpe/materialize_fpe_multi06_headcalc_stubs.py   --source tests/fsi/fsi04_real_headcalc_stubs.f90   --geometry-json "$PROFILE/geometry.json"   --output "$BUILD/stub.f90" | tee "$BUILD/stub.txt"
grep -Fq 'F_PE_MULTI06_STUB=PASS' "$BUILD/stub.txt" || fail "stub"

python3 tests/rom/compile_f_rom0_fortran_closure.py   --root "$ROOT"   --stub "$BUILD/stub.f90"   --target tests/fpe/test_fpe_pzg23_03_rejection_channel_attribution.f90   --external-source src/legacy/b1_10_port/headcalc.f90   --build "$BUILD/o2" --opt 2

(
  cd "$PROFILE"
  "$BUILD/o2/rom0_test"
) | tee "$BUILD/result.txt"

grep -Fq 'F_PE_PZG23_03=PASS' "$BUILD/result.txt" || fail "fixture result"

python3 - "$BUILD/result.txt" <<'PY'
import sys
rows=[]
for line in open(sys.argv[1],encoding="utf-8"):
    if not line.startswith("PZG23_03|"):
        continue
    d={}
    for p in line.strip().split("|")[1:]:
        if "=" in p:
            k,v=p.split("=",1)
            d[k]=v
    rows.append(d)

if len(rows)!=2:
    raise SystemExit(f"F_PE_PZG23_03_FAIL rows={len(rows)}")

for r in rows:
    if r["completed"]!="F":
        raise SystemExit("F_PE_PZG23_03_FAIL blocker not reproduced")
    if int(r["admission_rejections"])!=0 or int(r["checkpoint_rejections"])!=0:
        raise SystemExit("F_PE_PZG23_03_FAIL invalid diagnostic origin")

solver=sum(int(r["solver_rejections"]) for r in rows)
temporal=sum(int(r["temporal_rejections"]) for r in rows)
mass=sum(int(r["mass_rejections"]) for r in rows)

if solver>0 and mass==0:
    klass="SOLVER_REJECTION_DOMINANT"
elif temporal>0 and solver==0 and mass==0:
    klass="TEMPORAL_REJECTION_DOMINANT"
elif mass>0:
    klass="MASS_REJECTION_PRESENT"
else:
    klass="MIXED_OR_OTHER"

print(f"PZG23_03_TOTAL|solver_rejections={solver}|temporal_rejections={temporal}|mass_rejections={mass}")
print("PZG23_03_CLASS="+klass)
print("F_PE_PZG23_03_A1_CHANNEL_ATTRIBUTION=PASS")
print("F_PE_PZG23_03_RUN=PASS")
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
    raise SystemExit("F_PE_PZG23_03_SOURCE_SCOPE_FAIL="+repr(prod))
print("F_PE_PZG23_03_A2_SOURCE_SCOPE=PASS")
PY

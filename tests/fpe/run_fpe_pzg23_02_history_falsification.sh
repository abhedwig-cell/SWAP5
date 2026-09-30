#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

ARTIFACT_DIR="${1:?frozen BRO artifact directory required}"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-pzg23-02-${GITHUB_RUN_ID:-local}"
PROFILE="$BUILD/profile"
mkdir -p "$BUILD" "$PROFILE"
trap 'rm -rf "$BUILD"' EXIT

fail(){
  echo "F_PE_PZG23_02_FAIL $*" >&2
  exit 1
}

python3 tests/fpe/prepare_fpe_pzg23_02.py   --repo-root "$ROOT"   --artifact-dir "$ARTIFACT_DIR"   --out "$PROFILE" | tee "$BUILD/prep.txt"
grep -Fq 'F_PE_PZG23_02_PREP=PASS' "$BUILD/prep.txt" || fail "profile prep"

python3 tests/fpe/materialize_fpe_multi06_headcalc_stubs.py   --source tests/fsi/fsi04_real_headcalc_stubs.f90   --geometry-json "$PROFILE/geometry.json"   --output "$BUILD/stub.f90" | tee "$BUILD/stub.txt"
grep -Fq 'F_PE_MULTI06_STUB=PASS' "$BUILD/stub.txt" || fail "stub"

python3 tests/rom/compile_f_rom0_fortran_closure.py   --root "$ROOT"   --stub "$BUILD/stub.f90"   --target tests/fpe/test_fpe_pzg23_02_history_falsification.f90   --external-source src/legacy/b1_10_port/headcalc.f90   --build "$BUILD/o2" --opt 2

(
  cd "$PROFILE"
  "$BUILD/o2/rom0_test"
) | tee "$BUILD/result.txt"

grep -Fq 'F_PE_PZG23_02=PASS' "$BUILD/result.txt" || fail "fixture result"

python3 - "$BUILD/result.txt" <<'PY'
import sys
cases=[]
compares=[]
klass=None
for line in open(sys.argv[1],encoding="utf-8"):
    if line.startswith("PZG23_02_CASE|"):
        d={}
        for p in line.strip().split("|")[1:]:
            if "=" in p:
                k,v=p.split("=",1); d[k]=v
        cases.append(d)
    elif line.startswith("PZG23_02_COMPARE|"):
        d={}
        for p in line.strip().split("|")[1:]:
            if "=" in p:
                k,v=p.split("=",1); d[k]=v
        compares.append(d)
    elif line.startswith("PZG23_02_CLASS="):
        klass=line.strip().split("=",1)[1]

if len(cases)!=12:
    raise SystemExit(f"F_PE_PZG23_02_FAIL cases={len(cases)}")
if len(compares)!=2:
    raise SystemExit(f"F_PE_PZG23_02_FAIL compares={len(compares)}")
if klass not in {
    "ACCEPTED_HISTORY_CAUSAL",
    "PHYSICAL_STATE_OR_LOCAL_NONLINEAR_REGIME",
    "MIXED_HISTORY_SENSITIVITY",
}:
    raise SystemExit("F_PE_PZG23_02_FAIL missing class")

for origin in (10,11):
    b={int(x["arm"]):x for x in cases if x["interval"]=="B" and int(x["origin"])==origin}
    if set(b)!={1,2,3}:
        raise SystemExit(f"F_PE_PZG23_02_FAIL arms origin={origin}")
    if b[1]["completed"]!="F" or b[2]["completed"]!="F":
        raise SystemExit(f"F_PE_PZG23_02_FAIL baseline reproduction origin={origin}")
    # Same-history reconstruction must reproduce the original completion class.
    for key in ("completed","committed","kernel_status"):
        if b[1][key]!=b[2][key]:
            raise SystemExit(f"F_PE_PZG23_02_FAIL same-history drift origin={origin} key={key}")

print("F_PE_PZG23_02_A1_BASELINE_REPRODUCTION=PASS")
print("F_PE_PZG23_02_A2_SAME_HISTORY_RECONSTRUCTION=PASS")
print("F_PE_PZG23_02_CLASSIFICATION="+klass)
print("F_PE_PZG23_02_RUN=PASS")
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
    raise SystemExit("F_PE_PZG23_02_SOURCE_SCOPE_FAIL="+repr(prod))
print("F_PE_PZG23_02_A3_SOURCE_SCOPE=PASS")
PY

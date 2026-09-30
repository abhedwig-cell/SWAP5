#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

ARTIFACT_DIR="${1:?frozen BRO artifact directory required}"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-pzg23-04-${GITHUB_RUN_ID:-local}"
PROFILE="$BUILD/profile"
mkdir -p "$BUILD" "$PROFILE"
trap 'rm -rf "$BUILD"' EXIT

fail(){
  echo "F_PE_PZG23_04_FAIL $*" >&2
  exit 1
}

python3 tests/fpe/prepare_fpe_pzg23_04.py   --repo-root "$ROOT"   --artifact-dir "$ARTIFACT_DIR"   --out "$PROFILE" | tee "$BUILD/prep.txt"
grep -Fq 'F_PE_PZG23_04_PREP=PASS' "$BUILD/prep.txt" || fail "profile prep"

python3 tests/fpe/materialize_fpe_multi06_headcalc_stubs.py   --source tests/fsi/fsi04_real_headcalc_stubs.f90   --geometry-json "$PROFILE/geometry.json"   --output "$BUILD/stub.f90" | tee "$BUILD/stub.txt"
grep -Fq 'F_PE_MULTI06_STUB=PASS' "$BUILD/stub.txt" || fail "stub"

python3 tests/rom/compile_f_rom0_fortran_closure.py   --root "$ROOT"   --stub "$BUILD/stub.f90"   --target tests/fpe/test_fpe_pzg23_04_iteration_ceiling_falsification.f90   --external-source src/legacy/b1_10_port/headcalc.f90   --build "$BUILD/o2" --opt 2

(
  cd "$PROFILE"
  "$BUILD/o2/rom0_test"
) | tee "$BUILD/result.txt"

grep -Fq 'F_PE_PZG23_04=PASS' "$BUILD/result.txt" || fail "fixture result"

python3 - "$BUILD/result.txt" <<'PY'
import sys

rows=[]
klass=None
for line in open(sys.argv[1],encoding="utf-8"):
    if line.startswith("PZG23_04|"):
        d={}
        for p in line.strip().split("|")[1:]:
            if "=" in p:
                k,v=p.split("=",1)
                d[k]=v
        rows.append(d)
    elif line.startswith("PZG23_04_CLASS="):
        klass=line.strip().split("=",1)[1]

if len(rows)!=4:
    raise SystemExit(f"F_PE_PZG23_04_FAIL rows={len(rows)}")
if klass not in {
    "ITERATION_CEILING_CAUSAL",
    "ITERATION_CEILING_NOT_SUFFICIENT",
    "MIXED_ITERATION_CEILING_SENSITIVITY",
}:
    raise SystemExit("F_PE_PZG23_04_FAIL class")

for origin in (10,11):
    by={int(r["arm"]):r for r in rows if int(r["origin"])==origin}
    if set(by)!={1,2}:
        raise SystemExit(f"F_PE_PZG23_04_FAIL arms origin={origin}")
    if by[1]["completed"]!="F":
        raise SystemExit(f"F_PE_PZG23_04_FAIL baseline origin={origin}")
    if int(by[1]["mass_rejections"])!=0 or int(by[2]["mass_rejections"])!=0:
        raise SystemExit(f"F_PE_PZG23_04_FAIL unexpected mass rejection origin={origin}")

print("F_PE_PZG23_04_A1_BASELINE_REPRODUCTION=PASS")
print("F_PE_PZG23_04_CLASSIFICATION="+klass)
print("F_PE_PZG23_04_RUN=PASS")
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
    raise SystemExit("F_PE_PZG23_04_SOURCE_SCOPE_FAIL="+repr(prod))
print("F_PE_PZG23_04_A2_SOURCE_SCOPE=PASS")
PY

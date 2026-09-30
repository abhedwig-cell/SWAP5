#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

ARTIFACT_DIR="${1:?frozen BRO artifact directory required}"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-pzg23-01-${GITHUB_RUN_ID:-local}"
PROFILE="$BUILD/profile"
mkdir -p "$BUILD" "$PROFILE"
trap 'rm -rf "$BUILD"' EXIT

fail(){ echo "F_PE_PZG23_01_FAIL $*" >&2; exit 1; }

python3 tests/fpe/prepare_fpe_pzg23_01.py   --repo-root "$ROOT" --artifact-dir "$ARTIFACT_DIR" --out "$PROFILE" | tee "$BUILD/prep.txt"
grep -Fq 'F_PE_PZG23_01_PREP=PASS' "$BUILD/prep.txt" || fail "prep"

python3 tests/fpe/materialize_fpe_multi06_headcalc_stubs.py   --source tests/fsi/fsi04_real_headcalc_stubs.f90   --geometry-json "$PROFILE/geometry.json"   --output "$BUILD/stub.f90"

cp tests/rom/compile_f_rom0_fortran_closure.py "$BUILD/compile.py"
python3 - "$BUILD/compile.py" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text()
old='if not name.startswith(("iso_", "ieee_")):'
new='if not name.startswith(("iso_", "ieee_", "omp_")):'
if old not in s: raise SystemExit("F_PE_PZG23_01_FAIL compiler intrinsic seam")
p.write_text(s.replace(old,new,1))
PY

python3 "$BUILD/compile.py"   --root "$ROOT"   --stub "$BUILD/stub.f90"   --target tests/fpe/test_fpe_pzg23_01_second_interval_attribution.f90   --external-source src/legacy/b1_10_port/headcalc.f90   --build "$BUILD/o2" --opt 2

(
  cd "$PROFILE"
  "$BUILD/o2/rom0_test"
) | tee "$BUILD/result.txt"

grep -Fq 'F_PE_PZG23_01=PASS' "$BUILD/result.txt" || fail "fixture"
test "$(grep -c '^PZG23_A|' "$BUILD/result.txt")" -eq 16 || fail "A rows"
test "$(grep -c '^PZG23_B|' "$BUILD/result.txt")" -eq 16 || fail "B rows"

python3 - "$BUILD/result.txt" <<'PY'
import sys
rows=[]
for line in open(sys.argv[1],encoding="utf-8"):
    if not line.startswith("PZG23_B|"): continue
    d={}
    for p in line.strip().split("|")[1:]:
        if "=" in p:
            k,v=p.split("=",1); d[k]=v
    rows.append(d)
if len(rows)!=16:
    raise SystemExit(f"F_PE_PZG23_01_FAIL B rows={len(rows)}")
failed=[r for r in rows if r["completed"]!="T" or r["committed"]!="T"]
print("PZG23_FAILURE_COUNT="+str(len(failed)))
for r in failed:
    print("PZG23_FAILURE|origin={origin}|h0={h0}|delta={delta}|status={status}|attempts={attempts}|retries={retries}|accepted_substeps={accepted_substeps}|nonlinear={nonlinear}|internal_retries={internal_retries}|headcalc={headcalc}|jacobian={jacobian}|linear={linear}|backtracking={backtracking}|mass_complete={mass_complete}|mass_residual={mass_residual}".format(**r))
if not failed:
    raise SystemExit("F_PE_PZG23_01_FAIL blocker did not reproduce")
print("F_PE_PZG23_01_ATTRIBUTION=PASS")
PY

python3 - <<'PY'
import subprocess
base=subprocess.check_output(["git","merge-base","HEAD","origin/integration/f-ci-canonical"],text=True).strip()
src=[p for p in subprocess.check_output(["git","diff","--name-only",base+"..HEAD","--","src"],text=True).splitlines() if p]
if src: raise SystemExit("F_PE_PZG23_01_SOURCE_SCOPE_FAIL="+repr(src))
print("F_PE_PZG23_01_SOURCE_SCOPE=PASS")
PY

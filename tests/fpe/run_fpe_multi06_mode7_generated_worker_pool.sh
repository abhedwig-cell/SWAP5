#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

ARTIFACT_DIR="${1:?frozen BRO artifact directory required}"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-multi06-${GITHUB_RUN_ID:-local}"
PROFILE="$BUILD/profile"
mkdir -p "$BUILD" "$PROFILE"
trap 'rm -rf "$BUILD"' EXIT

fail(){
  echo "F_PE_MULTI06_FAIL $*" >&2
  exit 1
}

python3 tests/fpe/prepare_fpe_multi06_profile8016.py   --repo-root "$ROOT"   --artifact-dir "$ARTIFACT_DIR"   --work-dir "$PROFILE" | tee "$BUILD/prep.txt"
grep -Fq 'F_PE_MULTI06_PREP=PASS' "$BUILD/prep.txt" || fail "profile prep"

python3 tests/fpe/materialize_fpe_multi06_headcalc_stubs.py   --source tests/fsi/fsi04_real_headcalc_stubs.f90   --geometry-json "$PROFILE/geometry.json"   --output "$BUILD/stub.f90" | tee "$BUILD/stub.txt"
grep -Fq 'F_PE_MULTI06_STUB=PASS' "$BUILD/stub.txt" || fail "stub"

cp tests/rom/compile_f_rom0_fortran_closure.py "$BUILD/compile_multi06.py"
python3 - "$BUILD/compile_multi06.py" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1])
s=p.read_text()
old='if not name.startswith(("iso_", "ieee_")):'
new='if not name.startswith(("iso_", "ieee_", "omp_")):'
if old not in s:
    raise SystemExit("F_PE_MULTI06_FAIL compiler intrinsic seam")
p.write_text(s.replace(old,new,1))
PY
python3 "$BUILD/compile_multi06.py"   --root "$ROOT"   --stub "$BUILD/stub.f90"   --target tests/fpe/test_fpe_multi06_mode7_generated_worker_pool.f90   --external-source src/legacy/b1_10_port/headcalc.f90   --build "$BUILD/o2" --opt 2

export OMP_DYNAMIC=FALSE
export OMP_THREAD_LIMIT=4
export OMP_PROC_BIND=spread
export OMP_PLACES=cores

for workers in 1 2 4; do
  (
    cd "$PROFILE"
    "$BUILD/o2/rom0_test" "$workers"
  ) | tee "$BUILD/w${workers}.txt"
  grep -Fq 'F_PE_MULTI06=PASS' "$BUILD/w${workers}.txt" || fail "workers=$workers"
  grep '^MULTI06_COLUMN|' "$BUILD/w${workers}.txt"     | sed -E 's/\|workers=[0-9]+//'     > "$BUILD/w${workers}.columns"
  grep '^MULTI06_SUMMARY|' "$BUILD/w${workers}.txt" > "$BUILD/w${workers}.summary"
done

diff -u "$BUILD/w1.columns" "$BUILD/w2.columns"
diff -u "$BUILD/w1.columns" "$BUILD/w4.columns"
echo "F_PE_MULTI06_A1_COLUMN_IDENTITY=PASS"

python3 - "$BUILD/w1.summary" "$BUILD/w2.summary" "$BUILD/w4.summary" <<'PY'
import sys
rows={}
for w,p in zip((1,2,4),sys.argv[1:]):
    line=open(p,encoding="utf-8").read().strip()
    d={}
    for part in line.split("|")[1:]:
        k,v=part.split("=",1); d[k]=v
    rows[w]=d
for key in ("completed","committed","retries","mass_fail","diagnostic_rejected","aggregate_retries"):
    vals=[rows[w][key] for w in (1,2,4)]
    if len(set(vals))!=1:
        raise SystemExit(f"F_PE_MULTI06_FAIL summary drift {key}={vals}")
if int(rows[1]["completed"])!=256 or int(rows[1]["committed"])!=256:
    raise SystemExit("F_PE_MULTI06_FAIL incomplete serial authority")
if int(rows[1]["mass_fail"])!=0:
    raise SystemExit("F_PE_MULTI06_FAIL mass")
if rows[1]["aggregate_mass_complete"]!="T" or rows[2]["aggregate_mass_complete"]!="T" or rows[4]["aggregate_mass_complete"]!="T":
    raise SystemExit("F_PE_MULTI06_FAIL aggregate mass complete")
if int(rows[2]["max_simultaneous"])<2 or int(rows[4]["max_simultaneous"])<2:
    raise SystemExit("F_PE_MULTI06_FAIL no real concurrency")
print("MULTI06_IDENTITY|completed=%s|committed=%s|retries=%s|mass_fail=%s|maxsim2=%s|maxsim4=%s" %
      (rows[1]["completed"],rows[1]["committed"],rows[1]["retries"],rows[1]["mass_fail"],
       rows[2]["max_simultaneous"],rows[4]["max_simultaneous"]))
print("F_PE_MULTI06_A2_AGGREGATE_IDENTITY=PASS")
PY

git diff --check -- src/runtime/mod_fmr_parallel_worker_pool.f90   tests/fpe/test_fpe_multi06_mode7_generated_worker_pool.f90   tests/fpe/prepare_fpe_multi06_profile8016.py   tests/fpe/materialize_fpe_multi06_headcalc_stubs.py

python3 - <<'PY'
import subprocess
base=subprocess.check_output(
    ["git","merge-base","HEAD","origin/integration/f-ci-canonical"],text=True
).strip()
src=[
    p for p in subprocess.check_output(
        ["git","diff","--name-only",base+"..HEAD","--","src"],text=True
    ).splitlines() if p
]
expected=["src/runtime/mod_fmr_parallel_worker_pool.f90"]
if src!=expected:
    raise SystemExit("F_PE_MULTI06_SOURCE_SCOPE_FAIL="+repr(src))
print("F_PE_MULTI06_A3_SOURCE_SCOPE=PASS")
PY

echo "F_PE_MULTI06_RUN=PASS"

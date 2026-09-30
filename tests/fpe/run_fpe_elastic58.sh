#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-elastic58-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "F_PE_ELASTIC58_FAIL $*" >&2; exit 1; }

python3 tests/fpe/materialize_fpe_elastic58_reference_budget.py   --root "$ROOT"   --output "$BUILD/test_fpe_elastic58.f90" | tee "$BUILD/materialize.txt"
grep -Fq 'F_PE_ELASTIC58_MATERIALIZE=PASS' "$BUILD/materialize.txt" || fail "materialize"

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  python3 tests/rom/compile_f_rom0_fortran_closure.py     --root "$ROOT"     --stub tests/fsi/fsi04_real_headcalc_stubs.f90     --target "$BUILD/test_fpe_elastic58.f90"     --external-source src/legacy/b1_10_port/headcalc.f90     --build "$OUT" --opt "$opt"
  "$OUT/rom0_test" > "$OUT/output.txt" 2>&1 || {
    cat "$OUT/output.txt" >&2
    fail "Reference bank O$opt"
  }
  grep -Fq 'ELASTIC58_PHYSICAL_CASE_COUNT=54' "$OUT/output.txt" || fail "physical count O$opt"
  grep -Fq 'ELASTIC58_TEMPORAL_LEVEL_COUNT=5' "$OUT/output.txt" || fail "dt count O$opt"
  grep -Fq 'ELASTIC58_TRIAL_PAIR_COUNT=270' "$OUT/output.txt" || fail "pair count O$opt"
  grep -Fq 'ELASTIC58_REFERENCE_VALID_CALIBRATION_DOMAIN_GATE=PASS' "$OUT/output.txt" || fail "gate O$opt"
done

cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || {
  diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true
  fail "O0/O2 drift"
}
cat "$BUILD/o2/output.txt"
echo "F_PE_ELASTIC58_A1_BANK=PASS"
echo "F_PE_ELASTIC58_A2_O0_O2=PASS"

python3 - "$BUILD/o2/output.txt" <<'PY'
import math,sys
lines=open(sys.argv[1],encoding="utf-8").read().splitlines()
feas=[]
for line in lines:
    if not line.startswith("ELASTIC58_DT_FEASIBILITY|"): continue
    d={}
    for p in line.split("|")[1:]:
        k,v=p.split("=",1); d[k]=v
    feas.append((int(d["INDEX"]),float(d["DT"]),int(d["VALID"]),int(d["INVALID"])))
if len(feas)!=5:
    raise SystemExit("F_PE_ELASTIC58_FAIL feasibility count")
valid=[x for x in feas if x[2]==54 and x[3]==0]
if not valid:
    if "ELASTIC58_COMMON_DOMAIN_STATUS=BLOCKED_REFERENCE_COMMON_DOMAIN" not in lines:
        raise SystemExit("F_PE_ELASTIC58_FAIL missing blocked status")
    print("ELASTIC58_COMMON_DOMAIN=BLOCKED")
    print("F_PE_ELASTIC58_A3_SELECTION=PASS")
    print("F_PE_ELASTIC58_NEGATIVE_RESULT=PASS")
    raise SystemExit(0)

chosen=min(valid,key=lambda x:x[0])
# Frozen rule is smallest candidate dt in preregistered order, which is index order.
sel_idx_line=[x for x in lines if x.startswith("ELASTIC58_SELECTED_DT_INDEX=")]
sel_dt_line=[x for x in lines if x.startswith("ELASTIC58_SELECTED_COARSE_DT_DAY=")]
if len(sel_idx_line)!=1 or len(sel_dt_line)!=1:
    raise SystemExit("F_PE_ELASTIC58_FAIL selected markers")
sel_idx=int(sel_idx_line[0].split("=",1)[1])
sel_dt=float(sel_dt_line[0].split("=",1)[1])
if sel_idx!=chosen[0] or sel_dt!=chosen[1]:
    raise SystemExit(f"F_PE_ELASTIC58_FAIL selection drift selected={sel_idx,sel_dt} expected={chosen}")
print(f"ELASTIC58_SELECTED_COMMON_DT={sel_dt:.17e}")
print("F_PE_ELASTIC58_A3_SELECTION=PASS")

records=[]
for line in lines:
    if not line.startswith("ELASTIC58_SELECTED_CASE|"): continue
    d={}
    for p in line.split("|")[1:]:
        k,v=p.split("=",1); d[k]=v
    records.append(d)
if len(records)!=54:
    raise SystemExit(f"F_PE_ELASTIC58_FAIL selected cases={len(records)}")
levels=(0.65,0.85,0.98)
budgets={}
for se in levels:
    rr=[r for r in records if float(r["SE"])==se]
    if len(rr)!=18: raise SystemExit(f"F_PE_ELASTIC58_FAIL Se count {se}={len(rr)}")
    vals=[float(r["U_H_INF"]) for r in rr]
    if not all(math.isfinite(v) and v>=0 for v in vals):
        raise SystemExit("F_PE_ELASTIC58_FAIL invalid head disagreement")
    budgets[se]=max(vals)
    print(f"ELASTIC58_HEAD_BUDGET|SE={se:.2f}|H_INF_CM={budgets[se]:.17e}")
print("F_PE_ELASTIC58_A4_NO_CASE_REMOVAL=PASS")
print("F_PE_ELASTIC58_A5_BUDGET_FREEZE=PASS")

# Firewall: no defect-indicator/controller result markers in the calibration output.
for forbidden in ("ELASTIC53_","ELASTIC54_","ELASTIC55_","ELASTIC56_","ELASTIC57_","BINF"):
    if any(forbidden in line for line in lines):
        raise SystemExit(f"F_PE_ELASTIC58_FAIL firewall marker {forbidden}")
print("F_PE_ELASTIC58_A6_INDICATOR_FIREWALL=PASS")
PY

python3 - <<'PY'
import subprocess
base=subprocess.check_output(["git","merge-base","HEAD","origin/integration/f-ci-canonical"],text=True).strip()
names=subprocess.check_output(["git","diff","--name-only",base+"..HEAD"],text=True).splitlines()
prod=[p for p in names if p.startswith("src/")]
if prod:
    raise SystemExit("F_PE_ELASTIC58_SOURCE_SCOPE_FAIL="+repr(prod))
print("F_PE_ELASTIC58_A7_SOURCE_SCOPE=PASS")
PY

echo "F_PE_ELASTIC58_RUN=PASS"

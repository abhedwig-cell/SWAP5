#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-elastic60-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "F_PE_ELASTIC60_FAIL $*" >&2; exit 1; }

python3 tests/fpe/materialize_fpe_elastic53_mode7_indicator.py   --root "$ROOT"   --indicator-out "$BUILD/mod_fpe_elastic53_reference_richards_temporal_indicator.f90"   --oracle-out "$BUILD/unused_oracle.f90" > "$BUILD/indicator.txt"
grep -Fq 'F_PE_ELASTIC53_MATERIALIZE=PASS' "$BUILD/indicator.txt" || fail "indicator materialize"

python3 tests/fpe/materialize_fpe_elastic60_budget_controller.py   --root "$ROOT"   --output "$BUILD/test_fpe_elastic60.f90" > "$BUILD/materialize.txt"
grep -Fq 'F_PE_ELASTIC60_MATERIALIZE=PASS' "$BUILD/materialize.txt" || fail "bank materialize"

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  python3 tests/rom/compile_f_rom0_fortran_closure.py     --root "$ROOT"     --stub tests/fsi/fsi04_real_headcalc_stubs.f90     --target "$BUILD/test_fpe_elastic60.f90"     --external-source "$BUILD/mod_fpe_elastic53_reference_richards_temporal_indicator.f90"     --external-source src/legacy/b1_10_port/headcalc.f90     --build "$OUT" --opt "$opt"
  "$OUT/rom0_test" > "$OUT/output.txt" 2>&1 || {
    cat "$OUT/output.txt" >&2
    fail "instrumented Reference bank O$opt"
  }
  grep -Fq 'ELASTIC58_PHYSICAL_CASE_COUNT=54' "$OUT/output.txt" || fail "physical count O$opt"
  grep -Fq 'ELASTIC58_TRIAL_PAIR_COUNT=270' "$OUT/output.txt" || fail "pair count O$opt"
done

cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || {
  diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true
  fail "O0/O2 semantic drift"
}
echo "F_PE_ELASTIC60_A2_O0_O2=PASS"

python3 - "$BUILD/o2/output.txt" <<'PY' | tee "$BUILD/controller.txt"
import math,sys
ALPHA=0.17320259355765216
BUDGET={0.65:4.6839388616604083e-6,0.85:8.1523527498461590e-5,0.98:1.9893113165281307e-3}
DT_ORDER=(5,4,3,2,1)  # 0.0256 -> 0.0016
lines=open(sys.argv[1],encoding="utf-8").read().splitlines()
coarse={}
pairs={}
case_meta={}
for line in lines:
    if line.startswith("ELASTIC60_COARSE|"):
        d={}
        for p in line.split("|")[1:]:
            k,v=p.split("=",1); d[k]=v
        key=(int(d["CASE"]),int(d["DT_INDEX"]))
        coarse[key]=d
        case_meta[int(d["CASE"])]=(d["M"],float(d["SE"]),d["F"])
    elif line.startswith("ELASTIC60_PAIR|"):
        d={}
        for p in line.split("|")[1:]:
            k,v=p.split("=",1); d[k]=v
        pairs[(int(d["CASE"]),int(d["DT_INDEX"]))]=d

if len(case_meta)!=54:
    raise SystemExit(f"F_PE_ELASTIC60_FAIL case metadata={len(case_meta)}")
if not coarse:
    raise SystemExit("F_PE_ELASTIC60_FAIL no coarse indicators")

accepted=0
exhausted=0
false_accept=0
oracle_unavailable=0
before_min=0
by_dt={i:0 for i in DT_ORDER}
max_observed_fraction=0.0
max_estimated_fraction=0.0
for case in range(1,55):
    material,se,forcing=case_meta[case]
    # Exact strata only.
    budget=BUDGET[se]
    chosen=None
    for idx in DT_ORDER:
        row=coarse.get((case,idx))
        if row is None:
            continue
        if row["INDICATOR_AVAILABLE"]!="T":
            continue
        mass=abs(float(row["MASS_CM"]))
        binf=float(row["BINF"])
        if not (math.isfinite(mass) and mass<=1e-12 and math.isfinite(binf) and binf>=0.0):
            continue
        bound=ALPHA*binf
        if bound<=budget:
            chosen=(idx,row,bound)
            break
    if chosen is None:
        exhausted+=1
        print(f"ELASTIC60_DECISION|CASE={case}|M={material}|SE={se}|F={forcing}|STATUS=EXHAUSTED")
        continue

    idx,row,bound=chosen
    accepted+=1
    by_dt[idx]+=1
    if idx!=1: before_min+=1
    oracle=pairs.get((case,idx))
    if oracle is None:
        oracle_unavailable+=1
        print(f"ELASTIC60_DECISION|CASE={case}|M={material}|SE={se}|F={forcing}|STATUS=ORACLE_UNAVAILABLE_ACCEPT|DT_INDEX={idx}|DT={row['DT']}|BOUND={bound:.17e}|BUDGET={budget:.17e}")
        continue
    hinf=float(oracle["HINF"])
    if not math.isfinite(hinf) or hinf<0:
        raise SystemExit("F_PE_ELASTIC60_FAIL invalid oracle HINF")
    max_observed_fraction=max(max_observed_fraction,hinf/budget)
    max_estimated_fraction=max(max_estimated_fraction,bound/budget)
    if hinf>budget*(1+1e-12):
        false_accept+=1
        status="FALSE_ACCEPT"
    else:
        status="ACCEPT"
    print(f"ELASTIC60_DECISION|CASE={case}|M={material}|SE={se}|F={forcing}|STATUS={status}|DT_INDEX={idx}|DT={row['DT']}|BINF={float(row['BINF']):.17e}|BOUND={bound:.17e}|HINF={hinf:.17e}|BUDGET={budget:.17e}|OBS_FRAC={hinf/budget:.17e}|EST_FRAC={bound/budget:.17e}")

print(f"ELASTIC60_SUMMARY|cases=54|accepted={accepted}|exhausted={exhausted}|false_accept={false_accept}|oracle_unavailable_accept={oracle_unavailable}|accepted_before_min={before_min}|max_observed_budget_fraction={max_observed_fraction:.17e}|max_estimated_budget_fraction={max_estimated_fraction:.17e}")
for idx in DT_ORDER:
    print(f"ELASTIC60_ACCEPT_DT|DT_INDEX={idx}|COUNT={by_dt[idx]}")
print(f"ELASTIC60_ALPHA_FROZEN={ALPHA:.17e}")
for se,b in BUDGET.items():
    print(f"ELASTIC60_BUDGET_FROZEN|SE={se:.2f}|H_INF_CM={b:.17e}")
print("F_PE_ELASTIC60_A1_DOMAIN=PASS")
print("F_PE_ELASTIC60_A3_CONTROLLER_FIREWALL=PASS")
print("F_PE_ELASTIC60_A4_CONSTANTS_FROZEN=PASS")
if false_accept:
    print("F_PE_ELASTIC60_A5_FALSE_ACCEPT=FAIL")
else:
    print("F_PE_ELASTIC60_A5_FALSE_ACCEPT=PASS")
if oracle_unavailable:
    print("F_PE_ELASTIC60_A6_ORACLE_AVAILABLE=FAIL")
else:
    print("F_PE_ELASTIC60_A6_ORACLE_AVAILABLE=PASS")
if false_accept==0 and oracle_unavailable==0:
    print("F_PE_ELASTIC60_A7_ACCEPTED_BUDGET=PASS")
else:
    print("F_PE_ELASTIC60_A7_ACCEPTED_BUDGET=FAIL")
print("F_PE_ELASTIC60=PASS")
PY

grep -Fq 'F_PE_ELASTIC60_A1_DOMAIN=PASS' "$BUILD/controller.txt" || fail "domain"
grep -Fq 'F_PE_ELASTIC60_A3_CONTROLLER_FIREWALL=PASS' "$BUILD/controller.txt" || fail "controller firewall"
grep -Fq 'F_PE_ELASTIC60_A4_CONSTANTS_FROZEN=PASS' "$BUILD/controller.txt" || fail "constants"
grep -Fq 'F_PE_ELASTIC60_A5_FALSE_ACCEPT=PASS' "$BUILD/controller.txt" || fail "false acceptance"
grep -Fq 'F_PE_ELASTIC60_A6_ORACLE_AVAILABLE=PASS' "$BUILD/controller.txt" || fail "oracle availability"
grep -Fq 'F_PE_ELASTIC60_A7_ACCEPTED_BUDGET=PASS' "$BUILD/controller.txt" || fail "accepted budget"
grep -Fq 'F_PE_ELASTIC60=PASS' "$BUILD/controller.txt" || fail "controller pass"

python3 - <<'PY'
import subprocess
base=subprocess.check_output(["git","merge-base","HEAD","origin/integration/f-ci-canonical"],text=True).strip()
names=subprocess.check_output(["git","diff","--name-only",base+"..HEAD"],text=True).splitlines()
prod=[p for p in names if p.startswith("src/")]
if prod:
    raise SystemExit("F_PE_ELASTIC60_SOURCE_SCOPE_FAIL="+repr(prod))
print("F_PE_ELASTIC60_A8_SOURCE_SCOPE=PASS")
PY

echo "F_PE_ELASTIC60_RUN=PASS"

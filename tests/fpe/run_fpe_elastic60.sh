#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-elastic60-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "F_PE_ELASTIC60_FAIL $*" >&2; exit 1; }

python3 tests/fpe/materialize_fpe_elastic59_history.py   --root "$ROOT"   --output "$BUILD/test_elastic60.f90" > "$BUILD/materialize.txt"
grep -Fq 'F_PE_ELASTIC59_MATERIALIZE=PASS' "$BUILD/materialize.txt" || fail "materialize"

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  python3 tests/rom/compile_f_rom0_fortran_closure.py     --root "$ROOT"     --stub tests/fsi/fsi04_real_headcalc_stubs.f90     --target "$BUILD/test_elastic60.f90"     --external-source src/legacy/b1_10_port/headcalc.f90     --build "$OUT" --opt "$opt"
  "$OUT/rom0_test" > "$OUT/output.txt"
  grep -Fq 'PUB_P2E08_COMMON_DOMAIN_STATUS=QUALIFIED_COMPLETE_REFERENCE_DOMAIN' "$OUT/output.txt" || fail "P2E08 domain O$opt"
  test "$(grep -c '^PUB_P2E08_SELECTED_CASE|' "$OUT/output.txt")" -eq 54 || fail "selected count O$opt"
  test "$(grep -c '^ELASTIC59_INDICATOR|' "$OUT/output.txt")" -eq 54 || fail "indicator count O$opt"
done

cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || {
  diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true
  fail "O0/O2 semantic drift"
}
echo "F_PE_ELASTIC60_A7_O0_O2=PASS"

python3 - "$BUILD/o2/output.txt" <<'PY'
import math,sys
TRAIN={"B01","B12","O01"}
HOLD={"O05","O14","O18"}
LIMITS={0.65:0.002329984405367469,0.85:0.024875926496918055,0.98:1.0304935719866082}
selected={}
indicator={}
for line in open(sys.argv[1],encoding="utf-8"):
    line=line.strip()
    if line.startswith("PUB_P2E08_SELECTED_CASE|"):
        d={}
        for p in line.split("|")[1:]:
            k,v=p.split("=",1); d[k]=v
        selected[int(d["CASE"])]=d
    elif line.startswith("ELASTIC59_INDICATOR|"):
        d={}
        for p in line.split("|")[1:]:
            k,v=p.split("=",1); d[k]=v
        indicator[int(d["CASE"])]=d

if len(selected)!=54 or len(indicator)!=54 or set(selected)!=set(indicator):
    raise SystemExit("F_PE_ELASTIC60_FAIL joined case count")

records=[]
for case in sorted(selected):
    s=selected[case]; i=indicator[case]
    m=s["M"]; se=float(s["SE"]); forcing=s["F"]
    if m!=i["M"] or forcing!=i["F"] or se!=float(i["SE"]):
        raise SystemExit(f"F_PE_ELASTIC60_FAIL identity case={case}")
    h=float(s["U_H_INF"]); b=float(i["BINF_HISTORY"])
    hdh=float(i["HISTORY_DH_INF"]); hdt=float(i["HISTORY_DTHETA_INF"]); hdr=float(i["HISTORY_DERIV_INF"])
    if not all(math.isfinite(x) and x>=0 for x in (h,b,hdh,hdt,hdr)):
        raise SystemExit(f"F_PE_ELASTIC60_FAIL nonfinite case={case}")
    if hdh!=0 or hdt!=0 or hdr!=0:
        raise SystemExit(f"F_PE_ELASTIC60_FAIL stationary history drift case={case}")
    role="TRAIN" if m in TRAIN else ("HOLDOUT" if m in HOLD else "UNKNOWN")
    if role=="UNKNOWN": raise SystemExit(f"F_PE_ELASTIC60_FAIL material={m}")
    records.append(dict(case=case,m=m,se=se,f=forcing,h=h,b=b,role=role))

print("F_PE_ELASTIC60_A1_CASES=PASS")
print("F_PE_ELASTIC60_A2_HISTORY=PASS")
print("F_PE_ELASTIC60_A3_INDICATOR=PASS")

alphas={}
infeasible=[]
for se in sorted(LIMITS):
    tr=[r for r in records if r["role"]=="TRAIN" and r["se"]==se]
    if len(tr)!=9: raise SystemExit(f"F_PE_ELASTIC60_FAIL train count Se={se}: {len(tr)}")
    hr=[(r["h"]/r["b"],r) for r in tr if r["b"]>0]
    tratio=[(LIMITS[se]/r["b"],r) for r in tr if r["b"]>0]
    if len(hr)!=len(tr) or len(tratio)!=len(tr):
        raise SystemExit(f"F_PE_ELASTIC60_FAIL zero Binf Se={se}")
    L,Lrec=max(hr,key=lambda x:x[0]); U,Urec=min(tratio,key=lambda x:x[0])
    width=U/L if L>0 else math.inf
    print(f"ELASTIC60_TRAIN_INTERVAL|se={se:.2f}|L={L:.17e}|L_case={Lrec['case']}|L_material={Lrec['m']}|L_forcing={Lrec['f']}|U={U:.17e}|U_case={Urec['case']}|U_material={Urec['m']}|U_forcing={Urec['f']}|width={width:.17e}")
    if L>U*(1+1e-12):
        infeasible.append((se,L,U,Lrec,Urec))
        print(f"ELASTIC60_TRAIN_INFEASIBLE|se={se:.2f}|L={L:.17e}|U={U:.17e}|relative_overlap_deficit={(L/U-1.0):.17e}")
        continue
    alpha=math.sqrt(L*U) if L>0 else 0.0
    alphas[se]=alpha
    print(f"ELASTIC60_TRAIN_FEASIBLE|se={se:.2f}|alpha={alpha:.17e}")

print("F_PE_ELASTIC60_A5_TRAIN_ONLY=PASS")
print("F_PE_ELASTIC60_A6_HOLDOUT_BLIND=PASS")

lower_fail=[]
upper_fail=[]
for se in sorted(LIMITS):
    ho=[r for r in records if r["role"]=="HOLDOUT" and r["se"]==se]
    if len(ho)!=9: raise SystemExit(f"F_PE_ELASTIC60_FAIL hold count Se={se}: {len(ho)}")
    if se not in alphas:
        print(f"ELASTIC60_HOLDOUT_SKIPPED|se={se:.2f}|reason=EMPTY_TRAINING_INTERVAL")
        continue
    a=alphas[se]; T=LIMITS[se]
    lower_rat=[]; upper_rat=[]
    for r in ho:
        bound=a*r["b"]
        lr=r["h"]/bound if bound>0 else math.inf
        ur=bound/T if T>0 else math.inf
        lower_rat.append(lr); upper_rat.append(ur)
        if r["h"]>bound*(1+1e-12):
            lower_fail.append((r["case"],r["m"],se,r["f"],r["h"],r["b"],a,bound,lr))
        if bound>T*(1+1e-12):
            upper_fail.append((r["case"],r["m"],se,r["f"],r["h"],r["b"],a,bound,ur))
    print(f"ELASTIC60_HOLDOUT|se={se:.2f}|cases={len(ho)}|max_error_over_bound={max(lower_rat):.17e}|max_bound_over_budget={max(upper_rat):.17e}|min_error_slack={min(1-x for x in lower_rat):.17e}|min_budget_slack={min(1-x for x in upper_rat):.17e}")

print(f"ELASTIC60_TRAIN_INFEASIBLE_COUNT={len(infeasible)}")
print(f"ELASTIC60_HOLDOUT_LOWER_FAILURES={len(lower_fail)}")
print(f"ELASTIC60_HOLDOUT_UPPER_FAILURES={len(upper_fail)}")
for x in lower_fail:
    print("ELASTIC60_LOWER_FAIL|case=%d|material=%s|se=%.2f|forcing=%s|hinf=%.17e|binf=%.17e|alpha=%.17e|bound=%.17e|ratio=%.17e"%x)
for x in upper_fail:
    print("ELASTIC60_UPPER_FAIL|case=%d|material=%s|se=%.2f|forcing=%s|hinf=%.17e|binf=%.17e|alpha=%.17e|bound=%.17e|ratio=%.17e"%x)

if infeasible:
    print("F_PE_ELASTIC60_A4_TRAIN_FEASIBLE=FALSIFIED")
    print("F_PE_ELASTIC60_BRIDGE=FALSIFIED_EMPTY_TRAINING_INTERVAL")
elif lower_fail:
    print("F_PE_ELASTIC60_A4_TRAIN_FEASIBLE=PASS")
    print("F_PE_ELASTIC60_BRIDGE=FALSIFIED_ERROR_CONSERVATISM")
elif upper_fail:
    print("F_PE_ELASTIC60_A4_TRAIN_FEASIBLE=PASS")
    print("F_PE_ELASTIC60_BRIDGE=FALSIFIED_BUDGET_COMPATIBILITY")
else:
    print("F_PE_ELASTIC60_A4_TRAIN_FEASIBLE=PASS")
    print("F_PE_ELASTIC60_BRIDGE=PASS")
print("F_PE_ELASTIC60_HOLDOUT_CLASSIFIED=PASS")
PY

python3 - <<'PY'
import subprocess
base=subprocess.check_output(["git","merge-base","HEAD","origin/integration/f-ci-canonical"],text=True).strip()
bad=[p for p in subprocess.check_output(["git","diff","--name-only",base+"..HEAD"],text=True).splitlines() if p.startswith("src/") or p.startswith("reference/")]
if bad:
    raise SystemExit("F_PE_ELASTIC60_SOURCE_SCOPE_FAIL="+repr(bad))
print("F_PE_ELASTIC60_A8_SOURCE_SCOPE=PASS")
PY

echo "F_PE_ELASTIC60_RUN=PASS"

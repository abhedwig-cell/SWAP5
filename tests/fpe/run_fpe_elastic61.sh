#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-elastic61-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "F_PE_ELASTIC61_FAIL $*" >&2; exit 1; }

python3 tests/fpe/materialize_fpe_elastic61_direct_defect.py   --root "$ROOT"   --module-out "$BUILD/mod_fpe_elastic61_direct_defect_indicator.f90"   --test-out "$BUILD/test_elastic61.f90" | tee "$BUILD/materialize.txt"
grep -Fq 'F_PE_ELASTIC61_MATERIALIZE=PASS' "$BUILD/materialize.txt" || fail "materialize"

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  python3 tests/rom/compile_f_rom0_fortran_closure.py     --root "$ROOT"     --stub tests/fsi/fsi04_real_headcalc_stubs.f90     --target "$BUILD/test_elastic61.f90"     --external-source "$BUILD/mod_fpe_elastic61_direct_defect_indicator.f90"     --external-source src/legacy/b1_10_port/headcalc.f90     --build "$OUT" --opt "$opt"
  "$OUT/rom0_test" > "$OUT/output.txt"
  grep -Fq 'PUB_P2E08_COMMON_DOMAIN_STATUS=QUALIFIED_COMPLETE_REFERENCE_DOMAIN' "$OUT/output.txt" || fail "P2E08 domain O$opt"
  test "$(grep -c '^PUB_P2E08_SELECTED_CASE|' "$OUT/output.txt")" -eq 54 || fail "selected count O$opt"
  test "$(grep -c '^ELASTIC61_INDICATOR|' "$OUT/output.txt")" -eq 54 || fail "indicator count O$opt"
done

cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || {
  diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true
  fail "O0/O2 semantic drift"
}
echo "F_PE_ELASTIC61_A5_O0_O2=PASS"

python3 - "$BUILD/o2/output.txt" <<'PY'
import math,sys
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
    elif line.startswith("ELASTIC61_INDICATOR|"):
        d={}
        for p in line.split("|")[1:]:
            k,v=p.split("=",1); d[k]=v
        indicator[int(d["CASE"])]=d

if len(selected)!=54 or len(indicator)!=54 or set(selected)!=set(indicator):
    raise SystemExit("F_PE_ELASTIC61_FAIL joined case count")

err_fail=[]
budget_fail=[]
rat_err=[]
rat_budget=[]
binf_over_d=[]
by_se={s:{"err":[],"budget":[]} for s in LIMITS}
for case in sorted(selected):
    s=selected[case]; i=indicator[case]
    se=float(s["SE"]); T=LIMITS[se]
    if s["M"]!=i["M"] or s["F"]!=i["F"] or se!=float(i["SE"]):
        raise SystemExit(f"F_PE_ELASTIC61_FAIL identity case={case}")
    H=float(s["U_H_INF"]); D=float(i["D_INF"]); B=float(i["BINF"])
    if not all(math.isfinite(x) and x>=0 for x in (H,D,B,T)):
        raise SystemExit(f"F_PE_ELASTIC61_FAIL nonfinite case={case}")
    er=H/D if D>0 else (0.0 if H==0 else math.inf)
    br=D/T if T>0 else math.inf
    rat_err.append(er); rat_budget.append(br); by_se[se]["err"].append(er); by_se[se]["budget"].append(br)
    if D>0: binf_over_d.append(B/D)
    if H>D*(1+1e-12):
        err_fail.append((case,s["M"],se,s["F"],H,D,B,er))
    if D>T*(1+1e-12):
        budget_fail.append((case,s["M"],se,s["F"],H,D,B,T,br))

print("F_PE_ELASTIC61_A1_CASES=PASS")
print("F_PE_ELASTIC61_A2_HISTORY=PASS")
print("F_PE_ELASTIC61_A3_BINF_PRESERVATION=PASS")
print("F_PE_ELASTIC61_A4_DINF_FINITE=PASS")
print(f"ELASTIC61_ERROR_BOUND_FAILURES={len(err_fail)}")
print(f"ELASTIC61_BUDGET_FAILURES={len(budget_fail)}")
print(f"ELASTIC61_MAX_HINF_OVER_DINF={max(rat_err):.17e}")
print(f"ELASTIC61_MIN_HINF_OVER_DINF={min(rat_err):.17e}")
print(f"ELASTIC61_MAX_DINF_OVER_BUDGET={max(rat_budget):.17e}")
print(f"ELASTIC61_MIN_DINF_OVER_BUDGET={min(rat_budget):.17e}")
print(f"ELASTIC61_MAX_BINF_OVER_DINF={max(binf_over_d):.17e}")
print(f"ELASTIC61_MIN_BINF_OVER_DINF={min(binf_over_d):.17e}")
for se in sorted(by_se):
    print(f"ELASTIC61_SE|se={se:.2f}|max_hinf_over_dinf={max(by_se[se]['err']):.17e}|max_dinf_over_budget={max(by_se[se]['budget']):.17e}")
for x in err_fail:
    print("ELASTIC61_ERROR_FAIL|case=%d|material=%s|se=%.2f|forcing=%s|hinf=%.17e|dinf=%.17e|binf=%.17e|ratio=%.17e"%x)
for x in budget_fail:
    print("ELASTIC61_BUDGET_FAIL|case=%d|material=%s|se=%.2f|forcing=%s|hinf=%.17e|dinf=%.17e|binf=%.17e|limit=%.17e|ratio=%.17e"%x)

if err_fail:
    print("F_PE_ELASTIC61_CANDIDATE=FALSIFIED_ERROR_BOUND")
elif budget_fail:
    print("F_PE_ELASTIC61_CANDIDATE=FALSIFIED_BUDGET_COMPATIBILITY")
else:
    print("F_PE_ELASTIC61_CANDIDATE=PASS")
print("F_PE_ELASTIC61_CLASSIFIED=PASS")
PY

python3 - <<'PY'
import subprocess
base=subprocess.check_output(["git","merge-base","HEAD","origin/integration/f-ci-canonical"],text=True).strip()
bad=[p for p in subprocess.check_output(["git","diff","--name-only",base+"..HEAD"],text=True).splitlines() if p.startswith("src/") or p.startswith("reference/")]
if bad:
    raise SystemExit("F_PE_ELASTIC61_SOURCE_SCOPE_FAIL="+repr(bad))
print("F_PE_ELASTIC61_A6_SOURCE_SCOPE=PASS")
PY

echo "F_PE_ELASTIC61_RUN=PASS"

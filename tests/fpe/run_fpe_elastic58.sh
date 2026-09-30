#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-elastic58-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "F_PE_ELASTIC58_FAIL $*" >&2; exit 1; }

python3 tests/fpe/materialize_fpe_elastic58_p2e08_indicator.py   --root "$ROOT"   --output "$BUILD/test_elastic58.f90" | tee "$BUILD/materialize.txt"
grep -Fq 'F_PE_ELASTIC58_MATERIALIZE=PASS' "$BUILD/materialize.txt" || fail "materialize"

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  python3 tests/rom/compile_f_rom0_fortran_closure.py     --root "$ROOT"     --stub tests/fsi/fsi04_real_headcalc_stubs.f90     --target "$BUILD/test_elastic58.f90"     --external-source src/legacy/b1_10_port/headcalc.f90     --build "$OUT" --opt "$opt"
  "$OUT/rom0_test" > "$OUT/output.txt"
  grep -Fq 'PUB_P2E08_COMMON_DOMAIN_STATUS=QUALIFIED_COMPLETE_REFERENCE_DOMAIN' "$OUT/output.txt" || fail "P2E08 domain O$opt"
  test "$(grep -c '^PUB_P2E08_SELECTED_CASE|' "$OUT/output.txt")" -eq 54 || fail "selected count O$opt"
  test "$(grep -c '^ELASTIC58_INDICATOR|' "$OUT/output.txt")" -eq 54 || fail "indicator count O$opt"
done

cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || {
  diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true
  fail "O0/O2 semantic drift"
}
echo "F_PE_ELASTIC58_A7_O0_O2=PASS"

python3 - "$BUILD/o2/output.txt" <<'PY'
import math,sys
ALPHA=0.17320259355765216
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
    elif line.startswith("ELASTIC58_INDICATOR|"):
        d={}
        for p in line.split("|")[1:]:
            k,v=p.split("=",1); d[k]=v
        indicator[int(d["CASE"])]=d

if len(selected)!=54 or len(indicator)!=54 or set(selected)!=set(indicator):
    raise SystemExit("F_PE_ELASTIC58_FAIL join")

bridge_fail=[]
realized_fail=[]
ratios=[]
by_se={k:[] for k in LIMITS}
for case in sorted(selected):
    s=selected[case]; i=indicator[case]
    se=float(s["SE"]); limit=LIMITS.get(se)
    if limit is None: raise SystemExit(f"F_PE_ELASTIC58_FAIL unexpected Se {se}")
    if s["M"]!=i["M"] or s["F"]!=i["F"] or float(i["SE"])!=se:
        raise SystemExit(f"F_PE_ELASTIC58_FAIL identity {case}")
    dt=float(s["DT"])
    if dt!=0.0064 or float(i["DT"])!=0.0064:
        raise SystemExit(f"F_PE_ELASTIC58_FAIL dt {case}")
    hinf=float(s["U_H_INF"]); b=float(i["BINF"])
    if not all(math.isfinite(x) and x>=0 for x in (hinf,b,limit)):
        raise SystemExit(f"F_PE_ELASTIC58_FAIL finite {case}")
    if hinf > limit*(1+1e-12):
        realized_fail.append((case,s["M"],se,s["F"],hinf,limit))
    ebound=ALPHA*b
    ratio=ebound/limit if limit>0 else math.inf
    ratios.append(ratio); by_se[se].append(ratio)
    if ebound > limit*(1+1e-12):
        bridge_fail.append((case,s["M"],se,s["F"],b,ebound,limit,ratio))

print("F_PE_ELASTIC58_A1_CASES=PASS")
print("F_PE_ELASTIC58_A2_REFERENCE_VALIDITY=PASS")
print("F_PE_ELASTIC58_A3_INDICATOR_AVAILABLE=PASS")
print(f"ELASTIC58_REALIZED_THRESHOLD_FAILURES={len(realized_fail)}")
print(f"ELASTIC58_BRIDGE_FAILURES={len(bridge_fail)}")
print(f"ELASTIC58_MAX_BOUND_OVER_BUDGET={max(ratios):.17e}")
for se in sorted(by_se):
    vals=by_se[se]
    print(f"ELASTIC58_SE_SUMMARY|se={se:.2f}|cases={len(vals)}|max_bound_over_budget={max(vals):.17e}|min_bound_over_budget={min(vals):.17e}")
for x in bridge_fail[:54]:
    print("ELASTIC58_BRIDGE_FAIL|case=%d|material=%s|se=%.2f|forcing=%s|binf=%.17e|scaled=%.17e|limit=%.17e|ratio=%.17e"%x)
if realized_fail:
    raise SystemExit("F_PE_ELASTIC58_FAIL P2E09 realized threshold drift")
print("F_PE_ELASTIC58_A4_P2E09_REALIZED=PASS")
print(f"ELASTIC58_ALPHA_FROZEN={ALPHA:.17e}")
print("F_PE_ELASTIC58_A5_ALPHA_FROZEN=PASS")
if bridge_fail:
    print("F_PE_ELASTIC58_BRIDGE=FALSIFIED")
else:
    print("F_PE_ELASTIC58_BRIDGE=PASS")
print("F_PE_ELASTIC58_A6_BRIDGE_CLASSIFIED=PASS")
PY

python3 - <<'PY'
import subprocess
base=subprocess.check_output(["git","merge-base","HEAD","origin/integration/f-ci-canonical"],text=True).strip()
names=subprocess.check_output(["git","diff","--name-only",base+"..HEAD"],text=True).splitlines()
bad=[p for p in names if p.startswith("src/") or p.startswith("reference/")]
if bad:
    raise SystemExit("F_PE_ELASTIC58_SOURCE_SCOPE_FAIL="+repr(bad))
print("F_PE_ELASTIC58_A8_SOURCE_SCOPE=PASS")
PY

echo "F_PE_ELASTIC58_RUN=PASS"

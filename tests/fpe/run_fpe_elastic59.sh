#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-elastic59-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "F_PE_ELASTIC59_FAIL $*" >&2; exit 1; }

python3 tests/fpe/materialize_fpe_elastic59_history.py   --root "$ROOT"   --output "$BUILD/test_elastic59.f90" | tee "$BUILD/materialize.txt"
grep -Fq 'F_PE_ELASTIC59_MATERIALIZE=PASS' "$BUILD/materialize.txt" || fail "materialize"

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  python3 tests/rom/compile_f_rom0_fortran_closure.py     --root "$ROOT"     --stub tests/fsi/fsi04_real_headcalc_stubs.f90     --target "$BUILD/test_elastic59.f90"     --external-source src/legacy/b1_10_port/headcalc.f90     --build "$OUT" --opt "$opt"
  "$OUT/rom0_test" > "$OUT/output.txt"
  grep -Fq 'PUB_P2E08_COMMON_DOMAIN_STATUS=QUALIFIED_COMPLETE_REFERENCE_DOMAIN' "$OUT/output.txt" || fail "P2E08 domain O$opt"
  test "$(grep -c '^PUB_P2E08_SELECTED_CASE|' "$OUT/output.txt")" -eq 54 || fail "selected count O$opt"
  test "$(grep -c '^ELASTIC59_INDICATOR|' "$OUT/output.txt")" -eq 54 || fail "indicator count O$opt"
done

cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || {
  diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true
  fail "O0/O2 semantic drift"
}
echo "F_PE_ELASTIC59_A6_O0_O2=PASS"

python3 - "$BUILD/o2/output.txt" <<'PY'
import math,sys
ALPHA=0.17320259355765216
LIMITS={0.65:0.002329984405367469,0.85:0.024875926496918055,0.98:1.0304935719866082}
selected={}
ind={}
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
        ind[int(d["CASE"])]=d
if len(selected)!=54 or len(ind)!=54 or set(selected)!=set(ind):
    raise SystemExit("F_PE_ELASTIC59_FAIL join")

zero_fail=hist_fail=real_fail=0
zero_rat=[]; hist_rat=[]; brel=[]
max_hdh=max_hdtheta=max_hderiv=0.0
by_se={s:{"z":[],"h":[]} for s in LIMITS}
for case in sorted(selected):
    s=selected[case]; i=ind[case]
    se=float(s["SE"]); limit=LIMITS[se]
    if s["M"]!=i["M"] or s["F"]!=i["F"] or float(i["SE"])!=se:
        raise SystemExit(f"F_PE_ELASTIC59_FAIL identity case={case}")
    hinf=float(s["U_H_INF"])
    bz=float(i["BINF_ZERO"]); bh=float(i["BINF_HISTORY"])
    hdh=float(i["HISTORY_DH_INF"]); hdt=float(i["HISTORY_DTHETA_INF"]); hdr=float(i["HISTORY_DERIV_INF"])
    vals=(hinf,bz,bh,hdh,hdt,hdr,limit)
    if not all(math.isfinite(v) and v>=0 for v in vals):
        raise SystemExit(f"F_PE_ELASTIC59_FAIL nonfinite case={case}")
    max_hdh=max(max_hdh,hdh); max_hdtheta=max(max_hdtheta,hdt); max_hderiv=max(max_hderiv,hdr)
    if hdh>1e-10 or hdt>1e-12:
        raise SystemExit(f"F_PE_ELASTIC59_FAIL stationary history gate case={case}")
    rz=ALPHA*bz/limit; rh=ALPHA*bh/limit
    zero_rat.append(rz); hist_rat.append(rh); by_se[se]["z"].append(rz); by_se[se]["h"].append(rh)
    if ALPHA*bz>limit*(1+1e-12): zero_fail+=1
    if ALPHA*bh>limit*(1+1e-12): hist_fail+=1
    if hinf>limit*(1+1e-12): real_fail+=1
    if bz>0:
        brel.append(abs(bh-bz)/bz)
    elif bh!=0:
        brel.append(math.inf)

print("F_PE_ELASTIC59_A1_HISTORY=PASS")
print("F_PE_ELASTIC59_A2_CURRENT_DOMAIN=PASS")
print("F_PE_ELASTIC59_A3_INDICATORS=PASS")
print(f"ELASTIC59_HISTORY_MAX_DH={max_hdh:.17e}")
print(f"ELASTIC59_HISTORY_MAX_DTHETA={max_hdtheta:.17e}")
print(f"ELASTIC59_HISTORY_MAX_DERIV={max_hderiv:.17e}")
print(f"ELASTIC59_ZERO_BRIDGE_FAILURES={zero_fail}")
print(f"ELASTIC59_HISTORY_BRIDGE_FAILURES={hist_fail}")
print(f"ELASTIC59_ZERO_MAX_BOUND_OVER_BUDGET={max(zero_rat):.17e}")
print(f"ELASTIC59_HISTORY_MAX_BOUND_OVER_BUDGET={max(hist_rat):.17e}")
print(f"ELASTIC59_MAX_REL_BINF_CHANGE={max(brel) if brel else 0.0:.17e}")
for se in sorted(by_se):
    print(f"ELASTIC59_SE|se={se:.2f}|zero_fail={sum(x>1+1e-12 for x in by_se[se]['z'])}|history_fail={sum(x>1+1e-12 for x in by_se[se]['h'])}|zero_max={max(by_se[se]['z']):.17e}|history_max={max(by_se[se]['h']):.17e}")
print(f"ELASTIC59_REALIZED_THRESHOLD_FAILURES={real_fail}")
if real_fail:
    raise SystemExit("F_PE_ELASTIC59_FAIL P2E09 realized threshold drift")
print("F_PE_ELASTIC59_A4_P2E09_REALIZED=PASS")
print(f"ELASTIC59_ALPHA_FROZEN={ALPHA:.17e}")
print("F_PE_ELASTIC59_A5_ALPHA_FROZEN=PASS")
print("F_PE_ELASTIC59_ATTRIBUTION=PASS")
PY

python3 - <<'PY'
import subprocess
base=subprocess.check_output(["git","merge-base","HEAD","origin/integration/f-ci-canonical"],text=True).strip()
bad=[p for p in subprocess.check_output(["git","diff","--name-only",base+"..HEAD"],text=True).splitlines() if p.startswith("src/") or p.startswith("reference/")]
if bad:
    raise SystemExit("F_PE_ELASTIC59_SOURCE_SCOPE_FAIL="+repr(bad))
print("F_PE_ELASTIC59_A7_SOURCE_SCOPE=PASS")
PY

echo "F_PE_ELASTIC59_RUN=PASS"

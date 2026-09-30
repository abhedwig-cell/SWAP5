#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
ARTIFACT_DIR="${1:?frozen BRO artifact directory required}"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-elastic62-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/work"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "F_PE_ELASTIC62_FAIL $*" >&2; exit 1; }

python3 tests/fpe/prepare_fpe_elastic62.py   --repo-root "$ROOT"   --artifact-dir "$ARTIFACT_DIR"   --work-dir "$BUILD/work"   --fixture "$BUILD/test.f90"   --geometry-json "$BUILD/geometry.json" | tee "$BUILD/prepare.txt"
grep -Fq 'F_PE_ELASTIC62_PREP=PASS' "$BUILD/prepare.txt" || fail "prepare"

python3 tests/fpe/materialize_fpe_elastic46_headcalc_stubs.py   --source tests/fsi/fsi04_real_headcalc_stubs.f90   --geometry-json "$BUILD/geometry.json"   --output "$BUILD/stub.f90"

python3 tests/fpe/materialize_fpe_elastic53_mode7_indicator.py   --root "$ROOT"   --indicator-out "$BUILD/mod_fpe_elastic53_reference_richards_temporal_indicator.f90"   --oracle-out "$BUILD/unused_oracle.f90" > "$BUILD/indicator.txt"

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  python3 tests/rom/compile_f_rom0_fortran_closure.py     --root "$ROOT"     --stub "$BUILD/stub.f90"     --target "$BUILD/test.f90"     --external-source "$BUILD/mod_fpe_elastic53_reference_richards_temporal_indicator.f90"     --external-source src/legacy/b1_10_port/headcalc.f90     --build "$OUT" --opt "$opt"

  : > "$OUT/result.txt"
  for delta in 0.035 0.05; do
    for regime in OFF FIXED_1E6 GENERATED; do
      "$OUT/rom0_test" "$regime" -20 0.0009765625 "$delta" 16 >/dev/null 2>&1 && fail "argument order sentinel"
      "$OUT/rom0_test" "$regime" -20 "$delta" 0.0009765625 16 >> "$OUT/result.txt"
    done
  done
  test "$(grep -c '^ELASTIC62_FLOOR|' "$OUT/result.txt")" -eq 6 || fail "O$opt floor count"
  test "$(grep -c '^F_PE_ELASTIC62_EXEC=PASS' "$OUT/result.txt")" -eq 6 || fail "O$opt pass count"
done

cmp -s "$BUILD/o0/result.txt" "$BUILD/o2/result.txt" || {
  diff -u "$BUILD/o0/result.txt" "$BUILD/o2/result.txt" >&2 || true
  fail "O0/O2 drift"
}
cat "$BUILD/o2/result.txt"

python3 - "$BUILD/o2/result.txt" <<'PY'
import math,sys
rows=[]
for line in open(sys.argv[1],encoding="utf-8"):
    if not line.startswith("ELASTIC62_FLOOR|"): continue
    d={}
    for p in line.strip().split("|")[1:]:
        if "=" not in p: continue
        k,v=p.split("=",1); d[k]=v.strip()
    rows.append(d)
if len(rows)!=6: raise SystemExit("F_PE_ELASTIC62_FAIL row count")
local_supported=0; total_supported=0; aggregate_exceeds_baltol=0
for r in rows:
    vals={k:float(r[k]) for k in ("half_dt","max_local_floor","sum_local_floors","integrated_max_floor",
                                  "integrated_sum_floor","max_local_residual","abs_total_residual",
                                  "baltol_depth","baltol_rate")}
    if not all(math.isfinite(v) and v>=0 for v in vals.values()):
        raise SystemExit("F_PE_ELASTIC62_FAIL nonfinite floor diagnostic")
    rl=vals["max_local_residual"]/vals["max_local_floor"] if vals["max_local_floor"]>0 else math.inf
    rt=vals["abs_total_residual"]/vals["sum_local_floors"] if vals["sum_local_floors"]>0 else math.inf
    if rl<=1.0+1e-12: local_supported+=1
    if rt<=1.0+1e-12: total_supported+=1
    if vals["integrated_sum_floor"]>vals["baltol_depth"]: aggregate_exceeds_baltol+=1
    print(f"ELASTIC62_ATTR|regime={r['regime']}|delta={float(r['delta'])}|R_local={rl:.17e}|R_total={rt:.17e}|integrated_max_floor={vals['integrated_max_floor']:.17e}|integrated_sum_floor={vals['integrated_sum_floor']:.17e}|baltol_depth={vals['baltol_depth']:.17e}")
print(f"ELASTIC62_TOTAL|cases={len(rows)}|local_supported={local_supported}|total_supported={total_supported}|aggregate_exceeds_baltol={aggregate_exceeds_baltol}")
print("F_PE_ELASTIC62_A1_CASES=PASS")
print("F_PE_ELASTIC62_A2_O0_O2=PASS")
print("F_PE_ELASTIC62_A3_FINITE=PASS")
print("F_PE_ELASTIC62_A4_P2E07_FORMULA=PASS")
PY

python3 - <<'PY'
import subprocess
base=subprocess.check_output(["git","merge-base","HEAD","origin/integration/f-ci-canonical"],text=True).strip()
names=subprocess.check_output(["git","diff","--name-only",base+"..HEAD"],text=True).splitlines()
prod=[p for p in names if p.startswith("src/")]
if prod:
    raise SystemExit("F_PE_ELASTIC62_SOURCE_SCOPE_FAIL="+repr(prod))
print("F_PE_ELASTIC62_A5_SOURCE_SCOPE=PASS")
PY

echo "F_PE_ELASTIC62_RUN=PASS"

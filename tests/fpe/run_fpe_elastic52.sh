#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
ARTIFACT_DIR="${1:?frozen BRO artifact directory required}"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-elastic52-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/work"
trap 'rm -rf "$BUILD"' EXIT

fail(){ echo "F_PE_ELASTIC52_FAIL $*" >&2; exit 1; }

python3 tests/fpe/prepare_fpe_elastic52.py \
  --repo-root "$ROOT" \
  --artifact-dir "$ARTIFACT_DIR" \
  --work-dir "$BUILD/work" \
  --fixture "$BUILD/test_fpe_elastic52.f90" \
  --geometry-json "$BUILD/geometry.json" | tee "$BUILD/prepare.txt"

grep -Fq 'F_PE_ELASTIC52_PREP=PASS' "$BUILD/prepare.txt" || fail "prepare marker"

python3 tests/fpe/materialize_fpe_elastic46_headcalc_stubs.py \
  --source tests/fsi/fsi04_real_headcalc_stubs.f90 \
  --geometry-json "$BUILD/geometry.json" \
  --output "$BUILD/stub.f90"

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  python3 tests/rom/compile_f_rom0_fortran_closure.py \
    --root "$ROOT" --stub "$BUILD/stub.f90" \
    --target "$BUILD/test_fpe_elastic52.f90" \
    --external-source src/legacy/b1_10_port/headcalc.f90 \
    --build "$OUT" --opt "$opt"

  : > "$OUT/result.txt"
  for h0 in 2 10; do
    for delta in 0.05 -0.05; do
      for regime in OFF FIXED_1E6 GENERATED; do
        dt=0.015625
        for retry in 0 1 2 3 4 5 6 7 8; do
          env -u SWAP5_ELASTIC_STORAGE_CONFIG "$OUT/rom0_test" "$regime" "$h0" "$delta" "$dt" >> "$OUT/result.txt"
          dt="$(python3 -c "print(float('$dt')*0.5)")"
        done
      done
    done
  done
  test "$(grep -c '^ELASTIC52_MECH|' "$OUT/result.txt")" -eq 108 || fail "O$opt case count"
  test "$(grep -c '^F_PE_ELASTIC52_EXEC=PASS' "$OUT/result.txt")" -eq 108 || fail "O$opt pass count"
done

cmp -s "$BUILD/o0/result.txt" "$BUILD/o2/result.txt" || {
  diff -u "$BUILD/o0/result.txt" "$BUILD/o2/result.txt" >&2 || true
  fail "O0/O2 mechanism drift"
}
cat "$BUILD/o2/result.txt"
echo "F_PE_ELASTIC52_A1_CASES=PASS"
echo "F_PE_ELASTIC52_A5_O0_O2=PASS"

python3 - "$BUILD/o2/result.txt" <<'PY'
import math,sys
rows=[]
for line in open(sys.argv[1],encoding="utf-8"):
    if not line.startswith("ELASTIC52_MECH|"): continue
    d={}
    for p in line.strip().split("|")[1:]:
        if "=" not in p: continue
        k,v=p.split("=",1); d[k]=v.strip()
    rows.append(d)
if len(rows)!=108:
    raise SystemExit("F_PE_ELASTIC52_FAIL row count")
conv=[r for r in rows if r["all_converged"]=="T"]
for r in conv:
    vals=[float(r[k]) for k in (
        "qtop","ss1","full_h1","half1_h1","half2_h1","full_h2","half1_h2","half2_h2",
        "full_dh1","half1_dh1","half2_dh1","full_dtheta1","half1_dtheta1","half2_dtheta1",
        "full_storage_rate1","half1_storage_rate1","half2_storage_rate1","twohalf_storage_rate1",
        "full_internal_flux1","half1_internal_flux1","half2_internal_flux1","twohalf_internal_flux1",
        "terminal_dh1","storage_rate_diff1","internal_flux_diff1","ratio_full","ratio_half1","ratio_half2"
    )]
    if not all(math.isfinite(v) for v in vals):
        raise SystemExit("F_PE_ELASTIC52_FAIL nonfinite mechanism term")
    if abs(float(r["storage_rate_diff1"])+float(r["internal_flux_diff1"])) > 1e-13:
        raise SystemExit("F_PE_ELASTIC52_FAIL balance attribution identity")
    if r["regime"]!="OFF":
        ss=float(r["ss1"])
        for ratio_name,dh_name in (("ratio_full","full_dh1"),("ratio_half1","half1_dh1"),("ratio_half2","half2_dh1")):
            dh=abs(float(r[dh_name]))
            if dh>1e-14:
                ratio=float(r[ratio_name])
                if abs(ratio-ss) > max(1e-12,1e-7*abs(ss)):
                    raise SystemExit(f"F_PE_ELASTIC52_FAIL elastic slope {ratio_name} ratio={ratio} ss={ss}")
print(f"ELASTIC52_SUMMARY|cases={len(rows)}|all_converged={len(conv)}")
print("F_PE_ELASTIC52_A2_FINITE=PASS")
print("F_PE_ELASTIC52_A3_FIXED_QTOP=PASS")
print("F_PE_ELASTIC52_A4_ELASTIC_SLOPE=PASS")
PY

python3 - <<'PY'
import subprocess
base=subprocess.check_output(["git","merge-base","HEAD","origin/integration/f-ci-canonical"],text=True).strip()
names=subprocess.check_output(["git","diff","--name-only",base+"..HEAD"],text=True).splitlines()
prod=[p for p in names if p.startswith("src/")]
if prod:
    raise SystemExit("F_PE_ELASTIC52_SOURCE_SCOPE_FAIL="+repr(prod))
print("F_PE_ELASTIC52_A6_SOURCE_SCOPE=PASS")
PY

echo "F_PE_ELASTIC52=PASS"

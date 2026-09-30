#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
ARTIFACT_DIR="${1:?frozen BRO artifact directory required}"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-elastic53-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/work"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "F_PE_ELASTIC53_FAIL $*" >&2; exit 1; }

python3 tests/fpe/materialize_fpe_elastic53_mode7_indicator.py \
  --root "$ROOT" \
  --indicator-out "$BUILD/mod_fpe_elastic53_reference_richards_temporal_indicator.f90" \
  --oracle-out "$BUILD/test_fpe_elastic53_mode7_oracle.f90" | tee "$BUILD/materialize.txt"
grep -Fq 'F_PE_ELASTIC53_MATERIALIZE=PASS' "$BUILD/materialize.txt" || fail "materialize"

# Use the exact variable grid for the real-profile bank.
python3 tests/fpe/prepare_fpe_elastic53.py \
  --repo-root "$ROOT" \
  --artifact-dir "$ARTIFACT_DIR" \
  --work-dir "$BUILD/work" \
  --fixture "$BUILD/test_fpe_elastic53_bank.f90" \
  --geometry-json "$BUILD/geometry.json" | tee "$BUILD/prepare.txt"
grep -Fq 'F_PE_ELASTIC53_PREP=PASS' "$BUILD/prepare.txt" || fail "prepare"

python3 tests/fpe/materialize_fpe_elastic46_headcalc_stubs.py \
  --source tests/fsi/fsi04_real_headcalc_stubs.f90 \
  --geometry-json "$BUILD/geometry.json" \
  --output "$BUILD/real_stub.f90"

# Independent mode-7 operator oracle uses the original FSI38 fixed stub.
for opt in 0 2; do
  OUT="$BUILD/oracle_o$opt"
  python3 tests/rom/compile_f_rom0_fortran_closure.py \
    --root "$ROOT" \
    --stub tests/fsi/fsi04_real_headcalc_stubs.f90 \
    --target "$BUILD/test_fpe_elastic53_mode7_oracle.f90" \
    --external-source "$BUILD/mod_fpe_elastic53_reference_richards_temporal_indicator.f90" \
    --external-source src/legacy/b1_10_port/headcalc.f90 \
    --build "$OUT" --opt "$opt"
  "$OUT/rom0_test" > "$OUT/result.txt"
  grep -Fq 'ELASTIC53_MODE7_TEMPORAL_ORACLE=PASS' "$OUT/result.txt" || {
    cat "$OUT/result.txt" >&2; fail "mode7 oracle O$opt";
  }
done
cmp -s "$BUILD/oracle_o0/result.txt" "$BUILD/oracle_o2/result.txt" || {
  diff -u "$BUILD/oracle_o0/result.txt" "$BUILD/oracle_o2/result.txt" >&2 || true
  fail "oracle O0/O2 drift"
}
cat "$BUILD/oracle_o2/result.txt"
echo "F_PE_ELASTIC53_A1_OPERATOR_ORACLE=PASS"

# Real BOFEK/BRO bank.
for opt in 0 2; do
  OUT="$BUILD/bank_o$opt"
  python3 tests/rom/compile_f_rom0_fortran_closure.py \
    --root "$ROOT" \
    --stub "$BUILD/real_stub.f90" \
    --target "$BUILD/test_fpe_elastic53_bank.f90" \
    --external-source "$BUILD/mod_fpe_elastic53_reference_richards_temporal_indicator.f90" \
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
  test "$(grep -c '^ELASTIC53_BANK|' "$OUT/result.txt")" -eq 108 || fail "bank count O$opt"
  test "$(grep -c '^F_PE_ELASTIC53_EXEC=PASS' "$OUT/result.txt")" -eq 108 || fail "bank pass count O$opt"
done
cmp -s "$BUILD/bank_o0/result.txt" "$BUILD/bank_o2/result.txt" || {
  diff -u "$BUILD/bank_o0/result.txt" "$BUILD/bank_o2/result.txt" >&2 || true
  fail "bank O0/O2 drift"
}
cat "$BUILD/bank_o2/result.txt"
echo "F_PE_ELASTIC53_A2_BANK_O0_O2=PASS"

python3 - "$BUILD/bank_o2/result.txt" <<'PY'
import math,sys
rows=[]
for line in open(sys.argv[1],encoding="utf-8"):
    if not line.startswith("ELASTIC53_BANK|"): continue
    d={}
    for p in line.strip().split("|")[1:]:
        if "=" not in p: continue
        k,v=p.split("=",1); d[k]=v.strip()
    rows.append(d)
if len(rows)!=108: raise SystemExit("F_PE_ELASTIC53_FAIL bank rows")
fullconv=[r for r in rows if int(r["full_status"])==1]
avail=[r for r in fullconv if r["indicator_available"]=="T"]
if len(avail)!=len(fullconv):
    raise SystemExit(f"F_PE_ELASTIC53_FAIL indicator availability {len(avail)}/{len(fullconv)}")
for r in avail:
    vals=[float(r[k]) for k in ("indicator_binf","indicator_raw","indicator_defect")]
    if not all(math.isfinite(v) and v>=0 for v in vals):
        raise SystemExit("F_PE_ELASTIC53_FAIL indicator finite")
paired=[r for r in avail if r["all_converged"]=="T"]
ratios=[]
for r in paired:
    h=float(r["dh_inf"]); b=float(r["indicator_binf"])
    if h>0: ratios.append(b/h)
print(f"ELASTIC53_SUMMARY|cases={len(rows)}|full_converged={len(fullconv)}|indicator_available={len(avail)}|paired_full_half={len(paired)}")
if ratios:
    print(f"ELASTIC53_BINF_OVER_HINF|min={min(ratios):.17e}|max={max(ratios):.17e}")
print("F_PE_ELASTIC53_A3_REAL_BANK=PASS")
PY

python3 - <<'PY'
import subprocess
base=subprocess.check_output(["git","merge-base","HEAD","origin/integration/f-ci-canonical"],text=True).strip()
names=subprocess.check_output(["git","diff","--name-only",base+"..HEAD"],text=True).splitlines()
prod=[p for p in names if p.startswith("src/")]
if prod:
    raise SystemExit("F_PE_ELASTIC53_SOURCE_SCOPE_FAIL="+repr(prod))
print("F_PE_ELASTIC53_A4_SOURCE_SCOPE=PASS")
PY
echo "F_PE_ELASTIC53=PASS"

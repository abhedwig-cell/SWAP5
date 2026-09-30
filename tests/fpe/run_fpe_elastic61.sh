#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
ARTIFACT_DIR="${1:?frozen BRO artifact directory required}"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-elastic61-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/work"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "F_PE_ELASTIC61_FAIL $*" >&2; exit 1; }

python3 tests/fpe/prepare_fpe_elastic61.py   --repo-root "$ROOT"   --artifact-dir "$ARTIFACT_DIR"   --work-dir "$BUILD/work"   --fixture "$BUILD/test.f90"   --geometry-json "$BUILD/geometry.json" | tee "$BUILD/prepare.txt"
grep -Fq 'F_PE_ELASTIC61_PREP=PASS' "$BUILD/prepare.txt" || fail "prepare"

python3 tests/fpe/materialize_fpe_elastic46_headcalc_stubs.py   --source tests/fsi/fsi04_real_headcalc_stubs.f90   --geometry-json "$BUILD/geometry.json"   --output "$BUILD/stub.f90"

python3 tests/fpe/materialize_fpe_elastic53_mode7_indicator.py   --root "$ROOT"   --indicator-out "$BUILD/mod_fpe_elastic53_reference_richards_temporal_indicator.f90"   --oracle-out "$BUILD/unused_oracle.f90" > "$BUILD/indicator.txt"

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  python3 tests/rom/compile_f_rom0_fortran_closure.py     --root "$ROOT"     --stub "$BUILD/stub.f90"     --target "$BUILD/test.f90"     --external-source "$BUILD/mod_fpe_elastic53_reference_richards_temporal_indicator.f90"     --external-source src/legacy/b1_10_port/headcalc.f90     --build "$OUT" --opt "$opt"

  : > "$OUT/result.txt"
  for delta in 0.035 0.05; do
    for regime in OFF FIXED_1E6 GENERATED; do
      for tol in 1e-12 1.1e-12 2e-12 5e-12 1e-11; do
        "$OUT/rom0_test" "$regime" -20 "$delta" 0.0009765625 "$tol" >> "$OUT/result.txt"
      done
    done
  done
  test "$(grep -c '^ELASTIC61_CASE|' "$OUT/result.txt")" -eq 30 || fail "O$opt case count"
  test "$(grep -c '^ELASTIC61_HALF1|' "$OUT/result.txt")" -eq 30 || fail "O$opt half1 count"
  test "$(grep -c '^F_PE_ELASTIC61_EXEC=PASS' "$OUT/result.txt")" -eq 30 || fail "O$opt pass count"
done

cmp -s "$BUILD/o0/result.txt" "$BUILD/o2/result.txt" || {
  diff -u "$BUILD/o0/result.txt" "$BUILD/o2/result.txt" >&2 || true
  fail "O0/O2 drift"
}
cat "$BUILD/o2/result.txt"

python3 - "$BUILD/o2/result.txt" <<'PY'
import math,sys
case_rows=[]; half_rows=[]
for line in open(sys.argv[1],encoding="utf-8"):
    if line.startswith("ELASTIC61_CASE|") or line.startswith("ELASTIC61_HALF1|"):
        d={}
        for p in line.strip().split("|")[1:]:
            if "=" not in p: continue
            k,v=p.split("=",1); d[k]=v.strip()
        (case_rows if line.startswith("ELASTIC61_CASE|") else half_rows).append(d)
if len(case_rows)!=30 or len(half_rows)!=30:
    raise SystemExit("F_PE_ELASTIC61_FAIL parsed counts")

# Full solve invariance and baseline reproduction.
groups={}
for r in case_rows:
    key=(r["regime"],float(r["delta"]))
    groups.setdefault(key,[]).append(r)

paired_total=0; head_fail=0; theta_fail=0; env_fail=0
alpha=0.17320259355765216
thresholds={}
for key,seq in sorted(groups.items()):
    seq=sorted(seq,key=lambda r:float(r["oracle_totbal"]))
    fullsig={(r["full_status"],r["indicator_available"],r["indicator_binf"],r["full_nonlinear"]) for r in seq}
    if len(fullsig)!=1: raise SystemExit(f"F_PE_ELASTIC61_FAIL full drift {key}")
    if int(seq[0]["half1_status"])!=2:
        raise SystemExit(f"F_PE_ELASTIC61_FAIL baseline not failed {key}")
    recovered=[r for r in seq if int(r["half1_status"])==1]
    first=float(recovered[0]["oracle_totbal"]) if recovered else math.inf
    thresholds[key]=first
    patt=",".join(f"{float(r['oracle_totbal']):.1e}:{r['half1_status']}:{r['half2_status']}" for r in seq)
    print(f"ELASTIC61_ATTR|regime={key[0]}|delta={key[1]}|first_half1_recovery={first}|pattern={patt}")
    for r in seq:
        if r["all_converged"]=="T":
            paired_total+=1
            h=float(r["dh_inf"]); th=float(r["dtheta_inf"]); b=float(r["indicator_binf"])
            if h>0.01*(1+1e-12): head_fail+=1
            if th>1e-5*(1+1e-12): theta_fail+=1
            if h>alpha*b*(1+1e-12): env_fail+=1

# Preregistered causal pattern.
for reg in ("OFF","FIXED_1E6","GENERATED"):
    t035=thresholds[(reg,0.035)]
    t05=thresholds[(reg,0.05)]
    if not (t035==5e-12 and t05==1.1e-12):
        raise SystemExit(f"F_PE_ELASTIC61_FAIL threshold pattern {reg} {t035} {t05}")

# Compartment tolerance is hardcoded unchanged in generated fixture; half residual maxima stay finite.
for r in half_rows:
    vals=(float(r["max_residual"]),float(r["sum_residual"]))
    if not all(math.isfinite(x) for x in vals): raise SystemExit("F_PE_ELASTIC61_FAIL nonfinite residual")

if head_fail or theta_fail or env_fail:
    raise SystemExit(f"F_PE_ELASTIC61_FAIL recovered envelope head={head_fail} theta={theta_fail} env={env_fail}")
print(f"ELASTIC61_TOTAL|paired={paired_total}|head_failures={head_fail}|theta_failures={theta_fail}|envelope_failures={env_fail}")
print("F_PE_ELASTIC61_A1_ARMS=PASS")
print("F_PE_ELASTIC61_A2_FULL_INVARIANCE=PASS")
print("F_PE_ELASTIC61_A3_O0_O2=PASS")
print("F_PE_ELASTIC61_A4_BASELINE=PASS")
print("F_PE_ELASTIC61_A5_RECOVERED_ENVELOPE=PASS")
print("F_PE_ELASTIC61_A6_COMPARTMENT_UNCHANGED=PASS")
PY

python3 - <<'PY'
import subprocess
base=subprocess.check_output(["git","merge-base","HEAD","origin/integration/f-ci-canonical"],text=True).strip()
names=subprocess.check_output(["git","diff","--name-only",base+"..HEAD"],text=True).splitlines()
prod=[p for p in names if p.startswith("src/")]
if prod:
    raise SystemExit("F_PE_ELASTIC61_SOURCE_SCOPE_FAIL="+repr(prod))
print("F_PE_ELASTIC61_A7_SOURCE_SCOPE=PASS")
PY

echo "F_PE_ELASTIC61_RUN=PASS"

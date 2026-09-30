#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
ARTIFACT_DIR="${1:?frozen BRO artifact directory required}"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-elastic59-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/work"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "F_PE_ELASTIC59_FAIL $*" >&2; exit 1; }

python3 tests/fpe/prepare_fpe_elastic59.py   --repo-root "$ROOT"   --artifact-dir "$ARTIFACT_DIR"   --work-dir "$BUILD/work"   --fixture "$BUILD/test.f90"   --geometry-json "$BUILD/geometry.json" | tee "$BUILD/prepare.txt"
grep -Fq 'F_PE_ELASTIC59_PREP=PASS' "$BUILD/prepare.txt" || fail "prepare"

python3 tests/fpe/materialize_fpe_elastic46_headcalc_stubs.py   --source tests/fsi/fsi04_real_headcalc_stubs.f90   --geometry-json "$BUILD/geometry.json"   --output "$BUILD/stub.f90"

python3 tests/fpe/materialize_fpe_elastic53_mode7_indicator.py   --root "$ROOT"   --indicator-out "$BUILD/mod_fpe_elastic53_reference_richards_temporal_indicator.f90"   --oracle-out "$BUILD/unused_oracle.f90" > "$BUILD/indicator.txt"

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  python3 tests/rom/compile_f_rom0_fortran_closure.py     --root "$ROOT"     --stub "$BUILD/stub.f90"     --target "$BUILD/test.f90"     --external-source "$BUILD/mod_fpe_elastic53_reference_richards_temporal_indicator.f90"     --external-source src/legacy/b1_10_port/headcalc.f90     --build "$OUT" --opt "$opt"

  : > "$OUT/result.txt"
  for delta in 0.035 0.05; do
    for regime in OFF FIXED_1E6 GENERATED; do
      for maxit in 16 32 64 128; do
        "$OUT/rom0_test" "$regime" -20 "$delta" 0.0009765625 "$maxit" >> "$OUT/result.txt"
      done
    done
  done
  test "$(grep -c '^ELASTIC59_CASE|' "$OUT/result.txt")" -eq 24 || fail "O$opt case count"
  test "$(grep -c '^F_PE_ELASTIC59_EXEC=PASS' "$OUT/result.txt")" -eq 24 || fail "O$opt pass count"
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
    if not line.startswith("ELASTIC59_CASE|"): continue
    d={}
    for p in line.strip().split("|")[1:]:
        if "=" not in p: continue
        k,v=p.split("=",1); d[k]=v.strip()
    rows.append(d)
if len(rows)!=24: raise SystemExit("F_PE_ELASTIC59_FAIL row count")

cases={}
for r in rows:
    key=(r["regime"],float(r["delta"]))
    cases.setdefault(key,[]).append(r)

oracle_limit=0
persistent=0
mixed=0
paired_total=0
head_fail=0
theta_fail=0

for key,seq in sorted(cases.items()):
    seq=sorted(seq,key=lambda r:int(r["oracle_maxit"]))
    # Full solve must be converged and independent of oracle maxit.
    if any(int(r["full_status"])!=1 for r in seq):
        raise SystemExit(f"F_PE_ELASTIC59_FAIL full not converged {key}")
    full_sig={(r["full_status"],r["indicator_available"],r["indicator_binf"],r["full_nonlinear"]) for r in seq}
    if len(full_sig)!=1:
        raise SystemExit(f"F_PE_ELASTIC59_FAIL full semantics drift {key} {full_sig}")
    paired=[r["all_converged"]=="T" for r in seq]
    if paired[0]:
        raise SystemExit(f"F_PE_ELASTIC59_FAIL baseline unexpectedly paired {key}")
    indices=[i for i,x in enumerate(paired) if x]
    if not indices:
        cls="PERSISTENT_HALF_SOLVE_FAILURE"; persistent+=1
    else:
        first=indices[0]
        if all(paired[i] for i in range(first,len(paired))):
            cls="ORACLE_BUDGET_LIMIT"; oracle_limit+=1
        else:
            cls="MIXED"; mixed+=1
    print(f"ELASTIC59_ATTR|regime={key[0]}|delta={key[1]}|class={cls}|paired_pattern={','.join('T' if x else 'F' for x in paired)}")
    for r in seq:
        if r["all_converged"]=="T":
            paired_total+=1
            h=float(r["dh_inf"]); th=float(r["dtheta_inf"])
            if h>0.01*(1+1e-12): head_fail+=1
            if th>1e-5*(1+1e-12): theta_fail+=1

print(f"ELASTIC59_TOTAL|cases={len(cases)}|oracle_budget_limit={oracle_limit}|persistent={persistent}|mixed={mixed}|paired_observations={paired_total}|head_failures={head_fail}|theta_failures={theta_fail}")
if head_fail or theta_fail:
    raise SystemExit("F_PE_ELASTIC59_FAIL recovered oracle physical envelope")
print("F_PE_ELASTIC59_A1_SIX_CASES=PASS")
print("F_PE_ELASTIC59_A2_FULL_INVARIANCE=PASS")
print("F_PE_ELASTIC59_A3_O0_O2=PASS")
print("F_PE_ELASTIC59_A4_RECOVERED_ENVELOPE=PASS")
PY

python3 - <<'PY'
import subprocess
base=subprocess.check_output(["git","merge-base","HEAD","origin/integration/f-ci-canonical"],text=True).strip()
names=subprocess.check_output(["git","diff","--name-only",base+"..HEAD"],text=True).splitlines()
prod=[p for p in names if p.startswith("src/")]
if prod:
    raise SystemExit("F_PE_ELASTIC59_SOURCE_SCOPE_FAIL="+repr(prod))
print("F_PE_ELASTIC59_A5_SOURCE_SCOPE=PASS")
PY

echo "F_PE_ELASTIC59_RUN=PASS"

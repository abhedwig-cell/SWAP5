#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
ARTIFACT_DIR="${1:?frozen BRO artifact directory required}"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-elastic60-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/work"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "F_PE_ELASTIC60_FAIL $*" >&2; exit 1; }

python3 tests/fpe/prepare_fpe_elastic60.py   --repo-root "$ROOT"   --artifact-dir "$ARTIFACT_DIR"   --work-dir "$BUILD/work"   --fixture "$BUILD/test.f90"   --geometry-json "$BUILD/geometry.json" | tee "$BUILD/prepare.txt"
grep -Fq 'F_PE_ELASTIC60_PREP=PASS' "$BUILD/prepare.txt" || fail "prepare"

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
  test "$(grep -c '^ELASTIC60_POST|' "$OUT/result.txt")" -eq 24 || fail "O$opt post count"
  test "$(grep -c '^F_PE_ELASTIC60_EXEC=PASS' "$OUT/result.txt")" -eq 24 || fail "O$opt pass count"
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
    if not line.startswith("ELASTIC60_POST|"): continue
    d={}
    for p in line.strip().split("|")[1:]:
        if "=" not in p: continue
        k,v=p.split("=",1); d[k]=v.strip()
    rows.append(d)
if len(rows)!=24:
    raise SystemExit("F_PE_ELASTIC60_FAIL row count")

groups={}
for r in rows:
    key=(r["regime"],float(r["delta"]))
    groups.setdefault(key,[]).append(r)

for key,seq in sorted(groups.items()):
    seq=sorted(seq,key=lambda r:int(r["oracle_maxit"]))
    if any(int(r["status"])!=2 for r in seq):
        raise SystemExit(f"F_PE_ELASTIC60_FAIL persistent pattern {key}")
    vals=[]
    for r in seq:
        nums=[float(r[k]) for k in ("max_residual","sum_residual","l2_residual","max_last_dh","h_min","h_max",
                                    "capacity_min","capacity_max","k_min","k_max")]
        if not all(math.isfinite(x) for x in nums):
            raise SystemExit(f"F_PE_ELASTIC60_FAIL nonfinite {key}")
        vals.append((int(r["oracle_maxit"]),float(r["max_residual"]),float(r["max_last_dh"]),
                     int(r["backtracking"]),int(r["alternative"]),int(r["internal_retries"]),
                     int(r["saturated_nodes"])))
    r16=vals[0][1]; r128=vals[-1][1]
    improvement=(r16/r128) if r128>0 else math.inf
    backratio=(vals[-1][3]/vals[-1][0]) if vals[-1][0]>0 else math.nan
    print(f"ELASTIC60_ATTR|regime={key[0]}|delta={key[1]}|residual16={r16:.17e}|residual128={r128:.17e}|residual_improvement={improvement:.17e}|last_dh128={vals[-1][2]:.17e}|backtracking_per_iter128={backratio:.17e}|alternative128={vals[-1][4]}|internal_retries128={vals[-1][5]}|saturated_nodes128={vals[-1][6]}")

print("F_PE_ELASTIC60_A1_CASES=PASS")
print("F_PE_ELASTIC60_A3_O0_O2=PASS")
print("F_PE_ELASTIC60_A4_FINITE=PASS")
print("F_PE_ELASTIC60_A5_PERSISTENT=PASS")
PY

python3 - <<'PY'
import subprocess
base=subprocess.check_output(["git","merge-base","HEAD","origin/integration/f-ci-canonical"],text=True).strip()
names=subprocess.check_output(["git","diff","--name-only",base+"..HEAD"],text=True).splitlines()
prod=[p for p in names if p.startswith("src/")]
if prod:
    raise SystemExit("F_PE_ELASTIC60_SOURCE_SCOPE_FAIL="+repr(prod))
print("F_PE_ELASTIC60_A6_SOURCE_SCOPE=PASS")
PY

echo "F_PE_ELASTIC60_RUN=PASS"

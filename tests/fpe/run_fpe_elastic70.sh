#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
ARTIFACT_DIR="${1:?frozen BRO artifact directory required}"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-elastic70-${GITHUB_RUN_ID:-local}-$"
mkdir -p "$BUILD/profile"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "F_PE_ELASTIC70_FAIL $*" >&2; exit 1; }

python3 tests/rom/materialize_f_rom0_headcalc_stubs.py   --source tests/fsi/fsi04_real_headcalc_stubs.f90   --output "$BUILD/stub.f90" --nodes 16 --dz-cm 10

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  python3 tests/rom/compile_f_rom0_fortran_closure.py     --root "$ROOT" --stub "$BUILD/stub.f90"     --target tests/fpe/test_fpe_elastic70_production_transaction_performance.f90     --external-source src/legacy/b1_10_port/headcalc.f90     --build "$OUT" --opt "$opt"
  (cd "$BUILD/profile" && env -u SWAP5_ELASTIC_STORAGE_CONFIG "$OUT/rom0_test") | tee "$OUT/result.txt"
  grep -Fq 'F_PE_ELASTIC70_A1_GENERATED=PASS' "$OUT/result.txt" || fail "generated O$opt"
  grep -Fq 'F_PE_ELASTIC70_A2_TRANSACTION_WORK=PASS' "$OUT/result.txt" || fail "work O$opt"
  grep -Fq 'F_PE_ELASTIC70=PASS' "$OUT/result.txt" || fail "result O$opt"
  grep -Ev '^ELASTIC70_RUNTIME\|' "$OUT/result.txt" > "$OUT/deterministic.txt"
done

cmp -s "$BUILD/o0/deterministic.txt" "$BUILD/o2/deterministic.txt" || {
  diff -u "$BUILD/o0/deterministic.txt" "$BUILD/o2/deterministic.txt" >&2 || true
  fail "O0/O2 deterministic drift"
}
echo "F_PE_ELASTIC70_A3_O0_O2=PASS"

python3 - "$BUILD/o2/result.txt" <<'PY'
import re,sys
text=open(sys.argv[1],encoding="utf-8").read()
m=re.search(r'^ELASTIC70_TOTAL\|(.*)$',text,re.M)
if not m: raise SystemExit("missing total")
d={}
for p in m.group(1).split("|"):
    k,v=p.split("=",1); d[k]=int(v)
if d["policy_completed"] < d["strict_completed"]:
    raise SystemExit("completion regression")
if d["policy_retries"] > d["strict_retries"]:
    raise SystemExit("retry regression")
if not (d["policy_completed"] > d["strict_completed"] or d["policy_retries"] < d["strict_retries"]):
    raise SystemExit("no deterministic work benefit")
rm=re.search(r'^ELASTIC70_RUNTIME\|(.*)$',text,re.M)
if not rm: raise SystemExit("missing runtime")
rd={}
for p in rm.group(1).split("|"):
    k,v=p.split("=",1); rd[k]=v
print("ELASTIC70_SUMMARY|strict_completed=%d|policy_completed=%d|strict_retries=%d|policy_retries=%d|runtime_ratio=%s" %
      (d["strict_completed"],d["policy_completed"],d["strict_retries"],d["policy_retries"],rd["ratio"]))
print("F_PE_ELASTIC70_A4_SUMMARY=PASS")
PY

python3 - <<'PY'
import subprocess
base=subprocess.check_output(["git","merge-base","HEAD","origin/integration/f-ci-canonical"],text=True).strip()
prod=[p for p in subprocess.check_output(["git","diff","--name-only",base+"..HEAD","--","src"],text=True).splitlines() if p]
if prod:
    raise SystemExit("F_PE_ELASTIC70_SOURCE_SCOPE_FAIL="+repr(prod))
print("F_PE_ELASTIC70_A5_SOURCE_SCOPE=PASS")
PY

echo "F_PE_ELASTIC70_RUN=PASS"

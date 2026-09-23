#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-rm22-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "RM22_FAIL $*" >&2; exit 1; }

TX=src/transaction/mod_transaction_reference.f90
RT=src/runtime/mod_canonical_interval_runtime.f90
grep -Fq 'real(real64) :: max_temporal_indicator = 0.0_real64' "$TX" || fail "retry-complete field missing"
grep -Fq 'result%max_temporal_indicator = max(result%max_temporal_indicator,outcome%temporal_indicator)' "$TX" || fail "attempt maximum update missing"
grep -Fq 'tx%max_temporal_indicator' "$RT" || fail "canonical runtime not bound to retry-complete maximum"
grep -Fq 'result%temporal_indicator = outcome%temporal_indicator' "$TX" || fail "terminal indicator provenance was not preserved"
echo 'RM22_STATIC_DIAGNOSTIC_BINDING=PASS'

TX_COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -Wno-error=compare-reals -fcheck=all -fbacktrace)
for opt in 0 2; do
  OUT="$BUILD/tx_o$opt"; mkdir -p "$OUT"
  gfortran "${TX_COMMON[@]}" -O"$opt" -J "$OUT"     src/transaction/mod_transaction_reference.f90 tests/ribasim-management/test_rm22_retry_max.f90     -o "$OUT/test" || fail "targeted transaction compile O$opt"
  "$OUT/test" > "$OUT/output.txt" || { cat "$OUT/output.txt" >&2; fail "targeted transaction O$opt"; }
  grep -Fq 'RM22_RETRY_COMPLETE_DIAGNOSTIC=PASS' "$OUT/output.txt" || fail "targeted diagnostic O$opt"
done
cmp "$BUILD/tx_o0/output.txt" "$BUILD/tx_o2/output.txt" || fail "targeted transaction O0/O2 drift"
cat "$BUILD/tx_o0/output.txt"
echo 'RM22_TRANSACTION_ACCEPTANCE_REGRESSION=PASS'

bash tests/ribasim-management/run_rm21_temporal_attempt_provenance.sh | tee "$BUILD/rm21.txt"
grep -Fq 'RM21_TEMPORAL_ATTEMPT_PROVENANCE_GATE=PASS' "$BUILD/rm21.txt" || fail "RM21 retry ladder regression"

python3 - "$BUILD/rm21.txt" <<'PY'
import re,sys
text=open(sys.argv[1],encoding="utf-8").read()
def v(name):
    m=re.search(rf"^{re.escape(name)}=\s*([0-9.Ee+-]+)",text,re.M)
    if not m: raise SystemExit(f"missing {name}")
    return float(m.group(1))
full=v("RM21_ATTEMPT_1_NORMALIZED_INDICATOR")
terminal=v("RM21_ATTEMPT_3_NORMALIZED_INDICATOR")
reported=v("RM21_RM19_REPORTED")
assert abs(full-361493.0146731796) <= 1e-8*full, full
assert abs(terminal-reported) <= 1e-10*reported, (terminal,reported)
assert full > terminal
print(f"RM22_EXPECTED_RETRY_COMPLETE_MAX={full:.17g}")
print(f"RM22_TERMINAL_INDICATOR_PRESERVED={terminal:.17g}")
print("RM22_FROZEN_RM19_DIAGNOSTIC_EXPECTATION=PASS")
PY

echo 'RM22_TEMPORAL_DIAGNOSTIC_REPAIR_GATE=PASS'

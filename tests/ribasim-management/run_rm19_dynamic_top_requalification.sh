#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-rm19-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "RM19_FAIL $*" >&2; exit 1; }

# RM18 authority must be present and bounded.
INDICATOR=src/solver/mod_reference_richards_temporal_indicator.f90
grep -Fq 'reference-dynamic-flux-' "$INDICATOR" || fail "RM18 dynamic-flux route missing"
grep -Fq 'dynamic-flux-envelope-deferred' "$INDICATOR" || fail "RM18 fail-closed route missing"
echo 'RM19_RM18_AUTHORITY_BOUND=PASS'

bash tests/ribasim-management/run_rm14_dynamic_top_predictor.sh | tee "$BUILD/rm14.txt"
grep -Fq 'RM14_DYNAMIC_TOP_PREDICTOR=PASS' "$BUILD/rm14.txt" || fail "unchanged RM14 predictor did not pass"
grep -Fq 'RM14_DYNAMIC_TOP_PREDICTOR_GATE=PASS' "$BUILD/rm14.txt" || fail "unchanged RM14 gate marker missing"

python3 - "$BUILD/rm14.txt" <<'PY'
import ast,re,sys
text=open(sys.argv[1],encoding="utf-8").read()
m=re.search(r"RM14_PREDICTOR_DIAGNOSTICS=(\{.*\})",text)
if not m:
    raise SystemExit("missing predictor diagnostics")
d=ast.literal_eval(m.group(1))
assert d["completed"] is True, d
assert d["accepted_substeps"] >= 1, d
assert d["mass_rejections"] == 0, d
assert d["temporal_unavailable_rejections"] == 0, d
print(f"RM19_ACCEPTED_SUBSTEPS={d['accepted_substeps']}")
print(f"RM19_ATTEMPTS={d['attempts']}")
print(f"RM19_RETRIES={d['retries']}")
print(f"RM19_SOLVER_REJECTIONS={d['solver_rejections']}")
print(f"RM19_TEMPORAL_REJECTIONS={d['temporal_rejections']}")
print(f"RM19_MAX_TEMPORAL_INDICATOR={d['max_temporal_indicator']:.17g}")
PY

echo 'RM19_UNCHANGED_DYNAMIC_TOP_TRANSACTION=PASS'

#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
TMP="$(mktemp tests/fkt/.run_fkt11_owner_ci_XXXXXX.sh)"
trap 'rm -f "$TMP"' EXIT
cp tests/fkt/run_fkt11_richards_head_budget_policy.sh "$TMP"
python3 - "$TMP" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text()
old="grep -Fq 'FKT09_MODEL_CERTIFICATE_RUNNER PASS' \"$BUILD/fkt09.txt\""
new="grep -Fq 'FKT09_MODEL_CERTIFICATE_GATE=PASS' \"$BUILD/fkt09.txt\""
assert s.count(old)==1, 'F-KT11 F-KT09 marker patch drift'
s=s.replace(old,new,1)
old_fmt="""assert 'FKT11_CH= 5.00000000000000000E-001' in s or 'FKT11_CH= 5.000000000000' in s
assert 'FKT11_CH= 2.00000000000000000E+000' in s or 'FKT11_CH= 2.000000000000' in s"""
new_fmt="""# VALID_ACCEPT and VALID_REJECT already assert C_h numerically in the
# compiled owner driver. Keep this parser diagnostic-only and independent of
# compiler-specific ES exponent formatting.
assert s.count('FKT11_CH=') == 6"""
assert s.count(old_fmt)==1, 'F-KT11 C_h formatting guard patch drift'
s=s.replace(old_fmt,new_fmt,1)
old_source="""assert 'self%temporal_indicator_budget_supplied = config%model_temporal_indicator_budget_available' in backend
assert 'ieee_is_finite(config%model_temporal_indicator_budget)' in backend
assert 'config%model_temporal_indicator_budget > 0.0_real64' in backend"""
new_source="""assert 'self%temporal_indicator_budget_supplied = config%model_temporal_indicator_budget_available' in backend
assert 'self%temporal_indicator_budget_valid = .false.' in backend
assert 'self%temporal_indicator_budget = config%model_temporal_indicator_budget' in backend
assert 'ieee_is_finite(self%temporal_indicator_budget)' in backend
assert 'self%temporal_indicator_budget_valid = self%temporal_indicator_budget > 0.0_real64' in backend"""
assert s.count(old_source)==1, 'F-KT11 remediated validity source guard patch drift'
s=s.replace(old_source,new_source,1)
p.write_text(s)
PY
bash "$TMP"

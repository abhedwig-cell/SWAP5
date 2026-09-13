#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BASE="0181b7b674cc89d729e361dafc1135b719e23a7d"
cd "$ROOT"

fail() { echo "EB_I16_GATE_FAIL $*" >&2; exit 96; }

# Preserve the existing production authorities byte-for-byte.
[[ "$(git rev-parse HEAD:src/runtime/mod_fmr_bottom_thermal_carrier.f90)" == "c371be3e22eaa6da70ca8cbb060bc42d1e0e0bfb" ]] || \
  fail 'EB-I13 thermal carrier authority drift'
[[ "$(git rev-parse HEAD:src/runtime/mod_groundwater_coupling_contract.f90)" == "fc598d14eabafcb025bb55621f7b00d6d1816f10" ]] || \
  fail 'groundwater coupling contract authority drift'
[[ "$(git rev-parse HEAD:src/runtime/mod_groundwater_exchange_service_contract.f90)" == "f0fc25592624360802713a9487813d119e7dc4e9" ]] || \
  fail 'groundwater exchange service authority drift'
echo 'EB_I16_PRODUCTION_AUTHORITIES_BYTE_IDENTICAL=PASS'

python3 - <<'PY'
from pathlib import Path
import json

contract = Path('tests/eb/EB-I16_CONTRACT.md').read_text()
required = [
    'sole mass authority',
    'opaque accepted-candidate lineage identity',
    'one-based accepted thermal sample ordinal',
    'MUST NOT be treated as a sufficient binding key',
    'provider/coupler SHALL supply an already-qualified scalar donor temperature',
    'MUST NOT be silently reused',
    'exactly one matching binding is required',
    'duplicate bindings are invalid',
    'stale or foreign-lineage bindings are invalid',
    'Exact zero transfer requires no donor binding',
    'MUST NOT retroactively reject, mutate, or recommit',
    'MODFLOW',
    'deep-vadose',
    'does not retrofit a token into production types',
]
for token in required:
    if token not in contract:
        raise SystemExit(f'EB_I16_GATE_FAIL contract token missing: {token}')

for forbidden_claim in [
    'MODFLOW supplies the donor temperature',
    'use local bottom temperature as fallback',
    'T_ref as fallback',
]:
    if forbidden_claim in contract:
        raise SystemExit(f'EB_I16_GATE_FAIL forbidden contract claim present: {forbidden_claim}')

audit = json.loads(Path('tests/eb/EB-I16_ARCHITECTURE_AUDIT.json').read_text())
if audit.get('scope') != 'DESIGN_ONLY_EXTERNAL_BOTTOM_THERMAL_BINDING_NO_PRODUCTION_DELTA':
    raise SystemExit('EB_I16_GATE_FAIL architecture scope drift')
items = audit.get('invariants', [])
ids = [item.get('id') for item in items]
if ids != list(range(1, 31)):
    raise SystemExit(f'EB_I16_GATE_FAIL architecture IDs not exactly 1..30: {ids}')
if any(item.get('status') not in ('pass', 'preserved') for item in items):
    raise SystemExit('EB_I16_GATE_FAIL unresolved architecture invariant')

status = json.loads(Path('tests/eb/EB-I16_STATUS.json').read_text())
if status.get('decision') != 'DESIGN_FROZEN_NO_PRODUCTION_IMPLEMENTATION':
    raise SystemExit('EB_I16_GATE_FAIL status decision drift')
if status.get('qualification_state') != 'QUALIFIED_WHEN_EXACT_UNCHANGED_HEAD_WORKFLOW_SUCCEEDS':
    raise SystemExit('EB_I16_GATE_FAIL qualification-state drift')
if status.get('production_source_changed') is not False or status.get('mass_authority_changed') is not False:
    raise SystemExit('EB_I16_GATE_FAIL forbidden production or mass authority change declared')

print('EB_I16_CONTRACT_STATIC=PASS')
print('EB_I16_ARCHITECTURE_INVARIANTS_1_30=PASS')
print('EB_I16_GOVERNANCE_DISPOSITION=PASS')
PY

# Adversarial executable model of the frozen identity and fail-closed semantics.
python3 - <<'PY'
import math

EXTERNAL = 'external'
LOCAL = 'local'
ZERO = 'zero'
K = 0.01 * 1000.0 * 4180.0
TREF = 5.0

def evaluate(lineage, samples, bindings):
    # bindings are tuples (lineage, one_based_ordinal, donor_temp_c)
    seen = set()
    by_key = {}
    for b_lineage, ordinal, temp in bindings:
        if b_lineage != lineage:
            return 'invalid', None
        key = (b_lineage, ordinal)
        if key in seen:
            return 'invalid', None
        seen.add(key)
        if ordinal < 1 or ordinal > len(samples):
            return 'invalid', None
        donor, q = samples[ordinal - 1]
        if donor != EXTERNAL or not q < 0.0:
            return 'invalid', None
        if not math.isfinite(temp):
            return 'invalid', None
        by_key[key] = temp

    total = 0.0
    for ordinal, (donor, q) in enumerate(samples, 1):
        if donor == EXTERNAL:
            if not q < 0.0:
                return 'invalid', None
            key = (lineage, ordinal)
            if key not in by_key:
                return 'incomplete', None
            total += K * q * (by_key[key] - TREF)
        elif donor == LOCAL:
            if not q > 0.0:
                return 'invalid', None
            # Local energy is intentionally outside this binding model.
        elif donor == ZERO:
            if q != 0.0:
                return 'invalid', None
        else:
            return 'invalid', None
    return 'complete', total

samples = [(EXTERNAL, -0.10), (EXTERNAL, -0.20), (ZERO, 0.0)]
lineage = 'candidate-A'
status, energy = evaluate(lineage, samples, [(lineage, 1, 10.0), (lineage, 2, 20.0)])
assert status == 'complete'
expected = K * (-0.10) * (10.0 - TREF) + K * (-0.20) * (20.0 - TREF)
assert energy == expected
# A silently reused coupling-window scalar is not equivalent in the adversarial case.
window_scalar_energy = K * (-0.10) * (20.0 - TREF) + K * (-0.20) * (20.0 - TREF)
assert energy != window_scalar_energy
print('EB_I16_SAMPLE_RESOLVED_NOT_WINDOW_SCALAR=PASS')

assert evaluate(lineage, samples, [(lineage, 1, 10.0)])[0] == 'incomplete'
print('EB_I16_MISSING_BINDING_FAIL_CLOSED=PASS')

assert evaluate(lineage, samples, [(lineage, 1, 10.0), (lineage, 1, 10.0), (lineage, 2, 20.0)])[0] == 'invalid'
print('EB_I16_DUPLICATE_BINDING_REJECTED=PASS')

assert evaluate(lineage, samples, [('candidate-stale', 1, 10.0), (lineage, 2, 20.0)])[0] == 'invalid'
print('EB_I16_STALE_LINEAGE_REJECTED=PASS')

assert evaluate(lineage, samples, [(lineage, 1, 10.0), (lineage, 4, 20.0)])[0] == 'invalid'
print('EB_I16_WRONG_ORDINAL_REJECTED=PASS')

assert evaluate(lineage, [(ZERO, 0.0)], [])[0] == 'complete'
assert evaluate(lineage, [(ZERO, 0.0)], [(lineage, 1, 10.0)])[0] == 'invalid'
print('EB_I16_EXACT_ZERO_NO_BINDING=PASS')

assert evaluate(lineage, [(LOCAL, 0.1)], [(lineage, 1, 10.0)])[0] == 'invalid'
assert evaluate(lineage, [(EXTERNAL, -0.1)], [(lineage, 1, float('nan'))])[0] == 'invalid'
print('EB_I16_WRONG_CLASS_AND_NONFINITE_REJECTED=PASS')

# Same interval is deliberately absent from the binding key: lineage distinguishes candidates.
assert evaluate('candidate-B', [(EXTERNAL, -0.1)], [('candidate-A', 1, 10.0)])[0] == 'invalid'
print('EB_I16_INTERVAL_ONLY_IDENTITY_FORBIDDEN=PASS')
print('EB_I16_ADVERSARIAL_BINDING_MODEL=PASS')
PY

# Design-only exact scope: no production source changes are allowed.
if git diff --name-only "$BASE"..HEAD | grep -q '^src/'; then
  git diff --name-only "$BASE"..HEAD >&2
  fail 'production source delta present'
fi
echo 'EB_I16_NO_PRODUCTION_SOURCE_DELTA=PASS'

while IFS= read -r path; do
  [[ -z "$path" ]] && continue
  case "$path" in
    tests/eb/EB-I16_CONTRACT.md|\
    tests/eb/EB-I16_ARCHITECTURE_AUDIT.json|\
    tests/eb/EB-I16_STATUS.json|\
    tests/eb/EB-I16_CLOSURE.md|\
    tests/eb/run_eb_i16_external_binding_contract_gate.sh|\
    .github/workflows/eb-i16-contract.yml)
      ;;
    *) fail "unexpected EB-I16 branch delta: $path" ;;
  esac
done < <(git diff --name-only "$BASE"..HEAD)

echo 'EB_I16_EXACT_SCOPE_ALLOWLIST=PASS'
git diff --check "$BASE"..HEAD || fail 'branch whitespace check'
echo 'EB_I16_EXTERNAL_BOTTOM_THERMAL_BINDING_CONTRACT_GATE=PASS'

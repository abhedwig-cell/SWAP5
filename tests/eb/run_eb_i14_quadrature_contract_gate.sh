#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BASE="c3458c3df0428de0f2500e211391122c64c2de33"

fail() { echo "EB_I14_GATE_FAIL $*" >&2; exit 94; }

python3 - <<'PY'
from pathlib import Path
import json
import math

contract = Path('tests/eb/EB-I14_CONTRACT.md').read_text()
audit = json.loads(Path('tests/eb/EB-I14_ARCHITECTURE_AUDIT.json').read_text())

required = [
    'DESIGN_FROZEN_NO_PRODUCTION_IMPLEMENTATION',
    'Q_b = - q_b,end * Delta_t',
    'T_adv = T_bottom,end',
    'E_b = K_w * Q_b * (T_adv - T_ref)',
    'There is no small-transfer tolerance.',
    'aggregate outer-interval water multiplied by the final outer bottom temperature',
    'arithmetic mean of `T_bottom,start` and `T_bottom,end`',
    'first-order current-reference temporal accounting rule',
    'missing energy provenance does not retroactively invalidate an otherwise mass-conserving accepted hydrologic transaction',
]
for token in required:
    if token not in contract:
        raise SystemExit(f'EB_I14_GATE_FAIL missing frozen contract token: {token}')

items = audit.get('invariants', [])
ids = [item.get('id') for item in items]
if ids != list(range(1, 31)):
    raise SystemExit(f'EB_I14_GATE_FAIL architecture invariant ids are not exactly 1..30: {ids}')
if any(item.get('status') not in ('pass', 'preserved') for item in items):
    raise SystemExit('EB_I14_GATE_FAIL architecture audit contains unresolved invariant status')
if audit.get('production_delta') != []:
    raise SystemExit('EB_I14_GATE_FAIL design freeze declares a production delta')

rho = 1000.0
cp = 4180.0
k = 0.01 * rho * cp
samples = [
    (0.30, 10.0, 12.0),
    (0.20, 12.0, 20.0),
]
tref = 5.0
energy = sum(k*q*(tend-tref) for q, tstart, tend in samples)
expected = k*(0.30*(12.0-5.0) + 0.20*(20.0-5.0))
if energy != expected:
    raise SystemExit('EB_I14_GATE_FAIL sample-wise terminal algebra')

aggregate_final = k*sum(q for q, _, _ in samples)*(samples[-1][2]-tref)
if energy == aggregate_final:
    raise SystemExit('EB_I14_GATE_FAIL adversarial case does not distinguish forbidden aggregate shortcut')

hybrid_mean = sum(k*q*(0.5*(tstart+tend)-tref) for q, tstart, tend in samples)
if energy == hybrid_mean:
    raise SystemExit('EB_I14_GATE_FAIL adversarial case does not distinguish hybrid endpoint-mean rule')

shift = 7.25
shifted = sum(k*q*(tend-(tref+shift)) for q, _, tend in samples)
identity = energy - k*shift*sum(q for q, _, _ in samples)
if not math.isclose(shifted, identity, rel_tol=0.0, abs_tol=1.0e-10):
    raise SystemExit('EB_I14_GATE_FAIL reference-temperature shift identity')

zero = k*0.0*(float('nan')-tref)
# IEEE 0*NaN is NaN, so exact-zero semantics must branch before enthalpy evaluation.
if not math.isnan(zero):
    raise SystemExit('EB_I14_GATE_FAIL zero-path adversary assumption')
zero_energy = 0.0
if zero_energy != 0.0:
    raise SystemExit('EB_I14_GATE_FAIL exact-zero result')

# Right-endpoint refinement characterization for q=constant and linear T.
# The frozen rule is not claimed exact. Two right-endpoint rectangles must be
# closer to the analytical integral than one for this monotone linear case.
q_rate = 1.0
T0, T1 = 0.0, 20.0
exact = k*q_rate*0.5*(T0+T1)
one = k*q_rate*T1
mid = 0.5*(T0+T1)
two = 0.5*k*q_rate*mid + 0.5*k*q_rate*T1
if not abs(two-exact) < abs(one-exact):
    raise SystemExit('EB_I14_GATE_FAIL right-endpoint refinement characterization')

print('EB_I14_ARCHITECTURE_INVARIANTS_1_30=PASS')
print('EB_I14_TERMINAL_DONOR_ALGEBRA=PASS')
print('EB_I14_FORBIDDEN_AGGREGATE_SHORTCUT_DIFFERENT=PASS')
print('EB_I14_HYBRID_ENDPOINT_MEAN_NOT_DEFAULT=PASS')
print('EB_I14_REFERENCE_SHIFT_IDENTITY=PASS')
print('EB_I14_EXACT_ZERO_BRANCH_REQUIRED=PASS')
print('EB_I14_RIGHT_ENDPOINT_REFINEMENT_CHARACTERIZED=PASS')
PY

allowed='^(tests/eb/EB-I14_CONTRACT\.md|tests/eb/EB-I14_ARCHITECTURE_AUDIT\.json|tests/eb/EB-I14_STATUS\.json|tests/eb/EB-I14_CLOSURE\.md|tests/eb/run_eb_i14_quadrature_contract_gate\.sh|\.github/workflows/eb-i14-contract\.yml)$'
while IFS= read -r path; do
  [[ -z "$path" ]] && continue
  [[ "$path" =~ $allowed ]] || fail "unexpected design-freeze delta: $path"
done < <(git diff --name-only "$BASE"..HEAD)

echo 'EB_I14_NO_PRODUCTION_DELTA=PASS'
git diff --check "$BASE"..HEAD || fail 'whitespace check'
echo 'EB_I14_QUADRATURE_CONTRACT_GATE=PASS'

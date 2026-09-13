#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BASE="0181b7b674cc89d729e361dafc1135b719e23a7d"

fail() { echo "EB_I16_GATE_FAIL $*" >&2; exit 96; }

check_blob() {
  local path="$1" expected="$2" actual
  actual="$(git rev-parse "HEAD:$path")"
  [[ "$actual" == "$expected" ]] || fail "authority blob drift $path expected=$expected actual=$actual"
}

check_blob src/runtime/mod_groundwater_coupling_contract.f90 fc598d14eabafcb025bb55621f7b00d6d1816f10
check_blob src/runtime/mod_groundwater_exchange_service_contract.f90 f0fc25592624360802713a9487813d119e7dc4e9
check_blob src/runtime/mod_groundwater_interface_mass_ledger.f90 d37f1926dafde9d941939cf4147d799cb7478bfc
check_blob src/runtime/mod_fmr_bottom_thermal_carrier.f90 c371be3e22eaa6da70ca8cbb060bc42d1e0e0bfb
check_blob src/runtime/mod_fmr_bottom_sensible_energy.f90 fa053e6036cdfe781c81122120d60276c2d12952
echo 'EB_I16_EXISTING_AUTHORITIES_BYTE_UNCHANGED=PASS'

python3 - <<'PY'
from pathlib import Path
import json, math

contract = Path('tests/eb/EB-I16_CONTRACT.md').read_text()
audit = json.loads(Path('tests/eb/EB-I16_ARCHITECTURE_AUDIT.json').read_text())

required = [
    'DESIGN_FROZEN_NO_PRODUCTION_IMPLEMENTATION',
    'q_groundwater = -q_swap',
    'adds no water amount to the thermal contract',
    'There is no small-transfer tolerance.',
    "sample's `t1` reference instant",
    'A detached API that accepts only scalar lineage/window/revision metadata and later authorizes thermal provenance is forbidden.',
    'A copied, stale or replayed thermal handle must fail closed.',
    'The mass ledger remains authoritative for committed interface mass.',
    'accepted energy publication',
]
for token in required:
    if token not in contract:
        raise SystemExit(f'EB_I16_GATE_FAIL missing frozen token: {token}')

items = audit.get('invariants', [])
if [x.get('id') for x in items] != list(range(1, 31)):
    raise SystemExit('EB_I16_GATE_FAIL invariant ids must be exactly 1..30')
if any(x.get('status') not in ('pass','preserved') for x in items):
    raise SystemExit('EB_I16_GATE_FAIL unresolved invariant')
if audit.get('production_delta') != []:
    raise SystemExit('EB_I16_GATE_FAIL design freeze has production delta')

coupling = Path('src/runtime/mod_groundwater_coupling_contract.f90').read_text().lower()
exchange = Path('src/runtime/mod_groundwater_exchange_service_contract.f90').read_text().lower()
ledger = Path('src/runtime/mod_groundwater_interface_mass_ledger.f90').read_text().lower()
for token in ['q_groundwater = -q_swap', 'groundwater_interface_lineage_t']:
    if token not in coupling:
        raise SystemExit(f'EB_I16_GATE_FAIL missing coupling authority token: {token}')
for token in ['groundwater_exchange_candidate_t', 'groundwater_exchange_prepared_t', 'groundwater_prepare_candidate', 'groundwater_commit_prepared', 'groundwater_abort_prepared']:
    if token not in exchange:
        raise SystemExit(f'EB_I16_GATE_FAIL missing exchange lifecycle token: {token}')
for token in ['groundwater_interface_mass_ledger_t', 'stage_exchange', 'prepare_trial', 'commit_prepared', 'abort_prepared']:
    if token not in ledger:
        raise SystemExit(f'EB_I16_GATE_FAIL missing mass-ledger authority token: {token}')

# Executable model of the frozen thermal-only sidecar semantics. The request has
# no Q/flux/mass field; Q remains an argument owned by the existing SWAP sample.
class Provider:
    def __init__(self, temperature, candidate_handle):
        self.temperature = temperature
        self.candidate_handle = candidate_handle
        self.calls = []
    def current_temperature(self, sample_t1, required_handle):
        self.calls.append((sample_t1, required_handle))
        if required_handle != self.candidate_handle:
            return None
        if not math.isfinite(self.temperature):
            return None
        return self.temperature

def bind(q_swap, t0, t1, local_terminal, provider, exact_handle):
    if not (math.isfinite(q_swap) and math.isfinite(t0) and math.isfinite(t1) and t1 > t0):
        return False, None
    if q_swap > 0.0:
        return math.isfinite(local_terminal), local_terminal if math.isfinite(local_terminal) else None
    if q_swap == 0.0:
        return True, None
    if provider is None:
        return False, None
    temperature = provider.current_temperature(t1, exact_handle)
    return temperature is not None, temperature

# Inward matching provider. Current-reference time must be t1.
p = Provider(11.25, ('candidate', 7))
ok, temp = bind(-0.1, 3.0, 4.0, float('nan'), p, ('candidate', 7))
assert ok and temp == 11.25 and p.calls == [(4.0, ('candidate', 7))]

# Missing and non-finite fail closed.
ok, _ = bind(-0.1, 3.0, 4.0, float('nan'), None, ('candidate', 7)); assert not ok
p_bad = Provider(float('nan'), ('candidate', 7))
ok, _ = bind(-0.1, 3.0, 4.0, float('nan'), p_bad, ('candidate', 7)); assert not ok

# Tiny nonzero still queries.
p_tiny = Provider(9.0, ('candidate', 7))
ok, _ = bind(-float.fromhex('0x1.0p-1022'), 3.0, 4.0, float('nan'), p_tiny, ('candidate', 7))
assert ok and len(p_tiny.calls) == 1

# Exact zero and local outward never query the external provider.
p_zero = Provider(9.0, ('candidate', 7))
ok, temp = bind(0.0, 3.0, 4.0, float('nan'), p_zero, ('candidate', 7)); assert ok and temp is None and p_zero.calls == []
p_local = Provider(9.0, ('candidate', 7))
ok, temp = bind(0.2, 3.0, 4.0, 17.0, p_local, ('candidate', 7)); assert ok and temp == 17.0 and p_local.calls == []

# Stale/mismatched candidate handle fails closed even if visible window is equal.
p_stale = Provider(12.0, ('candidate', 7))
ok, _ = bind(-0.1, 3.0, 4.0, float('nan'), p_stale, ('candidate', 8)); assert not ok

# Two same-origin candidates with the same visible [t0,t1] remain distinct by opaque handle.
p_a = Provider(10.0, ('opaque-A', 1))
p_b = Provider(20.0, ('opaque-B', 1))
ok_a, t_a = bind(-0.1, 3.0, 4.0, float('nan'), p_a, ('opaque-A', 1))
ok_b_wrong, _ = bind(-0.1, 3.0, 4.0, float('nan'), p_a, ('opaque-B', 1))
ok_b, t_b = bind(-0.1, 3.0, 4.0, float('nan'), p_b, ('opaque-B', 1))
assert ok_a and t_a == 10.0 and not ok_b_wrong and ok_b and t_b == 20.0

print('EB_I16_INWARD_MATCHING_CURRENT_REFERENCE=PASS')
print('EB_I16_MISSING_INVALID_FAIL_CLOSED=PASS')
print('EB_I16_TINY_INWARD_REQUIRES_PROVENANCE=PASS')
print('EB_I16_ZERO_PROVIDER_NOT_QUERIED=PASS')
print('EB_I16_LOCAL_PROVIDER_NOT_QUERIED=PASS')
print('EB_I16_STALE_IDENTITY_FAIL_CLOSED=PASS')
print('EB_I16_SAME_ORIGIN_CANDIDATES_DISTINCT=PASS')
print('EB_I16_ARCHITECTURE_INVARIANTS_1_30=PASS')
PY

while IFS= read -r path; do
  [[ -z "$path" ]] && continue
  case "$path" in
    tests/eb/EB-I16_CONTRACT.md|\
    tests/eb/EB-I16_ARCHITECTURE_AUDIT.json|\
    tests/eb/EB-I16_STATUS.json|\
    tests/eb/EB-I16_CLOSURE.md|\
    tests/eb/run_eb_i16_external_bottom_thermal_binding_gate.sh|\
    .github/workflows/eb-i16-contract.yml)
      ;;
    *) fail "unexpected design-freeze delta: $path" ;;
  esac
done < <(git diff --name-only "$BASE"..HEAD)

echo 'EB_I16_NO_PRODUCTION_DELTA=PASS'
git diff --check "$BASE"..HEAD || fail 'whitespace check'
echo 'EB_I16_EXTERNAL_BOTTOM_THERMAL_BINDING_CONTRACT_GATE=PASS'

#!/usr/bin/env bash
set -euo pipefail

BASE="0181b7b674cc89d729e361dafc1135b719e23a7d"
CONTRACT="tests/eb/EB-I16_CONTRACT.md"
AUDIT="tests/eb/EB-I16_ARCHITECTURE_AUDIT.json"
STATUS="tests/eb/EB-I16_STATUS.json"
CLOSURE="tests/eb/EB-I16_CLOSURE.md"

for path in "$CONTRACT" "$AUDIT" "$STATUS" "$CLOSURE"; do
  test -f "$path"
done

# Frozen semantic anchors. These are intentionally strict so later prose edits
# cannot silently erase the core ownership/fail-closed requirements.
grep -Fq 'DESIGN_FROZEN_NO_PRODUCTION_IMPLEMENTATION' "$CONTRACT"
grep -Fq 'An external thermal provider is never a water-mass authority.' "$CONTRACT"
grep -Fq 'For the EB-I14 current-reference discretization, the required external donor-temperature quadrature point is `t1`' "$CONTRACT"
grep -Fq 'There is no local SWAP temperature fallback' "$CONTRACT"
grep -Fq 'The response shall not contain an authoritative replacement water transfer.' "$CONTRACT"
grep -Fq 'Accepted energy commit/publication remains a separate transactional integration boundary.' "$CONTRACT"
grep -Fq 'SWAP does not know the external component type.' "$CONTRACT"

# The current production carrier must still expose the direction class that
# creates the external request, and the existing groundwater contract remains
# a separate mass/head authority rather than becoming the thermal provider.
grep -Fq 'FMR_BOTTOM_THERMAL_DONOR_EXTERNAL = 2' src/runtime/mod_fmr_bottom_thermal_carrier.f90
grep -Fq 'type, public :: groundwater_interface_lineage_t' src/runtime/mod_groundwater_coupling_contract.f90
grep -Fq 'q_groundwater = -q_swap' src/runtime/mod_groundwater_coupling_contract.f90

python3 - <<'PY'
import json
from pathlib import Path

audit = json.loads(Path('tests/eb/EB-I16_ARCHITECTURE_AUDIT.json').read_text())
assert audit['work_unit'] == 'EB-I16'
assert audit['scope'] == 'GENERIC_EXTERNAL_BOTTOM_DONOR_TEMPERATURE_BINDING_CONTRACT_ONLY'
assert audit['production_delta'] is False
items = audit['invariants']
assert [x['id'] for x in items] == list(range(1, 31))
assert all(x['status'] in {'pass', 'preserved'} for x in items)
assert all(str(x['evidence']).strip() for x in items)

status = json.loads(Path('tests/eb/EB-I16_STATUS.json').read_text())
assert status['work_unit'] == 'EB-I16'
assert status['decision'] == 'DESIGN_FROZEN_NO_PRODUCTION_IMPLEMENTATION'
assert status['production_delta'] is False
assert status['implemented'] is False
assert status['runtime_integrated'] is False
assert status['accepted_energy_publication'] is False
assert status['canonical_admission'] is False

closure = Path('tests/eb/EB-I16_CLOSURE.md').read_text()
assert 'exact branch HEAD' in closure
assert 'No production source is changed in EB-I16.' in closure
print('EB_I16_METADATA=PASS')
PY

# Design-only means exactly zero src/ delta from the qualified EB-I15 head.
if git diff --name-only "${BASE}...HEAD" | grep -q '^src/'; then
  echo 'EB-I16 unexpectedly changes production source' >&2
  git diff --name-only "${BASE}...HEAD" >&2
  exit 1
fi

allowed_paths='^(tests/eb/EB-I16_CONTRACT\.md|tests/eb/EB-I16_ARCHITECTURE_AUDIT\.json|tests/eb/EB-I16_STATUS\.json|tests/eb/EB-I16_CLOSURE\.md|tests/eb/run_eb_i16_external_donor_contract_gate\.sh|\.github/workflows/eb-i16-contract\.yml)$'
unexpected="$(git diff --name-only "${BASE}...HEAD" | grep -Ev "$allowed_paths" || true)"
if [[ -n "$unexpected" ]]; then
  echo 'EB-I16 changed-path allowlist violation:' >&2
  printf '%s\n' "$unexpected" >&2
  exit 1
fi

# No design prose may claim a source-specific production binding.
if grep -Eiq 'modflow[_ -]temperature[_ -](provider|implementation)|deep[_ -]vadose[_ -]temperature[_ -](provider|implementation)' "$CONTRACT"; then
  echo 'EB-I16 contract contains a source-specific production binding claim' >&2
  exit 1
fi

git diff --check "${BASE}...HEAD"

echo 'EB_I16_NO_PRODUCTION_DELTA=PASS'
echo 'EB_I16_GENERIC_PROVIDER_OWNERSHIP=PASS'
echo 'EB_I16_FAIL_CLOSED=PASS'
echo 'EB_I16_ARCHITECTURE_30=PASS'
echo 'EB_I16_EXTERNAL_DONOR_CONTRACT_GATE PASS'

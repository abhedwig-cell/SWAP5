#!/usr/bin/env bash
set -euo pipefail
python3 tools/fsi/fsi09_source_admission_gate.py
python3 - <<'PY'
import json
from pathlib import Path
p = Path('integration/f-si/F-SI08_QUALIFICATION.json')
data = json.loads(p.read_text())
assert data['qualified'] is True
assert data['status'] == 'QUALIFIED_PROVIDER_CONTEXT_ISOLATION_ADMITTED_FIXTURE'
assert data['holds']['production_b1_10_constitutive_provider_admitted'] is False
assert data['holds']['parallel_reference_backend_admitted'] is False
print('F-SI09_FSI08_HANDOFF PASS')
PY

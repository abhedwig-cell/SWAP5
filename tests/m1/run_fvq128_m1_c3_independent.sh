#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
fail(){ echo "FVQ128_FAIL $*" >&2; exit 128; }

python3 - <<'PY'
import json
from pathlib import Path
e=json.loads(Path('integration/m1/M1_C3_FINAL_WHOLE_HUPSEL_QUALIFICATION.json').read_text())
assert e['exact_authority']['distribution_sha256']=='2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360'
assert e['exact_authority']['b1_11_manifest_sha256']=='24ce2768b3804ca1744457e8a7adcf101e37a4c1390049df23179e09816957e2'
q=e['whole_hupsel_typed_replay']
assert q['normal_completion'] is True
assert q['accepted_intervals']==32518
assert q['typed_attempts']==32552
assert q['retry_attempts']==34
assert q['accepted_time_trace_exact'] is True
assert q['normalized_result_bal_sha256']=='a9cc9b18a404726dfbce22d8372df279b9d3bdf1bc76c8c38f33c8080430d0e7'
assert q['normalized_result_blc_sha256']=='1bd2631d91cb21e72a5949f54524d0cb55ed0bb059a88fc4a4def8507693b77c'
assert q['signed_zero_difference_remaining'] is False
assert e['verdict']=='PASS_EXACT_WHOLE_HUPSEL_LEGACY_FILE_TO_TYPED_TASK2'
for p in [
 'src/solver/mod_b110_dynamic_top_boundary_provider.f90',
 'src/adapter/mod_b110_dynamic_top_boundary_solver_adapter.f90',
 'src/adapter/mod_b110_production_soil_water_task2.f90']:
    low=Path(p).read_text().lower()
    assert 'open(' not in low and 'file=' not in low and 'read(' not in low
print('FVQ128_EVIDENCE_INTEGRITY=PASS')
print('FVQ128_NO_PARSER_LEAK=PASS')
PY

tests/m1/run_m1_c3_final_adapter_gate.sh
echo 'FVQ128_M1_C3_INDEPENDENT=PASS'

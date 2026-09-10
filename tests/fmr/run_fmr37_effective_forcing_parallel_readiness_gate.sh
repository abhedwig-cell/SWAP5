#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BASE="8fa79a70a9faccaf8b63826df607a685eb75b046"
FMR35_HEAD="996038433690bb4c19f36774a633e485daa7f0db"
fail() { echo "FMR37_FAIL $*" >&2; exit 37; }
check_blob() {
  local path="$1" expected="$2" actual
  actual="$(git rev-parse "HEAD:$path")"
  [[ "$actual" == "$expected" ]] || fail "blob drift $path expected=$expected actual=$actual"
}

git merge-base --is-ancestor "$BASE" HEAD || fail 'branch is not descended from exact F-CI36 canonical authority'
[[ -z "$(git diff --name-only "$BASE"..HEAD -- src)" ]] || fail 'readiness workunit changed production source'
[[ -z "$(git diff --name-only "$BASE"..HEAD -- reference)" ]] || fail 'readiness workunit changed reference source'
check_blob src/runtime/mod_fmr_parallel_worker_pool.f90 0e700797cbaed4aaab7f04db0054f72faddcfc15
check_blob src/runtime/mod_fmr_parallel_physical_scheduler.f90 544a1ca16fdeebdfce7f89d1ddf1825fa32fa654
check_blob src/runtime/mod_fmr_serialized_multiswap_runtime.f90 fe5a06c9af59308cdad86c5126379f413591b0cd
check_blob src/runtime/mod_fmr_serialized_reference_backend.f90 9af5a494526810324dc00706b444e448e770cba9
check_blob src/runtime/mod_fmr_divdra_serialized_composition.f90 5cc7bd8674e24e4642f3ad909e6c93b8259a1cf5
check_blob src/runtime/mod_fmr_divdra_serialized_runtime.f90 9a384658ec37b68d2ef911e741aa89707dcb3e77
check_blob src/runtime/mod_fmr_divdra_runtime_binding.f90 e4737fb6f00a11ed16e34bee44b3442ac84b31aa
check_blob src/process/mod_drainage_spatial_distribution.f90 1f538174b7451aaa7a3c50d6078b7c1fc3ad8f5a
echo 'FMR37_SOURCE_AUTHORITY_AND_ZERO_PRODUCTION_DELTA=PASS'

python3 - <<'PY'
from pathlib import Path
import re
worker=Path('src/runtime/mod_fmr_parallel_worker_pool.f90').read_text().lower()
sched=Path('src/runtime/mod_fmr_parallel_physical_scheduler.f90').read_text().lower()
serial=Path('src/runtime/mod_fmr_serialized_multiswap_runtime.f90').read_text().lower()
divrt=Path('src/runtime/mod_fmr_divdra_serialized_runtime.f90').read_text().lower()
backend=Path('src/runtime/mod_fmr_serialized_reference_backend.f90').read_text().lower()

# Current parallel boundary: shared forcing registry is read-only and workers
# route through the serialized per-column executor.
assert re.search(r'type\(fmr_b110_physical_forcing_t\),\s*intent\(in\)\s*::\s*forcing_registry\(:\)', worker)
assert re.search(r'type\(fmr_b110_physical_forcing_t\),\s*intent\(in\)\s*::\s*forcing_registry\(:\)', sched)
assert 'fmr_execute_serialized_physical_column' in worker

# Registry is a lookup boundary, not a physics requirement: the executor
# resolves one forcing index and then passes exactly that object to run_trial
# and postcommit transpiration attribution.
assert 'forcing_index = int(column%forcing_handle)' in serial
assert 'forcing_registry(forcing_index)' in serial
assert 'backend%run_trial' in serial
assert 'bind_committed_actual_transpiration(parameter_registry(parameter_index), forcing_registry(forcing_index)' in serial

# Serialized DIVDRA requires a mutable registry precisely because it
# materializes then removes drainage_flux_by_level around the generic runtime.
assert re.search(r'type\(fmr_b110_physical_forcing_t\),\s*intent\(inout\)\s*::\s*forcing_registry\(:\)', divrt)
assert 'call fmr_preflight_serialized_divdra' in divrt
assert 'fmr_bind_single_level_positive_divdra' in divrt
assert '%drainage_flux_by_level' in divrt
assert 'call cleanup_materialized_divdra' in divrt

# A forcing value can own multiple optional allocatable arrays; this makes a
# whole-registry copy an unacceptable default scalability contract.
for token in ['root_extraction_sink', 'drainage_flux_by_level', 'subsurface_irrigation_source']:
    assert token in backend
assert backend.count('allocatable') >= 6
print('FMR37_CURRENT_RUNTIME_CAUSALITY_RECONSTRUCTED=PASS')
PY

# Adjacent F-MR35 is deliberately treated as evidence that a feature-specific
# pool duplicates substantial worker machinery, not as a generic seam to copy.
[[ "$(git rev-parse "$FMR35_HEAD:src/runtime/mod_fmr_parallel_root_uptake_pool.f90")" == "c78c13997642617376b8d118122c86c60ca77189" ]] || fail 'F-MR35 parallel root candidate drift'
lines="$(git show "$FMR35_HEAD:src/runtime/mod_fmr_parallel_root_uptake_pool.f90" | wc -l | tr -d ' ')"
[[ "$lines" -ge 400 ]] || fail "F-MR35 pool no longer demonstrates substantial separate worker route lines=$lines"
git show "$FMR35_HEAD:src/runtime/mod_fmr_parallel_root_uptake_pool.f90" | grep -q 'fmr_execute_serialized_physical_column' || fail 'F-MR35 no longer routes through serialized executor'
echo "FMR37_ADJACENT_FMR35_SEPARATE_POOL_LINES=$lines"
echo 'FMR37_FEATURE_SPECIFIC_POOL_DUPLICATION_NOT_SELECTED=PASS'

python3 - <<'PY'
from pathlib import Path
import json
contract=Path('integration/f-mr/F-MR37_READINESS_CONTRACT.md').read_text().lower()
required=[
 'generic resolved-column / explicit-effective-forcing execution seam',
 'ephemeral worker/job scratch',
 'must not mutate the base object',
 'backend consumes one drainage row',
 'cloning the entire forcing registry',
 'process-specific parallel worker-pool copy',
 'active parallel divdra execution',
 'ordinary serialized and parallel v1 behavioral preservation'
]
for phrase in required:
    assert phrase in contract, phrase
audit=json.loads(Path('integration/f-mr/F-MR37_INVARIANT_AUDIT.json').read_text())
assert audit['overall']=='QUALIFIED_DIRECTION_NO_PRODUCTION_DELTA'
assert [x['id'] for x in audit['invariants']]==list(range(1,31))
assert all(x['status']=='SATISFIED' for x in audit['invariants'])
assert len(audit['hard_rejects']) >= 6
print('FMR37_GENERIC_EFFECTIVE_FORCING_CONTRACT=PASS')
print('FMR37_ALL_30_ARCHITECTURE_INVARIANTS=PASS')
PY

echo 'FMR37_READINESS_GATE=PASS'

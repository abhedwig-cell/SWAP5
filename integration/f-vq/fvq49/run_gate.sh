#!/usr/bin/env bash
set -euo pipefail

BASE="49863406a6112baa9956f9396b34e7188934e0d4"
OWNER="419c463b06de72e2d8b659b03354aa03ffc114e2"
CANDIDATE_PATH="src/runtime/mod_fmr_divdra_runtime_binding.f90"
CANDIDATE_BLOB="e4737fb6f00a11ed16e34bee44b3442ac84b31aa"
PROCESS="src/process/mod_drainage_spatial_distribution.f90"
VIEW="src/solver/mod_process_hydraulic_view.f90"
BACKEND="src/runtime/mod_fmr_serialized_reference_backend.f90"
SOURCESINK="src/solver/mod_b110_source_sink_provider.f90"
TEST="integration/f-vq/fvq49/test_fvq49_independent_runtime_binding.f90"
AUDIT="integration/f-vq/F-VQ49_ARCHITECTURE_AUDIT.json"
BUILD="build/fvq49"

expect_blob() {
  local path="$1"
  local expected="$2"
  local actual
  actual="$(git hash-object "$path")"
  if [[ "$actual" != "$expected" ]]; then
    echo "BLOB_LOCK_FAIL $path expected=$expected actual=$actual" >&2
    exit 1
  fi
  echo "BLOB_LOCK_OK $path $actual"
}

expect_blob "$PROCESS" "1f538174b7451aaa7a3c50d6078b7c1fc3ad8f5a"
expect_blob "$VIEW" "d7d85fe71ced0d94b29c8d9395859ae1834f7dd6"
expect_blob "$BACKEND" "9af5a494526810324dc00706b444e448e770cba9"
expect_blob "$SOURCESINK" "d6c57add72387e5c0022a44319fff08046194aac"

owner_blob="$(git rev-parse "${OWNER}:${CANDIDATE_PATH}")"
if [[ "$owner_blob" != "$CANDIDATE_BLOB" ]]; then
  echo "CANDIDATE_OWNER_BLOB_FAIL expected=$CANDIDATE_BLOB actual=$owner_blob" >&2
  exit 1
fi
echo "CANDIDATE_OWNER_BLOB_OK $owner_blob"

if [[ -n "$(git diff --name-only "$BASE" HEAD -- src reference)" ]]; then
  echo "QUALIFICATION_PRODUCTION_OR_REFERENCE_DELTA_FAIL" >&2
  git diff --name-only "$BASE" HEAD -- src reference >&2
  exit 1
fi
echo "QUALIFICATION_SRC_REFERENCE_DELTA_ZERO"

rm -rf "$BUILD"
mkdir -p "$BUILD"
git show "${OWNER}:${CANDIDATE_PATH}" > "$BUILD/candidate.f90"
materialized_blob="$(git hash-object "$BUILD/candidate.f90")"
if [[ "$materialized_blob" != "$CANDIDATE_BLOB" ]]; then
  echo "MATERIALIZED_CANDIDATE_BLOB_FAIL expected=$CANDIDATE_BLOB actual=$materialized_blob" >&2
  exit 1
fi
echo "MATERIALIZED_CANDIDATE_BLOB_OK $materialized_blob"

python3 - <<'PY'
import json
from pathlib import Path

candidate = Path('build/fvq49/candidate.f90').read_text()
lower = candidate.lower()
for token in [
    'kernel_committed', 'committed_state', '%snapshot',
    'mod_fmr_process_hydraulic_view_binding',
    'mod_fmr_serialized_reference_backend', 'headcalc', 'jacobian',
    '.dra', 'modflow', 'tolerance', 'open(', 'read(', 'write(', ' save '
]:
    if token in lower:
        raise SystemExit(f'FORBIDDEN_CANDIDATE_TOKEN {token}')

prebound = lower.find('if (allocated(drainage_flux_by_level))')
process_call = lower.find('call distribute_single_level_positive_divdra')
status_guard = lower.find('if (process_diagnostics%status /= drain_dist_ok)')
publish = lower.find('allocate(drainage_flux_by_level(1,n))')
copy = lower.find('drainage_flux_by_level(1,:) = node_transfer%soil_to_drain_rate')
if min(prebound, process_call, status_guard, publish, copy) < 0:
    raise SystemExit('CANDIDATE_STRUCTURE_TOKEN_MISSING')
if not (prebound < process_call < status_guard < publish < copy):
    raise SystemExit('CANDIDATE_PUBLICATION_ORDER_FAIL')
if lower.count('call distribute_single_level_positive_divdra') != 1:
    raise SystemExit('CANDIDATE_PROCESS_CALL_COUNT_FAIL')
if 'sum(' in lower:
    raise SystemExit('CANDIDATE_RUNTIME_RECONSTRUCTION_FAIL')
if 'deallocate(drainage_flux_by_level' in lower:
    raise SystemExit('CANDIDATE_TARGET_MUTATION_FAIL')

report = json.loads(Path('integration/f-vq/F-VQ49_ARCHITECTURE_AUDIT.json').read_text())
items = report['invariants']
if [x['id'] for x in items] != list(range(1, 31)):
    raise SystemExit('ARCHITECTURE_AUDIT_ID_FAIL')
if report['independent_findings']['count'] != 30:
    raise SystemExit('ARCHITECTURE_AUDIT_COUNT_FAIL')
if report['independent_findings']['violations'] != 0:
    raise SystemExit('ARCHITECTURE_AUDIT_VIOLATION_FAIL')
for key in [
    'candidate_has_hidden_committed_state_capture',
    'candidate_has_backend_import',
    'candidate_has_solver_internal_or_jacobian_access',
    'candidate_has_configurable_mass_tolerance',
    'candidate_has_io_or_calendar_assumption',
    'candidate_adds_persistent_state',
    'candidate_reopens_scientific_divdra_scope'
]:
    if report['independent_findings'][key] is not False:
        raise SystemExit(f'ARCHITECTURE_AUDIT_FINDING_FAIL {key}')
print('INDEPENDENT_STATIC_RUNTIME_AUDIT_OK')
print('ARCHITECTURE_AUDIT_OK 30/30')
PY

compile_and_run() {
  local opt="$1"
  local tag="$2"
  local outdir="$BUILD/$tag"
  mkdir -p "$outdir/mod"
  gfortran "$opt" -std=f2008 -Wall -Wextra -pedantic \
    -J "$outdir/mod" -I "$outdir/mod" \
    src/solver/mod_soil_water_solver_contract.f90 \
    src/solver/mod_process_hydraulic_view.f90 \
    src/process/mod_drainage_spatial_distribution.f90 \
    "$BUILD/candidate.f90" \
    src/solver/mod_b110_source_sink_provider.f90 \
    "$TEST" \
    -o "$outdir/test_fvq49"
  "$outdir/test_fvq49" > "$outdir/output.txt"
}

compile_and_run -O0 O0
compile_and_run -O2 O2
cmp "$BUILD/O0/output.txt" "$BUILD/O2/output.txt"
cp "$BUILD/O0/output.txt" F-VQ49_O0.txt
cp "$BUILD/O2/output.txt" F-VQ49_O2.txt
sha256sum F-VQ49_O0.txt F-VQ49_O2.txt

python3 - <<'PY'
import json
from pathlib import Path
text = Path('F-VQ49_O0.txt').read_text()
required = {
    'VALID_RUNTIME_CASES': 400,
    'CONSUMER_COMPOSITION_CASES': 400,
    'FRESH_TARGET_REPEAT_CASES': 400,
    'ZERO_TRANSFER_CASES': 5,
    'PROCESS_REJECTION_CASES': 20,
    'PREALLOCATED_TARGET_GUARDS': 5,
}
if 'F-VQ49 PASS' not in text:
    raise SystemExit('VERIFIER_PASS_MARKER_MISSING')
for key, value in required.items():
    marker = f'{key}={value}'
    if marker not in text:
        raise SystemExit(f'VERIFIER_COUNT_FAIL {marker}')
for marker in [
    'ROW_COPY_IDENTITY=TRUE',
    'NO_ADDITIONAL_RUNTIME_MASS_DISCREPANCY=TRUE',
    'EXPLICIT_HYDRAULIC_VIEW_ONLY=TRUE'
]:
    if marker not in text:
        raise SystemExit(f'VERIFIER_MARKER_FAIL {marker}')
summary = {
    'schema': 'swap5.fvq49_gate_summary.v1',
    'decision': 'PASS_INDEPENDENT_RUNTIME_QUALIFICATION_GATE',
    'candidate_blob': 'e4737fb6f00a11ed16e34bee44b3442ac84b31aa',
    'valid_runtime_cases': 400,
    'consumer_composition_cases': 400,
    'fresh_target_repeat_cases': 400,
    'zero_transfer_cases': 5,
    'process_rejection_cases': 20,
    'preallocated_target_guards': 5,
    'architecture_invariants_audited': 30,
    'qualification_src_reference_delta_zero': True,
    'scientific_divdra_scope_reopened': False,
}
Path('F-VQ49_SUMMARY.json').write_text(json.dumps(summary, indent=2) + '\n')
print('F-VQ49_RESULT_COUNTS_OK')
PY

echo "F-VQ49_GATE_PASS"

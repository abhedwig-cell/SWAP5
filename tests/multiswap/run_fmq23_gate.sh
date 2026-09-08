#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CANDIDATE="$(realpath "${1:?candidate checkout required}")"
FVQ15="$(realpath "${2:?F-VQ15 checkout required}")"
FMR01="$(realpath "${3:?F-MR01 qualified checkout required}")"
RESULTS="$(realpath -m "${4:-$ROOT/fmq23-results}")"
mkdir -p "$RESULTS" "$RESULTS/fvq15"

EXPECTED_CANDIDATE=c28e7a2810b4a3678c577335a6a3086b173eb976
EXPECTED_TREE=a1a161e5e33fc143a7dc7f3c1b9749fc96f861f6
EXPECTED_RUNTIME_BLOB=e4f5bc0bf47e2721d689e62107b5224196a093d9
EXPECTED_FVQ15=65efc66cc76fa9005eac46e5779439c5ada574d1
EXPECTED_FMR01=6ed341437ebcfc6bd19c281f1064a789e90fbd05
EXPECTED_CORE_BLOB=543af573b34bfccd8fbdecf719af22994c5236b2
EXPECTED_DETERMINISTIC_BLOB=6f567600e42bc4e37e0e175ef4a3edc97a945592

[[ "$(git -C "$CANDIDATE" rev-parse HEAD)" == "$EXPECTED_CANDIDATE" ]]
[[ "$(git -C "$CANDIDATE" rev-parse HEAD^{tree})" == "$EXPECTED_TREE" ]]
[[ "$(git -C "$CANDIDATE" hash-object src/runtime/mod_fmr_serialized_multiswap_runtime.f90)" == "$EXPECTED_RUNTIME_BLOB" ]]
[[ "$(git -C "$FVQ15" rev-parse HEAD)" == "$EXPECTED_FVQ15" ]]
[[ "$(git -C "$FMR01" rev-parse HEAD)" == "$EXPECTED_FMR01" ]]
for repo in "$CANDIDATE" "$FMR01"; do
  [[ "$(git -C "$repo" hash-object src/runtime/mod_fmr_runtime_core.f90)" == "$EXPECTED_CORE_BLOB" ]]
  [[ "$(git -C "$repo" hash-object src/runtime/mod_fmr_deterministic_runtime.f90)" == "$EXPECTED_DETERMINISTIC_BLOB" ]]
done

python3 - "$ROOT" "$CANDIDATE" "$FVQ15" <<'PY' | tee "$RESULTS/provenance.log"
import json, subprocess, sys
from pathlib import Path
root, candidate, fvq15 = map(Path, sys.argv[1:])
status = json.loads((root/'integration/f-mq/F-MQ23_STATUS.json').read_text())
deps = json.loads((root/'integration/f-mq/F-MQ23_DEPENDENCIES.json').read_text())
vq = json.loads((fvq15/'integration/f-vq/F-VQ15_STATUS.json').read_text())
assert status['qualification_only'] is True
assert status['candidate_source_commit'] == 'c28e7a2810b4a3678c577335a6a3086b173eb976'
assert status['production_source_changed_by_fmq23'] is False
assert status['reference_source_changed_by_fmq23'] is False
assert status['parallel_real_physics_admitted'] is False
assert deps['resolved_blocker']['id'] == 'FMQ23-B01'
assert deps['resolved_blocker']['current_status'] == 'RESOLVED_UPSTREAM_BY_FMR05_AND_FVQ15'
assert vq['QUALIFIED'] is True
assert vq['scientific_admission'] is True
assert vq['production_serialized_multicolumn_admission'] is True
assert vq['release_to_fmq23'] is True
assert vq['candidate_source_commit'] == status['candidate_source_commit']
assert vq['parallel_reference_backend_admitted'] is False
assert vq['production_physics_qualified_scope'] == 'EXACT_FVQ14_RESTRICTED_PROFILE_ONLY'
changed = subprocess.check_output(['git','-C',str(root),'diff','--name-only',status['candidate_source_commit'],'HEAD','--','src','reference'], text=True).splitlines()
assert changed == [], f'F-MQ23 source boundary violation: {changed}'
print('FMQ23_PROVENANCE_AND_FVQ15_LOCK PASS')
print('FMQ23_PRODUCTION_REFERENCE_SOURCE_UNCHANGED PASS')
print('FMQ23_B01_RESOLVED_UPSTREAM PASS')
PY

echo 'FMQ23-G03 PASS_PRODUCTION_SERIALIZED_MULTICOLUMN_ENTRYPOINT'

(
  cd "$FMR01"
  bash tests/fmr/run_fmr01_gate.sh
) | tee "$RESULTS/fmr01_runtime_infrastructure.log"

grep -Fq 'FMR01_FOCUSED_O0_O2_GATE PASS' "$RESULTS/fmr01_runtime_infrastructure.log"
for workers in 1 2 4 8; do
  grep -Fq "FMR01_WORKERS workers=${workers} PASS" "$RESULTS/fmr01_runtime_infrastructure.log"
done
grep -Fq 'FMR01_MEMORY ' "$RESULTS/fmr01_runtime_infrastructure.log"
grep -Fq 'FMR01_DIFFICULT_TAIL ' "$RESULTS/fmr01_runtime_infrastructure.log"

echo 'FMQ23-G06 PASS_GENERIC_RUNTIME_SCRATCH_ISOLATION'
echo 'FMQ23-G13 PASS_GENERIC_DIFFICULT_TAIL_AND_FAILURE_ISOLATION'
echo 'FMQ23-G15 PASS_GENERIC_RUNTIME_WORKERS_1_2_4_8_NOT_PHYSICAL_PARALLEL_ADMISSION'
echo 'FMQ23-G16 PASS_GENERIC_RUNTIME_MEMORY_LAYOUT_OBSERVATION'

(
  cd "$CANDIDATE"
  bash tests/fmr/run_fmr05_gate.sh
) | tee "$RESULTS/fmr05_production_runtime.log"

for batch in 1 2 8 17 31 32; do
  grep -Fq "FMR05_BATCH_SIZE_${batch}=PASS" "$RESULTS/fmr05_production_runtime.log"
done
grep -Fq 'FMR05_INPUT_ORDER_INDEPENDENCE=PASS' "$RESULTS/fmr05_production_runtime.log"
grep -Fq 'FMR05_SINGLE_VS_MULTI_IDENTITY=PASS' "$RESULTS/fmr05_production_runtime.log"
grep -Fq 'FMR05_FAILURE_ISOLATION=PASS' "$RESULTS/fmr05_production_runtime.log"
grep -Fq 'FMR05_DUPLICATE_STATE_HANDLE_FAIL_CLOSED=PASS' "$RESULTS/fmr05_production_runtime.log"
grep -Fq 'FMR05_AUTHORITATIVE_MASS_COMPLETE_ALL_ACCEPTED=PASS' "$RESULTS/fmr05_production_runtime.log"
grep -Fq 'FMR05_A_B_A_REPEATABILITY=PASS' "$RESULTS/fmr05_production_runtime.log"
grep -Fq 'FMR05_IMMUTABLE_PARAMETER_SHARING=PASS' "$RESULTS/fmr05_production_runtime.log"
grep -Fq 'FMR05_CROSS_COLUMN_CHECKPOINT_REJECTION=PASS' "$RESULTS/fmr05_production_runtime.log"
grep -Fq 'FMR05_STALE_CHECKPOINT_REJECTION=PASS' "$RESULTS/fmr05_production_runtime.log"
grep -Fq 'FMR05_ROLLBACK_A_LEAVES_A_B_UNCHANGED=PASS' "$RESULTS/fmr05_production_runtime.log"
grep -Fq 'FMR05_COMMIT_A_LEAVES_B_UNCHANGED=PASS' "$RESULTS/fmr05_production_runtime.log"
grep -Fq 'FMR05_GENERIC_TIME_1000_125_TO_1000_625=PASS' "$RESULTS/fmr05_production_runtime.log"
grep -Fq 'FMR05_MAX_SIMULTANEOUS_REAL_PHYSICAL_SOLVES=1' "$RESULTS/fmr05_production_runtime.log"
grep -Fq 'FMR05_O0_O2_OUTPUT_IDENTITY PASS' "$RESULTS/fmr05_production_runtime.log"
grep -Fq 'FMR05_SINGLE_COLUMN_FMR04_MASS_BITWISE_IDENTITY=PASS' "$RESULTS/fmr05_production_runtime.log"
grep -Fq 'FMR05_SINGLE_COLUMN_FMR04_COMMITTED_STATE_IDENTITY=PASS' "$RESULTS/fmr05_production_runtime.log"
for marker in ROOT_EXTRACTION MACROPORE SNOW SWKIMPL; do
  grep -Fq "FMR05_UNSUPPORTED_${marker}=PASS" "$RESULTS/fmr05_production_runtime.log"
done

echo 'FMQ23-G04 PASS_REAL_TRANSACTION_CHECKPOINT_COMMIT_ROLLBACK'
echo 'FMQ23-G05 PASS_REAL_FAILURE_ISOLATION'
echo 'FMQ23-G07 PASS_SHARED_IMMUTABLE_PARAMETER_INTEGRITY'
echo 'FMQ23-G08 PASS_REAL_ORDER_PARTITION_INDEPENDENCE'
echo 'FMQ23-G09 PASS_SINGLE_VS_MULTI_IDENTITY'
echo 'FMQ23-G10 PASS_REAL_BATCH_MATRIX_1_2_8_17_31_32'
echo 'FMQ23-G11 PASS_REAL_A_B_A_REPEATABILITY'
echo 'FMQ23-G12 PASS_REAL_RUNTIME_DIAGNOSTICS_SERIALIZED_MAX1'
echo 'FMQ23-G14 PASS_AUTHORITATIVE_HARD_MASS'
echo 'FMQ23-G17 PASS_REAL_O0_O2_IDENTITY'
echo 'FMQ23-G18 PASS_REAL_GENERIC_TIME'

bash "$FVQ15/tests/fvq/run_fvq15_gate.sh" "$CANDIDATE" "$RESULTS/fvq15" \
  | tee "$RESULTS/fvq15_independent_scientific_replay.log"
grep -Fq 'FVQ15_GATE PASS_INDEPENDENT_SERIALIZED_MULTICOLUMN_SCIENTIFIC_ADMISSION' "$RESULTS/fvq15_independent_scientific_replay.log"
grep -Fq 'FVQ15_MAX_SCIENTIFIC_DIFFERENCE=0.0' "$RESULTS/fvq15_independent_scientific_replay.log"
for n in 1 2 17 31; do
  grep -Fq "FVQ15_DIRECT_REFERENCE_COLUMNS_${n}=PASS" "$RESULTS/fvq15_independent_scientific_replay.log"
done

echo 'FMQ23-G19 PASS_SOURCE_BOUND_SCOPE_AND_INDEPENDENT_SCIENTIFIC_REPLAY'
echo 'FMQ23_PARALLEL_REAL_PHYSICS_ADMISSION=FALSE'
echo 'FMQ23_MAX_SIMULTANEOUS_REAL_PHYSICAL_SOLVES=1'
echo 'FMQ23_PHYSICS_SCOPE=EXACT_FVQ14_RESTRICTED_PROFILE_ONLY'
echo 'FMQ23_GATE PASS_RESTRICTED_SERIALIZED_REAL_PHYSICS_MULTISWAP'

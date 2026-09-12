#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

BASE=eba90d79010b095b6556e93bd8b77a8c28d25560
BASE_TREE=ed3187c068697f17886cc85ddb9291dfbbd161d4
COMPOSITION=8c1617021ec935bc862b6cbc9be4ac6bcc94c51a
COMPOSITION_TREE=0f8c1c7eb1d84a2946675f3b76c979691b13fa50
FVQ59=f65f170fc6ec5f1a228ade2def3732cb36942ebd
FVQ59_PARENT=7b235ec2543d6bf80e74a0fa17ef8bb79bfec05b
FVQ59_STATUS_BLOB=bd0c5a2209112e3dad7aa37c23f96b53ab982da7
GOV=09ef05c60c5e45af218980001c8ad8ec30da2e9e
TX_SHA=2e6c210487bcc9f8b71367087932bee2ece216e8d019eafa1c7485d794365b96
RESTART_SHA=33b0e20bb6dd3e1200d0f361dd9296fc9aa290f71ecdeba10aeb183a17963e14
BUILD="${RUNNER_TEMP:-/tmp}/fci52-${GITHUB_RUN_ID:-local}"
rm -rf "$BUILD"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

fail() {
  echo "FCI52_GATE_FAIL $*" >&2
  exit 52
}

need_commit() {
  local sha="$1"
  git cat-file -e "${sha}^{commit}" 2>/dev/null || git fetch --no-tags origin "$sha" >/dev/null 2>&1 || fail "cannot fetch commit $sha"
}

for sha in "$BASE" "$COMPOSITION" "$FVQ59" "$FVQ59_PARENT" "$GOV"; do
  need_commit "$sha"
done

# Fail closed if either live authority moved after F-CI52 composition.
git fetch --no-tags origin integration/f-ci-canonical >/dev/null 2>&1 || fail 'cannot fetch current canonical'
CURRENT_CANONICAL="$(git rev-parse origin/integration/f-ci-canonical)"
[[ "$CURRENT_CANONICAL" == "$BASE" ]] || fail "canonical race: expected $BASE got $CURRENT_CANONICAL"
git fetch --no-tags origin regie/f-rg01-post-rb1-program-rebaseline >/dev/null 2>&1 || fail 'cannot fetch F-RG01 authority'
CURRENT_GOV="$(git rev-parse origin/regie/f-rg01-post-rb1-program-rebaseline)"
[[ "$CURRENT_GOV" == "$GOV" ]] || fail "governance race: expected $GOV got $CURRENT_GOV"
[[ "$(git rev-parse ${BASE}^{tree})" == "$BASE_TREE" ]] || fail 'canonical base tree drift'
echo 'FCI52_CANONICAL_AND_GOVERNANCE_RACE_GUARD=PASS'

# Exact production composition: one direct child, five and only five source files.
[[ "$(git rev-parse ${COMPOSITION}^)" == "$BASE" ]] || fail 'composition is not direct child of pinned canonical'
[[ "$(git rev-parse ${COMPOSITION}^{tree})" == "$COMPOSITION_TREE" ]] || fail 'composition tree drift'
PROD_PATHS=(
  src/process/mod_restricted_fixed_weir_surface_water.f90
  src/runtime/mod_fmr_fixed_weir_serialized_runtime.f90
  src/runtime/mod_fmr_restart_state_contract.f90
  src/runtime/mod_fmr_runtime_core.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
)
PROD_BLOBS=(
  16da4f6ec3d120b5a40f17ef04fb8faa457f4eaa
  f81229c2f4ad766fb8606111ca965963ebba46fe
  872c28bbc345f40073396cce57e4eb43c71de850
  43eef1979e0202f8ecc92f73eb7d8025dab515a4
  830605cc7c804ffaa57ed8f6c150e0527c863bff
)
printf '%s\n' "${PROD_PATHS[@]}" | sort > "$BUILD/expected-src.txt"
git diff --name-only "$BASE".."$COMPOSITION" -- src | sort > "$BUILD/actual-src.txt"
cmp "$BUILD/expected-src.txt" "$BUILD/actual-src.txt" || { diff -u "$BUILD/expected-src.txt" "$BUILD/actual-src.txt" >&2 || true; fail 'unexpected production source delta'; }
for i in "${!PROD_PATHS[@]}"; do
  path="${PROD_PATHS[$i]}"; blob="${PROD_BLOBS[$i]}"
  [[ "$(git rev-parse ${COMPOSITION}:$path)" == "$blob" ]] || fail "composition blob drift: $path"
  [[ "$(git rev-parse HEAD:$path)" == "$blob" ]] || fail "post-composition production drift: $path"
  [[ "$(git rev-parse ${FVQ59}:$path)" == "$blob" ]] || fail "F-VQ59 donor blob drift: $path"
done
git diff --quiet "$COMPOSITION"..HEAD -- src || fail 'admission governance changed production source after exact composition'
echo 'FCI52_EXACT_FIVE_BLOB_PRODUCTION_SCOPE=PASS'

# Reference, legacy HeadCalc, generic MultiSWAP dispatch and checkpoint orchestration stay exactly canonical.
[[ "$(git rev-parse HEAD:reference)" == "$(git rev-parse ${BASE}:reference)" ]] || fail 'reference tree changed'
for path in \
  src/legacy/b1_10_port/headcalc.f90 \
  src/runtime/mod_fmr_serialized_multiswap_runtime.f90 \
  src/runtime/mod_fmr_checkpoint_orchestrator.f90; do
  [[ "$(git rev-parse HEAD:$path)" == "$(git rev-parse ${BASE}:$path)" ]] || fail "canonical preservation drift: $path"
done
echo 'FCI52_REFERENCE_LEGACY_MULTISWAP_CHECKPOINT_PRESERVED=PASS'

# Pin the immutable F-VQ59 authority. Its final commit only persisted closeout status over the decisive tested parent.
[[ "$(git rev-parse ${FVQ59}^)" == "$FVQ59_PARENT" ]] || fail 'F-VQ59 final authority parent drift'
[[ "$(git rev-parse ${FVQ59}:integration/f-vq/F-VQ59_STATUS.json)" == "$FVQ59_STATUS_BLOB" ]] || fail 'F-VQ59 status blob drift'
git diff --name-only "$FVQ59_PARENT".."$FVQ59" | sort > "$BUILD/fvq59-final-delta.txt"
printf '%s\n' integration/f-vq/F-VQ59_STATUS.json > "$BUILD/fvq59-expected-final-delta.txt"
cmp "$BUILD/fvq59-expected-final-delta.txt" "$BUILD/fvq59-final-delta.txt" || fail 'F-VQ59 final authority contains unexpected post-test changes'
git show "${FVQ59}:integration/f-vq/F-VQ59_STATUS.json" > "$BUILD/fvq59-status.json"
python3 - "$BUILD/fvq59-status.json" <<'PY'
import json, sys
s=json.load(open(sys.argv[1]))
assert s['work_unit']=='F-VQ59'
assert s['governance_authority']=='regie/f-rg01-post-rb1-program-rebaseline@09ef05c60c5e45af218980001c8ad8ec30da2e9e'
assert s['canonical_base_at_recomposition']=='eba90d79010b095b6556e93bd8b77a8c28d25560'
assert s['candidate']['qualified_recomposed_head']=='7b235ec2543d6bf80e74a0fa17ef8bb79bfec05b'
assert s['state']['tested'] is True
assert s['state']['independently_qualified'] is True
assert s['state']['canonical_admitted'] is False
expected={
 'src/process/mod_restricted_fixed_weir_surface_water.f90':'16da4f6ec3d120b5a40f17ef04fb8faa457f4eaa',
 'src/runtime/mod_fmr_fixed_weir_serialized_runtime.f90':'f81229c2f4ad766fb8606111ca965963ebba46fe',
 'src/runtime/mod_fmr_restart_state_contract.f90':'872c28bbc345f40073396cce57e4eb43c71de850',
 'src/runtime/mod_fmr_runtime_core.f90':'43eef1979e0202f8ecc92f73eb7d8025dab515a4',
 'src/runtime/mod_fmr_serialized_reference_backend.f90':'830605cc7c804ffaa57ed8f6c150e0527c863bff'}
assert s['candidate']['production_blobs']==expected
ids=[x['id'] for x in s['architecture_invariant_audit']]
assert ids==list(range(1,31))
assert all(x['status'] in {'PRESERVED','QUALIFIED'} for x in s['architecture_invariant_audit'])
print('FCI52_FVQ59_STATUS_SEMANTICS=PASS')
PY
echo 'FCI52_FVQ59_IMMUTABLE_AUTHORITY_PINNED=PASS'

# Admission support must be byte-identical to the independently qualified F-VQ59 support.
declare -A TEST_BLOBS=(
  [tests/fpm/mod_fpm08d7_optional_state_compat.f90]=34b1cd3f3eb47eae706c6babfb91c9ace0900be0
  [tests/fpm/run_fpm08d7_fixed_weir_process_checkpoint.sh]=f324ea39c8c8c7ab0dcd0f7207ba2cadae34d20d
  [tests/fpm/run_fpm08d7_restart_lifecycle_owner.sh]=567f90d1861a412136f2409b1c99c80a2be65119
  [tests/fpm/run_fpm08d7_runtime_compile_checkpoint.sh]=6b449da8b8a37d3acec2e40fa9979be10ca0ed65
  [tests/fpm/run_fpm08d7_temporal_preservation_owner.sh]=11d31cf2bee5a49453310104e48405abe60d0a3d
  [tests/fpm/run_fpm08d7_transactional_runtime_owner.sh]=0512ae7134d50dfd360f202a8d5567a728b1d22a
  [tests/fpm/test_fpm08d7_fixed_weir_process.f90]=8377d460f95cf08b2d243924040b22583d1f88af
  [tests/fpm/test_fpm08d7_restart_lifecycle.f90]=accfe5d53cbc291f3eb4011ac4bf98c2eba29394
  [tests/fpm/test_fpm08d7_transactional_runtime.f90]=23f50c63aef2f8a5a24bca13370985148a8d6e1c
)
for path in "${!TEST_BLOBS[@]}"; do
  [[ "$(git rev-parse HEAD:$path)" == "${TEST_BLOBS[$path]}" ]] || fail "admission support blob drift: $path"
  [[ "$(git rev-parse ${FVQ59}:$path)" == "${TEST_BLOBS[$path]}" ]] || fail "F-VQ59 support blob drift: $path"
done
echo 'FCI52_FVQ59_TEST_SUPPORT_BYTE_IDENTITY=PASS'

# Explicitly re-audit all 30 architecture invariants for the admission image.
python3 - <<'PY'
import json
p='integration/f-ci/F-CI52_ARCHITECTURE_AUDIT.json'
a=json.load(open(p))
assert a['work_unit']=='F-CI52'
assert a['canonical_base']=='eba90d79010b095b6556e93bd8b77a8c28d25560'
assert a['composition_commit']=='8c1617021ec935bc862b6cbc9be4ac6bcc94c51a'
assert a['qualification_authority'].endswith('@f65f170fc6ec5f1a228ade2def3732cb36942ebd')
s=a['scope']
assert s['new_physics'] is True
assert s['new_soil_water_solver'] is False
assert s['scientific_tolerance_relaxation'] is False
assert s['mass_accounting_extension'] is True
assert s['mass_conservation']=='HARD_UNCHANGED'
assert s['reference_mode_removed_or_weakened'] is False
assert s['RB1_modified_or_reopened'] is False
assert s['large_batch_throughput_claim'] is False
assert a['production_scope']['exact_file_count']==5
ids=[x['id'] for x in a['invariants']]
assert ids==list(range(1,31)), ids
assert all(x['status'] in {'PRESERVED','QUALIFIED'} for x in a['invariants'])
print('FCI52_ARCHITECTURE_INVARIANTS_30_OF_30=PASS')
PY

# F-MR41 remains the typed optional-state identity owner; PM08D7 only adds a qualified identity and subtype use.
test ! -e src/runtime/mod_fmr_optional_state_layouts.f90 || fail 'superseded optional-state module reintroduced'
grep -Fq 'FMR_OPTIONAL_STATE_LAYOUT_FIXED_WEIR_SURFACE_WATER' src/runtime/mod_fmr_runtime_core.f90 || fail 'fixed-weir typed layout identity missing from F-MR41 registry'
python3 - <<'PY'
from pathlib import Path
import re
backend=Path('src/runtime/mod_fmr_serialized_reference_backend.f90').read_text().lower()
wrapper=Path('src/runtime/mod_fmr_fixed_weir_serialized_runtime.f90').read_text().lower()
process=Path('src/process/mod_restricted_fixed_weir_surface_water.f90').read_text().lower()
base=re.search(r'type, extends\(canonical_state_t\), public :: fmr_b110_physical_state_t(.*?)end type fmr_b110_physical_state_t', backend, re.S)
fixed=re.search(r'type, extends\(fmr_b110_physical_state_t\), public :: fmr_b110_fixed_weir_surface_water_state_t(.*?)end type fmr_b110_fixed_weir_surface_water_state_t', backend, re.S)
assert base and fixed
assert 'surface_water' not in base.group(1)
assert 'surface_water' in fixed.group(1)
assert 'call backend%clear_fixed_weir_surface_water()' in wrapper
for text,name in [(process,'process'),(wrapper,'wrapper')]:
    code='\n'.join(line.split('!')[0] for line in text.splitlines())
    for token in ['open(', 'read(', 'write(', 'close(']:
        assert token not in code, (name,token)
    assert not re.search(r'(^|[^a-z0-9_])(save|common)([^a-z0-9_]|$)', code), name
print('FCI52_FMR41_OWNER_AND_OPTIONAL_STATE_ISOLATION=PASS')
print('FCI52_NO_HIDDEN_IO_OR_PERSISTENT_PROCESS_SCRATCH=PASS')
PY

git diff --check "$BASE"..HEAD || fail 'diff hygiene failed'
echo 'FCI52_DIFF_CHECK=PASS'

# Replay the exact independently qualified scientific/runtime gates on the admission image.
bash tests/fpm/run_fpm08d7_fixed_weir_process_checkpoint.sh | tee "$BUILD/process.log"
grep -Fq 'PASS_FPM08D7_FIXED_WEIR_O0_O2_IDENTITY' "$BUILD/process.log" || fail 'fixed-weir process O0/O2 marker missing'

bash tests/fpm/run_fpm08d7_runtime_compile_checkpoint.sh | tee "$BUILD/compile.log"
grep -Fq 'FPM08D7_RUNTIME_COMPILE_O0=PASS' "$BUILD/compile.log" || fail 'runtime O0 compile marker missing'
grep -Fq 'FPM08D7_RUNTIME_COMPILE_O2=PASS' "$BUILD/compile.log" || fail 'runtime O2 compile marker missing'

FPM08D7_TX_EVIDENCE_DIR="$BUILD/tx-evidence" bash tests/fpm/run_fpm08d7_transactional_runtime_owner.sh | tee "$BUILD/transaction.log"
grep -Fq "FPM08D7_TRANSACTIONAL_RUNTIME_OUTPUT_SHA256=$TX_SHA" "$BUILD/transaction.log" || fail 'transaction output hash drift'
grep -Fq 'FPM08D7_TRANSACTIONAL_RUNTIME_O0_O2_EXACT_IDENTITY=PASS' "$BUILD/transaction.log" || fail 'transaction O0/O2 identity marker missing'
grep -Fq 'FPM08D7_INTERNAL_DRAINAGE_MASS_AND_SINGLE_COMMIT=PASS' "$BUILD/transaction.log" || fail 'mass/single-commit marker missing'
grep -Fq 'FPM08D7_SCALAR_NODE_MISMATCH_ROLLBACK=PASS' "$BUILD/transaction.log" || fail 'mismatch rollback marker missing'
grep -Fq 'FPM08D7_INFEASIBLE_SURFACE_WATER_ROLLBACK=PASS' "$BUILD/transaction.log" || fail 'infeasible rollback marker missing'

FPM08D7_RESTART_EVIDENCE_DIR="$BUILD/restart-evidence" bash tests/fpm/run_fpm08d7_restart_lifecycle_owner.sh | tee "$BUILD/restart.log"
grep -Fq "FPM08D7_RESTART_OUTPUT_SHA256=$RESTART_SHA" "$BUILD/restart.log" || fail 'restart output hash drift'
grep -Fq 'FPM08D7_RESTART_O0_O2_EXACT_IDENTITY=PASS' "$BUILD/restart.log" || fail 'restart O0/O2 identity marker missing'
grep -Fq 'FPM08D7_RESTART_LAYOUT_TYPE_FAIL_CLOSED=PASS' "$BUILD/restart.log" || fail 'restart fail-closed marker missing'
grep -Fq 'FPM08D7_RESTART_REJECTION_ATOMIC=PASS' "$BUILD/restart.log" || fail 'restart atomic rejection marker missing'
grep -Fq 'FPM08D7_RESTART_ROUNDTRIP_EXACT=PASS' "$BUILD/restart.log" || fail 'restart roundtrip marker missing'

echo 'FCI52_PM08D7_SCIENTIFIC_TRANSACTION_RESTART_REPLAY=PASS'
echo 'FCI52_MASS_CONSERVATION=HARD_UNCHANGED'
echo 'FCI52_LARGE_BATCH_THROUGHPUT_CLAIM=NOT_MADE'
echo 'FCI52_NEW_GROUNDWATER_COUPLING_CAPABILITY=NOT_CLAIMED'
echo 'FCI52_RB1_REOPENED=NO'
echo 'FCI52_CANONICAL_ADMISSION_GATE=PASS'

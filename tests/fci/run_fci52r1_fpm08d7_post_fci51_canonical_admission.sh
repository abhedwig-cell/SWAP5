#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

BASE=8695974b783e76b3807890be9e1c0ecb5d2f8d5f
BASE_TREE=64d6768b80965ad3449899658023698d5d871f3e
PREVIOUS_CANONICAL=eba90d79010b095b6556e93bd8b77a8c28d25560
FCI51=3f8492fc4ac36e7afd6132f130836a4a45aea3f2
COMPOSITION=7a35e123d263c3783a2a0a14ea467e5e065b821c
COMPOSITION_TREE=7c2de6b13d046e8ec858dd1a7461d128e4354f9e
FVQ59=f65f170fc6ec5f1a228ade2def3732cb36942ebd
GOV=09ef05c60c5e45af218980001c8ad8ec30da2e9e
TX_SHA=2e6c210487bcc9f8b71367087932bee2ece216e8d019eafa1c7485d794365b96
RESTART_SHA=33b0e20bb6dd3e1200d0f361dd9296fc9aa290f71ecdeba10aeb183a17963e14
BUILD="${RUNNER_TEMP:-/tmp}/fci52r1-${GITHUB_RUN_ID:-local}"
rm -rf "$BUILD"; mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "FCI52R1_GATE_FAIL $*" >&2; exit 52; }
need(){ git cat-file -e "$1^{commit}" 2>/dev/null || git fetch --no-tags origin "$1" >/dev/null 2>&1 || fail "cannot fetch $1"; }
for c in "$BASE" "$PREVIOUS_CANONICAL" "$FCI51" "$COMPOSITION" "$FVQ59" "$GOV"; do need "$c"; done

# Current-canonical and governance race guards.
git fetch --no-tags origin integration/f-ci-canonical >/dev/null 2>&1 || fail 'cannot fetch canonical'
[[ "$(git rev-parse origin/integration/f-ci-canonical)" == "$BASE" ]] || fail "canonical moved: expected $BASE got $(git rev-parse origin/integration/f-ci-canonical)"
git fetch --no-tags origin regie/f-rg01-post-rb1-program-rebaseline >/dev/null 2>&1 || fail 'cannot fetch F-RG01'
[[ "$(git rev-parse origin/regie/f-rg01-post-rb1-program-rebaseline)" == "$GOV" ]] || fail 'F-RG01 moved'
[[ "$(git rev-parse ${BASE}^{tree})" == "$BASE_TREE" ]] || fail 'base tree drift'
# F-CI51 must be the admitted intervening successor of the old canonical.
parents="$(git rev-list --parents -n1 "$BASE")"
grep -Fq "$PREVIOUS_CANONICAL" <<<"$parents" || fail 'post-F-CI51 canonical lost prior canonical parent'
grep -Fq "$FCI51" <<<"$parents" || fail 'post-F-CI51 canonical lost F-CI51 parent'
echo 'FCI52R1_CANONICAL_GOVERNANCE_AND_FCI51_LINEAGE=PASS'

# Exact five production blobs, directly on post-F-CI51 canonical.
[[ "$(git rev-parse ${COMPOSITION}^)" == "$BASE" ]] || fail 'composition is not direct child of current canonical'
[[ "$(git rev-parse ${COMPOSITION}^{tree})" == "$COMPOSITION_TREE" ]] || fail 'composition tree drift'
paths=(
 src/process/mod_restricted_fixed_weir_surface_water.f90
 src/runtime/mod_fmr_fixed_weir_serialized_runtime.f90
 src/runtime/mod_fmr_restart_state_contract.f90
 src/runtime/mod_fmr_runtime_core.f90
 src/runtime/mod_fmr_serialized_reference_backend.f90)
blobs=(
 16da4f6ec3d120b5a40f17ef04fb8faa457f4eaa
 f81229c2f4ad766fb8606111ca965963ebba46fe
 872c28bbc345f40073396cce57e4eb43c71de850
 43eef1979e0202f8ecc92f73eb7d8025dab515a4
 830605cc7c804ffaa57ed8f6c150e0527c863bff)
printf '%s\n' "${paths[@]}" | sort > "$BUILD/expected-src"
git diff --name-only "$BASE".."$COMPOSITION" -- src | sort > "$BUILD/actual-src"
cmp "$BUILD/expected-src" "$BUILD/actual-src" || fail 'unexpected production delta'
for i in "${!paths[@]}"; do p="${paths[$i]}"; b="${blobs[$i]}"; [[ "$(git rev-parse HEAD:$p)" == "$b" ]] || fail "HEAD blob drift $p"; [[ "$(git rev-parse ${FVQ59}:$p)" == "$b" ]] || fail "F-VQ59 blob drift $p"; done
git diff --quiet "$COMPOSITION"..HEAD -- src || fail 'production source changed after composition'
echo 'FCI52R1_EXACT_FIVE_BLOB_PRODUCTION_SCOPE=PASS'

# Preserve all F-CI51 production and evidence content from current canonical.
git diff --quiet "$BASE"..HEAD -- src/crop || fail 'F-CI51 crop production drift'
for p in \
 .github/workflows/fci51-wof43a-current-canonical-admission.yml \
 integration/f-ci/F-CI51_CANDIDATE_CONTRACT.json \
 integration/f-vq/F-VQ37_STATUS.json \
 integration/f-wof/F-WOF43A_STATUS.json \
 src/crop/mod_crop_et_canopy_view_provider.f90 \
 tests/fci/run_fci51_wof43a_current_canonical_gate.sh; do
 [[ "$(git rev-parse HEAD:$p)" == "$(git rev-parse ${BASE}:$p)" ]] || fail "F-CI51 preservation drift $p"
done
echo 'FCI52R1_FCI51_BIT_PRESERVATION=PASS'

# Preserve reference, legacy, generic MultiSWAP and checkpoint owners.
[[ "$(git rev-parse HEAD:reference)" == "$(git rev-parse ${BASE}:reference)" ]] || fail 'reference tree drift'
for p in src/legacy/b1_10_port/headcalc.f90 src/runtime/mod_fmr_serialized_multiswap_runtime.f90 src/runtime/mod_fmr_checkpoint_orchestrator.f90; do [[ "$(git rev-parse HEAD:$p)" == "$(git rev-parse ${BASE}:$p)" ]] || fail "preservation drift $p"; done
echo 'FCI52R1_REFERENCE_LEGACY_MULTISWAP_CHECKPOINT_PRESERVED=PASS'

# Byte-identical F-VQ59 support and architecture audit.
declare -A T=(
 [tests/fpm/mod_fpm08d7_optional_state_compat.f90]=34b1cd3f3eb47eae706c6babfb91c9ace0900be0
 [tests/fpm/run_fpm08d7_fixed_weir_process_checkpoint.sh]=f324ea39c8c8c7ab0dcd0f7207ba2cadae34d20d
 [tests/fpm/run_fpm08d7_restart_lifecycle_owner.sh]=567f90d1861a412136f2409b1c99c80a2be65119
 [tests/fpm/run_fpm08d7_runtime_compile_checkpoint.sh]=6b449da8b8a37d3acec2e40fa9979be10ca0ed65
 [tests/fpm/run_fpm08d7_temporal_preservation_owner.sh]=11d31cf2bee5a49453310104e48405abe60d0a3d
 [tests/fpm/run_fpm08d7_transactional_runtime_owner.sh]=0512ae7134d50dfd360f202a8d5567a728b1d22a
 [tests/fpm/test_fpm08d7_fixed_weir_process.f90]=8377d460f95cf08b2d243924040b22583d1f88af
 [tests/fpm/test_fpm08d7_restart_lifecycle.f90]=accfe5d53cbc291f3eb4011ac4bf98c2eba29394
 [tests/fpm/test_fpm08d7_transactional_runtime.f90]=23f50c63aef2f8a5a24bca13370985148a8d6e1c)
for p in "${!T[@]}"; do [[ "$(git rev-parse HEAD:$p)" == "${T[$p]}" ]] || fail "test support drift $p"; [[ "$(git rev-parse ${FVQ59}:$p)" == "${T[$p]}" ]] || fail "F-VQ59 support drift $p"; done
python3 - <<'PY'
import json,re
from pathlib import Path
a=json.load(open('integration/f-ci/F-CI52R1_ARCHITECTURE_AUDIT.json'))
assert a['work_unit']=='F-CI52' and a['revision']=='R1_POST_FCI51_RECOMPOSITION'
assert a['canonical_base']=='8695974b783e76b3807890be9e1c0ecb5d2f8d5f'
assert a['composition_commit']=='7a35e123d263c3783a2a0a14ea467e5e065b821c'
s=a['scope']; assert s['new_physics'] is True and s['new_soil_water_solver'] is False
assert s['mass_accounting_extension'] is True and s['mass_conservation']=='HARD_UNCHANGED'
assert s['scientific_tolerance_relaxation'] is False and s['F_CI51_crop_provider_preserved'] is True
assert [x['id'] for x in a['invariants']]==list(range(1,31))
assert all(x['status'] in {'PRESERVED','QUALIFIED'} for x in a['invariants'])
backend=Path('src/runtime/mod_fmr_serialized_reference_backend.f90').read_text().lower()
wrapper=Path('src/runtime/mod_fmr_fixed_weir_serialized_runtime.f90').read_text().lower()
base=re.search(r'type, extends\(canonical_state_t\), public :: fmr_b110_physical_state_t(.*?)end type fmr_b110_physical_state_t',backend,re.S)
fixed=re.search(r'type, extends\(fmr_b110_physical_state_t\), public :: fmr_b110_fixed_weir_surface_water_state_t(.*?)end type fmr_b110_fixed_weir_surface_water_state_t',backend,re.S)
assert base and fixed and 'surface_water' not in base.group(1) and 'surface_water' in fixed.group(1)
assert 'call backend%clear_fixed_weir_surface_water()' in wrapper
print('FCI52R1_ARCHITECTURE_INVARIANTS_30_OF_30=PASS')
print('FCI52R1_OPTIONAL_STATE_ISOLATION=PASS')
PY
test ! -e src/runtime/mod_fmr_optional_state_layouts.f90 || fail 'superseded optional-state module returned'
grep -Fq 'FMR_OPTIONAL_STATE_LAYOUT_FIXED_WEIR_SURFACE_WATER' src/runtime/mod_fmr_runtime_core.f90 || fail 'F-MR41 layout identity missing'
git diff --check "$BASE"..HEAD || fail 'diff hygiene failed'
echo 'FCI52R1_FMR41_OWNER_AND_DIFF_HYGIENE=PASS'

# Exact current-image scientific/runtime requalification.
bash tests/fpm/run_fpm08d7_fixed_weir_process_checkpoint.sh | tee "$BUILD/process.log"
grep -Fq 'PASS_FPM08D7_FIXED_WEIR_O0_O2_IDENTITY' "$BUILD/process.log" || fail 'process identity marker missing'
bash tests/fpm/run_fpm08d7_runtime_compile_checkpoint.sh | tee "$BUILD/compile.log"
grep -Fq 'FPM08D7_RUNTIME_COMPILE_O0=PASS' "$BUILD/compile.log" || fail 'compile O0 missing'
grep -Fq 'FPM08D7_RUNTIME_COMPILE_O2=PASS' "$BUILD/compile.log" || fail 'compile O2 missing'
FPM08D7_TX_EVIDENCE_DIR="$BUILD/tx" bash tests/fpm/run_fpm08d7_transactional_runtime_owner.sh | tee "$BUILD/tx.log"
grep -Fq "FPM08D7_TRANSACTIONAL_RUNTIME_OUTPUT_SHA256=$TX_SHA" "$BUILD/tx.log" || fail 'transaction hash drift'
for m in FPM08D7_TRANSACTIONAL_RUNTIME_O0_O2_EXACT_IDENTITY=PASS FPM08D7_INTERNAL_DRAINAGE_MASS_AND_SINGLE_COMMIT=PASS FPM08D7_SCALAR_NODE_MISMATCH_ROLLBACK=PASS FPM08D7_INFEASIBLE_TRIAL_ROLLBACK=PASS; do grep -Fq "$m" "$BUILD/tx.log" || fail "missing $m"; done
FPM08D7_RESTART_EVIDENCE_DIR="$BUILD/restart" bash tests/fpm/run_fpm08d7_restart_lifecycle_owner.sh | tee "$BUILD/restart.log"
grep -Fq "FPM08D7_RESTART_OUTPUT_SHA256=$RESTART_SHA" "$BUILD/restart.log" || fail 'restart hash drift'
for m in FPM08D7_RESTART_O0_O2_EXACT_IDENTITY=PASS FPM08D7_RESTART_LAYOUT_TYPE_FAIL_CLOSED=PASS FPM08D7_RESTART_REJECTION_ATOMIC=PASS FPM08D7_RESTART_ROUNDTRIP_EXACT=PASS; do grep -Fq "$m" "$BUILD/restart.log" || fail "missing $m"; done

echo 'FCI52R1_PM08D7_CURRENT_IMAGE_REQUALIFICATION=PASS'
echo 'FCI52R1_MASS_CONSERVATION=HARD_UNCHANGED'
echo 'FCI52R1_FCI51_PRESERVED=YES'
echo 'FCI52R1_RB1_REOPENED=NO'
echo 'FCI52R1_CANONICAL_ADMISSION_GATE=PASS'

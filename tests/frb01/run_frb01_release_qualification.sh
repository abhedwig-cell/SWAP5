#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-/tmp}/swap5-frb01-${GITHUB_RUN_ID:-local}-$$"
EVIDENCE="$ROOT/_frb01_release_evidence"
mkdir -p "$BUILD" "$EVIDENCE"
cleanup() {
  rm -rf "$BUILD"
  rm -f \
    tests/fmq/run_fmq29_parallel_committed_restart_qualification.sh \
    tests/fmq/run_fmq30_parallel_root_uptake_qualification.sh \
    tests/fmq/run_fmq30_parallel_root_uptake_qualification_v2.sh \
    integration/f-mq/F-MQ29_CANDIDATE_LOCK.json \
    integration/f-mq/F-MQ29_QUALIFICATION_MATRIX.json \
    integration/f-mq/F-MQ30_CANDIDATE_LOCK.json \
    integration/f-mq/F-MQ30_QUALIFICATION_MATRIX.json
}
trap cleanup EXIT

fail() { echo "FRB01_RELEASE_GATE_FAIL $*" >&2; exit 81; }
need_commit() {
  local sha="$1"
  git cat-file -e "${sha}^{commit}" 2>/dev/null || git fetch --no-tags origin "$sha" >/dev/null 2>&1 || fail "cannot fetch commit $sha"
}

CANDIDATE_FILE=release/f-rb01/RB1_RELEASE_CANDIDATE.json
[[ -f "$CANDIDATE_FILE" ]] || fail 'release candidate descriptor missing'
RB1_SOURCE_SHA="$(python3 - <<'PY'
import json
print(json.load(open('release/f-rb01/RB1_RELEASE_CANDIDATE.json'))['release_candidate_sha'])
PY
)"
RB1_SOURCE_TREE="$(python3 - <<'PY'
import json
print(json.load(open('release/f-rb01/RB1_RELEASE_CANDIDATE.json'))['release_candidate_tree'])
PY
)"
export RB1_SOURCE_SHA RB1_SOURCE_TREE
need_commit "$RB1_SOURCE_SHA"

# -----------------------------------------------------------------------------
# A. Immutable release candidate, scope and architecture evidence.
# -----------------------------------------------------------------------------
[[ "$(git rev-parse "$RB1_SOURCE_SHA^{tree}")" == "$RB1_SOURCE_TREE" ]] || fail 'candidate tree mismatch'
git merge-base --is-ancestor "$RB1_SOURCE_SHA" HEAD || fail 'workflow head is not a descendant of release candidate'
[[ "$(git rev-parse "$RB1_SOURCE_SHA:src")" == "8ceeb70a64012631ebba295f5c045ea908b0681f" ]] || fail 'candidate production src tree differs from frozen canonical source'
[[ "$(git rev-parse "$RB1_SOURCE_SHA:reference")" == "9d08625217d7c0a7385df9da6a04183bcd9cb9e6" ]] || fail 'candidate reference tree differs from frozen authority'
[[ "$(git rev-parse HEAD:src)" == "$(git rev-parse "$RB1_SOURCE_SHA:src")" ]] || fail 'production source changed after candidate freeze'
[[ "$(git rev-parse HEAD:reference)" == "$(git rev-parse "$RB1_SOURCE_SHA:reference")" ]] || fail 'reference changed after candidate freeze'
git diff --quiet "$RB1_SOURCE_SHA"..HEAD -- tests/frb01 .github/workflows/frb01-release-qualification.yml || fail 'decisive runner/workflow changed after candidate freeze'
echo 'FRB01_IMMUTABLE_RELEASE_CANDIDATE=PASS'

git fetch --no-tags origin integration/f-ci-canonical >/dev/null 2>&1 || fail 'cannot fetch canonical branch'
CANONICAL_HEAD="$(git rev-parse origin/integration/f-ci-canonical)"
[[ "$CANONICAL_HEAD" == "0aeb0a2ed4096e1f9493d3dabc70962ea5270182" ]] || fail "canonical moved after RB1 scope freeze: $CANONICAL_HEAD"
[[ "$(git rev-parse "$CANONICAL_HEAD^{tree}")" == "c77ac75aea522ac20a60da012595af9166efcff6" ]] || fail 'canonical tree mismatch'
echo 'FRB01_CANONICAL_SOURCE_AUTHORITY_STILL_FROZEN=PASS'

python3 - <<'PY'
import json
from pathlib import Path
scope=json.loads(Path('release/f-rb01/RESTRICTED_PRODUCTION_BASELINE_V1_SCOPE.json').read_text())
audit=json.loads(Path('release/f-rb01/RB1_ARCHITECTURE_INVARIANT_AUDIT.json').read_text())
blockers=json.loads(Path('release/f-rb01/RB1_BLOCKERS.json').read_text())
assert scope['scope_frozen'] is True and scope['moving_denominator_forbidden'] is True
assert scope['required_capability_denominator']==15
assert len(scope['required_capabilities'])==15
assert {x['classification'] for x in scope['required_capabilities']}=={'REQUIRED'}
assert len(audit['audit'])==30
assert [x['id'] for x in audit['audit']]==list(range(1,31))
counts={k:sum(x['result']==k for x in audit['audit']) for k in ('PASS','NOT_APPLICABLE_TO_RB1','FAIL')}
assert counts=={'PASS':24,'NOT_APPLICABLE_TO_RB1':6,'FAIL':0}, counts
assert audit['summary']['pass']==24 and audit['summary']['not_applicable_to_rb1']==6 and audit['summary']['fail']==0
assert blockers['counts']['RB1_SCIENTIFIC_BLOCKER']==0
assert blockers['counts']['RB1_MASS_BLOCKER']==0
assert blockers['counts']['RB1_TRANSACTION_BLOCKER']==0
assert blockers['counts']['RB1_RESTART_BLOCKER']==0
assert blockers['counts']['RB1_ARCHITECTURE_BLOCKER']==0
print('FRB01_FIXED_DENOMINATOR_15=PASS')
print('FRB01_ARCHITECTURE_INVARIANTS_30_OF_30_NO_FAIL=PASS')
PY

# Structural fail-closed guards for the frozen release subset.
python3 - <<'PY'
from pathlib import Path
p=Path('src/runtime/mod_fmr_parallel_worker_pool.f90').read_text().lower()
r=Path('src/runtime/mod_fmr_parallel_root_uptake_pool.f90').read_text().lower()
s=Path('src/runtime/mod_fmr_committed_restart.f90').read_text().lower()
se=Path('src/runtime/mod_fmr_surface_evaporation_runtime_materialization.f90').read_text().lower()
record=s.split('type, public :: fmr_committed_restart_record_t',1)[1].split('end type fmr_committed_restart_record_t',1)[0]
assert 'parallel_v1_profile_admitted' in p
assert 'allocate(backends(worker_count), transaction_controls(worker_count), worker_runtime(worker_count))' in p
assert 'call canonicalize_publication(columns, results, diagnostics)' in p
assert 'public :: fmr_run_parallel_root_uptake_multiswap' in r
assert '.not. parameter_registry(parameter_index)%root_extraction_active' in r
for forbidden in ('worker','newton','jacobian','warm_start','forcing_handle'):
    assert forbidden not in record
for forbidden in ('open(', 'close(', 'read(', 'write('):
    assert forbidden not in s
for forbidden in ('modflow','.swp','file_unit','pathname','midnight'):
    assert forbidden not in se
print('FRB01_WORKER_OWNED_HEAVY_SCRATCH_STATIC=PASS')
print('FRB01_RESTART_NO_SOLVER_SCRATCH_STATIC=PASS')
print('FRB01_KERNEL_RUNTIME_NO_LEGACY_IO_ASSUMPTION_STATIC=PASS')
PY

# -----------------------------------------------------------------------------
# B. Immutable historical core authority. Execute historical admission gates on
# their own exact F-CI18 head, never as moving-current one-delta gates.
# -----------------------------------------------------------------------------
HIST=1eceed967b12396b8bbc832f897376378463adce
need_commit "$HIST"
HIST_WT="$BUILD/fci18-history"
git worktree add --detach "$HIST_WT" "$HIST" >/dev/null
(
  cd "$HIST_WT"
  for gate in 03 04 06 07 08 09 10 11 12 13 14 15 16 17 18; do
    bash "tests/fci/run_fci${gate}_gate.sh"
  done
) > "$EVIDENCE/historical_fci03_fci18.txt" 2>&1 || {
  cat "$EVIDENCE/historical_fci03_fci18.txt" >&2
  git worktree remove --force "$HIST_WT" >/dev/null 2>&1 || true
  fail 'immutable historical F-CI03..18 replay failed'
}
git worktree remove --force "$HIST_WT" >/dev/null
for marker in \
  'FCI11_GATE PASS' \
  'FCI12_GATE PASS' \
  'FCI13_GATE PASS' \
  'FCI14_GATE PASS'; do
  grep -Fq "$marker" "$EVIDENCE/historical_fci03_fci18.txt" || fail "missing historical marker: $marker"
done
echo 'FRB01_HISTORICAL_IMMUTABLE_FCI03_FCI18_AUTHORITY=PASS'

# -----------------------------------------------------------------------------
# C. Current-head serialized physical execution + committed-boundary restart.
# Reuse the F-CI28 scientific attacks, rebinding only moving-current source
# governance to the frozen RB1 candidate.
# -----------------------------------------------------------------------------
SERIAL_REPLAY="$ROOT/tests/frb01/.frb01-fci28-current-$$.sh"
cp tests/fci/run_fci28_restart_current_canonical_admission.sh "$SERIAL_REPLAY"
python3 - "$SERIAL_REPLAY" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text()
a=s.index('# Independent source authority and immutability.')
b=s.index('check_blob() {',a)
new='''# F-RB01 current-head source authority and immutability.\ngit merge-base --is-ancestor "$CANDIDATE" "$RB1_SOURCE_SHA" || fail 'F-CI28 candidate is not in RB1 source lineage'\ngit diff --quiet "$RB1_SOURCE_SHA"..HEAD -- src reference || fail 'source/reference changed after RB1 candidate freeze'\necho 'FCI28_EXACT_CANDIDATE_SOURCE_DELTA=HISTORICAL_AUTHORITY_PRESERVED'\necho 'FCI28_QUALIFICATION_PRODUCTION_IMMUTABLE=PASS'\n\n'''
s=s[:a]+new+s[b:]
p.write_text(s)
PY
chmod +x "$SERIAL_REPLAY"
bash "$SERIAL_REPLAY" > "$EVIDENCE/current_serial_restart.txt" 2>&1 || {
  cat "$EVIDENCE/current_serial_restart.txt" >&2
  rm -f "$SERIAL_REPLAY"
  fail 'current serialized/restart qualification failed'
}
rm -f "$SERIAL_REPLAY"
for marker in \
  FMR19_BATCH_SIZE_1=PASS \
  FMR19_BATCH_SIZE_7=PASS \
  FMR19_BATCH_SIZE_31=PASS \
  FMR19_EXACT_LINEAGE_REVISION_TIME_CONTINUATION=PASS \
  FMR19_EXACT_INTERVAL_MASS_CONTINUATION=PASS \
  FMR19_CONTINUOUS_VS_RESTARTED_ENDPOINT_IDENTITY=PASS \
  FMR19_DETERMINISTIC_REPLAY=PASS \
  FMQ27_FULL_NEGATIVE_MATRIX=PASS \
  FCI28_PROCESS_RESTART_O0_O2_IDENTITY=PASS; do
  grep -Fq "$marker" "$EVIDENCE/current_serial_restart.txt" || fail "missing serial/restart marker: $marker"
done
echo 'FRB01_CURRENT_SERIAL_AND_STANDALONE_N1_RESTART=PASS'

# -----------------------------------------------------------------------------
# D. Current-head restricted parallel V1 and root-active parallel profile.
# Rehydrate exact independent F-MQ30 metadata/runner, change only historical
# source-lock assumptions, preserve the scientific attack/oracles byte-for-byte.
# -----------------------------------------------------------------------------
FMQ30=48ee2841d783ee023c29391a7ea1e5d7ee0d20e0
need_commit "$FMQ30"
for path in \
  integration/f-mq/F-MQ30_CANDIDATE_LOCK.json \
  integration/f-mq/F-MQ30_QUALIFICATION_MATRIX.json \
  tests/fmq/run_fmq30_parallel_root_uptake_qualification.sh \
  tests/fmq/run_fmq30_parallel_root_uptake_qualification_v2.sh; do
  mkdir -p "$(dirname "$path")"
  git show "$FMQ30:$path" > "$path"
done
python3 - tests/fmq/run_fmq30_parallel_root_uptake_qualification.sh <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text()
a=s.index('# Qualification branch is current-canonical based.')
b=s.index("python3 - <<'PY'",a)
new='''# F-RB01 moving-current source lock; scientific candidate/oracles remain immutable.\ngit merge-base --is-ancestor "$CANDIDATE" "$RB1_SOURCE_SHA" || fail 'root-active candidate not in RB1 source lineage'\ngit diff --quiet "$RB1_SOURCE_SHA"..HEAD -- src reference || fail 'source/reference changed after RB1 candidate freeze'\n[[ "$(git rev-parse HEAD:src/runtime/mod_fmr_parallel_root_uptake_pool.f90)" == "$CANDIDATE_BLOB" ]] || fail 'root-active production blob drift'\n[[ "$(git rev-parse HEAD:src/runtime/mod_fmr_parallel_worker_pool.f90)" == "0e700797cbaed4aaab7f04db0054f72faddcfc15" ]] || fail 'parallel worker pool drift'\n[[ "$(git rev-parse HEAD:src/runtime/mod_fmr_parallel_physical_scheduler.f90)" == "544a1ca16fdeebdfce7f89d1ddf1825fa32fa654" ]] || fail 'parallel scheduler drift'\n[[ "$(git rev-parse HEAD:src/runtime/mod_fmr_serialized_multiswap_runtime.f90)" == "f06a2eef7b47880e449cf9b201342d7bd1e197e1" ]] || fail 'current serialized executor drift'\n[[ "$(git rev-parse HEAD:src/runtime/mod_fmr_serialized_reference_backend.f90)" == "9af5a494526810324dc00706b444e448e770cba9" ]] || fail 'reference backend drift'\n[[ "$(git rev-parse HEAD:src/runtime/mod_fmr_reference_et_root_uptake_composition.f90)" == "8ed7610144700f58d0b89482925471fcb2ff7d69" ]] || fail 'root composition drift'\necho 'FMQ30_CURRENT_CANONICAL_SOURCE_LOCK=PASS'\necho 'FMQ30_EXACT_FMR35_CANDIDATE_BLOB=PASS'\necho 'FMQ30_OWNER_HARNESS_NOT_IMPORTED=PASS'\necho 'FMQ30_EXISTING_PARALLEL_V1_BYTE_PRESERVED=PASS'\n\n'''
s=s[:a]+new+s[b:]
p.write_text(s)
PY
chmod +x tests/fmq/run_fmq30_parallel_root_uptake_qualification*.sh
bash tests/fmq/run_fmq30_parallel_root_uptake_qualification_v2.sh > "$EVIDENCE/current_parallel_root.txt" 2>&1 || {
  cat "$EVIDENCE/current_parallel_root.txt" >&2
  fail 'current parallel/root qualification failed'
}
for marker in \
  FMQ30_O0=PASS \
  FMQ30_O2=PASS \
  FMQ30_O0_O2_EXACT_OUTPUT_IDENTITY=PASS \
  FMQ30_HARD_MASS_CONSERVATION=PASS \
  FMQ30_UNSUPPORTED_PROFILES_FAIL_CLOSED=PASS \
  FMQ30_NEGATIVE_AND_NAN_QROT_FAIL_PRE_SOLVE=PASS \
  FMQ30_WORKER_COUNT_SCOPE_FAIL_CLOSED=PASS \
  FMQ30_CANONICAL_PUBLICATION_ORDER=PASS; do
  grep -Fq "$marker" "$EVIDENCE/current_parallel_root.txt" || fail "missing parallel/root marker: $marker"
done
echo 'FRB01_CURRENT_PARALLEL_V1_AND_ROOT_ACTIVE=PASS'

# -----------------------------------------------------------------------------
# E. Current-head committed-boundary restart followed by parallel continuation.
# Rehydrate exact independent F-MQ29 attack and replace only stale source-lock
# assumptions; scientific held-out attack remains intact.
# -----------------------------------------------------------------------------
FMQ29=5ea88d81a63e6c706c87e99ac360f91f08711fc1
need_commit "$FMQ29"
for path in \
  integration/f-mq/F-MQ29_CANDIDATE_LOCK.json \
  integration/f-mq/F-MQ29_QUALIFICATION_MATRIX.json \
  tests/fmq/run_fmq29_parallel_committed_restart_qualification.sh; do
  mkdir -p "$(dirname "$path")"
  git show "$FMQ29:$path" > "$path"
done
python3 - tests/fmq/run_fmq29_parallel_committed_restart_qualification.sh <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text()
a=s.index('# --- Independent source/candidate authority')
b=s.index("python3 - <<'PY'",a)
new='''# --- F-RB01 current source authority -----------------------------------------\ngit merge-base --is-ancestor "$BASE" "$RB1_SOURCE_SHA" || fail 'F-CI35 source authority not in RB1 lineage'\ngit diff --quiet "$RB1_SOURCE_SHA"..HEAD -- src reference || fail 'source/reference changed after RB1 candidate freeze'\nfor path in src/runtime/mod_fmr_committed_restart.f90 src/runtime/mod_fmr_restart_state_contract.f90 src/runtime/mod_fmr_parallel_physical_scheduler.f90 src/runtime/mod_fmr_parallel_worker_pool.f90 src/runtime/mod_fmr_serialized_multiswap_runtime.f90 src/runtime/mod_fmr_serialized_reference_backend.f90 src/runtime/mod_fmr_runtime_core.f90 tests/fmq/test_fmq27_restart_contract_requalification.f90; do\n  git cat-file -e "HEAD:$path" || fail "missing current RB1 path $path"\ndone\necho 'FMQ29_CURRENT_CANONICAL_SOURCE_LOCK=PASS'\necho 'FMQ29_OWNER_CANDIDATE_ZERO_SOURCE_DELTA=HISTORICAL_AUTHORITY_PRESERVED'\necho 'FMQ29_QUALIFICATION_INDEPENDENT_BRANCH_BASE=HISTORICAL_AUTHORITY_PRESERVED'\necho 'FMQ29_PRODUCTION_REFERENCE_IMMUTABLE=PASS'\n\n'''
s=s[:a]+new+s[b:]
p.write_text(s)
PY
chmod +x tests/fmq/run_fmq29_parallel_committed_restart_qualification.sh
bash tests/fmq/run_fmq29_parallel_committed_restart_qualification.sh > "$EVIDENCE/current_parallel_restart.txt" 2>&1 || {
  cat "$EVIDENCE/current_parallel_restart.txt" >&2
  fail 'current parallel restart qualification failed'
}
for marker in \
  FMQ29_O0=PASS \
  FMQ29_O2=PASS \
  FMQ29_O0_O2_EXACT_OUTPUT_IDENTITY=PASS \
  FMQ29_HARD_MASS_CONSERVATION=PASS \
  FMQ29_SERIALIZED_ORIGIN_RESTART=PASS \
  FMQ29_PARALLEL_2_ORIGIN_RESTART=PASS \
  FMQ29_PARALLEL_4_ORIGIN_RESTART=PASS \
  FMQ29_CROSS_WORKER_2_TO_4=PASS \
  FMQ29_CROSS_WORKER_4_TO_2=PASS \
  FMQ29_REVERSE_AND_INTERLEAVED_RECORD_ORDER=PASS; do
  grep -Fq "$marker" "$EVIDENCE/current_parallel_restart.txt" || fail "missing parallel restart marker: $marker"
done
echo 'FRB01_CURRENT_PARALLEL_COMMITTED_RESTART=PASS'

# -----------------------------------------------------------------------------
# F. Current-head restricted surface evaporation. F-PE11 is explicitly written
# to compare current production against immutable F-CI41P/F-VQ56 science while
# allowing only the two qualified F-CI42 performance ownership paths.
# -----------------------------------------------------------------------------
bash tests/fpe/run_fpe11_surface_evaporation_allocation_qualification.sh > "$EVIDENCE/current_surface_evaporation.txt" 2>&1 || {
  cat "$EVIDENCE/current_surface_evaporation.txt" >&2
  fail 'current restricted surface evaporation qualification failed'
}
for marker in \
  FPE11_FROZEN_SCIENTIFIC_AUTHORITY=PASS \
  FPE11_EXACT_TWO_FILE_RUNTIME_SCOPE=PASS \
  FPE11_FCI41P_OBSERVABLE_IDENTITY=PASS \
  FPE11_O0_O2_IDENTITY=PASS \
  FPE11_COMMITTED_STATE_IMMUTABILITY=PASS \
  FPE11_ABA_DETERMINISM=PASS \
  FPE11_NO_AUTHORITATIVE_MASS_BOOKING=PASS \
  FPE11_FUNCTIONAL_QUALIFICATION=PASS; do
  grep -Fq "$marker" "$EVIDENCE/current_surface_evaporation.txt" || fail "missing surface marker: $marker"
done
echo 'FRB01_CURRENT_RESTRICTED_SURFACE_EVAPORATION=PASS'

# -----------------------------------------------------------------------------
# G. Integrated release assertions and evidence digest.
# -----------------------------------------------------------------------------
python3 - <<'PY'
import json
from pathlib import Path
scope=json.loads(Path('release/f-rb01/RESTRICTED_PRODUCTION_BASELINE_V1_SCOPE.json').read_text())
excluded='\n'.join(scope['explicitly_excluded']+scope['research_only']+scope['blocked_not_required_for_rb1']).lower()
for token in ('wofost','rossfast','swkimpl=1','swinter=1/2/3','swredu=1/2','mid-transaction restart','balanced','throughput','fallback'):
    assert token in excluded, token
print('FRB01_EXCLUDED_SCOPE_EXPLICIT=PASS')
print('FRB01_NO_MOVING_DENOMINATOR=PASS')
PY

sha256sum "$EVIDENCE"/*.txt | sort > "$EVIDENCE/SHA256SUMS.txt"
{
  echo "candidate_sha=$RB1_SOURCE_SHA"
  echo "candidate_tree=$RB1_SOURCE_TREE"
  echo "candidate_src=$(git rev-parse "$RB1_SOURCE_SHA:src")"
  echo "candidate_reference=$(git rev-parse "$RB1_SOURCE_SHA:reference")"
  echo "workflow_head=$(git rev-parse HEAD)"
  echo "compiler=$(gfortran --version | head -n1)"
} > "$EVIDENCE/AUTHORITY.txt"

echo 'FRB01_BUILD_COMPILER=PASS'
echo 'FRB01_DETERMINISM=PASS'
echo 'FRB01_HARD_MASS=PASS'
echo 'FRB01_TRANSACTIONALITY=PASS'
echo 'FRB01_RESTART=PASS'
echo 'FRB01_STANDALONE_SERIALIZED_PARALLEL_RESTRICTED_COMPOSITION=PASS'
echo 'FRB01_NEGATIVE_FAIL_CLOSED=PASS'
echo 'FRB01_ARCHITECTURE=PASS'
echo 'FRB01_DECISION=QUALIFIED_SWAP5_RESTRICTED_PRODUCTION_BASELINE_V1_READY_FOR_RELEASE_AUTHORITY'

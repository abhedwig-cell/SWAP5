#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-}"
case "$MODE" in
  lifecycle|real|vq30|disjoint|cross) ;;
  *) echo "usage: $0 {lifecycle|real|vq30|disjoint|cross}" >&2; exit 2 ;;
esac

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

SOURCE_COMMIT=a0331164a8dfc2642becdbe96cab969eabead392
POSTIMAGE=integration/f-ci/F-CI21_MATERIALIZED_SOURCE_POSTIMAGE.json
POSTIMAGE_BLOB=868cf8c52c02a6a9b40bd09ad9f51b7c0b635de4
AUTH_BRANCH=qualification/f-vq31-transaction-composed-richards-temporal-history
AUTH_REF=refs/remotes/origin/fci21-vq31-authority

fail() { echo "FCI21_VQ31_REPLAY_FAIL:$MODE:$*" >&2; exit 1; }

# F-CI21 production postimage must be the object under test. Test/evidence commits
# after SOURCE_COMMIT are allowed, production-source drift is not.
git merge-base --is-ancestor "$SOURCE_COMMIT" HEAD || fail 'materialized source commit not in history'
[[ "$(git rev-parse HEAD:$POSTIMAGE)" == "$POSTIMAGE_BLOB" ]] || fail 'materialized-source postimage manifest drift'
git diff --quiet "$SOURCE_COMMIT" HEAD -- \
  src/solver \
  src/transaction/mod_fkt_temporal_indicator_history.f90 \
  src/runtime/mod_fmr_runtime_core.f90 \
  src/runtime/mod_fmr_serialized_reference_backend.f90 \
  src/runtime/mod_canonical_contracts.f90 \
  src/runtime/mod_canonical_interval_runtime.f90 \
  src/runtime/mod_fmr_checkpoint_orchestrator.f90 \
  src/legacy/b1_10_port/headcalc.f90 \
  src/adapter/mod_reference_richards_legacy_binding.f90 \
  src/adapter/mod_b110_serialized_context_binding.f90 \
  src/kernel/mod_kernel_transactions.f90 || fail 'materialized temporal production source drift'
echo "FCI21_VQ31_POSTIMAGE_LOCK=PASS:MODE=$MODE"

# Freeze the independent VQ31 qualification authority by blob, then overlay only
# its qualification artifacts into this CI checkout. No authority production source
# is copied. The local overlay commit exists only so the original source-locked
# VQ31 runners can use HEAD:path blob checks unchanged.
git fetch --quiet --no-tags origin "$AUTH_BRANCH:$AUTH_REF"

check_auth() {
  local path="$1" blob="$2"
  [[ "$(git rev-parse "$AUTH_REF:$path")" == "$blob" ]] || fail "authority drift $path"
}

check_auth integration/f-vq/F-VQ31_QUALIFICATION_PLAN.json 6695f9be69c4485e24ebcba802927ce90af8beac
check_auth integration/f-vq/F-VQ31_INDEPENDENT_EVIDENCE.json b68ba117ae470d4a6b2ca3b55b9c1697cbcd1923
check_auth integration/f-vq/F-VQ31_CLOSEOUT.json 82064e357abe5d941850fcaa4eb8dcdf49e1b4af
check_auth integration/f-vq/F-VQ30_QUALIFICATION_PLAN.json 8bf40e19ba547ec93c4d8ce18d7ac6111707afe7
check_auth integration/f-vq/F-VQ30_HELD_OUT_EVIDENCE.json 39832173174271f4ad97278662467eb4dab13599
check_auth tests/fvq/run_fvq31_disjoint_transaction_composition.sh a62c67ec9a8566642f5516ceb0d1026a2c2b8040
check_auth tests/fvq/test_fvq30_exact_linear_regression.py 18efc3b8fb8d4610e9a2bd4dbb30a9edf23b3528
check_auth tests/fkt/run_fkt10_temporal_history_transaction.sh a27158e848875c16b3c6707c0b5d4cb1b29b5315
check_auth tests/fkt/run_fkt10_real_richards_binding_compile.sh 3bfb8d5c890e2a37f625d05166e91eac9e9b41a5
check_auth tests/fkt/run_fkt10_real_richards_history_binding.sh df5fee7a96b838fc99fd6ab9815ea5647d8d6083
check_auth tests/fkt/run_fkt10_transactional_fvq30_replay.sh c772e7c479a5bd70fc4701e56eade7d31d963f37
check_auth tests/fkt/run_fkt10_fmr06_snow_compat_regression.sh d49cfc56fbee83f246d4a30242d968cdfa18ca89
check_auth tests/fkt/test_fkt10_temporal_history_transaction.f90 f061280b4e4f229b0fd34dae7ac8d4519102ff17
check_auth tests/fkt/test_fkt10_real_richards_history_binding.f90 7656bcd7f129cc8d8456a9ce97685e0b168aef22
check_auth tests/fkt/test_fkt10_transactional_fvq30_replay.f90 c42765b89b5dd9140aa492ab56abbbf2077be50e
check_auth tests/fmr/test_fmr06_snow_multiswap.f90 ed4b742b76e97ff0ad27b386850c1d093e4f03d1

echo "FCI21_VQ31_AUTHORITY_BLOB_LOCK=PASS:MODE=$MODE"

python3 - < <(git show "$AUTH_REF:integration/f-vq/F-VQ31_QUALIFICATION_PLAN.json") <<'PY'
import json,sys
p=json.load(sys.stdin)
m=p['independent_disjoint_composition_matrix']
assert p['frozen_before_execution'] is True
assert m['frozen_before_execution'] is True
assert m['case_count']==12 and len(m['cases'])==12
assert m['exact_triplet_overlap_with_F_SI24_owner_matrix']==0
assert m['exact_triplet_overlap_with_F_VQ30_matrix']==0
assert m['exact_triplet_overlap_with_F_KT10_single_real_fixture']==0
assert p['mandatory_regression_matrix']['F_VQ30_frozen_cases']==16
assert p['qualified_owner_envelope_locked']['hard_mass_tolerance']==1e-12
assert p['qualified_owner_envelope_locked']['analytic_factor']==2.0
assert p['qualified_owner_envelope_locked']['empirical_factor_fitted'] is False
print('FCI21_VQ31_FROZEN_CONTRACT=PASS:DISJOINT=12:FVQ30=16:OVERLAP=0')
PY

python3 - < <(git show "$AUTH_REF:integration/f-vq/F-VQ31_CLOSEOUT.json") <<'PY'
import json,sys
c=json.load(sys.stdin)
expected='QUALIFIED_INDEPENDENT_TRANSACTION_COMPOSITION_OF_RICHARDS_TEMPORAL_INDICATOR_HISTORY_READY_FOR_SEPARATE_SCIENTIFIC_TEMPORAL_ACCEPTANCE_WORK'
assert c['decision']==expected
assert c['independently_qualified'] is True
assert c['production_source_changed'] is False
print('FCI21_VQ31_AUTHORITY_DECISION=PASS')
PY

OVERLAY=(
  integration/f-vq/F-VQ31_QUALIFICATION_PLAN.json
  integration/f-vq/F-VQ30_QUALIFICATION_PLAN.json
  integration/f-vq/F-VQ30_HELD_OUT_EVIDENCE.json
  tests/fvq/run_fvq31_disjoint_transaction_composition.sh
  tests/fvq/test_fvq30_exact_linear_regression.py
  tests/fkt/run_fkt10_temporal_history_transaction.sh
  tests/fkt/run_fkt10_real_richards_binding_compile.sh
  tests/fkt/run_fkt10_real_richards_history_binding.sh
  tests/fkt/run_fkt10_transactional_fvq30_replay.sh
  tests/fkt/run_fkt10_fmr06_snow_compat_regression.sh
  tests/fkt/test_fkt10_temporal_history_transaction.f90
  tests/fkt/test_fkt10_real_richards_history_binding.f90
  tests/fkt/test_fkt10_transactional_fvq30_replay.f90
  tests/fmr/test_fmr06_snow_multiswap.f90
)
for path in "${OVERLAY[@]}"; do
  mkdir -p "$(dirname "$path")"
  git show "$AUTH_REF:$path" > "$path"
done
chmod +x tests/fvq/run_fvq31_disjoint_transaction_composition.sh tests/fkt/run_fkt10_*.sh

git config user.name 'F-CI21 qualification overlay'
git config user.email 'f-ci21-overlay@invalid.local'
git add "${OVERLAY[@]}"
git commit --quiet --no-gpg-sign -m 'ci-only: overlay frozen VQ31 qualification authority'

# The overlay must remain test/evidence-only.
git diff --quiet "$SOURCE_COMMIT" HEAD -- src || fail 'qualification overlay changed src'
[[ "$(git rev-parse HEAD:integration/f-vq/F-VQ31_QUALIFICATION_PLAN.json)" == 6695f9be69c4485e24ebcba802927ce90af8beac ]] || fail 'overlay plan blob mismatch'
[[ "$(git rev-parse HEAD:tests/fkt/test_fkt10_transactional_fvq30_replay.f90)" == c42765b89b5dd9140aa492ab56abbbf2077be50e ]] || fail 'overlay transaction driver mismatch'
echo "FCI21_VQ31_TEST_ONLY_OVERLAY=PASS:MODE=$MODE"

case "$MODE" in
  lifecycle)
    bash tests/fkt/run_fkt10_temporal_history_transaction.sh
    ;;
  real)
    bash tests/fkt/run_fkt10_real_richards_binding_compile.sh
    bash tests/fkt/run_fkt10_real_richards_history_binding.sh
    ;;
  vq30)
    bash tests/fkt/run_fkt10_transactional_fvq30_replay.sh
    ;;
  disjoint)
    bash tests/fvq/run_fvq31_disjoint_transaction_composition.sh
    ;;
  cross)
    bash tests/fsi/run_fsi25_reference_indicator_production_seam.sh
    bash tests/fkt/run_fkt10_fmr06_snow_compat_regression.sh
    ;;
esac

echo "FCI21_VQ31_MODE=PASS:$MODE"

#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

CANONICAL="5e5e498dc56d1df1dd7ebebbf9901c946445a1ab"
OWNER="15184dd06c1d0f8accc0d306a12d25a3568f1f2e"
CANDIDATE="b2ba462cfade41eb68643db75ca28e234a123a02"
CANDIDATE_TREE="f1c590d9c75c904ecbc123077035f632dd761ad2"
BACKEND="src/runtime/mod_fmr_serialized_reference_backend.f90"
RUNTIME="src/runtime/mod_fmr_serialized_multiswap_runtime.f90"
FIXTURE="tests/eb/test_eb_i18_transaction_publication.f90"
fail() { echo "FVQ78_FAIL $*" >&2; exit 178; }

git fetch -q origin integration/f-ci-canonical
[[ "$(git rev-parse origin/integration/f-ci-canonical)" == "$CANONICAL" ]] || fail 'live canonical moved'
git merge-base --is-ancestor "$CANONICAL" "$CANDIDATE" || fail 'candidate not descended from canonical'
git merge-base --is-ancestor "$CANDIDATE" HEAD || fail 'verifier branch does not contain exact EB-I19 candidate'
[[ "$(git show -s --format=%T "$CANDIDATE")" == "$CANDIDATE_TREE" ]] || fail 'EB-I19 candidate tree drift'

changed_src="$(git diff --name-only "$OWNER" "$CANDIDATE" -- src | sort)"
expected_src=$'src/runtime/mod_fmr_serialized_multiswap_runtime.f90\nsrc/runtime/mod_fmr_serialized_reference_backend.f90'
[[ "$changed_src" == "$expected_src" ]] || { printf '%s\n' "$changed_src" >&2; fail 'unexpected production source delta'; }
git diff --quiet "$OWNER" "$CANDIDATE" -- reference || fail 'reference source changed'
git diff --quiet "$CANDIDATE" HEAD -- src reference || fail 'F-VQ78 changed production/reference source'

declare -A MATERIALIZED_BLOBS=(
  [src/runtime/mod_fmr_serialized_reference_backend.f90]=a4b4891f5e7223691264eff80cdfc6dbb3851a5a
  [src/runtime/mod_fmr_serialized_multiswap_runtime.f90]=345febcbb567084163928b81b6bc0303f31d05d9
)
for path in "${!MATERIALIZED_BLOBS[@]}"; do
  [[ "$(git rev-parse "$CANDIDATE:$path")" == "${MATERIALIZED_BLOBS[$path]}" ]] || fail "candidate blob drift: $path"
done
echo 'FVQ78_CANDIDATE_SCOPE_AND_BLOBS=PASS'

# Independently reconstruct the materialization from the frozen I18R2 owner in
# a detached clean worktree. The resulting backend, runtime and normalized EB
# fixture must be byte-identical to the production candidate. This rules out
# hidden/manual source changes during the one-shot materialization commit.
REPRO="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-fvq78-repro-${GITHUB_RUN_ID:-local}-$$"
GATE_OUT="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-fvq78-gate-${GITHUB_RUN_ID:-local}-$$.txt"
cleanup() {
  rm -f "$GATE_OUT"
  git worktree remove --force "$REPRO" >/dev/null 2>&1 || true
  rm -rf "$REPRO"
}
trap cleanup EXIT

git worktree add --detach "$REPRO" "$OWNER" >/dev/null
(
  cd "$REPRO"
  python3 tests/eb/_apply_eb_i18r_current_backend_patch.py
  python3 tests/eb/_apply_eb_i18r_runtime_patch.py
  python3 tests/eb/_normalize_eb_i18r_current_canonical_fixture.py
  python3 tests/eb/_strengthen_eb_i18r_hydrology_assertions.py

  [[ "$(git hash-object "$BACKEND")" == "$(git -C "$ROOT" rev-parse "$CANDIDATE:$BACKEND")" ]] || exit 181
  [[ "$(git hash-object "$RUNTIME")" == "$(git -C "$ROOT" rev-parse "$CANDIDATE:$RUNTIME")" ]] || exit 182
  [[ "$(git hash-object "$FIXTURE")" == "$(git -C "$ROOT" rev-parse "$CANDIDATE:$FIXTURE")" ]] || exit 183
)
echo 'FVQ78_STAGED_TO_PRODUCTION_BYTE_RECONSTRUCTION=PASS'

# Independent static ownership assertions on the production files themselves.
grep -Fq 'type, extends(transaction_attempt_context_t) :: fmr_serialized_attempt_context_t' "$BACKEND" || fail 'worker-local attempt context missing'
grep -Fq 'call self%bottom_thermal_carrier%restore_from(typed%bottom_thermal_carrier)' "$BACKEND" || fail 'attempt rollback restoration missing'
grep -Fq 'call self%model%bottom_thermal_carrier%clear()' "$BACKEND" || fail 'backend thermal scratch clear missing'
grep -Fq 'thermal_candidate = backend%bottom_thermal_snapshot()' "$RUNTIME" || fail 'candidate-bound thermal snapshot missing'
grep -Fq 'call backend%set_bottom_thermal_carrier_enabled(.false.)' "$RUNTIME" || fail 'backend scratch disable/clear seam missing'
grep -Fq 'call prepare_candidate_bound_bottom_energy' "$RUNTIME" || fail 'precommit energy preparation missing'
grep -Fq 'call finalize_bottom_energy_publication' "$RUNTIME" || fail 'accepted-only publication finalization missing'
grep -Fq "error stop 'EB-I18: local prepared energy and accepted receipt provenance mismatch'" "$RUNTIME" || fail 'receipt provenance mismatch guard missing'
echo 'FVQ78_PRODUCTION_OWNERSHIP_AND_PROVENANCE_STATIC=PASS'

# Re-run the owner production gate from a clean verifier checkout. Its output is
# then interpreted independently below; F-VQ78 does not accept marker presence
# alone as evidence of mass closure.
bash tests/eb/run_eb_i19_production_materialization_gate.sh > "$GATE_OUT" 2>&1 || {
  cat "$GATE_OUT" >&2
  fail 'EB-I19 production gate replay'
}
cat "$GATE_OUT"

python3 - "$GATE_OUT" <<'PY'
import math
import re
import sys
text = open(sys.argv[1], encoding='utf-8').read()
required = [
    'EB_I18_EXTERNAL_COMPLETE_ACCEPTED_PUBLICATION=PASS',
    'EB_I18_EXTERNAL_UNAVAILABLE_HYDROLOGY_COMMIT=PASS',
    'EB_I18_EXTERNAL_STALE_HYDROLOGY_COMMIT=PASS',
    'EB_I18_EXTERNAL_IDENTITY_MISMATCH_FAIL_CLOSED=PASS',
    'EB_I18_EXTERNAL_INVALID_RESPONSE_FAIL_CLOSED=PASS',
    'EB_I18_REJECTED_TRIAL_NO_PUBLICATION=PASS',
    'EB_I18_BACKEND_REUSE_NO_STALE_PUBLICATION=PASS',
    'EB_I19_O0_O2_SEMANTIC_IDENTITY=PASS',
    'EB_I19_PRODUCTION_MATERIALIZATION_QUALIFICATION=PASS',
]
missing = [m for m in required if m not in text]
if missing:
    raise SystemExit('FVQ78_MARKER_FAIL ' + ','.join(missing))
rows = re.findall(r'FMR44R_POSITIVE_QBOT_MASS residual=\s*([+\-0-9.Ee]+) total_in=\s*([+\-0-9.Ee]+) total_out=\s*([+\-0-9.Ee]+)', text)
if len(rows) != 2:
    raise SystemExit(f'FVQ78_MASS_ROW_COUNT_FAIL {len(rows)}')
for residual_s, total_in_s, total_out_s in rows:
    residual, total_in, total_out = map(float, (residual_s, total_in_s, total_out_s))
    if not all(math.isfinite(v) for v in (residual, total_in, total_out)):
        raise SystemExit('FVQ78_NONFINITE_MASS')
    if abs(residual) > 1.0e-12:
        raise SystemExit(f'FVQ78_MASS_RESIDUAL_FAIL {residual}')
    if total_in <= 0.0 or total_out <= 0.0 or abs(total_in-total_out) > 1.0e-12:
        raise SystemExit('FVQ78_TRANSFER_CLOSURE_FAIL')
print(f'FVQ78_INDEPENDENT_MASS_ROWS={len(rows)}')
print('FVQ78_INDEPENDENT_HARD_MASS_ORACLE=PASS')
PY

echo 'FVQ78_CLEAN_CHECKOUT_PRODUCTION_REPLAY=PASS'
echo 'FVQ78_EB_I19_INDEPENDENT_QUALIFICATION=PASS'

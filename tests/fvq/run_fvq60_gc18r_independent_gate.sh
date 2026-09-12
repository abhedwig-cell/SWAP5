#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

CANONICAL="828ba0f0ed933fb62107f849ae0bb7cc32c47c30"
DONOR="7c1c5251a2dff94291db381cf0b66631b81e9f05"
MERGE_BASE="eba90d79010b095b6556e93bd8b77a8c28d25560"
GC18="774c01d69c619f463e0d471eb797f8f0418fee07"
GC18A="ac25e009b795f231a522d2f048795ccc1d64417c"
RG01="09ef05c60c5e45af218980001c8ad8ec30da2e9e"
COUPLING_BLOB="fc598d14eabafcb025bb55621f7b00d6d1816f10"

# Fail closed if any moving authority used by this qualification moved.
git fetch --no-tags origin \
  "+refs/heads/integration/f-ci-canonical:refs/remotes/origin/integration/f-ci-canonical" \
  "+refs/heads/work/f-gc18r-two-phase-commit-readiness:refs/remotes/origin/work/f-gc18r-two-phase-commit-readiness" \
  "+refs/heads/work/f-gc18-transactional-groundwater-exchange-service-abstraction:refs/remotes/origin/work/f-gc18-transactional-groundwater-exchange-service-abstraction" \
  "+refs/heads/work/f-gc18a-groundwater-owner-evidence-canonicalization-audit:refs/remotes/origin/work/f-gc18a-groundwater-owner-evidence-canonicalization-audit" \
  "+refs/heads/regie/f-rg01-post-rb1-program-rebaseline:refs/remotes/origin/regie/f-rg01-post-rb1-program-rebaseline"

test "$(git rev-parse refs/remotes/origin/integration/f-ci-canonical)" = "$CANONICAL"
test "$(git rev-parse refs/remotes/origin/work/f-gc18r-two-phase-commit-readiness)" = "$DONOR"
test "$(git rev-parse refs/remotes/origin/work/f-gc18-transactional-groundwater-exchange-service-abstraction)" = "$GC18"
test "$(git rev-parse refs/remotes/origin/work/f-gc18a-groundwater-owner-evidence-canonicalization-audit)" = "$GC18A"
test "$(git rev-parse refs/remotes/origin/regie/f-rg01-post-rb1-program-rebaseline)" = "$RG01"

test "$(git merge-base "$CANONICAL" "$DONOR")" = "$MERGE_BASE"
test "$(git merge-base "$GC18" "$DONOR")" = "$GC18"
test "$(git rev-parse "$DONOR:src/runtime/mod_groundwater_coupling_contract.f90")" = "$COUPLING_BLOB"
test "$(git rev-parse "$CANONICAL:src/runtime/mod_groundwater_coupling_contract.f90")" = "$COUPLING_BLOB"

# Verifier branch may contain only verifier-owned evidence, tests and workflow.
while IFS= read -r path; do
  case "$path" in
    .github/workflows/fvq60-gc18r-independent-qualification.yml|integration/f-vq/F-VQ60_*|tests/fvq/run_fvq60_gc18r_independent_gate.sh|tests/fvq/test_fvq60_gc18r_independent.f90) ;;
    *) echo "FVQ60_VERIFIER_SCOPE_FAIL unexpected path: $path" >&2; exit 20 ;;
  esac
done < <(git diff --name-only "$CANONICAL..HEAD")

# Recompute the owner production delta against the exact common base.
mapfile -t donor_src < <(git diff --name-only "$MERGE_BASE..$DONOR" -- 'src/**')
test "${#donor_src[@]}" -eq 1
test "${donor_src[0]}" = "src/runtime/mod_groundwater_exchange_service_contract.f90"

# F-CI51 and F-CI52 are canonical-only production changes and must remain
# disjoint from the GC18R donor production source.
mapfile -t canonical_src < <(git diff --name-only "$MERGE_BASE..$CANONICAL" -- 'src/**')
expected_canonical_src=(
  "src/crop/mod_crop_et_canopy_view_provider.f90"
  "src/process/mod_restricted_fixed_weir_surface_water.f90"
  "src/runtime/mod_fmr_fixed_weir_serialized_runtime.f90"
  "src/runtime/mod_fmr_restart_state_contract.f90"
  "src/runtime/mod_fmr_runtime_core.f90"
  "src/runtime/mod_fmr_serialized_reference_backend.f90"
)
test "${#canonical_src[@]}" -eq "${#expected_canonical_src[@]}"
for i in "${!expected_canonical_src[@]}"; do
  test "${canonical_src[$i]}" = "${expected_canonical_src[$i]}"
done
for path in "${canonical_src[@]}"; do
  test "$path" != "src/runtime/mod_groundwater_exchange_service_contract.f90"
done

python3 - <<'PY'
import subprocess
CANONICAL='828ba0f0ed933fb62107f849ae0bb7cc32c47c30'
DONOR='7c1c5251a2dff94291db381cf0b66631b81e9f05'
source=subprocess.check_output(['git','show',f'{DONOR}:src/runtime/mod_groundwater_exchange_service_contract.f90'], text=True)
low=source.lower()
for forbidden in ['modflow', '.swp', 'midnight', '86400']:
    assert forbidden not in low, forbidden
assert 'groundwater_coupling_window_t' in source
assert 'commit_prepared_backend' in source
assert 'abort_prepared_backend' in source
assert 'candidate_revision_value = checkpoint%origin_revision_value + 1_int64' in source
contract=subprocess.check_output(['git','show',f'{CANONICAL}:src/runtime/mod_groundwater_coupling_contract.f90'], text=True)
assert 'self%t1 <= self%t0' in contract
assert 'q_groundwater_m_per_s = -q_swap_m_per_s' in contract
assert 'flux_residual_m_per_s = state%q_swap_m_per_s + state%q_groundwater_m_per_s' in contract
print('FVQ60_TYPED_GROUNDWATER_CONTRACT_COMPATIBILITY=PASS')
PY

work="$(mktemp -d)"
trap 'git worktree remove -f "$work/donor" >/dev/null 2>&1 || true; git worktree remove -f "$work/merged" >/dev/null 2>&1 || true; rm -rf "$work"' EXIT

git worktree add --detach "$work/donor" "$DONOR" >/dev/null
(
  cd "$work/donor"
  bash tests/fgc/run_fgc18r_prepared_commit.sh > "$work/owner-replay.txt"
)
grep -q '^FGC18R_O0_O2_IDENTITY=PASS$' "$work/owner-replay.txt"
grep -q '^FGC18R_PREPARE_ABORT_NO_PUBLICATION=PASS$' "$work/owner-replay.txt"
grep -q '^FGC18R_PREPARED_COMMIT_ONCE=PASS$' "$work/owner-replay.txt"
echo 'FVQ60_PINNED_OWNER_TEST_REPLAY=PASS'

# Verify a true temporary history-preserving merge with current canonical is
# conflict-free. This worktree is never committed or pushed.
git worktree add --detach "$work/merged" "$CANONICAL" >/dev/null
git -C "$work/merged" config user.name 'F-VQ60 verifier'
git -C "$work/merged" config user.email 'fvq60-verifier@invalid.local'
git -C "$work/merged" merge --no-commit --no-ff "$DONOR" >/dev/null

test -f "$work/merged/src/crop/mod_crop_et_canopy_view_provider.f90"
test -f "$work/merged/src/process/mod_restricted_fixed_weir_surface_water.f90"
test -f "$work/merged/src/runtime/mod_groundwater_exchange_service_contract.f90"
echo 'FVQ60_CURRENT_CANONICAL_TEMP_MERGE=PASS'

compile_probe() {
  local opt="$1"
  local out="$2"
  local dir="$work/probe-$opt"
  mkdir -p "$dir"
  gfortran "-$opt" -std=f2008 -Wall -Wextra -fcheck=all -ffpe-trap=invalid,zero,overflow \
    -J"$dir" -I"$dir" \
    "$work/merged/src/runtime/mod_groundwater_coupling_contract.f90" \
    "$work/merged/src/runtime/mod_groundwater_exchange_service_contract.f90" \
    "$ROOT/tests/fvq/test_fvq60_gc18r_independent.f90" \
    -o "$dir/test_fvq60"
  "$dir/test_fvq60" > "$out"
}

compile_probe O0 "$work/probe-o0.txt"
compile_probe O2 "$work/probe-o2.txt"
diff -u "$work/probe-o0.txt" "$work/probe-o2.txt"
for marker in \
  FVQ60_PREPARE_REFUSAL_PRESERVES_COMMITTED_STATE \
  FVQ60_INVALID_PARTICIPANT_REJECTED_BEFORE_PREPARE; do
  grep -q "^${marker}=PASS$" "$work/probe-o0.txt"
done
for marker in \
  FVQ60_CONTRACT_GAP_COPIED_PREPARED_REPLAY_REACHES_PUBLICATION \
  FVQ60_CONTRACT_GAP_COPIED_PREPARED_ABORT_REPLAY \
  FVQ60_BLOCKER_REVISION_OVERFLOW_ACCEPTED; do
  grep -q "^${marker}=REPRODUCED$" "$work/probe-o0.txt"
done
grep -q '^FVQ60_INDEPENDENT_NEGATIVE_PATH_AUDIT=PASS_BLOCKERS_CONFIRMED$' "$work/probe-o0.txt"
cat "$work/probe-o0.txt"
echo 'FVQ60_O0_O2_ADVERSARIAL_IDENTITY=PASS'
echo 'FVQ60_DECISION=BLOCKED_REMEDIATION_REQUIRED'

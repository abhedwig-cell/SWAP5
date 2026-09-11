#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-/tmp}/swap5-frb01-temporal-${GITHUB_RUN_ID:-local}-$$"
WT="$BUILD/fci21"
mkdir -p "$BUILD"
cleanup() {
  if git worktree list --porcelain | grep -Fq "worktree $WT"; then
    git worktree remove --force "$WT" >/dev/null 2>&1 || true
  fi
  rm -rf "$BUILD"
}
trap cleanup EXIT
fail() { echo "FRB01_TEMPORAL_GATE_FAIL $*" >&2; exit 82; }
AUTH=697755068253cfb5a2f838c63894e1609a85ff51
FCI40=d81ef430ebaa601469a165dfc5b9866b813b71aa
for sha in "$AUTH" "$FCI40"; do
  git cat-file -e "${sha}^{commit}" 2>/dev/null || git fetch --no-tags origin "$sha" >/dev/null 2>&1 || fail "cannot fetch $sha"
done

git worktree add --detach "$WT" "$AUTH" >/dev/null
(
  cd "$WT"
  bash tests/fci/run_fci21_si25_scientific_replay.sh
  bash tests/fci/run_fci21_vq30_heldout_replay.sh
  for mode in lifecycle real vq30 disjoint cross; do
    bash tests/fci/run_fci21_vq31_transaction_history_replay.sh "$mode"
  done
  for mode in semantic nonlinear; do
    bash tests/fci/run_fci21_vq32_head_budget_normalization_replay.sh "$mode"
  done
  bash tests/fci/run_fci21_vq34_remediated_certificate_replay.sh
) > "$BUILD/temporal.txt" 2>&1 || {
  cat "$BUILD/temporal.txt" >&2
  fail 'frozen temporal scientific replay failed'
}

# Current canonical preservation is a separate claim from the immutable
# historical admission. Compare only the temporal dependency surface with the
# later F-CI40 moving-current authority, not a historical one-delta source tree.
paths=(
  src/transaction/mod_transaction_reference.f90
  src/transaction/mod_fkt_temporal_indicator_history.f90
  src/runtime/mod_fmr_runtime_core.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
  src/solver/mod_reference_richards_temporal_indicator.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/kernel/mod_kernel_transactions.f90
)
for path in "${paths[@]}"; do
  [[ "$(git rev-parse HEAD:$path)" == "$(git rev-parse "$FCI40:$path")" ]] || fail "current temporal dependency drift: $path"
done

grep -Fq 'FCI21_VQ34' "$BUILD/temporal.txt" || fail 'VQ34 replay markers missing'
grep -Fq 'FCI21_VQ32' "$BUILD/temporal.txt" || fail 'VQ32 replay markers missing'
grep -Fq 'FCI21_VQ31' "$BUILD/temporal.txt" || fail 'VQ31 replay markers missing'
echo 'FRB01_FROZEN_TEMPORAL_SCIENTIFIC_AUTHORITY=PASS'
echo 'FRB01_CURRENT_TEMPORAL_DEPENDENCY_PRESERVATION=PASS'
echo 'FRB01_TEMPORAL_AUTHORITY_AND_CURRENT_PRESERVATION=PASS'

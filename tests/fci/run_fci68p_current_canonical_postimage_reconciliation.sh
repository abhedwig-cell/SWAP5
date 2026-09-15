#!/usr/bin/env bash
set -euo pipefail

CANON=b4e637885eafa6c193257cd11fa5b6fb45c18fa3
PARENT1=67b702e983f5104c80c8c16fb5e2570d969cce9e
PARENT2=26081057b9d8ba5efd3b437c3ece72dc2ad1a57b
OLD_AUTH=87893112dd9bfb9e37f48a2f851b85e6f23b9951
NEW_AUTH="$CANON"
WORKFLOW=.github/workflows/fci-canonical.yml

LIVE="$(git ls-remote origin refs/heads/integration/f-ci-canonical | awk '{print $1}')"
test "$LIVE" = "$CANON" || { echo "FCI68P_LIVE_CANONICAL_DRIFT $LIVE" >&2; exit 68; }
git merge-base --is-ancestor "$CANON" HEAD

test "$(git show -s --format=%P "$CANON")" = "$PARENT1 $PARENT2" || {
  echo 'FCI68P_FCI68_PROMOTION_NOT_EXACT_TWO_PARENT_MERGE' >&2; exit 68;
}
test "$(git rev-parse "$CANON^{tree}")" = "$(git rev-parse "$PARENT2^{tree}")" || {
  echo 'FCI68P_FCI68_PROMOTION_TREE_NOT_CANDIDATE_TREE' >&2; exit 68;
}

# Admitted F-CI68 production postimage and immutable upstream authorities.
test "$(git rev-parse HEAD:src/kernel/mod_kernel_transactions.f90)" = d3a53385e3707f05e5396bbd6f218633b9803f65
test "$(git rev-parse HEAD:src/runtime/mod_fmr_checkpoint_orchestrator.f90)" = 0dceaa2d108d5c7e1263e0f424a056a8df585908
test "$(git rev-parse HEAD:src/transaction/mod_transaction_reference.f90)" = d5a71a526efaebd82054580c3186f8e3545db331
test "$(git rev-parse HEAD:src/runtime/mod_canonical_contracts.f90)" = 3cbb81b25626e6574ae83416f088dc52882f91fc
test "$(git rev-parse HEAD:src/runtime/mod_canonical_interval_runtime.f90)" = b12327aa6e77bdbf4586fe0bed82cf0e7704f237
test "$(git rev-parse HEAD:src/runtime/mod_rossfast_d3r_execution_policy.f90)" = a39a636d01f373ae6ef0dc3ac0e1e25b6522fda9

test -z "$(git diff --name-only "$CANON..HEAD" -- src reference)" || {
  echo 'FCI68P_SOURCE_OR_REFERENCE_DRIFT' >&2; exit 68;
}

# The central preservation workflow must differ from the F-CI68 admitted
# postimage by exactly the authority substitution and nothing else.
tmp_expected="$(mktemp)"
git show "$CANON:$WORKFLOW" > "$tmp_expected"
python3 - "$tmp_expected" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1])
s=p.read_text()
old='AUTH=87893112dd9bfb9e37f48a2f851b85e6f23b9951'
new='AUTH=b4e637885eafa6c193257cd11fa5b6fb45c18fa3'
assert s.count(old) == 1
assert new not in s
p.write_text(s.replace(old,new))
PY
cmp -s "$tmp_expected" "$WORKFLOW" || {
  echo 'FCI68P_CANONICAL_WORKFLOW_TRANSFORM_NOT_EXACT_AUTH_SUBSTITUTION' >&2; exit 68;
}
rm -f "$tmp_expected"
test "$(grep -c "AUTH=$NEW_AUTH" "$WORKFLOW")" -eq 1
test "$(grep -c "AUTH=$OLD_AUTH" "$WORKFLOW" || true)" -eq 0
grep -q 'src/kernel/mod_kernel_transactions.f90' "$WORKFLOW"
grep -q 'src/runtime/mod_fmr_checkpoint_orchestrator.f90' "$WORKFLOW"

# Re-run the admitted F-CI68 composition on the exact preserved source.
bash tests/fci/run_fci68_rossfast_d3r_kernel_selector_routing.sh

echo 'FCI68P_CURRENT_CANONICAL_POSTIMAGE_RECONCILIATION=PASS'

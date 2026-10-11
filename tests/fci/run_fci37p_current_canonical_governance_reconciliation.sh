#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
fail() { echo "FCI37P_GATE_FAIL $*" >&2; exit 137; }
BASE=f4074feea33cc8eac370dc5272f8e9d763530c53
FCI36=8fa79a70a9faccaf8b63826df607a685eb75b046
SRC_TREE=6aa66da28255fc31c2891ee89716c62569a8c068
REF_TREE=9d08625217d7c0a7385df9da6a04183bcd9cb9e6
ROOT_BLOB=c78c13997642617376b8d118122c86c60ca77189

# Governance-only reconciliation: science/source postimage must be bit-identical.
git merge-base --is-ancestor "$BASE" HEAD || fail 'HEAD not descended from F-CI37 promoted science head'
git diff --quiet "$BASE"..HEAD -- src || fail 'src changed in governance reconciliation'
git diff --quiet "$BASE"..HEAD -- reference || fail 'reference changed in governance reconciliation'
[[ "$(git rev-parse HEAD:src)" == "$SRC_TREE" ]] || fail 'F-CI37 src tree drift'
[[ "$(git rev-parse HEAD:reference)" == "$REF_TREE" ]] || fail 'reference tree drift'
[[ "$(git rev-parse HEAD:src/runtime/mod_fmr_parallel_root_uptake_pool.f90)" == "$ROOT_BLOB" ]] || fail 'root-uptake candidate blob drift'

# Neither historical F-CI36 nor current F-CI37 scientific runners may be relaxed.
for p in tests/fci/run_fci36_fmr36_divdra_active_runtime_canonical_admission.sh \
         tests/fci/run_fci37_fmr35_parallel_root_uptake_canonical_admission.sh; do
  [[ "$(git rev-parse HEAD:$p)" == "$(git rev-parse $BASE:$p)" ]] || fail "scientific runner changed: $p"
done

# Broad workflow must freeze F-CI36 and move only the current authority pointer to F-CI37.
WF=.github/workflows/fci-canonical.yml
grep -Fq 'frozen-fci36-divdra-active-runtime-authority:' "$WF" || fail 'missing frozen F-CI36 authority job'
grep -Fq 'ref: 8fa79a70a9faccaf8b63826df607a685eb75b046' "$WF" || fail 'frozen F-CI36 ref not exact'
grep -Fq 'Replay exact admitted F-CI36 DIVDRA active-runtime authority' "$WF" || fail 'missing frozen F-CI36 replay'
grep -Fq 'Current F-CI37 parallel root-uptake canonical source authority gate' "$WF" || fail 'current pointer not moved to F-CI37'
grep -Fq 'run: bash tests/fci/run_fci37_fmr35_parallel_root_uptake_canonical_admission.sh' "$WF" || fail 'current F-CI37 runner absent'
grep -Fq 'test "$(git rev-parse HEAD:src)" = 6aa66da28255fc31c2891ee89716c62569a8c068' "$WF" || fail 'current F-CI37 src tree not frozen'
grep -Fq 'test "$(git rev-parse HEAD:src/runtime/mod_fmr_parallel_root_uptake_pool.f90)" = c78c13997642617376b8d118122c86c60ca77189' "$WF" || fail 'current root blob not frozen'

# The historical F-CI36 exact-delta gate must no longer be used against moving HEAD.
python3 - <<'PY'
from pathlib import Path
s=Path('.github/workflows/fci-canonical.yml').read_text()
current=s.split('  current-restricted-canonical-postimage:',1)[1]
assert 'run_fci36_fmr36_divdra_active_runtime_canonical_admission.sh' not in current
assert 'run_fci37_fmr35_parallel_root_uptake_canonical_admission.sh' in current
print('FCI37P_MOVING_POINTER_STATIC_BINDING=PASS')
PY

echo 'FCI37P_ZERO_SRC_REFERENCE_DELTA=PASS'
echo 'FCI37P_FCI36_HISTORICAL_RUNNER_PRESERVED=PASS'
echo 'FCI37P_FCI37_SCIENTIFIC_RUNNER_PRESERVED=PASS'
echo 'FCI37P_FCI36_FROZEN_AUTHORITY_ADDED=PASS'
echo 'FCI37P_CURRENT_POINTER_MOVED_TO_FCI37=PASS'

# Re-run current F-CI37 science/source gate on this governance-only postimage.
bash tests/fci/run_fci37_fmr35_parallel_root_uptake_canonical_admission.sh
echo 'FCI37P_FCI37_CURRENT_POSTIMAGE_REPLAY=PASS'
echo 'FCI37P_DECISION=GOVERNANCE_RECONCILIATION_GATE_PASS'

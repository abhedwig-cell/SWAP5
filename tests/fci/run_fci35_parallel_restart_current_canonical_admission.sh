#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fci35-$$"
REPLAY="$ROOT/tests/fci/.fci35-fmq29-replay-$$.sh"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"; rm -f "$REPLAY"' EXIT
cd "$ROOT"

fail() { echo "FCI35_GATE_FAIL $*" >&2; exit 35; }
BASE=6318f04bd4d7dd8f9a587f03decaaea63d4f5f36
FMQ29=5ea88d81a63e6c706c87e99ac360f91f08711fc1
OWNER=1e27f2758d9dbed11350aec5a089662921826d21

# Current canonical admission is metadata-only.
git merge-base --is-ancestor "$BASE" HEAD || fail 'admission head not descended from exact canonical base'
git diff --quiet "$BASE"..HEAD -- src reference || {
  git diff --name-only "$BASE"..HEAD -- src reference >&2
  fail 'F-CI35 changed production/reference source'
}

check_blob() {
  local path="$1" expected="$2" actual
  actual="$(git rev-parse "HEAD:$path")"
  [[ "$actual" == "$expected" ]] || fail "blob drift $path expected=$expected actual=$actual"
}
check_blob src/runtime/mod_fmr_committed_restart.f90 19ea410e0ed48e65b5d73887a8e1dba59c7c4f37
check_blob src/runtime/mod_fmr_restart_state_contract.f90 f1359f97d02408d8b700b0c93fe961a6ba46742c
check_blob src/runtime/mod_fmr_parallel_physical_scheduler.f90 544a1ca16fdeebdfce7f89d1ddf1825fa32fa654
check_blob src/runtime/mod_fmr_parallel_worker_pool.f90 0e700797cbaed4aaab7f04db0054f72faddcfc15
check_blob src/runtime/mod_fmr_serialized_multiswap_runtime.f90 fe5a06c9af59308cdad86c5126379f413591b0cd
check_blob src/runtime/mod_fmr_serialized_reference_backend.f90 9af5a494526810324dc00706b444e448e770cba9
check_blob src/runtime/mod_fmr_runtime_core.f90 adc2b7514cc062c0cde4e71582ba8ed7776a7335
check_blob src/runtime/mod_fmr_accepted_commit_receipt.f90 6798b3296b426950bf028814585c3f5de9be950b
check_blob src/runtime/mod_canonical_contracts.f90 c06aa869a0bd479df4c7d6e1d0b4f5c07a207144
check_blob src/transaction/mod_transaction_reference.f90 2fd932b74dbd0ffc0ec089f49e632b7ac8852df4

echo 'FCI35_EXACT_CURRENT_CANONICAL_POSTIMAGE=PASS'
echo 'FCI35_METADATA_ONLY_PRODUCTION_REFERENCE_IMMUTABLE=PASS'

# Pin and independently validate the admitted qualification authority.
git merge-base --is-ancestor "$BASE" "$FMQ29" || fail 'F-MQ29 closeout not descended from canonical source authority'
git diff --quiet "$BASE".."$FMQ29" -- src reference || fail 'F-MQ29 closeout has source/reference delta'
git show "$FMQ29:integration/f-mq/F-MQ29_STATUS.json" > "$BUILD/fmq29-status.json"
git show "$FMQ29:integration/f-mq/F-MQ29_EVIDENCE.json" > "$BUILD/fmq29-evidence.json"
git show "$FMQ29:integration/f-mq/F-MQ29_CANDIDATE_LOCK.json" > "$BUILD/fmq29-lock.json"
git show "$FMQ29:integration/f-mq/F-MQ29_QUALIFICATION_MATRIX.json" > "$BUILD/fmq29-matrix.json"
python3 - "$BUILD" <<'PY'
import json,sys
from pathlib import Path
b=Path(sys.argv[1])
s=json.loads((b/'fmq29-status.json').read_text())
e=json.loads((b/'fmq29-evidence.json').read_text())
l=json.loads((b/'fmq29-lock.json').read_text())
m=json.loads((b/'fmq29-matrix.json').read_text())
assert s['decision']=='QUALIFIED_PARALLEL_COMMITTED_BOUNDARY_RESTART_COMPOSITION'
assert s['independently_qualified'] is True and s['canonical_admitted'] is False
assert s['authoritative_qualification_run']['run']==34496804763
assert e['decision']=='QUALIFIED_PARALLEL_COMMITTED_BOUNDARY_RESTART_COMPOSITION'
assert e['authoritative_run']['run']==34496804763
assert e['production_defect_observed'] is False
assert l['owner']['candidate']=='1e27f2758d9dbed11350aec5a089662921826d21'
assert [x['n'] for x in m['held_out_composition_cases']]==[3,5,9,16,23,33]
print('FCI35_EXACT_FMQ29_QUALIFICATION_AUTHORITY=PASS')
print('FCI35_FMQ29_DECISION_AND_SCOPE_LOCK=PASS')
PY

# Rehydrate the exact F-MQ29 qualification runner, but execute it against this
# F-CI35/current-canonical HEAD. Only its two local qualification metadata paths
# are rebound to immutable temp copies extracted from the exact FMQ29 closeout.
git show "$FMQ29:tests/fmq/run_fmq29_parallel_committed_restart_qualification.sh" > "$REPLAY"
python3 - "$REPLAY" "$BUILD/fmq29-lock.json" "$BUILD/fmq29-matrix.json" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text()
lock=Path(sys.argv[2]).as_posix(); matrix=Path(sys.argv[3]).as_posix()
s=s.replace("integration/f-mq/F-MQ29_CANDIDATE_LOCK.json",lock)
s=s.replace("integration/f-mq/F-MQ29_QUALIFICATION_MATRIX.json",matrix)
p.write_text(s)
PY
chmod +x "$REPLAY"

# The replay must still be source-clean on the canonical-admission head.
bash "$REPLAY" > "$BUILD/fmq29-replay.txt" 2>&1 || {
  cat "$BUILD/fmq29-replay.txt" >&2
  fail 'exact F-MQ29 replay failed on current canonical admission head'
}
for marker in \
  FMQ29_CURRENT_CANONICAL_SOURCE_LOCK=PASS \
  FMQ29_OWNER_CANDIDATE_ZERO_SOURCE_DELTA=PASS \
  FMQ29_QUALIFICATION_INDEPENDENT_BRANCH_BASE=PASS \
  FMQ29_PRODUCTION_REFERENCE_IMMUTABLE=PASS \
  FMQ29_COMMITTED_STATE_ONLY_RESTART=PASS \
  FMQ29_ATOMIC_RESTORE_BEFORE_PARALLEL_DISPATCH=PASS \
  FMQ29_WORKER_SCRATCH_REBUILT_NOT_PERSISTED=PASS \
  FMQ29_CANONICAL_PUBLICATION_STATIC=PASS \
  FMQ29_HELDOUT_FIXTURE_RECONSTRUCTED_INDEPENDENTLY=PASS \
  FMQ29_O0=PASS \
  FMQ29_O2=PASS \
  FMQ29_O0_O2_EXACT_OUTPUT_IDENTITY=PASS \
  FMQ29_HARD_MASS_CONSERVATION=PASS \
  FMQ29_PRODUCTION_CHANGE=NONE \
  FMQ29_DECISION=QUALIFIED_PARALLEL_COMMITTED_BOUNDARY_RESTART_COMPOSITION; do
  grep -Fq "$marker" "$BUILD/fmq29-replay.txt" || fail "missing replay marker $marker"
done
for n in 3 5 9 16 23 33; do
  grep -Fq "FMQ29_HELDOUT_N${n}_" "$BUILD/fmq29-replay.txt" || fail "missing heldout n=$n"
done

echo 'FCI35_EXACT_FMQ29_REPLAY_ON_CURRENT_CANONICAL=PASS'
echo 'FCI35_HELDOUT_CROSS_WORKER_RESTART_REPLAY=PASS'
echo 'FCI35_HARD_MASS_AND_CANONICAL_PUBLICATION_REPLAY=PASS'
echo 'FCI35_PRODUCTION_CHANGE=NONE'
echo 'FCI35_DECISION=READY_FOR_CANONICAL_CAPABILITY_ADMISSION'

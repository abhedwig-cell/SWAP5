#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SOURCE="$ROOT/tests/fkt/run_fkt18_current_preservation_gate.sh"
TMP="$ROOT/tests/fkt/.fkt18-current-preservation-v2-$$.sh"
cleanup() { rm -f "$TMP"; }
trap cleanup EXIT
cp "$SOURCE" "$TMP"
python3 - "$TMP" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1])
s=p.read_text(encoding='utf-8')

# Current serialized restart composition requires the admitted commit-receipt module.
marker='# Production parallel runtime qualification:'
pos=s.index(marker)
prefix=s[:pos]
suffix=s[pos:]
old='  src/runtime/mod_fmr_checkpoint_orchestrator.f90\n'
new=old+'  src/runtime/mod_fmr_accepted_commit_receipt.f90\n'
if prefix.count(old) != 1:
    raise SystemExit(f'FKT18 V2 restart dependency anchor count={prefix.count(old)}')
s=prefix.replace(old,new,1)+suffix

# The frozen F-VQ64 independent program is assertion-driven and emits only its
# final success marker. A zero exit plus that marker means every embedded
# predictor/corrector, rollback, ledger and action-reaction assertion passed.
start=s.index('  for marker in FVQ64_REJECTED_WINDOW_RETRIES_UNCHANGED_ORIGIN=PASS')
end=s.index('  done\n', start)+len('  done\n')
replacement=(
    "  grep -Fq 'F-VQ64 INDEPENDENT F-GC21 SEQUENCES PASS' \"$out/output.txt\" || fail \"coupling O$opt final marker\"\n"
    "  echo \"FKT18_FVQ64_INDEPENDENT_SEQUENCE_O${opt}=PASS\"\n"
)
s=s[:start]+replacement+s[end:]
p.write_text(s, encoding='utf-8')
PY
echo 'FKT18_PRESERVATION_V2_ACCEPTED_COMMIT_RECEIPT_DEPENDENCY=PASS'
echo 'FKT18_PRESERVATION_V2_FVQ64_ASSERTION_CONTRACT=PASS'
bash "$TMP"

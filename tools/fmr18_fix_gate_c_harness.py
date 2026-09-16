from pathlib import Path

path = Path('tests/fmr/run_fmr18_multiswap_receipt_gate.sh')
src = path.read_text(encoding='utf-8')

anchor = '''git archive "$FCI19_PRESERVATION_HEAD" tests tools integration/f-kt | tar -x -C "$ROOT"
FCI19_BASE="$ROOT/tests/fci/run_fci19_candidate_a_preservation_gate.sh"
'''
insert = '''git archive "$FCI19_PRESERVATION_HEAD" tests tools integration/f-kt | tar -x -C "$ROOT"

# F-CI19 creates a disposable F-MR15 semantic replay from the historical
# F-MR15 runner on the current working tree. Gate C adds one compile-time
# dependency to the serialized MultiSWAP runtime, so patch only that disposable
# historical runner's module list before F-CI19 derives its temporary replay.
FMR15_REPLAY_SOURCE="$ROOT/tests/fmr/run_fmr15_owner_composition_gate.sh"
python3 - "$FMR15_REPLAY_SOURCE" <<'PY_FMR15'
from pathlib import Path
import sys
p = Path(sys.argv[1])
s = p.read_text(encoding='utf-8')
needle = '  src/runtime/mod_fmr_serialized_multiswap_runtime.f90'
with_receipt = '  src/runtime/mod_fmr_accepted_commit_receipt.f90\\n' + needle
if with_receipt not in s:
    count = s.count(needle)
    if count != 1:
        raise SystemExit(f'F-MR18 Gate C nested F-MR15 module anchor count={count}')
    s = s.replace(needle, with_receipt, 1)
p.write_text(s, encoding='utf-8')
print('FMR18C_FCI19_NESTED_FMR15_RECEIPT_DEPENDENCY=PASS')
PY_FMR15

FCI19_BASE="$ROOT/tests/fci/run_fci19_candidate_a_preservation_gate.sh"
'''

if 'FMR18C_FCI19_NESTED_FMR15_RECEIPT_DEPENDENCY=PASS' in src:
    print('FMR18_GATE_C_NESTED_FMR15_DEPENDENCY_ALREADY_ALIGNED=PASS')
else:
    count = src.count(anchor)
    if count != 1:
        raise SystemExit(f'F-MR18 Gate C F-CI19 insertion anchor count={count}')
    src = src.replace(anchor, insert, 1)
    path.write_text(src, encoding='utf-8')
    print('FMR18_GATE_C_NESTED_FMR15_DEPENDENCY_ALIGNED=PASS')

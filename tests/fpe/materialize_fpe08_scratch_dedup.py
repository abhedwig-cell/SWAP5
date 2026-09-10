from pathlib import Path
import hashlib
import subprocess

A23 = Path('src/runtime/mod_a23bu_worker_execution_context.f90')
BIND = Path('src/adapter/mod_reference_richards_legacy_binding.f90')
EXPECTED = {
    A23: '2a190d206200ad201c37c9a82d3e32e651d37a37',
    BIND: '1c7be9119986eb8ad3bd3c00b0b3b3afb4ed68ff',
}


def git_blob(path: Path) -> str:
    return subprocess.check_output(['git', 'hash-object', str(path)], text=True).strip()

for path, expected in EXPECTED.items():
    actual = git_blob(path)
    if actual != expected:
        raise SystemExit(f'FPE08_FAIL preimage lock {path}: {actual} != {expected}')
print('FPE08_MAT_G01_PREIMAGE_LOCK=PASS')

text = A23.read_text()
old_sig = '  subroutine a23bu_initialize_worker(worker, active_nodes, worker_id)\n'
new_sig = '  subroutine a23bu_initialize_worker(worker, active_nodes, worker_id, allocate_headcalc_scratch)\n'
if text.count(old_sig) != 1:
    raise SystemExit('FPE08_FAIL A23 initializer signature count')
text = text.replace(old_sig, new_sig, 1)

old_decl = '''    integer, intent(in), optional :: worker_id\n\n    if (active_nodes <= 0) error stop 'A23BU worker: active_nodes must be positive'\n    call a23bu_release_worker(worker)\n'''
new_decl = '''    integer, intent(in), optional :: worker_id\n    logical, intent(in), optional :: allocate_headcalc_scratch\n    logical :: allocate_scratch\n\n    if (active_nodes <= 0) error stop 'A23BU worker: active_nodes must be positive'\n    allocate_scratch = .true.\n    if (present(allocate_headcalc_scratch)) allocate_scratch = allocate_headcalc_scratch\n    call a23bu_release_worker(worker)\n'''
if text.count(old_decl) != 1:
    raise SystemExit('FPE08_FAIL A23 declaration anchor count')
text = text.replace(old_decl, new_decl, 1)

start_marker = '    allocate(worker%headcalc%dfdhl(active_nodes), worker%headcalc%dfdhm(active_nodes), &\n'
end_marker = '    worker%headcalc%flunsatok = .false.\n'
if text.count(start_marker) != 1 or text.count(end_marker) != 1:
    raise SystemExit('FPE08_FAIL A23 scratch block anchors')
start = text.index(start_marker)
end = text.index(end_marker, start) + len(end_marker)
block = text[start:end]
wrapped = '    if (allocate_scratch) then\n' + ''.join('  ' + line for line in block.splitlines(True)) + '    end if\n'
text = text[:start] + wrapped + text[end:]
A23.write_text(text)

binding = BIND.read_text()
old_call = '          call a23bu_initialize_worker(ws%legacy_worker, n)\n'
new_call = '          call a23bu_initialize_worker(ws%legacy_worker, n, allocate_headcalc_scratch=.false.)\n'
if binding.count(old_call) != 1:
    raise SystemExit('FPE08_FAIL canonical initializer call count')
binding = binding.replace(old_call, new_call, 1)
BIND.write_text(binding)

# Fail closed on the intended semantics before allowing the commit.
a23 = A23.read_text()
bind = BIND.read_text()
assert 'logical, intent(in), optional :: allocate_headcalc_scratch' in a23
assert 'allocate_scratch = .true.' in a23
assert 'if (present(allocate_headcalc_scratch)) allocate_scratch = allocate_headcalc_scratch' in a23
assert a23.count('if (allocate_scratch) then') == 1
assert bind.count('allocate_headcalc_scratch=.false.') == 1
assert 'call a23bu_initialize_worker(ctx, numnod)' not in bind
print('FPE08_MAT_G02_OPTIONAL_DEFAULT_ON_API=PASS')
print('FPE08_MAT_G03_CANONICAL_NO_SCRATCH_BINDING=PASS')
print('FPE08_A23_POSTIMAGE=' + git_blob(A23))
print('FPE08_BINDING_POSTIMAGE=' + git_blob(BIND))

from pathlib import Path
import subprocess

BASE = '485003c1be6e55521297b7b6bdc0195a15ca0f4f'
CURRENT = {
    'src/runtime/mod_fmr_serialized_reference_backend.f90': '605593edf96a510a291695356f47390caf17d01c',
    'src/runtime/mod_fmr_serialized_multiswap_runtime.f90': 'e2993e171c9203f4c66e35cab2889130591d3b05',
    'src/runtime/mod_fmr_parallel_worker_pool.f90': 'd1881ac6dd18363c731c4f57a078433883b2bb63',
}
RESTORED = {
    'src/runtime/mod_fmr_serialized_reference_backend.f90': '64c3d9581c71fc7bf5e5f3764995d41280312a2e',
    'src/runtime/mod_fmr_serialized_multiswap_runtime.f90': 'be4005a97e35c498ffc40297409a75efe65ff5df',
    'src/runtime/mod_fmr_parallel_worker_pool.f90': '393e9bfbc4c078d259a5ec70aca78f50e54e8b35',
}


def run(*args):
    return subprocess.check_output(args, text=True)

for path, expected in CURRENT.items():
    actual = run('git', 'rev-parse', f'HEAD:{path}').strip()
    if actual != expected:
        raise SystemExit(f'FPE10_RESTORE_FAIL candidate lock {path}: {actual} != {expected}')
print('FPE10_RESTORE_G01_CANDIDATE_POSTIMAGE_LOCK=PASS')

try:
    subprocess.check_call(['git', 'cat-file', '-e', f'{BASE}^{{commit}}'])
except subprocess.CalledProcessError:
    subprocess.check_call(['git', 'fetch', '--quiet', '--no-tags', '--depth=1', 'origin', BASE])

for path, expected in RESTORED.items():
    base_blob = run('git', 'rev-parse', f'{BASE}:{path}').strip()
    if base_blob != expected:
        raise SystemExit(f'FPE10_RESTORE_FAIL PE09 authority drift {path}: {base_blob} != {expected}')
    content = subprocess.check_output(['git', 'show', f'{BASE}:{path}'])
    Path(path).write_bytes(content)
print('FPE10_RESTORE_G02_PE09_AUTHORITY_LOCK=PASS')

for path, expected in RESTORED.items():
    worktree_blob = run('git', 'hash-object', path).strip()
    if worktree_blob != expected:
        raise SystemExit(f'FPE10_RESTORE_FAIL restored worktree {path}: {worktree_blob} != {expected}')
print('FPE10_RESTORE_G03_EXACT_PE09_SOURCE_RESTORED=PASS')

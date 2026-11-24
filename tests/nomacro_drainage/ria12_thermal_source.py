"""Actual bounded RIA thermal source against admitted canonical400; no projected views."""
import hashlib
import json
from pathlib import Path
import subprocess

R = Path(__file__).resolve().parents[2]
CORE = '2c361f08f7170943d716483252512817ef35a3a1'
git = lambda *a: subprocess.check_output(['git', *a], cwd=R)
SHA = lambda b: hashlib.sha256(b).hexdigest()


def complete_inverse():
    path = 'integration/f-ci/nomacro-complete01/RIA12_THERMAL_SNOW_DOMAIN_CONTRACT_V1.json'
    raw = (R / path).read_bytes().replace(b'\r\n', b'\n')
    assert raw == git('show', 'HEAD:' + path)
    q = json.loads(raw)
    assert q['source_dependency'] == CORE and q['parent_PR'] == 1796
    assert all(q['invariants'][key] is False for key in ('physical_equations_changed', 'mass_or_convergence_limits_changed', 'epsilon_water_added', 'age_moment_disposed', 'rejected_trial_semantics_changed', 'production_authority_changed'))
    domains = ('app', 'src', 'tools', 'reference')
    assert set(git('diff', '--name-only', CORE, 'HEAD', '--', *domains).decode().splitlines()) == set(q['files']) | set(q['added_files'])
    assert not git('status', '--porcelain=v1', '--untracked-files=all', '--', *domains, 'tests', '.github')
    for path, item in q['files'].items():
        before = git('show', CORE + ':' + path)
        actual = (R / path).read_bytes().replace(b'\r\n', b'\n')
        assert SHA(before) == item['before_lf_sha256'] and SHA(actual) == item['proposed_lf_sha256'] and actual == git('show', 'HEAD:' + path)
        source = before.decode()
        parts, cursor = [], 0
        for edit in item['ordered_literal_edits']:
            low, high = edit['base_start'], edit['base_end']
            assert cursor <= low <= high <= len(source) and source[low:high] == edit['before']
            parts.extend((source[cursor:low], edit['after']))
            cursor = high
        parts.append(source[cursor:])
        assert ''.join(parts).encode() == actual
    for path, item in q['added_files'].items():
        assert not git('ls-tree', CORE, '--', path)
        actual = (R / path).read_bytes().replace(b'\r\n', b'\n')
        assert SHA(actual) == item['proposed_lf_sha256'] and actual == git('show', 'HEAD:' + path)
    for path, item in q.get('observer_execution_policy', {}).items():
        before = git('show', CORE + ':' + path)
        actual = (R / path).read_bytes().replace(b'\r\n', b'\n')
        assert SHA(before) == item['before_lf_sha256'] and SHA(actual) == item['proposed_lf_sha256']
        assert actual == git('show', 'HEAD:' + path)
        insertion = b'import sys\nsys.dont_write_bytecode = True\n'
        assert actual.count(insertion) == 1 and actual.replace(insertion, b'', 1) == before
    return dict(status='EXACT_REAL_ACTUAL_RIA_PRIMARY_PARENT_BOUNDARY_NATIVE_SOURCE_AND_ALL_OTHER_EXECUTION_DEPENDENCIES_PASS', actual_head=git('rev-parse', 'HEAD').decode().strip(), actual_parent=CORE)

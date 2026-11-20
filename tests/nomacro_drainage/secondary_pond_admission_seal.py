"""Seal actual secondary admission observations without modifying neutral proofs."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import zipfile

CANONICAL = 'd785e2c3c415122b8e391d3979f1fbceb81ce5b5'
CANDIDATE = '1075e98a6e306e49203863c96eae1cd04e4c7ad5'
BASE = '21fce9bc6275d998d3936e035c39ed4204efa70b'
TREE = '8ed0459e294e0c1eca1f437cca3731dea0d4af71'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--evidence', type=Path, required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    proof = root/'integration/f-ci/nomacro-complete01'
    def read(name):
        return json.loads((args.evidence/(name+'.json')).read_text())
    def git(*a):
        return subprocess.check_output(['git', *a], cwd=root, text=True).strip()
    assert git('show', '-s', '--format=%P', CANONICAL).split() == [BASE, CANDIDATE]
    assert git('rev-parse', CANONICAL+'^{tree}') == git('rev-parse', CANDIDATE+'^{tree}') == TREE
    labels = ['SECONDARY_CLEAN_CANDIDATE_PUBLIC_OWNER_V1',
              'SECONDARY_ACTUAL_COMMITTED_SOURCE_NEGATIVE_V1',
              'SECONDARY_ACTUAL_COMMITTED_INHERITED_RAW_NEGATIVE_V1',
              'SECONDARY_EOL_CLEAN_CANDIDATE_PUBLIC_OWNER_V1',
              'SECONDARY_EOL_ACTUAL_COMMITTED_SOURCE_NEGATIVE_V1',
              'SECONDARY_EOL_ACTUAL_COMMITTED_INHERITED_RAW_NEGATIVE_V1',
              'SECONDARY_ACTUAL_CANONICAL_PUBLIC_OWNER_V1']
    for label in labels:
        q = read(label)
        assert q['before'] == q['after'] and q['before']['status'] == ''
        assert len(q['before']['sparse']) == 22 and q['model_executions'] == 0
        assert q['command'][-1] == 'tests/hupsel51/verify_successor.py'
        if q.get('expected_error'):
            assert q['returncode'] != 0 and q['expected_error'] in (args.evidence/(label+'.stderr.txt')).read_text()
        else:
            assert q['returncode'] == 0 and q['stderr_bytes'] == 0
            result = json.loads((args.evidence/(label+'.stdout.txt')).read_text())
            assert result['status'] == 'BOUNDED_SECONDARY_EXTENDED_IMPLICIT_SOURCE_RAW_ADMISSION_PASS'
    candidate = read(labels[3])
    actual = read(labels[-1])
    assert candidate['before']['head'] == CANDIDATE and actual['before']['head'] == CANONICAL
    assert candidate['before']['tree'] == actual['before']['tree'] == TREE
    checks = read('SECONDARY_PR1767_TERMINAL_CHECKS_V1')
    assert checks['headRevision'] == CANDIDATE and not checks['hasMore'] and len(checks['checks']) == 45
    assert all(c['status'] == 'completed' and c['conclusion'] in ('success', 'skipped') for c in checks['checks'])
    files = {label+suffix: args.evidence/(label+suffix) for label in labels
             for suffix in ('.json', '.stdout.txt', '.stderr.txt')}
    for name in ['SECONDARY_PR1767_TERMINAL_CHECKS_V1.json',
                 'SECONDARY_PR1767_PREMERGE_IDENTITY_V1.json',
                 'SECONDARY_PR1767_ACTUAL_MERGE_IDENTITY_V1.json',
                 'SECONDARY_INHERITED_CHECKOUT_EOL_DIAGNOSTIC_V1.json',
                 'SECONDARY_PR1767_CHECKOUT_EOL_FAILURE_V1.log',
                 'SECONDARY_PR1767_TERMINAL_UBUNTU_JOB_V1.log']:
        files[name] = args.evidence/name
    files['run-secondary-public-owner-v1.py'] = args.evidence.parent/'run-secondary-public-owner-v1.py'
    inventory = {name: dict(bytes=path.stat().st_size, sha256=hashlib.sha256(path.read_bytes()).hexdigest())
                 for name, path in files.items()}
    archive = proof/'EXTENDED_DRAINAGE_SECONDARY_POND_ADMISSION_RAW_V1.zip'
    record = archive.with_suffix('.json')
    assert not archive.exists() and not record.exists()
    with zipfile.ZipFile(archive, 'x', compression=zipfile.ZIP_DEFLATED) as target:
        for name, path in sorted(files.items()):
            target.write(path, name)
    q = dict(status='ACTUAL_CANONICAL_SECONDARY_ADMISSION_RAW_SEALED', canonical=CANONICAL,
             candidate=CANDIDATE, full_tree=TREE, archive=archive.name,
             bytes=archive.stat().st_size, sha256=hashlib.sha256(archive.read_bytes()).hexdigest(),
             members=inventory, sealer_source=git('rev-parse', 'HEAD'), initial_failed_ci_log_truncated=True,
             actual_canonical_public_seconds=actual['elapsed_seconds'], model_executions=0,
             neutral_scientific_archives_changed=False, functional_completion='PARTIAL',
             whole_scientific_equivalence='NOT_QUALIFIED', global_counts='UNKNOWN', RC3_changed=False)
    record.write_text(json.dumps(q, indent=2)+'\n')
    print(json.dumps({k: q[k] for k in ('status', 'canonical', 'bytes', 'sha256')}))


if __name__ == '__main__':
    main()

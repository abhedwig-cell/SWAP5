"""Verify diagnostic evidence; explicitly does not authorize canonical admission."""
import csv
import hashlib
import io
import json
from pathlib import Path
import sys
import tarfile

ROOT = Path(__file__).resolve().parents[2]
STEM = ROOT / 'benchmarks/performance/PERF01_SURFACE_FOLLOWUP_20261022_EVIDENCE'
sha = lambda raw: hashlib.sha256(raw).hexdigest()


def verify(files, reader=lambda path: (ROOT / path).read_bytes()):
    manifest = json.loads(files['MANIFEST.json'])
    assert set(files) == set(manifest) | {'MANIFEST.json'}
    assert all(sha(files[path]) == expected for path, expected in manifest.items())
    result = json.loads(files['ASSESSMENT.json'])
    assert result['status'] == 'BOUNDED_OBSERVATION_AND_INCUMBENT_PRESERVATION_PASS_ADMISSION_BLOCKED'
    assert not result['canonically_admitted']
    for path, expected in result['current_inputs'].items():
        assert sha(reader(path)) == expected, path
    for path, raw in files.items():
        if path.startswith('current-source/'):
            assert reader(path.removeprefix('current-source/')) == raw, path
    for label in ['column', 'water', 'daily']:
        report = json.loads(files[label + '/result.json'])
        assert report['status'] == 'PASS' and len(report['events']) == result['controls'][label]['events']
    for label in ['1x', '4x']:
        reference = list(csv.DictReader(io.StringIO(files[f'reference-{label}/daily.csv'].decode())))
        observed = list(csv.DictReader(io.StringIO(files[f'probe-{label}/native/daily.csv'].decode())))
        def physical(rows):
            return [{k: v for k, v in row.items() if k != 'core_cpu_s'} for row in rows]
        assert len(reference) == len(observed) == 97 and physical(reference) == physical(observed)
        stream = files[f'probe-{label}/native/stdout'].splitlines(keepends=True)
        assert b''.join(row for row in stream if not row.startswith(b'SURFACE_WORK')) == files[f'reference-{label}/stdout']
        traces = [row.split()[1:] for row in stream if row.startswith(b'SURFACE_WORK')]
        offset = 7 if label == '4x' else 4
        groups = result['observations'][label]['groups']
        assert len(traces) == groups['all']['calls'] == sum(int(row['headcalc_calls']) for row in reference)
        assert sum(int(row[offset + 1]) for row in traces) == groups['all']['switches']
        assert sum(int(row[offset + 2]) for row in traces) == groups['all']['newton']
        assert sum(int(row[offset + 3]) for row in traces) == groups['all']['backtracks']
        assert sum(int(row[offset + 5]) for row in traces) == groups['failed']['calls']
        assert sum(int(row[offset + 1]) > 0 for row in traces) == groups['switching']['calls']
    assert b'foreign daily scientific delta' in files['owner-guard.log']
    return {'status': 'BOUNDED_SURFACE_OBSERVATION_VERIFIED', 'canonically_admitted': False}


index = json.loads(STEM.with_suffix('.index.json').read_text())
archive = STEM.with_suffix('.tar.xz')
assert sha(archive.read_bytes()) == index['sha256']
with tarfile.open(archive, 'r:xz') as tar:
    members = tar.getmembers()
    assert len(members) == index['members'] == len({m.name for m in members})
    assert all(m.isfile() and not Path(m.name).is_absolute() and '..' not in Path(m.name).parts for m in members)
    files = {m.name: tar.extractfile(m).read() for m in members}
result = verify(files)
if '--self-test' in sys.argv:
    controls = []
    for path in ['probe-4x/native/stdout', 'daily/result.json', 'owner-guard.log']:
        bad = dict(files)
        bad.pop(path)
        try:
            verify(bad)
        except (AssertionError, KeyError):
            controls.append('missing ' + path)
        else:
            raise AssertionError('accepted missing evidence')
    try:
        verify(files, lambda path: (ROOT / path).read_bytes() + b'!')
    except AssertionError:
        controls.append('current source drift')
    else:
        raise AssertionError('accepted foreign current source')
    result['negative_controls'] = controls
print(json.dumps(result))

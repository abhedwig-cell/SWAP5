"""Verify sealed fresh canonical diagnostics, never archived executables.

Source identities bind this diagnostic to its recorded native build. A later
production change needs its own execution evidence, not inherited PASS here.
"""
import csv
import hashlib
import io
import json
from pathlib import Path
import struct
import tarfile
import zlib

ROOT = Path(__file__).resolve().parents[2]
sha = lambda b: hashlib.sha256(b).hexdigest()


def main():
    d = json.loads((ROOT/'integration/dataqual15/CLOSURE16_CURRENT_ANDELST_RESULT.json').read_text())
    assert not d['production_changed'] and not d['full_original_complete']
    assert d['original_projects_increment'] == d['scientific_qualifications_increment'] == 0
    for p, h in d['source_sha256'].items():
        assert sha((ROOT/p).read_bytes()) == h, ('source changed', p)
    raw = (ROOT/d['archive']).read_bytes()
    assert sha(raw) == d['archive_sha256']
    with tarfile.open(fileobj=io.BytesIO(raw)) as t:
        members = t.getmembers()
        assert len({m.name for m in members}) == len(members)
        assert all(m.isfile() and not Path(m.name).is_absolute() and '..' not in Path(m.name).parts for m in members)
        files = {m.name: t.extractfile(m).read() for m in members}
    assert json.loads(files.pop('MANIFEST.json')) == {n: sha(b) for n, b in files.items()}
    get = lambda n: json.loads(files[n])
    rows = lambda n: list(csv.DictReader(io.StringIO(files[n].decode())))
    assert get('build/column/build-complete.json')['input_sha256'] == d['source_sha256']
    assert get('sharp/RESULT_NATIVE.json') == d['original_sharp']['result']
    assert get('sharp/RESULT_NATIVE.json')['censored']
    assert get('sharp/RESULT.json')['returncode'] == 1  # retained CLI grammar refusal
    sharp = rows('sharp/budget.csv')
    assert len(sharp) == d['original_sharp']['full_completed_days'] == 1
    assert abs(float(sharp[0]['water_residual_cm'])) < 1e-10
    assert float(rows('sharp/progress.csv')[-1]['t1']) == d['original_sharp']['last_completed_source_interval_day']
    for prefix in ['baseline', 'refresh-observer']:
        result = get(prefix+'/RESULT.json')
        assert result['returncode'] == 1 and not result['censored']
        assert not result['skipped_refresh_seen']
        assert b'REFRESH_WITH_SKIPPED_JACOBIAN' not in files[prefix+'/stdout']
        a, b = files[prefix+'/origin.bin'], files[prefix+'/diagnostic-rejected.bin']
        assert a == b
        assert a[:8] == b'S5WM0001'
        assert zlib.crc32(a[:-4]) == struct.unpack('=I', a[-4:])[0]
        assert struct.unpack_from('=d', a, 204)[0] == d['historical_rebound_control']['clock_day']
        assert get(prefix+'/LAUNCH.json')['command'][9] == '0.0001'
    assert rows('baseline/cost.csv') == rows('refresh-observer/cost.csv')
    assert rows('baseline/cost.csv')[0] == d['historical_rebound_control']['actual_cost']
    print('SEALED CURRENT ANDELST FAILURE AND REJECTED JACOBIAN HYPOTHESIS VERIFIED; FULL ORIGINAL OPEN')


if __name__ == '__main__':
    main()

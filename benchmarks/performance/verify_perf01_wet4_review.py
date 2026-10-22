"""Recompute the bounded wet4 successor evidence; never grants admission."""
import hashlib
import io
import json
from pathlib import Path
import runpy
import sys
import tarfile
import tempfile

ROOT = Path(__file__).resolve().parents[2]
SHA = lambda raw: hashlib.sha256(raw).hexdigest()
argv = sys.argv
sys.argv = ['assessor', '/tmp']
helper = runpy.run_path(str(ROOT / 'benchmarks/performance/assess_perf01_weather.py'))
sys.argv = argv


def verify(files, source=lambda p: (ROOT / p).read_bytes()):
    manifest = json.loads(files['MANIFEST.json'])
    assert set(files) == set(manifest) | {'MANIFEST.json'}
    for path, expected in manifest.items():
        assert SHA(files[path]) == expected, path
        if path.startswith('source/'):
            assert files[path] == source(path[7:]), path
    build = json.loads(files['build/fallback-O2/BUILD.json'])
    assert SHA(source('src/legacy/b1_10_port/headcalc.f90')) == build['headcalc_sha256']
    overrides = {'tests/fsi/fsi04_real_headcalc_stubs.f90': 'grid_stubs.f90',
                 'src/runtime/mod_fmr_serialized_multiswap_runtime.f90': 'observed_serial_runtime.f90',
                 'src/runtime/mod_fmr_production_application_bootstrap.f90': 'observed_bootstrap.f90'}
    for path, expected in build['sources'].items():
        raw = files['build/fallback-O2/' + overrides[path]] if path in overrides else source(path)
        assert SHA(raw) == expected, path
    for path, key in [('src/runtime/mod_fmr_serialized_multiswap_runtime.f90', 'observer_original_sha256'),
                      ('src/runtime/mod_fmr_production_application_bootstrap.f90', 'surface_observer_original_sha256')]:
        assert SHA(source(path)) == build[key]
    with tempfile.TemporaryDirectory() as directory:
        directory = Path(directory)
        for path, raw in files.items():
            if path.startswith('native/'):
                dest = directory / path
                dest.parent.mkdir(parents=True, exist_ok=True)
                dest.write_bytes(raw)
        for name in ['strict', '1e4', '1e3', '1e2', '1e1', '1']:
            metrics, rows = helper['read'](directory / 'native' / name)
            assert metrics['weather_sha256'] == build['weather_sha256']
            assert metrics['expected_rain_mm'] == 908
            assert metrics['totals']['rain_mm'] == 908
            assert metrics['executable_sha256'] == build['executable_sha256']
        for name in ['O0-1e3', 'restart-active']:
            helper['read'](directory / 'native' / name)
            assert files['native/' + name + '/stdout'] == files['native/1e3/stdout']
        assert json.loads(files['native/restart-active/RESULT.json'])['command'][8] == 'restart'
    for opt in ['O0', 'O2']:
        for role in ['focused', 'default']:
            result = json.loads(files[f'controls/fallback-{role}-{opt}/RESULT.json'])
            assert 'PASS' in result['status'] or 'BYTE_EXACT' in result['status']
    assert files['controls/corner-rejection/O0.stdout'] == files['controls/corner-rejection/O2.stdout']
    assert b'CORNER_REJECT_UNCHANGED_PASS' in files['controls/corner-rejection/O0.stdout']
    assert b'WEATHER_SURFACE_ROLLBACK_PASS           1' in files['native/rollback/stdout']
    return {'status': 'BOUNDED_WET4_SUCCESSOR_EVIDENCE_PASS', 'canonically_admitted': False}


archive = ROOT / 'benchmarks/performance/PERF01_WET4_REVIEW_20261022_EVIDENCE.tar.xz'
index = json.loads(archive.with_suffix('.index.json').read_text())
assert SHA(archive.read_bytes()) == index['sha256']
with tarfile.open(archive, 'r:xz') as tar:
    assert all(m.isfile() and not m.name.startswith('/') and '..' not in Path(m.name).parts
               for m in tar.getmembers())
    files = {m.name: tar.extractfile(m).read() for m in tar.getmembers()}
result = verify(files)
if '--self-test' in sys.argv:
    rejected = []
    for name, key in [('missing native', 'native/strict/stdout'),
                      ('corrupt source', 'source/src/legacy/b1_10_port/headcalc.f90'),
                      ('wrong forcing', 'native/strict/RESULT.json')]:
        altered = dict(files)
        if name == 'missing native':
            del altered[key]
        elif name == 'wrong forcing':
            record = json.loads(altered[key])
            record['expected_rain_mm'] = 227
            altered[key] = json.dumps(record).encode()
            manifest = json.loads(altered['MANIFEST.json'])
            manifest[key] = SHA(altered[key])
            altered['MANIFEST.json'] = json.dumps(manifest).encode()
        else:
            altered[key] += b'!'
        try:
            verify(altered)
        except (AssertionError, KeyError):
            rejected.append(name)
        else:
            raise AssertionError('accepted corrupt evidence: ' + name)
    try:
        verify(files, lambda p: (ROOT / p).read_bytes() + b'!')
    except AssertionError:
        rejected.append('current source drift')
    else:
        raise AssertionError('accepted changed source')
    result['negative_controls'] = rejected
print(json.dumps(result))

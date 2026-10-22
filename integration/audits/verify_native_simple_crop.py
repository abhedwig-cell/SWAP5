"""Source-bound native simple-crop preparation, with unchanged incumbent proof."""
import base64
import csv
import hashlib
import io
import json
from pathlib import Path
import runpy
import subprocess
import tarfile

ROOT = Path(__file__).resolve().parents[2]
BASE = 'f95b95d1f459f4f4688f7822d9b3c031ab028837'
STATUS = 'integration/audits/MC_SOL01_DYNAMIC_DECAY_STATUS.json'
PARENT = 'integration/audits/verify_swp_etref.py'
SELF = 'integration/audits/verify_native_simple_crop.py'
KEY = 'simple_crop_preparation_successor'
SCIENCE = ['src', 'app', 'tools', 'tests', 'examples', '.github', 'reference', 'integration/audits',
           'integration/performance', 'integration/diagnostics']


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def require(ok, message):
    if not ok:
        raise ValueError(message)


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT, text=True).strip()


def record(reader=lambda p: (ROOT / p).read_bytes()):
    return json.loads(reader(STATUS))['swp_water_successor']['daily_meteo_successor']['etref_successor'][KEY]


def parent_projection():
    text = subprocess.check_output(['git', 'show', BASE + ':' + PARENT], cwd=ROOT).decode()
    for name, arguments in [('source', 'reader,changed'), ('verify', ''), ('self_test', '')]:
        offset = text.index('\n', text.index('def ' + name + '(')) + 1
        text = text[:offset] + ("    if 'evidence' in record().get('" + KEY + "', {}):\n"
            "        return __import__('runpy').run_path(str(ROOT/'" + SELF + "'))['" + name + "'](" + arguments + ")\n") + text[offset:]
    return text.encode()


def source(reader=lambda p: (ROOT / p).read_bytes(), changed=None):
    if 'postimages' in json.loads((ROOT/'integration/mc-nut01/MC-NUT01-HIST-COMPLETE_STATUS.json').read_text())['extended_output_component_20261021'].get('thermal_output_successor_20261022',{}):
        return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_nut_thermal_output.py'))['source'](reader,changed)
    r = record(reader)
    require(r['baseline'] == BASE, 'crop baseline')
    current = json.loads(reader(STATUS))
    current['swp_water_successor']['daily_meteo_successor']['etref_successor'].pop(KEY)
    before = json.loads(subprocess.check_output(['git', 'show', BASE + ':' + STATUS], cwd=ROOT))
    require(current == before, 'unrelated recovery state changed')
    require(reader(PARENT) == parent_projection(), 'incumbent authority bodies changed')
    expected_paths = set(git('diff', '--name-only', BASE, 'HEAD').splitlines()) - {STATUS}
    require(set(r['postimages']) == expected_paths, 'crop postimage inventory')
    for path, expected in r['postimages'].items():
        require(sha(reader(path)) == expected, 'crop postimage ' + path)
    delta = {line.split('\t')[1]: line.split('\t')[0] for line in
             git('diff', '--name-status', BASE, 'HEAD', '--', *SCIENCE).splitlines()}
    require(delta == r['source_delta'], 'unregistered crop scientific delta')
    require(git('diff', '--name-only', BASE, 'HEAD', '--', 'src').splitlines() ==
            ['src/crop/mod_crop_fixed_phenology.f90'], 'incumbent production changed')
    require(not git('status', '--porcelain', '--', 'src', 'app', 'tools', 'tests'), 'dirty scientific source')
    if changed is not None:
        require(not any(path not in r['source_delta'] and path not in r['inherited_science_paths']
                        for path in changed), 'foreign caller delta')
    return json.loads(reader(STATUS))['swp_water_successor']


def capsule():
    e = record()['evidence']
    raw = base64.b64decode(b''.join((ROOT / e['path']).read_bytes().split()), validate=True)
    require(sha(raw) == e['decoded_sha256'] and len(raw) == e['decoded_bytes'], 'crop capsule bytes')
    with tarfile.open(fileobj=io.BytesIO(raw), mode='r:xz') as archive:
        members = archive.getmembers()
        require(len(members) == e['members'] and len({m.name for m in members}) == len(members), 'crop census')
        require(all(m.isfile() and not Path(m.name).is_absolute() and '..' not in Path(m.name).parts
                    for m in members), 'unsafe crop member')
        files = {m.name: archive.extractfile(m).read() for m in members}
    manifest = json.loads(files.pop('MANIFEST.json'))
    require(set(files) == set(manifest), 'crop member inventory')
    require(all(sha(files[p]) == h for p, h in manifest.items()), 'crop evidence corruption')
    return files


def validate(files, reader=lambda p: (ROOT / p).read_bytes()):
    def js(p):
        return json.loads(files[p])

    def rows(p):
        return [{k: float(v) for k, v in row.items()} for row in csv.DictReader(io.StringIO(files[p].decode()))]

    result = js('qualified/result.json')
    require(result['status'] == 'NATIVE_SIMPLE_CROP_PREPARATION_O0_O2_PASS' and
            result['invalid_cases'] == 22 and len(result['events']) == 52 and len(result['cases']) == 8,
            'incomplete native crop execution')
    require(result['original_fixed_sha256'] == '1d57e86f0bf067e8432da69f46cd19e0df6768b9c6bcf560d2221248f3b12f75',
            'original fixed source')
    for path, expected in result['inputs'].items():
        require(sha(reader(path)) == expected, 'crop executed test changed ' + path)
    for index, event in enumerate(result['events']):
        require((event['returncode'] == 0) == event['expected_success'], 'failed crop observation')
        if event['marker']:
            require(event['marker'].encode() in files[f'qualified/{index:04d}.stdout'], 'native crop marker')
    count = 0
    for opt in ['O0', 'O2']:
        build = js('final-' + opt + '/build-complete.json')
        require(build == result['builds'][opt] and build['status'] == 'BUILT', 'crop build identity')
        require('-' + opt in build['flags'] and '-fcheck=all' in build['flags'], 'unchecked crop build')
        require(build['application_providers'] == 7 and build['original_input_providers'] == 153, 'crop closure')
        require(len(build['events']) == 155 and all(e['returncode'] == 0 for e in build['events']), 'crop compile failure')
        for path, expected in build['input_sha256'].items():
            require(sha(reader(path)) == expected, 'crop provider changed ' + path)
        for path, expected in build['generated_input_sha256'].items():
            require(sha(files['final-' + opt + '/' + path]) == expected, 'original input provider')
        for name in ['fixed', 'thermal', 'maturity', 'cold']:
            prefix = 'qualified/' + opt + '/' + name + '/'
            actual, original = rows(prefix + 'crop_daily.csv'), rows(prefix + 'original.csv')
            require(len(actual) == len(original) == 8 and actual == original, 'original daily crop differs')
            require(actual == result['cases'][opt + '-' + name]['days'] and
                    sha(files[prefix + 'crop_daily.csv']) == result['cases'][opt + '-' + name]['sha256'], 'crop reported rows')
            require(files[prefix + 'crop_daily.csv'] == files[prefix + 'again/crop_daily.csv'], 'fresh preparation repeat')
            count += sum(len(row) for row in actual)
        invalid = [p for p in files if p.startswith('qualified/' + opt + '/invalid-') and p.endswith('/crop_daily.csv')]
        require(not invalid, 'invalid input emitted crop output')
    require(count == 576, 'crop oracle census')
    modular = js('modular/RESULTS.json')
    require(modular['status'] == 'PASS' and len(modular['records']) == 2 and
            {r['optimization'] for r in modular['records']} == {0, 2}, 'modular crop state proof')
    for r in modular['records']:
        require(r['case'] == 'fixed_crop' and r['compiler_requests'] == 3 and
                len(r['sources']) == 2 and '-fcheck=all' in r['flags'], 'modular crop closure')
        for path, expected in r['inputs'].items():
            require(sha(reader(path)) == expected, 'modular crop source changed')
        for path, expected in r['artifact_sha256'].items():
            require(sha(files['modular/' + path]) == expected, 'modular crop artifact changed')
    require(len(modular['events']) == 8 and all(e['returncode'] == 0 for e in modular['events']),
            'modular crop event failure')
    for index in [3, 7]:
        raw = files[f'modular/{index:05d}-science.stdout']
        require(b'FIXED_CROP_STATE_NONMUTATION_ABA_REJECTION_PASS' in raw, 'modular state marker')

    return {'qualified': True, 'status': 'NATIVE_SIMPLE_CROP_PREPARATION_O0_O2_QUALIFIED',
            'original_exact_values': count, 'native_cases': 8, 'invalid_inputs': 22,
            'coupled_actual_root_uptake': False, 'full_historical_migration': False}


def self_test():
    if 'postimages' in json.loads((ROOT/'integration/mc-nut01/MC-NUT01-HIST-COMPLETE_STATUS.json').read_text())['extended_output_component_20261021'].get('thermal_output_successor_20261022',{}):
        return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_nut_thermal_output.py'))['self_test']()
    controls = []
    for path in record()['postimages']:
        def changed(p):
            return (ROOT / p).read_bytes() + (b'corrupt' if p == path else b'')
        try:
            source(changed)
        except ValueError:
            controls.append(path)
        else:
            raise AssertionError('stale crop source accepted ' + path)
    files = capsule()
    for path in ['qualified/result.json', 'qualified/O0/fixed/crop_daily.csv',
                 'qualified/O2/thermal/original.csv', 'qualified/O2/cold/again/crop_daily.csv',
                 'final-O0/build-complete.json', 'modular/RESULTS.json']:
        altered = dict(files);altered[path] += b'corrupt'
        try:
            validate(altered)
        except (ValueError, KeyError, json.JSONDecodeError):
            controls.append(path)
        else:
            raise AssertionError('crop raw corruption accepted ' + path)
    parent = runpy.run_path(str(ROOT / PARENT))
    old_files = parent['capsule']()
    for path in ['qualified/result.json', 'qualified/O0/dry/full/restart.bin',
                 'qualified/O2/transition/full/budget.csv', 'frozen-owner.json', 'preservation.json',
                 'concurrent-project/result.json', 'concurrent-preservation.json']:
        altered = dict(old_files);altered[path] += b'corrupt'
        try:
            parent['validate'](altered)
        except (ValueError, KeyError, json.JSONDecodeError):
            controls.append('incumbent:' + path)
        else:
            raise AssertionError('incumbent raw corruption accepted ' + path)
    try:
        source(changed={'src/foreign_crop.f90': 'A'})
    except ValueError:
        controls.append('foreign scientific delta')
    else:
        raise AssertionError('foreign crop source accepted')
    return controls


def verify():
    if 'postimages' in json.loads((ROOT/'integration/mc-nut01/MC-NUT01-HIST-COMPLETE_STATUS.json').read_text())['extended_output_component_20261021'].get('thermal_output_successor_20261022',{}):
        return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_nut_thermal_output.py'))['verify']()
    source()
    result = validate(capsule())
    # The predecessor's complete raw scientific assertions are retained. Every
    # executed incumbent build/test/provider byte is checked against current
    # files. The new independent module is absent from those original closures.
    parent = runpy.run_path(str(ROOT / PARENT))
    result['incumbent'] = parent['validate'](parent['capsule']())
    result['controls'] = len(self_test())
    result['current_source_tree'] = git('rev-parse', 'HEAD:src')
    return result


if __name__ == '__main__':
    print(json.dumps(verify(), indent=2))

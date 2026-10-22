"""Current fallow ETref proof; frozen predecessors retain their own authority."""
import base64
import csv
import hashlib
import io
import json
from pathlib import Path
import subprocess
import tarfile

ROOT = Path(__file__).resolve().parents[2]
BASE = '288ba1473c478b9a2a637f0b12d624fbcc63ca4a'
CONCURRENT = '367ef349d9a32b7980ef49370961fa213c041cf9'
NUT_PARENT = 'integration/audits/verify_nut_native_output_start.py'
STATUS = 'integration/audits/MC_SOL01_DYNAMIC_DECAY_STATUS.json'
PARENT = 'integration/audits/verify_swp_daily.py'
SELF = 'integration/audits/verify_swp_etref.py'
WORKFLOW = '.github/workflows/mc-sol01-swp-reader.yml'
SCIENCE = ['src', 'app', 'tools', 'tests', 'examples', '.github', 'reference',
           'integration/audits', 'integration/performance', 'integration/diagnostics']
PRODUCTION = ['src/runtime/mod_fmr_serialized_reference_backend.f90',
              'src/process/mod_b111_persistent_pond.f90',
              'src/runtime/mod_fmr_b111_pond_solute_route.f90']


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def require(ok, why):
    if not ok:
        raise ValueError(why)


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT, text=True).strip()


def record(reader=lambda p: (ROOT / p).read_bytes()):
    return json.loads(reader(STATUS))['swp_water_successor']['daily_meteo_successor']['etref_successor']


def projection(path):
    text = subprocess.check_output(['git', 'show', (CONCURRENT if path in [PARENT,NUT_PARENT] else BASE) + ':' + path], cwd=ROOT).decode()
    if path in [PARENT,NUT_PARENT]:
        for entry, target, arguments in [('source', 'source', 'reader,changed'), ('verify', 'verify', ''),
                                          ('self_test', 'self_test', '')]:
            start = text.index('def ' + entry + '(')
            offset = text.index('\n', start) + 1
            condition = "'evidence' in json.loads((ROOT/'" + STATUS + "').read_text())['swp_water_successor']['daily_meteo_successor'].get('etref_successor', {})"
            indent = ' ' if path == NUT_PARENT else '    '
            hook = (indent + "if " + condition + ":\n"
                    + indent*2 + "return __import__('runpy').run_path(str(ROOT/'" + SELF + "'))['" + target + "'](" + arguments + ")\n")
            text = text[:offset] + hook + text[offset:]
    elif path == WORKFLOW:
        marker = '      - name: Source bound admission and negative controls\n'
        step = '''      - name: Actual fallow ETref, original demand, mass and restart
        run: |
          set -euo pipefail
          root="$RUNNER_TEMP/swp-reader"
          python -B tests/nut-sol/qualify_swp_etref.py --reader-O0 "$root/daily-O0/swap5_read_daily" --reader-O2 "$root/daily-O2/swap5_read_daily" --column-O0 "$root/O0/swap5_solute_column" --column-O2 "$root/O2/swap5_solute_column" --output "$root/etref"
'''
        require(text.count(marker) == 1, 'original workflow insertion point')
        text = text.replace(marker, step + marker, 1)
    return text.encode()


def source(reader=lambda p: (ROOT / p).read_bytes(), changed=None):
    r = record(reader)
    require(r['baseline'] == BASE, 'ETref baseline')
    before = json.loads(subprocess.check_output(['git', 'show', BASE + ':' + STATUS], cwd=ROOT))
    current = json.loads(reader(STATUS))
    current['swp_water_successor']['daily_meteo_successor'].pop('etref_successor')
    require(current == before, 'unrelated status changed')
    for p, h in r['postimages'].items():
        require(sha(reader(p)) == h, 'ETref postimage ' + p)
    for p in [PARENT, NUT_PARENT, WORKFLOW]:
        require(reader(p) == projection(p), 'original assertions changed ' + p)
    # Upstream callback deltas can refer to older baselines. Always inspect the
    # exact current baseline independently; caller-supplied drift is rejected.
    delta = {line.split('\t')[1]: line.split('\t')[0] for line in
             git('diff', '--name-status', BASE, 'HEAD', '--', *SCIENCE).splitlines()}
    require(delta == r['source_delta'], 'unregistered ETref scientific delta')
    if changed is not None:
        require(not any(p not in r['source_delta'] and p not in r['inherited_science_paths']
                        for p in changed), 'foreign caller scientific delta')
    actual = git('diff', '--name-only', BASE, 'HEAD', '--', 'src').splitlines()
    require(sorted(actual) == sorted(PRODUCTION + r['concurrent_production']), 'foreign production change')
    for path in r['concurrent_paths']:
        if path in [PARENT,NUT_PARENT]:continue
        require(reader(path) == subprocess.check_output(['git','show',CONCURRENT+':'+path],cwd=ROOT), 'concurrent admitted source drift ' + path)
    require(not git('status', '--porcelain', '--', 'src'), 'dirty production source')
    return json.loads(reader(STATUS))['swp_water_successor']


def capsule():
    combined = {}
    for e in [record()['evidence'], record()['concurrent_evidence']]:
        raw = base64.b64decode(b''.join((ROOT / e['path']).read_bytes().split()), validate=True)
        require(sha(raw) == e['decoded_sha256'], 'ETref archive identity')
        with tarfile.open(fileobj=io.BytesIO(raw), mode='r:xz') as archive:
            members = archive.getmembers()
            require(len(members) == e['members'] and len({m.name for m in members}) == len(members), 'ETref census')
            require(all(m.isfile() and not Path(m.name).is_absolute() and '..' not in Path(m.name).parts
                        for m in members), 'unsafe ETref member')
            files = {m.name: archive.extractfile(m).read() for m in members}
        manifest = json.loads(files.pop('MANIFEST.json'))
        require(set(files) == set(manifest), 'ETref member inventory')
        require(all(sha(files[p]) == h for p, h in manifest.items()), 'ETref member bytes')
        require(not set(combined).intersection(files), 'overlapping evidence members')
        combined.update(files)
    return combined


def validate(files, reader=lambda p: (ROOT / p).read_bytes()):
    def js(p):
        return json.loads(files[p])

    def rows(p):
        return [{k: float(v) for k, v in row.items()} for row in csv.DictReader(io.StringIO(files[p].decode()))]

    r = js('qualified/result.json')
    require(r['status'] == 'PASS' and len(r['cases']) == 8 and len(r['events']) == 44, 'incomplete ETref proof')
    for p, h in r['inputs'].items():
        require(sha(reader(p)) == h, 'stale executed ETref input ' + p)
    for event in r['events']:
        require((event['returncode'] == 0) == event['expected_success'], 'ETref failure counted as pass')
    for opt in ['O0', 'O2']:
        for kind, prefix in [('column', 'stable-'), ('reader', 'reader-')]:
            b = js(prefix + opt + '/build-complete.json')
            require(b == r['builds'][opt][kind] and b['status'] == 'BUILT', 'ETref build identity')
            require('-' + opt in b['flags'] and '-fcheck=all' in b['flags'], 'unchecked ETref build')
            require(all(e['returncode'] == 0 for e in b['events']), 'failed ETref build')
            for p, h in b['input_sha256'].items():
                require(sha(reader(p)) == h, 'current ETref compiled provider ' + p)
            for p, h in b['generated_input_sha256'].items():
                require(sha(files[prefix + opt + '/' + p]) == h, 'original TTUTIL source')
        for name in ['dry', 'ponded', 'transition', 'linear']:
            prefix = 'qualified/' + opt + '/' + name + '/'
            for p in ['state.csv', 'endpoint.csv', 'restart.bin']:
                require(files[prefix + 'full/' + p] == files[prefix + 'resumed/' + p], 'ETref fresh restart')
            for generation in ['full', 'split', 'resumed']:
                m = js(prefix + generation + '/manifest.json')
                require(m['status'] == 'COMPLETE' and m['executable_sha256'] == r['builds'][opt]['column']['executable_sha256'], 'ETref generation')
                for p, h in m['files'].items():
                    require(sha(files[prefix + generation + '/' + p]) == h, 'ETref generation corruption')
            budget = rows(prefix + 'full/budget.csv')
            require(budget == r['cases'][opt + '-' + name]['budget'], 'ETref raw budget')
            require(rows(prefix + 'resumed/budget.csv') == budget[1:], 'ETref continuation history')
            rainfall = [.1, 0., .05] if name == 'transition' else [0., 0., 0.]
            for i, row in enumerate(budget):
                require(abs(row['water_end_cm'] - row['water_start_cm'] - rainfall[i] + row['soil_evaporation_cm'] + row['pond_evaporation_cm'] + row['runoff_cm']) < 1e-10, 'accepted gross evaporation accounting')
                for substance, unit in [('water', 'cm'), ('solute', 'mg_cm2')]:
                    residual = row[f'{substance}_end_{unit}'] - row[f'{substance}_start_{unit}'] - row[f'{substance}_in_{unit}'] + row[f'{substance}_out_{unit}']
                    require(abs(residual) < 1e-10 and abs(row[f'{substance}_residual_{unit}']) < 1e-10, 'ETref hard balance')
            if name in ['dry', 'linear']:
                require(abs(sum(row['soil_evaporation_cm'] for row in budget) - .06) < 1e-10, 'actual bare evaporation')
                require(abs(budget[-1]['solute_end_mg_cm2'] - budget[0]['solute_start_mg_cm2']) < 1e-10, 'evaporation exported salt')
    frozen = js('frozen-owner.json')
    require(frozen['baseline'] == BASE and frozen['owner']['status'] == 'NATIVE_DAILY_MET_O0_O2_PASS'
            and len(frozen['controls']) == 39, 'original predecessor authority')
    for path, status, count in [('stable-chemistry/result.json', 'ORIGINAL_SWP_CHEMISTRY_O0_O2_MAPPING_BALANCE_RESTART_REJECTION_PASS', 172),
                                ('stable-water/result.json', 'PASS', 110), ('stable-daily/result.json', 'PASS', 72),
                                ('stable-incumbent/result.json', 'PASS', 86)]:
        result = js(path)
        require(result['status'] == status and len(result['events']) == count, 'incumbent preservation ' + path)
    annual = js('stable-annual/result.json')
    require(len(annual['runs']) == 18 and annual['status'] == 'PHYSICAL_LONG_FILE_RUNS_PASS_ACCURACY_ASSESSMENT_REQUIRED', 'thermal annual preservation')
    preservation = js('preservation.json')
    require(preservation['status'] == 'PASS' and len(preservation['files']) >= 100, 'baseline artifact census')
    for p, h in preservation['files'].items():
        require(files['baseline-incumbent/' + p] == files['stable-incumbent/' + p]
                and sha(files['stable-incumbent/' + p]) == h, 'zero-demand artifact drift')
    nut_frozen = js('concurrent-frozen-owner.json')
    require(nut_frozen['baseline'] == CONCURRENT and nut_frozen['owner']['status'] == 'NATIVE_OUTPUT_START_SOURCE_EVIDENCE_PASS'
            and nut_frozen['controls']['count'] == 20, 'concurrent original NUT owner')
    project = js('concurrent-project/result.json')
    native_input = js('concurrent-input/result.json')
    controls = js('concurrent-controls/result.json')
    require(project['status'] == 'NATIVE_TRUE_OUTPUT_PROJECT_O0_O2_FRESH_PASS'
            and project['results']['O0'] == project['results']['O2'], 'actual concurrent native NUT project')
    require(native_input['status'] == 'NATIVE_OUTPUT_INPUT_O0_O2_PASS' and native_input['new_cases'] == 26
            and native_input['incumbent_cases'] == 38, 'concurrent native input')
    require(controls['status'] == 'NATIVE_OUTPUT_THREE_COMPILED_CONTROLS_PASS' and len(controls['controls']) == 3,
            'concurrent compiled negative controls')
    require(all(v['compiled'] and v['assertions_rejected'] and v['returncode'] != 0 for v in controls['controls'].values()),
            'concurrent NUT mutant escaped')
    for result in [project, native_input, controls]:
        for p, h in result['input_sha256'].items():
            require(sha(reader(p)) == h, 'stale concurrent NUT execution ' + p)
    for kind in ['concurrent-project', 'concurrent-input']:
        require(all(e['returncode'] == 0 for e in js(kind + '/events.json')), 'failed final concurrent NUT observation')
    comparison = js('concurrent-preservation.json')
    require(comparison['status'] == 'PASS' and len(comparison['files']) >= 12, 'concurrent NUT preservation census')
    for p, h in comparison['files'].items():
        require(files['concurrent-project/' + p] == files['concurrent-baseline/' + p]
                and sha(files['concurrent-project/' + p]) == h, 'concurrent NUT endpoint drift')
    return {'qualified': True, 'status': 'FALLOW_ETREF_O0_O2_MASS_RESTART_QUALIFIED',
            'native_cases': 8, 'fresh_restarts': 8, 'original_etpot_checks': 40,
            'old_exact_artifacts': len(preservation['files']), 'concurrent_nut_exact_files': len(comparison['files']),
            'concurrent_nut_preserved': True, 'full_historical_migration': False}


def self_test():
    checks = []
    for p in record()['postimages']:
        def stale(path):
            return (ROOT / path).read_bytes() + (b'corrupt' if path == p else b'')
        try:
            source(stale)
        except ValueError:
            checks.append(p)
        else:
            raise AssertionError('stale ETref source accepted: ' + p)
    files = capsule()
    for p in ['qualified/result.json', 'qualified/O0/dry/full/restart.bin',
              'qualified/O2/transition/full/budget.csv', 'frozen-owner.json', 'preservation.json',
              'concurrent-project/result.json', 'concurrent-preservation.json']:
        bad = dict(files)
        bad[p] += b'corrupt'
        try:
            validate(bad)
        except (ValueError, KeyError, json.JSONDecodeError):
            checks.append(p)
        else:
            raise AssertionError('corrupt ETref evidence accepted: ' + p)
    try:
        source(changed={'src/foreign_etref.f90': 'A'})
    except ValueError:
        checks.append('foreign scientific delta')
    else:
        raise AssertionError('unregistered source accepted')
    return checks


def verify():
    source()
    result = validate(capsule())
    result['controls'] = len(self_test())
    result['current_source_tree'] = git('rev-parse', 'HEAD:src')
    return result


if __name__ == '__main__':
    print(json.dumps(verify(), indent=2))

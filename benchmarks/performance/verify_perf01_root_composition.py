"""Current composition evidence, deliberately separate from owner admission.

--seal collects native observations from this controlled execution. Verification
binds every current compiled provider, retained raw output and predecessor bytes.
It never substitutes an old source postimage or dispatches around an owner guard.
"""
import argparse
import csv
import hashlib
import io
import json
from pathlib import Path
import runpy
import subprocess
import tarfile

ROOT = Path(__file__).resolve().parents[2]
BASE = '80dbce8d325e9197a53b7189ad184bcdf91f6f5c'
STEM = ROOT / 'benchmarks/performance/PERF01_ROOT_COMPOSITION_20261022_EVIDENCE'
FOLDERS = ['weather-O0', 'weather-O2', 'column-O0', 'column-O2', 'crop_column-O0', 'crop_column-O2',
           'daily-O0', 'daily-O2', 'crop-O0', 'crop-O2', 'root-O0', 'root-O2', 'focused-O0', 'focused-O2',
           'original-weather-O0', 'original-weather-O2', 'default-O0', 'default-O2',
           'season-O0-4x', 'season-O2-4x', 'season-O2-1x', 'restart-build', 'restart-native',
           'rollback-build', 'rollback-native', 'incumbent-final', 'chemistry', 'water', 'daily-proof',
           'etref-final', 'crop-joint-final', 'crop-transaction', 'trace', 'root-modular-pass',
           'nut-cold', 'nut-thermal', 'nut-calendar', 'root-substep-daily', 'root-substep-transaction',
           'warm-build-O0', 'warm-build-O2', 'warm-season-O0-1x', 'warm-season-O0-4x',
           'warm-season-O2-1x', 'warm-season-O2-4x', 'warm-screen']


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def check(ok, why):
    if not ok:
        raise ValueError(why)


def verify(files, reader=lambda p: (ROOT / p).read_bytes()):
    manifest = json.loads(files['MANIFEST.json'])
    check(set(files) == set(manifest) | {'MANIFEST.json'}, 'member inventory')
    check(all(sha(files[p]) == h for p, h in manifest.items()), 'member bytes')
    report = json.loads(files['ASSESSMENT.json'])
    check(report['canonical_input'] == BASE and not report['canonically_admitted'], 'scope drift')
    for p, h in report['current_inputs'].items():
        check(sha(reader(p)) == h, 'current executed input ' + p)
    for p, h in report['archive_inputs'].items():
        check(sha(reader(p)) == h, 'predecessor archive ' + p)
    def js(p):
        return json.loads(files[p])
    def rows(p):
        return [{k: float(v) for k, v in r.items()} for r in csv.DictReader(io.StringIO(files[p].decode()))]
    controls = {}
    for label, status, count in [
        ('incumbent-final', 'PASS', 86), ('chemistry', 'ORIGINAL_SWP_CHEMISTRY_O0_O2_MAPPING_BALANCE_RESTART_REJECTION_PASS', 172),
        ('water', 'PASS', 110), ('daily-proof', 'PASS', 72), ('etref-final', 'PASS', 44),
        ('crop-joint-final', 'NATIVE_CROP_ROOT_JOINT_O0_O2_PASS', 86),
        ('crop-transaction', 'CROP_ROOT_REAL_REJECT_RETRY_O0_O2_PASS', 4),
        ('trace', 'CANONICAL_WEATHER_TRACE_AND_REJECT_RETRY_O0_O2_PASS', 4)]:
        result = js(label + ('/RESULT.json' if label == 'trace' else '/result.json'))
        check(result['status'] == status and len(result['events']) == count, 'incomplete native ' + label)
        if label != 'incumbent-final':
            check(all((e['returncode'] == 0) == e.get('expected_success', e.get('positive', True)) for e in result['events']),
                  'failed native ' + label)
        controls[label] = count
    crop = js('crop-joint-final/result.json')
    check(len(crop['cases']) == 16 and crop['fresh_restarts'] == 16 and crop['invalid_inputs'] == 34, 'crop scope')
    for label in ['etref-final', 'crop-joint-final']:
        r = js(label + '/result.json')
        for key, case in r['cases'].items():
            opt, name = key.split('-', 1)
            prefix = label + '/' + opt + '/' + name + '/'
            budget = rows(prefix + 'full/budget.csv')
            check(budget == case['budget'], 'raw budget mismatch')
            for row in budget:
                for substance, unit in [('water', 'cm'), ('solute', 'mg_cm2')]:
                    residual = row[f'{substance}_end_{unit}'] - row[f'{substance}_start_{unit}'] - row[f'{substance}_in_{unit}'] + row[f'{substance}_out_{unit}']
                    check(abs(residual) < 1e-10 and abs(row[f'{substance}_residual_{unit}']) < 1e-10, 'hard joint balance')
            for name in ['state.csv', 'endpoint.csv', 'restart.bin']:
                check(files[prefix + 'full/' + name] == files[prefix + 'resumed/' + name], 'fresh joint restart')
    for opt in ['O0', 'O2']:
        for label, status in [('focused', 'WARM_START_AND_ORIGINAL_CORNER_CONTROLS_PASS'),
                              ('original-weather', 'WEATHER_SURFACE_NATIVE_PRESERVATION_PASS'),
                              ('default', 'DEFAULT_REAL_SOLVER_BEFORE_AFTER_BYTE_EXACT')]:
            r = js(label + '-' + opt + '/RESULT.json')
            check(r['status'] == status and all(e['returncode'] == 0 for e in r['events']), label + ' failed')
        for label in ['crop-transaction', 'trace']:
            prefix = label + '/' + opt + '/'
            for a, b in [('original.bin', 'rejected.bin'), ('retry.bin', 'fresh.bin')]:
                check(files[prefix + a] == files[prefix + b], 'joint owner mutation')
        check(b'WEATHER_CANONICAL_ACCEPTED_EVAPORATION_ALIASES_PASS' in files['trace/' + opt + '/native.stdout'],
              'positive evaporation alias test missing')
    weather, closures = {}, {}
    for label in ['season-O0-4x', 'season-O2-4x', 'season-O2-1x', 'restart-native']:
        prefix = label + ('/' if label == 'restart-native' else '/native/')
        r = js(prefix + 'RESULT.json')
        check(r['status'] == 'COMPLETE_NATIVE_OBSERVATION' and r['completed_days'] == 97 and
              r['returncode'] == 0 and not r['timed_out'] and r['head_budget_cm'] == .001, 'incomplete season')
        for p, h in r['raw_sha256'].items():
            check(sha(files[prefix + p]) == h, 'season raw receipt')
        data = rows(prefix + 'daily.csv')
        check(len(data) == 97, 'season day census')
        weather[label] = files[prefix + 'stdout']
        losses = [0.] * 97
        counts = {'PERF01_BOTTOM': 0, 'PERF01_SURFACE': 0}
        for line in weather[label].decode().splitlines():
            values = line.split()
            if not values:
                continue
            if values[0] == 'PERF01_INITIAL_STORAGE_CM':
                initial = float(values[1]) * 10
            if values[0] not in counts:
                continue
            x = list(map(float, values[1:]))
            day = int(x[0])
            check(0 <= day < 97 and abs(x[1] - x[0] - 1 / 64) < 1e-12, 'weather receipt interval')
            counts[values[0]] += 1
            losses[day] += 10 * (x[2] if values[0] == 'PERF01_BOTTOM' else sum(x[2:5]))
        check(set(counts.values()) == {97 * 64}, 'weather receipt census')
        previous, residuals = initial, []
        for i, row in enumerate(data):
            residuals.append(row['storage_mm'] - previous - row['rain_mm'] + losses[i] + row['transpiration_mm'])
            previous = row['storage_mm']
        closures[label] = max(map(abs, residuals))
        check(closures[label] < 1e-8, 'independent gross daily water closure')
    check(weather['season-O0-4x'] == weather['season-O2-4x'] == weather['restart-native'], 'weather O0/O2 or reconstruction drift')
    for rain in [1, 4]:
        for opt in ['O0', 'O2']:
            result = js(f'warm-screen/{opt}-{rain}x.json')
            check(result['status'] == 'WARM_COLD_97DAY_PHYSICAL_SCREEN_PASS', 'current warm season failed')
            check(result['warm']['max_gross_daily_closure_mm'] < 1e-8, 'current warm gross closure')
        check(files[f'warm-season-O0-{rain}x/native/stdout'] == files[f'warm-season-O2-{rain}x/native/stdout'],
              'current warm O0/O2 identity')
    check(js('rollback-native/RESULT.json')['status'] == 'PASS' and
          b'WEATHER_SURFACE_ROLLBACK_PASS' in files['rollback-native/stdout'], 'weather rollback')
    for p, h in report['exact_predecessor_files'].items():
        check(sha(files[p]) == h, 'predecessor physical bytes differ ' + p)
    # Re-evaluate the complete unchanged thermal owner's physical assertions on
    # newly executed cold/thermal raw files, retaining its frozen oracle extras.
    nut = runpy.run_path(str(ROOT / 'integration/audits/verify_nut_thermal_output.py'))
    nf = {p.removeprefix('nut-owner/'): raw for p, raw in files.items() if p.startswith('nut-owner/')}
    check(nut['validate'](nf)['qualified'], 'current thermal output proof')

    # Execute every current-root assertion before its explicitly frozen legacy
    # section. The complete unmodified authority also executes at exact BASE.
    # Its literal extraction boundary is checked against that exact source.
    root_path = 'integration/audits/verify_root_substep.py'
    root_code = subprocess.check_output(['git', 'show', BASE + ':' + root_path], cwd=ROOT, text=True)
    boundary = ' # Preserve all original predecessor raw assertions against explicitly frozen inputs.'
    check(root_code.count(boundary) == 1, 'root validation extraction boundary')
    ns = {'__file__': str(ROOT / root_path), '__name__': 'current_root_receipt_assertions'}
    code = root_code.split(boundary, 1)[0] + "\n require(count==128,'daily mass census')\n return dict(qualified=True,physical_cases=16,daily_balance_observations=count,fresh_restarts=16)\n"
    exec(compile(code, root_path, 'exec'), ns)
    rf = {}
    for label, target in [('root-substep-daily/', 'daily/'), ('root-substep-transaction/', 'transaction/'),
                          ('crop_column-O0/', 'column-O0/'), ('crop_column-O2/', 'column-O2/'),
                          ('crop-O0/', 'crop-O0/'), ('crop-O2/', 'crop-O2/'),
                          ('root-O0/', 'root-O0/'), ('root-O2/', 'root-O2/')]:
        rf.update({target + p.removeprefix(label): raw for p, raw in files.items() if p.startswith(label)})
    current_roots = ns['validate'](rf)
    check(current_roots['qualified'], 'current trial-root science')
    calendar = runpy.run_path(str(ROOT / 'integration/audits/verify_nut_calendar_output.py'))
    cf = {p.removeprefix('calendar-owner/'): raw for p, raw in files.items() if p.startswith('calendar-owner/')}
    current_calendar = calendar['validate'](cf)
    check(current_calendar['qualified'], 'current calendar output science')

    check(js('frozen-canonical-owner.json')['qualified'], 'missing frozen canonical owner')
    check(b'predecessor assertion body changed integration/audits/verify_crop_root_joint.py' in
          files['current-owner-guard.stderr'], 'current owner guard not retained')
    return {'status': 'CURRENT_ROOT_CALENDAR_WEATHER_NATIVE_PASS_OWNER_ADMISSION_PENDING', 'native_processes': controls,
            'current_root_feedback': current_roots, 'current_calendar_output': current_calendar,
            'current_active_warm_97day_seasons': 4,
            'exact_predecessor_files': len(report['exact_predecessor_files']),
            'max_gross_daily_closure_mm': closures, 'canonically_admitted': False}


def seal():
    files, inputs = {}, {}
    for folder in FOLDERS:
        source = Path(('/tmp/perf01-compose-' if folder.startswith(('daily-O', 'crop-O', 'root-O')) else '/tmp/perf01-compose2-') + folder)
        check(source.is_dir(), 'missing selected folder ' + folder)
        for p in sorted(source.rglob('*')):
            if p.is_file() and p.suffix not in {'.o', '.mod', '.a', '.so'}:
                raw = p.read_bytes()
                if not raw.startswith(b'\x7fELF'):
                    files[folder + '/' + str(p.relative_to(source))] = raw
        for name in ['build-complete.json', 'BUILD.json']:
            path = source / name
            if not path.exists():
                continue
            r = json.loads(path.read_text())
            check(r['status'] == 'BUILT', 'incomplete build ' + folder)
            for p, h in r.get('input_sha256', {}).items():
                check(sha((ROOT / p).read_bytes()) == h, 'changed compiled source ' + p)
                inputs[p] = h
            if 'sources' in r:
                for p, h in r['sources'].items():
                    if p == 'tests/fsi/fsi04_real_headcalc_stubs.f90':
                        continue
                    if p.startswith('src/runtime/mod_fmr_') and p.endswith(('serialized_multiswap_runtime.f90', 'production_application_bootstrap.f90')):
                        continue
                    check(sha((ROOT / p).read_bytes()) == h, 'changed weather source ' + p)
                    inputs[p] = h
    # Bind all recorded current input maps, except the explicit before/after
    # historical comparison, whose prefix deliberately identifies the source.
    for p, raw in list(files.items()):
        if p.endswith(('/result.json', '/RESULT.json')):
            r = json.loads(raw)
            for k in ['input_sha256', 'inputs', 'cold_input_sha256']:
                mapping = r.get(k, {})
                if not isinstance(mapping, dict):
                    continue  # Some controllers record an input filename here.
                for path, h in mapping.items():
                    if ':' in path:
                        continue
                    check(sha((ROOT / path).read_bytes()) == h, 'executed input drift ' + path)
                    inputs[path] = h
    for p in subprocess.check_output(['git', 'diff', '--name-only', BASE, 'HEAD', '--', 'src'], cwd=ROOT, text=True).splitlines():
        inputs[p] = sha((ROOT / p).read_bytes())
    for p in [Path(__file__).relative_to(ROOT).as_posix(), 'tests/fmig431/qualify_weather_canonical_trace.py', 'integration/audits/verify_root_substep.py', 'integration/audits/verify_nut_calendar_output.py']:
        inputs[p] = sha((ROOT / p).read_bytes())
    for p in inputs:
        files['current-source/' + p] = (ROOT / p).read_bytes()
    prior = runpy.run_path(str(ROOT / 'integration/audits/verify_crop_root_joint.py'))
    etref = runpy.run_path(str(ROOT / 'integration/audits/verify_swp_etref.py'))
    nut = runpy.run_path(str(ROOT / 'integration/audits/verify_nut_thermal_output.py'))
    exact = {}
    for old, before, after in [(prior['capsule'](), 'qualified/', 'crop-joint-final/'),
                                (etref['capsule'](), 'qualified/', 'etref-final/')]:
        for p, raw in old.items():
            if p.startswith(before) and Path(p).name in ['state.csv', 'budget.csv', 'endpoint.csv', 'restart.bin'] and '.pending-' not in p:
                target = after + p.removeprefix(before)
                check(files[target] == raw, 'predecessor drift ' + target)
                exact[target] = sha(raw)
    warm_path = 'benchmarks/performance/PERF01_WARM_START_20261022_EVIDENCE.tar.xz'
    with tarfile.open(ROOT / warm_path) as t:
        for rain in [1, 4]:
            target = f'season-O2-{rain}x/native/stdout'
            raw = t.extractfile(f'paired/{rain}x-0-cold/native/stdout').read()
            check(files[target] == raw, 'changed original weather physics')
            exact[target] = sha(raw)
    nf = nut['capsule']()
    for label, prefix in [('nut-cold/', 'cold/'), ('nut-thermal/', 'thermal/')]:
        nf.update({prefix + p.removeprefix(label): raw for p, raw in files.items() if p.startswith(label)})
    nut['validate'](nf)
    files.update({'nut-owner/' + p: raw for p, raw in nf.items()})

    calendar = runpy.run_path(str(ROOT / 'integration/audits/verify_nut_calendar_output.py'))
    cf = calendar['capsule']()
    for label, prefix in [('nut-cold/', 'cold/'), ('nut-calendar/', 'calendar/')]:
        cf.update({prefix + p.removeprefix(label): raw for p, raw in files.items() if p.startswith(label)})
    calendar['validate'](cf)
    files.update({'calendar-owner/' + p: raw for p, raw in cf.items()})

    files['frozen-canonical-owner.json'] = Path('/tmp/perf01-canonical80-owner-result.json').read_bytes()
    guard = subprocess.run(['python', '-B', 'integration/audits/verify_root_substep.py'], cwd=ROOT, capture_output=True)
    check(guard.returncode != 0, 'unexpected owner admission')
    files['current-owner-guard.stderr'] = guard.stderr
    archive_inputs = {warm_path: sha((ROOT / warm_path).read_bytes())}
    for e in [prior['record']()['evidence'], etref['record']()['evidence']]:
        archive_inputs[e['path']] = sha((ROOT / e['path']).read_bytes())
    root_owner = runpy.run_path(str(ROOT / 'integration/audits/verify_root_substep.py'))
    root_capsule = root_owner['record']()['evidence']['path']
    archive_inputs[root_capsule] = sha((ROOT / root_capsule).read_bytes())
    calendar_index = calendar['record']()['evidence_index']
    for p in [calendar_index, str(Path(calendar_index).parent / 'evidence.tar.xz.b64')]:
        archive_inputs[p] = sha((ROOT / p).read_bytes())
    r = {'canonical_input': BASE, 'source_checkpoint': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
         'canonically_admitted': False, 'current_inputs': inputs, 'archive_inputs': archive_inputs,
         'exact_predecessor_files': exact,
         'limits': 'Full owner source-successor/FSI35 reconciliation is pending. No new performance claim or 1e-6 selection. Build receipts retain executable identities; objects and ELF executables are reproducible build products, not archived.'}
    files['ASSESSMENT.json'] = (json.dumps(r, indent=2) + '\n').encode()
    files['MANIFEST.json'] = (json.dumps({p: sha(raw) for p, raw in sorted(files.items())}, indent=2) + '\n').encode()
    result = verify(files)
    pending = STEM.with_suffix('.tar.xz.pending')
    with tarfile.open(pending, 'w:xz', preset=3) as t:
        for p, raw in sorted(files.items()):
            member = tarfile.TarInfo(p)
            member.size = len(raw)
            t.addfile(member, io.BytesIO(raw))
    pending.replace(STEM.with_suffix('.tar.xz'))
    index = {'sha256': sha(STEM.with_suffix('.tar.xz').read_bytes()), 'members': len(files),
             'bytes': STEM.with_suffix('.tar.xz').stat().st_size}
    STEM.with_suffix('.index.json').write_text(json.dumps(index, indent=2) + '\n')
    STEM.with_suffix('.json').write_text(json.dumps({**r, **result, 'evidence': index}, indent=2) + '\n')
    print(json.dumps({**result, 'evidence': index}))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--seal', action='store_true')
    parser.add_argument('--self-test', action='store_true')
    args = parser.parse_args()
    if args.seal:
        return seal()
    index = json.loads(STEM.with_suffix('.index.json').read_text())
    check(sha(STEM.with_suffix('.tar.xz').read_bytes()) == index['sha256'], 'capsule identity')
    with tarfile.open(STEM.with_suffix('.tar.xz')) as t:
        members = t.getmembers()
        check(len(members) == index['members'] == len({m.name for m in members}), 'capsule census')
        check(all(m.isfile() and not Path(m.name).is_absolute() and '..' not in Path(m.name).parts for m in members), 'unsafe capsule')
        files = {m.name: t.extractfile(m).read() for m in members}
    result = verify(files)
    if args.self_test:
        controls = []
        for p in ['season-O2-4x/native/stdout', 'trace/O0/native.stdout', 'nut-owner/thermal/O2/output.restart.environment-after']:
            bad = dict(files)
            bad.pop(p)
            try:
                verify(bad)
            except (ValueError, KeyError):
                controls.append('missing ' + p)
            else:
                raise AssertionError('accepted missing evidence')
        try:
            verify(files, lambda p: (ROOT / p).read_bytes() + b'!')
        except ValueError:
            controls.append('current source drift')
        else:
            raise AssertionError('accepted source drift')
        result['negative_controls'] = controls
    print(json.dumps(result))


if __name__ == '__main__':
    main()

"""Independently decode actual ordinary pond physical/native/output evidence.

No model imports or model executions. Earlier scientific/native readers remain
literal dependencies; producer summaries supply locations, never expected fluxes.
"""
import argparse
from datetime import date
import hashlib
import io
import json
from pathlib import Path
import re
import sys
import struct
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parents[2]/'tests/nomacro_scheduled_subsurface'))
import implicit_conductivity_forensics as prior
from age_groundwater_verify import geometry

require = prior.require


def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8'))


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def rows(directory):
    return [json.loads(line) for line in (directory/'daily.jsonl').read_text(encoding='utf-8').splitlines()]


def physical(data):
    return [{k: v for k, v in row.items() if k not in ('column', 'revision')} for row in data]


def clock_checkpoint(raw, build, row, selected):
    """Use the already qualified CDE clock owner for its unchanged S5CCH ABI."""
    from cde_clock_verify import native
    with zipfile.ZipFile(io.BytesIO(raw)) as archive:
        require(set(archive.namelist()) == {'checkpoint.json', 'result.end', 'macro.bin'}, 'Foreign CDE clock checkpoint')
        meta = json.loads(archive.read('checkpoint.json'))
        require(meta['schema'] == 'swap5-hybrid-water-checkpoint-3' and meta['binding'] == build['binding'] and
                meta['receipt'] == row and set(meta['files']) == {'result.end', 'macro.bin'}, 'CDE clock receipt/binding differs')
        for name, sha in meta['files'].items():
            require(hashlib.sha256(archive.read(name)).hexdigest() == sha, 'Actual CDE clock native bytes changed')
        wire = archive.read('macro.bin')
        n, stored, step, canopy = struct.unpack_from('<i3d', wire, 8)
        epoch = build['project']['start_date']
        clock = (date.fromisoformat(epoch)-date(1900, 1, 1)).days+1
        require(wire[:8] == b'S5CCH001' and n == build['project']['nodes'] and stored == clock+row['day'] and
                prior.finite([stored, step, canopy]) and 0 < step <= 1 and canopy >= 0,
                'Actual CDE clock prefix differs')
        prior.sequential_records(archive.read('result.end'))
        return native(wire, row, n, selected, epoch)


def clock_short(case, report, build, selected):
    """The new composition uses the existing clock codec, not the older whitelist."""
    from cde_clock_verify import ledger
    path = case/'short'
    full = path/'trajectory'
    data = rows(full)
    require(report['status'] == 'ACTUAL_ORIGINAL_IMPLICIT_CONDUCTIVITY_SHORT_PHYSICAL_COMPLETE_NATIVE_OUTPUT_PASS' and
            len(data) == report['trajectory']['days'] == 35 and data[0]['day'] == 1 and data[-1]['day'] == 35,
            'Incomplete actual composed CDE clock short period')
    require(report['numerical_policy'] == {k: v for k, v in build['identity']['implicit_conductivity'].items()
                                         if k != 'source_sha256'}, 'Actual composed numerical contract differs')
    prior.water(data)
    ledger(data, 35)
    epoch = build['project']['start_date']
    prior.original_observations((full/'original/donor.stdout').read_bytes(), data, epoch)
    def native_at(directory, actual):
        by_day = {r['day']: r for r in actual}
        found = set()
        for p in directory.glob('accepted-column-1-day-*.zip'):
            day = int(p.stem.rsplit('-', 1)[1])
            require(day in by_day, 'Native clock day outside actual period')
            clock_checkpoint(p.read_bytes(), build, by_day[day], selected)
            found.add(day)
        return found
    def outputs(directory):
        return {name: prior.output_records((directory/name).read_bytes(), name)
                for name in ('result_output.csv', 'result_output.bin') if (directory/name).is_file()}
    windows = [(2, 4), (7, 9), (30, 34)]
    require([(v['start'], v['end']) for v in report['cold']] == windows and
            native_at(full, data) == {2, 4, 7, 9, 30, 34, 35}, 'Actual CDE clock native windows differ')
    for item in report['cold']:
        start, end = item['start'], item['end']
        cold_path = path/f'own-{start}'
        cold = rows(cold_path)
        require(physical(cold) == physical(data[start:end]), 'Actual composed CDE clock cold rows differ')
        prior.water(cold)
        ledger(cold, len(cold))
        prior.original_observations((cold_path/'original/donor.stdout').read_bytes(), cold, epoch)
        require(native_at(cold_path, cold) == {end}, 'Actual composed CDE cold native missing')
        with zipfile.ZipFile(full/f'accepted-column-1-day-{end}.zip') as a, \
                zipfile.ZipFile(cold_path/f'accepted-column-1-day-{end}.zip') as b:
            require(all(a.read(n) == b.read(n) for n in ('result.end', 'macro.bin')), 'Actual complete CDE native differs')
        require(prior.output_continuation(outputs(full/'original'), outputs(cold_path/'original'),
                selected, start, end, epoch) == item['exact_original_output'], 'Actual CDE original output differs')
    return 3


def audit_short(case, build_root=None, input_root=None):
    """Reuse the literal prior 35-day physical/native/output observation body."""
    from implicit_conductivity_verify import actual_period
    case = Path(case)
    report = read(case/'short/RESULT.json')
    build_root = Path(build_root or report['build_root'])
    input_root = Path(input_root or report['input_root'])
    build = read(build_root/'BUILD.json')
    require(build['identity']['ordinary_implicit_pond_switch']['policy'] ==
            'ordinary-original-continuous-pond-exact-root-chain-rule-v2', 'Foreign current ordinary short policy')
    for name, sha in build['inputs'].items():
        require(Path(name).name == name and digest(input_root/name) == sha, 'Actual ordinary short input changed')
    for name, sha in build['identity']['donor_generated'].items():
        require(Path(name).name == name and digest(build_root/name) == sha, 'Actual ordinary short Fortran changed')
    raw = (input_root/'swap.swp').read_bytes()
    selected = dict(build['identity']['original_output'])
    for field, name in [('swdra', 'SWDRA'), ('et', 'SWCFBS'), ('swhyst', 'SWHYST')]:
        values = re.findall(rb'(?mi)^\s*'+name.encode()+rb'\s*=\s*(\d+)', raw)
        require(len(values) == 1, 'Ambiguous actual ordinary short selector')
        selected[field] = int(values[0])
    files = {'profile/'+p.relative_to(case/'short').as_posix(): p
             for p in (case/'short').rglob('*') if p.is_file()}
    files['build/BUILD.json'] = build_root/'BUILD.json'
    class ActualFiles:
        def namelist(self):
            return list(files)
        def read(self, name):
            return files[name].read_bytes()
    projected_report = dict(report, _build_prefix='build/')
    if build['identity']['original_output'].get('native_codec') == 'S5CCH001':
        count = clock_short(case, report, build, selected)
    else:
        count = actual_period(ActualFiles(), 'profile/', projected_report, build,
                              report['parameters']['optimization'], selected,
                              geometry(raw, build['project']['nodes']), 'short')
    require(count == 3, 'Actual ordinary short native denominator differs')
    return dict(status='INDEPENDENT_ORDINARY_SHORT_NATIVE_OUTPUT_PASS', actual_days=35,
                actual_cold_windows=count, parameters=report['parameters'])


def audit_root(root, build_root=None, input_root=None):
    root = Path(root)
    q = read(root/'RESULT.json')
    require(q['status'] == 'ACTUAL_ORDINARY_CONTINUOUS_POND_SOURCE_PHYSICAL_NATIVE_PASS',
            'Failed/censored ordinary period cannot qualify')
    build_root = Path(build_root or q['build_root'])
    input_root = Path(input_root or q['input_root'])
    build = read(build_root/'BUILD.json')
    policy = build['identity']['ordinary_implicit_pond_switch']
    require(policy['policy'] == 'ordinary-original-continuous-pond-exact-root-chain-rule-v2' and
            policy['root_iteration_bound'] == 128 and policy['original_pond_equation_preserved'] is True and
            policy['original_positive_head_deadband_preserved'] is False and
            policy['original_nonlinear_approximate_root_preserved'] is False and
            policy['convergence_clock_mass_rollback_limits_changed'] is False and
            policy['new_physical_state'] is False, 'Foreign ordinary numerical/reference contract')
    require(q['canonical_admission'] is False and q['functional_completion'] == 'PARTIAL' and
            q['whole_scientific_equivalence'] == 'NOT_QUALIFIED', 'Ordinary scope promoted')
    for name, sha in build['inputs'].items():
        require(Path(name).name == name and digest(input_root/name) == sha, 'Actual ordinary input changed')
    for name, sha in build['identity']['donor_generated'].items():
        require(Path(name).name == name and digest(build_root/name) == sha,
                'Actual ordinary compiled Fortran changed')
    for role, stem in [('donor', 'day_donor'), ('kernel', 'day_kernel')]:
        executable = next((build_root/(stem+suffix) for suffix in ('', '.exe')
                           if (build_root/(stem+suffix)).is_file()), None)
        require(executable is not None and digest(executable) == build['executable_sha256'][role],
                'Actual ordinary executable changed')
    opt = q['parameters']['optimization']
    for key in ('donor_flags', 'kernel_flags'):
        require({'-'+opt, '-ffp-contract=off', '-march=x86-64', '-mtune=generic'} <=
                set(build['identity'][key]), 'Actual ordinary arithmetic/optimization changed')
    raw = (input_root/'swap.swp').read_bytes()
    def scalar(key):
        values = re.findall(rb'(?mi)^\s*'+key.encode()+rb'\s*=\s*([^!\r\n]+)', raw)
        require(len(values) == 1, 'Ambiguous actual ordinary input: '+key)
        return float(values[0].strip().replace(b'd', b'e').replace(b'D', b'E'))
    for key, value in [('SWKIMPL', 1), ('SWMACRO', 0), ('MAXIT', 100), ('MAXBACKTR', 10),
                       ('NUMBIT_CRIT', 3), ('FACT_DT_INCREASE', 2), ('FACT_DT_DECREASE', .5),
                       ('FACT_DT_FLDECT', 3)]:
        require(scalar(key) == value, 'Original numerical/input control changed: '+key)
    for key, argument in [('SWKMEAN', 'kmean'), ('SWSOLU', 'solute'), ('SWHYST', 'hysteresis'), ('SWBOTB', 'bottom')]:
        require(scalar(key) == q['parameters'][argument], 'Actual ordinary selector differs')
    selected = dict(build['identity']['original_output'])
    selected.update(swdra=int(scalar('SWDRA')), et=int(scalar('SWCFBS')))
    require(selected['swhyst'] == int(scalar('SWHYST')), 'Actual ordinary history differs')
    dz = geometry(raw, build['project']['nodes'])
    full = root/'full'
    trajectory = full/'trajectory'
    data = rows(trajectory)
    require(len(data) == 1096 and data[0]['day'] == 1 and data[-1]['day'] == 1096 and
            q['full']['days'] == 1096 and q['full']['build_sha256'] == digest(build_root/'BUILD.json') and
            read(trajectory/'BUILD.json') == build, 'Incomplete or rebound actual ordinary full period')
    metrics = prior.water(data)
    epoch = build['project']['start_date']
    prior.original_observations((trajectory/'original/donor.stdout').read_bytes(), data, epoch)
    if q['parameters']['solute']:
        from cde_clock_verify import ledger
        metrics['chemical'] = ledger(data, 1096)
    windows = [(2, 4), (7, 9), (30, 34), (163, 165), (199, 201),
               (364, 367), (530, 532), (1094, 1096)]
    require([(v['start'], v['end']) for v in q['cold']] == windows, 'Actual ordinary native windows differ')
    def checkpoints(path, actual):
        observed = {v['day']: v for v in actual}
        found = []
        for checkpoint in path.glob('accepted-column-1-day-*.zip'):
            day = int(checkpoint.stem.rsplit('-', 1)[1])
            require(day in observed, 'Checkpoint outside actual accepted period')
            prior.general_checkpoint(checkpoint.read_bytes(), build, observed[day], selected, dz)
            found.append(day)
        return set(found)
    require(checkpoints(trajectory, data) == {1096, *(v for pair in windows for v in pair)},
            'Actual full native checkpoint inventory differs')
    def outputs(path):
        return {name: prior.output_records((path/name).read_bytes(), name)
                for name in ('result_output.csv', 'result_output.bin') if (path/name).is_file()}
    def inventory(path):
        return {p.name for p in path.iterdir() if p.is_file() and
                (p.suffix == '.csv' or p.name.endswith('_output.bin'))}
    warm = outputs(trajectory/'original')
    for report in q['cold']:
        start, end = report['start'], report['end']
        path = full/f'own-{start}'
        cold = rows(path)
        require(physical(cold) == physical(data[start:end]), 'Actual ordinary cold physical rows differ')
        prior.water(cold)
        prior.original_observations((path/'original/donor.stdout').read_bytes(), cold, epoch)
        require(checkpoints(path, cold) == {end}, 'Actual cold native checkpoint missing')
        with zipfile.ZipFile(trajectory/f'accepted-column-1-day-{end}.zip') as a, \
                zipfile.ZipFile(path/f'accepted-column-1-day-{end}.zip') as b:
            require(all(a.read(n) == b.read(n) for n in ('result.end', 'macro.bin')),
                    'Actual complete ordinary cold native bytes differ')
        require(inventory(trajectory/'original') == inventory(path/'original'), 'Actual cold output inventory differs')
        observed = prior.output_continuation(warm, outputs(path/'original'), selected, start, end, epoch)
        require(observed == report['exact_original_output'], 'Actual original user output continuation differs')
        require(report['exact_physical'] is report['exact_complete_native'] is report['origin_unchanged'] is True,
                'Actual ordinary producer assertion differs')
    return dict(status='INDEPENDENT_ORDINARY_FULL_SOURCE_PHYSICAL_COMPLETE_NATIVE_OUTPUT_PASS',
                actual_days=1096, actual_cold_windows=8, optimization=opt, selectors=q['parameters'],
                metrics=metrics, functional_completion='PARTIAL', whole_scientific_equivalence='NOT_QUALIFIED')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('root', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    result = audit_root(args.root)
    require(not args.output.exists(), 'Refuse overwriting actual independent ordinary observation')
    args.output.write_text(json.dumps(result, indent=2)+'\n', encoding='utf-8')
    print(result['status'])

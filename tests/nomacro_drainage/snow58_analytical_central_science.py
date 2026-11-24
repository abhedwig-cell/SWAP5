"""Read original Snow5/8 archives directly; never rebind producers or run models."""
import argparse
import io
import json
import math
import re
import struct
import subprocess
import zipfile
from contextlib import ExitStack
from decimal import Decimal, localcontext
from pathlib import Path

from analytical_hydraulic_archives import SHA
from explicit_bottom9_snow_analytical_central_science import (
    Pool, build, exact_native, pe_bytes, read, rows, sample_stock, source_files,
)
from ordinary_pond_evidence import physical
from snow58_analytical_native import native
import snow_undrained_forensics as frozen

R = Path(__file__).resolve().parents[2]
P = R / 'integration/f-ci/nomacro-complete01'


def ledger(root, data):
    water = frozen.original.water(data)
    soil = []
    for line in (root / 'original/donor.stdout').read_text().splitlines():
        if not line.startswith('HYBRID_SNOW_SOIL_RECEIPT '):
            continue
        row = list(map(float, line.split()[1:]))
        assert len(row) == 29 and all(map(math.isfinite, row))
        residual = math.fsum(row[12:19] + [-v for v in row[19:28]] + row[6:12] + [-v for v in row[:6]])
        assert abs(residual) <= 1e-10 and abs(row[-1]) <= 1e-10
        assert row[2:6] == row[8:12] == [0.] * 4
        soil.append(row)
    assert len(soil) == len(data)
    peak = Decimal(0)
    with localcontext() as context:
        context.prec = 60
        for row in data:
            d = lambda value: Decimal(str(value))
            residual = sum(map(d, row['stock_start_cm'])) + sum(map(d, row['external_flux_cm'][:7])) - sum(map(d, row['external_flux_cm'][7:])) - sum(map(d, row['stock_end_cm']))
            assert abs(residual) <= Decimal('1e-10')
            assert row['external_flux_cm'][-1] == max(row['bottom_outward_cm'], 0.)
            assert row['external_flux_cm'][6] == max(-row['bottom_outward_cm'], 0.)
            peak = max(peak, abs(residual))
    chemical = None
    if 'solute_ledger_mg_cm2' in data[0]:
        from groundwater_snow_forensics import clock
        chemical = clock.ledger(data, len(data))
        class Files:
            def read(self, name):
                return (root / name).read_bytes()
        clock.daily(Files(), '', data, len(data[0]['pressure_head_cm']))
    return dict(water=water, soil_max_cm=max(abs(row[-1]) for row in soil), solute=chemical, decimal_global_max_cm=str(peak))


def checkpoints(root, data, meta, scalars, dz):
    byday = {row['day']: row for row in data}
    seen = []
    for path in root.glob('accepted-column-1-day-*.zip'):
        day = int(path.stem.rsplit('-', 1)[1])
        with zipfile.ZipFile(io.BytesIO(path.read_bytes())) as z:
            assert set(z.namelist()) == {'checkpoint.json', 'macro.bin', 'result.end'}
            q = json.loads(z.read('checkpoint.json'))
            assert q['binding'] == meta['binding'] and q['receipt'] == byday[day]
            assert all(SHA(z.read(name)) == digest for name, digest in q['files'].items())
            native(z.read('macro.bin'), byday[day], meta, scalars, dz)
            frozen.original.sequential_records(z.read('result.end'))
        seen.append(day)
    return sorted(seen)


def compiled(left, right):
    suffixes = {'.o', '.mod', '.smod', '.exe', '.dll', '.so', '.a'}
    def files(root):
        return {p.relative_to(root).as_posix(): p for p in root.rglob('*') if p.is_file() and (p.suffix.lower() in suffixes or p.name in ('day_donor', 'day_kernel'))}
    a, b = files(left), files(right)
    assert a and a.keys() == b.keys()
    for name, path in a.items():
        before, after = path.read_bytes(), b[name].read_bytes()
        if before != after:
            assert path.suffix.lower() in ('.exe', '.dll') and before[:2] == after[:2] == b'MZ'
            pe_bytes(before, after)
    assert {'day_donor.exe', 'day_kernel.exe', 'restart_publish.dll'} <= set(a) or {'day_donor', 'day_kernel', 'restart_publish.so'} <= set(a)
    return len(a)


def startup(pool, location, profile, q, meta, scalars, dz, root_control=False):
    root = pool.resolve(location)
    record = read(root / 'RESULT.json')
    key, count = ('refusals', 25) if root_control else ('compiled_refusals', 18)
    assert record['actual_compiler_producer'] == q['source']
    assert record['actual_BUILD_sha256'] == q['actual_BUILD_sha256']
    assert record['accepted_model_days'] == record['compiler_executions'] == 0
    assert len(record[key]) == count
    row = rows(profile / 'trajectory')[3 if root_control else 1]
    seen = set()
    for item in record[key]:
        label = item['attack']
        assert label not in seen
        seen.add(label)
        prefix = root / label
        stream = prefix / 'original' if root_control else prefix
        stdout, stderr = (stream / 'donor.stdout').read_bytes(), (stream / 'donor.stderr').read_bytes()
        assert b'HYBRID_READY' not in stdout and b'HYBRID_DAY_RETURN' not in stdout and b'ERROR STOP' in stderr
        raw = (prefix / 'origin/macro.bin').read_bytes()
        if not root_control:
            assert SHA(raw) == item['actual_raw_sha256'] and item['identical_raw_typed_refusal']
        try:
            native(raw, row, meta, scalars, dz)
        except (AssertionError, ValueError, struct.error):
            pass
        else:
            raise AssertionError('Native decoder accepted actual malformed payload ' + label)
    positive = root / ('positive-startup/original' if root_control else 'genuine-own-positive')
    assert b'HYBRID_READY' in (positive / 'donor.stdout').read_bytes() and not (positive / 'donor.stderr').read_bytes()
    return count


def positive(pool, item):
    profile = pool.resolve(item['profile'])
    q = read(profile / 'RESULT.json')
    assert q['days'] == 35 and q['status'].endswith('PASS_NOT_ADMITTED')
    assert q['observer_source'] == q['actual_completion_head']
    assert q['source'] == q['build']['actual_completion_head']
    assert not subprocess.check_output(['git', 'diff', q['source'], q['observer_source'], '--', 'app', 'src', 'tools', 'reference'], cwd=R)
    bundle, meta = build(pool, q['build_root'], q['actual_BUILD_sha256'])
    inputs = pool.resolve(q['input_root'])
    assert {name: SHA((inputs / name).read_bytes()) for name, _ in q['input_inventory']} == dict(q['input_inventory']) == meta['inputs']
    text = (inputs / 'swap.swp').read_bytes().decode('cp1252')
    scalars = {key: frozen.scalar(text, key) for key in ('SWKIMPL', 'SWSNOW', 'SWSOLU', 'SWHYST', 'SWBOTB', 'SWDRA', 'SWCFBS', 'NPRINTDAY', 'SWRES')}
    assert scalars['SWBOTB'] in (5, 8) and scalars['SWBOTB'] == item['bottom']
    assert scalars['SWKIMPL'] == scalars['SWHYST'] == scalars['SWDRA'] == 0
    assert scalars['SWSNOW'] == 1 and scalars['SWSOLU'] == int(q['kind'] == 'cde')
    assert meta['identity']['original_output']['analytical_snow_models'] == q['layer_models'] == [item['model']] * 2
    dz = frozen.geometry((inputs / 'swap.swp').read_bytes(), meta['project']['nodes'])
    warm = profile / 'trajectory'
    data = rows(warm)
    assert len(data) == 35 and [row['day'] for row in data] == list(range(1, 36))
    proof = ledger(warm, data)
    assert checkpoints(warm, data, meta, scalars, dz) == [2, 4, 7, 9, 30, 34, 35]
    assert max(row['stock_end_cm'][2] for row in data) > 0
    windows = [(2, 4), (7, 9), (30, 34)]
    assert [(entry['start'], entry['end']) for entry in q['cold']] == windows
    for low, high in windows:
        root = profile / ('own-' + str(low))
        actual = rows(root)
        assert physical(actual) == physical(data[low:high])
        ledger(root, actual)
        assert checkpoints(root, actual, meta, scalars, dz) == [high]
        exact_native(root / f'accepted-column-1-day-{high}.zip', warm / f'accepted-column-1-day-{high}.zip')
    if q['kind'] == 'cde':
        assert any(row['solute_ledger_mg_cm2'][3] > 0 for row in data)
    if item['bottom'] == 8:
        assert any(row['bottom_outward_cm'] > 0 for row in data)
    post = pool.resolve(item['current_opposite_initialization_postimage'])
    counter = read(post / 'RESULT.json')
    assert counter['source'] == counter['actual_compiler_start_HEAD'] == counter['actual_compiler_end_HEAD']
    assert counter['original_producer'] == q['source'] and counter['profile_RESULT_sha256'] == SHA((profile / 'RESULT.json').read_bytes())
    assert counter['original_initialization'] + counter['counterpart_initialization'] == 3
    assert counter['actual_original_BUILD_sha256'] == q['actual_BUILD_sha256']
    current, currentmeta = build(pool, counter['build_root'], counter['actual_counterpart_BUILD_sha256'])
    opposite = pool.resolve(counter['input_root'])
    assert len(counter['input_inventory']) == 10
    for name, digest in counter['input_inventory'].items():
        before, after = (inputs / name).read_bytes(), (opposite / name).read_bytes()
        assert SHA(after) == digest == currentmeta['inputs'][name]
        if name == 'swap.swp':
            expected, count = re.subn(rb'(?mi)^([ \t]*SWINCO[ \t]*=[ \t]*)[12]\b', lambda m: m[1] + str(counter['counterpart_initialization']).encode(), before)
            assert count == 1 and after == expected
        else:
            assert before == after
    a, b = source_files(bundle), source_files(current)
    assert a and a.keys() == b.keys()
    for name, path in a.items():
        assert path.read_bytes().replace(b'\r\n', b'\n') == b[name].read_bytes().replace(b'\r\n', b'\n')
    compiled_files = compiled(bundle, current)
    samples = sample_stock(pool, item['original_samples'], profile, q, inputs, data, dz)
    malformed = startup(pool, item['model_native_controls'], profile, q, meta, scalars, dz)
    roots = startup(pool, item['root_native_controls'], profile, q, meta, scalars, dz, True) if item['root_native_controls'] else 0
    if item['transactions']:
        tx = read(pool.resolve(item['transactions']) / 'RESULT.json')
        assert tx['actual_compiler_producer'] == q['source'] and tx['actual_BUILD_sha256'] == q['actual_BUILD_sha256'] and tx['compiler_executions'] == 0
        assert tx['transactions'] == dict(discard_no_day_advance=True, replay_exact=True, accept_exact=True, recovered_next_day_exact=True, origin_unchanged=True)
    if item['foreign_active_vapor_refusal']:
        root = pool.resolve(item['foreign_active_vapor_refusal'])
        vap = read(root / 'RESULT.json')
        assert vap['actual_compiler_producer'] == q['source'] and vap['actual_BUILD_sha256'] == q['actual_BUILD_sha256'] and vap['accepted_model_days'] == 0
        for label, ready in [('own-positive', True), ('foreign-active-vapor-private-input', False)]:
            stdout, stderr = (root / label / 'donor.stdout').read_bytes(), (root / label / 'donor.stderr').read_bytes()
            assert (b'HYBRID_READY' in stdout) == ready and b'HYBRID_DAY_RETURN' not in stdout
            assert not stderr if ready else b'Active vapor cannot use analytical Snow native' in stderr
    return dict(case=item['case'], actual_source=q['source'], actual_observer=q['observer_source'], days=35, native=7, exact_cold=3, compiled_files=compiled_files, model_refusals=malformed, root_refusals=roots, transactions=bool(item['transactions']), vapor_refusal=bool(item['foreign_active_vapor_refusal']), ledger=proof, original_constitutive=samples)


def preservation(optimization):
    name = 'SNOW58_ANALYTICAL_EXISTING9_MODEL1_PRESERVATION_RAW_V1'
    with ExitStack() as stack:
        pool = Pool(stack)
        store = pool.store(name)
        for path, prefix in json.loads(store.get('ACTUAL_LOCATIONS.json')).items():
            pool.add(path, name, prefix)
        parents = ('EXPLICIT_BOTTOM9_SNOW_ANALYTICAL_CURRENT_GUARD_WINDOWS_RAW_V1', 'EXPLICIT_BOTTOM9_SNOW_ANALYTICAL_WINDOWS_POSITIVE505_RAW_V1')
        for parent in parents:
            old = pool.store(parent)
            for path, entry in json.loads(old.get('ACTUAL_ARCHIVE_LOCATIONS_V1.json')).items():
                pool.add(path, entry['archive'], entry['prefix'])
        label = 'snow58-existing9-model1-preservation-' + optimization + '-v1'
        group = json.loads(store.get('profiles/' + label + '/RESULT.json'))
        assert group['actual_current_source'] == store.record['actual_compiler_source']
        assert len(group['contexts']) == 6 and group['model_executions'] == 0
        results = []
        for item in group['contexts']:
            q = read(pool.resolve(item['result']))
            case = q['case']
            assert q['source'] == group['actual_current_source'] and q['model_executions'] == 0
            parent = next(pool.store(n) for n in parents if pool.store(n).record['sha256'] == case['original_archive_sha256'])
            raw = parent.get(case['original_member'])
            assert SHA(raw) == case['original_metadata_sha256']
            oldq = json.loads(raw)
            assert oldq['build_root'] == case['baseline_build']
            before, oldmeta = build(pool, case['baseline_build'], case['baseline_BUILD_sha256'])
            after, meta = build(pool, q['actual_current_build_root'], q['actual_current_BUILD_sha256'])
            assert oldmeta['inputs'] == meta['inputs']
            a, b = source_files(before), source_files(after)
            assert a and a.keys() == b.keys()
            observed = []
            for path, entry in sorted(a.items()):
                x, y = entry.read_bytes(), b[path].read_bytes()
                assert x.replace(b'\r\n', b'\n') == y.replace(b'\r\n', b'\n')
                observed.append(dict(file=path, old_sha256=SHA(x), current_sha256=SHA(y)))
            assert observed == q['generated_sources']
            results.append(dict(label=item['label'], actual_source=q['source'], original_source=case['baseline_source'], generated_files=len(a), compiled_files=compiled(before, after)))
        return dict(status='CENTRAL_ALL6_EXISTING9_MODEL1_GENERATED_COMPILED_PRESERVATION_PASS', optimization=optimization, contexts=results, compiler_executions=0, model_executions=0)


def audit(platform, optimization):
    name = 'SNOW58_ANALYTICAL_WINDOWS_RAW_V1' if platform == 'Windows' else f'SNOW58_ANALYTICAL_UBUNTU_{optimization}_SUPPLEMENT107_V1'
    with ExitStack() as stack:
        pool = Pool(stack)
        archive = pool.store(name)
        if platform == 'Windows':
            for locator in ('ACTUAL_ARCHIVE_LOCATIONS_V1.json', 'ACTUAL_CURRENT_COMPILED_ARCHIVE_LOCATIONS_V1.json'):
                for path, item in json.loads(archive.get(locator)).items():
                    pool.add(path, item['archive'], item['prefix'])
            batch = json.loads(archive.get(f'profiles/snow58-batch-Windows-{optimization}-v2/BATCH.json'))
            all6 = json.loads(archive.get(f'profiles/snow58-Windows-{optimization}-all6-independent-107-v1/ALL6.json'))
            parent = all6['contexts'][-1]['profile'].replace(chr(92), '/').rsplit('/', 1)[0]
            repair = parent.rsplit('/', 1)[0] + f'/snow58-Windows-{optimization}-last-controls-107-v1'
        else:
            pool.add('/home/runner/work/_temp/proof', name, '')
            for path, item in json.loads(archive.get('COMPILED_PROJECTION_V1.json')).items():
                pool.add(path, name, item['archive_prefix'])
            batch = json.loads(archive.get('current/BATCH.json'))
            all6 = json.loads(archive.get('locator-repair/ALL6_INDEPENDENT.json'))
            parent = '/home/runner/work/_temp/proof/current'
            repair = '/home/runner/work/_temp/proof/locator-repair'
        assert len(batch['contexts']) == 5 and len(all6['contexts']) == 6
        items = list(batch['contexts'])
        last = all6['contexts'][-1]
        label = last['case'] + '-' + optimization
        items.append(dict(case=last['case'], model=11, bottom=5, profile=last['profile'], current_opposite_initialization_postimage=parent+'/'+label+'-opposite-initialization', original_samples=parent+'/'+label+'-original-samples', model_native_controls=repair+'/native18', root_native_controls=None, transactions=None, foreign_active_vapor_refusal=repair+'/active-vapor'))
        results = [positive(pool, item) for item in items]
        assert sum(x['model_refusals'] for x in results) == 108 and sum(x['root_refusals'] for x in results) == 50
        assert sum(x['transactions'] for x in results) == sum(x['vapor_refusal'] for x in results) == 2
        return dict(status='CENTRAL_ORIGINAL_SNOW58_SCIENCE_AND_CONTROLS_PASS_NOT_ADMITTED', platform=platform, optimization=optimization, archive_sha256=archive.record['sha256'], contexts=results, compiler_executions=0, model_executions=0, canonical_admission=False)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--platform', choices=('Windows', 'Ubuntu'), required=True)
    parser.add_argument('--optimization', choices=('O0', 'O2'), required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    result = audit(args.platform, args.optimization)
    with args.output.open('x') as stream:
        json.dump(result, stream, indent=2)
    print(result['status'], args.platform, args.optimization)

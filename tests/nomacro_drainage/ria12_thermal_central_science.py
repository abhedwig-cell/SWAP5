"""Independent fresh thermal scientific reads at explicit immutable locations."""
import argparse,json,io,re,struct,zipfile
from pathlib import Path
from contextlib import ExitStack
from analytical_hydraulic_archives import SHA
from explicit_bottom9_snow_analytical_central_science import Pool,read,rows,build,exact_native
from ria12_boundary_central_science import compiled,generated
from ordinary_pond_evidence import physical
from ria12_thermal_native import native
from ria12_thermal_science import audit_profile

def controls(pool, folder, profile, meta, parameters):
    q = read(folder / 'RESULT.json')
    original = read(profile / 'RESULT.json')
    assert q['genuine_checkpoint_producer'] == original['source'] and q['accepted_model_days'] == q['model_periods'] == 0
    assert len(q['compiled_refusals']) == 43 + 6 * original['snow'] and len(q['private_input_refusals']) == 3 and q['own_positive_ready']
    directory, current = build(pool, q['actual_current_build_root'], q['actual_BUILD_sha256'])
    assert current['inputs'] == meta['inputs']
    postimages = compiled(pool.resolve(original['build_root']), directory)
    assert generated(pool.resolve(original['build_root']), directory)
    with zipfile.ZipFile(io.BytesIO((profile / 'trajectory/accepted-column-1-day-2.zip').read_bytes())) as z:
        good = z.read('macro.bin')
    positive = folder / 'genuine-own-native-positive'
    assert b'HYBRID_READY' in (positive / 'donor.stdout').read_bytes() and not (positive / 'donor.stderr').read_bytes()
    assert (positive / 'origin/macro.bin').read_bytes() == good
    row = rows(profile / 'trajectory')[1]
    seen = set()
    for item in q['compiled_refusals']:
        label = item['attack']
        assert label not in seen
        seen.add(label)
        root = folder / label
        stdout, stderr = (root / 'donor.stdout').read_bytes(), (root / 'donor.stderr').read_bytes()
        assert b'HYBRID_READY' not in stdout and b'HYBRID_DAY_RETURN' not in stdout and b'ERROR STOP' in stderr
        raw = (root / 'origin/macro.bin').read_bytes()
        assert SHA(raw) == item['actual_raw_sha256']
        try:
            native(raw, row, meta, parameters)
        except (AssertionError, ValueError, struct.error):
            pass
        else:
            raise AssertionError('Independent complete RIA reader accepted ' + label)
    for item in q['private_input_refusals']:
        root = folder / item['attack']
        key, value = {'private-HeatOn': ('HeatOn', '.TRUE.'), 'private-VaporCond': ('VaporCond', '.TRUE.'), 'private-constitutive-ksat': ('RIA_UHCC_ksat', '11.0 5.0')}[item['attack']]
        before = (positive / 'original/swap.swp').read_bytes()
        expected, count = re.subn(rb'(?mi)^([ \t]*' + key.encode() + rb'[ \t]*=[ \t]*)[^!\r\n]*', lambda m: m[1] + value.encode(), before)
        assert count == 1 and (root / 'original/swap.swp').read_bytes() == expected
        assert (root / 'origin/macro.bin').read_bytes() == good
        assert b'HYBRID_READY' not in (root / 'donor.stdout').read_bytes() and b'ERROR STOP' in (root / 'donor.stderr').read_bytes()
    return dict(native_refusals=43 + 6 * original['snow'], private_input_refusals=3, own_positive=True, compiled_files=len(postimages), actual_compiler=q['actual_compiler_source'])


def postimage(pool, folder, profile, meta, parameters):
    q, old = read(folder / 'RESULT.json'), read(profile / 'RESULT.json')
    assert q['profile_RESULT_sha256'] == SHA((profile / 'RESULT.json').read_bytes())
    assert q['actual_original_BUILD_sha256'] == old['actual_BUILD_sha256'] and not q['completed_full35_periods_replayed']
    baseline = pool.resolve(old['build_root'])
    current, current_meta = build(pool, q['actual_current_build_root'], q['actual_current_BUILD_sha256'])
    inputs = pool.resolve(q['actual_input_root'])
    old_inputs = pool.resolve(old['input_root'])
    assert dict(q['input_inventory']) == current_meta['inputs']
    for name, digest in current_meta['inputs'].items():
        before, after = (old_inputs / name).read_bytes(), (inputs / name).read_bytes()
        assert SHA(after) == digest
        if name == 'swap.swp':
            expected, count = re.subn(rb'(?mi)^([ \t]*SWINCO[ \t]*=[ \t]*)2\b', lambda match: match[1] + b'1', before)
            assert count == 1 and after == expected
        else:
            assert before == after
    count = len(compiled(baseline, current))
    sources = generated(baseline, current)
    short = q['short_native']
    if old['kind'] == 'cde':
        assert short and short['actual_initial2_physical_prefix_exact'] and short['actual_initial2_complete_day2_native_exact']
        data = rows(folder / 'short-trajectory')
        assert len(data) == 2 and physical(data) == physical(rows(profile / 'trajectory')[:2])
        assert physical(rows(folder / 'short-own-1')) == physical(data[1:])
        exact_native(folder / 'short-trajectory/accepted-column-1-day-2.zip', profile / 'trajectory/accepted-column-1-day-2.zip')
        exact_native(folder / 'short-own-1/accepted-column-1-day-2.zip', folder / 'short-trajectory/accepted-column-1-day-2.zip')
        for day in (1, 2):
            with zipfile.ZipFile(io.BytesIO((folder / f'short-trajectory/accepted-column-1-day-{day}.zip').read_bytes())) as z:
                receipt = json.loads(z.read('checkpoint.json'))
                assert receipt['binding'] == current_meta['binding'] and receipt['receipt'] == data[day - 1]
                native(z.read('macro.bin'), data[day - 1], current_meta, parameters)
    else:
        assert short is None
    return dict(compiled_files=count, generated_sources=sources, cde_short_native_exact=bool(short), actual_compiler=q['actual_compiler_source'])


def transactions(pool, folder, profile, parameters):
    q = read(folder / 'RESULT.json')
    assert q['status'] == 'RIA12_THERMAL_ACTUAL_EXTERNAL_DISCARD_REPLAY_ACCEPT_RECOVER_EXACT_PASS_NOT_ADMITTED'
    assert q['full35_producer'] == read(profile / 'RESULT.json')['source']
    assert q['full35_periods_replayed'] == q['compiler_executions'] == 0 and not q['original_checkpoint_metadata_or_binding_rewritten']
    assert q['external_worker_prepares'] == 3 and q['external_commits'] == 1
    assert all(q[key] for key in ('discard_no_day_advance', 'replay_exact', 'accept_exact', 'recovered_next_day_exact', 'origin_unchanged'))
    _, meta = build(pool, q['actual_build_root'], q['actual_BUILD_sha256'])
    data = rows(profile / 'trajectory')
    stages = [('external/trial-1', 5), ('external/trial-2', 5), ('external', 5), ('recovered/trial-1', 6)]
    for stage, day in stages:
        path = folder / stage / f'accepted-column-1-day-{day}.zip'
        with zipfile.ZipFile(io.BytesIO(path.read_bytes())) as z:
            receipt = json.loads(z.read('checkpoint.json'))
            binding = receipt['binding']
            if 'external_daily' in binding:
                assert {k: v for k, v in binding.items() if k != 'external_daily'} == meta['binding']
            else:
                assert binding == meta['binding']
            actual_receipt = receipt['receipt']
            if stage == 'external':
                coupling = actual_receipt['coupling']
                assert coupling['id'] == 'original-output' and coupling['revision'] == 1 and coupling['origin_revision'] == 0 and coupling['origin_day'] == 4 and coupling['forcing'] == 'original-project'
                assert coupling['origin_sha256'] == SHA(pool.resolve(q['actual_origin']).read_bytes())
            else:
                assert 'coupling' not in actual_receipt
            assert physical([{k: v for k, v in actual_receipt.items() if k != 'coupling'}]) == physical([data[day - 1]])
            assert all(SHA(z.read(name)) == digest for name, digest in receipt['files'].items())
            native(z.read('macro.bin'), data[day - 1], meta, parameters)
    exact_native(folder / 'external/trial-1/accepted-column-1-day-5.zip', folder / 'external/trial-2/accepted-column-1-day-5.zip')
    exact_native(folder / 'external/trial-2/accepted-column-1-day-5.zip', folder / 'external/accepted-column-1-day-5.zip')
    if q['targeted_current_prefix_days']:
        assert q['targeted_current_prefix_days'] == 4 and physical(rows(folder / 'current-prefix4')) == physical(data[:4])
        exact_native(folder / 'current-prefix4/accepted-column-1-day-4.zip', profile / 'trajectory/accepted-column-1-day-4.zip')
    return dict(exact_external_transaction=True, actual_control_source=q['actual_observer_source'], targeted_prefix_days=q['targeted_current_prefix_days'])


def setup_windows(pool):
    for name in ('RIA12_WINDOWS_RAW_V1', 'RIA12_BOUNDARY_WINDOWS_RAW_V1', 'RIA12_THERMAL_WINDOWS_RAW_V1'):
        store = pool.store(name)
        for path, item in json.loads(store.get('ACTUAL_ARCHIVE_LOCATIONS_V1.json')).items():
            pool.add(path, name, item['prefix'])
    return 'RIA12_THERMAL_WINDOWS_RAW_V1'


def audit(platform, optimization):
    assert platform in ('Windows', 'Ubuntu') and optimization in ('O0', 'O2')
    with ExitStack() as stack:
        pool = Pool(stack)
        if platform == 'Windows':
            name = setup_windows(pool)
            supplement = name
            e = 'evidence/'
            supplement_prefix = 'evidence/ria12-thermal-Windows-native-postimages-external-v1/'
        else:
            name = 'RIA12_THERMAL_UBUNTU_' + optimization + '_ORIGINAL_V1'
            supplement = 'RIA12_THERMAL_UBUNTU_' + optimization + '_CONTROLS_V1'
            pool.add('/home/runner/work/_temp/proof/current', name, 'current')
            pool.add('/home/runner/work/_temp/builds', name, 'compiled')
            pool.add('/home/runner/work/_temp/proof/supplement', supplement, '')
            pool.store(supplement)
            e = 'current/'
            supplement_prefix = ''
        store = pool.store(name)
        result = []
        for kind in ('water', 'cde'):
            for snow in (0, 1):
                short_label=f'{kind}-snow{snow}'
                label=(f'ria12-thermal-{kind}-snow{snow}-Windows-{optimization}-full35-' + ('v2' if optimization=='O0' else 'v1')) if platform=='Windows' else short_label
                profile=pool.view(name,e+label)
                samples=pool.view(name,e+label+'-original-samples')
                actual=audit_profile(profile,samples,pool.resolve)
                original=json.loads(store.get(e+label+'-INDEPENDENT.json'))
                observer=original.pop('actual_observer_source');actual.pop('actual_observer_source')
                assert actual==original,'Fresh original scientific read differs: '+label
                q=read(profile/'RESULT.json');_,meta=build(pool,q['build_root'],q['actual_BUILD_sha256'])
                parameters=(samples/'original-parameters.bin').read_bytes()
                if platform=='Windows':
                    control=pool.view(name,supplement_prefix+short_label+'-'+optimization+'-controls')
                    post=pool.view(name,supplement_prefix+short_label+'-'+optimization+'-opposite-initial')
                    tx=pool.view(name,supplement_prefix+short_label+'-'+optimization+'-transactions') if snow or kind=='cde' else None
                else:
                    control=pool.view(name,'current/'+short_label+'-controls') if kind=='water' else pool.view(supplement,short_label+'-controls')
                    post=pool.view(name,'current/'+short_label+'-opposite-initial')
                    tx=pool.view(supplement,short_label+'-transactions') if snow or kind=='cde' else None
                result.append(dict(kind=kind,snow=snow,optimization=optimization,actual_producer=q['source'],actual_compiler=q['actual_compiler_source'],original_observer=observer,
                                   independent=actual,native_controls=controls(pool,control,profile,meta,parameters),opposite_initial=postimage(pool,post,profile,meta,parameters),
                                   external=transactions(pool,tx,profile,parameters) if tx else None,native=7,cold=3))
        return dict(status='ACTUAL_RIA_THERMAL_SNOW_CENTRAL_ORIGINAL_STOCK_WATER_SOLUTE_TEMPERATURE_NATIVE_COLD_COMPILED_AND_EXTERNAL_PASS',platform=platform,optimization=optimization,
                    contexts=result,full35_periods=4,model_executions=0,compiler_executions=0,metadata_or_source_views_faked=False,canonical_admission=False)


def main():
    p=argparse.ArgumentParser()
    p.add_argument('--platform',choices=('Windows','Ubuntu'),required=True)
    p.add_argument('--optimization',choices=('O0','O2'),required=True)
    p.add_argument('--output',type=Path,required=True)
    a=p.parse_args();q=audit(a.platform,a.optimization)
    with a.output.open('x') as out:json.dump(q,out,indent=2)
    print(q['status'],a.platform,a.optimization)


if __name__=='__main__':main()

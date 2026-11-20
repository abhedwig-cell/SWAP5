"""Read sealed actual Frost science through explicit immutable archive locations."""
from contextlib import ExitStack
import fnmatch
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import subprocess
import zipfile

from frost_cde_drainage_model_forensics import audit as model
from frost_cde_drainage_portable_forensics import binary, audit as portable
from frost_cde_drainage_sealed_components import audit as components

SHA = lambda raw: hashlib.sha256(raw).hexdigest()
ROOT = Path(__file__).resolve().parents[2]


class View:
    """Read-only path inside actual archived bytes; never rewrites a producer."""
    def __init__(self, store, name): self.store, self.path = store, str(PurePosixPath(name))
    def __truediv__(self, name): return View(self.store, self.path + '/' + str(name))
    @property
    def name(self): return PurePosixPath(self.path).name
    def read_bytes(self): return self.store.get(self.path)
    def read_text(self, encoding='utf-8'): return self.read_bytes().decode(encoding).replace('\r\n', '\n')
    def is_file(self): return self.path in self.store.names
    def glob(self, pattern):
        prefix = self.path + '/'
        return [View(self.store, n) for n in self.store.names if n.startswith(prefix) and '/' not in n[len(prefix):] and fnmatch.fnmatch(n[len(prefix):], pattern)]


class Archives:
    def __init__(self, proof, prefix, labels, stack):
        self.names = {}; self.records = {}
        for label in labels:
            record = json.loads((Path(proof) / (prefix + label + '_RAW_ARCHIVE.json')).read_text())
            path = Path(proof) / record['archive']
            if record.get('byte_parts'):
                chunks = []
                for item in record['byte_parts']:
                    raw = (Path(proof) / item['path']).read_bytes()
                    assert len(raw) == item['bytes'] and SHA(raw) == item['sha256']; chunks.append(raw)
                raw = b''.join(chunks); assert len(raw) == record['bytes'] and SHA(raw) == record['sha256']
                z = stack.enter_context(zipfile.ZipFile(io.BytesIO(raw)))
            else:
                assert path.stat().st_size == record['bytes'] and SHA(path.read_bytes()) == record['sha256']
                z = stack.enter_context(zipfile.ZipFile(path))
            assert set(z.namelist()) == set(record['members']) and not set(z.namelist()).intersection(self.names)
            for name, item in record['members'].items(): self.names[name] = (z, item)
            self.records[label] = record
    def get(self, name):
        z, item = self.names[name]; raw = z.read(name)
        assert SHA(raw) == (item['sha256'] if isinstance(item, dict) else item)
        if isinstance(item, dict): assert len(raw) == item['bytes']
        return raw
    def view(self, name): return View(self, name)


class Bytes:
    def __init__(self, values): self.names = values
    def get(self, name): return self.names[name]


def mapped(store, path):
    path = str(path).replace('\\', '/')
    relative = path.split('/evidence/', 1)[1]
    assert not PurePosixPath(relative).is_absolute() and '..' not in PurePosixPath(relative).parts
    return store.view('profiles/' + relative)


def windows(proof):
    with ExitStack() as stack:
        labels = ['WINDOWS_' + o + '_' + k for o in ('O0', 'O2') for k in ('SCIENCE', 'CONTROLS')] + ['WINDOWS_SUPPORT']
        current = Archives(proof, 'FROST_DRAINAGE_', labels, stack)
        projection = json.loads(current.get('COMPILED_PROJECTION_V1.json'))
        prepared = json.loads(current.get('provider-PREPARED.json'))
        captured = json.loads(current.get('profiles/frost-drainage-source-v1/RESULT.json'))
        capsule = current.get('profiles/frost-drainage-source-v1/actual-producer-source.zip')
        assert len(capsule) == captured['bytes'] and SHA(capsule) == captured['sha256']
        production = ('app', 'src', 'tools/solute', 'tools/vq', 'reference/swap-4.3.1')
        assert not subprocess.check_output(['git', 'diff', '6e40385c9b871992641f7a601bbf0ec30f5f68d3',
            captured['producer_head'], '--', *production], cwd=ROOT)
        tree = subprocess.check_output(['git', 'ls-tree', '-r', captured['producer_head']], cwd=ROOT, text=True)
        expected = {line.split('\t', 1)[1]: line.split('\t', 1)[0].split()[2] for line in tree.splitlines()}
        cap = stack.enter_context(zipfile.ZipFile(io.BytesIO(capsule)))
        for name in cap.namelist():
            raw = cap.read(name); item = captured['members'][name]
            assert SHA(raw) == item['sha256'] and item['git_blob'] == expected[name]
            blob = lambda value: hashlib.sha1(b'blob ' + str(len(value)).encode() + b'\0' + value).hexdigest()
            assert expected[name] in (blob(raw), blob(raw.replace(b'\r\n', b'\n')))
        original = stack.enter_context(zipfile.ZipFile(io.BytesIO(cap.read('reference/swap-4.3.1/source-archives/SWAP.ZIP'))))
        assert SHA(cap.read('reference/swap-4.3.1/source-archives/SWAP.ZIP')) == prepared['source_archives']['SWAP.ZIP'] == '1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151'
        ref = View(Bytes({'original/build/swap-selected/divdra.f90': original.read('SWAP/divdra.f90')}), 'original')
        results = []; controls = []; component_results = {}
        for opt in ('O0', 'O2'):
            component_results[opt] = components(current.get, current.names,
                dict(overlap=f'profiles/frost-cde-drainage-overlap-{opt}-v1',
                     rates=f'profiles/frost-cde-drainage-rates-corrected-{opt}-v1',
                     cde=f'profiles/frost-cde-drainage-cde-{opt}-v2'),
                {name: original.read('SWAP/' + name + '.f90') for name in ('divdra', 'solute', 'frozencond')}, prepared, opt)
            for kind in ('water', 'cde'):
                for phase in ('short', 'full'):
                    version = 'v2' if (opt, kind, phase) == ('O0', 'water', 'short') else 'v1'
                    root = 'profiles/frost-divdra-daily-' + kind + '-' + phase + '-' + opt + '-' + version
                    profile = current.view(root); q = json.loads((profile / 'RESULT.json').read_text())
                    item = projection[q['build_root']]; bundle = current.view(item['prefix'])
                    assert SHA((bundle / 'BUILD.json').read_bytes()) == item['actual_BUILD_sha256']
                    result = model(profile, ref, locations=dict(bundle=bundle, inputs=mapped(current, q['input_root']),
                        warm=profile / 'trajectory', cold=lambda day, p=profile: p / ('own-' + str(day))),
                        provider_catalog=prepared['provider_files'])
                    warm_output = binary((profile / 'trajectory/original/result_output.bin').read_bytes())
                    from datetime import date, timedelta
                    meta = json.loads((bundle / 'BUILD.json').read_text())
                    first = date.fromisoformat(meta['project']['start_date'])
                    for own in q['own']:
                        low, high = str(first+timedelta(days=own['start'])), str(first+timedelta(days=own['end']))
                        expected = [row for row in warm_output[1:] if low <= row[:19].decode().strip() < high]
                        actual = binary((profile / ('own-' + str(own['start'])) / 'original/result_output.bin').read_bytes())[1:]
                        assert actual == expected
                    results.append(result)
                cq = json.loads(current.get(f'profiles/frost-divdra-daily-{kind}-controls-{opt}-v1/RESULT.json'))
                assert cq['status'] == 'ACTUAL_FROST_SWDIVD1_COMPILED_NATIVE_ACTIVE_TRANSACTIONS_SCOPE_SOURCE_CONTROLS_PASS'
                assert len(cq['native_refusals']) == (39 if kind == 'water' else 44)
                assert all(v['status'] == 'REFUSED' and 'ERROR STOP' in v['diagnostic'] for v in cq['native_refusals'])
                assert len(cq['source_refusals']) == (4 if kind == 'water' else 6)
                assert len(cq['descriptor_refusals']) == (6 if kind == 'water' else 7)
                assert all(v is True for k, v in cq['transactions'].items() if k != 'start_day') and cq['transactions']['start_day'] == 19
                controls.append(dict(kind=kind, optimization=opt, native_refusals=len(cq['native_refusals']),
                    source_refusals=len(cq['source_refusals']), descriptor_refusals=len(cq['descriptor_refusals']), transactions=1))
        inherited = {}
        for prefix in ('SNOW_UNDRAINED_', 'WATER_SNOW_GROUNDWATER_'):
            store = Archives(proof, prefix, labels, stack)
            inherited[prefix] = (store, json.loads(store.get('COMPILED_PROJECTION_V1.json')))
        postimages = []
        for opt, version in (('O0', 'v7'), ('O2', 'v4')):
            q = json.loads(current.get(f'profiles/frost-unselected-postimages-{opt}-{version}/RESULT.json'))
            assert q['status'] == 'ACTUAL_SIX_UNSELECTED_FROST_COMPOSITION_DEPENDENCY_POSTIMAGES_PASS' and q['fresh_unaffected_full_periods'] == 0
            legacy = Archives(proof, '', ['OUTPUT_THERMAL_WINDOWS_' + opt], stack)
            for name, item in q['profiles'].items():
                assert item['status'] == 'EXACT_UNSELECTED_FORTRAN_PHYSICAL_NATIVE_USER_OUTPUT_POSTIMAGE_PASS'
                bundle = current.view(projection[item['build_root']]['prefix']); base = item['baseline']
                if base.get('qualified_archive'):
                    assert base['qualified_archive_sha256'] == legacy.records['OUTPUT_THERMAL_WINDOWS_' + opt]['sha256']
                    stem = f'output-thermal-water-frost-{name.split("old-frost-",1)[1]}-{opt}-v1'
                    before = legacy.view(stem + '/build'); warm_before = legacy.view(stem + '/trajectory')
                    assert SHA((legacy.view(stem) / 'RESULT.json').read_bytes()) == base['receipt_sha256']
                else:
                    sources = [(store, table[base['build_root']]) for store, table in inherited.values() if base['build_root'] in table]
                    assert sources, 'No accepted original compiled baseline for ' + name
                    store, entry = sources[0]; before = store.view(entry.get('prefix', entry.get('archive_prefix')))
                    warm_before = mapped(store, base['trajectory_root'])
                    assert SHA(mapped(store, base['receipt']).read_bytes()) == base['receipt_sha256']
                assert {p.name: p.read_bytes() for p in before.glob('*.f90')} == {p.name: p.read_bytes() for p in bundle.glob('*.f90')}
                oldmeta = json.loads((before / 'BUILD.json').read_text()); newmeta = json.loads((bundle / 'BUILD.json').read_text())
                assert oldmeta['inputs'] == newmeta['inputs']
                warm = mapped(current, item['trajectory_root']); cold = mapped(current, item['cold_actual_root'])
                rows = lambda p: [json.loads(s) for s in (p / 'daily.jsonl').read_text().splitlines()]
                data, previous = rows(warm), rows(warm_before)
                from ordinary_pond_evidence import physical
                assert len(data) == 35 and physical(data) == physical(previous[:35]) and physical(rows(cold)) == physical(data[30:34])
                for day in (2, 4, 30, 34, 35):
                    with zipfile.ZipFile(io.BytesIO((warm_before / f'accepted-column-1-day-{day}.zip').read_bytes())) as a, \
                         zipfile.ZipFile(io.BytesIO((warm / f'accepted-column-1-day-{day}.zip').read_bytes())) as b:
                        assert all(a.read(n) == b.read(n) for n in ('macro.bin', 'result.end'))
                with zipfile.ZipFile(io.BytesIO((warm / 'accepted-column-1-day-34.zip').read_bytes())) as a, \
                     zipfile.ZipFile(io.BytesIO((cold / 'accepted-column-1-day-34.zip').read_bytes())) as b:
                    assert all(a.read(n) == b.read(n) for n in ('macro.bin', 'result.end'))
                postimages.append(dict(name=name, optimization=opt, original_Fortran_exact=True, physical_native_exact=True, cold_exact=True))
        assert len(postimages) == 12
        return dict(status='SEALED_ACTUAL_FROST_WINDOWS_MODELS_CONTROLS_UNSELECTED_POSTIMAGES_PASS', results=results,
            controls=controls, components=component_results, postimages=postimages, actual_full_periods=4, actual_full_cold_windows=28,
            actual_short_contexts=4, actual_short_cold_windows=12, actual_compiled_refusals=166,
            actual_source_refusals=20, actual_descriptor_refusals=26, actual_transaction_contexts=4,
            actual_unselected_contexts=12, actual_unselected_cold_windows=12, model_executions=0, compiler_executions=0)


def ubuntu(proof, optimization):
    proof = Path(proof)
    records = [json.loads((proof / f'FROST_DRAINAGE_UBUNTU_{role}_{optimization}_RAW_ARCHIVE.json').read_text())
               for role in ('ORIGINAL', 'FOLLOWUPPASS')]
    paths = [proof / record['archive'] for record in records]
    for path, record in zip(paths, records):
        assert path.stat().st_size == record['bytes'] and SHA(path.read_bytes()) == record['sha256']
    with zipfile.ZipFile(paths[0]) as original, zipfile.ZipFile(paths[1]) as followup:
        result = portable(original, followup, optimization)
    return dict(status='SEALED_ACTUAL_FROST_UBUNTU_SOURCE_COMPONENT_MODELS_CONTROLS_PASS',
        observations=result, actual_full_periods=2, actual_full_cold_windows=14,
        actual_short_contexts=2, actual_short_cold_windows=6, actual_compiled_refusals=83,
        actual_source_refusals=10, actual_descriptor_refusals=13, actual_transaction_contexts=2,
        actual_unselected_contexts=0, actual_unselected_cold_windows=0,
        model_executions=0, compiler_executions=0)

"""Recompute the bounded input study from raw observations and current source."""
import argparse
import csv
import hashlib
import io
import json
from pathlib import Path
import statistics
import subprocess
import sys
import tarfile
import tempfile
from assess_perf01_weather import read, differences, same_physics

ROOT = Path(__file__).resolve().parents[2]
SOURCE_TREE = '8eda6373e2d3b5e083514d550d9ab43c0525126f'
PREDECESSOR_SHA = 'bcf446368a5cc8a1cfe41deac4718bc3f66f05712abe05972a17446c2fd16f3d'
sha = lambda raw: hashlib.sha256(raw).hexdigest()
def verify(folder):
    report = json.loads((folder/'RESULT.json').read_text())
    assert report['status'] == 'COMPLETE_BOUNDED_RETRY_ACCURACY_STUDY_O0_O2_RESTART_PASS'
    context = report.get('source_context_commit','53010691c79d3e132914ce372059cf873d88b96d')
    assert subprocess.check_output(['git','rev-parse',context+':src'],cwd=ROOT,text=True).strip() == report['source_tree']
    profile = report.get('profile','original')
    assert profile in ['original','sensitive']
    closure = subprocess.check_output([sys.executable,str(ROOT/'tests/support/augment_bartholomeus_backend_sources.py'),'--all',
        'tests/fsi/fsi04_real_headcalc_stubs.f90','src/runtime/mod_fmr_production_application_bootstrap.f90',
        'src/kernel/mod_kernel_committed_persistence.f90'],cwd=ROOT,text=True).splitlines()
    expected = []
    for rain in [4,1]:
        for repeat in range(3):
            budgets = [.001,.003,.01] if repeat != 1 else [.01,.003,.001]
            expected += [f'{rain}x-{b:g}-r{repeat}' for b in budgets]
        expected += [f'{rain}x-{b:g}-checked' for b in [.001,.01]]
        expected += [f'{rain}x-0.01-restart']
    assert [e['label'] for e in report['events']] == expected
    assert all(e['returncode'] == 0 for e in report['events'])
    for opt, meta in report['builds'].items():
        assert list(meta['sources']) == closure
        assert meta['weather_line_search_retry'] and meta['observe_work']
        generated = {'tests/fsi/fsi04_real_headcalc_stubs.f90': 'grid_stubs.f90',
            'src/runtime/mod_fmr_serialized_multiswap_runtime.f90': 'observed_serial_runtime.f90',
            'src/runtime/mod_fmr_production_application_bootstrap.f90': 'observed_bootstrap.f90'}
        for path, digest in meta['sources'].items():
            raw = (folder/'builds'/opt/generated[path]).read_bytes() if path in generated else (ROOT/path).read_bytes()
            assert sha(raw) == digest, path
        assert sha((ROOT/'src/legacy/b1_10_port/headcalc.f90').read_bytes()) == meta['headcalc_sha256']
        assert sha((folder/'builds'/opt/'driver.f90').read_bytes()) == meta['generated_driver_sha256']
    predecessor = ROOT/'benchmarks/performance/PERF01_LINE_SEARCH_COMPOSITION_20261022_EVIDENCE.tar.xz'
    assert sha(predecessor.read_bytes()) == PREDECESSOR_SHA
    replay = {}
    with tarfile.open(predecessor,'r:xz') as old:
        for opt in ['O0','O2']:
            for name in ['observed_bootstrap.f90','observed_serial_runtime.f90','grid_stubs.f90']:
                assert (folder/'builds'/opt/name).read_bytes() == old.extractfile(f'weather-{opt}/{name}').read()
        for rain in [4,1]:
            metrics, rows, work = {}, {}, {}
            for label in [p for p in expected if p.startswith(f'{rain}x-')]:
                m, r = read(folder/label/'native')
                assert abs(m['totals']['rain_mm']-rain*227) < 1e-8
                opt = 'O0' if label.endswith('checked') else 'O2'
                assert m['executable_sha256'] == report['builds'][opt]['executable_sha256']
                assert m['head_budget_cm'] == float(label.split('-')[1])
                assert m['command'][-1] == profile
                w = [list(map(int,l.split()[1:])) for l in (folder/label/'native/stdout').read_text().splitlines()
                    if l.startswith('NEWTON_WORK')]
                assert len(w) == 97 and [v[0] for v in w] == list(range(1,98))
                metrics[label],rows[label],work[label] = m,r,w
            # The new 1e-3 run must retain the admitted ON physical values and work.
            if profile == 'original':
                raw = old.extractfile(f'on-season-O2-{rain}x/native/daily.csv').read().decode()
                previous = [{k:float(v) for k,v in row.items()} for row in csv.DictReader(io.StringIO(raw))]
                for r,s in zip(rows[f'{rain}x-0.001-r0'],previous):
                    assert all(r[k] == v for k,v in s.items() if k != 'core_cpu_s')
            elif rain == 1:
                assert metrics[f'{rain}x-0.001-r0']['stress_days'] > 0
                assert metrics[f'{rain}x-0.001-r0']['totals']['stress_deficit_mm'] > 1e-4
            for budget in [.001,.003,.01]:
                labels = [f'{rain}x-{budget:g}-r{i}' for i in range(3)]
                ref = labels[0]
                for label in labels[1:]:
                    same_physics(rows[label],rows[ref]); assert work[label] == work[ref]
                saved = report['cases'][str(rain)][str(budget)]
                cpu = [metrics[l]['user_seconds'] for l in labels]
                assert saved['cpu_seconds'] == cpu and saved['median_cpu_seconds'] == statistics.median(cpu)
                assert saved['differences_vs_1e3'] == differences(rows[ref],rows[f'{rain}x-0.001-r0'])
                assert saved['work'] == metrics[ref]['work']
                assert saved['newton_work'] == dict(zip(['jacobians','backtracks','solver_rejections'],
                    [sum(w[i] for w in work[ref]) for i in [1,2,3]]))
                assert saved['totals'] == metrics[ref]['totals']
                if 'stress_days' in saved: assert saved['stress_days'] == metrics[ref]['stress_days']
            for budget in [.001,.01]:
                label, ref = f'{rain}x-{budget:g}-checked', f'{rain}x-{budget:g}-r0'
                same_physics(rows[label],rows[ref]); assert work[label] == work[ref]
            label,ref = f'{rain}x-0.01-restart',f'{rain}x-0.01-r0'
            same_physics(rows[label],rows[ref]); assert work[label] == work[ref]
            case = report['cases'][str(rain)]
            ratio = case['0.01']['median_cpu_seconds']/case['0.001']['median_cpu_seconds']
            assert ratio == case['on_1e2_over_on_1e3_cpu']
            replay[str(rain)] = dict(cpu_ratio=ratio, differences=case['0.01']['differences_vs_1e3'],
                stress_days=metrics[f'{rain}x-0.001-r0']['stress_days'],
                total_stress_deficit_mm=metrics[f'{rain}x-0.001-r0']['totals']['stress_deficit_mm'])
    return dict(status='RAW_REPLAY_O0_O2_RESTART_PREDECESSOR_PASS', native_observations=24, cases=replay,
        source_tree=report['source_tree'], profile=profile, default_changed=False, general_accuracy_guarantee=False)
def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('evidence', type=Path)
    args = ap.parse_args()
    if args.evidence.is_dir():
        result = verify(args.evidence)
    else:
        index = json.loads(args.evidence.with_name(args.evidence.name.removesuffix('.tar.xz')+'.index.json').read_text())
        raw = args.evidence.read_bytes()
        assert sha(raw) == index['sha256'] and len(raw) == index['bytes']
        with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz') as tar, tempfile.TemporaryDirectory() as temp:
            members = tar.getmembers()
            assert len(members) == index['members'] == len({m.name for m in members})
            assert all(m.isfile() and not Path(m.name).is_absolute() and '..' not in Path(m.name).parts for m in members)
            tar.extractall(temp,filter='data')
            folder = Path(temp)
            manifest = json.loads((folder/'MANIFEST.json').read_text())
            assert set(manifest) == {m.name for m in members} - {'MANIFEST.json'}
            for path,digest in manifest.items(): assert sha((folder/path).read_bytes()) == digest,path
            result = verify(folder)
    print(json.dumps(result,indent=2))
if __name__ == '__main__':
    main()

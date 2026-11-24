"""Independent RIA35 balances, complete native/calendar and original soil observations."""
import argparse
from decimal import Decimal, localcontext
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import zipfile

R = Path(__file__).resolve().parents[2]
sys.path[:0] = [str(R / 'tests/nomacro_drainage'), str(R / 'tests/nomacro_scheduled_subsurface')]
from ria12_native import native
from ordinary_pond_evidence import physical
from implicit_conductivity_forensics import water, sequential_records
SHA = lambda raw: hashlib.sha256(raw).hexdigest()


def main():
    parser = argparse.ArgumentParser()
    for key in ('profile', 'reference-samples', 'output'):
        parser.add_argument('--' + key, type=Path, required=True)
    args = parser.parse_args()
    q = json.loads((args.profile / 'RESULT.json').read_text())
    assert q['status'] == 'ACTUAL_RIA12_FULL35_PHYSICAL_NATIVE_COLD_USER_OUTPUT_PASS_NOT_ADMITTED'
    assert q['days'] == 35 and q['source'] == q['actual_completion_head'] == q['build']['actual_completion_head']
    bundle, inputs = Path(q['build_root']), Path(q['input_root'])
    meta = json.loads((bundle / 'BUILD.json').read_text())
    assert SHA((bundle / 'BUILD.json').read_bytes()) == q['actual_BUILD_sha256']
    assert dict(q['input_inventory']) == meta['inputs'] == {name: SHA((inputs / name).read_bytes()) for name, _ in q['input_inventory']}
    assert meta['identity']['original_output']['original_ria12']['models'] == q['layer_models'] == [12, 12]
    for name, digest in meta['identity']['donor_generated'].items():
        assert SHA((bundle / name).read_bytes()) == digest
    for role in ('donor', 'kernel'):
        paths = [bundle / ('day_' + role + suffix) for suffix in ('', '.exe') if (bundle / ('day_' + role + suffix)).is_file()]
        assert len(paths) == 1 and SHA(paths[0].read_bytes()) == meta['executable_sha256'][role]
    sample = json.loads((args.reference_samples / 'RESULT.json').read_text())
    assert sample['profile_RESULT_sha256'] == SHA((args.profile / 'RESULT.json').read_bytes())
    assert sample['daily_sha256'] == SHA((args.profile / 'trajectory/daily.jsonl').read_bytes()) and sample['actual_soil_input_sha256'] == meta['inputs']['swap.swp']
    assert sample['model_periods'] == 0 and sample['maximum_original_theta_stock_difference_cm'] <= 1e-10
    component = Path(sample['component_root'])
    assert json.loads((component / 'COMPONENT.json').read_text()) == sample['component']
    assert SHA((component / sample['component']['executable']).read_bytes()) == sample['component']['executable_sha256']
    assert SHA((args.reference_samples / 'sample.stdout').read_bytes()) == sample['stdout_sha256'] and not (args.reference_samples / 'sample.stderr').read_bytes()
    parameters = (args.reference_samples / 'original-parameters.bin').read_bytes()
    assert SHA(parameters) == sample['original_parameter_bytes_sha256']
    rows = lambda path: [json.loads(line) for line in (path / 'daily.jsonl').read_text().splitlines()]
    warm = args.profile / 'trajectory'
    data = rows(warm)
    assert len(data) == 35 and [row['day'] for row in data] == list(range(1, 36))
    peak = Decimal(0)
    with localcontext() as context:
        context.prec = 60
        for row in data:
            dec = lambda value: Decimal(str(value))
            residual = sum(map(dec, row['stock_start_cm'])) + sum(map(dec, row['external_flux_cm'][:7])) - sum(map(dec, row['external_flux_cm'][7:])) - sum(map(dec, row['stock_end_cm']))
            assert abs(residual) <= Decimal('1e-10')
            peak = max(peak, abs(residual))
    def audit(root, observed):
        water_proof = water(observed)
        byday = {row['day']: row for row in observed}
        seen = []
        for path in root.glob('accepted-column-1-day-*.zip'):
            day = int(path.stem.rsplit('-', 1)[1])
            with zipfile.ZipFile(path) as z:
                assert set(z.namelist()) == {'checkpoint.json', 'macro.bin', 'result.end'}
                checkpoint = json.loads(z.read('checkpoint.json'))
                assert checkpoint['binding'] == meta['binding'] and checkpoint['receipt'] == byday[day]
                assert all(SHA(z.read(name)) == digest for name, digest in checkpoint['files'].items())
                native(z.read('macro.bin'), byday[day], meta, parameters)
                sequential_records(z.read('result.end'))
            seen.append(day)
        chemical = None
        if q['kind'] == 'cde':
            from groundwater_snow_forensics import clock
            chemical = clock.ledger(observed, len(observed))
            class Files:
                def read(self, name):
                    return (root / name).read_bytes()
            clock.daily(Files(), '', observed, meta['project']['nodes'])
        return dict(water=water_proof, solute=chemical, native_samples=sorted(seen))
    proof = audit(warm, data)
    assert proof['native_samples'] == [2, 4, 7, 9, 30, 34, 35]
    windows = [(2, 4), (7, 9), (30, 34)]
    assert [(item['start'], item['end']) for item in q['cold']] == windows
    cold = []
    for low, high in windows:
        root = args.profile / ('own-' + str(low))
        observed = rows(root)
        assert physical(observed) == physical(data[low:high])
        result = audit(root, observed)
        assert result['native_samples'] == [high]
        with zipfile.ZipFile(warm / f'accepted-column-1-day-{high}.zip') as a, zipfile.ZipFile(root / f'accepted-column-1-day-{high}.zip') as b:
            assert all(a.read(name) == b.read(name) for name in ('macro.bin', 'result.end'))
        cold.append(result)
    if q['kind'] == 'cde':
        assert any(row['solute_ledger_mg_cm2'][3] > 0 for row in data)
    record = dict(status='INDEPENDENT_RIA12_FULL35_GLOBAL_SOLUTE_ORIGINAL_STOCK_NATIVE_PARAMETERS_AND_EXACT_COLD_PASS_NOT_ADMITTED',
                  actual_model_producer=q['source'], actual_observer_source=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=R).decode().strip(),
                  actual_BUILD_sha256=q['actual_BUILD_sha256'], kind=q['kind'], optimization=q['optimization'], days=35, warm=proof, cold=cold,
                  actual_original_constitutive_observations=sum(len(rows) for rows in sample['observations_by_layer'].values()),
                  maximum_original_theta_stock_difference_cm=sample['maximum_original_theta_stock_difference_cm'], decimal_global_maximum_absolute_residual_cm=str(peak),
                  absolute_water_limit_cm='1e-10', original_parameter_bytes_verified=True, model_executions=0, compiler_executions=0, canonical_admission=False)
    with args.output.open('x') as stream:
        json.dump(record, stream, indent=2)
    print(record['status'], q['kind'], q['optimization'], peak)


if __name__ == '__main__':
    main()

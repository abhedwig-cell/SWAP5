"""Independent RIA35 balances, complete native/calendar and original soil observations."""
import argparse
from datetime import date
from decimal import Decimal, localcontext
import hashlib
import io
import json
import math
import re
from pathlib import Path
import subprocess
import sys
import zipfile

R = Path(__file__).resolve().parents[2]
sys.path[:0] = [str(R / 'tests/nomacro_drainage'), str(R / 'tests/nomacro_scheduled_subsurface')]
from ria12_corrected_native import native
from ordinary_pond_evidence import physical
from implicit_conductivity_forensics import water, sequential_records
SHA = lambda raw: hashlib.sha256(raw).hexdigest()


def standard_cde_daily(root, data, epoch):
    """Read this producer's actual standard-daily ABI, not interval diagnostics."""
    ledgers, receipts, returns = [], [], []
    for line in (root / 'original/donor.stdout').read_text().splitlines():
        if line.startswith('HYBRID_SOLUTE_LEDGER '):
            values = list(map(float, line.split()[1:]))
            assert len(values) == 9 and all(map(math.isfinite, values))
            ledgers.append(values)
        elif line.startswith('ORIGINAL_DAILY_RECEIPT '):
            fields = line.split()
            assert len(fields) == 3
            receipts.append((int(fields[1]), float(fields[2])))
        elif line.startswith('HYBRID_DAY_RETURN '):
            fields = line.split()
            assert len(fields) == 3
            returns.append((int(fields[1]), float(fields[2])))
    assert len(ledgers) == 2 * len(data) + 1
    assert ledgers[0][0] == data[0]['solute_start_mg_cm2']
    for index, row in enumerate(data):
        assert ledgers[2 * index + 1] == ledgers[2 * index + 2] == row['solute_ledger_mg_cm2']
    clock = (date.fromisoformat(epoch) - date(1900, 1, 1)).days + 1
    expected = [(row['day'], clock + row['day']) for row in data]
    assert receipts == returns == expected
    return dict(actual_original_daily_receipts=len(receipts), actual_paired_original_chemical_ledgers=len(ledgers) - 1)


def original_samples(folder, component, sample, inputs, data):
    """Read original executable observations and every measured stock afresh."""
    q = sample['component']
    assert all(item['returncode'] == 0 for item in q['compiler'])
    for name, key in (('MOD_RIA.f90', 'original_RIA_raw_sha256'), ('swap_base.f90', 'original_swap_base_raw_sha256'),
                      ('original_swapoutput.f90', 'original_error_full_source_sha256'), ('swap_error.f90', 'original_error_fragment_sha256'),
                      ('ria12_reference_probe.f90', 'driver_raw_sha256')):
        assert SHA((component / name).read_bytes()) == q[key]
    assert SHA((component / 'MOD_RIA.f90').read_bytes().replace(b'\r\n', b'\n')) == '454b3949827917ce0ca32ce044e6368faffbf6c4c14266f1f969c2e3b038a01a'
    full = (component / 'original_swapoutput.f90').read_bytes()
    low, high = q['original_error_fragment_bounds']
    assert full[low:high] == (component / 'swap_error.f90').read_bytes()
    driver = (component / 'ria12_reference_probe.f90').read_bytes()
    committed = subprocess.check_output(['git', 'show', q['actual_source'] + ':tests/nomacro_drainage/ria12_reference_probe.f90'], cwd=R)
    assert driver.replace(b'\r\n', b'\n') == committed
    heads = sorted({head for row in data for head in row['pressure_head_cm']})
    expected = (str(len(heads)) + '\n' + ''.join(format(head, '.17g') + '\n' for head in heads)).encode()
    actual_heads = (folder / 'actual-heads.txt').read_bytes()
    assert sample['heads'] == heads and actual_heads.replace(b'\r\n', b'\n') == expected
    assert SHA(actual_heads) == sample['head_input_sha256']
    observed = {}
    for line in (folder / 'sample.stdout').read_text().splitlines():
        if not line.startswith('ACTUAL_ORIGINAL_RIA12_SAMPLE '):
            continue
        words = line.split()
        model, layer, index = map(int, words[1:4])
        values = list(map(float, words[4:]))
        assert len(words) == 10 and model == 12 and layer in (1, 2) and 1 <= index <= len(heads)
        assert (layer, index) not in observed and values[0] == heads[index - 1] and all(map(math.isfinite, values))
        assert min(values[1:5]) >= 0 and values[5] == 0 and values[3] == values[4]
        observed[layer, index] = values
    assert len(observed) == 2 * len(heads)
    for layer in (1, 2):
        assert sample['observations_by_layer'][str(layer)] == [observed[layer, i] for i in range(1, len(heads) + 1)]
    table = re.search(r'(?mi)^\s*ISUBLAY\s+ISOILLAY\s+HSUBLAY\s+NCOMP\s*\n(.*?)^\* End of table', (inputs / 'swap.swp').read_bytes().decode('cp1252'), re.S)
    assert table
    layers, dz = [], []
    for line in table[1].splitlines():
        words = line.split('!')[0].split()
        if words:
            assert len(words) == 4 and int(words[1]) in (1, 2)
            count = int(words[3])
            layers.extend([int(words[1])] * count)
            dz.extend([float(words[2]) / count] * count)
    lookup = {layer: {values[0]: values for (soil, _), values in observed.items() if soil == layer} for layer in (1, 2)}
    errors = []
    for row in data:
        assert len(row['pressure_head_cm']) == len(layers)
        stock = math.fsum(lookup[layer][head][1] * height for layer, head, height in zip(layers, row['pressure_head_cm'], dz))
        error = abs(stock - row['stock_end_cm'][0])
        assert error <= 1e-10
        errors.append(error)
    assert max(errors) == sample['maximum_original_theta_stock_difference_cm']


def audit_profile(profile, reference_samples, resolve=Path):
    """Audit real directories or explicit immutable archive locations."""
    q = json.loads((profile / 'RESULT.json').read_text())
    assert q['status'] == 'ACTUAL_RIA12_CORRECTED_FULL35_PHYSICAL_NATIVE_COLD_USER_OUTPUT_PASS_NOT_ADMITTED'
    assert q['days'] == 35 and q['source'] == q['actual_completion_head']
    assert q['actual_compiler_source'] == q['build']['actual_completion_head']
    assert not subprocess.check_output(['git', 'diff', q['actual_compiler_source'], q['source'], '--', 'app', 'src', 'tools', 'reference'], cwd=R)
    bundle, inputs = resolve(q['build_root']), resolve(q['input_root'])
    meta = json.loads((bundle / 'BUILD.json').read_text())
    assert SHA((bundle / 'BUILD.json').read_bytes()) == q['actual_BUILD_sha256']
    assert dict(q['input_inventory']) == meta['inputs'] == {name: SHA((inputs / name).read_bytes()) for name, _ in q['input_inventory']}
    assert meta['identity']['original_output']['original_ria12_corrected']['models'] == q['layer_models'] == [12, 12]
    for name, digest in meta['identity']['donor_generated'].items():
        assert SHA((bundle / name).read_bytes()) == digest
    for role in ('donor', 'kernel'):
        paths = [bundle / ('day_' + role + suffix) for suffix in ('', '.exe') if (bundle / ('day_' + role + suffix)).is_file()]
        assert len(paths) == 1 and SHA(paths[0].read_bytes()) == meta['executable_sha256'][role]
    sample = json.loads((reference_samples / 'RESULT.json').read_text())
    assert sample['profile_RESULT_sha256'] == SHA((profile / 'RESULT.json').read_bytes())
    assert sample['daily_sha256'] == SHA((profile / 'trajectory/daily.jsonl').read_bytes()) and sample['actual_soil_input_sha256'] == meta['inputs']['swap.swp']
    assert sample['model_periods'] == 0 and sample['maximum_original_theta_stock_difference_cm'] <= 1e-10
    component = resolve(sample['component_root'])
    assert json.loads((component / 'COMPONENT.json').read_text()) == sample['component']
    assert SHA((component / sample['component']['executable']).read_bytes()) == sample['component']['executable_sha256']
    assert SHA((reference_samples / 'sample.stdout').read_bytes()) == sample['stdout_sha256'] and not (reference_samples / 'sample.stderr').read_bytes()
    parameters = (reference_samples / 'original-parameters.bin').read_bytes()
    assert SHA(parameters) == sample['original_parameter_bytes_sha256']
    rows = lambda path: [json.loads(line) for line in (path / 'daily.jsonl').read_text().splitlines()]
    warm = profile / 'trajectory'
    data = rows(warm)
    original_samples(reference_samples, component, sample, inputs, data)
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
            with zipfile.ZipFile(io.BytesIO(path.read_bytes())) as z:
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
            actual_daily = standard_cde_daily(root, observed, meta['project']['start_date'])
            chemical = dict(unchanged_ledger=chemical, actual_standard_daily_output=actual_daily)
        return dict(water=water_proof, solute=chemical, native_samples=sorted(seen))
    proof = audit(warm, data)
    assert proof['native_samples'] == [2, 4, 7, 9, 30, 34, 35]
    windows = [(2, 4), (7, 9), (30, 34)]
    assert [(item['start'], item['end']) for item in q['cold']] == windows
    cold = []
    for low, high in windows:
        root = profile / ('own-' + str(low))
        observed = rows(root)
        assert physical(observed) == physical(data[low:high])
        result = audit(root, observed)
        assert result['native_samples'] == [high]
        with zipfile.ZipFile(io.BytesIO((warm / f'accepted-column-1-day-{high}.zip').read_bytes())) as a, zipfile.ZipFile(io.BytesIO((root / f'accepted-column-1-day-{high}.zip').read_bytes())) as b:
            assert all(a.read(name) == b.read(name) for name in ('macro.bin', 'result.end'))
        cold.append(result)
    if q['kind'] == 'cde':
        assert any(row['solute_ledger_mg_cm2'][3] > 0 for row in data)
    record = dict(status='INDEPENDENT_RIA12_CORRECTED_FULL35_GLOBAL_SOLUTE_ORIGINAL_STOCK_NATIVE_PARAMETERS_AND_EXACT_COLD_PASS_NOT_ADMITTED',
                  actual_model_producer=q['source'], actual_compiler_source=q['actual_compiler_source'], actual_observer_source=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=R).decode().strip(),
                  actual_BUILD_sha256=q['actual_BUILD_sha256'], kind=q['kind'], optimization=q['optimization'], days=35, warm=proof, cold=cold,
                  actual_original_constitutive_observations=sum(len(rows) for rows in sample['observations_by_layer'].values()),
                  maximum_original_theta_stock_difference_cm=sample['maximum_original_theta_stock_difference_cm'], decimal_global_maximum_absolute_residual_cm=str(peak),
                  absolute_water_limit_cm='1e-10', original_parameter_bytes_verified=True, model_executions=0, compiler_executions=0, canonical_admission=False)
    return record


def main():
    parser = argparse.ArgumentParser()
    for key in ('profile', 'reference-samples', 'output'):
        parser.add_argument('--' + key, type=Path, required=True)
    args = parser.parse_args()
    record = audit_profile(args.profile, args.reference_samples)
    with args.output.open('x') as stream:
        json.dump(record, stream, indent=2)
    print(record['status'], record['kind'], record['optimization'], record['decimal_global_maximum_absolute_residual_cm'])


if __name__ == '__main__':
    main()

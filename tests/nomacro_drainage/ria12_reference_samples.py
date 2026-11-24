"""Measure complete original RIA/TTUTIL at actual heads without a model period."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import re
import subprocess

R = Path(__file__).resolve().parents[2]
SHA = lambda raw: hashlib.sha256(raw).hexdigest()
ORIGINAL_RIA = '454b3949827917ce0ca32ce044e6368faffbf6c4c14266f1f969c2e3b038a01a'


def main():
    parser = argparse.ArgumentParser()
    for name in ('profile', 'reference-work', 'output'):
        parser.add_argument('--' + name, type=Path, required=True)
    parser.add_argument('--build-root', type=Path)
    parser.add_argument('--reuse-component', type=Path)
    args = parser.parse_args()
    assert (args.build_root is None) != (args.reuse_component is None)
    git = lambda *a: subprocess.check_output(['git', *a], cwd=R)
    head = git('rev-parse', 'HEAD').decode().strip()
    assert not git('status', '--porcelain=v1', '--untracked-files=all', '--', 'app', 'src', 'tools', 'tests', 'reference', '.github')
    args.output.mkdir()
    profile_raw = (args.profile / 'RESULT.json').read_bytes()
    q = json.loads(profile_raw)
    bundle = Path(q['build_root'])
    meta = json.loads((bundle / 'BUILD.json').read_text())
    assert SHA((bundle / 'BUILD.json').read_bytes()) == q['actual_BUILD_sha256']
    assert meta['identity']['original_output']['original_ria12']['models'] == [12, 12]
    inputs = Path(q['input_root'])
    actual_input = inputs / 'swap.swp'
    assert SHA(actual_input.read_bytes()) == meta['inputs']['swap.swp']
    driver = R / 'tests/nomacro_drainage/ria12_reference_probe.f90'
    assert driver.read_bytes().replace(b'\r\n', b'\n') == git('show', 'HEAD:tests/nomacro_drainage/ria12_reference_probe.f90')
    source = args.reference_work / 'build/swap-selected/MOD_RIA.f90'
    original_raw = source.read_bytes()
    assert SHA(original_raw.replace(b'\r\n', b'\n')) == ORIGINAL_RIA
    library = args.reference_work / 'build/ttutil-obj/libttutil.a'
    base_source = args.reference_work / 'build/swap-selected/swap_base.f90'
    if args.reuse_component:
        component_root = args.reuse_component
        component = json.loads((component_root / 'COMPONENT.json').read_text())
        assert component['optimization'] == q['optimization'] and component['original_RIA_lf_sha256'] == ORIGINAL_RIA
        assert component['driver_raw_sha256'] == SHA(driver.read_bytes()) and component['TTUTIL_library_sha256'] == SHA(library.read_bytes())
        assert SHA((component_root / 'MOD_RIA.f90').read_bytes()) == component['original_RIA_raw_sha256']
        assert SHA((component_root / 'swap_base.f90').read_bytes()) == component['original_swap_base_raw_sha256'] == SHA(base_source.read_bytes())
    else:
        component_root = args.build_root
        component_root.mkdir(parents=True, exist_ok=True)
        assert not any(component_root.iterdir()), 'Component allocation must be empty'
        (component_root / 'MOD_RIA.f90').write_bytes(original_raw)
        (component_root / 'swap_base.f90').write_bytes(base_source.read_bytes())
        (component_root / driver.name).write_bytes(driver.read_bytes())
        flags = ['-' + q['optimization'], '-ffree-line-length-none', '-fallow-argument-mismatch', '-finit-local-zero', '-ffp-contract=off', '-march=x86-64', '-mtune=generic', '-ffunction-sections', '-fdata-sections']
        includes = ['-J.', '-I.', '-I' + str(args.reference_work / 'build/swap-obj'), '-I' + str(args.reference_work / 'build/ttutil-obj')]
        executable = 'original_ria12_probe.exe' if __import__('os').name == 'nt' else 'original_ria12_probe'
        commands = [
            ['gfortran', *flags, *includes, '-c', 'swap_base.f90', '-o', 'swap_base.o'],
            ['gfortran', *flags, *includes, '-c', 'MOD_RIA.f90', '-o', 'MOD_RIA.o'],
            ['gfortran', *flags, *includes, '-c', driver.name, '-o', 'probe.o'],
            ['gfortran', *flags, '-Wl,--gc-sections', 'swap_base.o', 'MOD_RIA.o', 'probe.o', str(library), '-o', executable],
        ]
        compiler = []
        for index, command in enumerate(commands):
            with (component_root / f'compile-{index}.stdout').open('xb') as out, (component_root / f'compile-{index}.stderr').open('xb') as err:
                result = subprocess.run(command, cwd=component_root, stdout=out, stderr=err, timeout=60)
            compiler.append(dict(command=command, returncode=result.returncode))
            result.check_returncode()
        component = dict(status='COMPLETE_ORIGINAL_RIA_AND_TTUTIL_COMPONENT_BUILT_NO_MODEL', actual_source=head, optimization=q['optimization'],
                         original_RIA_lf_sha256=ORIGINAL_RIA, original_RIA_raw_sha256=SHA(original_raw), driver_raw_sha256=SHA(driver.read_bytes()),
                         TTUTIL_library_sha256=SHA(library.read_bytes()), executable=executable, executable_sha256=SHA((component_root / executable).read_bytes()),
                         original_swap_base_raw_sha256=SHA(base_source.read_bytes()),
                         shared_runtime_dependency='Complete original RIA junction initialization uses original MOD_swap_base.unit_log; compile complete original swap_base and discard unused sections. No replacement physics or module stubs.',
                         compiler=compiler, model_periods=0)
        (component_root / 'COMPONENT.json').write_text(json.dumps(component, indent=2) + '\n')
    assert SHA((component_root / component['executable']).read_bytes()) == component['executable_sha256']
    daily_raw = (args.profile / 'trajectory/daily.jsonl').read_bytes()
    data = [json.loads(line) for line in daily_raw.splitlines()]
    heads = sorted({value for row in data for value in row['pressure_head_cm']})
    heads_path = args.output / 'actual-heads.txt'
    heads_path.write_text(str(len(heads)) + '\n' + ''.join(format(value, '.17g') + '\n' for value in heads))
    parameters = args.output / 'original-parameters.bin'
    command = [str(component_root / component['executable']), str(actual_input), str(heads_path), str(parameters)]
    with (args.output / 'sample.stdout').open('xb') as out, (args.output / 'sample.stderr').open('xb') as err:
        result = subprocess.run(command, cwd=args.output, stdout=out, stderr=err, timeout=90)
    result.check_returncode()
    assert not (args.output / 'sample.stderr').read_bytes()
    observed = {}
    for line in (args.output / 'sample.stdout').read_text().splitlines():
        if not line.startswith('ACTUAL_ORIGINAL_RIA12_SAMPLE '):
            continue
        fields = line.split()
        model, layer, index = map(int, fields[1:4])
        values = list(map(float, fields[4:]))
        assert len(fields) == 10 and model == 12 and layer in (1, 2) and 1 <= index <= len(heads)
        assert values[0] == heads[index - 1] and all(map(math.isfinite, values)) and min(values[1:5]) >= 0 and values[5] == 0 and values[3] == values[4]
        assert (layer, index) not in observed
        observed[layer, index] = values
    assert len(observed) == 2 * len(heads)
    table = re.search(r'(?mi)^\s*ISUBLAY\s+ISOILLAY\s+HSUBLAY\s+NCOMP\s*\n(.*?)^\* End of table', actual_input.read_text(encoding='cp1252'), re.S)
    assert table
    layers, dz = [], []
    for line in table[1].splitlines():
        fields = line.split('!')[0].split()
        if fields:
            assert len(fields) == 4
            count = int(fields[3])
            layers.extend([int(fields[1])] * count)
            dz.extend([float(fields[2]) / count] * count)
    assert len(layers) == len(dz) == meta['project']['nodes']
    lookup = {layer: {heads[i - 1]: observed[layer, i] for i in range(1, len(heads) + 1)} for layer in (1, 2)}
    errors = []
    for row in data:
        stock = math.fsum(lookup[layer][pressure][1] * height for layer, pressure, height in zip(layers, row['pressure_head_cm'], dz))
        error = abs(stock - row['stock_end_cm'][0])
        assert error <= 1e-10
        errors.append(error)
    from ria12_native import native
    import zipfile
    for row in data:
        path = args.profile / f"trajectory/accepted-column-1-day-{row['day']}.zip"
        if path.is_file():
            with zipfile.ZipFile(path) as z:
                native(z.read('macro.bin'), row, meta, parameters.read_bytes())
    assert git('rev-parse', 'HEAD').decode().strip() == head
    record = dict(status='COMPLETE_ORIGINAL_RIA_TTUTIL_ALL_ACTUAL_HEADS_STOCK_AND_NATIVE_PARAMETER_BYTES_PASS_NO_MODEL_PERIOD', actual_source=head,
                  actual_model_producer=q['source'], profile_RESULT_sha256=SHA(profile_raw), daily_sha256=SHA(daily_raw), actual_soil_input_sha256=SHA(actual_input.read_bytes()),
                  optimization=q['optimization'], component_root=str(component_root), component=component, heads=heads,
                  observations_by_layer={str(layer): [observed[layer, i] for i in range(1, len(heads) + 1)] for layer in (1, 2)},
                  maximum_original_theta_stock_difference_cm=max(errors), original_parameter_bytes_sha256=SHA(parameters.read_bytes()),
                  stdout_sha256=SHA((args.output / 'sample.stdout').read_bytes()), head_input_sha256=SHA(heads_path.read_bytes()), model_periods=0, canonical_admission=False)
    (args.output / 'RESULT.json').write_text(json.dumps(record, indent=2) + '\n')
    print(record['status'], q['optimization'], len(observed), max(errors))


if __name__ == '__main__':
    main()

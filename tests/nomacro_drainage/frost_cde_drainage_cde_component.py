"""Real FrozenCond -> FrozenBounds -> corrected Divdra -> Solute_CDE(2).

This component qualifies the nodal rate/chemical receipt seam only. It does not
execute or qualify a coupled model period, restart, or public admission domain.
"""
import argparse
from decimal import Decimal, localcontext
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]


def audit(stdout):
    rows = [s.split() for s in stdout.splitlines() if s.startswith('ACTUAL_FROST_CDE_TASK2 ')]
    assert len(rows) == 252
    worst = Decimal(0)
    with localcontext() as ctx:
        ctx.prec = 80
        for index, row in enumerate(rows, 1):
            case, levels = map(int, row[1:3])
            assert case == index and levels in (1, 2)
            values = list(map(Decimal, row[3:]))
            assert len(values) == 26 + 4 * levels and all(x.is_finite() for x in values)
            exponent, dt, qbot, initial, final, drain, idrain, bottom, ibottom, balance = values[:10]
            assert exponent in (Decimal('.5'), Decimal(1), Decimal(2))
            before, concentration, after = values[10:14], values[14:18], values[18:22]
            node_rates = values[26:]
            # Independent physical face flux integral, using emitted actual
            # nodal rates and pre-step concentrations, not production CDRTOT.
            expected_drain = sum(node_rates[cell * levels + level] *
                (concentration[cell] if node_rates[cell * levels + level] > 0 else Decimal('.007')) * dt
                for cell in range(4) for level in range(levels))
            expected_bottom = qbot * (Decimal('.011') if qbot > 0 else concentration[3]) * dt
            thickness = list(map(Decimal, (10, 20, 40, 60)))
            checks = [drain - expected_drain, idrain - expected_drain,
                bottom - expected_bottom, ibottom - expected_bottom,
                final - initial + drain - bottom, balance,
                initial - sum(m * d for m, d in zip(before, thickness)),
                final - sum(m * d for m, d in zip(after, thickness))]
            for cell in range(4):
                lateral = sum(node_rates[cell * levels + level] *
                    (concentration[cell] if node_rates[cell * levels + level] > 0 else Decimal('.007')) * dt
                    for level in range(levels))
                checks.append((after[cell] - before[cell]) * thickness[cell] + lateral -
                    (expected_bottom if cell == 3 else 0))
            worst = max(worst, *map(abs, checks))
            assert all(abs(x) <= Decimal('1e-10') for x in checks), (case, checks)
    return dict(cases=len(rows), independent_decimal_budget_max_abs=str(worst))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('reference-work', 'build-root', 'output'):
        parser.add_argument('--' + name, type=Path, required=True)
    parser.add_argument('--optimization', choices=('O0', 'O2'), required=True)
    args = parser.parse_args()
    args.output.mkdir(); args.build_root.mkdir(exist_ok=True)
    sys.path.insert(0, str(ROOT / 'app/hybrid_water'))
    import user_prepare
    import frost_reference
    import frost_divdra_overlap
    import snow_undrained_cde_positive
    import frost_cde_drainage_cde_probe as probe
    import frost_cde_drainage_cde_driver as driver_builder
    from daily_host import NO_MACRO_FP_FLAGS, no_macro_fp_profile
    sha = lambda raw: hashlib.sha256(raw).hexdigest()
    record = dict(status='RUNNING', source=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
        optimization=args.optimization, executions=[], model_periods=0, canonical_admission=False,
        reference_correction='FROST-DIVDRA-OVERLAP-01', floating_point_profile=no_macro_fp_profile())
    def save():
        (args.output / 'RESULT.json').write_text(json.dumps(record, indent=2) + '\n', encoding='utf-8')
    def run(command, cwd):
        return subprocess.run(command, cwd=cwd, capture_output=True, text=True, timeout=60)
    save()
    try:
        user_prepare.validate(args.reference_work)
        ref = args.reference_work / 'build'; objects = ref / 'swap-obj'
        files = sorted(p for p in objects.glob('*.o') if p.name != 'swap_main.o')
        def symbols(flag):
            result = run(['nm', '-g', flag, '--format=posix', *map(str, files)], args.build_root)
            result.check_returncode(); table = {}; current = None
            for line in result.stdout.splitlines():
                if line.endswith(':'):
                    current = Path(line[:-1]); table[current] = set(); continue
                if current is not None and line.strip(): table[current].add(line.split()[0])
            assert set(table) == set(files)
            return table
        defined, undefined = symbols('--defined-only'), symbols('--undefined-only')
        lookup = {}
        for path, names in defined.items():
            for name in names: lookup.setdefault(name, path)
        selected = {objects / 'frozencond.o', objects / 'solute.o'}
        while True:
            before = set(selected)
            for path in before: selected.update(lookup[s] for s in undefined[path] if s in lookup)
            if before == selected: break
        raw = {name: (ref / 'swap-selected' / (name + '.f90')).read_bytes()
               for name in ('frozencond', 'divdra', 'solute')}
        divdra = frost_divdra_overlap.source(raw['divdra'])
        solute = raw['solute'].decode('cp1252').replace('\r\n', '\n')
        driver = driver_builder.source(Path(__file__).with_name('frost_cde_drainage_rates_driver.f90').read_text())
        (args.output / 'actual-driver.f90').write_text(driver, encoding='utf-8')
        record.update(original_source_sha256={k: sha(v) for k, v in raw.items()},
            original_object_closure=[dict(name=p.name, sha256=sha(p.read_bytes())) for p in sorted(selected)],
            ttutil_sha256=sha((ref / 'ttutil-obj/libttutil.a').read_bytes()),
            verification='Private task97 initializes explicit fixture only. Entire Solute_CDE(2) and drain collection remain literal; probe insertion has exact whole-file inverse.')
        outputs = {}
        for mode in ('original', 'guarded'):
            build = args.build_root / mode; build.mkdir()
            frost = raw['frozencond'] if mode == 'original' else frost_reference.source(raw['frozencond'])
            actual_cde = solute if mode == 'original' else snow_undrained_cde_positive.source(solute)
            sources = dict(frozencond=frost, divdra=divdra.encode('cp1252'), solute=probe.source(actual_cde).encode('cp1252'))
            flags = ['gfortran', '-' + args.optimization, '-cpp', '-ffree-line-length-none', '-fcheck=all',
                '-fimplicit-none', '-finit-local-zero', '-ffpe-trap=invalid,zero,overflow', *NO_MACRO_FP_FLAGS,
                '-I' + str(build), '-I' + str(objects), '-I' + str(ref / 'ttutil-obj'), '-J' + str(build)]
            if mode == 'guarded': flags.append('-DGUARDED')
            commands = []; compiled = []
            for name, body in sources.items():
                path = build / (name + '.f90'); path.write_bytes(body)
                (args.output / (mode + '-' + path.name)).write_bytes(body)
                obj = build / (name + '.o'); compiled.append(obj)
                commands.append([*flags, '-c', str(path), '-o', str(obj)])
            path = build / 'driver.f90'; path.write_text(driver, encoding='utf-8')
            exe = build / ('actual-frost-cde' + ('.exe' if os.name == 'nt' else ''))
            unchanged = selected - {objects / (name + '.o') for name in sources}
            commands.append([*flags, str(path), *map(str, compiled), *map(str, sorted(unchanged)),
                str(ref / 'ttutil-obj/libttutil.a'), '-o', str(exe)])
            logs = []
            for command in commands:
                start = time.perf_counter(); result = run(command, build)
                logs.append(dict(command=command, returncode=result.returncode, seconds=time.perf_counter()-start,
                    stdout=result.stdout, stderr=result.stderr))
                (args.output / (mode + '-compile.json')).write_text(json.dumps(logs, indent=2) + '\n', encoding='utf-8')
                result.check_returncode()
            (args.output / (mode + '-' + exe.name)).write_bytes(exe.read_bytes())
            start = time.perf_counter(); result = run([str(exe)], build)
            observation = dict(mode=mode, returncode=result.returncode, native_seconds=time.perf_counter()-start,
                executable_sha256=sha(exe.read_bytes()), actual_source_sha256={k: sha(v) for k, v in sources.items()},
                stdout=result.stdout, stderr=result.stderr)
            record['executions'].append(observation); save(); result.check_returncode()
            assert not result.stderr
            observation['independent_budget'] = audit(result.stdout)
            outputs[mode] = result.stdout
        assert outputs['original'] == outputs['guarded'], 'Unclipped original CDE production seam changed'
        record['status'] = 'ACTUAL_FROST_CORRECTED_DIVDRA_CDE_TASK2_252_CASES_PASS_NOT_MODEL_QUALIFIED'
        print(record['status'], len(selected), flush=True)
    except Exception as error:
        record.update(status='FAILED', error=repr(error)); raise
    finally:
        save()


if __name__ == '__main__':
    main()

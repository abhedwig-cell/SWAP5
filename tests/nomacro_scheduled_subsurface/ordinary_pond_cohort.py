"""Representative ordinary compositions; reuse literal original producers.

Six means, three lower boundaries, history0/1/2, water/CDE and original
calendar modes share one numerical work unit. CDE full uses sparse reporting;
the separate weighted-water full already covers dense per-step output.
"""
import argparse
import json
from pathlib import Path
import subprocess
import sys
import time

import implicit_conductivity_runtime as original

m, ROOT = original.m, original.ROOT
CASES = (
    ('water-groundwater', 0, 0, 1, 1, False, 'periodic', 2, 0, 1),
    ('water-history1-head', 0, 1, 5, 2, True, 'explicit', 3, 1, 3),
    ('cde-plate-history', 1, 2, 8, 3, False, 'periodic', 3, 1, 3),
    ('cde-groundwater-history', 1, 2, 1, 4, False, 'periodic', 3, 1, 3),
    ('water-plate', 0, 0, 8, 5, False, 'monthly', 2, 1, 1),
    ('cde-head-history1', 1, 1, 5, 6, True, 'explicit', 3, 1, 3),
)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for key in ('reference-work', 'build-root', 'output'):
        parser.add_argument('--'+key, type=Path, required=True)
    parser.add_argument('--optimization', choices=('O0', 'O2'), required=True)
    parser.add_argument('--phase', choices=('short', 'cde-full'), default='short')
    parser.add_argument('--reuse-case', type=Path)
    parser.add_argument('--full-cap', type=int, choices=(180, 600), default=180)
    args = parser.parse_args()
    args.output.mkdir()
    record = dict(status='RUNNING', controller_source=subprocess.check_output(
        ['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
        parameters={k: str(v) if isinstance(v, Path) else v for k, v in vars(args).items()},
        functional_completion='PARTIAL', whole_scientific_equivalence='NOT_QUALIFIED',
        canonical_admission=False, cases={})
    def save():
        (args.output/'RESULT.json').write_text(json.dumps(record, indent=2)+'\n', encoding='utf-8')
    def execute(parent, label, command):
        started = time.monotonic()
        with (parent/(label+'.stdout')).open('w') as out, (parent/(label+'.stderr')).open('w') as err:
            result = subprocess.run(command, cwd=ROOT, stdout=out, stderr=err, timeout=240)
        observation = dict(command=command, returncode=result.returncode, seconds=time.monotonic()-started)
        record['last_execution'] = observation
        save()
        result.check_returncode()
        return observation
    save()
    try:
        if args.phase == 'short':
            for name, solute, history, bottom, mean, step, mode, fmt, reset, npd in CASES:
                out = args.output/name
                out.mkdir()
                inputs, build = out/'input', args.build_root/name/'bundle'
                original.fixture(inputs, solute, history, bottom, step, mean, mode, fmt, reset, npd)
                project = m.e.load(inputs, original_output=True)
                item = record['cases'][name] = dict(input_root=str(inputs), build_root=str(build))
                save()
                item['build'] = execute(out, 'build', [sys.executable, '-B', str(ROOT/'tools/solute/run_water.py'),
                    '--model', project.model, '--experimental-project', str(inputs), '--original-output',
                    '--reference-work', str(args.reference_work), '--build-only', '--donor-opt', args.optimization,
                    '--kernel-opt', args.optimization, '--output', str(build)])
                save()
                command = [sys.executable, '-B', str(Path(original.__file__)), '--reference-work', str(args.reference_work),
                    '--output', str(out/'short'), '--optimization', args.optimization, '--solute', str(solute),
                    '--hysteresis', str(history), '--bottom', str(bottom), '--kmean', str(mean), '--mode', mode,
                    '--format', str(fmt), '--reset', str(reset), '--nprintday', str(npd),
                    '--reuse-build', str(build), '--existing-input', str(inputs)]
                if step:
                    command.append('--perstep')
                item['short'] = execute(out, 'short', command)
                save()
            record['status'] = 'ACTUAL_SIX_ORDINARY_POND_COMPOSITIONS_SHORT_NATIVE_PASS'
        else:
            assert args.reuse_case
            short = json.loads((args.reuse_case/'short/RESULT.json').read_text(encoding='utf-8'))
            assert short['status'] == 'ACTUAL_ORIGINAL_IMPLICIT_CONDUCTIVITY_SHORT_PHYSICAL_COMPLETE_NATIVE_OUTPUT_PASS'
            fields = ('solute', 'hysteresis', 'bottom', 'kmean', 'perstep', 'mode', 'format', 'reset', 'nprintday')
            assert tuple(short['parameters'][k] for k in fields) == (1, 2, 1, 4, False, 'periodic', 3, 1, 3)
            assert short['parameters']['optimization'] == args.optimization
            inputs, build = Path(short['input_root']), Path(short['build_root'])
            project = m.e.load(inputs, original_output=True)
            m.validate_bundle(build, args.reference_work, project)
            assert m.sha(build/'BUILD.json') == short['trajectory']['build_sha256']
            record.update(input_root=str(inputs), build_root=str(build), parameters=dict(short['parameters']),
                          reused_short_receipt_sha256=m.sha(args.reuse_case/'short/RESULT.json'),
                          fresh_compilations=0, fresh_short_models=0, full_resource_cap_seconds=args.full_cap)
            full = args.output/'full'
            full.mkdir()
            windows = [(2, 4), (7, 9), (30, 34), (163, 165), (199, 201),
                       (364, 367), (530, 532), (1094, 1096)]
            save()
            record['full'], data = m.trajectory(build, args.reference_work, project,
                full/'trajectory', 1096, {1096, *(v for pair in windows for v in pair)}, args.full_cap)
            record['cold'] = []
            save()
            for start, end in windows:
                record['cold'].append(original.previous.own(build, args.reference_work, project,
                    full/'trajectory', data, start, end, full/f'own-{start}'))
                save()
            record['status'] = 'ACTUAL_ORDINARY_CONTINUOUS_POND_SOURCE_PHYSICAL_NATIVE_PASS'
    except Exception as error:
        record.update(status='FAILED_OR_CENSORED', error=repr(error))
        raise
    finally:
        save()
    print(record['status'])


if __name__ == '__main__':
    main()

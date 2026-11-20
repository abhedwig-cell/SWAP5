"""Current ordinary implicit reference correction, short before bounded full.

Keep the original 180-second model cap and literal prior physical/native readers.
The existing donor, kernel, checkpoint and conservation owners remain in charge.
"""
import argparse
import json
import subprocess
import sys
import time
from pathlib import Path

import implicit_conductivity_runtime as original

m = original.m
ROOT = original.ROOT


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for key in ('reference-work', 'build-root', 'output'):
        parser.add_argument('--'+key, type=Path, required=True)
    parser.add_argument('--optimization', choices=('O0', 'O2'), required=True)
    parser.add_argument('--solute', type=int, choices=(0, 1), default=0)
    parser.add_argument('--hysteresis', type=int, choices=(0, 1, 2), default=2)
    parser.add_argument('--kmean', type=int, choices=range(1, 7), default=6)
    parser.add_argument('--bottom', type=int, choices=(1, 5, 8), default=5)
    parser.add_argument('--short-only', action='store_true')
    args = parser.parse_args()
    args.output.mkdir()
    inputs = args.output/'input'
    original.fixture(inputs, args.solute, args.hysteresis, args.bottom, True, args.kmean)
    project = m.e.load(inputs, original_output=True)
    build = args.build_root/'bundle'
    record = dict(status='RUNNING', controller_source=subprocess.check_output(
        ['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
        parameters={k: str(v) if isinstance(v, Path) else v for k, v in vars(args).items()},
        build_root=str(build), input_root=str(inputs), functional_completion='PARTIAL',
        whole_scientific_equivalence='NOT_QUALIFIED', canonical_admission=False)
    def save():
        (args.output/'RESULT.json').write_text(json.dumps(record, indent=2)+'\n')
    def execute(label, command):
        clock = time.monotonic()
        with (args.output/(label+'.stdout')).open('w') as out, (args.output/(label+'.stderr')).open('w') as err:
            result = subprocess.run(command, cwd=ROOT, stdout=out, stderr=err, timeout=240)
        record[label] = dict(returncode=result.returncode, seconds=time.monotonic()-clock, command=command)
        save()
        result.check_returncode()
    save()
    try:
        execute('build', [sys.executable, '-B', str(ROOT/'tools/solute/run_water.py'),
            '--model', project.model, '--experimental-project', str(inputs), '--original-output',
            '--reference-work', str(args.reference_work), '--build-only', '--donor-opt', args.optimization,
            '--kernel-opt', args.optimization, '--output', str(build)])
        execute('short', [sys.executable, '-B', str(Path(original.__file__)),
            '--reference-work', str(args.reference_work), '--output', str(args.output/'short'),
            '--optimization', args.optimization, '--solute', str(args.solute), '--hysteresis', str(args.hysteresis),
            '--bottom', str(args.bottom), '--kmean', str(args.kmean), '--perstep',
            '--reuse-build', str(build), '--existing-input', str(inputs)])
        if not args.short_only:
            full = args.output/'full'
            full.mkdir()
            windows = [(2, 4), (7, 9), (30, 34), (163, 165), (199, 201),
                       (364, 367), (530, 532), (1094, 1096)]
            record['full'], data = m.trajectory(build, args.reference_work, project,
                full/'trajectory', 1096, {1096, *(v for pair in windows for v in pair)}, 180)
            save()
            record['cold'] = []
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

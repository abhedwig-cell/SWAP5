#!/usr/bin/env python3
"""Run the fresh study sequentially, retaining expected native failures as failures."""
import argparse
import json
from pathlib import Path
import re
import shlex
import subprocess
import os

ROOT = Path(__file__).resolve().parents[2]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--results', type=Path, required=True)
    parser.add_argument('--capsule', type=Path, help='Persist and verify raw evidence after all native runs finish')
    args = parser.parse_args()
    root = args.results.resolve()
    build = json.loads((root/'build-O2/build-complete.json').read_text())
    environment = {**os.environ, 'FC': shlex.join(build['compiler_command'])}
    receipt = {'fresh_reexecution': True, 'production_source_baseline': build['candidate'], 'steps': []}

    def run(label, command, expected_failure=False):
        with (root/(label+'.log')).open('w') as log:
            process = subprocess.run(command, cwd=ROOT, env=environment, stdout=log, stderr=log)
        entry = {'label': label, 'command': command, 'exit': process.returncode}
        receipt['steps'].append(entry)
        (root/'PIPELINE.json').write_text(json.dumps(receipt, indent=2)+'\n')
        print(label, process.returncode, flush=True)
        if expected_failure:
            native = root/label/'dry32/1e-06-on-0/stdout'
            text = native.read_text() if native.exists() else ''
            gap = re.search(r'ENDPOINT_GAP\s+(\S+)', text)
            if (process.returncode == 0 or not re.search(r'joint status/water/chemical:\s+3\s+0\s+1', text)
                    or not gap or not 0 < float(gap[1]) < 1e-14
                    or not re.search(r'COMMITTED_WATER_CLOCK\s+0\.0+\s+T', text)
                    or not re.search(r'COMMITTED_CHEMICAL_CLOCK\s+0\.0+\s+CHEMICAL_STEPS\s+0', text)):
                raise RuntimeError('different failure than the declared strict-endpoint reproducer: '+label)
            entry['expected_failure_reproduced_not_native_pass'] = True
        elif process.returncode:
            raise RuntimeError('unexpected diagnostic failure: '+label)
        (root/'PIPELINE.json').write_text(json.dumps(receipt, indent=2)+'\n')

    run('build-O0', ['python', 'tools/solute/build_column.py', '--optimization', 'O0',
                     '--build-profile', 'checked', '--output', str(root/'build-O0')])
    driver = ['python', 'tools/performance/study_perf01_temporal.py']
    scenarios = [
        ('temporal-fresh-O2', 'O2', ['--cases', 'pond4', 'pond32', 'pond256', 'pulse4']),
        ('temporal-fresh-O2-dry-control', 'O2', ['--cases', 'dry32', '--repeat', '1', '--tolerances', '1e-6', '2.5e-7']),
        ('temporal-fresh-O2-dry-snap', 'O2', ['--cases', 'dry32', '--snap-proposal-endpoint']),
        ('temporal-fresh-O2-snap-preservation', 'O2', ['--cases', 'pond4', 'pond32', 'pond256', 'pulse4',
            '--repeat', '1', '--tolerances', '1e-6', '2.5e-7', '--snap-proposal-endpoint']),
        ('temporal-fresh-O0-snap', 'O0', ['--repeat', '1', '--tolerances', '1e-6', '2.5e-7', '--snap-proposal-endpoint']),
        ('temporal-fresh-O0-dry-control', 'O0', ['--cases', 'dry32', '--repeat', '1', '--tolerances', '1e-6', '2.5e-7']),
    ]
    for label, opt, extra in scenarios:
        run(label, driver+['--build', str(root/('build-'+opt)), '--output', str(root/label)]+extra,
            expected_failure=label.endswith('dry-control'))
    receipt['status'] = 'FRESH_STUDY_COMPLETED_INCLUDING_TWO_EXPECTED_NATIVE_FAILURES_NO_PRODUCTION_ADMISSION'
    (root/'PIPELINE.json').write_text(json.dumps(receipt, indent=2)+'\n')
    if args.capsule:
        subprocess.run(['python', 'tools/performance/package_perf01_temporal.py', '--results', str(root),
                        '--output', str(args.capsule.resolve())], cwd=ROOT, check=True)


if __name__ == '__main__':
    main()

#!/usr/bin/env python3
"""Fresh compulsory shared-runtime owner and coupling science, unchanged gates."""
from pathlib import Path
import argparse
import hashlib
import json
import os
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tests/modularity'))
from joint_admission_authority import verify_source, git

STEPS = [
    ('source', ['python', '-B', 'tests/mc-met01/run_daily_demand_source.py']),
    ('reference', ['python', '-B', 'tests/mc-met01/run_daily_demand_reference_preservation.py']),
    ('heat-runtime', ['bash', 'tests/fmig431/run_mc_heat01_runtime.sh']),
    ('fkt22', ['bash', 'tests/fkt/run_fkt22_fmr_runtime_gate.sh']),
    ('boesten', ['bash', 'tests/fapp/run_ppa_wu04b_boesten_evaporation.sh']),
    ('macro-top', ['bash', 'tests/fpm/run_ppa_wu05a9_top_input.sh']),
    ('multiswap', ['bash', 'tests/fgc/run_fgc25_multiswap_groundwater_composition_gate.sh']),
    ('coupled-restart', ['bash', 'tests/fgc/run_fgc24_coupled_restart_split_process_gate.sh']),
    ('live-modflow', ['bash', 'tests/fgc/run_fgc49d_live_production_application_context.sh']),
    ('independent-application', ['bash', 'tests/fvq/run_fvq124_fgc49d_independent.sh']),
]


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--output', type=Path, required=True)
    ap.add_argument('--resume', action='store_true', help='Continue this live failed controller; verify every completed raw log')
    ap.add_argument('--coupling-python-path', type=Path, help='Exact workflow-pinned FloPy/xmipy installation for live MODFLOW only')
    ap.add_argument('--coupling-compiler-bin', type=Path, help='Separate PIC/shared-library compiler profile, never mixed with owning executables')
    args = ap.parse_args()
    source = verify_source()
    out = args.output.resolve()
    if args.resume:
        record = json.loads((out / 'RESULTS.json').read_text())
        assert record['status'] == 'FAIL' and record['source'] == source
        failed = record['steps'].pop()
        assert failed['exit'] != 0
        record.setdefault('failed_attempts', []).append(failed)
        for index, step in enumerate(record['steps']):
            assert step['exit'] == 0 and (step['name'], step['command']) == STEPS[index]
            assert hashlib.sha256((out / (step['name'] + '.stdout')).read_bytes()).hexdigest() == step['stdout_sha256']
        # Preserve the actual failure before the failed step's next execution.
        for suffix in ['stdout', 'stderr']:
            target = out / (failed['name'] + '.failed-' + str(len(record['failed_attempts'])) + '.' + suffix)
            target.write_bytes((out / (failed['name'] + '.' + suffix)).read_bytes())
        record['status'] = 'RUNNING'
    else:
        out.mkdir(parents=True, exist_ok=False)
        record = {'source': source, 'head': git('rev-parse', 'HEAD'), 'steps': [], 'status': 'RUNNING',
                  'scope': 'FRESH_SHARED_RUNTIME_OWNER_AND_COUPLING_NOT_FCI_ADMISSION'}
    start = time.monotonic()
    env = {**os.environ, 'PYTHONDONTWRITEBYTECODE': '1'}
    # Scope differs between these established original runners. No persistent
    # cache or result inheritance is introduced; each original case executes.
    for name, command in STEPS[len(record['steps']):]:
        begin = time.monotonic()
        print('START ' + name, flush=True)
        with (out / (name + '.stdout')).open('w') as stdout, (out / (name + '.stderr')).open('w') as stderr:
            step_env = dict(env)
            if name == 'boesten':
                # The admitted runner explicitly provides this preservation
                # mode. All static, physical, lifecycle and O0/O2 gates run;
                # the historical initial-admission Git delta is not re-claimed.
                step_env['WU04B_PRESERVATION_ONLY'] = '1'
            if name == 'live-modflow' and args.coupling_python_path:
                dependencies = args.coupling_python_path.resolve()
                commits = {json.loads(p.read_text())['vcs_info']['commit_id']
                           for p in dependencies.glob('*.dist-info/direct_url.json')}
                assert {'1a783da6582f8203190a8d6b1d7a60659022afdb',
                        '9769f8cd4bc6153c71bcc360f602a931b102d902'} <= commits
                step_env['PYTHONPATH'] = str(dependencies)
                record['coupling_python_inputs'] = {
                    'commits': sorted(commits),
                    'files': {str(p.relative_to(dependencies)): hashlib.sha256(p.read_bytes()).hexdigest()
                              for p in dependencies.rglob('*') if p.is_file() and p.suffix != '.pyc'},
                    'path': str(dependencies),
                }
            if name == 'live-modflow' and args.coupling_compiler_bin:
                directory = args.coupling_compiler_bin.resolve()
                compiler = directory / 'gfortran'
                assert compiler.is_file()
                step_env['PATH'] = str(directory) + os.pathsep + env['PATH']
                record['shared_library_compiler_profile'] = {
                    'launcher': str(compiler),
                    'launcher_sha256': hashlib.sha256(compiler.read_bytes()).hexdigest(),
                    'version': subprocess.check_output([str(compiler), '--version'], text=True),
                    'separate_from_owning_executable_profile': True,
                }
            if name == 'live-modflow':
                cp = subprocess.run(['python3', '-B', '-c', 'import flopy; from xmipy import XmiWrapper'],
                                    cwd=ROOT, env=step_env, stdout=stdout, stderr=stderr)
                if cp.returncode == 0:
                    cp = subprocess.run(command, cwd=ROOT, env=step_env, stdout=stdout, stderr=stderr)
            else:
                cp = subprocess.run(command, cwd=ROOT, env=step_env, stdout=stdout, stderr=stderr)
        record['steps'].append({'name': name, 'command': command, 'exit': cp.returncode,
                               'wall_seconds': time.monotonic() - begin,
                               'stdout_sha256': hashlib.sha256((out / (name + '.stdout')).read_bytes()).hexdigest()})
        (out / 'PROGRESS.json').write_text(json.dumps(record, indent=2) + '\n')
        if cp.returncode:
            record['status'] = 'FAIL'
            (out / 'RESULTS.json').write_text(json.dumps(record, indent=2) + '\n')
            raise RuntimeError('Original owner gate failed: ' + name)
        verify_source()
        print(name + '=PASS', flush=True)
    record['status'] = 'PASS'; record['wall_seconds'] = time.monotonic() - start
    record['command_wall_seconds'] = sum(s['wall_seconds'] for s in record['steps'])
    record['failed_command_wall_seconds'] = sum(s['wall_seconds'] for s in record.get('failed_attempts', []))
    (out / 'RESULTS.json').write_text(json.dumps(record, indent=2) + '\n')


if __name__ == '__main__':
    main()

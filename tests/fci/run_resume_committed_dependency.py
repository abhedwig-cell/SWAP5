#!/usr/bin/env python3
"""Reproduce or reject inheritance across an unaudited committed dependency."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import secrets
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument('--output', type=Path, required=True)
parser.add_argument('--controller-ref', required=True)
parser.add_argument('--toolchain-dirs', required=True)
parser.add_argument('--expect', choices=['unsafe-inherit', 'run'], required=True)
parser.add_argument('--dependency', choices=['committed-source', 'exported-function'],
                    default='committed-source')
args = parser.parse_args()
source = Path(__file__).resolve().parents[2]
out = args.output.resolve()
out.mkdir(exist_ok=False, parents=True)
root = out / 'checkout'
subprocess.run(['git', 'worktree', 'add', '--detach', str(root), 'HEAD'],
               cwd=source, check=True, capture_output=True)
controller = 'tools/fci/resume_group.py'
(root / controller).write_bytes(subprocess.check_output(
    ['git', 'show', args.controller_ref + ':' + controller], cwd=source))
runner = root / 'tests/frost/run_frost_invalid_input_preservation.sh'
fixture = root / 'tests/frost/resume-extra-input.txt'
fixture.write_text('first\n')
if args.dependency == 'committed-source':
    runner.write_bytes(runner.read_bytes() +
        b'\ntest "$(cat tests/frost/resume-extra-input.txt)" = first\n')
subprocess.run(['git', 'add', controller, 'tests/frost'], cwd=root, check=True)
subprocess.run(['git', '-c', 'user.name=F-CI trial', '-c',
               'user.email=fci-trial@example.invalid', 'commit', '-m',
               'Controlled committed runner with new external dependency'],
               cwd=root, check=True, capture_output=True)
key = out / 'key'
key.write_bytes(secrets.token_bytes(32))
key.chmod(0o600)
env = dict(os.environ, FCI_RESUME_KEY=str(key),
           FCI_RESUME_STORE=str(out / 'receipts'),
           FCI_RESUME_TOOLCHAIN_DIRS=args.toolchain_dirs)
if args.dependency == 'exported-function':
    env['BASH_FUNC_cmp%%'] = ('() { test "$(cat ' + str(fixture) +
                             ')" = first && command cmp "$@"; }')
command = ['python', controller, 'frost-invalid', 'bash', str(runner.relative_to(root))]
results = []
for name, mode in [('first', 'SHADOW'), ('changed-fixture', 'RESUME'), ('oracle-off', 'OFF')]:
    if name == 'changed-fixture':
        fixture.write_text('second\n')
    result = subprocess.run(command, cwd=root, env=dict(env, FCI_RESUME_MODE=mode),
                            capture_output=True)
    log = result.stdout + result.stderr
    (out / (name + '.log')).write_bytes(log)
    results.append({'case': name, 'exit_code': result.returncode,
                    'inherited': b'FCI_RESUME_INHERITED frost-invalid' in log,
                    'log_sha256': hashlib.sha256(log).hexdigest()})
assert results[0]['exit_code'] == 0
assert results[2]['exit_code'] == 1  # actual changed dependency fails original runner
if args.expect == 'unsafe-inherit':
    assert results[1]['inherited'] and results[1]['exit_code'] == 0
else:
    assert not results[1]['inherited'] and results[1]['exit_code'] == 1
    assert b'FCI_RESUME_RUN' in (out / 'changed-fixture.log').read_bytes()
report = {'controller_ref': args.controller_ref, 'expectation': args.expect,
          'dependency': args.dependency,
          'command': command, 'toolchain_dirs': args.toolchain_dirs,
          'results': results, 'reproducer_expectation_met': True}
(out / 'results.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps(report, indent=2))
subprocess.run(['git', 'worktree', 'remove', '--force', str(root)],
               cwd=source, check=True, capture_output=True)

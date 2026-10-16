#!/usr/bin/env python3
"""Capture read-only audited runtime manifests; never scientific PASS evidence."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument('--output', type=Path, required=True)
parser.add_argument('--toolchain-dirs', required=True)
args = parser.parse_args()
root = Path(__file__).resolve().parents[2]
out = args.output.resolve()
out.mkdir(parents=True, exist_ok=False)
results = []
for group, runner in [('frost-invalid', 'run_frost_invalid_input_preservation.sh'),
                      ('frost-independent', 'run_frost_nan_guard_independent.sh')]:
    command = ['python', 'tools/fci/resume_group.py', '--inspect-profile', group,
               'bash', 'tests/frost/' + runner]
    process = subprocess.run(command, cwd=root, capture_output=True,
        env=dict(os.environ, FCI_RESUME_TOOLCHAIN_DIRS=args.toolchain_dirs))
    (out / (group + '.stdout.json')).write_bytes(process.stdout)
    (out / (group + '.stderr')).write_bytes(process.stderr)
    assert process.returncode == 0, process.stderr
    manifest = json.loads(process.stdout)
    encoded = json.dumps(manifest['manifest'], sort_keys=True, separators=(',', ':'),
                         ensure_ascii=True).encode()
    assert hashlib.sha256(encoded).hexdigest() == manifest['fingerprint']
    assert b'=PASS' not in process.stdout and b'FCI_RESUME_INHERITED' not in process.stdout
    results.append({'group': group, 'command': command, 'exit_code': process.returncode,
                    'fingerprint': manifest['fingerprint'],
                    'manifest_stdout_sha256': hashlib.sha256(process.stdout).hexdigest(),
                    'tool_entries': len(manifest['manifest']['tools']),
                    'metadata_only': True})
assert results[0]['fingerprint'] == results[1]['fingerprint']
(out / 'results.json').write_text(json.dumps(results, indent=2) + '\n')
print(json.dumps(results, indent=2))

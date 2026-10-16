#!/usr/bin/env python3
"""Measured full current moving F-CI after the sealed joint owner prerequisite."""
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
from verify_joint_preservation import verify_qualification


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    source = verify_source(); verify_qualification()
    output = args.output.resolve(); output.mkdir(parents=True, mode=0o700, exist_ok=False)
    key = output / 'receipt.key'; key.write_bytes(os.urandom(32)); key.chmod(0o600)
    environment = {**os.environ, 'PYTHONDONTWRITEBYTECODE': '1', 'FCI_RESUME_MODE': 'SHADOW',
                   'FCI_RESUME_STORE': str(output / 'receipts'), 'FCI_RESUME_KEY': str(key)}
    command = ['bash', 'tests/fci/run_fci_canonical_p2e05_moving_preservation.sh']
    record = {'source': source, 'head': git('rev-parse', 'HEAD'), 'first_parent': git('rev-parse', 'HEAD^1'),
              'command': command, 'mode': 'SHADOW_ALL_SCIENTIFIC_GROUPS_EXECUTE',
              'environment_sha256': hashlib.sha256(json.dumps(environment, sort_keys=True).encode()).hexdigest(),
              'status': 'RUNNING', 'preserved': False, 'admitted': False}
    (output / 'PROGRESS.json').write_text(json.dumps(record, indent=2) + '\n')
    start = time.monotonic()
    with (output / 'stdout').open('w') as stdout, (output / 'stderr').open('w') as stderr:
        cp = subprocess.run(command, cwd=ROOT, env=environment, stdout=stdout, stderr=stderr)
    record.update({'exit': cp.returncode, 'wall_seconds': time.monotonic() - start,
                   'stdout_sha256': hashlib.sha256((output / 'stdout').read_bytes()).hexdigest(),
                   'stderr_sha256': hashlib.sha256((output / 'stderr').read_bytes()).hexdigest()})
    success = cp.returncode == 0 and 'FCI_CANONICAL_LINEAGE_AWARE_GATE PASS' in (output / 'stdout').read_text()
    record['status'] = 'PASS' if success else 'FAIL'; record['preserved'] = success
    (output / 'RESULTS.json').write_text(json.dumps(record, indent=2) + '\n')
    if not success:
        raise RuntimeError('Full moving preservation failed; raw evidence retained')
    verify_source()
    print('JOINT_FULL_MOVING_PRESERVATION=PASS')


if __name__ == '__main__':
    main()

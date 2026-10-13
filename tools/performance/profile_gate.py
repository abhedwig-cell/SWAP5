#!/usr/bin/env python3
"""Opt-in F-CI gate/compiler timing. Does not profile SWAP5 numerical solver time.

Example:
python3 tools/performance/profile_gate.py --output /tmp/owner-01.json -- bash tests/...sh
"""
import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time

# Do not start Python on every compiler request: startup overhead can exceed a
# short Fortran compile. GNU time captures one real compiler command per shim.
SHIM = """#!/bin/sh
stage=combined
for arg do
    if [ "$arg" = "-c" ]; then stage=compile; fi
done
exec /usr/bin/time -a -o "$SWAP_PROFILE_EVENTS" -f "${stage}\\t%e\\t%x" "$SWAP_PROFILE_REAL_GFORTRAN" "$@"
"""

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True)
    parser.add_argument('command', nargs=argparse.REMAINDER)
    args = parser.parse_args()
    command = args.command[1:] if args.command[:1] == ['--'] else args.command
    if not command:
        parser.error('command after -- is required')
    compiler = shutil.which('gfortran')
    if not compiler:
        parser.error('gfortran is unavailable')
    if not Path('/usr/bin/time').is_file():
        parser.error('GNU /usr/bin/time is required')
    report_path = Path(args.output).resolve()
    if report_path.exists():
        parser.error('output already exists; immutable measurement evidence is not overwritten')
    with tempfile.TemporaryDirectory(prefix='swap5-timing-') as td:
        shim = Path(td) / 'gfortran'
        shim.write_text(SHIM)
        shim.chmod(0o755)
        raw = Path(td) / 'compiler.tsv'
        env = os.environ.copy()
        env['PATH'] = td + os.pathsep + env.get('PATH', '')
        env['SWAP_PROFILE_EVENTS'] = str(raw)
        env['SWAP_PROFILE_REAL_GFORTRAN'] = str(Path(compiler).resolve())
        began = datetime.now(timezone.utc).isoformat()
        before = time.monotonic()
        try:
            code = subprocess.run(command, env=env).returncode
        except OSError as exc:
            print(f'gate launch failed: {exc}', file=sys.stderr)
            code = 127
        seconds = time.monotonic() - before
        records = []
        if raw.exists():
            for line in raw.read_text().splitlines():
                fields = line.split('\t')
                # GNU time emits a diagnostic line before its formatted
                # event on nonzero compiler exit. It is not an event.
                if line.startswith('Command exited with non-zero status '):
                    continue
                if len(fields) != 3:
                    parser.error(f'incomplete compiler event: {line!r}')
                stage, elapsed, status = fields
                if stage not in ('compile', 'combined'):
                    parser.error(f'unknown compiler event: {line!r}')
                records.append({'stage': stage, 'seconds': float(elapsed),
                                'returncode': int(status)})
    report = {
        'schema_version': 2, 'began_utc': began,
        'ended_utc': datetime.now(timezone.utc).isoformat(),
        'command': command, 'cwd': os.getcwd(),
        'compiler': str(Path(compiler).resolve()),
        'gate_returncode': code, 'gate_wall_seconds': seconds,
        'compiler_invocations': len(records),
        'compiler_seconds_sum': sum(row['seconds'] for row in records),
        'compiler_events': records,
        'limitations': [
            'Compiler timings have GNU time centisecond resolution.',
            'Only calls to PATH-resolved gfortran are intercepted.',
            'Compiler timings can overlap and are not a disjoint wall-time breakdown.',
            'Combined compilation/link invocations cannot be separated further.',
            'This does not measure SWAP5 numerical solver time.',
            'Measure unwrapped control too; wrapper perturbs execution.',
        ],
    }
    report_path.parent.mkdir(parents=True, exist_ok=True)
    with report_path.open('x') as handle:
        json.dump(report, handle, indent=2, sort_keys=True)
        handle.write('\n')
    print(f"gate_exit={code} wall_s={seconds:.3f} compiler_calls={len(records)} "
          f"compiler_s_sum={report['compiler_seconds_sum']:.3f} report={report_path}")
    return code

if __name__ == '__main__':
    sys.exit(main())

#!/usr/bin/env python3
"""Instrument gfortran invocations within one SWAP5 gate, without modifying source.

Usage: python3 tools/performance/profile_gate.py --output evidence.json -- bash tests/...sh
The residual wall time is NOT the model runtime.
"""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time
from datetime import datetime, timezone

WRAPPER = """#!/usr/bin/env python3
import json, os, subprocess, sys, time
start = time.monotonic_ns()
try:
    rc = subprocess.run([os.environ['SWAP_PROFILE_REAL_GFORTRAN'], *sys.argv[1:]]).returncode
except OSError:
    rc = 127
entry = {'kind': 'gfortran', 'duration_ns': time.monotonic_ns() - start,
         'returncode': rc, 'stage': 'compile' if '-c' in sys.argv[1:] else 'link_or_combined'}
fd = os.open(os.environ['SWAP_PROFILE_EVENTS'], os.O_WRONLY | os.O_CREAT | os.O_APPEND, 0o600)
try:
    os.write(fd, (json.dumps(entry, sort_keys=True) + '\\n').encode())
finally:
    os.close(fd)
sys.exit(rc)
"""

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True)
    parser.add_argument('command', nargs=argparse.REMAINDER)
    args = parser.parse_args()
    command = args.command[1:] if args.command[:1] == ['--'] else args.command
    if not command:
        parser.error('provide a command after --')
    real_compiler = shutil.which('gfortran')
    if not real_compiler:
        parser.error('gfortran not in PATH')
    real_compiler = str(Path(real_compiler).resolve())
    result_path = Path(args.output).resolve()
    if result_path.exists():
        parser.error('output exists; select a new path to preserve previous evidence')
    with tempfile.TemporaryDirectory(prefix='swap5-perf-') as temp:
        shim = Path(temp) / 'gfortran'
        shim.write_text(WRAPPER)
        shim.chmod(0o755)
        events = Path(temp) / 'compiler-events.jsonl'
        env = os.environ.copy()
        env['SWAP_PROFILE_REAL_GFORTRAN'] = real_compiler
        env['SWAP_PROFILE_EVENTS'] = str(events)
        env['PATH'] = temp + os.pathsep + env.get('PATH', '')
        started_utc = datetime.now(timezone.utc).isoformat()
        started = time.monotonic_ns()
        try:
            rc = subprocess.run(command, env=env).returncode
        except OSError as exc:
            rc = 127
            print(f'Could not launch gate: {exc}', file=sys.stderr)
        wall_ns = time.monotonic_ns() - started
        records = [json.loads(x) for x in events.read_text().splitlines()] if events.exists() else []
    compiler_sum = sum(r['duration_ns'] for r in records)
    result = {
        'schema_version': 1, 'started_utc': started_utc,
        'ended_utc': datetime.now(timezone.utc).isoformat(),
        'command': command, 'cwd': os.getcwd(), 'compiler_path': real_compiler,
        'gate_returncode': rc, 'wall_seconds': wall_ns / 1e9,
        'compiler_invocations': len(records),
        'compiler_compile_invocations': sum(r['stage'] == 'compile' for r in records),
        'compiler_link_or_combined_invocations': sum(r['stage'] != 'compile' for r in records),
        'compiler_invocation_seconds_sum': compiler_sum / 1e9,
        'compiler_events': records,
        'limits': ['Only PATH-resolved gfortran commands are intercepted.',
                   'Absolute compiler paths and nested PATH overrides are not covered.',
                   'Compiler seconds may overlap and must not be subtracted from gate wall time.',
                   'Residual time is not a measurement of physics/model runtime.',
                   'The wrapper adds overhead; compare against an unwrapped run.']}
    result_path.parent.mkdir(parents=True, exist_ok=True)
    with result_path.open('x') as out:
        json.dump(result, out, indent=2, sort_keys=True)
        out.write('\n')
    print(f"gate_exit={rc} wall_seconds={wall_ns / 1e9:.3f} compiler_invocations={len(records)} compiler_sum_seconds={compiler_sum / 1e9:.3f} evidence={result_path}")
    return rc

if __name__ == '__main__':
    sys.exit(main())

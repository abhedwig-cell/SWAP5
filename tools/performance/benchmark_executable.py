#!/usr/bin/env python3
"""Benchmark an already-built model executable independently of qualification overhead.

Example: python3 tools/performance/benchmark_executable.py --repeat 5 \
  --output /tmp/reference-richards.json -- ./build/reference_case input.dat
Run from an identical fixture directory with deterministic outputs. This measures
whole executable duration, NOT an isolated solver loop unless executable scope
is itself exactly the solver.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import resource
import subprocess
import sys
import time

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True)
    parser.add_argument('--repeat', type=int, default=3)
    parser.add_argument('command', nargs=argparse.REMAINDER)
    args = parser.parse_args()
    command = args.command[1:] if args.command[:1] == ['--'] else args.command
    if args.repeat < 1 or not command:
        parser.error('repeat must be positive and a command is required')
    target = Path(args.output).resolve()
    if target.exists():
        parser.error('refusing to overwrite existing measurement evidence')
    if not Path(command[0]).exists():
        parser.error('use an explicit executable path; executable does not exist')
    events = []
    for trial in range(args.repeat):
        cpu_before = resource.getrusage(resource.RUSAGE_CHILDREN)
        started = time.monotonic_ns()
        completed = subprocess.run(command, capture_output=True)
        elapsed = (time.monotonic_ns() - started) / 1e9
        cpu_after = resource.getrusage(resource.RUSAGE_CHILDREN)
        events.append({
            'trial': trial + 1, 'wall_seconds': elapsed,
            'user_cpu_seconds': cpu_after.ru_utime - cpu_before.ru_utime,
            'system_cpu_seconds': cpu_after.ru_stime - cpu_before.ru_stime,
            'exit_code': completed.returncode,
            'stdout_sha256': hashlib.sha256(completed.stdout).hexdigest(),
            'stderr_sha256': hashlib.sha256(completed.stderr).hexdigest(),
        })
        if completed.returncode != 0:
            break
    report = {
        'schema_version': 1, 'cwd': os.getcwd(), 'command': command,
        'executable_sha256': hashlib.sha256(Path(command[0]).read_bytes()).hexdigest(),
        'events': events,
        'warnings': [
            'Whole-executable timing, not isolated Richards solver timing.',
            'Restart, generated outputs and filesystem side effects may affect repeated trials.',
            'Compare only when numerical input, executable/compiler, hardware and state match.',
            'Output digests do not replace scientific field-by-field equivalence.',
        ],
    }
    target.parent.mkdir(parents=True, exist_ok=True)
    with target.open('x') as out:
        json.dump(report, out, indent=2, sort_keys=True)
        out.write('\n')
    print(f"Recorded {len(events)} trials in {target}")
    return events[-1]['exit_code']

if __name__ == '__main__':
    sys.exit(main())

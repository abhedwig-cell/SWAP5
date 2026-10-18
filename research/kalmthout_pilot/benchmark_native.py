#!/usr/bin/env python3
"""Measure one already compiled native command; compilation is excluded."""
import argparse
import hashlib
import json
import platform
import resource
import subprocess
import time
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('output', type=Path)
    parser.add_argument('--cwd', type=Path, default=Path.cwd())
    parser.add_argument('command', nargs=argparse.REMAINDER)
    args = parser.parse_args()
    command = args.command
    if command and command[0] == '--':
        command = command[1:]
    if not command:
        parser.error('native command required after --')
    executable = Path(command[0]).resolve()
    before = resource.getrusage(resource.RUSAGE_CHILDREN)
    start = time.perf_counter()
    with args.output.with_suffix('.stdout').open('wb') as stdout:
        with args.output.with_suffix('.stderr').open('wb') as stderr:
            result = subprocess.run(command, cwd=args.cwd, stdout=stdout, stderr=stderr)
    elapsed = time.perf_counter() - start
    after = resource.getrusage(resource.RUSAGE_CHILDREN)
    data = {
        'command': command, 'cwd': str(args.cwd.resolve()),
        'executable_sha256': hashlib.sha256(executable.read_bytes()).hexdigest(),
        'wall_seconds': elapsed, 'user_seconds': after.ru_utime - before.ru_utime,
        'system_seconds': after.ru_stime - before.ru_stime,
        'max_rss_kib': after.ru_maxrss, 'returncode': result.returncode,
        'machine': platform.machine(), 'platform': platform.platform(),
        'compile_seconds': None, 'scope': 'native execution with file I/O; single observation',
    }
    args.output.write_text(json.dumps(data, indent=2) + '\n')
    print(json.dumps(data))


if __name__ == '__main__':
    main()

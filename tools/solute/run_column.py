#!/usr/bin/env python3
"""Run a file-driven Reference solute column and publish a complete generation."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--exe', type=Path, required=True)
    parser.add_argument('--input', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--restart', type=Path, help='A complete earlier output directory')
    parser.add_argument('--stop-after', type=int, default=128, help='Last input window to execute')
    args = parser.parse_args()
    exe, source, output = args.exe.resolve(), args.input.resolve(), args.output.resolve()
    if output.exists():
        raise FileExistsError(f'output exists: {output}')
    if args.stop_after < 1:
        raise ValueError('stop-after must be positive')
    build_path = exe.parent / 'build.json'
    build = json.loads(build_path.read_text())
    if build.get('status') != 'BUILT' or build.get('executable_sha256') != sha(exe):
        raise ValueError('executable does not match its completed build')
    input_hash, exe_hash = sha(source), sha(exe)
    restart = None
    parent = None
    if args.restart:
        directory = args.restart.resolve()
        parent = json.loads((directory / 'manifest.json').read_text())
        if parent.get('schema') != 'SWAP5_SOLUTE_COLUMN_1' or parent.get('status') != 'COMPLETE':
            raise ValueError('restart generation incomplete')
        if parent.get('input_sha256') != input_hash or parent.get('executable_sha256') != exe_hash:
            raise ValueError('restart input or executable identity mismatch')
        if set(parent.get('files', {})) != {'input.nml', 'restart.bin', 'budget.csv', 'state.csv', 'endpoint.csv', 'stdout', 'stderr'}:
            raise ValueError('invalid restart manifest inventory')
        for name, expected in parent['files'].items():
            if sha(directory / name) != expected:
                raise ValueError(f'restart generation hash mismatch: {name}')
        if sha(directory / 'input.nml') != input_hash:
            raise ValueError('restart input binding mismatch')
        restart = directory / 'restart.bin'
    # Same-filesystem staging: interruption leaves the old generation intact.
    # The requested final output name exists only after every byte is durable.
    output.parent.mkdir(parents=True, exist_ok=True)
    stage = Path(tempfile.mkdtemp(prefix=output.name + '.pending-', dir=output.parent))
    staged_input = stage / 'input.nml'
    staged_input.write_bytes(source.read_bytes())
    if sha(staged_input) != input_hash:
        raise ValueError('input changed during staging')
    command = [str(exe), str(staged_input), str(restart) if restart else '-', str(args.stop_after)]
    start = time.perf_counter()
    result = subprocess.run(command, cwd=stage, capture_output=True)
    (stage / 'stdout').write_bytes(result.stdout)
    (stage / 'stderr').write_bytes(result.stderr)
    if result.returncode or b'SWAP5_SOLUTE_COLUMN_COMPLETED' not in result.stdout:
        raise RuntimeError(f'column failed with exit {result.returncode}; diagnostics: {stage}')
    files = {name: sha(stage / name) for name in
             ['input.nml', 'restart.bin', 'budget.csv', 'state.csv', 'endpoint.csv', 'stdout', 'stderr']}
    manifest = {'schema': 'SWAP5_SOLUTE_COLUMN_1', 'status': 'COMPLETE', 'input_sha256': input_hash,
                'executable_sha256': exe_hash, 'build_candidate': build['candidate'],
                'build_input_sha256': build['input_sha256'], 'compiler': build['compiler'], 'flags': build['flags'],
                'stop_after': args.stop_after, 'returncode': result.returncode,
                'native_seconds': time.perf_counter() - start,
                'parent_restart_sha256': parent['files']['restart.bin'] if parent else None, 'files': files}
    (stage / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    for path in stage.iterdir():
        with path.open('rb') as stream:
            os.fsync(stream.fileno())
    fd = os.open(stage, os.O_RDONLY | os.O_DIRECTORY)
    try:
        os.fsync(fd)
    finally:
        os.close(fd)
    # rename rather than replace: an existing nonempty result cannot be replaced.
    os.rename(stage, output)
    fd = os.open(output.parent, os.O_RDONLY | os.O_DIRECTORY)
    try:
        os.fsync(fd)
    finally:
        os.close(fd)
    print(f'COMPLETE {output}')


if __name__ == '__main__':
    main()

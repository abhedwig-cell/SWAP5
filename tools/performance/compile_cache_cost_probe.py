#!/usr/bin/env python3
"""Diagnostic copy of the canonical opt-in cache with per-request timing stages.

Never use as an admission cache or a normal F-CI compiler wrapper.
"""
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import time

FLAGS = {'-std=f2008', '-ffree-line-length-none', '-w', '-fopenmp',
         '-fcheck=all', '-fbacktrace', '-ffpe-trap=invalid,zero,overflow', '-O0', '-O2'}
CONTROLS = {'SWAP5_CACHE_DIR', 'SWAP5_CACHE_EVENTS', 'SWAP5_CACHE_PROFILE',
            'SWAP5_REAL_FC', 'SWAP5_CACHE_DISABLED'}


def digest(data):
    return hashlib.sha256(data).hexdigest()


def file_hash(path):
    return digest(Path(path).read_bytes())


def emit(event):
    target = os.environ.get('SWAP5_CACHE_EVENTS')
    if target:
        with open(target, 'a') as f:
            fcntl.flock(f, fcntl.LOCK_EX)
            f.write(json.dumps(event, sort_keys=True) + '\n')


def pool(directory):
    files = sorted(p for p in directory.iterdir() if p.suffix in {'.o', '.mod', '.smod'})
    if any(p.is_symlink() or not p.is_file() for p in files):
        raise ValueError('non-regular build input')
    return {p.name: file_hash(p) for p in files}


def toolchain(profile):
    config = json.loads(Path(profile).read_text())
    if config.get('closure_status') != 'EXPLICIT_GNU13_TRIAL_PROFILE':
        raise ValueError('unknown toolchain closure')
    files = set()
    for item in config['roots']:
        p = Path(item)
        if not p.exists():
            raise ValueError('missing toolchain input')
        if p.is_dir():
            files.update(q for q in p.rglob('*') if q.is_file())
        else:
            files.add(p)
    if not files:
        raise ValueError('empty toolchain')
    return {str(p): file_hash(p) for p in sorted(files)}


def parse(args):
    if args.count('-c') != 1 or args.count('-o') != 1:
        raise ValueError('not one compile')
    source = Path(args[args.index('-c') + 1])
    output = Path(args[args.index('-o') + 1])
    includes = []; modules = []; flags = []; i = 0
    while i < len(args):
        a = args[i]
        if a in {'-c', '-o', '-I', '-J'}:
            value = args[i + 1]; i += 2
            if a == '-I': includes.append(Path(value).resolve())
            if a == '-J': modules.append(Path(value).resolve())
        elif a in FLAGS:
            flags.append(a); i += 1
        else:
            raise ValueError('unsupported compiler option')
    if len(includes) != 1 or includes != modules:
        raise ValueError('unknown include/module surface')
    if source.suffix != '.f90' or not source.is_file() or output.suffix != '.o':
        raise ValueError('unsupported source/output')
    if output.resolve().parent != modules[0] or source.resolve().parent == modules[0]:
        raise ValueError('unsupported build layout')
    text = source.read_text()
    if re.search(r'(?im)^\s*#', text) or re.search(r'''(?i)\binclude\s*['"]''', re.sub(r'&\s*\n\s*&?', '', text)):
        raise ValueError('textual include/preprocessor not modeled')
    if '-w' not in flags or sum(f in {'-O0', '-O2'} for f in flags) != 1:
        raise ValueError('unsupported diagnostic/optimization profile')
    return source, output, modules[0], flags


def run(args):
    started = time.monotonic()
    compiler = os.environ['SWAP5_REAL_FC']
    def normal(reason):
        rc = subprocess.call([compiler, *args])
        row = {'event': 'BYPASS', 'reason': reason, 'exit': rc,
               'seconds': time.monotonic() - started}
        if rc == 0:
            try:
                source, output, directory, flags = parse(args)
                row.update(source=str(source), flags=flags, object_sha256=file_hash(output),
                           pool_sha256=digest(json.dumps(pool(directory), sort_keys=True).encode()))
            except (ValueError, OSError, IndexError, UnicodeError):
                pass
        emit(row)
        return rc
    if os.environ.get('SWAP5_CACHE_DISABLED') == '1':
        return normal('explicit disabled')
    try:
        source, output, directory, flags = parse(args)
        profile = os.environ['SWAP5_CACHE_PROFILE']
        if any(v for k, v in os.environ.items() if k.startswith('LD_')) or any(os.environ.get(k) for k in ('LD_LIBRARY_PATH', 'LD_PRELOAD',
                   'GCC_EXEC_PREFIX', 'COMPILER_PATH', 'LIBRARY_PATH', 'CPATH',
                   'C_INCLUDE_PATH', 'CPLUS_INCLUDE_PATH', 'GFORTRAN_INCLUDE_PATH')):
            raise ValueError('unmodeled search-path environment')
        toolchain_started = time.monotonic()
        chain = toolchain(profile)
        toolchain_seconds = time.monotonic() - toolchain_started
        covered = {str(Path(p).resolve()) for p in chain}
        for helper in ('f951', 'as'):
            found = subprocess.check_output([compiler, '-print-prog-name=' + helper], text=True).strip()
            resolved = Path(found) if '/' in found else Path(shutil.which(found) or '/nonexistent')
            if str(resolved.resolve()) not in covered:
                raise ValueError('compiler helper outside declared closure')
        if str(Path(compiler).resolve()) not in {str(Path(p).resolve()) for p in chain}:
            raise ValueError('compiler outside declared closure')
        inputs = {'version': 1, 'tool': file_hash(__file__),
                  'source_path': str(source.resolve()), 'source': file_hash(source),
                  'cwd_prefix': pool(Path.cwd()), 'source_directory_prefix': pool(source.resolve().parent),
                  'prefix': pool(directory), 'flags': flags,
                  'compiler': str(Path(compiler).resolve()), 'toolchain': chain,
                  'profile': file_hash(profile), 'cwd': str(Path.cwd()),
                  'environment': digest(json.dumps({k: v for k, v in os.environ.items()
                                          if k not in CONTROLS}, sort_keys=True).encode())}
        key = digest(json.dumps(inputs, sort_keys=True).encode())
        key_preparation_seconds = time.monotonic() - started - toolchain_seconds
        root = Path(os.environ['SWAP5_CACHE_DIR']); root.mkdir(parents=True, exist_ok=True)
    except (ValueError, KeyError, OSError, IndexError, UnicodeError) as e:
        return normal(str(e))
    with (root / (key + '.lock')).open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        entry = root / key
        cached = None
        lookup_started = time.monotonic()
        if entry.exists():
            try:
                manifest = json.loads((entry / 'manifest.json').read_text())
                assert manifest['inputs'] == inputs
                assert set(manifest['members']) == {'object', *manifest['pool']}
                for name, sha in manifest['members'].items():
                    assert Path(name).name == name and not (entry / name).is_symlink()
                    assert file_hash(entry / name) == sha
                assert manifest['members']['object'] == manifest['object_sha256']
                assert {n: manifest['members'][n] for n in manifest['pool']} == manifest['pool']
                cached = manifest
            except (AssertionError, KeyError, ValueError, OSError):
                emit({'event': 'INVALID', 'key': key, 'source': str(source)})
                shutil.rmtree(entry)
        lookup_seconds = time.monotonic() - lookup_started
        if cached:
            shutil.copyfile(entry / 'object', output)
            for name in cached['pool']:
                shutil.copyfile(entry / name, directory / name)
            emit({'event': 'HIT', 'key': key, 'source': str(source), 'flags': flags,
                  'object_sha256': file_hash(output), 'pool_sha256': digest(json.dumps(pool(directory), sort_keys=True).encode()),
                  'seconds': time.monotonic() - started,
                  'audit_timing': {'toolchain_seconds': toolchain_seconds,
                                   'prelookup_seconds': key_preparation_seconds,
                                   'lookup_seconds': lookup_seconds}})
            return 0
        result = subprocess.run([compiler, *args], capture_output=True)
        sys.stdout.buffer.write(result.stdout); sys.stderr.buffer.write(result.stderr)
        if result.returncode != 0:
            emit({'event': 'FAILED', 'key': key, 'source': str(source), 'exit': result.returncode})
            return result.returncode
        if result.stdout or result.stderr:
            emit({'event': 'BYPASS', 'key': key, 'source': str(source), 'reason': 'diagnostics'})
            return 0
        if file_hash(source) != inputs['source'] or toolchain(profile) != chain:
            raise RuntimeError('inputs changed during compilation; evidence rejected')
        modules = {n: h for n, h in pool(directory).items() if n.endswith(('.mod', '.smod'))}
        obj_hash = file_hash(output)
        with tempfile.TemporaryDirectory(dir=root, prefix='publish-') as staging:
            dest = Path(staging)
            shutil.copyfile(output, dest / 'object')
            for name in modules:
                shutil.copyfile(directory / name, dest / name)
            manifest = {'inputs': inputs, 'object_sha256': obj_hash,
                        'pool': modules, 'members': {'object': obj_hash, **modules}}
            (dest / 'manifest.json').write_text(json.dumps(manifest, sort_keys=True))
            os.rename(dest, entry)
        emit({'event': 'MISS', 'key': key, 'source': str(source), 'flags': flags,
              'object_sha256': obj_hash, 'pool_sha256': digest(json.dumps(pool(directory), sort_keys=True).encode()),
              'seconds': time.monotonic() - started,
              'audit_timing': {'toolchain_seconds': toolchain_seconds,
                               'prelookup_seconds': key_preparation_seconds,
                               'lookup_seconds': lookup_seconds}})
        return 0


if __name__ == '__main__':
    raise SystemExit(run(sys.argv[1:]))

#!/usr/bin/env python3
"""Bounded F-CI leaf receipts. Unknown identity/evidence always executes."""
import datetime
import fcntl
import hashlib
import hmac
import json
import os
import re
from pathlib import Path
import shutil
import shlex
import signal
import stat
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]
CONTROL = 'tools/fci/resume_group.py'
OUTER = 'tests/fci/run_fci_canonical_p2e05_moving_preservation.sh'
# A changed runtime/capsule must not self-qualify a previously unaudited
# transitive tool closure. Populate only after reviewing the complete manifest.
AUDITED_TOOL_PROFILE = 'PENDING_REVIEW'
GROUPS = {
    'frost-invalid': ('tests/frost/run_frost_invalid_input_preservation.sh',
                      ['test_ppa_wu05b_frost_effect.f90',
                       'test_frost_invalid_input_preservation.f90',
                       'test_invalid_parameter_guard.f90'],
                      'FROST_INVALID_INPUT_O0_O2_IDENTICAL=PASS', 6),
    'frost-independent': ('tests/frost/run_frost_nan_guard_independent.sh',
                          ['test_frost_nan_guard_independent.f90'],
                          'FROST_NAN_GUARD_INDEPENDENT_O0_O2_IDENTITY=PASS', 2),
}
CONTROL_ENV = {'FCI_RESUME_MODE', 'FCI_RESUME_STORE', 'FCI_RESUME_KEY',
               'FCI_RESUME_STOP_AFTER'}
# Eligibility is an audited closure, not merely a fingerprint of arbitrary new
# committed code. A changed leaf can introduce includes, fixtures or outputs.
# Qualify that new closure before changing these pins in the controller.
AUDITED_LEAF_BLOBS = {
    'src/process/mod_frost_hydraulic_effect.f90': '0dd5b541af936d292d23575f798c3cdd5be19c47',
    'tests/frost/run_frost_invalid_input_preservation.sh': 'a33e28b61147d665736831f23948eaac2939a20a',
    'tests/frost/run_frost_nan_guard_independent.sh': 'c14028598fe46b81a1282a361bf10aedd70b4da3',
    'tests/frost/test_frost_invalid_input_preservation.f90': '79a9a1dbd21f331077a53a423023221abe80435d',
    'tests/frost/test_frost_nan_guard_independent.f90': 'cb666c75ab610c60924ee4f70216e57f8f07f1c3',
    'tests/frost/test_invalid_parameter_guard.f90': '02eeaac0f934d8e06432bc40c6e2ceb24e97ab1e',
    'tests/frost/test_ppa_wu05b_frost_effect.f90': 'b5a253aba2060d8011479eee10f22a3336e964d2',
}


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def encode(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'),
                      ensure_ascii=True).encode()


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT).decode().strip()


def atomic(path, data):
    fd, name = tempfile.mkstemp(dir=path.parent, prefix='.pending-')
    try:
        with os.fdopen(fd, 'wb') as stream:
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(name, path)
        fd = os.open(path.parent, os.O_RDONLY | os.O_DIRECTORY)
        try:
            os.fsync(fd)
        finally:
            os.close(fd)
    finally:
        if os.path.exists(name):
            os.unlink(name)


def utc():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def identity(group, command):
    runner, tests, marker, compilations = GROUPS[group]
    if command != ['bash', runner]:
        raise ValueError('unqualified command/arguments')
    if any(name.startswith('BASH_FUNC_') for name in os.environ):
        raise ValueError('unqualified exported shell function')
    for name in ['BASH_ENV', 'ENV', 'LD_PRELOAD', 'LD_LIBRARY_PATH',
                 'LD_AUDIT', 'LIBRARY_PATH', 'COMPILER_PATH', 'GCC_EXEC_PREFIX',
                 'CPATH', 'C_INCLUDE_PATH', 'GFORTRAN_INCLUDE_PATH',
                 'PYTHONPATH', 'PYTHONHOME']:
        if os.environ.get(name):
            raise ValueError('unqualified external input setting: ' + name)
    paths = [CONTROL, OUTER, runner,
             'src/process/mod_frost_hydraulic_effect.f90']
    paths += ['tests/frost/' + test for test in tests]
    # GNU module lookup has implicit cwd/source-directory prefixes even with
    # explicit -I/-J. No pre-existing module state is qualified in those paths.
    prefixes = {(ROOT / path).parent for path in paths if path.endswith('.f90')}
    for directory in prefixes:
        if any(file.suffix.lower() in ['.mod', '.smod'] for file in directory.iterdir()):
            raise ValueError('unqualified implicit module prefix: ' + str(directory))
    inputs = {}
    for path in sorted(paths):
        file = ROOT / path
        if not file.is_file() or file.is_symlink():
            raise ValueError('missing/nonregular input: ' + path)
        # Bind the committed control and all working bytes; dirty input is RUN.
        blob = git('rev-parse', 'HEAD:' + path)
        if path not in [CONTROL, OUTER] and blob != AUDITED_LEAF_BLOBS.get(path):
            raise ValueError('unqualified changed leaf closure: ' + path)
        if git('hash-object', '--no-filters', path) != blob:
            raise ValueError('uncommitted input: ' + path)
        inputs[path] = {'git_blob': blob, 'sha256': digest(file)}
    # No imported modules, fixtures, includes, generated inputs or Git-based
    # science in these leaves. Their complete file closure is explicit above.
    # Toolchain directories are explicit, conservative and hashed in full.
    directories = os.environ.get('FCI_RESUME_TOOLCHAIN_DIRS', '').split(os.pathsep)
    if not all(directories):
        raise ValueError('toolchain capsule directories not declared')
    tools = {}
    def dynamic(path):
        with Path(path).open('rb') as stream:
            header = stream.read(18)
        if header[:4] != b'\x7fELF':
            return
        result = subprocess.run(['ldd', str(path)], capture_output=True, text=True)
        kind = int.from_bytes(header[16:18], 'little' if header[5] == 1 else 'big')
        if (result.returncode and kind != 1) or 'not found' in result.stdout:
            raise ValueError('unverifiable ELF dependency graph: ' + str(path))
        for line in result.stdout.splitlines():
            for token in line.split():
                if token.startswith('/'):
                    if not Path(token).is_file():
                        raise ValueError('missing dynamic dependency: ' + token)
                    tool(token)
    def tool(file):
        path = Path(file).resolve()
        if str(path) in tools:
            return
        tools[str(path)] = digest(path)
        if path.read_bytes()[:4] != b'\x7fELF' and path.suffix == '.so':
            script = re.sub(r'/\*.*?\*/', '', path.read_text(), flags=re.S)
            for token in re.split(r'[\s();]+', script):
                if not token or token in ['GROUP', 'INPUT', 'AS_NEEDED', 'OUTPUT_FORMAT'] or token.startswith('elf'):
                    continue
                if token.startswith('-l'):
                    name = 'lib' + token[2:] + '.a'
                    dependency = subprocess.check_output(['gfortran', '-print-file-name='+name], text=True).strip()
                elif token.startswith('/'):
                    dependency = token
                else:
                    dependency = str(path.parent / token)
                    if not Path(dependency).is_file():
                        dependency = subprocess.check_output(['gfortran', '-print-file-name='+token], text=True).strip()
                if not Path(dependency).is_absolute() or not Path(dependency).is_file():
                    raise ValueError('unqualified linker-script input: ' + token)
                tool(dependency)
        dynamic(path)
    for name in ['bash', 'sh', 'gfortran', 'as', 'ld', 'rm', 'mkdir',
                 'mktemp', 'grep', 'cmp', 'cat', 'git', 'ldd']:
        file = shutil.which(name)
        if file is None:
            raise ValueError('missing tool: ' + name)
        if name not in ['gfortran', 'ldd'] and Path(file).read_bytes()[:4] != b'\x7fELF':
            raise ValueError('unqualified text tool: ' + name)
        tool(file)
    tool(sys.executable)
    for directory in directories:
        base = Path(directory)
        if not base.is_absolute() or not base.is_dir():
            raise ValueError('invalid toolchain directory')
        for file in sorted(base.rglob('*')):
            if file.is_symlink():
                if file.is_dir():
                    raise ValueError('unqualified symlink capsule directory: ' + str(file))
                tools[str(file.absolute())+'#symlink'] = hashlib.sha256(str(file.readlink()).encode()).hexdigest()
            if file.is_file():
                tools[str(file.resolve())] = digest(file)
    # Require the actual compiler front end, archive/link specs and libraries
    # selected by gfortran to be inside the hashed surface.
    for query in ['-print-prog-name=f951', '-print-file-name=libgfortran.a',
                  '-print-file-name=libgcc.a', '-print-file-name=libgfortran.spec']:
        file = subprocess.check_output(['gfortran', query], text=True).strip()
        if str(Path(file).resolve()) not in tools:
            raise ValueError('compiler dependency outside capsule: ' + file)
        # Capsule hashing also covers specs/includes/startup objects. Traverse
        # dynamic dependencies of the actual frontend, not a shell wrapper.
        dynamic(file)
    compiler = Path(shutil.which('gfortran')).resolve()
    if compiler.read_bytes()[:4] != b'\x7fELF':
        lines = compiler.read_text().splitlines()
        if len(lines) != 2 or lines[0] != '#!/bin/sh':
            raise ValueError('unqualified compiler wrapper')
        tokens = shlex.split(lines[1])
        if (tokens[:1] != ['exec'] or tokens[-1:] != ['$@'] or
                not Path(tokens[1]).is_absolute() or
                any(not token.startswith(('-B/', '-L/', '-Wl,-rpath,/'))
                    for token in tokens[2:-1])):
            raise ValueError('unqualified compiler wrapper command')
        compiler = Path(tokens[1]).resolve()
        if str(compiler) not in tools or compiler.read_bytes()[:4] != b'\x7fELF':
            raise ValueError('compiler wrapper target outside capsule')
    dynamic(compiler)
    # Compiler-selected test-executable runtime and linker/startup inputs.
    for name in ['libgfortran.so', 'libquadmath.so', 'libgcc_s.so', 'libm.so',
                 'libc.so', 'libc_nonshared.a', 'crt1.o', 'crti.o', 'crtn.o',
                 'crtbegin.o', 'crtend.o']:
        file = subprocess.check_output(['gfortran', '-print-file-name=' + name],
                                       text=True).strip()
        if not Path(file).is_absolute() or not Path(file).is_file():
            raise ValueError('unknown runtime/linker input: ' + name)
        tool(file)
    for module in list(sys.modules.values()):
        file = getattr(module, '__file__', None)
        if file and Path(file).is_file():
            tool(file)
    runtime = {'flags': list(sys.flags), 'xoptions': sys._xoptions}
    profile = {path: value for path, value in tools.items()
               if path != str((ROOT / CONTROL).resolve())}
    fingerprint = hashlib.sha256(encode({'tools': profile, 'runtime': runtime})).hexdigest()
    if fingerprint != AUDITED_TOOL_PROFILE:
        raise ValueError('unqualified toolchain/runtime profile: ' + fingerprint)
    env = {k: v for k, v in os.environ.items()
           if k not in CONTROL_ENV | {'_', 'SHLVL'} }
    # Do not publish environment values (possible secrets); bind their digest.
    return {'schema': 'swap5.fci.leaf-input.v2', 'group': group,
            'command': command, 'inputs': inputs, 'tools': tools,
            'execution_command': ['bash', str(ROOT / runner)],
            'execution_cwd_policy': 'private-empty-temporary-directory-v1',
            'implicit_source_module_prefixes': {str(path): [] for path in sorted(prefixes)},
            'environment_sha256': hashlib.sha256(encode(env)).hexdigest(),
            'cwd': str(ROOT), 'platform': list(os.uname()),
            'controller_python': digest(sys.executable),
            'audited_tool_profile': fingerprint, 'interpreter_runtime': runtime,
            'marker': marker, 'compilations': compilations,
            'required_outputs': [], 'shared_state': False}


def trusted_storage():
    store = Path(os.environ.get('FCI_RESUME_STORE', ''))
    key = Path(os.environ.get('FCI_RESUME_KEY', ''))
    if not store.is_absolute() or not key.is_absolute():
        raise ValueError('absolute durable store/key required')
    if (store.is_symlink() or key.is_symlink() or store in key.parents or
            key.resolve() != key or store.resolve() != store):
        raise ValueError('separate non-symlink trust key required')
    key_stat = key.stat()
    if not stat.S_ISREG(key_stat.st_mode) or key_stat.st_uid != os.getuid():
        raise ValueError('invalid key ownership/type')
    if key_stat.st_mode & 0o077 or key_stat.st_size != 32:
        raise ValueError('private 32-byte key required')
    store.mkdir(parents=True, exist_ok=True, mode=0o700)
    store_stat = store.stat()
    if store_stat.st_uid != os.getuid() or store_stat.st_mode & 0o077:
        raise ValueError('private store required')
    return store, key.read_bytes()


def verify(receipt, log, current, key):
    envelope = json.loads(receipt.read_bytes())
    record = envelope['record']
    signature = hmac.new(key, encode(record), hashlib.sha256).hexdigest()
    if not hmac.compare_digest(signature, envelope['hmac_sha256']):
        raise ValueError('receipt authentication failed')
    if (record['status'] != 'PASS' or record['exit_code'] != 0 or
            not record['started_utc'] or not record['ended_utc'] or
            record['input'] != current or record['end_input'] != current or
            record['required_outputs'] != [] or record['shared_state'] is not False or
            record['execution_command'] != current['execution_command'] or
            record['private_cwd_removed'] is not True):
        raise ValueError('terminal/closure/output mismatch')
    data = log.read_bytes()
    if log.is_symlink() or hashlib.sha256(data).hexdigest() != record['log_sha256']:
        raise ValueError('log integrity mismatch')
    if len(data) != record['log_bytes']:
        raise ValueError('log length mismatch')
    if current['marker'].encode() not in data.splitlines():
        raise ValueError('terminal scientific marker missing')
    return record, data


def execute(command, log=None, cwd=ROOT):
    child = subprocess.Popen(command, cwd=cwd, stdout=subprocess.PIPE,
                             stderr=subprocess.STDOUT, start_new_session=True)
    def interrupted(signum, frame):
        os.killpg(child.pid, signum)
        child.wait()
        raise SystemExit(128 + signum)
    old = {sig: signal.signal(sig, interrupted) for sig in [signal.SIGTERM, signal.SIGINT]}
    try:
        stream = log.open('wb') if log else None
        try:
            for block in iter(lambda: child.stdout.read(65536), b''):
                if stream:
                    stream.write(block)
                sys.stdout.buffer.write(block)
                sys.stdout.buffer.flush()
            code = child.wait()
            if stream:
                stream.flush()
                os.fsync(stream.fileno())
            return code
        finally:
            if stream:
                stream.close()
    finally:
        for sig, handler in old.items():
            signal.signal(sig, handler)


def main():
    group, *command = sys.argv[1:]
    mode = os.environ.get('FCI_RESUME_MODE', 'OFF')
    if mode == 'OFF':
        return execute(command)
    if mode not in ['SHADOW', 'RESUME'] or group not in GROUPS:
        print('FCI_RESUME_RUN unknown mode/group', file=sys.stderr)
        return execute(command)
    started = time.monotonic()
    try:
        current = identity(group, command)
        store, key = trusted_storage()
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        print(f'FCI_RESUME_RUN {group}: {error}', file=sys.stderr)
        return execute(command)
    # Lock spans verification, execution and publication. No concurrent writer
    # may turn a partial run into a complete receipt or replace its log.
    with (store / (group + '.lock')).open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        receipt = store / (group + '.json')
        log = store / (group + '.log')
        if receipt.is_symlink() or log.is_symlink():
            print('FCI_RESUME_RUN unsafe evidence path', file=sys.stderr)
            return execute(command)
        inherited = None
        reason = 'missing receipt'
        try:
            inherited = verify(receipt, log, current, key)
        except (OSError, ValueError, KeyError, TypeError, RecursionError) as error:
            reason = str(error)
        verification_seconds = time.monotonic() - started
        decision = 'INHERIT' if inherited else 'RUN'
        event = {'group': group, 'mode': mode, 'decision': decision,
                 'reason': 'verified authenticated terminal PASS' if inherited else reason,
                 'verification_seconds': verification_seconds, 'utc': utc()}
        print('FCI_RESUME_DECISION ' + json.dumps(event, sort_keys=True), flush=True)
        if mode == 'RESUME' and inherited:
            sys.stdout.buffer.write(inherited[1])
            sys.stdout.buffer.flush()
            print('FCI_RESUME_INHERITED ' + group, flush=True)
            return 0
        # Invalidate previous terminal authority BEFORE beginning a new run.
        atomic(receipt, encode({'record': {'status': 'RUNNING', 'started_utc': utc()}}))
        begin = utc()
        t0 = time.monotonic()
        with tempfile.TemporaryDirectory(prefix='swap5-fci-leaf-') as execution_cwd:
            code = execute(current['execution_command'], log, cwd=execution_cwd)
        elapsed = time.monotonic() - t0
        end = utc()
        if code != 0:
            return code
        final_started = time.monotonic()
        try:
            final = identity(group, command)
            if final != current or current['marker'].encode() not in log.read_bytes().splitlines():
                changed = [name for name in sorted(set(current['tools']) | set(final['tools']))
                           if current['tools'].get(name) != final['tools'].get(name)]
                raise ValueError('closure changed or marker missing during execution; changed tool paths=' + str(changed))
        except (OSError, ValueError, subprocess.SubprocessError) as error:
            print('FCI_RESUME_NO_RECEIPT ' + str(error), file=sys.stderr)
            return 1
        record = {'status': 'PASS', 'started_utc': begin, 'ended_utc': end,
                  'exit_code': 0, 'wall_seconds': elapsed, 'input': current,
                  'end_input': final, 'executed_head': git('rev-parse', 'HEAD'),
                  'log_sha256': digest(log), 'log_bytes': log.stat().st_size,
                  'execution_command': current['execution_command'],
                  'execution_cwd': execution_cwd,
                  'private_cwd_removed': not Path(execution_cwd).exists(),
                  'end_input_verification_seconds': time.monotonic() - final_started,
                  'required_outputs': [], 'shared_state': False}
        publication = time.monotonic()
        atomic(receipt, encode({'record': record, 'hmac_sha256':
                               hmac.new(key, encode(record), hashlib.sha256).hexdigest()}))
        print('FCI_RESUME_EXECUTED ' + json.dumps({
            'group': group, 'wall_seconds': elapsed,
            'compilations': current['compilations'],
            'checkpoint_write_seconds': time.monotonic() - publication,
            'end_input_verification_seconds': record['end_input_verification_seconds'],
            'verification_seconds': verification_seconds}), flush=True)
        if os.environ.get('FCI_RESUME_STOP_AFTER') == group:
            return 75  # controlled interruption, never whole-run PASS
        return 0


if __name__ == '__main__':
    sys.exit(main())

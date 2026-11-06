"""Private complete-provider S5PT proof; never modifies current production source."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import struct
import subprocess
import sys
import time
import zlib

ROOT = Path(__file__).resolve().parents[2]
RECORD = ROOT / 'integration/dataqual15_hupsel/POND_THERMAL_NATIVE_RECOVERY_20261106.json'
SOURCE = 'src/adapter/mod_pond_thermal_restart_file.f90'
RUNNER = 'tests/nut-sol/run_pond_thermal.py'
CANDIDATE = ROOT / 'tests/dataqual15_hupsel/pond_thermal_native_candidate.f90'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def guard():
    record = json.loads(RECORD.read_text())
    assert sha(CANDIDATE) == record['candidate_sha256'], 'candidate drift'
    for name, digest in record['inputs'].items():
        assert hashlib.sha256((ROOT / name).read_bytes().replace(b'\r\n', b'\n')).hexdigest() == digest, 'input drift: ' + name
    delta = subprocess.check_output(['git', 'diff', '--name-only', record['baseline'], '--', 'src', 'app', 'reference'], cwd=ROOT, text=True)
    assert not delta.strip(), 'production source changed'
    untracked = subprocess.check_output(['git', 'ls-files', '--others', '--exclude-standard', '--', 'src', 'app', 'reference'], cwd=ROOT, text=True)
    assert not untracked.strip(), 'untracked production source'
    return record


def execute(command, cwd, output, label):
    start = time.monotonic()
    cp = subprocess.run(list(map(str, command)), cwd=cwd, capture_output=True,
                        env=dict(os.environ, OMP_NUM_THREADS='1', PYTHONUTF8='1'), timeout=1800)
    (output / (label + '.stdout')).write_bytes(cp.stdout)
    (output / (label + '.stderr')).write_bytes(cp.stderr)
    return dict(command=list(map(str, command)), returncode=cp.returncode,
                seconds=time.monotonic()-start, stdout=label+'.stdout', stderr=label+'.stderr')


def prepare(out, role, record):
    view = out / 'source'
    subprocess.run(['git', 'worktree', 'add', '--detach', '--no-checkout', str(view), record['baseline']], cwd=ROOT, check=True, capture_output=True)
    paths = ['src', 'app/support/restart_publish.c', RUNNER,
             'tests/nut-sol/run_nonlinear_pond.py', 'tests/nut-sol/test_pond_thermal.f90',
             'tests/nut-sol/matrix_nonlinear_oracle.f90', 'tests/modularity/low_air_consistent_grid_stubs.f90',
             'tests/physics/test_ppa_wu05d2_mixed_application.f90',
             'integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64']
    subprocess.run(['git', 'checkout', record['baseline'], '--']+paths, cwd=view, check=True, capture_output=True)
    if role == 'candidate':
        (view / SOURCE).write_bytes(CANDIDATE.read_bytes())
    # Explicit execution seam, equal on both sides. No assertion or recipe changes.
    runner = (view / RUNNER).read_text()
    before = "run(fc + flags + objects + ['-o', exe], build, 'link')"
    after = "run(fc + flags + objects + (['-Wl,--stack,67108864'] if os.name == 'nt' else []) + ['-o', exe], build, 'link')"
    assert runner.count(before) == 1
    (view / RUNNER).write_text(runner.replace(before, after))
    return view


def measure(out, view, role):
    result = dict(role=role, platform=os.name, production_admission=False,
                  whole_scientific_admission=False, events=[], malformed=[], positives=[])
    for recipe, prefix in [('base', ''), ('rutter', 'rutter-')]:
        physical = out / recipe
        command = [sys.executable, '-B', view / RUNNER, '--output', physical]
        if recipe == 'rutter':
            command += ['--black-rutter']
        event = execute(command, view, out, recipe)
        result['events'].append(event)
        (out / 'RESULT.json').write_text(json.dumps(result, indent=2)+'\n')
        assert event['returncode'] == 0, (out / (recipe+'.stderr')).read_text(errors='replace')[-3000:]
        report = json.loads((physical / 'result.json').read_text())
        assert all(e['returncode'] == 0 for e in report['events'])
        for opt in ('O0', 'O2'):
            build = physical / opt
            exe = build / ('thermal.exe' if os.name == 'nt' else 'thermal')
            if os.name == 'nt':
                raw = exe.read_bytes(); pe = struct.unpack_from('<I', raw, 0x3c)[0]
                assert raw[pe:pe+4] == b'PE\0\0'
                assert struct.unpack_from('<Q', raw, pe+24+72)[0] == 67108864
            raw = (build / '2/restart.bin').read_bytes()
            assert raw[:8] == (b'S5PT0004' if recipe == 'rutter' else b'S5PT0001')
            assert zlib.crc32(raw[:-4]) == struct.unpack_from('=I', raw, len(raw)-4)[0]
            # Actual stream fields, independently checked against both producer builds.
            n, history, physical_id, count = struct.unpack_from('=iiqi', raw, 148)
            assert n == 4 and history == 0 and count > 0 and physical_id > 0
            fields = {'time_bound': 144, 'history': 152}
            if recipe == 'rutter':
                micro = 168 + 8*count + 8*(3*n+2) + 8
                params = micro+12+12+44
                fields.update(rutter_bound=params, irrigation_intercepted=params+4+6*8)
            controls = build / 'logical-controls'; controls.mkdir()
            for name, offset in fields.items():
                original = struct.unpack_from('=i', raw, offset)[0]
                assert original in (0, 1), (name, offset, original)
                for word in (2, -1, 0x01000000, 0x7fffffff):
                    blob = bytearray(raw); struct.pack_into('=i', blob, offset, word)
                    struct.pack_into('=I', blob, len(blob)-4, zlib.crc32(blob[:-4]))
                    label = name+'-'+str(word); path = controls / (label+'.bin'); path.write_bytes(blob)
                    event = execute([exe, prefix+'reject', path, controls/'endpoint', 2, 1], controls, controls, label)
                    accepted = event['returncode'] != 0
                    if role == 'candidate':
                        assert not accepted, (recipe, opt, name, word, event)
                        assert b'THERMAL_INVALID_RESTART=PASS' in (controls / event['stdout']).read_bytes()
                    result['malformed'].append(dict(recipe=recipe, optimization=opt, field=name, word=word,
                                                    rejected=not accepted, event=event))
            for path in sorted(build.glob('*/*.bin')):
                if path.parent.name not in ('logical-controls', 'controls'):
                    result['positives'].append(dict(path=str(path.relative_to(out)), sha256=sha(path)))
        print(role, recipe, 'O0/O2 complete physical/native execution finished', flush=True)
    result['source_sha256'] = sha(view / SOURCE)
    result['status'] = 'PRIVATE_COMPLETE_COMPOSITION_NATIVE_LOGICAL_MEASUREMENT'
    (out / 'RESULT.json').write_text(json.dumps(result, indent=2)+'\n')
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--role', choices=['baseline', 'candidate'], required=True)
    args = parser.parse_args(); record = guard(); out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=False)
    view = prepare(out, args.role, record)
    measure(out, view, args.role)
    guard()


if __name__ == '__main__':
    main()

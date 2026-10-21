"""Assess actual interval refinement, semantic corruptions and crash publication."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import struct
import subprocess
import time
import zlib

ROOT = Path(__file__).resolve().parents[2]


def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--physical', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--build', type=Path)
    parser.add_argument('--nonlinear-refinement', action='store_true')
    args = parser.parse_args()
    physical = args.physical.resolve()
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=False)
    prior = json.loads((physical / 'result.json').read_text())
    assert prior['status'] == 'FOCUSED_PHYSICAL_PASS_REFINEMENT_ASSESSMENT_PENDING_NOT_ADMITTED'
    assert prior['results']['O0'] == prior['results']['O2']
    assert all(sha(ROOT / p) == h for p, h in prior['inputs'].items())
    report = {'physical_sha256': sha(physical / 'result.json'), 'events': [], 'results': {},
              'inputs': {str(p.relative_to(ROOT)): sha(p) for p in [Path(__file__).resolve(), ROOT / 'tests/nut-sol/thermal_rename_kill.c']}}

    def persist():
        # Replace a complete report; a reader must not observe an earlier
        # event snapshot truncated while the final qualification is published.
        temporary = out / 'result.pending'
        with temporary.open('w') as stream:
            stream.write(json.dumps(report, indent=2) + '\n')
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, out / 'result.json')

    def run(command, cwd, category, env=None, expected=0):
        start = time.perf_counter()
        r = subprocess.run(list(map(str, command)), cwd=cwd, capture_output=True, env=env)
        i = len(report['events'])
        (out / f'{i:04d}.stdout').write_bytes(r.stdout)
        (out / f'{i:04d}.stderr').write_bytes(r.stderr)
        report['events'].append({'command': list(map(str, command)), 'category': category,
                                 'returncode': r.returncode, 'expected_returncode': expected,
                                 'seconds': time.perf_counter() - start, 'stdout': f'{i:04d}.stdout', 'stderr': f'{i:04d}.stderr'})
        persist()
        assert r.returncode == expected, (r.stdout, r.stderr)
        return r.stdout.decode()

    library = out / 'rename-kill.so'
    run(['gcc', '-shared', '-fPIC', ROOT / 'tests/nut-sol/thermal_rename_kill.c', '-ldl', '-o', library], out, 'observer_compile_link')
    for opt in ['O0', 'O2']:
        exe = (args.build.resolve() if args.build else physical) / opt / 'thermal'
        assert sha(exe) == prior['executables'][opt]
        exponent = str(prior['exponent'])
        build = out / opt
        build.mkdir()
        points = {int(n): v['stdout'][0] for n, v in prior['results'][opt].items() if n != 'controls'}
        refined = [32, 64, 128, 256] if args.nonlinear_refinement else [32, 64, 128]
        for windows in refined:
            case = build / str(windows)
            case.mkdir()
            path, full, fresh = case / 'restart.bin', case / 'full.bin', case / 'fresh.bin'
            for mode, endpoint in [('full', full), ('split', full), ('resume', fresh)]:
                stdout = run([exe, mode, path, endpoint, windows, exponent], case, 'refinement_native')
                assert 'THERMAL_PHYSICAL_LITERAL_RESTART=PASS' in stdout
                if mode == 'full':
                    points[windows] = stdout
            assert full.read_bytes() == fresh.read_bytes()
        def values(text, label):
            return [float(x) for x in re.search(r'^' + label + r'=(.*)$', text, re.M)[1].split()]
        keys = sorted(points)
        mass = [values(points[n], 'MASS_VECTOR') for n in keys]
        decay = [values(points[n], 'DECAY')[0] for n in keys]
        mass_delta = [max(abs(a - b) for a, b in zip(x, y)) for x, y in zip(mass, mass[1:])]
        decay_delta = [abs(x - y) for x, y in zip(decay, decay[1:])]
        assert all(a > b > 0 for a, b in zip(mass_delta, mass_delta[1:])), mass_delta
        assert all(a > b > 0 for a, b in zip(decay_delta, decay_delta[1:])), decay_delta
        assert decay_delta[-1] / decay[-1] < 1e-3, decay_delta[-1] / decay[-1]
        assert mass_delta[-1] / max(mass[-1]) < 1e-6
        # Native same-platform layout controls, with valid outer CRC.
        raw = (physical / opt / '2/restart.bin').read_bytes()
        assert raw[:8] == b'S5MT0001'
        n, history = struct.unpack_from('ii', raw, 148)
        count = struct.unpack_from('i', raw, 164)[0]
        assert n == 4 and history in [0, 1] and 0 < count < 10000
        body = 168 + 8 * count
        mutants = {'overlong': raw[:-4] + b'X'}
        for label, offset, fmt, value in [
                ('water_clock', 136, 'd', .0005), ('water_revision', 128, 'q', -1),
                ('physical_id', 156, 'q', 0), ('geometry', 168, 'd', -999.),
                ('negative_water', body + 8 * n, 'd', -.1),
                ('nonfinite_temperature', body + 8 * (2 * n + 2), 'd', float('nan'))]:
            bad = bytearray(raw[:-4])
            struct.pack_into(fmt, bad, offset, value)
            mutants[label] = bytes(bad)
        for label, payload in mutants.items():
            path = build / (label + '.bin')
            path.write_bytes(payload + struct.pack('I', zlib.crc32(payload) & 0xffffffff))
            stdout = run([exe, 'reject', path, build / 'unused', 2, exponent], build, 'semantic_negative')
            assert 'THERMAL_INVALID_RESTART=PASS' in stdout
        for mode in ['before', 'after']:
            case = build / ('kill-' + mode)
            case.mkdir()
            target = case / 'generation.bin'
            target.write_bytes(raw)
            run([exe, 'full', case / 'unused', target, 2, exponent], case, 'crash_native',
                {**os.environ, 'LD_PRELOAD': str(library), 'SWAP5_THERMAL_KILL_TARGET': str(target),
                 'SWAP5_THERMAL_KILL_MODE': mode}, expected=-signal.SIGKILL)
            expected = raw if mode == 'before' else (physical / opt / '2/full.bin').read_bytes()
            assert target.read_bytes() == expected, 'partial committed generation'
            if mode == 'before':
                stdout = run([exe, 'resume', target, case / 'fresh.bin', 2, exponent], case, 'crash_recovery_native')
                assert 'THERMAL_PHYSICAL_LITERAL_RESTART=PASS' in stdout
                assert (case / 'fresh.bin').read_bytes() == (physical / opt / '2/full.bin').read_bytes()
        report['results'][opt] = {'windows': keys, 'stdout': points, 'mass_delta': mass_delta,
                                  'decay_delta': decay_delta, 'final_relative_decay_difference': decay_delta[-1] / decay[-1],
                                  'semantic_negatives': sorted(mutants), 'kill_before_after_generation_exact': True,
                                  'executable_sha256': sha(exe), 'finest_endpoint_sha256': sha(build / str(keys[-1]) / 'full.bin')}
    assert {k: v for k, v in report['results']['O0'].items() if k != 'executable_sha256'} == {
        k: v for k, v in report['results']['O2'].items() if k != 'executable_sha256'}, 'qualification O0/O2 differs'
    assert all(sha(ROOT / p) == h for p, h in {**prior['inputs'], **report['inputs']}.items())
    report['status'] = 'DYNAMIC_ACCEPTED_ENDPOINT_DECAY_O0_O2_RESTART_REFINEMENT_CRASH_PASS_NOT_ADMITTED'
    report['cost_seconds'] = {c: sum(e['seconds'] for e in report['events'] if e['category'] == c)
                              for c in sorted({e['category'] for e in report['events']})}
    persist()
    assert json.loads((out / 'result.json').read_text()) == json.loads(json.dumps(report))
    print(report['status'])


if __name__ == '__main__':
    main()

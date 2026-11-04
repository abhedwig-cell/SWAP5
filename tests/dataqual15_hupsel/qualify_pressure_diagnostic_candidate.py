"""Actual same-build diagnostic persistence and fail-closed decoder experiment."""
import argparse, csv, hashlib, json, math, os, re, shutil, struct, subprocess, time, zlib
from pathlib import Path

sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()


def qualify(exe, inputs, out):
    out.mkdir()
    env = os.environ.copy(); env.pop('SWAP5_DIAG_PREDECESSOR', None)
    events = []
    def run(name, end, seed=None, mutation=None, rejected=False, capture=None):
        case = out/name; case.mkdir()
        for p in inputs.iterdir():
            if p.suffix.lower() in ('.swp', '.crp', '.met', '.dra', '.nml'):
                shutil.copyfile(p, case/p.name)
        if seed:
            raw = bytearray(seed.read_bytes())
            if mutation: mutation(raw, case)
            (case/'restart-input.bin').write_bytes(raw)
        ends = [float(x) for x in re.search(r'^ends_day=(.*)$', (case/'input.nml').read_text(), re.M)[1].split(',') if x.strip()]
        stop = next(i+1 for i, x in enumerate(ends) if x == end)
        cmd = [str(exe), 'input.nml', str(case/'restart-input.bin') if seed else '-', str(stop), 'swap.swp', 'maize.crp']
        begin = time.monotonic()
        with (case/'stdout').open('wb') as so, (case/'stderr').open('wb') as se:
            p = subprocess.Popen(cmd, cwd=case, env=env, stdout=so, stderr=se)
            while p.poll() is None:
                if time.monotonic()-begin > 2400:
                    p.kill(); p.wait(); raise TimeoutError(name)
                if capture is not None and not (case/f'checkpoint-{capture}.bin').exists():
                    try:
                        raw = (case/'checkpoint.bin').read_bytes()
                        if (raw[:8] == b'S5HR0004' and zlib.crc32(raw[:-4]) == struct.unpack('=I', raw[-4:])[0]
                                and struct.unpack_from('=d', raw, 8)[0] == capture):
                            (case/f'checkpoint-{capture}.bin').write_bytes(raw)
                    except (OSError, struct.error): pass
                time.sleep(.01)
        output = (case/'stdout').read_text(errors='replace')+(case/'stderr').read_text(errors='replace')
        event = dict(case=name, command=cmd, returncode=p.returncode, seconds=time.monotonic()-begin,
                     expected_refusal=rejected, executable_sha256=sha(exe))
        events.append(event); (out/'EVENTS.json').write_text(json.dumps(events, indent=2)+'\n')
        if rejected:
            assert p.returncode != 0 and 'source rotation envelope rejected before publication' in output, output[-1500:]
            assert not any((case/n).exists() for n in ('budget.csv', 'crop.csv', 'checkpoint.bin'))
        else:
            assert p.returncode == 0, output[-1500:]
            raw = (case/'checkpoint.bin').read_bytes()
            assert raw[:8] == b'S5HR0004' and zlib.crc32(raw[:-4]) == struct.unpack('=I', raw[-4:])[0]
            assert struct.unpack_from('=d', raw, 8)[0] == end
            assert all(math.isfinite(x) for x in struct.unpack_from('=2d', raw, len(raw)-20))
        print(name, 'PASS', flush=True)
        return case
    uninterrupted = run('uninterrupted525', 525, capture=524)
    checkpoint = uninterrupted/'checkpoint-524.bin'
    assert checkpoint.exists(), 'actual accepted524 publication was not captured'
    whole = run('restart525', 525, checkpoint)
    assert (whole/'checkpoint.bin').read_bytes() == (uninterrupted/'checkpoint.bin').read_bytes()
    def rows(case, name):
        with (case/name).open(newline='') as f: return list(csv.DictReader(f))
    comparisons = {}
    for name in ('budget.csv', 'crop.csv'):
        a = rows(whole, name); b = rows(uninterrupted, name)
        assert a
        key = next(iter(a[0]))
        by_time = {row[key]: row for row in b}
        assert all(row == by_time[row[key]] for row in a), name
        comparisons[name] = len(a)
    raw = checkpoint.read_bytes()
    pressures = struct.unpack_from('=2d', raw, len(raw)-20)
    assert pressures[0] != 0, 'experiment must exercise a historical nonzero potato observation'
    def reseal(data): struct.pack_into('=I', data, len(data)-4, zlib.crc32(data[:-4]))
    def change(offset, value):
        def mutate(data, case): struct.pack_into('=d', data, len(data)-20+offset, value); reseal(data)
        return mutate
    mutations = {f'{crop}_{kind}': change(offset, value)
                 for crop, offset in [('potato', 0), ('grass', 8)]
                 for kind, value in [('nan', float('nan')), ('posinf', float('inf')), ('neginf', -float('inf'))]}
    def legacy(data, case): data[:8] = b'S5HR0003'; reseal(data)
    def missing(data, case): del data[-20:-4]; reseal(data)
    def extra(data, case): data[-4:-4] = b'extra'; reseal(data)
    def bad_crc(data, case): data[-20] ^= 1
    def bound_input(data, case):
        p = case/'grass.crp'; p.write_bytes(p.read_bytes()+b'\n')
    mutations.update(legacy=legacy, missing=missing, extra=extra, crc=bad_crc, changed_input=bound_input)
    for name, mutate in mutations.items(): run('reject_'+name, 525, checkpoint, mutate, True)
    sentinel = run('finite_sentinel', 525, checkpoint, change(0, -123.456789))
    observed = rows(sentinel, 'crop.csv')
    assert all(float(row['pressure_average_cm']) == -123.456789 for row in observed)
    # The diagnostic intervention must not alter the physical endpoint or budget.
    sr = (sentinel/'checkpoint.bin').read_bytes(); wr = (whole/'checkpoint.bin').read_bytes()
    assert sr[:-20] == wr[:-20] and sr[-12:-4] == wr[-12:-4]
    assert (sentinel/'budget.csv').read_bytes() == (whole/'budget.csv').read_bytes()
    result = dict(status='NATIVE_COPIED_APP_DIAGNOSTIC_RESTART_AND_REFUSALS_PASS', platform=os.name,
                  executable_sha256=sha(exe), pressures_at524=pressures, exact_suffix_rows=comparisons,
                  uninterrupted_endpoint_sha256=sha(uninterrupted/'checkpoint.bin'),
                  refusal_count=len(mutations), finite_sentinel_restored=True,
                  physical_sentinel_noninterference=True, production_admission=False, events=events)
    (out/'RESULT.json').write_text(json.dumps(result, indent=2)+'\n')


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    for n in ('exe', 'inputs', 'output'): p.add_argument('--'+n, type=Path, required=True)
    a = p.parse_args(); qualify(a.exe.resolve(), a.inputs.resolve(), a.output.resolve())

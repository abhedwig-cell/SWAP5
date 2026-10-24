"""Split constant-rain intervals without moving rain events; research only."""
import argparse
import csv
import hashlib
import json
from pathlib import Path
import subprocess
import time


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--base', type=Path, required=True)
    ap.add_argument('--guard-build', type=Path, required=True)
    ap.add_argument('--head-input', type=Path, required=True)
    ap.add_argument('--flux-input', type=Path, required=True)
    ap.add_argument('--restart', required=True)
    ap.add_argument('--stop', type=int, default=153)
    ap.add_argument('--cap-day', type=float, required=True)
    ap.add_argument('--output', type=Path, required=True)
    a = ap.parse_args()
    assert 0 < a.cap_day <= .1
    out = a.output.resolve()
    out.mkdir(parents=True, exist_ok=False)
    base = a.base.resolve()
    guard = a.guard_build.resolve()
    r = dict(status='RESEARCH_RUNNING', production_qualified=False,
             partition='balanced-original-event', cap_day=a.cap_day, events=[], cases={})

    def save():
        (out / 'RESULT.json').write_text(json.dumps(r, indent=2) + '\n')

    def run(cmd, cwd, label):
        cmd = list(map(str, cmd))
        t = time.perf_counter()
        try:
            p = subprocess.run(cmd, cwd=cwd, capture_output=True, timeout=120)
            code, stdout, stderr = p.returncode, p.stdout, p.stderr
        except subprocess.TimeoutExpired as e:
            code, stdout, stderr = 'CENSORED', e.stdout or b'', e.stderr or b''
        (out / (label + '.stdout')).write_bytes(stdout)
        (out / (label + '.stderr')).write_bytes(stderr)
        r['events'].append(dict(label=label, command=cmd, returncode=code,
                                seconds=time.perf_counter() - t))
        save()
        return code

    original = (base / 'main.f90').read_text()
    needle = '      endpoint=min(day_end,rain_ends(idx))'
    assert original.count(needle) == 1
    # Partition each remaining true event in equal bounded pieces. Repeated
    # cursor+cap can leave a sub-picosecond final interval at an exact day end.
    text = original.replace(needle, needle + '\n' +
        '      endpoint=cursor+(endpoint-cursor)/real(max(1,ceiling((endpoint-cursor)/' +
        format(a.cap_day, '.17e') + '_real64)),real64)')
    needle = '      if(cursor<day_end)idx=idx+1'
    assert text.count(needle) == 1
    text = text.replace(needle, '      if(cursor<day_end.and.cursor>=rain_ends(idx))idx=idx+1')
    main_source = out / 'main.f90'
    main_source.write_text(text)
    r['main_sha256'] = hashlib.sha256(main_source.read_bytes()).hexdigest()
    r['restart_sha256'] = None if a.restart == '-' else hashlib.sha256(Path(a.restart).read_bytes()).hexdigest()
    link = next(e['command'] for e in json.loads((guard / 'RESULT.json').read_text())['events']
                if e['label'] == 'project-build')
    cmd = [str(main_source) if x == str(base / 'main.f90') else
           str(out / 'project') if x == str(guard / 'project') else
           '-J' + str(out) if x.startswith('-J') else x for x in link]
    assert run(cmd, out, 'build') == 0
    for arm, source in [('head', a.head_input), ('flux', a.flux_input)]:
        case = out / arm
        case.mkdir()
        for n in ['input.nml', 'input.swp']:
            (case / n).write_bytes((source / n).read_bytes())
        code = run([out / 'project', 'input.nml', a.restart, a.stop, 'input.swp'], case, arm)
        rows = list(csv.DictReader((case / 'budget.csv').open())) if (case / 'budget.csv').exists() else []
        r['cases'][arm] = dict(returncode=code, published_days=len(rows))
        if code == 0:
            residual = max(abs(float(v['water_residual_cm'])) for v in rows)
            assert residual < 1e-10
            r['cases'][arm]['max_water_residual_cm'] = residual
            assert max(abs(float(v['solute_residual_mg_cm2'])) for v in rows) < 1e-10
            assert all(float(v[k]) == 0 for v in rows for k in
                       ['solute_start_mg_cm2', 'solute_end_mg_cm2', 'solute_in_mg_cm2', 'solute_out_mg_cm2'])
        save()
    r['status'] = 'RESEARCH_COMPLETED' if all(v['returncode'] == 0 for v in r['cases'].values()) else 'RESEARCH_FAILED_OR_CENSORED'
    save()
    print(json.dumps(dict(status=r['status'], cap_day=a.cap_day, cases=r['cases'])))


if __name__ == '__main__':
    main()

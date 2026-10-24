"""Research-only discriminator: dry head versus actual incumbent Darcy exchanges.

Requires a freshly generated historical endpoint build from screen_perf01_geometry.
Never edits production source. Each native call retains raw outputs and its exit.
"""
import argparse
import csv
import hashlib
import json
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--base', type=Path, required=True)
    ap.add_argument('--bundle', type=Path, required=True)
    ap.add_argument('--input', type=Path, required=True)
    ap.add_argument('--output', type=Path, required=True)
    ap.add_argument('--guard', choices=['none', 'dry', 'exchange', 'incumbent'], required=True)
    ap.add_argument('--restart', default='-')
    ap.add_argument('--stop', type=int, default=153)
    a = ap.parse_args()
    out = a.output.resolve()
    out.mkdir(parents=True, exist_ok=False)
    base = a.base.resolve()
    bundle = a.bundle.resolve()
    shared = bundle / 'shared'
    record = dict(status='RUNNING_RESEARCH', production_changed=False,
                  production_qualified=False, guard=a.guard, events=[], source_sha256={})
    sha = lambda b: hashlib.sha256(b).hexdigest()

    def save():
        (out / 'RESULT.json').write_text(json.dumps(record, indent=2) + '\n')

    def run(cmd, cwd, label, cap=120):
        cmd = list(map(str, cmd))
        start = time.perf_counter()
        try:
            p = subprocess.run(cmd, cwd=cwd, capture_output=True, timeout=cap)
            code, stdout, stderr = p.returncode, p.stdout, p.stderr
        except subprocess.TimeoutExpired as e:
            code, stdout, stderr = 'CENSORED', e.stdout or b'', e.stderr or b''
        (out / (label + '.stdout')).write_bytes(stdout)
        (out / (label + '.stderr')).write_bytes(stderr)
        record['events'].append(dict(label=label, command=cmd, returncode=code,
                                     seconds=time.perf_counter() - start))
        save()
        return code

    meta = json.loads((shared / 'build-complete.json').read_text())
    for p, h in meta['input_sha256'].items():
        assert sha((ROOT / p).read_bytes()) == h, p
    record['source_sha256'] = meta['input_sha256']
    link_meta = json.loads((base / 'RESULT.json').read_text())
    commands = {e['label']: e['command'] for e in link_meta['events']}
    source = (base / 'mod_fmr_serialized_reference_backend.f90').read_text()
    start = source.index('  real(real64) function fmr_water_flux_temporal_assessment(')
    end = source.index('  end function', start)
    body = source[start:end]
    needle = '        if(available)value=normalized*self%temporal_tolerance_cm'
    assert body.count(needle) == 1
    if a.guard == 'dry':
        body = body.replace(needle, needle + '''
        value=max(value,maxval(abs(full%pressure_head-half%pressure_head), &
          mask=max(full%pressure_head,half%pressure_head)<0.0_real64))''')
    elif a.guard in ['exchange', 'incumbent']:
        extra = ',.true.' if a.guard == 'exchange' else ''
        body = body.replace(needle, needle + '\n        value=max(value, &\n' +
                            '          fmr_weather_surface_temporal_error(self,full_state,half_state' + extra + '))')
    source = source[:start] + body + source[end:]
    if a.guard == 'exchange':
        # Call the actual existing Darcy assessment; suppress only its dry-head
        # component for this discriminator. All other callers retain old behavior.
        old = 'function fmr_weather_surface_temporal_error(self,full_state,half_state) result(value)'
        assert source.count(old) == 1
        source = source.replace(old, old.replace('half_state)', 'half_state,exchange_only)'))
        start = source.index('  real(real64) function fmr_weather_surface_temporal_error(')
        end = source.index('  end function', start)
        part = source[start:end]
        part = part.replace('    logical::ok', '    logical,intent(in),optional::exchange_only\n    logical::ok', 1)
        needle2 = '        value=max(head_error,storage_error,abs(full%ponding_depth-half%ponding_depth))'
        assert part.count(needle2) == 1
        part = part.replace(needle2, '''        if(present(exchange_only))then
          if(exchange_only)head_error=0.0_real64
        end if
''' + needle2)
        source = source[:start] + part + source[end:]
    backend = out / 'mod_fmr_serialized_reference_backend.f90'
    backend.write_text(source)
    cmd = [str(backend) if x == str(base / backend.name) else
           str(out / 'backend.o') if x == str(base / 'backend.o') else
           '-J' + str(out) if x.startswith('-J') else x for x in commands['backend-build']]
    assert run(cmd, out, 'backend-build') == 0
    assert (out / 'mod_fmr_serialized_reference_backend.mod').read_bytes() == (base / 'mod_fmr_serialized_reference_backend.mod').read_bytes()

    metric_path = ROOT / 'src/process/mod_pond_water_temporal_difference.f90'
    metric = metric_path.read_text()
    needle = 'output_error=abs(output(1)-output(2)-output(3))/dt'
    assert metric.count(needle) == 1
    metric = metric.replace(needle, needle[:-3]).replace(
        'output_error/policy%output_rate_budget_cm_day', 'output_error/(0.001_real64)')
    generated_metric = out / metric_path.name
    generated_metric.write_text(metric)
    old = next(e['command'] for e in meta['events'] if str(metric_path) in e['command'])
    metric_obj = old[-1]
    cmd = [str(generated_metric) if x == str(metric_path) else
           str(out / 'metric.o') if x == metric_obj else
           '-J' + str(out) if x.startswith('-J') else x for x in old]
    assert run(cmd, out, 'metric-build') == 0
    assert (out / 'mod_pond_water_temporal_difference.mod').read_bytes() == (shared / 'mod_pond_water_temporal_difference.mod').read_bytes()
    cmd = [str(out / 'project') if x == str(base / 'project') else
           str(out / 'backend.o') if x == str(base / 'backend.o') else
           str(out / 'metric.o') if x == metric_obj else
           '-J' + str(out) if x.startswith('-J') else x for x in commands['project-build']]
    assert run(cmd, out, 'project-build') == 0
    for p in [backend, generated_metric, base / 'main.f90', base / 'mod_fmr_b111_pond_joint_application.f90']:
        record.setdefault('generated_sha256', {})[str(p)] = sha(p.read_bytes())
    case = out / 'case'
    case.mkdir()
    for n in ['input.nml', 'input.swp']:
        (case / n).write_bytes((a.input / n).read_bytes())
    code = run([out / 'project', 'input.nml', a.restart, a.stop, 'input.swp'], case, 'native')
    rows = list(csv.DictReader((case / 'budget.csv').open())) if (case / 'budget.csv').exists() else []
    record['published_days'] = len(rows)
    if code == 0:
        assert rows
        record['max_water_residual_cm'] = max(abs(float(r['water_residual_cm'])) for r in rows)
        assert record['max_water_residual_cm'] < 1e-10
        record['max_solute_residual_mg_cm2'] = max(abs(float(r['solute_residual_mg_cm2'])) for r in rows)
        assert record['max_solute_residual_mg_cm2'] < 1e-10
        assert all(float(r[k]) == 0 for r in rows for k in
                   ['solute_start_mg_cm2', 'solute_end_mg_cm2', 'solute_in_mg_cm2', 'solute_out_mg_cm2'])
    record['status'] = 'RESEARCH_COMPLETED' if code == 0 else 'RESEARCH_FAILED_OR_CENSORED'
    save()
    print(json.dumps({k: record[k] for k in ['status', 'guard', 'published_days']}))


if __name__ == '__main__':
    main()

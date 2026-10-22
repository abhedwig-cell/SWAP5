"""Observe actual HeadCalc work without modifying production sources.

Reuses a source-verified weather build, links a generated diagnostic HeadCalc,
and checks every daily physical/work value against the uninstrumented run.
Trace times include instrumentation overhead and are not benchmark timings.
"""
import argparse
import csv
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--build', type=Path, required=True)
    ap.add_argument('--reference', type=Path, required=True)
    ap.add_argument('--output', type=Path, required=True)
    ap.add_argument('--weather-build', type=Path, help='Same-executable build with alternate bound rainfall')
    args = ap.parse_args()
    build, reference, output = (p.resolve() for p in (args.build, args.reference, args.output))
    output.mkdir(parents=True, exist_ok=False)
    meta = json.loads((build / 'BUILD.json').read_text())
    control = json.loads((reference / 'RESULT.json').read_text())
    assert meta['status'] == 'BUILT' and control['status'] == 'COMPLETE_NATIVE_OBSERVATION'
    assert sha(build / 'weather') == meta['executable_sha256'] == control['executable_sha256']
    weather_build = args.weather_build.resolve() if args.weather_build else build
    weather_meta = json.loads((weather_build / 'BUILD.json').read_text())
    assert weather_meta['executable_sha256'] == meta['executable_sha256']
    assert sha(weather_build / 'weather.999') == weather_meta['weather_sha256'] == control['weather_sha256']
    overrides = {'tests/fsi/fsi04_real_headcalc_stubs.f90': 'grid_stubs.f90',
                 'src/runtime/mod_fmr_serialized_multiswap_runtime.f90': 'observed_serial_runtime.f90',
                 'src/runtime/mod_fmr_production_application_bootstrap.f90': 'observed_bootstrap.f90'}
    for path, expected in meta['sources'].items():
        assert sha(build / overrides[path] if path in overrides else ROOT / path) == expected, path
    for path, key in [('src/runtime/mod_fmr_serialized_multiswap_runtime.f90', 'observer_original_sha256'),
                      ('src/runtime/mod_fmr_production_application_bootstrap.f90', 'surface_observer_original_sha256')]:
        assert sha(ROOT / path) == meta[key]
    source = ROOT / 'src/legacy/b1_10_port/headcalc.f90'
    assert sha(source) == meta['headcalc_sha256']
    text = source.read_text()

    def replace_once(old, new):
        nonlocal text
        assert text.count(old) == 1, old
        text = text.replace(old, new, 1)

    replace_once('   real(8) :: bottom_dkdh', '''   integer :: probe_evals, probe_switches, probe_last_regime, probe_iterations, probe_backtracks
   integer :: probe_start_iterations, probe_start_backtracks
   logical :: probe_ready
   real(8) :: probe_start_cpu, probe_end_cpu, probe_h1, probe_pond, probe_hbottom
   real(8) :: bottom_dkdh''')
    replace_once('   legacy_state_binding = .not. present(state_binding)', '''   probe_ready=.false.
   probe_evals=0; probe_switches=0; probe_last_regime=-1
   call cpu_time(probe_start_cpu)
   legacy_state_binding = .not. present(state_binding)''')
    replace_once('   corner_retry_active = .false.', '''   probe_h1=state%hm1(1); probe_pond=state%pondm1
   probe_hbottom=state%hm1(numnod)
   probe_start_iterations=ctx%diagnostics%jacobian_builds
   probe_start_backtracks=ctx%diagnostics%backtracking_attempts
   probe_ready=.true.
   corner_retry_active = .false.''')
    replace_once('      select case (provider_dynamic_top_result%regime)', '''      probe_evals=probe_evals+1
      if(probe_last_regime/=-1.and.probe_last_regime/=provider_dynamic_top_result%regime) &
        probe_switches=probe_switches+1
      probe_last_regime=provider_dynamic_top_result%regime
      select case (provider_dynamic_top_result%regime)''')
    body, helpers = text.split('\ncontains\n', 1)
    body, return_count = re.subn(r'^(\s*)return\s*$', r'\1call probe_emit()\n\1return', body, flags=re.M)
    assert return_count == 8, return_count
    emitter = '''
subroutine probe_emit()
   if(.not.probe_ready)return
   call cpu_time(probe_end_cpu)
   probe_iterations=ctx%diagnostics%jacobian_builds-probe_start_iterations
   probe_backtracks=ctx%diagnostics%backtracking_attempts-probe_start_backtracks
   write(*,'(a,7(1x,es25.17e3),7(1x,i0))') 'SURFACE_WORK', &
     dt,probe_h1,probe_pond,probe_end_cpu-probe_start_cpu, &
     probe_hbottom,state%h(1),state%h(numnod), &
     probe_evals,probe_switches,probe_iterations,probe_backtracks, &
     merge(1,0,corner_retry_active),merge(1,0,ctx%control%request_dt_reduction),probe_last_regime
end subroutine probe_emit
'''
    generated = output / 'headcalc_observed.f90'
    generated.write_text(body + '\ncontains\n' + emitter + helpers)
    flags = [f for f in meta['flags'] if not f.startswith(('-I', '-J'))]
    flags += ['-I' + str(build), '-J' + str(output)]
    objects = [build / f'{i:04d}.o' for i in range(len(meta['sources']))]
    command = meta['compiler_command'] + flags + [str(build / 'driver.f90'), str(generated)]
    command += [str(p) for p in objects] + ['-o', str(output / 'weather')]
    result = subprocess.run(command, capture_output=True)
    (output / 'link.stdout').write_bytes(result.stdout)
    (output / 'link.stderr').write_bytes(result.stderr)
    result.check_returncode()
    diagnostic_meta = {**meta, 'executable_sha256': sha(output / 'weather'),
                       'weather_sha256': weather_meta['weather_sha256']}
    (output / 'BUILD.json').write_text(json.dumps(diagnostic_meta, indent=2) + '\n')
    (output / 'weather.999').write_bytes((weather_build / 'weather.999').read_bytes())
    native = output / 'native'
    subprocess.run([sys.executable, str(ROOT / 'benchmarks/performance/run_perf01_weather_bound.py'),
                    '--build', str(output), '--output', str(native),
                    '--expected-rain-mm', str(control['expected_rain_mm']),
                    '--budget', str(control['head_budget_cm']), '--days', str(control['days']),
                    '--windows', str(control['windows_per_day']), '--timeout', '120'],
                   stdout=subprocess.DEVNULL, check=True)
    def physical(path):
        return [{k: v for k, v in row.items() if k != 'core_cpu_s'}
                for row in csv.DictReader(path.open())]
    assert physical(native / 'daily.csv') == physical(reference / 'daily.csv'), 'physical/work drift'
    clean = b''.join(line for line in (native / 'stdout').read_bytes().splitlines(keepends=True)
                     if not line.startswith(b'SURFACE_WORK'))
    assert clean == (reference / 'stdout').read_bytes(), 'physical receipt drift'
    traces = []
    day = 1
    for line in (native / 'stdout').read_text().splitlines():
        if line.startswith('SURFACE_WORK'):
            values = line.split()[1:]
            row = dict(zip(['dt', 'h1', 'pond', 'cpu', 'hbottom', 'final_h1', 'final_hbottom'],
                           map(float, values[:7])))
            row.update(zip(['evaluations', 'switches', 'newton', 'backtracks', 'corner', 'failed', 'regime'],
                           map(int, values[7:])))
            row['day'] = day
            traces.append(row)
        elif 'COMPLETED_DAY' in line:
            day += 1
    assert traces and len(physical(native / 'daily.csv')) == 97
    daily = list(csv.DictReader((reference / 'daily.csv').open()))
    assert sum(int(row['headcalc_calls']) for row in daily) == len(traces), 'missing solve traces'
    groups = {}
    for label, predicate in [('all', lambda r: True), ('switching', lambda r: r['switches'] > 0),
                              ('no_switch', lambda r: r['switches'] == 0),
                              ('failed', lambda r: r['failed'] > 0),
                              ('corner_restart', lambda r: r['corner'] > 0),
                              ('failed_saturated_top_entry', lambda r: r['failed'] > 0 and r['h1'] >= 0),
                              ('failed_bottom_within_0p01cm', lambda r: r['failed'] > 0 and abs(r['hbottom']) <= 0.01)]:
        rows = [r for r in traces if predicate(r)]
        groups[label] = {'calls': len(rows), **{k: sum(r[k] for r in rows) for k in
                        ['cpu', 'evaluations', 'switches', 'newton', 'backtracks', 'failed', 'corner']}}
    result = {'status': 'OBSERVED_WORK_PHYSICAL_AND_WORK_EXACT', 'production_changed': False,
              'baseline': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
              'build': str(build), 'reference': str(reference), 'link_command': command,
              'probe_script_sha256': sha(Path(__file__)), 'headcalc_sha256': sha(source),
              'observed_headcalc_sha256': sha(generated), 'original_build_sha256': sha(build / 'BUILD.json'),
              'physical_and_receipt_identity': True, 'tolerance_cm': control['head_budget_cm'],
              'rain_mm': control['expected_rain_mm'], 'groups': groups,
              'limitation': 'Observed CPU includes tracing overhead; association is not causal attribution.',
              'days': [{**{'day': i}, **{k: sum(r[k] for r in traces if r['day'] == i)
                        for k in ['cpu', 'switches', 'newton', 'backtracks', 'failed', 'corner']}}
                       for i in range(1, 98)]}
    (output / 'RESULT.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({'status': result['status'], 'groups': groups}))


if __name__ == '__main__':
    main()

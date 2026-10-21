"""Real production runtime, fixed-horizon error/cost and restart observations.

Instrumentation observes the actual column executable; no shadow runtime or
policy injection. Both numerical policies are selected through production input.
"""
import argparse
import csv
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]
FILES = ['budget.csv', 'state.csv', 'endpoint.csv', 'restart.bin']


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return list(csv.DictReader(path.open()))


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--build', type=Path, required=True)
    ap.add_argument('--incumbent-build', type=Path, required=True)
    ap.add_argument('--output', type=Path, required=True)
    ap.add_argument('--suite', choices=['short', 'pilot', 'long'], required=True)
    ap.add_argument('--tolerances', type=float, nargs='+', default=[1e-6, 2.5e-7, 6.25e-8, 1e-8])
    ap.add_argument('--cases', nargs='+')
    ap.add_argument('--repeat', type=int, default=1)
    ap.add_argument('--timeout', type=float, default=120)
    args = ap.parse_args()
    base, old, out = args.build.resolve(), args.incumbent_build.resolve(), args.output.resolve()
    out.mkdir(parents=True, exist_ok=False)
    spec = importlib.util.spec_from_file_location('study', ROOT/'tools/performance/study_perf01_temporal.py')
    study = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(study)
    manifest = json.loads((base/'build-complete.json').read_text())
    assert all(sha(ROOT/p) == h for p, h in manifest['input_sha256'].items())
    assert sha(base/'swap5_solute_column') == manifest['executable_sha256']
    incumbent = json.loads((old/'build-complete.json').read_text())
    assert sha(old/'swap5_solute_column') == incumbent['executable_sha256']
    changed = {'src/runtime/mod_canonical_interval_runtime.f90', 'app/solute_column/main.f90'}
    assert manifest['input_sha256'].keys() == incumbent['input_sha256'].keys()
    for p, h in incumbent['input_sha256'].items():
        raw = subprocess.check_output(['git', 'show', '9c16572a:'+p], cwd=ROOT)
        assert hashlib.sha256(raw).hexdigest() == h
        if p not in changed:
            assert sha(ROOT/p) == h
    report = dict(status='RUNNING_NOT_QUALIFIED', suite=args.suite, build=manifest,
                  incumbent_executable_sha256=incumbent['executable_sha256'], runs=[], summary=[],
                  candidate=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
                  controller_sha256=sha(Path(__file__)), tolerances=args.tolerances)
    generated = study.build_main(base, manifest, out/'observer', False, False)
    report['generated'] = generated
    (out/'driver.py').write_bytes(Path(__file__).read_bytes())

    def save():
        (out/'CONTROL.json').write_text(json.dumps(report, indent=2)+'\n')

    def execute(exe, source, directory, stop=128, restart=None, expected_success=True):
        directory.mkdir()
        cmd = [str(exe), str(source), str(restart) if restart else '-', str(stop)]
        record = dict(directory=str(directory.relative_to(out)), command=cmd)
        start = time.monotonic()
        with (directory/'stdout').open('wb') as so, (directory/'stderr').open('wb') as se:
            try:
                p = subprocess.run(cmd, cwd=directory, stdout=so, stderr=se, timeout=args.timeout,
                                   preexec_fn=lambda: os.sched_setaffinity(0, {max(os.sched_getaffinity(0))}))
                record['exit'] = p.returncode
            except subprocess.TimeoutExpired:
                record['exit'] = 'TIMEOUT'
        record['wall_seconds'] = time.monotonic()-start
        report['runs'].append(record)
        if record['exit'] != 0:
            report['status'] = 'NATIVE_FAILED_OR_CENSORED_NOT_QUALIFIED'
            save()
            raise RuntimeError('native failure/censoring retained: '+str(directory))
        record['files'] = {f: sha(directory/f) for f in FILES}
        if (directory/'work.csv').exists():
            work = read(directory/'work.csv')
            record['cpu'] = sum(float(r['cpu']) for r in work)
            record['work'] = {k: sum(int(r[k]) for r in work) for k in study.FIELDS}
            assert record['work']['mass_rejections'] == 0
            assert len(read(directory/'trajectory.csv')) == len(work)*len(read(directory/'state.csv'))
        budget = read(directory/'budget.csv')
        record['water_residual'] = max(abs(float(r['water_residual_cm'])) for r in budget)
        record['solute_residual'] = max(abs(float(r['solute_residual_mg_cm2'])) for r in budget)
        save()
        return record

    cases = study.cases()
    if args.suite != 'short':
        # Also stress infiltration into the initially dry profile. The no-rain
        # dry32 control alone has no solver rejections at coarse tolerance.
        cases['dry_infiltration32'] = cases['dry32']
    report_windows = 8 if args.suite == 'short' else 64
    report['report_windows'] = report_windows
    if args.suite != 'short':
        # Keep the same 24 h horizon and 1.5 h forcing blocks, reporting four
        # times per block. Fine OFF previously exceeded the strict 100000-entry
        # chemical trace contract with sixteen reports; do not relax that bound.
        for name, text in cases.items():
            text = re.sub(r'(?m)^ windows=.*$', ' windows=64', text)
            text = re.sub(r'(?m)^ ends_day=.*$', ' ends_day='+','.join(str((i+1)/64) for i in range(64)), text)
            for field, value in [('rain_cm_day', '.25'), ('irrigation_cm_day', '.25'),
                                 ('runon_cm_day', '.5'), ('evaporation_cm_day', '.05')]:
                values = '64*'+value
                if name == 'dry32' and field != 'evaporation_cm_day':
                    values = '64*0'
                if name == 'pulse4' and field != 'evaporation_cm_day':
                    blocks = [0,0,5,0,0,2,0,0]*2 if field == 'rain_cm_day' else [0]*16
                    values = ','.join(str(v) for v in blocks for _ in range(4))
                text = re.sub(r'(?m)^ '+field+r'=.*$', ' '+field+'='+values, text)
            cases[name] = text
    selected = args.cases or (list(cases) if args.suite == 'short' else ['pond4', 'dry32', 'pulse4'])
    for name in selected:
        case = out/name
        case.mkdir()
        for tol in args.tolerances:
            sources = {}
            for policy in ['off', 'on']:
                source = case/(str(tol)+'-'+policy+'.nml')
                text = cases[name].replace('&column\n', '&column\n temporal_tolerance='+str(tol)+'\n')
                if policy == 'on':
                    text = text.replace('&column\n', '&column\n retain_accepted_step_proposal=.true.\n')
                source.write_text(text)
                sources[policy] = source
            for repeat in range(args.repeat if tol == args.tolerances[0] else 1):
                for policy in (['off', 'on'] if repeat % 2 == 0 else ['on', 'off']):
                    execute(out/'observer/column', sources[policy], case/f'{tol}-{policy}-{repeat}')
        if args.suite == 'pilot':
            continue
        original = execute(base/'swap5_solute_column', case/(str(args.tolerances[0])+'-off.nml'), case/'original')
        default = next(r for r in report['runs'] if r['directory'] == name+'/'+str(args.tolerances[0])+'-off-0')
        assert original['files'] == default['files'], 'observer physical perturbation'
        legacy = execute(old/'swap5_solute_column', case/(str(args.tolerances[0])+'-off.nml'), case/'incumbent')
        assert legacy['files'] == default['files'], 'default OFF preservation'
        windows = report_windows
        for policy in ['off', 'on']:
            execute(out/'observer/column', case/(str(args.tolerances[0])+'-'+policy+'.nml'),
                    case/(policy+'-prefix'), stop=windows//2)
            execute(out/'observer/column', case/(str(args.tolerances[0])+'-'+policy+'.nml'),
                    case/(policy+'-restart'), restart=case/(policy+'-prefix/restart.bin'))
            full = case/(str(args.tolerances[0])+'-'+policy+'-0')
            resumed = case/(policy+'-restart')
            assert all((full/f).read_bytes() == (resumed/f).read_bytes() for f in FILES[1:])
            for f in ['budget.csv', 'trajectory.csv']:
                assert [r for r in read(full/f) if int(r['window']) > windows//2] == read(resumed/f)
        summary = dict(case=name, default_off_exact=True, restarts_exact=True, errors={})
        for tol in args.tolerances:
            for policy in ['off', 'on']:
                path = case/(str(tol)+'-'+policy+'-0')
                summary['errors'][str(tol)+'-'+policy] = {
                    ref: study.errors(path, case/(str(args.tolerances[-1])+'-'+ref+'-0')) for ref in ['off', 'on']}
        for policy in ['off', 'on']:
            observations = [r for r in report['runs'] if re.fullmatch(name+'/'+str(args.tolerances[0])+r'-'+policy+r'-\d+', r['directory'])]
            assert all(r['files'] == observations[0]['files'] and r['work'] == observations[0]['work'] for r in observations)
            import statistics
            summary[policy] = dict(cpu_median=statistics.median(r['cpu'] for r in observations), work=observations[0]['work'])
        summary['speedup'] = summary['off']['cpu_median']/summary['on']['cpu_median']
        report['summary'].append(summary)
        save()
        print(json.dumps(summary), flush=True)
    report['status'] = 'PILOT_COMPLETE_NOT_QUALIFIED' if args.suite == 'pilot' else 'PHYSICAL_ERROR_COST_RESTART_PASS_NOT_ADMITTED'
    save()
    print(report['status'], flush=True)


if __name__ == '__main__':
    main()

"""Three paired repeats at bounded, measured state-error dominance.

Use the same two finite references for both policies. Select the cheapest tested
proposal by HeadCalc/iteration counts whose head/theta/concentration errors do not exceed default tolerance
1e-6 errors against either reference. Other errors remain reported separately.
This is not an assertion of identical global accuracy or an exact solution.
"""
import argparse
import csv
import hashlib
import json
import os
from pathlib import Path
import statistics
import subprocess
import time


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--study', type=Path, required=True)
    ap.add_argument('--output', type=Path, required=True)
    args = ap.parse_args()
    study, out = args.study.resolve(), args.output.resolve()
    out.mkdir(parents=True, exist_ok=False)
    source = json.loads((study/'CONTROL.json').read_text())
    assert source['status'] == 'PHYSICAL_ERROR_COST_RESTART_PASS_NOT_ADMITTED'
    report = dict(status='RUNNING_NOT_QUALIFIED', study_sha256=hashlib.sha256((study/'CONTROL.json').read_bytes()).hexdigest(),
                  driver_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(), cases=[], runs=[])
    (out/'driver.py').write_bytes(Path(__file__).read_bytes())

    def save():
        (out/'MATCHED.json').write_text(json.dumps(report, indent=2)+'\n')

    for case in source['summary']:
        name = case['case']
        scores = case['errors']
        eligible = []
        for tol in source['tolerances']:
            key = str(tol)+'-on'
            if all(scores[key][ref][field] <= scores['1e-06-off'][ref][field]
                   for ref in ['off', 'on'] for field in ['head', 'theta', 'concentration']):
                run = next(r for r in source['runs'] if r['directory'] == name+'/'+key+'-0')
                w = run['work']
                eligible.append((w['headcalc_calls'], w['nonlinear_iterations'], w['attempts'], -tol, tol, w))
        if not eligible:
            report['status'] = 'NO_ERROR_DOMINATING_PROPOSAL_NOT_QUALIFIED'
            save()
            raise RuntimeError('no tested state-error dominating proposal: '+name)
        _, _, _, _, tol, work = min(eligible)
        observed = {'off': [], 'on': []}
        for repeat in range(3):
            for policy in (['off', 'on'] if repeat % 2 == 0 else ['on', 'off']):
                directory = out/f'{name}-{policy}-{repeat}'
                directory.mkdir()
                chosen = 1e-6 if policy == 'off' else tol
                input_path = study/name/(str(chosen)+'-'+policy+'.nml')
                cmd = [str(study/'observer/column'), str(input_path), '-', '128']
                start = time.monotonic()
                with (directory/'stdout').open('wb') as so, (directory/'stderr').open('wb') as se:
                    try:
                        p = subprocess.run(cmd, cwd=directory, stdout=so, stderr=se, timeout=120,
                                           preexec_fn=lambda: os.sched_setaffinity(0, {max(os.sched_getaffinity(0))}))
                        code = p.returncode
                    except subprocess.TimeoutExpired:
                        code = 'TIMEOUT'
                record = dict(directory=directory.name, command=cmd, exit=code, wall_seconds=time.monotonic()-start)
                report['runs'].append(record)
                if code != 0:
                    report['status'] = 'NATIVE_FAILED_OR_CENSORED_NOT_QUALIFIED'
                    save()
                    raise RuntimeError('matched native failed: '+directory.name)
                reference = study/name/(str(chosen)+'-'+policy+'-0')
                for file in ['state.csv', 'endpoint.csv', 'restart.bin', 'budget.csv', 'trajectory.csv']:
                    assert (directory/file).read_bytes() == (reference/file).read_bytes(), 'matched physical replay'
                rows = list(csv.DictReader((directory/'work.csv').open()))
                record['cpu'] = sum(float(r['cpu']) for r in rows)
                observed[policy].append(record['cpu'])
                save()
        result = dict(case=name, proposal_tolerance=tol, selected_numeric_work=work,
                      default_errors=scores['1e-06-off'], proposal_errors=scores[str(tol)+'-on'],
                      state_error_fields=['head', 'theta', 'concentration'], both_finite_references=True,
                      cpu_samples=observed, speedup=statistics.median(observed['off'])/statistics.median(observed['on']))
        report['cases'].append(result)
        save()
        print(json.dumps(result), flush=True)
    report['status'] = 'STATE_ERROR_DOMINANCE_PAIRED_COST_PASS_NOT_ADMITTED'
    save()


if __name__ == '__main__':
    main()

"""Read actual original heat receipts and exercise accepted-only observation guards."""
import argparse
import json
from pathlib import Path
import sys

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'app/hybrid_water'))
import daily_host as h
from heat_receipts import read_accepted_heat

p=argparse.ArgumentParser(description=__doc__);p.add_argument('--runs',type=Path,required=True)
a=p.parse_args();results={}
for folder in sorted(a.runs.iterdir()):
    if not folder.is_dir() or '-' not in folder.name:continue
    key=folder.name.split('-')[0]
    if key not in ('hupsel','grass','andelst'):continue
    project={'hupsel':h.HUPSEL,'grass':h.GRASSGROWTH,'andelst':h.ANDELST}[key]
    window=next(folder.glob('window-*'))
    receipts=[json.loads(l) for l in (window/'daily.jsonl').read_text().splitlines()]
    trace=window/'original/original-heat-accounting.txt'
    report=read_accepted_heat(trace,receipts,project)
    assert len(report['daily'])==2 and all(not r['full_energy_balance_complete'] for r in report['daily'])
    # A calculated but externally unaccepted day never becomes an accepted heat
    # receipt. This is observer bookkeeping, not a new model computation.
    refused=read_accepted_heat(trace,[dict(r,committed=False) for r in receipts],project)
    assert not refused['daily'] and refused['unaccepted_steps_ignored']>0
    first=read_accepted_heat(trace,receipts[:1],project)
    assert len(first['daily'])==1 and first['unaccepted_steps_ignored']>0
    raw=trace.read_text();parts=raw.splitlines();node=next(i for i,l in enumerate(parts) if l.startswith('HEAT_NODE'))
    values=parts[node].split();values[-1]=str(float(values[-1])+.001);parts[node]=' '.join(values)
    bad=window/'bad-heat-face.txt';bad.write_text('\n'.join(parts)+'\n')
    try:read_accepted_heat(bad,receipts,project)
    except ValueError:pass
    else:raise AssertionError('Corrupt actual conductive face accepted')
    # Preserve the failed zero-mass-carried-energy hypothesis as a failed
    # physical comparison, not a reason to widen the existing1e-9 budget.
    report['counterfactual_zero_advection_verdict']='FAIL' if any(
        r['zero_advection_step_residual_max_j_cm2'] is not None and
        r['zero_advection_step_residual_max_j_cm2']>report['energy_budget_j_cm2'] for r in report['daily']) else 'NOT_QUALIFIED'
    report['accepted_only_and_corrupt_face_guards']='PASS'
    results[folder.name]=report
(a.runs/'HEAT_RECEIPTS.json').write_text(json.dumps({'status':'ACCEPTED_HEAT_OBSERVER_AND_FAIL_CLOSED_ENERGY_LIMITS_PASS',
    'results':results,'sources':{n:h.sha(ROOT/n) for n in ['app/hybrid_water/heat_receipts.py',
        'research/hybrid-water01/check_original_heat_accounting.py']}},indent=2)+'\n',encoding='utf-8')
print(json.dumps(results))

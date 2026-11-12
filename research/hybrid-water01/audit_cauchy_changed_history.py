"""Independent actual modified-origin Cauchy input, physical and native audit."""
import argparse
from datetime import date,timedelta
import hashlib
import json
import math
from pathlib import Path
import re
import zipfile

p=argparse.ArgumentParser(description=__doc__)
for n in ['runs','prior','output']:p.add_argument('--'+n,type=Path,required=True)
a=p.parse_args();sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
physical=lambda r:{k:v for k,v in r.items() if k not in ('coupling','revision','column','committed','candidate_only')}
def load(path):
    with zipfile.ZipFile(path) as z:
        m=json.loads(z.read('checkpoint.json'));data={n:z.read(n) for n in ('result.end','macro.bin')}
        for n,digest in m['files'].items():assert hashlib.sha256(z.read(n)).hexdigest()==digest
        assert m['receipt']['committed'] is True
        return m,data
r=json.loads((a.runs/'RESULT.json').read_text());prior=json.loads((a.prior/'RESULT.json').read_text())
assert r['status']=='CAUCHY_ACTUAL_MODIFIED_HISTORY_RETRY_RECOVERY_ORIGINAL_CONTROL_PASS'
assert prior['status']=='ACTUAL_ORIGINAL_CAUCHY_DAILY_FORCING_RETRY_RECOVERY_PASS'
assert prior['sources']['app/hybrid_water/daily_coupling.py']==r['sources']['app/hybrid_water/daily_coupling.py']
results=[]
for entry in r['cases']:
    root=a.runs/entry['optimization'];old=a.prior/entry['optimization']
    baseline,baseline_data=load(old/'external/accepted-column-1-day-21.zip')
    first,first_data=load(root/'external/accepted-column-1-day-21.zip')
    final,final_data=load(root/'external/accepted-column-1-day-22.zip')
    disk,disk_data=load(root/'recovered/accepted-column-1-day-22.zip')
    assert physical(first['receipt'])!=physical(baseline['receipt']) and first_data!=baseline_data
    assert first['receipt']['coupling']['origin_sha256']==entry['origin_sha256']==sha(root/'accepted-origin-day-20.zip')
    assert entry['origin_sha256']==baseline['receipt']['coupling']['origin_sha256']
    assert final['receipt']['coupling']['origin_sha256']==sha(root/'external/accepted-column-1-day-21.zip')
    assert final['receipt']==disk['receipt'] and final_data==disk_data
    for i,day in enumerate([21,22]):
        rejected,rejected_data=load(root/f'external/trial-{2*i+1}/accepted-column-1-day-{day}.zip')
        retry,retry_data=load(root/f'external/trial-{2*i+2}/accepted-column-1-day-{day}.zip')
        accepted,accepted_data=(first,first_data) if i==0 else (final,final_data)
        control,control_data=load(root/f'manual-control-{day-1}/accepted-column-1-day-{day}.zip')
        assert rejected_data==retry_data==accepted_data==control_data
        assert physical(rejected['receipt'])==physical(retry['receipt'])==physical(accepted['receipt'])==physical(control['receipt'])
        row=accepted['receipt'];c=row['coupling'];f=c['forcing'];x=f['input']
        assert x==entry['requests'][i] and f['mode']=='andelst-cauchy-daily-v1'
        assert hashlib.sha256(json.dumps(x,sort_keys=True,separators=(',', ':'),allow_nan=False).encode()).hexdigest()==f['identity_sha256']
        source=root/f'external/trial-{2*i+2}/original/swap.bbc';assert sha(source)==f['applied_bbc_sha256']
        knots=dict(re.findall(r'(?m)^\s*(\d{4}-\d{2}-\d{2})[ \t]+([-+0-9.]+)[ \t]*$',source.read_text(encoding='cp1252')))
        stamp=date(1998,1,1)+timedelta(days=day-1)
        assert float(knots[str(stamp)])==x['head_start_cm']
        assert float(knots[str(stamp+timedelta(days=1))])==x['head_end_cm']
        assert x['origin_sha256']==c['origin_sha256'] and x['origin_day']==day-1==c['origin_day']
        assert [x['t0_day1900'],x['t1_day1900']]==c['window_day1900'] and x['coupling_id']==c['id']
        flow=row['external_flux_cm'];residual=math.fsum([*flow[:7],*(-v for v in flow[7:]),*row['stock_start_cm'],*(-v for v in row['stock_end_cm'])])
        assert residual==row['independent_residual_cm']
        # Keep the original Andelst hybrid 1e-6cm water gate; never import the stricter nonmacro limit.
        assert abs(residual)<=1e-6
        assert sha(root/f'external/accepted-column-1-day-{day}.zip')==entry['accepted_sha256'][i]
    assert entry['requests'][1]['head_start_cm']==entry['requests'][0]['head_end_cm']
    results.append({'optimization':entry['optimization'],'window':[20,22],'modified_native_origin_proven_against_same_origin_original_control':True,
        'both_day_retries_original_controls_native_exact':True,'second_day_changed_history_live_disk_native_exact':True,
        'water_input_and_state_lineage':'PASS','first_day_bottom_change_cm':first['receipt']['bottom_outward_cm']-baseline['receipt']['bottom_outward_cm']})
out={'status':'INDEPENDENT_CAUCHY_ACTUAL_MODIFIED_HISTORY_NATIVE_INPUT_BALANCE_AUDIT_PASS',
     'cases':results,'auditor_sha256':sha(Path(__file__)),'prior_report_sha256':sha(a.prior/'RESULT.json')}
a.output.write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(out))

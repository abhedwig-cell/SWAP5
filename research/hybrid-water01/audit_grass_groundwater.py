"""Independent accepted native/input/lineage audit of real groundwater runs."""
import argparse
import hashlib
import json
from pathlib import Path
import zipfile

p=argparse.ArgumentParser(description=__doc__);p.add_argument('--runs',type=Path,required=True)
p.add_argument('--output',type=Path,required=True);a=p.parse_args()
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def load(p):
    with zipfile.ZipFile(p) as z:
        m=json.loads(z.read('checkpoint.json'));raw={n:z.read(n) for n in ('result.end','macro.bin')}
        for n,digest in m['files'].items():assert hashlib.sha256(z.read(n)).hexdigest()==digest
        assert m['receipt']['committed'] is True
        return m,raw
physical=lambda r:{k:v for k,v in r.items() if k not in ('coupling','column','revision','committed','candidate_only')}
r=json.loads((a.runs/'RESULT.json').read_text());assert r['status']=='GRASS_ORIGINAL_PRESCRIBED_GROUNDWATER_CHANGED_HISTORY_RETRY_RECOVERY_PASS'
results=[]
for entry in r['cases']:
    cut=entry['cut'];d=cut+1;root=a.runs/entry['optimization']/f'window-{cut}-to-{cut+2}'
    first,first_data=load(root/f'external/trial-1/accepted-column-1-day-{d}.zip')
    retry,retry_data=load(root/f'external/trial-2/accepted-column-1-day-{d}.zip')
    accepted,accepted_data=load(root/f'external/accepted-column-1-day-{d}.zip')
    terminal,terminal_data=load(root/f'external/accepted-column-1-day-{d+1}.zip')
    recovered,recovered_data=load(root/f'recovered/accepted-column-1-day-{d+1}.zip')
    manual0,manual0_data=load(root/f'manual-control-0/accepted-column-1-day-{d}.zip')
    manual1,manual1_data=load(root/f'manual-control-1/accepted-column-1-day-{d+1}.zip')
    assert first_data==retry_data==accepted_data==manual0_data
    assert physical(first['receipt'])==physical(retry['receipt'])==physical(accepted['receipt'])==physical(manual0['receipt'])
    assert terminal_data==recovered_data==manual1_data
    assert terminal['receipt']==recovered['receipt']
    assert physical(terminal['receipt'])==physical(manual1['receipt'])
    assert sha(root/f'external/accepted-column-1-day-{d+1}.zip')==entry['terminal_sha256']
    for m,folder in [(accepted,root/'external/trial-2/original'),(terminal,root/'external/trial-3/original'),
                     (recovered,root/'recovered/trial-1/original')]:
        c=m['receipt']['coupling'];f=c['forcing'];x=f['input']
        assert f['mode']=='grass-groundwater-daily-v1'
        assert hashlib.sha256(json.dumps(x,sort_keys=True,separators=(',', ':'),allow_nan=False).encode()).hexdigest()==f['identity_sha256']
        assert sha(folder/'swap.bbc')==f['applied_bbc_sha256']
        assert x['origin_sha256']==c['origin_sha256'] and x['origin_day']==c['origin_day']
        assert [x['t0_day1900'],x['t1_day1900']]==c['window_day1900'] and x['coupling_id']==c['id']
        assert abs(m['receipt']['independent_residual_cm'])<=1e-10
    assert terminal['receipt']['coupling']['origin_sha256']==sha(root/f'external/accepted-column-1-day-{d}.zip')
    for trial in ['trial-1','trial-2','trial-3']:
        m,_=load(next((root/'external'/trial).glob('accepted-column-1-day-*.zip')))
        assert m['binding']['external_groundwater_trial']['mode']=='grass-groundwater-daily-v1'
    results.append({'optimization':entry['optimization'],'window':[cut,cut+2],
        'actual_modified_state_disk_recovery_exact':True,'actual_independent_original_controls_both_days_exact':True,
        'actual_retry_native_payloads_exact':True,'forcing_and_applied_input_lineage':'PASS'})
out={'status':'INDEPENDENT_GROUNDWATER_MODIFIED_HISTORY_NATIVE_INPUT_LINEAGE_CONTROL_AUDIT_PASS',
     'cases':results,'auditor_sha256':sha(Path(__file__))}
a.output.write_text(json.dumps(out,indent=2)+'\n',encoding='utf-8');print(json.dumps(out))

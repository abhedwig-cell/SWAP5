"""Independently inspect actual Cauchy proposal/accept/recovery evidence; no model."""
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
        m=json.loads(z.read('checkpoint.json'))
        data={n:z.read(n) for n in ('result.end','macro.bin')}
        for n,digest in m['files'].items():assert hashlib.sha256(z.read(n)).hexdigest()==digest
        assert m['receipt']['committed'] is True
        return m,data
physical=lambda r:{k:v for k,v in r.items() if k not in ('coupling','revision','column','committed','candidate_only')}
summary=[]
r=json.loads((a.runs/'RESULT.json').read_text());assert r['status']=='ACTUAL_ORIGINAL_CAUCHY_DAILY_FORCING_RETRY_RECOVERY_PASS'
for case in r['cases']:
    root=a.runs/case['optimization'];cut=case['cut'];day=cut+1
    first,first_data=load(root/f'external/trial-1/accepted-column-1-day-{day}.zip')
    retry,retry_data=load(root/f'external/trial-2/accepted-column-1-day-{day}.zip')
    accepted,accepted_data=load(root/f'external/accepted-column-1-day-{day}.zip')
    original,original_data=load(root/f'original-control/trial-1/accepted-column-1-day-{day}.zip')
    shifted,shift_data=load(root/f'shifted/accepted-column-1-day-{day}.zip')
    manual,manual_data=load(root/f'manual-control/accepted-column-1-day-{day}.zip')
    terminal,terminal_data=load(root/f'external/accepted-column-1-day-{day+1}.zip')
    restored,restored_data=load(root/f'recovered/accepted-column-1-day-{day+1}.zip')
    assert first_data==retry_data==accepted_data==original_data
    assert physical(first['receipt'])==physical(retry['receipt'])==physical(accepted['receipt'])==physical(original['receipt'])
    assert shift_data==manual_data and physical(shifted['receipt'])==physical(manual['receipt'])
    assert physical(shifted['receipt'])!=physical(accepted['receipt'])
    assert terminal_data==restored_data and terminal['receipt']==restored['receipt']
    for m,folder in [(accepted,root/'external/trial-2/original'),(shifted,root/'shifted/trial-1/original'),
                     (terminal,root/'external/trial-3/original'),(restored,root/'recovered/trial-1/original')]:
        c=m['receipt']['coupling'];f=c['forcing'];x=f['input']
        assert f['mode']=='andelst-cauchy-daily-v1'
        digest=hashlib.sha256(json.dumps(x,sort_keys=True,separators=(',', ':'),allow_nan=False).encode()).hexdigest()
        assert digest==f['identity_sha256'] and sha(folder/'swap.bbc')==f['applied_bbc_sha256']
        assert x['origin_sha256']==c['origin_sha256'] and x['origin_day']==c['origin_day']
        assert [x['t0_day1900'],x['t1_day1900']]==c['window_day1900']
        assert x['coupling_id']==c['id'] and x['provenance']
    for trial in ['trial-1','trial-2','trial-3']:
        private,_=load(next((root/'external'/trial).glob('accepted-column-*.zip')))
        assert 'external_cauchy_trial' in private['binding'],'Modified forcing rebound as original-only input'
    assert original['binding'].get('external_cauchy_trial') is None
    for receipt in [first,retry,accepted,original,shifted,manual,terminal,restored]:
        assert abs(receipt['receipt']['independent_residual_cm'])<=1e-6
    summary.append({'optimization':case['optimization'],'window':[cut,cut+2],
        'exact_original_and_retry_native_state':True,'exact_recovery_native_state':True,
        'exact_independent_shifted_original_control':True,'forcing_receipt_and_applied_input_hashes':'PASS',
        'bottom_response_cm':shifted['receipt']['bottom_outward_cm']-accepted['receipt']['bottom_outward_cm'],
        'accepted_terminal_sha256':sha(root/f'external/accepted-column-1-day-{day+1}.zip')})
out={'status':'INDEPENDENT_ACTUAL_CAUCHY_STATE_INPUT_LINEAGE_AND_PHYSICAL_CONTROL_AUDIT_PASS','cases':summary,
     'source_sha256':sha(Path(__file__))}
a.output.write_text(json.dumps(out,indent=2)+'\n',encoding='utf-8');print(json.dumps(out))

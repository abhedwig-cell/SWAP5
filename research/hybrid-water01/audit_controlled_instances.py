"""Independent pending/accepted sibling isolation and original-control audit."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import zipfile

p=argparse.ArgumentParser(description=__doc__)
for n in ['runs','cauchy','groundwater','irrigation','output']:p.add_argument('--'+n,type=Path,required=True)
a=p.parse_args();sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
physical=lambda row:{k:v for k,v in row.items() if k not in ('column','revision','coupling','committed','candidate_only')}
def load(path):
    with zipfile.ZipFile(path) as z:
        m=json.loads(z.read('checkpoint.json'));data={n:z.read(n) for n in ('result.end','macro.bin')}
        for n,digest in m['files'].items():assert hashlib.sha256(z.read(n)).hexdigest()==digest
        return m,data
r=json.loads((a.runs/'RESULT.json').read_text());assert r['status']=='INTERLEAVED_CONTROLLED_PROJECT_INSTANCE_STATE_NATIVE_ISOLATION_PASS'
results=[]
for group in r['groups']:
    opt=group['optimization'];root=a.runs/opt
    archives={sha(p):(p,*load(p)) for p in root.rglob('accepted-column-*.zip')}
    cuts={'andelst':20,'grass':2,'hupsel':4};clocks={'andelst':35795,'grass':29220,'hupsel':37256}
    controls={'andelst':a.cauchy/opt/'external','grass':a.groundwater/opt/'window-2-to-4/external','hupsel':a.irrigation/opt/'modified/external'}
    for e in group['events']:
        owner=e['owner'];before=e['before'];after=e['after'];action=e['action']
        assert all(before[k]==after[k] for k in cuts if k!=owner)
        if action in ('foreign-refusal','cold-reconstruct'):assert before==after
        b,c=before[owner],after[owner]
        if action in ('prepare','discard'):
            for field in ('day','revision','accepted_sha256','coupling_id'):assert b[field]==c[field]
        if action=='discard':assert b['pending_sha256'] is not None and c['pending_sha256'] is None
        if action=='prepare':
            assert b['pending_sha256'] is None and c['pending_sha256'] is not None
            path,m,data=archives[c['pending_sha256']];day=c['day']+1
            expected,raw=load(controls[owner]/f'accepted-column-1-day-{day}.zip')
            assert physical(m['receipt'])==physical(expected['receipt']) and data==raw
        if action=='accept':
            assert c['day']==b['day']+1 and c['revision']==b['revision']+1
            assert b['pending_sha256'] is not None and c['pending_sha256'] is None
            _,candidate,native=archives[b['pending_sha256']];_,accepted,stored=archives[c['accepted_sha256']]
            assert physical(candidate['receipt'])==physical(accepted['receipt']) and native==stored
    assert sum(e['action']=='foreign-refusal' for e in group['events'])==7
    assert sum(e['action']=='discard' for e in group['events'])==2
    assert sum(e['action']=='cold-reconstruct' for e in group['events'])==3
    assert len({s['coupling_id'] for s in group['events'][0]['before'].values()})==3
    for key in cuts:
        previous=None
        for field,day in [('first_endpoints',cuts[key]+1),('final_endpoints',cuts[key]+2)]:
            path=a.runs/group[field][key];m,data=load(path);expected,raw=load(controls[key]/f'accepted-column-1-day-{day}.zip')
            assert physical(m['receipt'])==physical(expected['receipt']) and data==raw
            c=m['receipt']['coupling'];f=c['forcing'];x=f['input'];row=m['receipt']
            assert c['id']=='interleaved-'+opt+'-'+key and c['revision']==day-cuts[key]
            assert x['coupling_id']==c['id'] and x['origin_sha256']==c['origin_sha256']
            assert x['origin_day']==day-1 and [x['t0_day1900'],x['t1_day1900']]==c['window_day1900']==[clocks[key]+day-1,clocks[key]+day]
            assert hashlib.sha256(json.dumps(x,sort_keys=True,separators=(',', ':'),allow_nan=False).encode()).hexdigest()==f['identity_sha256']
            if previous is not None:assert c['origin_sha256']==previous
            previous=sha(path);flow=row['external_flux_cm']
            residual=math.fsum([*flow[:7],*(-v for v in flow[7:]),*row['stock_start_cm'],*(-v for v in row['stock_end_cm'])])
            tol=1e-6 if key=='andelst' else 1e-10
            assert residual==row['independent_residual_cm'] and abs(residual)<=tol and abs(row['kernel_residual_cm'])<=tol
            if key=='hupsel':
                end,delta,rain,irrig,bottom,drain,decay,uptake,reported=row['solute_ledger_mg_cm2']
                residual=math.fsum([end,-row['solute_start_mg_cm2'],-rain,-irrig,-bottom,drain,decay,uptake])
                assert residual==row['solute_independent_residual_mg_cm2'] and abs(residual)<=1e-10 and abs(reported)<=1e-10
    results.append({'optimization':opt,'actual_events':len(group['events']),'accepted_pending_sibling_isolation':'PASS',
        'six_controlled_physical_native_endpoints':'EXACT','foreign_refusals':7,'discards':2,'cold_reconstructions':3,
        'original_calendars_water_solute_and_input_lineage':'PASS'})
out={'status':'INDEPENDENT_CONTROLLED_INSTANCE_INTERLEAVING_STATE_NATIVE_BALANCE_AUDIT_PASS',
     'groups':results,'auditor_sha256':sha(Path(__file__))}
a.output.write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(out))

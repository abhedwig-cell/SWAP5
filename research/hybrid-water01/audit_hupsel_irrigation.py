"""Independent raw accepted-state, actual-input and water/solute event audit."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import zipfile

p=argparse.ArgumentParser(description=__doc__);p.add_argument('--runs',type=Path,required=True)
p.add_argument('--output',type=Path,required=True);p.add_argument('--workspace',type=Path,required=True);a=p.parse_args()
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
physical=lambda r:{k:v for k,v in r.items() if k not in ('coupling','column','revision','committed','candidate_only')}
def load(path):
    with zipfile.ZipFile(path) as z:
        m=json.loads(z.read('checkpoint.json'));data={n:z.read(n) for n in ('result.end','macro.bin')}
        for n,digest in m['files'].items():assert hashlib.sha256(z.read(n)).hexdigest()==digest
        assert m['receipt']['committed'] is True
        return m,data
r=json.loads((a.runs/'RESULT.json').read_text());assert r['status']=='HUPSEL_SURFACE_IRRIGATION_CHANGED_HISTORY_AND_ORIGINAL_PRESERVATION_PASS'
idx=json.loads((a.workspace/'PROOF_INDEX.json').read_text());members=json.loads((a.workspace/'MEMBER_SHA256.json').read_text())
cases=[]
for entry in r['cases']:
    root=a.runs/entry['optimization']/entry['scenario']
    first,data=load(root/'external/trial-1/accepted-column-1-day-5.zip')
    retry,retrydata=load(root/'external/trial-2/accepted-column-1-day-5.zip')
    accepted,accepteddata=load(root/'external/accepted-column-1-day-5.zip')
    final,finaldata=load(root/'external/accepted-column-1-day-6.zip')
    recovered,recovereddata=load(root/'recovered/accepted-column-1-day-6.zip')
    assert data==retrydata==accepteddata and finaldata==recovereddata
    assert physical(first['receipt'])==physical(retry['receipt'])==physical(accepted['receipt'])
    assert final['receipt']==recovered['receipt']
    assert sha(root/'external/accepted-column-1-day-6.zip')==entry['terminal_sha256']
    rows=[json.loads(x) for x in (root/'independent-original-control/daily.jsonl').read_text().splitlines()]
    assert physical(accepted['receipt'])==physical(rows[4]) and physical(final['receipt'])==physical(rows[5])
    for m,folder in [(accepted,root/'external/trial-2/original'),(final,root/'external/trial-3/original'),
                     (recovered,root/'recovered/trial-1/original')]:
        row=m['receipt'];c=row['coupling'];f=c['forcing'];x=f['input']
        assert f['mode']=='hupsel-surface-irrigation-daily-v1'
        assert hashlib.sha256(json.dumps(x,sort_keys=True,separators=(',', ':'),allow_nan=False).encode()).hexdigest()==f['identity_sha256']
        actual=folder/'hybrid-irrigation-day.in';assert sha(actual)==f['applied_irrigation_sha256']
        fields=actual.read_text().split();assert fields[0]=='S5IRR001'
        assert list(map(float,fields[1:]))==[x['t0_day1900'],int(x['enabled']),x['depth_mm'],x['concentration_mg_cm3'],x['rate_mm_h']]
        assert 'HYBRID_IRRIGATION_INPUT' in (folder/'donor.stdout').read_text()
        assert x['origin_sha256']==c['origin_sha256'] and x['origin_day']==c['origin_day']
        assert [x['t0_day1900'],x['t1_day1900']]==c['window_day1900'] and x['coupling_id']==c['id']
        flow=row['external_flux_cm'];start=row['stock_start_cm'];end=row['stock_end_cm']
        water=math.fsum([*flow[:7],*(-v for v in flow[7:]),*start,*(-v for v in end)])
        assert water==row['independent_residual_cm'] and abs(water)<=1e-10 and row['bottom_outward_cm']==0.
        last,delta,rain,irrig,bottom,drain,decay,uptake,reported=row['solute_ledger_mg_cm2']
        solute=math.fsum([last,-row['solute_start_mg_cm2'],-rain,-irrig,-bottom,drain,decay,uptake])
        assert solute==row['solute_independent_residual_mg_cm2'] and abs(solute)<=1e-10 and abs(reported)<=1e-10
        assert abs(irrig-.1*x['depth_mm']*x['concentration_mg_cm3'])<=1e-10
        assert abs(flow[3]-.1*x['depth_mm'])<=1e-10
    assert final['receipt']['coupling']['origin_sha256']==sha(root/'external/accepted-column-1-day-5.zip')
    build=root.parent/'build';meta=json.loads((build/'BUILD.json').read_text());identity=meta['identity'];ext=identity['irrigation_extension']
    assert sha(build/'irrigation.f90')==identity['donor_generated']['irrigation.f90']
    assert sha(build/'irrigation.o')==ext['object_sha256']
    log=json.loads((build/'INCREMENTAL_BUILD.json').read_text());assert len(log)==2 and all(x['exit_code']==0 for x in log)
    assert '-c' in log[0]['command'] and log[0]['command'][-1]=='irrigation.f90'
    native=idx['cases']['hupsel-'+entry['optimization']];base=a.workspace/native['build']
    frozen=a.workspace/native['report']/'gift-seven'
    baseline=[json.loads(x) for x in (root.parent/'no-file-original/daily.jsonl').read_text().splitlines()]
    original=[json.loads(x) for x in (frozen/'daily.jsonl').read_text().splitlines()]
    assert [physical(x) for x in baseline]==[physical(x) for x in original]
    assert load(root.parent/'no-file-original/accepted-column-1-day-5.zip')[1]==load(frozen/'accepted-column-1-day-5.zip')[1]
    assert ext['original_irrigation_sha256']==members[(base/'irrigation.f90').relative_to(a.workspace).as_posix()]
    for name in identity['donor_generated']:
        if name=='irrigation.f90':continue
        for suffix in ['.f90','.o']:
            path=build/Path(name).with_suffix(suffix)
            assert sha(path)==members[(base/path.name).relative_to(a.workspace).as_posix()]
    for name,digest in identity['donor_objects'].items():
        path=a.workspace/idx['reference']/'build/swap-obj'/name
        assert sha(path)==digest==members[path.relative_to(a.workspace).as_posix()]
    cases.append({'optimization':entry['optimization'],'scenario':entry['scenario'],'native_retry_and_changed_history_recovery':'EXACT',
                  'independent_original_input_physical_control':'EXACT_BOTH_DAYS','actual_input_lineage_water_solute':'PASS',
                  'incremental_build_commands':2})
out={'status':'INDEPENDENT_IRRIGATION_NATIVE_INPUT_WATER_SOLUTE_AUDIT_PASS','cases':cases,'auditor_sha256':sha(Path(__file__))}
a.output.write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(out))

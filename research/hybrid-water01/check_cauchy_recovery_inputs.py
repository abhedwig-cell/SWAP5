"""Actual checkpoint forcing attacks and year input transformation; no model runs."""
import argparse
from datetime import date,timedelta
import json
from pathlib import Path
import re
import sys
import zipfile

ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'app/hybrid_water'))
import daily_host as h
from daily_coupling import (CoupledDailyColumn,CauchyDayForcing,CAUCHY_FORCING,write_cauchy_case,
                           GroundwaterDayForcing,GROUNDWATER_FORCING,write_groundwater_case)
p=argparse.ArgumentParser(description=__doc__)
for n in ['workspace','runs','output']:p.add_argument('--'+n,type=Path,required=True)
p.add_argument('--groundwater',action='store_true')
a=p.parse_args();a.output.mkdir();idx=json.loads((a.workspace/'PROOF_INDEX.json').read_text())
project=h.GRASSGROWTH if a.groundwater else h.ANDELST
mode=GROUNDWATER_FORCING if a.groundwater else CAUCHY_FORCING
kind=GroundwaterDayForcing if a.groundwater else CauchyDayForcing
writer=write_groundwater_case if a.groundwater else write_cauchy_case
cut=2 if a.groundwater else 20
coupling='grass-level-O2-2' if a.groundwater else 'actual-cauchy-O2'
item=idx['cases']['grass-O2' if a.groundwater else 'andelst-O2']
bundle=a.workspace/item['build'];reference=a.workspace/idx['reference'];meta=json.loads((a.workspace/item['report']/'BUILD.json').read_text())
good=a.runs/('O2/window-2-to-4' if a.groundwater else 'O2')/'external'/f'accepted-column-1-day-{cut+1}.zip'
with zipfile.ZipFile(good) as z:files={n:z.read(n) for n in z.namelist()}
original_hash=h.sha(good);refusals=[]
for name in ['digest','mode','clock','foreign','nonfinite','applied-hash']:
    m=json.loads(files['checkpoint.json']);f=m['receipt']['coupling']['forcing']
    if name=='digest':f['identity_sha256']='0'*64
    if name=='mode':f['mode']='foreign'
    if name=='clock':f['input']['t0_day1900']+=1
    if name=='foreign':f['input']['coupling_id']='foreign'
    if name=='nonfinite':f['input']['head_start_cm']=float('nan')
    if name=='applied-hash':f['applied_bbc_sha256']='invalid'
    bad=a.output/(name+'.zip')
    with zipfile.ZipFile(bad,'w',zipfile.ZIP_DEFLATED) as z:
        for n,data in files.items():z.writestr(n,json.dumps(m).encode() if n=='checkpoint.json' else data)
    try:CoupledDailyColumn(bundle,reference,a.output/(name+'-owner'),project,coupling,
                           origin=bad,day=cut+1,forcing_mode=mode)
    except (ValueError,TypeError,KeyError):refusals.append(name)
    else:raise AssertionError('Invalid persisted forcing accepted: '+name)
assert h.sha(good)==original_hash
base=a.workspace/item['continuous']/'accepted-column-1-day-2.zip'
receipt=h.verify_checkpoint(base,2,meta['binding'],a.output/'native-source-for-input-only')
years=[]
for day in ([58,59,365,1826] if a.groundwater else [364,365,453]):
    t0=project.start_clock+day
    f=kind('input-only',None,day,t0,t0+1,-79.0,-78.999,'year-input-transform-only')
    case=a.output/f'case-{day}';writer(reference/'distribution/SWAP_4.3.1/cases'/project.case,case,f,project)
    folder=a.output/f'prepared-{day}'
    h.prepare_column(case,folder,h.ColumnStart(day=day,origin=a.output/'native-source-for-input-only',receipt=receipt),True,True,project=project)
    text=(folder/'swap.bbc').read_text(encoding='cp1252')
    entries=re.findall(r'(?m)^\s*(\d{4}-\d{2}-\d{2})[ \t]+([-+0-9.]+)[ \t]*$',text)
    stamps=[s for s,v in entries];assert stamps==sorted(set(stamps))
    first=date.fromisoformat(project.start_date)+timedelta(days=day);values=dict(entries)
    assert float(values[str(first)])==-79.0 and float(values[str(first+timedelta(days=1))])==-78.999
    years.append({'day':day,'prepared_bbc_sha256':h.sha(folder/'swap.bbc'),'scope':'input transformation only, no year model execution'})
r={'status':'PERSISTED_CAUCHY_FORCING_REFUSALS_AND_YEAR_INPUT_TRANSFORMATION_PASS','checkpoint_attacks':refusals,
   'year_input_checks':years,'original_checkpoint_sha256':original_hash,'model_runs':0,
   'sources':{n:h.sha(ROOT/n) for n in ['app/hybrid_water/daily_coupling.py','research/hybrid-water01/check_cauchy_recovery_inputs.py']}}
if a.groundwater:r['status']='PERSISTED_GROUNDWATER_FORCING_REFUSALS_LEAP_YEAR_INPUT_TRANSFORMATION_PASS'
(a.output/'RESULT.json').write_text(json.dumps(r,indent=2)+'\n',encoding='utf-8');print(json.dumps(r))

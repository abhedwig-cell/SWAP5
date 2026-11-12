"""Persisted-input attacks and actual original consuming-routine refusals."""
import argparse
import contextlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import time
import zipfile

ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'app/hybrid_water'))
import daily_host as h
from daily_coupling import CoupledDailyColumn,IRRIGATION_FORCING
from irrigation_forcing import INPUT
p=argparse.ArgumentParser(description=__doc__)
for n in ['workspace','runs','reference','bundle','accepted']:p.add_argument('--'+n,type=Path)
p.add_argument('--project',choices=['hupsel','saltfarm'],default='hupsel')
p.add_argument('--output',type=Path,required=True)
a=p.parse_args();a.output.mkdir();start=time.monotonic()
project={'hupsel':h.HUPSEL,'saltfarm':h.SALTFARM}[a.project]
if a.bundle:
    assert a.reference and a.accepted
    reference=a.reference;bundle=a.bundle;good=a.accepted
else:
    idx=json.loads((a.workspace/'PROOF_INDEX.json').read_text());reference=a.workspace/idx['reference']
    bundle=a.runs/'O2/build';good=a.runs/'O2/modified/external/accepted-column-1-day-5.zip'
meta=json.loads((bundle/'BUILD.json').read_text());digest=h.sha(good)
with zipfile.ZipFile(good) as z:manifest=json.loads(z.read('checkpoint.json'))
day=manifest['receipt']['day'];cid=manifest['receipt']['coupling']['id'];mode=manifest['binding']['external_daily']['forcing']
with zipfile.ZipFile(good) as z:files={n:z.read(n) for n in z.namelist()}
persisted=[]
for name in ['digest','mode','clock','foreign','nonfinite','applied-hash','disabled']:
    m=json.loads(files['checkpoint.json']);f=m['receipt']['coupling']['forcing']
    if name=='digest':f['identity_sha256']='0'*64
    if name=='mode':f['mode']='foreign'
    if name=='clock':f['input']['t0_day1900']+=1
    if name=='foreign':f['input']['coupling_id']='foreign'
    if name=='nonfinite':f['input']['depth_mm']=float('nan')
    if name=='applied-hash':f['applied_irrigation_sha256']='invalid'
    if name=='disabled':f['input']['enabled']=False
    bad=a.output/(name+'.zip')
    with zipfile.ZipFile(bad,'w',zipfile.ZIP_DEFLATED) as z:
        for n,data in files.items():z.writestr(n,json.dumps(m).encode() if n=='checkpoint.json' else data)
    try:CoupledDailyColumn(bundle,reference,a.output/(name+'-owner'),project,cid,
                           origin=bad,day=day,forcing_mode=mode)
    except (ValueError,TypeError,KeyError):persisted.append(name)
    else:raise AssertionError('Malformed persisted irrigation accepted: '+name)
assert h.sha(good)==digest
clock=project.start_clock;original=reference/'distribution/SWAP_4.3.1/cases'/project.case
refusals=[]
for name,line,expected in [('stale',f'S5IRR001 {clock+1} 1 24.0 20.0 12.0','Foreign external irrigation clock'),
                           ('nonfinite',f'S5IRR001 {clock} 1 NaN 20.0 12.0','Nonfinite external irrigation'),
                           ('range',f'S5IRR001 {clock} 1 101.0 20.0 12.0','External irrigation outside original range'),
                           ('duration',f'S5IRR001 {clock} 1 14.4 0.401 0.5','External irrigation exceeds one day')]:
    case=a.output/(name+'-case');shutil.copytree(original,case);(case/INPUT).write_text(line+'\n')
    out=a.output/(name+'-run');out.mkdir()
    try:
        with contextlib.ExitStack() as stack:
            host=h.DailyHost(stack,h.executable(bundle,'day_donor'),h.executable(bundle,'day_kernel'),case,out,
                [h.ColumnStart(name='original')],runtime=True,checkpoint_enabled=True,binding=meta['binding'],project=project)
            host.step(1,checkpoint=True)
    except RuntimeError:
        error=(out/'original/donor.stderr').read_text();assert expected in error
        assert not list(out.glob('accepted-*.zip'));refusals.append(name)
    else:raise AssertionError('Invalid actual consuming input accepted')
r={'status':'IRRIGATION_PERSISTED_AND_ACTUAL_CONSUMER_REFUSALS_PASS','persisted_refusals':persisted,'actual_consumer_refusals':refusals,
   'sources':{n:h.sha(ROOT/n) for n in ['app/hybrid_water/daily_coupling.py','app/hybrid_water/irrigation_forcing.py','research/hybrid-water01/check_irrigation_inputs.py']},
   'source_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'elapsed_seconds':time.monotonic()-start}
(a.output/'RESULT.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r))

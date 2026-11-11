"""Observe original numerical heat; existing production storage owner decides completeness.

Relink only the read-only observed original temperature unit and four small
accounting objects. All other objects come from the admitted source-bound capsule.
"""
import argparse
import contextlib
import hashlib
import json
import math
import os
from pathlib import Path
import subprocess
import sys
import tarfile
import threading
import time
import traceback
import zipfile

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'app/hybrid_water'))
import daily_host as h

SOURCES=['src/process/mod_linear_mixture_sensible_storage.f90',
         'src/kernel/mod_energy_conservation_types.f90',
         'src/process/mod_whole_column_sensible_energy_accounting.f90',
         'app/hybrid_water/heat_accounting.f90']
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--base-archive',type=Path,required=True)
p.add_argument('--workspace',type=Path,required=True)
p.add_argument('--output',type=Path,required=True)
p.add_argument('--case',action='append',choices=['hupsel-O0','hupsel-O2','grass-O0','grass-O2','andelst-O0','andelst-O2'])
a=p.parse_args();a.output.mkdir()
a.case=a.case or ['hupsel-O2']
digest=h.sha(a.base_archive)
assert digest in ['678be090346a13ffd3b68f2a3447a947f86e52b8854fdc46f9fef798ab8b21c1',
                  'feaec2daeada9b5f01f0391352a7b15910f406c4a0034123e65c58418cd67bde']
if not a.workspace.exists():
 a.workspace.mkdir()
 with tarfile.open(a.base_archive) as t:t.extractall(a.workspace,filter='data')
index=json.loads((a.workspace/'PROOF_INDEX.json').read_text())
member_hash=json.loads((a.workspace/'MEMBER_SHA256.json').read_text())
for name,expected in member_hash.items():assert h.sha(a.workspace/name)==expected,name
reference=a.workspace/index['reference'];objects=reference/'build/swap-obj';ttutil=reference/'build/ttutil-obj'
original=reference/'build/swap-selected/temperature.f90'
started=[];real_start=h.start_process
def track(*args):
 proc,log=real_start(*args);started.append(proc);return proc,log
h.start_process=track
expired=[]
def stop():
 expired.append(True)
 for proc in started:
  if proc.poll() is None:proc.kill()
timer=threading.Timer(240,stop);timer.daemon=True;timer.start()
events=[];report={'status':'RUNNING','base_archive_sha256':digest,'cases':[],
 'source_commit':subprocess.check_output(['git','rev-parse','HEAD'],text=True,cwd=ROOT).strip(),
 'sources':{n:h.sha(ROOT/n) for n in SOURCES+['research/hybrid-water01/qualify_original_heat_accounting.py']},
 'original_temperature_sha256':h.sha(original),'selected_cases':a.case}
def execute(command,folder,label):
 begin=time.monotonic();r=subprocess.run(list(map(str,command)),cwd=folder,capture_output=True,timeout=45)
 (folder/(label+'.stdout')).write_bytes(r.stdout);(folder/(label+'.stderr')).write_bytes(r.stderr)
 events.append({'label':label,'command':list(map(str,command)),'seconds':time.monotonic()-begin,'returncode':r.returncode})
 assert r.returncode==0,(label,r.stderr.decode(errors='replace')[-2500:])

def instrument(raw):
 # Removing precisely these marked observation blocks must recover every byte
 # of the original unit. Original constitutive/Thomas operations are untouched.
 patches=[('      implicit none\n      \n      ! heat variables (numerical temperature function)',
           '      use mod_hybrid_heat_accounting, only: observe_original_heat\n'),
          ('      integer                                   :: i, lay, ierror, ipos\n',
           '      real(8) :: audit_face(macp+1),audit_solid(macp)\n'),
          ('           ! estimate TeTop in case swtopbhea == 3\n', '''           if(swtopbhea/=1.or.swbotbhea/=1.or.abs(ssnow)>1d-10)error stop 'Unsupported heat audit profile'
           audit_face(1)=dt*heacon(1)*(tetop-tsoil(1))/disnod(1)
           do i=2,numnod
              audit_face(i)=dt*heacon(i)*(tsoil(i-1)-tsoil(i))/disnod(i)
           end do
           audit_face(numnod+1)=0d0
           audit_solid(1:numnod)=(fquartz(layer(1:numnod))*cdQuartz+ &
                fclay(layer(1:numnod))*cdClay+forg(layer(1:numnod))*cdOrg)*1d-6
           call observe_original_heat(numnod,t1900,dt,dz(1:numnod),thetas(1:numnod), &
                thetm1(1:numnod),theta(1:numnod),tmpold(1:numnod),tsoil(1:numnod), &
                heacap(1:numnod),audit_solid(1:numnod),audit_face(1:numnod+1))
''')]
 # Original layer/thetas are already global through a different routine, not
 # this scope. Import read-only aliases explicitly at this observation seam.
 patches[0]=(patches[0][0],patches[0][1]+'      use MOD_grid, only: layer\n      use variables, only: thetas\n')
 for anchor,insert in patches:
  assert raw.count(anchor)==1,anchor
  raw=raw.replace(anchor,'! BEGIN HEAT OBSERVATION\n'+insert+'! END HEAT OBSERVATION\n'+anchor)
 return raw

def physical(r):return {k:v for k,v in r.items() if k not in ('column','revision')}
try:
 for key,project in [('hupsel',h.HUPSEL),('grass',h.GRASSGROWTH),('andelst',h.ANDELST)]:
  for opt in ['O0','O2']:
   if key+'-'+opt not in a.case:continue
   case=index['cases'][key+'-'+opt];bundle=a.workspace/case['build'];meta=json.loads((a.workspace/case['report']/'BUILD.json').read_text())
   out=a.output/(key+'-'+opt);out.mkdir()
   # Declare observation profile separately; never relabel an old accepted ZIP.
   build_sources={n:h.sha(ROOT/n) for n in SOURCES}
   for n in SOURCES:execute(['gfortran','-'+opt,'-ffree-line-length-none','-fcheck=all','-I',out,'-J',out,'-c',ROOT/n],out,Path(n).stem)
   raw=original.read_text(encoding='cp1252');observed=instrument(raw)
   import re
   assert re.sub(r'! BEGIN HEAT OBSERVATION\n.*?! END HEAT OBSERVATION\n','',observed,flags=re.S)==raw
   temperature=out/'temperature.f90';temperature.write_text(observed,encoding='cp1252')
   execute(['gfortran',*meta['identity']['donor_flags'],'-I',out,'-I',bundle,'-I',objects,'-I',ttutil,'-J',out,'-c',temperature],out,'temperature')
   replaced={Path(n).with_suffix('.o').name:bundle/Path(n).with_suffix('.o').name for n in meta['identity']['donor_generated']}
   replaced['temperature.o']=out/'temperature.o'
   donor=h.executable(out,'observed-donor')
   linked=[replaced.get(path.name,path) for path in sorted(objects.glob('*.o'))]
   extras=[out/Path(n).with_suffix('.o').name for n in SOURCES]
   if meta['binding']['budget_retry']:extras.append(bundle/'hybrid_step_budget.o')
   execute(['gfortran','-o',donor,*linked,*extras,ttutil/'libttutil.a'],out,'link')
   kernel=h.executable(bundle,'day_kernel')
   if os.name!='nt':kernel.chmod(0o755)
   windows=[(2,4)] if key!='hupsel' else [(4,6)]
   for cut,end in windows:
    if key=='hupsel':
     full=index['hupsel_full'];origin=a.workspace/full/'full'/f'accepted-column-1-day-{cut}.zip'
     parent=json.loads((a.workspace/full/'BUILD.json').read_text())['binding']
     expected_folder=a.workspace/full/f'own-{cut}-to-{end}'
    else:
     origin=a.workspace/case['continuous']/f'accepted-column-1-day-{cut}.zip';parent=meta['binding']
     expected_folder=a.workspace/case['resumed']
    prefix=out/f'window-{cut}-to-{end}';prefix.mkdir();unpacked=prefix/'origin'
    receipt=h.verify_checkpoint(origin,cut,parent,unpacked)
    binding={'original_binding':meta['binding'],'heat_observation_sources':build_sources,
             'original_temperature_sha256':h.sha(original),'observed_temperature_sha256':h.sha(temperature),
             'observed_donor_sha256':h.sha(donor),'optimization':opt,'adopted_original_origin_sha256':h.sha(origin)}
    (out/'BUILD.json').write_text(json.dumps({'binding':binding,'original_build':meta,'linked_objects':{str(p):h.sha(p) for p in linked+extras}},indent=2)+'\n')
    before=h.sha(origin)
    with contextlib.ExitStack() as stack:
     host=h.DailyHost(stack,donor,kernel,reference/'distribution/SWAP_4.3.1/cases'/project.case,prefix,
           [h.ColumnStart(day=cut,origin=unpacked,receipt=receipt,name='original')],runtime=True,
           checkpoint_enabled=True,binding=binding,project=project)
     rows=[]
     for day in range(cut+1,end+1):
      r=host.step(1,checkpoint=day==end);assert r['committed'];rows.append(r)
     host.close()
    assert h.sha(origin)==before
    expected=[json.loads(line) for line in (expected_folder/'daily.jsonl').read_text().splitlines()]
    assert list(map(physical,rows))==list(map(physical,expected)),key+' physical observation changed state'
    with zipfile.ZipFile(prefix/f'accepted-column-1-day-{end}.zip') as z:
     for name in h.CHECKPOINT_FILES:assert z.read(name)==(expected_folder/'original'/name).read_bytes(),name
    (prefix/'daily.jsonl').write_text(''.join(json.dumps(r)+'\n' for r in rows))
    report['cases'].append({'project':key,'optimization':opt,'cut':cut,'end':end,'origin_sha256':before,
                            'exact_physical_and_native_payloads':True})
    print(key,opt,'OBSERVED_ORIGINAL_STATE_EXACT',flush=True)
 assert not expired,'Selected240-second cap exceeded'
 report['status']='ORIGINAL_HEAT_OBSERVATION_PHYSICAL_PRESERVATION_PASS'
except BaseException:
 report.update(status='FAILED',traceback=traceback.format_exc());raise
finally:
 timer.cancel()
 report['censored']=bool(expired)
 report['events']=events
 (a.output/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')

"""Recheck complete or explicitly censored native-grid evidence, without relabeling."""
import argparse,base64,hashlib,io,json,runpy,tarfile,tempfile
from pathlib import Path
import numpy as np
ROOT=Path(__file__).resolve().parents[3]
sha=lambda raw:hashlib.sha256(raw).hexdigest()
def assess(files):
 ns=runpy.run_path(str(ROOT/'integration/mc-sol01/native_grid/run.py'))
 reconciliation=json.loads(files['CURRENT_COMPATIBILITY.json'])
 assert reconciliation['status']=='CURRENT_SEASONAL_EXTENSION_CONSTANT_ROUTE_EXACT_PHYSICAL_PRESERVATION'
 allowed={'app/solute_project/main.f90','app/solute_crop/read_swp_project.f90','tools/solute/build_project.py','tools/solute/run_project.py'}
 assert set(reconciliation['source_preimages'])==set(reconciliation['source_postimages'])==allowed
 for p,h in reconciliation['source_postimages'].items():assert sha((ROOT/p).read_bytes())==h
 event=json.loads(files['current/event.json']);assert event['returncode']==0 and event['status']==reconciliation['status']
 for p in ['state.csv','endpoint.csv','budget.csv']:assert files['current/output/'+p]==files['two-day/1/full/'+p]
 current_build=json.loads(files['current/build/column/build-complete.json'])
 assert current_build['status']=='BUILT' and current_build['reused_provider_objects']==193
 for p,h in current_build['input_sha256'].items():assert sha((ROOT/p).read_bytes())==h
 cm=json.loads(files['current/output/manifest.json']);assert cm['status']=='COMPLETE' and cm['returncode']==0 and cm['executable_sha256']==current_build['executable_sha256']
 for p,h in cm['files'].items():assert sha(files['current/output/'+p])==h
 reports={};observations={}
 for label in ['eight-day','two-day']:
  key=label+'/RESULT.json'
  if key not in files:continue
  report=json.loads(files[key]);assert report['days']==(8 if label=='eight-day' else 2)
  checkpoint=files[label+'/checkpoint.raw']
  assert hashlib.sha1(b'commit '+str(len(checkpoint)).encode()+b'\0'+checkpoint).hexdigest()==report['baseline']
  assert not report['full_native_grid_convergence'] and not report['full_mc_sol01_closed']
  references=json.loads(files[label+'/SOURCE_REFERENCES.json'])
  assert set(references)<={ns['CAPSULE'],'integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64','integration/audits/evidence/SWAP431_TTUTIL_AUTHORITY.zip.b64'}
  for p,h in report['inputs'].items():
   if p in references:assert references[p]==h and sha((ROOT/p).read_bytes())==h,('versioned immutable authority',label,p)
   else:assert sha(files[label+'/source/'+p])==h,('retained execution source',label,p)
   if p!='integration/mc-sol01/native_grid/run.py' and sha((ROOT/p).read_bytes())!=h:
    assert p in allowed and h==reconciliation['source_preimages'][p],('unreconciled execution source',label,p)
  build=report['build'];assert build['status']=='BUILT' and '-O2' in build['flags'] and '-fcheck=all' in build['flags']
  for p,h in build['input_sha256'].items():
   if sha((ROOT/p).read_bytes())!=h:assert p in allowed and h==reconciliation['source_preimages'][p]
  assert len(report['events'])==3 and [e['factor'] for e in report['events']]==[1,2,4]
  assert report['status'] in ['BOUNDED_NATIVE_NESTED_GRID_EXECUTIONS_COMPLETE_NOT_ACCURACY_ADMISSION','TERMINAL_FAILED_OR_CENSORED']
  arrays={};valid=[];failed=[]
  old_raw=base64.b64decode((ROOT/ns['CAPSULE']).read_bytes());assert sha(old_raw)==ns['EXPECTED']
  with tarfile.open(fileobj=io.BytesIO(old_raw),mode='r:xz') as archive:
   original={p:archive.extractfile(ns['PREFIX']+p).read() for p in ['Project.SWP','Crop Data/First.CRP','Crop Data/Second.CRP','Weather Data/History.998']}
  with tempfile.TemporaryDirectory() as name:
   d=Path(name)
   for p,raw in files.items():
    if not p.startswith(label+'/'):continue
    rel=p[len(label)+1:];q=d/rel;q.parent.mkdir(parents=True,exist_ok=True);q.write_bytes(raw)
   template=(d/'1/Project.SWP').read_text()
   assert template.encode()==original['Project.SWP']
   for event in report['events']:
    k=str(event['factor']);factor=int(k);swp=(d/k/'Project.SWP').read_text();mesh=f'1 1 40.0 {20*factor}\n2 2 2.0 {factor}\n3 2 78.0 {20*factor}'
    assert swp.count(mesh)==1 and swp.replace(mesh,ns['MESH'])==template
    for p in ['Crop Data/First.CRP','Crop Data/Second.CRP','Weather Data/History.998']:assert (d/k/p).read_bytes()==original[p]
    assert (d/k/'stdout').is_file() and (d/k/'stderr').is_file()
    if event['returncode'] or event['censored']:
     failed.append(k);assert k not in report['cases'];continue
    value,state=ns['validate'](d/k/'full',report['days']);assert value==report['cases'][k]
    assert len(state)==41*factor;valid.append(k)
    arrays[k]={p:np.array([r[p] for r in state]).reshape(41,factor).sum(axis=1) for p in ['dissolved_mg_cm2','sorbed_mg_cm2','dz_cm']}
    arrays[k]['water_cm']=np.array([r['theta']*r['dz_cm'] for r in state]).reshape(41,factor).sum(axis=1)
   assert (not failed)==(report['status']=='BOUNDED_NATIVE_NESTED_GRID_EXECUTIONS_COMPLETE_NOT_ACCURACY_ADMISSION')
  diffs={}
  for lo,hi in [('1','2'),('2','4')]:
   if lo not in arrays or hi not in arrays:continue
   a,b=arrays[lo],arrays[hi];assert np.max(np.abs(a['dz_cm']-b['dz_cm']))<1e-12
   ma=a['dissolved_mg_cm2']+a['sorbed_mg_cm2'];mb=b['dissolved_mg_cm2']+b['sorbed_mg_cm2']
   ca=a['dissolved_mg_cm2']/a['water_cm'];cb=b['dissolved_mg_cm2']/b['water_cm']
   diffs[f'{41*int(lo)}-vs-{41*int(hi)}']=dict(soil_total_mass_l1_mg_cm2=float(np.sum(np.abs(ma-mb))),relative_soil_total_mass_l1=float(np.sum(np.abs(ma-mb))/np.sum(mb)),water_l1_cm=float(np.sum(np.abs(a['water_cm']-b['water_cm']))),aqueous_concentration_l1=float(np.sum(a['dz_cm']*np.abs(ca-cb))),maximum_coarse_bin_concentration_difference=float(np.max(np.abs(ca-cb))))
  if not failed:assert diffs==report['comparisons']
  observations[label]=dict(completed_grids=[41*int(k) for k in valid],failed_or_censored_grids=[41*int(k) for k in failed],comparisons=diffs,initial_stocks={k:dict(water_cm=v['initial_water_cm'],solute_mg_cm2=v['initial_solute_mg_cm2']) for k,v in report['cases'].items()},seconds={str(e['factor']):e['seconds'] for e in report['events']},active_crop_days={k:v['active_crop_days'] for k,v in report['cases'].items()})
  reports[label]=report
 assert 'eight-day' in reports
 physical=json.loads(files['build/shared/build-complete.json'])
 assert physical['status']=='BUILT' and physical['provider_count']==194 and len(physical['events'])==349
 for p,h in physical['input_sha256'].items():assert sha((ROOT/p).read_bytes())==h
 for p,h in physical['generated_input_sha256'].items():assert sha(files['build/shared/'+p])==h
 for e in physical['events']:
  assert e['returncode']==0
  for stream in ['stdout','stderr']:assert 'build/shared/'+e[stream] in files
 return dict(status='BOUNDED_NATIVE_GRID_OBSERVATIONS_VERIFIED_NOT_NATIVE_ACCURACY_ADMISSION',observations=observations,full_native_grid_convergence=False,full_mc_sol01_closed=False)
def self_test(files):
 passed=[]
 def reject(label,change):
  bad=dict(files);change(bad)
  try:assess(bad)
  except (AssertionError,KeyError,FileNotFoundError,ValueError):passed.append(label);return
  raise AssertionError('accepted evidence corruption '+label)
 def edit(f,label,change):
  p=label+'/RESULT.json';r=json.loads(f[p]);change(r);f[p]=json.dumps(r).encode()
 reject('missing164cell terminal profile',lambda f:f.pop('two-day/4/full/state.csv'))
 reject('false full native grid qualification',lambda f:edit(f,'two-day',lambda r:r.update(full_native_grid_convergence=True)))
 def fake(f):
  def mutate(r):r.update(status='BOUNDED_NATIVE_NESTED_GRID_EXECUTIONS_COMPLETE_NOT_ACCURACY_ADMISSION');r['events'][-1].update(returncode=0,censored=False)
  edit(f,'eight-day',mutate)
 reject('censored8day relabeled completed',fake)
 p='eight-day/source/integration/mc-sol01/native_grid/run.py'
 reject('foreign executed runner',lambda f:f.update({p:f[p]+b'!'}))
 physical=json.loads(files['build/shared/build-complete.json']);p='build/shared/'+next(iter(physical['generated_input_sha256']))
 reject('missing original generated provider',lambda f:f.pop(p))
 p='two-day/2/full/budget.csv';reject('corrupt actual daily balance',lambda f:f.update({p:f[p]+b'!'}))
 return passed
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--capsule',type=Path,required=True);ap.add_argument('--expected-sha256',required=True);ap.add_argument('--self-test',action='store_true');a=ap.parse_args()
 raw=base64.b64decode(a.capsule.read_bytes());assert sha(raw)==a.expected_sha256
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz') as t:
  ms=t.getmembers();assert len(ms)==len({m.name for m in ms}) and all(m.isfile() and not Path(m.name).is_absolute() and '..' not in Path(m.name).parts for m in ms)
  f={m.name:t.extractfile(m).read() for m in ms}
 manifest=json.loads(f.pop('MANIFEST.json'));assert manifest=={p:sha(v) for p,v in f.items()}
 result=assess(f);assert result==json.loads(f['VERIFICATION.json'])
 if a.self_test:result={'assessment':result,'controls':self_test(f)}
 print(json.dumps(result,indent=2))
if __name__=='__main__':main()

"""Supplemental SURFACE-AGE02 evidence checks, without changing admitted guards."""
from pathlib import Path
import argparse,base64,copy,hashlib,io,json,subprocess,sys,tarfile
ROOT=Path(__file__).resolve().parents[3]
STATUS='integration/audits/MC_SOL01_SURFACE_AGE02_STATUS.json'
def check(ok,label):
 if not ok:raise ValueError(label)
def sha(b):return hashlib.sha256(b).hexdigest()
def record():return json.loads((ROOT/STATUS).read_text())
def load():
 e=record()['evidence'];raw=base64.b64decode((ROOT/e['path']).read_bytes());check(sha(raw)==e['decoded_sha256'],'capsule integrity')
 with tarfile.open(fileobj=io.BytesIO(raw))as t:
  ms=t.getmembers();check(all(m.isfile()and not Path(m.name).is_absolute()and'..'not in Path(m.name).parts for m in ms),'unsafe member');check(len(ms)==len({m.name for m in ms}),'duplicate member');f={m.name:t.extractfile(m).read()for m in ms}
 manifest=json.loads(f.pop('MANIFEST.json'));check(set(manifest)==set(f),'inventory')
 for p,h in manifest.items():check(sha(f[p])==h,'raw integrity '+p)
 return f
def validate(f,reader=lambda p:(ROOT/p).read_bytes()):
 r=json.loads(f['final/result.json']);ee=json.loads(f['final/events.json'])
 check(r['status']=='TWO_DAY_REFERENCE_QUALIFIED_BOUNDED','unfinished qualification')
 check(r['execution_commit']==record()['execution_commit'],'unbound execution')
 for p,h in r['input_sha256'].items():check(sha(reader(p))==h,'stale input '+p)
 for e in ee:
  check(e['returncode']==0 and e['seconds']>=0,'failed command')
  for stream in ['stdout','stderr']:check('final/'+e[stream]in f,'missing raw stream')
  if '-c'in e['command']:check('-fcheck=all'in e['command']and'-ffpe-trap=invalid,zero,overflow'in e['command'],'unchecked leaf')
 check(sum(e['category']=='long_native'for e in ee)==6,'missing two-day native')
 check(sum(e['category']=='restart_native'for e in ee)==12,'missing fresh process')
 for opt in ['O0','O2']:
  row=r['results'][opt];dt=row['actual_max_dt_day'];dd=row['refinement_differences']
  check(dt[1]<=.501*dt[0]and dt[2]<=.501*dt[1],'actual mesh not refined')
  for k in range(2):check(dd[1][k]<dd[0][k]and dd[1][k]/max(1.,abs(row['64']['summary'][3+k]))<1e-3,'unqualified stabilization')
  for level in [16,32,64]:
   rr=row[str(level)];prefix='final/'+opt+'/';endpoint=f[prefix+f'level{level}.endpoint']
   check(sha(endpoint)==rr['endpoint_sha256'],'endpoint digest')
   check(rr['summary'][0]==2.0 and rr['summary'][1]>0.,'two-day positive pond')
   check(abs(rr['age_budget'][-1])<1e-9,'cumulative age budget')
   check(len(rr['restarts'])==(4 if level==64 else 1),'checkpoint count')
   for restart in rr['restarts']:
    name=f'level{level}-fresh{restart["cut"]}.endpoint'
    check(f[prefix+name]==endpoint and sha(endpoint)==restart['fresh_sha256'],'fresh endpoint')
   check(endpoint==f['final/O0/'+f'level{level}.endpoint'],'optimization drift')
   e=next(e for e in ee if e['category']=='long_native'and'/'+opt+'/'in e['command'][0]and e['command'][2]==str(level))
   text=f['final/'+e['stdout']].decode()
   check('SURFACE_AGE_TWO_DAY_REFERENCE=PASS'in text,'missing real completion')
   check(f'EXECUTED_WINDOWS {2000*level:9d}'in text,'missing windows')
   water=next(list(map(float,l.split()[1:]))for l in text.splitlines()if l.startswith('TOTAL_WATER_CM '))
   check(len(water)==6 and min(water)>0.,'missing real flux')
  for category,tag in [('dry_limit_native','COMPLETE_DRY_LIMIT_REJECTED_WITHOUT_MUTATION=PASS'),('incumbent_native','SURFACE_AGE_REAL_REFERENCE_TRIPLET=PASS')]:
   e=next(e for e in ee if e['category']==category and'/'+opt+'/'in e['command'][0]);check(tag in f['final/'+e['stdout']].decode(),'missing '+category)
 # Provider provenance must match the previously admitted source-bound capsule.
 sys.path.insert(0,str(ROOT/'tests/nut-sol'));import verify_surface_age_successor as old
 old.verify_qualification();prior=old.evidence()
 check(json.loads(f['final/provider_result.json'])==json.loads(prior['physical/result.json']),'provider result drift')
 check(json.loads(f['final/provider_events.json'])==json.loads(prior['physical/events.json']),'provider compile provenance drift')
 return dict(two_day_reference=True,optimization_exact=True,fresh_processes=12,refinement='observed decreasing endpoint changes, not a formal order proof',full_evaporative_drying=False,production_changed=False)
def verify():
 s=record();delta=subprocess.check_output(['git','diff','--name-only',s['baseline'],'HEAD','--','src','tests','tools','reference','.github'],cwd=ROOT,text=True)
 if delta.strip():
  import runpy
  ci=runpy.run_path(str(ROOT/'integration/audits/surface_age_ci/authority.py'),run_name='ci_qualification_authority')
  ci['verify_qualification']()
 return validate(load())
def main():
 p=argparse.ArgumentParser();p.add_argument('--self-test',action='store_true');a=p.parse_args();print(json.dumps(verify(),indent=2))
 if not a.self_test:return
 original=load();controls=[]
 def reject(label,f,reader=lambda p:(ROOT/p).read_bytes()):
  try:validate(f,reader)
  except(ValueError,KeyError,AssertionError,IndexError,StopIteration):controls.append(label);return
  raise AssertionError('accepted '+label)
 f=dict(original);f['final/O2/level64.endpoint']+=b'x';reject('endpoint corruption',f)
 f=dict(original);ev=json.loads(f['final/events.json']);f['final/events.json']=json.dumps([e for e in ev if e['category']!='restart_native']).encode();reject('missing fresh process',f)
 f=dict(original);ev=json.loads(f['final/events.json']);ev[0]['returncode']=1;f['final/events.json']=json.dumps(ev).encode();reject('failed command',f)
 f=dict(original);ev=json.loads(f['final/events.json']);e=next(e for e in ev if '-c'in e['command']);e['command'].remove('-fcheck=all');f['final/events.json']=json.dumps(ev).encode();reject('unchecked leaf',f)
 f=dict(original);del f['final/'+json.loads(f['final/events.json'])[0]['stdout']];reject('missing raw stream',f)
 f=dict(original);r=json.loads(f['final/result.json']);r['results']['O0']['actual_max_dt_day']=[1.,1.,1.];f['final/result.json']=json.dumps(r).encode();reject('inactive refinement',f)
 f=dict(original);r=json.loads(f['final/result.json']);r['status']='RUNNING';f['final/result.json']=json.dumps(r).encode();reject('unfinished result',f)
 q='src/process/mod_b111_surface_age_budget.f90';reject('changed production',dict(original),lambda p:(ROOT/p).read_bytes()+(b'!'if p==q else b''))
 print(json.dumps(dict(negative_controls=controls,count=len(controls))))
if __name__=='__main__':main()

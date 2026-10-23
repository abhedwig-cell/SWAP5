"""Source-bound accepted-trace proof, including all failed research rounds."""
import argparse,base64,hashlib,io,json,runpy,tarfile,tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
sha=lambda b:hashlib.sha256(b).hexdigest()
LABELS=['water_failed','replay_failed_1','replay_failed_2','water','replay','reference_failed','reference']
def assess(files):
 for label in LABELS:
  r=json.loads(files[label+'/execution.json']);raw=files[label+'/checkpoint.raw']
  assert hashlib.sha1(b'commit '+str(len(raw)).encode()+b'\0'+raw).hexdigest()==r['baseline']
  for p,h in r['inputs'].items():
   assert sha(files[label+'/source/'+p])==h
   if label in ['water','replay','reference_failed','reference']:assert sha((ROOT/p).read_bytes())==h,('source',p)
  for e in r.get('events',[]):
   for stream in ['stdout','stderr']:assert sha(files[label+'/'+e[stream]])==e[stream+'_sha256']
   if '-fcheck=all' in e['command']:
    assert '-ffpe-trap=invalid,zero,overflow' in e['command']
    actual={str(Path(p).relative_to(ROOT)) for p in e['command'] if p.endswith('.f90') and Path(p).is_relative_to(ROOT)}
    expected={p for p in r['inputs'] if p.endswith('.f90')}
    if label=='replay':
     expected.remove('integration/mc-sol01/fct_water_sorption/mod_research_storage_fct.f90')
     assert any(p.endswith('/storage_successor.f90') for p in e['command'])
    assert actual==expected,('compile closure',label,actual^expected)
  if 'failed' in label and label!='reference_failed':
   assert r['status']=='FAILED' and r['events'][-1]['returncode']!=0
  if label in ['water','replay']:assert b'GNU Fortran' in files[label+'/'+r['events'][0]['stdout']]
 for label in ['replay_failed_1','replay_failed_2']:
  r=json.loads(files[label+'/execution.json']);assert b'ERROR STOP low replay' in files[label+'/'+r['events'][-1]['stderr']]
 r=json.loads(files['water_failed/execution.json']);assert b'qrot' in files['water_failed/'+r['events'][-1]['stderr']]
 for label,fields in [('water',['optimization','n','factor','path','sha256']),('replay',['optimization','n','factor','exponent','shape'])]:
  r=json.loads(files[label+'/execution.json'])
  for c in r['water_cases' if label=='water' else 'cases']:
   event={k:v for k,v in c.items() if k not in fields};assert event in r['events']
 with tempfile.TemporaryDirectory() as name:
  out=Path(name)
  for p,v in files.items():
   if p.split('/')[0] in ['water','replay','reference_failed','reference']:
    q=out/p;q.parent.mkdir(parents=True,exist_ok=True);q.write_bytes(v)
  result=runpy.run_path(str(HERE/'extend_reference.py'))['assess'](out/'reference',out/'reference_failed',out/'replay',out/'water')
 assert result==json.loads(files['reference/result.json'])
 assert result['actual_water_trace_qualified'] and result['time_series_accuracy_qualified']
 assert not any(result[k] for k in ['production_activated','native_qualified','full_mc_sol01_closed'])
 p=json.loads(files['PRESERVATION.json']);assert p['current_qualified'] and p['current_controls']==17
 assert p['storage_qualified'] and p['storage_controls']==8 and p['prototype_qualified'] and p['prototype_controls']==6
 return result
def controls(files):
 passed=[]
 def reject(label,mutate):
  f=dict(files);mutate(f)
  try:assess(f)
  except(AssertionError,KeyError,ValueError,FileNotFoundError):passed.append(label);return
  raise AssertionError('accepted '+label)
 r=json.loads(files['water/execution.json']);w=next(c for c in r['water_cases'] if c['optimization']=='O2')
 reject('missing actual accepted carrier',lambda f:f.pop('water/'+w['path']))
 r=json.loads(files['replay/execution.json']);c=next(c for c in r['cases'] if c['optimization']=='O2' and c['shape']==0)
 reject('missing replay profile',lambda f:f.pop('replay/'+c['stdout']))
 reject('missing failed water stderr',lambda f:f.pop('water_failed/'+json.loads(f['water_failed/execution.json'])['events'][-1]['stderr']))
 reject('missing failed surface replay',lambda f:f.pop('replay_failed_2/execution.json'))
 reject('missing unresolved reference round',lambda f:f.pop('reference_failed/execution.json'))
 def false_native(f):
  p='reference/result.json';r=json.loads(f[p]);r['native_qualified']=True;f[p]=json.dumps(r).encode()
 reject('false native activation claim',false_native)
 def wrong_option(f):f['replay/storage_successor.f90']=f['replay/storage_successor.f90'].replace(b'exact_empty_pond_limit=.true.',b'exact_empty_pond_limit=.false.')
 reject('wrong physical surface option',wrong_option)
 def negative(f):
  p='replay/'+c['stdout'];lines=f[p].decode().splitlines();v=lines[3].split();v[7]='-1.0';lines[3]=' '.join(v);f[p]=('\n'.join(lines)+'\n').encode()
  r=json.loads(f['replay/execution.json'])
  for e in [*r['events'],*r['cases']]:
   if e['stdout']==c['stdout']:e['stdout_sha256']=sha(f[p])
  f['replay/execution.json']=json.dumps(r).encode()
 reject('negative corrected mass with consistent stream hashes',negative)
 def bad_clock(f):
  p='water/'+w['path'];lines=f[p].decode().splitlines();v=lines[2].split();v[0]='0.0';lines[2]=' '.join(v);f[p]=('\n'.join(lines)+'\n').encode()
  r=json.loads(f['water/execution.json']);next(c for c in r['water_cases'] if c['path']==w['path'])['sha256']=sha(f[p]);f['water/execution.json']=json.dumps(r).encode()
  q=json.loads(f['replay/execution.json']);q['water_execution_sha256']=sha(f['water/execution.json']);f['replay/execution.json']=json.dumps(q).encode()
 reject('duplicate water clock with consistent carrier hash',bad_clock)
 def bad_reference(f):
  p='reference/execution.json';r=json.loads(f[p]);r['extensions'][0]['mass'][0]=-1.;f[p]=json.dumps(r).encode()
 reject('negative independent reference stock',bad_reference)
 reject('missing preservation receipt',lambda f:f.pop('PRESERVATION.json'))
 return passed
def unpack(path,expected):
 raw=base64.b64decode(path.read_bytes());assert sha(raw)==expected
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz') as t:
  ms=t.getmembers();assert len(ms)==len({m.name for m in ms}) and all(m.isfile() and not Path(m.name).is_absolute() and '..' not in Path(m.name).parts for m in ms)
  files={m.name:t.extractfile(m).read() for m in ms}
 manifest=json.loads(files.pop('MANIFEST.json'));assert manifest=={p:sha(v) for p,v in files.items()}
 return files
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--capsule',type=Path,required=True);ap.add_argument('--expected-sha256',required=True);ap.add_argument('--self-test',action='store_true');a=ap.parse_args()
 files=unpack(a.capsule,a.expected_sha256);result=assess(files);assert result==json.loads(files['VERIFICATION.json'])
 result={k:v for k,v in result.items() if k!='accuracy'}
 if a.self_test:result['evidence_controls']=controls(files)
 print(json.dumps(result,indent=2))
if __name__=='__main__':main()

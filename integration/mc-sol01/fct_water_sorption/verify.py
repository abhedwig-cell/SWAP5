"""Recompute sealed raw proof and enforce narrow qualification claims."""
import argparse,base64,hashlib,io,json,runpy,tarfile,tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
sha=lambda b:hashlib.sha256(b).hexdigest()
def assess(files):
 for label in ['oracle_failed','qualified']:
  r=json.loads(files[label+'/execution.json']);raw=files[label+'/checkpoint.raw']
  assert hashlib.sha1(b'commit '+str(len(raw)).encode()+b'\0'+raw).hexdigest()==r['baseline']
  assert r['status']=='EXECUTED' and len(r['cases'])==192
  for p,h in r['inputs'].items():
   assert sha(files[label+'/source/'+p])==h
   if label=='qualified':assert sha((ROOT/p).read_bytes())==h,('source',p)
  for e in r['events']:
   for stream in ['stdout','stderr']:assert sha(files[label+'/'+e[stream]])==e[stream+'_sha256']
   if '-fcheck=all' in e['command']:
    actual={str(Path(p).relative_to(ROOT)) for p in e['command'] if p.endswith('.f90')}
    assert actual=={p for p in r['inputs'] if p.endswith('.f90')}
  assert b'GNU Fortran' in files[label+'/'+r['events'][0]['stdout']]
 failure=json.loads(files['ORACLE_FAILURE.json'])
 assert failure['status']=='ASSESSMENT_FAILED_NATIVE_192_PASSED' and failure['reproduction_returncode']!=0
 assert b'Failed to converge after 100 iterations' in files['oracle_failed/assessment-reproduced.stderr']
 with tempfile.TemporaryDirectory() as name:
  out=Path(name)
  for p,v in files.items():
   if p.startswith('qualified/'):
    q=out/p[len('qualified/'):];q.parent.mkdir(parents=True,exist_ok=True);q.write_bytes(v)
  result=runpy.run_path(str(HERE/'run.py'))['assess'](out)
 assert result==json.loads(files['qualified/result.json'])
 assert not any(result[k] for k in ['production_activated','native_qualified','actual_water_trace_qualified','time_series_accuracy_qualified','full_mc_sol01_closed'])
 preservation=json.loads(files['PRESERVATION.json'])
 assert preservation['current_owner']['qualified'] and preservation['current_controls']==17
 assert preservation['prototype_controls']==6 and preservation['prototype_qualified']
 return result
def controls(files):
 passed=[]
 def reject(label,mutate):
  f=dict(files);mutate(f)
  try:assess(f)
  except(AssertionError,KeyError,ValueError,FileNotFoundError):passed.append(label);return
  raise AssertionError('accepted corruption: '+label)
 r=json.loads(files['qualified/execution.json']);case=next(c for c in r['cases'] if c['shape']==0)
 reject('missing corrected cells',lambda f:f.pop('qualified/'+case['stdout']))
 reject('missing failed-oracle reproduction',lambda f:f.pop('oracle_failed/assessment-reproduced.stderr'))
 def false_scope(f):
  p='qualified/result.json';r=json.loads(f[p]);r['actual_water_trace_qualified']=True;f[p]=json.dumps(r).encode()
 reject('false actual-water-trace claim',false_scope)
 def false_source(f):
  p='qualified/source/integration/mc-sol01/fct_water_sorption/mod_research_storage_fct.f90';f[p]+=b'!foreign'
 reject('foreign correction source',false_source)
 def edit_cells(f,column,value):
  p='qualified/'+case['stdout'];lines=f[p].decode().splitlines();v=lines[2].split();v[column]=value;lines[2]=' '.join(v);f[p]=('\n'.join(lines)+'\n').encode()
  r=json.loads(f['qualified/execution.json'])
  for e in [*r['events'],*r['cases']]:
   if e['stdout']==case['stdout']:e['stdout_sha256']=sha(f[p])
  f['qualified/execution.json']=json.dumps(r).encode()
 reject('negative mass with consistent stream hashes',lambda f:edit_cells(f,11,'-1.0'))
 reject('water imbalance with consistent stream hashes',lambda f:edit_cells(f,3,'0.4'))
 reject('wrong nonlinear partition with consistent stream hashes',lambda f:edit_cells(f,12,'0.4'))
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
 files=unpack(a.capsule,a.expected_sha256);result=assess(files)
 assert result==json.loads(files['VERIFICATION.json'])
 if a.self_test:result['evidence_controls']=controls(files)
 print(json.dumps(result,indent=2))
if __name__=='__main__':main()

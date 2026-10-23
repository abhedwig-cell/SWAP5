"""Validate bounded prototype proof without promoting it to native physics."""
import argparse,base64,hashlib,io,json,runpy,tarfile,tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
sha=lambda b:hashlib.sha256(b).hexdigest()
def assess(f):
 for label in ['failed','qualified']:
  r=json.loads(f[label+'/execution.json'])
  raw=f[label+'/checkpoint.raw'];assert hashlib.sha1(b'commit '+str(len(raw)).encode()+b'\0'+raw).hexdigest()==r['baseline']
  for p,h in r['inputs'].items():
   assert sha(f[label+'/source/'+p])==h
   if label=='qualified':assert sha((ROOT/p).read_bytes())==h,('source',p)
  for e in r['events']:
   for stream in ['stdout','stderr']:assert label+'/'+e[stream] in f
  assert b'GNU Fortran' in f[label+'/'+r['events'][0]['stdout']]
  for e in r['events']:
   if '-fcheck=all' not in e['command']:continue
   compiled={str(Path(p).relative_to(ROOT)) for p in e['command'] if p.endswith('.f90')}
   assert compiled=={p for p in r['inputs'] if p.endswith('.f90')}
  if label=='failed':assert r['status']=='FAILED' and len(r['cases'])<64 and r['events'][-1]['returncode']!=0
 with tempfile.TemporaryDirectory() as name:
  out=Path(name)
  for p,v in f.items():
   if p.startswith('qualified/'):
    q=out/p[len('qualified/'):];q.parent.mkdir(parents=True,exist_ok=True);q.write_bytes(v)
  result=runpy.run_path(str(ROOT/'integration/mc-sol01/fct_prototype/run.py'))['assess'](out)
 assert result==json.loads(f['qualified/result.json'])
 assert not any(result[p] for p in ['production_activated','native_qualified','nonlinear_Freundlich_qualified','full_mc_sol01_closed'])
 return result
def controls(f):
 passed=[]
 def reject(label,fn):
  bad=dict(f);fn(bad)
  try:assess(bad)
  except (AssertionError,KeyError,ValueError,FileNotFoundError):passed.append(label);return
  raise AssertionError('accepted '+label)
 r=json.loads(f['qualified/execution.json']);case=next(c for c in r['cases'] if c['mode']==1)
 reject('missing corrected profile',lambda b:b.pop('qualified/'+case['stdout']))
 def false_source(b):
  r=json.loads(b['qualified/execution.json']);r['inputs']['integration/mc-sol01/fct_prototype/mod_research_fct.f90']='0'*64;b['qualified/execution.json']=json.dumps(r).encode()
 reject('foreign correction source',false_source)
 def negative(b):
  p='qualified/'+case['stdout'];lines=b[p].decode().splitlines();fields=lines[1].split();assert fields[0]=='PROFILE';fields[3]='-1.0';lines[1]=' '.join(fields);b[p]=('\n'.join(lines)+'\n').encode()
  r=json.loads(b['qualified/execution.json']);next(c for c in r['cases'] if c['stdout']==case['stdout'])['sha256']=sha(b[p]);b['qualified/execution.json']=json.dumps(r).encode()
 reject('negative stock with consistent file hash',negative)
 def false_native(b):
  r=json.loads(b['qualified/result.json']);r['native_qualified']=True;b['qualified/result.json']=json.dumps(r).encode()
 reject('false native qualification',false_native)
 e=json.loads(f['failed/execution.json'])['events'][-1]
 reject('missing failed execution stream',lambda b:b.pop('failed/'+e['stderr']))
 def false_success(b):
  r=json.loads(b['failed/execution.json']);r['status']='EXECUTED';b['failed/execution.json']=json.dumps(r).encode()
 reject('failed attempt relabeled success',false_success)
 return passed
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--capsule',type=Path,required=True);ap.add_argument('--expected-sha256',required=True);ap.add_argument('--self-test',action='store_true');a=ap.parse_args()
 raw=base64.b64decode(a.capsule.read_bytes());assert sha(raw)==a.expected_sha256
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz') as t:
  ms=t.getmembers();assert len(ms)==len({m.name for m in ms}) and all(m.isfile() and not Path(m.name).is_absolute() and '..' not in Path(m.name).parts for m in ms)
  f={m.name:t.extractfile(m).read() for m in ms}
 manifest=json.loads(f.pop('MANIFEST.json'));assert manifest=={p:sha(v) for p,v in f.items()}
 r=assess(f);assert r==json.loads(f['VERIFICATION.json']);out={k:v for k,v in r.items() if k!='measurements'}
 if a.self_test:out['evidence_controls']=controls(f)
 print(json.dumps(out,indent=2))
if __name__=='__main__':main()

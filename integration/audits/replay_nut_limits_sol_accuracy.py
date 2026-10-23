"""Replay unchanged SOL accuracy assertions with explicit recorded-path anchoring.

The existing runner's relative_to(ROOT) refers to recorded compiler command
paths, while ROOT/path source hashing must read the current checkout. This
adapter separates those two path roles without changing any assertion body,
archived command, source byte, numerical observation or scientific threshold.
"""
from pathlib import Path
import base64,hashlib,io,json,runpy,tarfile,tempfile,time
ROOT=Path(__file__).resolve().parents[2]
HERE=ROOT/'integration/mc-sol01/transport_accuracy'
start=time.perf_counter();raw=base64.b64decode((HERE/'EVIDENCE.tar.xz.b64').read_bytes())
index=json.loads((HERE/'EVIDENCE_INDEX.json').read_text())
assert hashlib.sha256(raw).hexdigest()==index['decoded_sha256']
with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz')as a:
 ms=a.getmembers();assert len(ms)==len({m.name for m in ms})and all(m.isfile()and not Path(m.name).is_absolute()and'..'not in Path(m.name).parts for m in ms)
 files={m.name:a.extractfile(m).read()for m in ms}
manifest=json.loads(files.pop('MANIFEST.json'));assert manifest=={p:hashlib.sha256(b).hexdigest()for p,b in files.items()}
report=json.loads(files['execution.json']);anchors=set()
for p,h in report['inputs'].items():
 assert hashlib.sha256(files['source/'+p]).hexdigest()==h
 assert hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==h
for e in report['events']:
 for arg in e['command']:
  if not arg.endswith('.f90'):continue
  matches=[p for p in report['inputs']if p.endswith('.f90')and arg.endswith('/'+p)]
  assert len(matches)==1;anchors.add(arg[:-len('/'+matches[0])])
assert len(anchors)==1;recorded_root=next(iter(anchors))
class RecordedCommandRoot:
 def __fspath__(self):return recorded_root
 def __truediv__(self,path):return ROOT/path
ns=runpy.run_path(str(HERE/'run.py'));ns['assess'].__globals__['ROOT']=RecordedCommandRoot()
with tempfile.TemporaryDirectory()as tmp:
 out=Path(tmp)
 for p,b in files.items():
  dest=out/p;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(b)
 result=ns['assess'](out)
 expected=json.loads(files['result.json']);differences=[]
 def compare(a,b,path=''):
  if isinstance(a,dict)and isinstance(b,dict):
   assert a.keys()==b.keys()
   for k in a:compare(a[k],b[k],path+'/'+str(k))
  elif isinstance(a,list)and isinstance(b,list):
   assert len(a)==len(b)
   for i,(x,y)in enumerate(zip(a,b)):compare(x,y,path+'/'+str(i))
  elif a!=b:differences.append({'path':path,'current':a,'recorded':b,'absolute_difference':abs(a-b)if isinstance(a,(int,float))and isinstance(b,(int,float))else None})
 compare(result,expected)
 print(json.dumps({'original_scientific_assessment_passed':True,'summary_exact':not differences,'differences':differences},indent=2))
 assert result==expected
print(json.dumps(dict(status='UNCHANGED_SOL_ACCURACY_CAPSULE_PATH_ADAPTER_PASS',
 evidence_sha256=index['decoded_sha256'],profiles=result['profiles'],
 status_from_original_assertions=result['status'],original_assessment_sha256=hashlib.sha256((HERE/'run.py').read_bytes()).hexdigest(),
 live_inputs_exact=True,recorded_command_anchor=recorded_root,observations_or_assertions_changed=False,
 seconds=time.perf_counter()-start),indent=2))

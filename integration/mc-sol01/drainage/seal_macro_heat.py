"""Seal measured existing-runner proof, retaining initial failed execution."""
import base64,hashlib,io,json,runpy,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];W=ROOT.parent;D=Path('integration/mc-sol01/drainage');BASE='043e92ac319d3a3b8ca40b57e995be60db91679a';sha=lambda b:hashlib.sha256(b).hexdigest();f={};excluded={}
def folder(prefix,path):
 for p in sorted(path.rglob('*')):
  if not p.is_file():continue
  data=p.read_bytes();name=prefix+'/'+str(p.relative_to(path))
  if p.suffix in ['.o','.mod','.a']or data[:4]==b'\x7fELF':excluded[name]=dict(sha256=sha(data),bytes=len(data));continue
  f[name]=data
for opt in ['O0','O2']:
 for prefix,path in [('heat-'+opt,'heat-final2-'+opt),('uncovered-'+opt,'uncovered-preserve-'+opt),('covered-'+opt,'covered-preserve-'+opt)]:folder(prefix,W/path)
folder('counter',W/'exact-heat-counter');folder('matrix',W/'matrix-preserve')
f['parent/owner.json']=(W/'predecessor-owner.json').read_bytes();f['parent/commit.raw']=subprocess.check_output(['git','cat-file','commit',BASE],cwd=ROOT)
with tarfile.open(fileobj=io.BytesIO(base64.b64decode((ROOT/D/'COVERED_MACRO_TRACE_EVIDENCE.tar.xz.b64').read_bytes())),mode='r:xz')as t:
 for opt in ['O0','O2']:
  f['prior/uncovered-'+opt+'.json']=t.extractfile('uncovered-'+opt+'/RESULT.json').read()
  for wet in [0,1]:
   for trace in [0,1]:
    p='covered-'+opt+'/wet'+str(wet)+'-trace'+str(trace)+'.stdout';f['prior/'+p]=t.extractfile(p).read()
inputs=set()
for label in ['heat','covered','uncovered']:
 for opt in ['O0','O2']:inputs.update(json.loads(f[label+'-'+opt+'/RESULT.json'])['input_sha256'])
inputs.update(['integration/audits/verify_macro_heat_current.py','integration/audits/verify_covered_macro_current.py',*[str(D/x)for x in ['MACRO_HEAT_CONTRACT.md','seal_macro_heat.py','preserve_covered_matrix.py','rebuild_covered_macro.py','verify_source_continuation.py','probe_macro_heat_predecessor.py']]])
for p in sorted(inputs):f['executed/'+p]=(ROOT/p).read_bytes()
f['executed-hashes.json']=(json.dumps({p:sha(f['executed/'+p])for p in sorted(inputs)},indent=2)+'\n').encode()
for p in sorted(W.glob('*heat*.log')):f['development/'+p.name]=p.read_bytes()
for name in ['heat-final-O0','heat-final-O2']:folder('development/'+name,W/name)
f['raw-hashes.json']=(json.dumps({p:sha(b)for p,b in f.items()if p.endswith(('.stdout','.stderr'))},indent=2)+'\n').encode()
f['excluded-build-artifacts.json']=(json.dumps(excluded,indent=2)+'\n').encode();m=runpy.run_path(str(ROOT/'integration/audits/verify_macro_heat_current.py'));result=m['validate'](f)
f['MANIFEST.json']=(json.dumps({p:sha(b)for p,b in sorted(f.items())},indent=2)+'\n').encode();stream=io.BytesIO()
with tarfile.open(fileobj=stream,mode='w:xz')as t:
 for p,b in sorted(f.items()):info=tarfile.TarInfo(p);info.size=len(b);info.mode=0o644;t.addfile(info,io.BytesIO(b))
raw=stream.getvalue();cap=D/'MACRO_HEAT_EVIDENCE.tar.xz.b64';(ROOT/cap).write_bytes(base64.b64encode(raw));p=ROOT/D/'MACRO_HEAT_STATUS.json';s=json.loads(p.read_bytes());delta={x.split('\t')[1]:x.split('\t')[0]for x in subprocess.check_output(['git','diff','--name-status',BASE,'--',*m['SCIENCE']],cwd=ROOT,text=True).splitlines()};posts={p:sha((ROOT/p).read_bytes())for p in set(delta)|{str(D/x)for x in ['MACRO_HEAT_CONTRACT.md','seal_macro_heat.py','qualify_macro_trace.py','rebuild_covered_macro.py','preserve_covered_matrix.py','verify_source_continuation.py','probe_macro_heat_predecessor.py']}}
s.update(stage='QUALIFIED_PENDING_CANONICAL_ADMISSION',implemented=True,persisted=True,tested=True,qualified=True,canonically_admitted=False,scientific_delta=delta,postimages=posts,evidence=dict(path=str(cap),sha256=sha(raw),bytes=len(raw),members=len(f)),qualification=result,blockers=['Actual canonical merge and postimage verification','Original native macro input/dispatch remains excluded'],next_action='Admit bounded runtime, verify actual merge; continue original native input mapping separately',recovery_point='Complete fresh O0/O2 thermal and nonthermal production proof')
p.write_text(json.dumps(s,indent=2)+'\n');print(json.dumps(result,indent=2))

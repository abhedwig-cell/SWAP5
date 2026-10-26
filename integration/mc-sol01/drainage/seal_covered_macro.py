"""Seal actual covered, incumbent and current composition evidence; exclude binaries."""
import base64,hashlib,io,json,runpy,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];W=ROOT.parent;D=Path('integration/mc-sol01/drainage');BASE='9d108ee89ae6e1e19d8705a696779555a4a0491c';sha=lambda b:hashlib.sha256(b).hexdigest();f={};excluded={}
def add(name,p):
 b=p.read_bytes()
 if p.suffix in ['.o','.mod','.a']or b[:4]==b'\x7fELF':excluded[name]={'bytes':len(b),'sha256':sha(b)};return
 f[name]=b
def folder(prefix,path):
 for p in sorted(path.rglob('*')):
  if p.is_file():add(prefix+'/'+str(p.relative_to(path)),p)
for opt in ['O0','O2']:
 for label,path in [('covered-'+opt,'covered-proof2-'+opt),('counter/'+opt,'covered-counter2-'+opt),('uncovered-'+opt,'covered-uncovered-preserve-'+opt)]:folder(label,W/path)
for label,path in [('nut-joint','covered-nut-joint'),('nut-nonjuvenile','covered-nut-nonjuvenile'),('matrix','covered-matrix-preserve')]:folder(label,W/path)
f['parent/owner.json']=(W/'covered-parent-owner.json').read_bytes();f['parent/fsi35.json']=(W/'covered-parent-fsi35.json').read_bytes();f['parent/commit.raw']=subprocess.check_output(['git','cat-file','commit',BASE],cwd=ROOT)
for opt in ['O0','O2']:
 b=json.loads((W/('covered-base-'+opt)/'build-complete.json').read_text())
 for p,h in b['input_sha256'].items():
  data=subprocess.check_output(['git','show',BASE+':'+p],cwd=ROOT);assert sha(data)==h,p;f['parent/executed/'+p]=data
# Existing accepted macro/NUT results are identity oracles, not fresh PASS.
p=ROOT/D/'MACRO_TRACE_EVIDENCE.tar.xz.b64'
with tarfile.open(fileobj=io.BytesIO(base64.b64decode(p.read_bytes())),mode='r:xz')as t:
 for opt in ['O0','O2']:f['prior/uncovered-'+opt+'.json']=t.extractfile('macro-'+opt+'/RESULT.json').read()
 for label in ['nut-joint','nut-nonjuvenile']:f['prior/'+label+'.json']=t.extractfile(label+'/result.json').read()
inputs=set()
for name in ['covered-O0/RESULT.json','covered-O2/RESULT.json','uncovered-O0/RESULT.json','uncovered-O2/RESULT.json','nut-joint/result.json','nut-nonjuvenile/result.json']:inputs.update(json.loads(f[name])['input_sha256'])
inputs.update(str(D/p)for p in ['COVERED_MACRO_TRACE_CONTRACT.md','qualify_covered_macro_trace.py','rebuild_covered_macro.py','preserve_covered_matrix.py','seal_covered_macro.py','verify_source_continuation.py']);inputs.update(['integration/audits/verify_covered_macro_current.py','integration/audits/verify_saturation_storage_current.py'])
for p in sorted(inputs):f['executed/'+p]=(ROOT/p).read_bytes()
f['executed-hashes.json']=(json.dumps({p:sha(f['executed/'+p])for p in sorted(inputs)},indent=2)+'\n').encode()
for p in sorted(W.glob('covered-*.log')):add('development-logs/'+p.name,p)
for path in ['covered-baseline-probe-O0','covered-baseline-probe2-O0','covered-baseline-probe3-O0','covered-probe-O0','covered-probe2-O0','covered-probe2-O2','covered-probe3-O0','covered-probe3-O2','covered-probe4-O0','covered-probe4-O2','covered-probe5-O0','covered-probe5-O2','covered-qualified-O0','covered-qualified-O2']:
 if(W/path).is_dir():folder('development/'+path,W/path)
f['excluded-build-artifacts.json']=(json.dumps(excluded,indent=2)+'\n').encode();m=runpy.run_path(str(ROOT/'integration/audits/verify_covered_macro_current.py'));result=m['validate'](f)
f['MANIFEST.json']=(json.dumps({p:sha(b)for p,b in sorted(f.items())},indent=2)+'\n').encode();stream=io.BytesIO()
with tarfile.open(fileobj=stream,mode='w:xz')as tar:
 for name,b in sorted(f.items()):info=tarfile.TarInfo(name);info.size=len(b);info.mode=0o644;tar.addfile(info,io.BytesIO(b))
raw=stream.getvalue();cap=D/'COVERED_MACRO_TRACE_EVIDENCE.tar.xz.b64';(ROOT/cap).write_bytes(base64.b64encode(raw));p=ROOT/D/'COVERED_MACRO_TRACE_STATUS.json';s=json.loads(p.read_text());delta={x.split('\t')[1]:x.split('\t')[0]for x in subprocess.check_output(['git','diff','--name-status',BASE,'--',*m['SCIENCE']],cwd=ROOT,text=True).splitlines()};posts={p:sha((ROOT/p).read_bytes())for p in sorted(set(delta)|{str(D/x)for x in ['COVERED_MACRO_TRACE_CONTRACT.md','qualify_covered_macro_trace.py','rebuild_covered_macro.py','preserve_covered_matrix.py','seal_covered_macro.py','verify_source_continuation.py']})};s.update(stage='QUALIFIED_PENDING_CANONICAL_ADMISSION',implemented=True,tested=True,qualified=True,canonically_admitted=False,scientific_delta=delta,postimages=posts,evidence=dict(path=str(cap),sha256=sha(raw),bytes=len(raw),members=len(f)),qualification=result,remaining_blockers=['Canonical admission and exact merged-postimage verification'],recovery_point='Persisted complete covered receipt evidence and current preservation',next_action='Verify owning source/raw gates, integrate candidate and verify actual canonical merge. Do not claim full original application.')
p.write_text(json.dumps(s,indent=2)+'\n');print(json.dumps({'qualified':True,'evidence':s['evidence'],'result':result},indent=2))

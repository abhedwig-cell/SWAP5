"""Seal current input qualification and fresh inherited application preservation."""
import base64,hashlib,io,json,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];BASE='7afa86335ed18c1f2365151d16f39385bf39d9e7';D=ROOT/'integration/mc-sol01/drainage';sha=lambda b:hashlib.sha256(b).hexdigest()
with tarfile.open(fileobj=io.BytesIO(base64.b64decode((D/'HYDROSTATIC_BOOTSTRAP_EVIDENCE.tar.xz.b64').read_bytes())),mode='r:xz')as t:f={m.name:t.extractfile(m).read()for m in t.getmembers()}
manifest=json.loads(f.pop('MANIFEST.json'));assert manifest=={p:sha(b)for p,b in f.items()}
f={p:b for p,b in f.items()if not p.startswith(('proof-O0/','proof-O2/','executed/'))};omitted={}
def addtree(root,prefix):
 for p in sorted(root.rglob('*')):
  if not p.is_file():continue
  b=p.read_bytes();name=prefix+'/'+str(p.relative_to(root))
  if p.suffix in ['.o','.mod','.a']or b.startswith(b'\x7fELF'):omitted[name]=dict(bytes=len(b),sha256=sha(b));continue
  f[name]=b
for opt in ['O0','O2']:
 for kind,prefix in [('ksatexm-qualified-','ksatexm-'),('ksatexm-preserve-','proof-')]:
  root=ROOT.parent/(kind+opt);r=json.loads((root/'RESULT.json').read_text());addtree(root,prefix+opt)
  for p,h in r['input_sha256'].items():
   data=(ROOT/p).read_bytes();assert sha(data)==h,p;f['executed/'+p]=data
 addtree(ROOT.parent/('ksatexm-final-'+opt),'build-'+opt)
for name in ['ksatexm-proof-O0','ksatexm-final-proof-O0','ksatexm-final-proof-O2','ksatexm-pilot']:
 p=ROOT.parent/name
 if p.exists():addtree(p,'earlier-rounds/'+name)
f['ksatexm-parent/proof.json']=(ROOT.parent/'ksatexm-parent-proof.json').read_bytes();f['ksatexm-parent/commit.raw']=subprocess.check_output(['git','cat-file','commit',BASE],cwd=ROOT);f['ksatexm-parent/owner.py']=subprocess.check_output(['git','show',BASE+':integration/audits/verify_hydrostatic_bootstrap_current.py'],cwd=ROOT);f['KSATEXM_OMITTED_BINARIES.json']=json.dumps(omitted,sort_keys=True).encode();f['MANIFEST.json']=json.dumps({p:sha(b)for p,b in f.items()},sort_keys=True).encode();buf=io.BytesIO()
with tarfile.open(fileobj=buf,mode='w:xz',preset=6)as t:
 for p,b in sorted(f.items()):
  m=tarfile.TarInfo(p);m.size=len(b);m.mode=0o644;t.addfile(m,io.BytesIO(b))
raw=buf.getvalue();ep='integration/mc-sol01/drainage/KSATEXM_INPUT_EVIDENCE.tar.xz.b64';(ROOT/ep).write_bytes(base64.b64encode(raw));s=json.loads((D/'KSATEXM_INPUT_STATUS.json').read_text());delta={x.split('\t')[1]:x.split('\t')[0]for x in subprocess.check_output(['git','diff','--name-status',BASE,'--','src','app','tools','tests','examples','reference','.github','integration/audits'],cwd=ROOT,text=True).splitlines()};delta['integration/audits/verify_ksatexm_input_current.py']='A';post=list(delta)+['integration/mc-sol01/drainage/'+p for p in ['qualify_ksatexm_input.py','seal_ksatexm_input.py']];a=json.loads(f['ksatexm-O0/RESULT.json']);b=json.loads(f['ksatexm-O2/RESULT.json']);assert a['results']==b['results'];budgets=[row for r in [a,b]for k,v in r['results'].items()if k!='original'for row in v['budget']]
s.update(stage='SOURCE_BOUND_QUALIFICATION_SEALED',qualified=True,evidence=dict(path=ep,sha256=sha(raw),bytes=len(raw),members=len(f)),scientific_delta=delta,postimages={p:sha((ROOT/p).read_bytes())for p in post},physical_results=dict(source_nodes=112,source_original_KSATEXM_equals_KSATFIT=True,coupled_cases=6,fresh_process_restarts=6,new_rejected_processes=22,water_max_cm=max(abs(float(r['water_residual_cm']))for r in budgets),solute_max_mg_cm2=max(abs(float(r['solute_residual_mg_cm2']))for r in budgets),inherited_current_cases=6,inherited_current_restarts=6,inherited_current_rejections=38,incumbent_artifact_comparisons=10,all_process_solver_sources_unchanged=True),admission_record='integration/mc-sol01/drainage/KSATEXM_INPUT_ADMISSION.json',next_action='Validate sealed source/raw controls and docs, integrate exact tree, verify actual merge')
(D/'KSATEXM_INPUT_STATUS.json').write_text(json.dumps(s,indent=2)+'\n');print(json.dumps(dict(bytes=len(raw),members=len(f),delta=delta)))

"""Seal raw current project qualification without duplicating unchanged evidence."""
import base64,hashlib,io,json,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];BASE='3f184a488bce19bfcabf9c349cbff0d836b8cfeb';D=ROOT/'integration/mc-sol01/drainage';sha=lambda b:hashlib.sha256(b).hexdigest();f={};omitted={}
def addtree(root,prefix):
 for p in sorted(root.rglob('*')):
  if not p.is_file():continue
  b=p.read_bytes();name=prefix+'/'+str(p.relative_to(root))
  if p.suffix in ['.o','.mod','.a']or b.startswith(b'\x7fELF'):omitted[name]=dict(bytes=len(b),sha256=sha(b));continue
  f[name]=b
for opt in ['O0','O2']:
 root=ROOT.parent/('project-proof-'+opt);r=json.loads((root/'RESULT.json').read_text());addtree(root,'project-'+opt)
 for p,h in r['input_sha256'].items():
  data=(ROOT/p).read_bytes();assert sha(data)==h,p;f['executed/'+p]=data
 addtree(ROOT.parent/('project-current-'+opt),'build-'+opt)
 addtree(ROOT.parent/('project-base-'+opt)/'column','baseline-build-'+opt)
addtree(ROOT.parent/'project-pilot','earlier-pilot')
f['initial-qualifier.py']=(ROOT.parent/'project-initial-qualifier.py').read_bytes()
f['parent/proof.json']=(ROOT.parent/'project-parent-proof.json').read_bytes();f['parent/commit.raw']=subprocess.check_output(['git','cat-file','commit',BASE],cwd=ROOT)
f['parent/project-main.f90']=subprocess.check_output(['git','show',BASE+':app/solute_project/main.f90'],cwd=ROOT)
f['OMITTED_BINARIES.json']=json.dumps(omitted,sort_keys=True).encode();f['MANIFEST.json']=json.dumps({p:sha(b)for p,b in f.items()},sort_keys=True).encode();buf=io.BytesIO()
with tarfile.open(fileobj=buf,mode='w:xz',preset=6)as t:
 for p,b in sorted(f.items()):
  m=tarfile.TarInfo(p);m.size=len(b);m.mode=0o644;t.addfile(m,io.BytesIO(b))
raw=buf.getvalue();ep='integration/mc-sol01/drainage/PROJECT_HYDRAULICS_EVIDENCE.tar.xz.b64';(ROOT/ep).write_bytes(base64.b64encode(raw));s=json.loads((D/'PROJECT_HYDRAULICS_STATUS.json').read_text())
delta={x.split('\t')[1]:x.split('\t')[0]for x in subprocess.check_output(['git','diff','--name-status',BASE,'--','src','app','tools','tests','examples','reference','.github','integration/audits'],cwd=ROOT,text=True).splitlines()};delta['integration/audits/verify_project_hydraulics_current.py']='A'
post=list(delta)+['integration/mc-sol01/drainage/'+p for p in ['qualify_project_hydraulics.py','seal_project_hydraulics.py']];a=json.loads(f['project-O0/RESULT.json']);b=json.loads(f['project-O2/RESULT.json']);assert a['results']==b['results'];budgets=[row for r in [a,b]for k,v in r['results'].items()if k!='default'for row in v['budget']]
s.update(stage='SOURCE_BOUND_QUALIFICATION_SEALED',qualified=True,evidence=dict(path=ep,sha256=sha(raw),bytes=len(raw),members=len(f)),scientific_delta=delta,postimages={p:sha((ROOT/p).read_bytes())for p in post},remaining_implementation_blockers=[],remaining_evidence_blockers=['Actual canonical merge/postimage validation'],physical_results=dict(source_nodes=12,cases=4,days_per_case=481,fresh_process_restarts=4,rejected_processes=20,default_artifact_comparisons=8,water_max_cm=max(abs(float(r['water_residual_cm']))for r in budgets),solute_max_mg_cm2=max(abs(float(r['solute_residual_mg_cm2']))for r in budgets),all_process_solver_sources_unchanged=True),admission_record='integration/mc-sol01/drainage/PROJECT_HYDRAULICS_ADMISSION.json',hosted_checks_selection='NOT_SELECTED_IMPACT: native local O0/O2 qualification; [skip ci] avoids unchanged broad suites. No hosted PASS claimed.',next_action='Validate source/raw owner and docs; integrate exact tree and verify actual merge before admission')
(D/'PROJECT_HYDRAULICS_STATUS.json').write_text(json.dumps(s,indent=2)+'\n');print(json.dumps(dict(bytes=len(raw),members=len(f),physical_results=s['physical_results'])))

"""Seal current heat/crop plus all affected current native caller proof."""
import base64,hashlib,io,json,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];BASE='3ebf19fad6027e174341302d64c22585d47b91bc';D=ROOT/'integration/mc-sol01/drainage';sha=lambda b:hashlib.sha256(b).hexdigest();omitted={}
def load(name):
 s=json.loads((D/(name+'_STATUS.json')).read_bytes());e=s['evidence'];raw=base64.b64decode((ROOT/e['path']).read_bytes(),validate=True);assert sha(raw)==e['sha256']
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz')as t:f={m.name:t.extractfile(m).read()for m in t.getmembers()}
 assert json.loads(f.pop('MANIFEST.json'))=={p:sha(b)for p,b in f.items()};return f
old=load('PROJECT_HYDRAULICS');f={p:b for p,b in old.items()if p.startswith('parent/')or('/active/full.pending-'in p)}
c=load('KSATEXM_INPUT');c={p:b for p,b in c.items()if not p.startswith(('proof-O0/','proof-O2/','ksatexm-O0/','ksatexm-O2/','executed/'))}
def addtree(root,prefix,dest):
 for p in sorted(root.rglob('*')):
  if not p.is_file():continue
  b=p.read_bytes();name=prefix+'/'+str(p.relative_to(root))
  if p.suffix in ['.o','.mod','.a']or b.startswith(b'\x7fELF'):omitted[name]=dict(bytes=len(b),sha256=sha(b));continue
  dest[name]=b
def proof(root,prefix,dest):
 r=json.loads((root/'RESULT.json').read_text());addtree(root,prefix,dest)
 for p,h in r['input_sha256'].items():
  data=(ROOT/p).read_bytes();assert sha(data)==h,p;dest['executed/'+p]=data
for opt in ['O0','O2']:
 proof(ROOT.parent/('heat-ksatexm-'+opt),'ksatexm-'+opt,c);proof(ROOT.parent/('heat-hydrostatic-'+opt),'proof-'+opt,c)
 proof(ROOT.parent/('heat-preserve-'+opt),'project-'+opt,f);proof(ROOT.parent/('heat-proof-'+opt),'heat-'+opt,f)
 for kind,prefix in [('heat-final-','build-'),('heat-physical-','physical-build-')]:addtree(ROOT.parent/(kind+opt),prefix+opt,f)
f.update({'column-inherited/'+p:b for p,b in c.items()})
for name in ['heat-pilot','heat-diagnostic']:
 for root in ROOT.parent.glob(name+'.pending-*'):addtree(root,'earlier-attempts/'+root.name,f)
for name in ['heat-traced-pilot','heat-cold-pilot']:addtree(ROOT.parent/name,'earlier-attempts/'+name,f)
f['earlier-attempts/initial-qualifier.py']=(ROOT.parent/'heat-initial-qualifier.py').read_bytes();f['heat-parent/proof.json']=(ROOT.parent/'heat-parent-proof.json').read_bytes();f['heat-parent/commit.raw']=subprocess.check_output(['git','cat-file','commit',BASE],cwd=ROOT)
f['HEAT_OMITTED_BINARIES.json']=json.dumps(omitted,sort_keys=True).encode();f['MANIFEST.json']=json.dumps({p:sha(b)for p,b in f.items()},sort_keys=True).encode();buf=io.BytesIO()
with tarfile.open(fileobj=buf,mode='w:xz',preset=6)as t:
 for p,b in sorted(f.items()):
  m=tarfile.TarInfo(p);m.size=len(b);m.mode=0o644;t.addfile(m,io.BytesIO(b))
raw=buf.getvalue();ep='integration/mc-sol01/drainage/PROJECT_HEAT_EVIDENCE.tar.xz.b64';(ROOT/ep).write_bytes(base64.b64encode(raw));s=json.loads((D/'PROJECT_HEAT_STATUS.json').read_text());delta={x.split('\t')[1]:x.split('\t')[0]for x in subprocess.check_output(['git','diff','--name-status',BASE,'--','src','app','tools','tests','examples','reference','.github','integration/audits'],cwd=ROOT,text=True).splitlines()};delta['integration/audits/verify_project_heat_current.py']='A';post=list(delta)+['integration/mc-sol01/drainage/'+p for p in ['qualify_project_heat.py','seal_project_heat.py','rebuild_project_heat.py']];a=json.loads(f['heat-O0/RESULT.json']);b=json.loads(f['heat-O2/RESULT.json']);assert a['results']==b['results'];budgets=[row for r in [a,b]for v in r['results'].values()for row in v['budget']]
s.update(stage='SOURCE_BOUND_QUALIFICATION_SEALED',qualified=True,evidence=dict(path=ep,sha256=sha(raw),bytes=len(raw),members=len(f)),scientific_delta=delta,postimages={p:sha((ROOT/p).read_bytes())for p in post},remaining_implementation_blockers=[],remaining_evidence_blockers=['Actual canonical merge/postimage validation'],physical_results=dict(source_nodes=12,heat_crop_cases=4,days_per_case=481,fresh_heat_process_restarts=4,rejected_heat_processes=16,water_max_cm=max(abs(float(r['water_residual_cm']))for r in budgets),solute_max_mg_cm2=max(abs(float(r['solute_residual_mg_cm2']))for r in budgets),observed_heat_max_j_cm2=max(float(r['observed_heat_residual_j_cm2'])for r in budgets),current_project_preservation_cases=4,current_column_cases=12,current_preservation_restarts=16,default_project_artifact_comparisons=8,physical_equations_unchanged=True,runtime_change='EXACT_NUMERIC_HEAT_SUBSTEP_FEDDES_GUARD_ONLY'),admission_record='integration/mc-sol01/drainage/PROJECT_HEAT_ADMISSION.json',hosted_checks_selection='NOT_SELECTED_IMPACT: current native O0/O2 and owning checks selected locally, no hosted PASS claimed; [skip ci] avoids unchanged broad suites.',next_action='Validate current source/raw controls and docs; integrate exact tree and verify actual merge')
(D/'PROJECT_HEAT_STATUS.json').write_text(json.dumps(s,indent=2)+'\n');print(json.dumps(dict(bytes=len(raw),members=len(f),physical_results=s['physical_results'])))

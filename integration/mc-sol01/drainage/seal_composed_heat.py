"""Seal current composed heat plus fresh affected native owners and old-format proof."""
import base64,hashlib,io,json,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];BASE='d6378c7ac492a9e051b04468b814be6d1d54d121';D=ROOT/'integration/mc-sol01/drainage';sha=lambda b:hashlib.sha256(b).hexdigest();s0=json.loads((D/'PROJECT_HEAT_STATUS.json').read_text());e=s0['evidence'];raw=base64.b64decode((ROOT/e['path']).read_bytes(),validate=True);assert sha(raw)==e['sha256']
with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz')as t:old={m.name:t.extractfile(m).read()for m in t.getmembers()}
assert json.loads(old.pop('MANIFEST.json'))=={p:sha(b)for p,b in old.items()}
replace=('heat-O0/','heat-O2/','project-O0/','project-O2/','executed/','column-inherited/ksatexm-O0/','column-inherited/ksatexm-O2/','column-inherited/proof-O0/','column-inherited/proof-O2/','column-inherited/executed/')
f={p:b for p,b in old.items()if not p.startswith(replace)or'/active/full.pending-'in p};omitted={}
def addtree(root,prefix):
 for p in sorted(root.rglob('*')):
  if not p.is_file():continue
  b=p.read_bytes();name=prefix+'/'+str(p.relative_to(root))
  if p.suffix in ['.o','.mod','.a']or b.startswith(b'\x7fELF'):omitted[name]=dict(bytes=len(b),sha256=sha(b));continue
  f[name]=b
def proof(root,prefix,executed='executed/'):
 r=json.loads((root/'RESULT.json').read_text());addtree(root,prefix)
 for p,h in r['input_sha256'].items():
  data=(ROOT/p).read_bytes();assert sha(data)==h,p;f[executed+p]=data
for opt in ['O0','O2']:
 f['baseline-heat-'+opt+'-RESULT.json']=old['heat-'+opt+'/RESULT.json']
 for kind,prefix in [('composed-qualified-','composed-'),('composed-rollback-final-','rollback-'),('composed-heat-preserve-','heat-'),('composed-project-preserve-','project-')]:proof(ROOT.parent/(kind+opt),prefix+opt)
 for kind,prefix in [('composed-ksatexm-','ksatexm-'),('composed-hydrostatic-','proof-')]:proof(ROOT.parent/(kind+opt),'column-inherited/'+prefix+opt,'column-inherited/executed/')
 for kind,prefix in [('composed-final-','composed-build-'),('composed-physical-','composed-physical-')]:addtree(ROOT.parent/(kind+opt),prefix+opt)
 addtree(ROOT.parent/('composed-proof-'+opt),'earlier-composed-compile-'+opt)
addtree(ROOT.parent/'composed-pilot','earlier-composed-pilot')
f['composed-parent/proof.json']=(ROOT.parent/'composed-parent-proof.json').read_bytes();f['composed-parent/commit.raw']=subprocess.check_output(['git','cat-file','commit',BASE],cwd=ROOT);f['COMPOSED_OMITTED_BINARIES.json']=json.dumps(omitted,sort_keys=True).encode();f['MANIFEST.json']=json.dumps({p:sha(b)for p,b in f.items()},sort_keys=True).encode();buf=io.BytesIO()
with tarfile.open(fileobj=buf,mode='w:xz',preset=9)as t:
 for p,b in sorted(f.items()):
  m=tarfile.TarInfo(p);m.size=len(b);m.mode=0o644;t.addfile(m,io.BytesIO(b))
raw=buf.getvalue();ep='integration/mc-sol01/drainage/COMPOSED_HEAT_EVIDENCE.tar.xz.b64';(ROOT/ep).write_bytes(base64.b64encode(raw));s=json.loads((D/'COMPOSED_HEAT_STATUS.json').read_text());delta={x.split('\t')[1]:x.split('\t')[0]for x in subprocess.check_output(['git','diff','--name-status',BASE,'--','src','app','tools','tests','examples','reference','.github','integration/audits'],cwd=ROOT,text=True).splitlines()};delta['integration/audits/verify_composed_heat_current.py']='A';post=list(delta)+['integration/mc-sol01/drainage/'+p for p in ['qualify_composed_heat.py','qualify_composed_rollback.py','prepare_composed_heat_build.py','seal_composed_heat.py','qualify_project_heat.py']];a=json.loads(f['composed-O0/RESULT.json']);b=json.loads(f['composed-O2/RESULT.json']);assert a['results']==b['results'];budgets=[row for r in [a,b]for v in r['results'].values()for row in v['budget']]
s.update(stage='SOURCE_BOUND_QUALIFICATION_SEALED',qualified=True,evidence=dict(path=ep,sha256=sha(raw),bytes=len(raw),members=len(f)),scientific_delta=delta,postimages={p:sha((ROOT/p).read_bytes())for p in post},remaining_implementation_blockers=[],remaining_evidence_blockers=['Actual canonical merge/postimage validation'],physical_results=dict(source_nodes=12,cases=4,days_per_case=481,exact_restarts=4,typed_pair_controls=14,real_joint_rollback_retry_cases=2,rejected_project_processes=16,water_max_cm=max(abs(float(r['water_residual_cm']))for r in budgets),solute_max_mg_cm2=max(abs(float(r['solute_residual_mg_cm2']))for r in budgets),observed_heat_max_j_cm2=max(float(r['observed_heat_residual_j_cm2'])for r in budgets),fresh_preservation_cases=20,fresh_preservation_restarts=20,old_thermal_format_exact=True,equations_unchanged=True,committed_boesten_pair=b['results']['boesten']['committed_pairs']),admission_record='integration/mc-sol01/drainage/COMPOSED_HEAT_ADMISSION.json',hosted_checks_selection='NOT_SELECTED_IMPACT: current local O0/O2 native qualification and owning source gates; [skip ci] avoids unchanged broad suites, no hosted PASS claimed.',next_action='Validate source/raw owner and docs; integrate exact tree and verify actual canonical merge')
(D/'COMPOSED_HEAT_STATUS.json').write_text(json.dumps(s,indent=2)+'\n');print(json.dumps(dict(bytes=len(raw),members=len(f),physical_results=s['physical_results'])))

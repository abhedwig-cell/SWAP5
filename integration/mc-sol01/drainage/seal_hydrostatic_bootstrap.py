"""Seal executed inputs and raw proof; preserve failed rounds without PASS credit."""
import base64,hashlib,io,json,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];SCRATCH=ROOT.parent;BASE='a44c346216b67a2b9db4acbcfa18c229442648a9';D=ROOT/'integration/mc-sol01/drainage';sha=lambda b:hashlib.sha256(b).hexdigest();files={};omitted={}
def addtree(root,prefix):
 for p in sorted(root.rglob('*')):
  if not p.is_file():continue
  b=p.read_bytes();name=prefix+'/'+str(p.relative_to(root))
  if p.suffix in ['.o','.mod','.a']or b.startswith(b'\x7fELF'):omitted[name]=dict(bytes=len(b),sha256=sha(b));continue
  files[name]=b
for opt in ['O0','O2']:
 path=SCRATCH/('hydrostatic-qualified-v2-'+opt);r=json.loads((path/'RESULT.json').read_text());assert r['status']=='HYDROSTATIC_SOURCE_HEAT_FILE_RESTART_AND_INCUMBENT_PASS';addtree(path,'proof-'+opt);addtree(SCRATCH/('hydrostatic-build-complete-'+opt),'build-'+opt)
 for p,h in r['input_sha256'].items():
  b=(ROOT/p).read_bytes();assert sha(b)==h,p;files['executed/'+p]=b
 for name in ['incumbent-0.5','incumbent-1.0','incumbent-2.0','incumbent-water','incumbent-explicit-heat']:
  case=name.replace('incumbent-','bootstrap-',1)if name[10:11].isdigit()else name
  directory='full'if case.startswith('bootstrap-')else'current'
  for p in r['results'][name]:files['incumbent-'+opt+'/'+name+'/'+p]=(path/'predecessor'/case/directory/p).read_bytes()
for p in sorted(SCRATCH.glob('hydrostatic-proof*')):
 if p.is_dir():addtree(p,'earlier-rounds/'+p.name)
for opt in ['O0','O2']:addtree(SCRATCH/('hydrostatic-qualified-'+opt),'earlier-rounds/hydrostatic-qualified-'+opt)
for p in sorted(SCRATCH.glob('hydrostatic-build*')):
 if p.is_dir()and'-final-'not in p.name:addtree(p,'earlier-rounds/'+p.name)
files['parent/proof.json']=(SCRATCH/'hydrostatic-parent-proof.json').read_bytes();files['parent/owner.py']=subprocess.check_output(['git','show',BASE+':integration/audits/verify_native_heat_bootstrap_current.py'],cwd=ROOT);files['parent/commit.raw']=subprocess.check_output(['git','cat-file','commit',BASE],cwd=ROOT)
files['OMITTED_BINARY_INVENTORY.json']=json.dumps(omitted,sort_keys=True).encode();files['MANIFEST.json']=json.dumps({p:sha(b)for p,b in files.items()},sort_keys=True).encode();buf=io.BytesIO()
with tarfile.open(fileobj=buf,mode='w:xz',preset=6)as t:
 for p,b in sorted(files.items()):
  m=tarfile.TarInfo(p);m.size=len(b);m.mode=0o644;t.addfile(m,io.BytesIO(b))
raw=buf.getvalue();ep='integration/mc-sol01/drainage/HYDROSTATIC_BOOTSTRAP_EVIDENCE.tar.xz.b64';(ROOT/ep).write_bytes(base64.b64encode(raw))
s=json.loads((D/'HYDROSTATIC_BOOTSTRAP_STATUS.json').read_text());delta={line.split('\t')[1]:line.split('\t')[0]for line in subprocess.check_output(['git','diff','--name-status',BASE,'--','src','app','tools','tests','examples','reference','.github','integration/audits'],cwd=ROOT,text=True).splitlines()}
for p in ['integration/audits/verify_hydrostatic_bootstrap_current.py']:delta[p]='A'
post=list(delta)+['integration/mc-sol01/drainage/'+p for p in ['HYDROSTATIC_BOOTSTRAP_CONTRACT.md','qualify_hydrostatic_bootstrap.py','seal_hydrostatic_bootstrap.py']]
r0=json.loads(files['proof-O0/RESULT.json']);r2=json.loads(files['proof-O2/RESULT.json']);assert r0['results']==r2['results']
budgets=[row for r in [r0,r2]for k,v in r['results'].items()if k.startswith('app-')for row in v['budget']]
s.update(stage='SOURCE_BOUND_QUALIFICATION_SEALED',qualified=True,scientific_delta=delta,postimages={p:sha((ROOT/p).read_bytes())for p in post},evidence=dict(path=ep,sha256=sha(raw),bytes=len(raw),members=len(files)),current_executed_inputs=len(r0['input_sha256']),physical_results=dict(source_cases=18,source_negative_processes=22,coupled_cases=6,fresh_process_restarts=6,file_negative_processes=16,incumbent_comparisons=10,water_max_cm=max(abs(r['water_residual_cm'])for r in budgets),solute_max_mg_cm2=max(abs(r['solute_residual_mg_cm2'])for r in budgets),O0_O2_exact=True,original_hydrostatic_and_heat_component_nodes=112),fully_saturated_file_execution=False,original_hydraulic_KSATEXM_import=False,full_original_Andelst=False,admission_record='integration/mc-sol01/drainage/HYDROSTATIC_BOOTSTRAP_ADMISSION.json',next_action='Verify sealed owner/controls/docs, publish coherent implementation and check actual canonical merge')
s['exclusions']+=['Fully saturated file initialization','Original KSATEXM hydraulic import','External BBC file staging/orchestration']
(D/'HYDROSTATIC_BOOTSTRAP_STATUS.json').write_text(json.dumps(s,indent=2)+'\n');print(json.dumps(dict(evidence_bytes=len(raw),members=len(files),scientific_delta=delta,physical_results=s['physical_results'])))

"""Seal source/native-file heat qualification and retained initial failures."""
import base64,hashlib,io,json,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];W=ROOT.parent;BASE='de6299171e3b13d8f444993e9bf8893ad15fec72';sha=lambda b:hashlib.sha256(b).hexdigest();f={};excluded={}
def add(name,p):
 b=p.read_bytes()
 if p.suffix in ['.o','.mod','.a']or b.startswith(b'\x7fELF'):excluded[name]={'bytes':len(b),'sha256':sha(b)};return
 f[name]=b
for opt in ['O0','O2']:
 for label,folder in [('source-'+opt,'native-heat-source-final-'+opt),('app-'+opt,'native-heat-app-final-'+opt),('initial-build-'+opt,'native-heat-column-'+opt),('repaired-build-'+opt,'native-heat-repaired-'+opt),('final-build-'+opt,'native-heat-final-'+opt)]:
  p=W/folder
  for q in sorted(p.rglob('*')):
   if q.is_file():add(label+'/'+str(q.relative_to(p)),q)
for folder in ['native-heat-component-O0','native-heat-component-O2','native-heat-component-v2-O0','native-heat-component-v2-O2','native-heat-component-v3-O0','native-heat-component-v3-O2','native-heat-component-v4-O0','native-heat-component-v4-O2','native-heat-app-pilot-O0','native-heat-app-pilot2-O0','native-heat-app-qualified-O0','native-heat-app-qualified-O2']:
 p=W/folder
 if p.exists():
  for q in sorted(p.rglob('*')):
   if q.is_file():add('earlier-rounds/'+folder+'/'+str(q.relative_to(p)),q)
f['parent/proof.json']=(W/'native-heat-parent-proof.json').read_bytes();f['parent/commit.raw']=subprocess.check_output(['git','cat-file','commit',BASE],cwd=ROOT);f['parent/owner.py']=subprocess.check_output(['git','show',BASE+':integration/audits/verify_macro_trace_current.py'],cwd=ROOT)
inputs={}
for name in ['source-O0/RESULT.json','source-O2/RESULT.json','app-O0/RESULT.json','app-O2/RESULT.json']:
 for p,h in json.loads(f[name])['input_sha256'].items():
  raw=(ROOT/p).read_bytes();assert sha(raw)==h,('stale executed source',p);f['executed-sources/'+p]=raw;inputs[p]=h
f['EXCLUDED.json']=json.dumps(excluded,indent=2).encode();f['INPUTS.json']=json.dumps(inputs,indent=2).encode();f['MANIFEST.json']=json.dumps({p:sha(b)for p,b in sorted(f.items())},sort_keys=True).encode();buf=io.BytesIO()
with tarfile.open(fileobj=buf,mode='w:xz')as t:
 for name,b in sorted(f.items()):
  i=tarfile.TarInfo(name);i.size=len(b);i.mtime=0;t.addfile(i,io.BytesIO(b))
raw=buf.getvalue();path='integration/mc-sol01/drainage/NATIVE_HEAT_BOOTSTRAP_EVIDENCE.tar.xz.b64';(ROOT/path).write_bytes(base64.b64encode(raw));record='integration/mc-sol01/drainage/NATIVE_HEAT_BOOTSTRAP_STATUS.json';r=json.loads((ROOT/record).read_text());r.update(stage='SOURCE_COMPONENT_AND_CURRENT_FILE_QUALIFICATION_SEALED',qualified=True,canonically_admitted=False,evidence={'path':path,'sha256':sha(raw),'bytes':len(raw),'members':len(f)},current_executed_inputs=len(inputs),admission_record='integration/mc-sol01/drainage/NATIVE_HEAT_BOOTSTRAP_ADMISSION.json',qualification_scope='112-node original Andelst thermal component and constructed current two-layer coupled file application; not full original hydraulic/crop/macro application',next_action='Validate source/raw controls and docs, publish one coherent PR, verify actual merge and persist separate admission')
science=['src','app','tools','tests','examples','reference','.github','integration/audits'];delta={x.split('\t')[1]:x.split('\t')[0]for x in subprocess.check_output(['git','diff','--name-status',BASE,'--',*science],cwd=ROOT,text=True).splitlines()}
for p in ['integration/audits/verify_native_heat_bootstrap_current.py','examples/solute_column/native_heat.nml','examples/solute_column/layered_heat.swp']:delta[p]='A'
r['scientific_delta']=delta;r['postimages']={p:sha((ROOT/p).read_bytes())for p in delta}
for p in ['integration/mc-sol01/drainage/NATIVE_HEAT_BOOTSTRAP_CONTRACT.md','integration/mc-sol01/drainage/qualify_native_heat_bootstrap.py','integration/mc-sol01/drainage/qualify_native_heat_application.py','integration/mc-sol01/drainage/seal_native_heat_bootstrap.py']:r['postimages'][p]=sha((ROOT/p).read_bytes())
r['physical_results']={'source_nodes':112,'source_valid_cases_O0_O2':4,'source_negative_processes':22,'constructor_negative_assertions':28,'coupled_cases':6,'separate_process_restarts':6,'file_negative_processes':18,'water_max_cm':4.508112633194727e-16,'solute_max_mg_cm2':1.7539366226754227e-13,'O0_O2_all_native_physical_outputs_exact':True,'old_heat_procedure_and_type_bytes_exact':True,'old_water_and_explicit_heat_application_outputs_exact':True}
r['preservation_selection']={'old_heat_routines':'Exact byte projection after removing additive source initializer/export; original main versus current file application exact','NUT_and_macro':'Dated canonical17-control proof retained; no fresh NUT/macro run claimed or selected for unused additive initializer','FSI35':'All27 executable dependency sources unchanged; select current source boundary only','full_FCI':'NOT_SELECTED_IMPACT','highest_low_air':'NOT_SELECTED_POLICY','RossFast':'NOT_SELECTED'}
(ROOT/record).write_text(json.dumps(r,indent=2)+'\n');print(json.dumps({'evidence_bytes':len(raw),'members':len(f),'inputs':len(inputs),'delta':delta}))

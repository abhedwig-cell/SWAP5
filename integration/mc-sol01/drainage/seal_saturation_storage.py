"""Seal bounded arithmetic repair and all failed/censored predecessor work."""
import base64,hashlib,io,json,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];D=ROOT/'integration/mc-sol01/drainage';sha=lambda b:hashlib.sha256(b).hexdigest();f={};omitted={}
def addtree(root,prefix):
 for p in sorted(root.rglob('*')):
  if not p.is_file():continue
  b=p.read_bytes();name=prefix+'/'+str(p.relative_to(root))
  if p.suffix in ['.o','.mod','.a']or b.startswith(b'\x7fELF'):omitted[name]=dict(bytes=len(b),sha256=sha(b));continue
  f[name]=b
for opt in ['O0','O2']:
 for kind,prefix in [('storage-component-','component-'),('storage-final-','native-')]:
  root=ROOT.parent/(kind+opt);r=json.loads((root/'RESULT.json').read_text());addtree(root,prefix+opt)
  for p,h in r['input_sha256'].items():
   b=(ROOT/p).read_bytes();assert sha(b)==h,p;f['executed/'+p]=b
 addtree(ROOT.parent/('storage-build-'+opt),'build-'+opt)
 for kind in ['storage-qualified-','storage-focused-','storage-selected-']:
  root=ROOT.parent/(kind+opt)
  if root.exists():addtree(root,'censored/'+kind+opt)
for name in ['day10-diagnostic','day10-consistent-probe','day10-metric-diagnostic','day10-saturated-seed-probe','day10-damped-probe','day10-residual','day10-convergence','day10-storage-probe']:
 root=ROOT.parent/name
 if root.exists():addtree(root,'earlier-private/'+name)
for p in ROOT.parent.glob('probe_*day10.py'):f['earlier-private/scripts/'+p.name]=p.read_bytes()
f['parent/proof.json']=(ROOT.parent/'storage-parent-proof.json').read_bytes();f['parent/commit.raw']=subprocess.check_output(['git','cat-file','commit','3f1b2e5eca5881e5e6739686aa1338dc9ebd5267'],cwd=ROOT);f['OMITTED_BINARIES.json']=json.dumps(omitted,sort_keys=True).encode();f['MANIFEST.json']=json.dumps({p:sha(b)for p,b in f.items()},sort_keys=True).encode();buf=io.BytesIO()
with tarfile.open(fileobj=buf,mode='w:xz',preset=9)as t:
 for p,b in sorted(f.items()):
  m=tarfile.TarInfo(p);m.size=len(b);m.mode=0o644;t.addfile(m,io.BytesIO(b))
raw=buf.getvalue();ep='integration/mc-sol01/drainage/SATURATION_STORAGE_EVIDENCE.tar.xz.b64';(ROOT/ep).write_bytes(base64.b64encode(raw));s=json.loads((D/'SATURATION_STORAGE_STATUS.json').read_text());delta={x.split('\t')[1]:x.split('\t')[0]for x in subprocess.check_output(['git','diff','--name-status',s['baseline'],'HEAD','--','src','app','tools','tests','examples','reference','.github','integration/audits'],cwd=ROOT,text=True).splitlines()};post=list(delta)+['integration/mc-sol01/drainage/'+p for p in ['SATURATION_STORAGE_CONTRACT.md','SATURATION_STORAGE_PRESERVATION.json','qualify_saturation_profile.py','qualify_saturation_component.py','rebuild_saturation_storage.py','seal_saturation_storage.py','verify_original_matrix_profile.py']];proof=[json.loads(f['native-'+opt+'/RESULT.json'])for opt in ['O0','O2']];assert proof[0]['results']==proof[1]['results'];budgets=[row for r in proof for row in r['results']['budget']]
s.update(stage='SOURCE_BOUND_BOUNDED_QUALIFICATION',persisted=True,tested=True,qualified=True,canonically_admitted=False,evidence=dict(path=ep,sha256=sha(raw),bytes=len(raw),members=len(f)),scientific_delta=delta,postimages={p:sha((ROOT/p).read_bytes())for p in post},physical_results=dict(cases=2,days=30,nodes=112,source_layers=8,exact_day9_restarts=2,direct_real128_cases=1728,component_link_provider_objects=2,reused_native_providers_per_optimization=192,public_modules_exact=True,water_max_cm=max(abs(float(r['water_residual_cm']))for r in budgets),solute_max_mg_cm2=max(abs(float(r['solute_residual_mg_cm2']))for r in budgets),observed_heat_max_j_cm2=max(float(r['observed_heat_residual_j_cm2'])for r in budgets)),full481_qualified=False,full_original_Andelst=False,remaining_blockers=['Actual canonical admission and merge/postimage checks'],next_action='Run current owning controls and affected F-SI35, integrate exact tree and verify actual merge',admission_record='integration/mc-sol01/drainage/SATURATION_STORAGE_ADMISSION.json');(D/'SATURATION_STORAGE_STATUS.json').write_text(json.dumps(s,indent=2)+'\n');print(json.dumps(s['evidence']))

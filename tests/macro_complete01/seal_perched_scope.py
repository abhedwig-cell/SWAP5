from pathlib import Path
import json,hashlib,zipfile,subprocess
ROOT=Path(__file__).resolve().parents[2];R=ROOT/'integration/macro-complete01';res=json.loads((R/'RESOURCE_PATHS.json').read_text());files={};sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
for p in R.iterdir():
 if p.is_file() and p.suffix=='.json' and p.name.startswith(('BLOCK35_','SCOPE35_','PERIOD33_O0_65','PERIOD33_O2_65')):files['records/'+p.name]=p
for opt in ['O0','O2']:
 b=Path(res[opt]['path'])
 for label in ['GEOMETRY_V33_DAY65','SCOPE35_CONTEXT64TO65','worker-geometry-scope-observer35']:
  for p in (b/label).rglob('*'):
   if p.is_file() and p.suffix!='.s':files['raw/'+opt+'/'+p.relative_to(b).as_posix()]=p
for name in ['geometry_scope_probe.f90','build_geometry_scope_probe.py','assess_geometry_scope.py']:
 p=ROOT/'tests/macro_complete01'/name;files['source/'+name]=p
m={n:dict(sha256=sha(p),bytes=p.stat().st_size) for n,p in files.items()};zp=R/'BLOCK35_EVIDENCE.zip';assert not zp.exists()
with zipfile.ZipFile(zp,'w',zipfile.ZIP_DEFLATED,compresslevel=3) as z:
 for n,p in files.items():z.write(p,n)
 z.writestr('MANIFEST.json',json.dumps(m,indent=2))
with zipfile.ZipFile(zp) as z:
 for n,q in m.items():assert hashlib.sha256(z.read(n)).hexdigest()==q['sha256']
q=dict(sha256=sha(zp),bytes=zp.stat().st_size,members=len(m),checkpoint=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),models_launched=0,current_source_archive=json.loads((R/'BLOCK33_EVIDENCE.json').read_text())['sha256'],scope='Actual20scappedoriginalday65 and distinctread-onlyperchedscopeprobe, first64witnessesexactO0/O2, noacceptedday65',accepted_hashes_verified_by_reading_all_members=True)
(R/'BLOCK35_EVIDENCE.json').write_text(json.dumps(q,indent=2)+'\n');print(json.dumps(q))

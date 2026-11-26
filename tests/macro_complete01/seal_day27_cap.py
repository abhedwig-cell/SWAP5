from pathlib import Path
import json,hashlib,zipfile,subprocess
ROOT=Path(__file__).resolve().parents[2];R=ROOT/'integration/macro-complete01';res=json.loads((R/'RESOURCE_PATHS.json').read_text());files={};sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
for name in ['BLOCK29_DAY27_CAP_DIAGNOSIS.json','BLOCK28_PRIOR_TRAJECTORY_COMPARISON.json','PERIOD27_O0_27_29.json','PERIOD27_O2_27_29.json']:
 files['records/'+name]=R/name
files['source/assess_day27_cap.py']=ROOT/'tests/macro_complete01/assess_day27_cap.py'
for opt in ['O0','O2']:
 b=Path(res[opt]['path'])/'ORDINARY_V27_FIXED_DAY27'
 for p in b.rglob('*'):
  if p.is_file():files['raw/'+opt+'/'+p.relative_to(b).as_posix()]=p
m={n:dict(sha256=sha(p),bytes=p.stat().st_size) for n,p in files.items()};zp=R/'BLOCK29_EVIDENCE.zip';assert not zp.exists()
with zipfile.ZipFile(zp,'w',zipfile.ZIP_DEFLATED,compresslevel=3) as z:
 for n,p in files.items():z.write(p,n)
 z.writestr('MANIFEST.json',json.dumps(m,indent=2))
with zipfile.ZipFile(zp) as z:
 for n,q in m.items():assert hashlib.sha256(z.read(n)).hexdigest()==q['sha256']
q=dict(sha256=sha(zp),bytes=zp.stat().st_size,members=len(m),checkpoint=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),models_launched=0,source_and_fixed_prefix_archive=json.loads((R/'BLOCK28_EVIDENCE.json').read_text())['sha256'],scope='Two genuinely20scapped day27routes, noacceptedday27receipt; common976observedrows exact; no unchangedrerun.',accepted_hashes_verified_by_reading_all_members=True)
(R/'BLOCK29_EVIDENCE.json').write_text(json.dumps(q,indent=2)+'\n');print(json.dumps(q))

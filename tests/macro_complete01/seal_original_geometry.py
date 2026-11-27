from pathlib import Path
import json,hashlib,zipfile,subprocess
ROOT=Path(__file__).resolve().parents[2];R=ROOT/'integration/macro-complete01';res=json.loads((R/'RESOURCE_PATHS.json').read_text());files={};sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
for p in R.iterdir():
 if p.is_file() and p.suffix=='.json' and (p.name.startswith(('BLOCK33_','GEOMETRY_V33_','GEOMETRYFD33')) or p.name=='BLOCK32_ORIGINAL_PREFIX41_QUALIFICATION.json' or p.name.startswith(('PERIOD31_O0_35','PERIOD31_O0_38','PERIOD31_O0_41','PERIOD31_O2_35','PERIOD31_O2_38','PERIOD31_O2_41'))):files['records/'+p.name]=p
for opt in ['O0','O2']:
 b=Path(res[opt]['path'])
 for d in b.iterdir():
  if d.is_dir() and (d.name.startswith(('worker-coupled-original-geometry-v33','worker-live-geometry-jacobian-v33','GEOMETRY_V33_','GEOMETRYFD33')) or d.name in ['PREPARED_V31_DAY'+str(day) for day in range(35,43)]):
   for p in d.rglob('*'):
    if p.is_file() and p.suffix!='.s':files['raw/'+opt+'/'+p.relative_to(b).as_posix()]=p
for folder in ['app/hybrid_water','tests/macro_complete01']:
 for p in (ROOT/folder).iterdir():
  if p.is_file() and (folder.startswith('tests/') or p.name.startswith('macro_') or p.name=='coupled_macro_policy.py'):files['source/'+folder+'/'+p.name]=p
files['source/app/support/restart_publish.c']=ROOT/'app/support/restart_publish.c'
m={n:dict(sha256=sha(p),bytes=p.stat().st_size) for n,p in files.items()};zp=R/'BLOCK33_EVIDENCE.zip';assert not zp.exists()
with zipfile.ZipFile(zp,'w',zipfile.ZIP_DEFLATED,compresslevel=3) as z:
 for n,p in files.items():z.write(p,n)
 z.writestr('MANIFEST.json',json.dumps(m,indent=2))
with zipfile.ZipFile(zp) as z:
 for n,q in m.items():assert hashlib.sha256(z.read(n)).hexdigest()==q['sha256']
q=dict(sha256=sha(zp),bytes=zp.stat().st_size,members=len(m),checkpoint=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),models_launched=0,physicalprefix_archive=json.loads((R/'BLOCK28_EVIDENCE.json').read_text())['sha256'],scope='PreparedV31actualdays35..41plusrealrefusal42; V33context42own43; allgeometryFDanchors/buildfail/negativekink andsmoothproof; allrawmembersverified',accepted_hashes_verified_by_reading_all_members=True)
(R/'BLOCK33_EVIDENCE.json').write_text(json.dumps(q,indent=2)+'\n');print(json.dumps(q))

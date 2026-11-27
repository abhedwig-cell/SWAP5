from pathlib import Path
import json,hashlib,zipfile,subprocess
ROOT=Path(__file__).resolve().parents[2];R=ROOT/'integration/macro-complete01';res=json.loads((R/'RESOURCE_PATHS.json').read_text());files={};sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
for p in R.iterdir():
 if p.is_file() and p.suffix=='.json' and p.name.startswith(('BLOCK31_','BLOCK32_','PROFILER30_','PREPARED_V31_','PERIOD31_')):files['records/'+p.name]=p
for opt in ['O0','O2']:
 b=Path(res[opt]['path'])
 for d in b.iterdir():
  if d.is_dir() and d.name.startswith(('worker-runtime-profiler30','worker-coupled-prepared-publisher-v31','PROFILER30_','PREPARED_V31_')):
   for p in d.rglob('*'):
    if p.is_file() and p.suffix!='.s':files['raw/'+opt+'/'+p.relative_to(b).as_posix()]=p
for folder in ['app/hybrid_water','tests/macro_complete01']:
 for p in (ROOT/folder).iterdir():
  if p.is_file() and (folder.startswith('tests/') or p.name.startswith('macro_') or p.name=='coupled_macro_policy.py'):files['source/'+folder+'/'+p.name]=p
files['source/app/support/restart_publish.c']=ROOT/'app/support/restart_publish.c'
m={n:dict(sha256=sha(p),bytes=p.stat().st_size) for n,p in files.items()};zp=R/'BLOCK32_EVIDENCE.zip';assert not zp.exists()
with zipfile.ZipFile(zp,'w',zipfile.ZIP_DEFLATED,compresslevel=3) as z:
 for n,p in files.items():z.write(p,n)
 z.writestr('MANIFEST.json',json.dumps(m,indent=2))
with zipfile.ZipFile(zp) as z:
 for n,q in m.items():assert hashlib.sha256(z.read(n)).hexdigest()==q['sha256']
q=dict(sha256=sha(zp),bytes=zp.stat().st_size,members=len(m),checkpoint=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),models_launched=0,physicalprefix_archive=json.loads((R/'BLOCK28_EVIDENCE.json').read_text())['sha256'],scope='Readonlyprofiler30day27, preparedpublisher31day27+own28..34; existingfixedV27physicalprefixreferenceonce; allrawmembersverified',accepted_hashes_verified_by_reading_all_members=True)
(R/'BLOCK32_EVIDENCE.json').write_text(json.dumps(q,indent=2)+'\n');print(json.dumps(q))

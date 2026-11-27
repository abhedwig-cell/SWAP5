from pathlib import Path
import sys,json,hashlib,zipfile,subprocess
ROOT=Path(__file__).resolve().parents[2];R=ROOT/'integration/macro-complete01';res=json.loads((R/'RESOURCE_PATHS.json').read_text());start,end=map(int,sys.argv[1:3]);assert 44<=start<=end;files={};sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
for p in R.glob('PERIOD33_*.json'):
 q=json.loads(p.read_text())
 if start<=q['start'] and q['end']<=end:files['records/'+p.name]=p
p=R/f'BLOCK34_V33_ORIGINAL41TO{end}_QUALIFICATION.json';assert p.is_file();files['records/'+p.name]=p
for opt in ['O0','O2']:
 b=Path(res[opt]['path'])
 for day in range(start,end+1):
  d=b/f'GEOMETRY_V33_DAY{day}';assert d.is_dir()
  for p in d.rglob('*'):
   if p.is_file():files[f'raw/{opt}/'+p.relative_to(b).as_posix()]=p
m={n:dict(sha256=sha(p),bytes=p.stat().st_size) for n,p in files.items()};name=f'BLOCK34_RANGE{start}_{end}_EVIDENCE';zp=R/(name+'.zip');assert not zp.exists()
with zipfile.ZipFile(zp,'w',zipfile.ZIP_DEFLATED,compresslevel=3) as z:
 for n,p in files.items():z.write(p,n)
 z.writestr('MANIFEST.json',json.dumps(m,indent=2))
with zipfile.ZipFile(zp) as z:
 for n,q in m.items():assert hashlib.sha256(z.read(n)).hexdigest()==q['sha256']
q=dict(sha256=sha(zp),bytes=zp.stat().st_size,members=len(m),checkpoint=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),models_launched=0,current_source_and_initialcontext_archive=json.loads((R/'BLOCK33_EVIDENCE.json').read_text())['sha256'],actual_current_candidate_own_day_range=[start,end],accepted_hashes_verified_by_reading_all_members=True)
(R/(name+'.json')).write_text(json.dumps(q,indent=2)+'\n');print(json.dumps(q))

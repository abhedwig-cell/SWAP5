"""Retain paired native policy observations and original production control."""
import base64,csv,hashlib,io,json,runpy,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).resolve().parent
sha=lambda b:hashlib.sha256(b).hexdigest()
def assess(files):
 r=json.loads(files['runs/RESULT.json']);assert r['status']=='DIAGNOSTICS_COMPLETE' and len(r['cases'])==12
 passed=0;rejected=0;maxima={'water':0.,'solute':0.};streams={};profiles={}
 for e in r['cases']:
  base=f"runs/{e['opt']}-{e['head']}-{e['policy']}/";stdout=files[base+'stdout'].decode();streams[e['opt'],e['head'],e['policy']]=stdout
  if e['head']=='uniform':
   assert e['returncode']==1 and 'joint status/water/chemical:            2           2           1' in stdout
   assert 'rejected window/process/completed:           1           0           0' in stdout and base+'restart.bin' not in files
   rejected+=1
  else:
   assert e['returncode']==0 and 'SWAP5_SOLUTE_COLUMN_COMPLETED' in stdout
   rows=list(csv.DictReader(io.StringIO(files[base+'budget.csv'].decode())));assert len(rows)==4
   for row in rows:
    for s,u in [('water','cm'),('solute','mg_cm2')]:
     residual=float(row[f'{s}_end_{u}'])-float(row[f'{s}_start_{u}'])-float(row[f'{s}_in_{u}'])+float(row[f'{s}_out_{u}']);assert abs(residual)<1e-10;maxima[s]=max(maxima[s],abs(residual))
   profiles[e['opt'],e['policy']]=files[base+'state.csv'];passed+=1
 assert passed==rejected==6
 assert all(streams['o0',h,p]==streams['o2',h,p] for h in ['uniform','sloping'] for p in ['frozen','picard','continuous'])
 assert all(profiles['o0',p]==profiles['o2',p] for p in ['frozen','picard','continuous'])
 ref=json.loads(files['reference/event.json']);assert ref['returncode']==1
 assert files['reference/stdout']==files['runs/o2-uniform-frozen/stdout']
 return dict(status='PRE_CHEMISTRY_HYDRAULIC_REJECTION_REPRODUCED_IN_ORIGINAL_NATIVE',native_policy_cases=12,completed=6,water_rejected=6,original_reference_water_rejection_exact=True,O0_O2_diagnostic_and_successful_profile_bytes_equal=True,maxima=maxima,root_cause_fully_identified=False,production_repair_qualified=False)
def main():
 scratch=ROOT.parent;files={}
 for name,folder in [('runs',scratch/'wet-initial-diagnostic'),('reference',scratch/'wet-original-control')]:
  files.update({name+'/'+str(p.relative_to(folder)):p.read_bytes() for p in folder.rglob('*') if p.is_file()})
 build=scratch/'wet-reference-recovered-o2';b=json.loads((build/'build.json').read_text());assert b['status']=='BUILT_RESEARCH_NATIVE'
 files['reference/build.json']=(build/'build.json').read_bytes()
 failed=scratch/'wet-reference-o2/build.json'
 if failed.exists():files['failed_compiler_route/build.json']=failed.read_bytes()
 for p in b['generated']:files['reference/generated/'+p]=(build/p).read_bytes()
 for p,h in b['inputs'].items():v=(ROOT/p).read_bytes();assert sha(v)==h;files['source/'+p]=v
 for p in build.glob('*'):
  if p.suffix in ['.stdout','.stderr']:files['reference/compiler/'+p.name]=p.read_bytes()
 for p in ['run.py','seal.py']:files['validation/'+p]=(HERE/p).read_bytes()
 result=assess(files);files['RESULT.json']=json.dumps(result).encode();files['MANIFEST.json']=json.dumps({p:sha(b) for p,b in files.items()}).encode();s=io.BytesIO()
 with tarfile.open(fileobj=s,mode='w:xz') as t:
  for p,b in sorted(files.items()):m=tarfile.TarInfo(p);m.size=len(b);m.mtime=0;t.addfile(m,io.BytesIO(b))
 raw=s.getvalue();(HERE/'EVIDENCE.tar.xz.b64').write_bytes(base64.encodebytes(raw));(HERE/'STATUS.json').write_text(json.dumps(dict(result=result,evidence_sha256=sha(raw),evidence_bytes=len(raw),canonically_admitted=False,next_safe_work='Trace accepted water time and final failing trial around wet-surface depletion in original water owner; do not modify FCT chemistry or relax guards.'),indent=2)+'\n');print(json.dumps(result,indent=2))
if __name__=='__main__':main()

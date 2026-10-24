"""Persist exact successful native candidate continuations, never admission."""
import base64,hashlib,io,json,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).resolve().parent
sha=lambda b:hashlib.sha256(b).hexdigest()
def main():
 files={};reports={};scratch=ROOT.parent
 for opt,build in [('o0','wet-neighbor'),('o2','wet-neighbor-o2')]:
  run=scratch/('neighbor-restart-'+opt);r=json.loads((run/'RESULT.json').read_text());assert r['status']=='BOUNDED_RESEARCH_CANDIDATE_NATIVE_RESTART_PASS';reports[opt]=r
  for p in run.rglob('*'):
   if not p.is_file():continue
   b=p.read_bytes()
   if p.name in ['stdout','stderr']:
    key='streams/'+sha(b);files[key]=b;files['runs-'+opt+'/'+str(p.relative_to(run))+'.sha256']=sha(b).encode()
   else:files['runs-'+opt+'/'+str(p.relative_to(run))]=b
  folder=scratch/build
  for p in folder.iterdir():
   if p.is_file() and p.suffix in ['.f90','.json']:files['build-'+opt+'/'+p.name]=p.read_bytes()
 for head in ['uniform','sloping']:
  for label in ['full','split','resume']:
   for p in ['state.csv','endpoint.csv','restart.bin','budget.csv']:
    key=head+'/'+label+'/'+p;assert files['runs-o0/'+key]==files['runs-o2/'+key],key
 for p in ['trace.py','neighbor.py','run_neighbor.py','seal_neighbor.py']:files['validation/'+p]=(HERE/p).read_bytes()
 result=dict(stage='PRIVATE_ORIGINAL_NATIVE_CANDIDATE_O0_O2_RESTART_PASS',cases=4,processes=12,exact_restarts=4,O0_O2_files_byte_exact=True,production_source_changed=False,production_repair_qualified=False,FCT_caller_requalified=False,restart_policy_identity_isolated=False,next_safe_work='Separate research policy identity; bind full source/compiler/executable closure; negative controls; fresh FCT caller binding and qualified production preservation before any production merge.')
 files['RESULT.json']=json.dumps(result).encode();files['MANIFEST.json']=json.dumps({p:sha(b) for p,b in files.items()}).encode();stream=io.BytesIO()
 with tarfile.open(fileobj=stream,mode='w:xz') as t:
  for p,b in sorted(files.items()):m=tarfile.TarInfo(p);m.size=len(b);m.mtime=0;t.addfile(m,io.BytesIO(b))
 raw=stream.getvalue();encoded=base64.b64encode(raw)
 for i in range(0,len(encoded),500000):(HERE/f'NEIGHBOR_EVIDENCE_{i//500000:02d}.b64').write_bytes(encoded[i:i+500000])
 result['evidence_sha256']=sha(raw);result['evidence_bytes']=len(raw);result['evidence_parts']=(len(encoded)+499999)//500000
 (HERE/'NEIGHBOR_STATUS.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
if __name__=='__main__':main()

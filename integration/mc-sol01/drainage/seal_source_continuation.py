"""Persist completed native generations, including the original admitted seed."""
import argparse,base64,hashlib,io,json,runpy,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];D=Path('integration/mc-sol01/drainage');sha=lambda b:hashlib.sha256(b).hexdigest()
def main():
 p=argparse.ArgumentParser();p.add_argument('output',type=Path);a=p.parse_args();out=a.output;r=json.loads((out/'RESULT.json').read_text());assert r['status']=='CONTINUATION_SEGMENT_PASS';f={'RESULT.json':(out/'RESULT.json').read_bytes()}
 def generation(prefix,folder):
  m=json.loads((folder/'manifest.json').read_text());assert m['status']=='COMPLETE'
  for n in ['manifest.json',*m['files']]:f[prefix+'/'+n]=(folder/n).read_bytes()
 generation('seed',Path(r['seed']))
 for s in r['segments']:generation(s['folder'],out/s['folder'])
 if(out/'year-replay').exists():generation('year-replay',out/'year-replay')
 # Retain the exact executable so continuation survives workspace cleanup.
 recovery=out/'exact-recovery.json'
 if recovery.is_file():
  record=json.loads(recovery.read_text());exe=Path(record['executable']);assert record['status']=='EXACT_RECOVERY' and sha(exe.read_bytes())==r['executable_sha256']==record['actual_executable_sha256']
  f['recovery/exact-recovery.json']=recovery.read_bytes()
 for n in ['inherited-owner.json','inherited-controls.json','year-replay-control.json','year-replay.stdout']:
  if(out/n).is_file():f[n]=(out/n).read_bytes()
 for p in sorted(out.glob('censored-*.json')):f['censored/'+p.name]=p.read_bytes()
 for folder in sorted(out.glob('to-481.pending-*')):
  if(folder/'budget.csv').is_file():f['censored/'+folder.name+'/budget.csv']=(folder/'budget.csv').read_bytes()
 for p in sorted(out.glob('to-*.*')):
  if p.is_file():f['events/'+p.name]=p.read_bytes()
 for n in ['continue_source_profile.py','verify_source_continuation.py','seal_source_continuation.py','SOURCE_PROFILE_CONTINUATION_CONTRACT.md']:f['executed/'+str(D/n)]=(ROOT/D/n).read_bytes()
 result=None
 if r['completed_days']==481:result=runpy.run_path(str(ROOT/D/'verify_source_continuation.py'))['validate'](f)
 f['MANIFEST.json']=(json.dumps({p:sha(b)for p,b in sorted(f.items())},indent=2)+'\n').encode();stream=io.BytesIO()
 with tarfile.open(fileobj=stream,mode='w:xz')as tar:
  for name,b in sorted(f.items()):info=tarfile.TarInfo(name);info.size=len(b);info.mode=0o644;tar.addfile(info,io.BytesIO(b))
 raw=stream.getvalue();cap=D/'SOURCE_PROFILE_CONTINUATION_EVIDENCE.tar.xz.b64';(ROOT/cap).write_bytes(base64.b64encode(raw));status=ROOT/D/'SOURCE_PROFILE_CONTINUATION_STATUS.json';s=json.loads(status.read_text());s.update(stage='FULL_CHAIN_QUALIFIED_PENDING_CANONICAL'if result else'COMPLETED_PREFIX_PERSISTED',persisted=True,tested=True,qualified=bool(result),canonically_admitted=False,completed_days=r['completed_days'],evidence=dict(path=str(cap),sha256=sha(raw),bytes=len(raw),members=len(f)),postimages={str(D/n):sha((ROOT/D/n).read_bytes())for n in ['continue_source_profile.py','verify_source_continuation.py','seal_source_continuation.py','SOURCE_PROFILE_CONTINUATION_CONTRACT.md']},physical_results=r['physical_results'],recovery_point='Complete immutable generation to-'+str(r['completed_days'])+' in evidence capsule',remaining_implementation_blockers=[],remaining_evidence_blockers=['Actual canonical integration and postimage verification']if result else['Complete continuation to day481','Short exact year-boundary replay','Actual canonical integration and postimage verification'],next_action='Integrate and verify actual merge'if result else'Continue once from latest complete generation; no prefix rerun')
 if recovery.is_file():s['postimages'][str(D/'SOURCE_PROFILE_EXACT_RECOVERY.json')]=sha((ROOT/D/'SOURCE_PROFILE_EXACT_RECOVERY.json').read_bytes())
 if result:
  s['qualification']=result;s['full481_qualified']=r['completed_days']==481;s['interruption']='Historical workspace loss resolved by byte-exact executable recovery; original interrupted attempt remains unqualified.'
 status.write_text(json.dumps(s,indent=2)+'\n');print(json.dumps(dict(completed_days=r['completed_days'],qualified=bool(result),capsule=s['evidence'])))
if __name__=='__main__':main()

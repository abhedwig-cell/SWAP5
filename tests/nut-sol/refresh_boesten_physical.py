"""Refresh a private backend body in a verified native build, without ABI drift."""
import argparse,copy,hashlib,json,re,shutil,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
SOURCE='src/runtime/mod_fmr_serialized_reference_backend.f90'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 p=argparse.ArgumentParser();p.add_argument('--previous',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();old=a.previous.resolve();out=a.output.resolve();m=json.loads((old/'build-complete.json').read_text());assert m['status']=='BUILT'
 changed=[p for p,h in m['input_sha256'].items()if sha(ROOT/p)!=h];assert changed==[SOURCE],changed
 before=subprocess.check_output(['git','show',m['candidate']+':'+SOURCE],cwd=ROOT)
 assert hashlib.sha256(before).hexdigest()==m['input_sha256'][SOURCE]
 assert before.split(b'\ncontains\n',1)[0]==(ROOT/SOURCE).read_bytes().split(b'\ncontains\n',1)[0],'public declarations changed'
 assert sha(old/'swap5_solute_column')==m['executable_sha256']
 for p,h in m['generated_input_sha256'].items():assert sha(old/p)==h
 # Every reused compile artifact is sealed before copying.
 original_objects=[Path(e['command'][-1])for e in m['events']if e['category']=='compile']
 seals={str(p.relative_to(old)):sha(p)for p in original_objects+[old/'libttutil.a']+list(old.glob('*.mod'))}
 shutil.copytree(old,out)
 assert all(sha(out/p)==h for p,h in seals.items())
 def relocate(x):
  if isinstance(x,str):return x.replace(str(old),str(out))
  if isinstance(x,list):return [relocate(v)for v in x]
  if isinstance(x,dict):return {k:relocate(v)for k,v in x.items()}
  return x
 prior=copy.deepcopy(m);m=relocate(m);events=[]
 for e in m['events']:
  cmd=e['command']
  if str(ROOT/SOURCE)not in cmd and e['category']!='link':continue
  t=time.perf_counter();r=subprocess.run(cmd,cwd=out,capture_output=True,timeout=300);idx=len(events)
  for stream in ['stdout','stderr']:(out/f'refresh-{idx:03}.{stream}').write_bytes(getattr(r,stream))
  event=dict(command=cmd,seconds=time.perf_counter()-t,returncode=r.returncode,category=e['category']);events.append(event);assert r.returncode==0,r.stderr.decode();e.update(event)
 m['candidate']=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip();m['input_sha256'][SOURCE]=sha(ROOT/SOURCE);m['executable_sha256']=sha(out/'swap5_solute_column')
 m['private_body_refresh']=dict(previous_build=prior,unchanged_public_declarations=True,sealed_reused_artifacts=seals,events=events)
 assert len(events)==2
 (out/'build-complete.json').write_text(json.dumps(m,indent=2)+'\n');print('VERIFIED_PRIVATE_BACKEND_BODY_REFRESH')
if __name__=='__main__':main()

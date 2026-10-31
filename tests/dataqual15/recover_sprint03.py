"""Live authentic numerical-profile restart at the early groundwater transition."""
import argparse,hashlib,json,subprocess,tarfile,time
from pathlib import Path
from sprint03_evidence import CAP,verify
from checkpoint_layout import layout
sha=lambda b:hashlib.sha256(b).hexdigest()

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
 verify();out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
 with tarfile.open(CAP)as archive:
  get=lambda name:archive.extractfile(name).read()
  binary=get('build-O2/swap5_grass_startup');build=json.loads(get('build-O2/BUILD.json'));assert sha(binary)==build['executable_sha256']
  exe=out/'swap5_grass_startup';exe.write_bytes(binary);exe.chmod(0o755)
  for name in ['input.swp','grass.crp','input.met','swap.bbc','swap.dra','application.binding']:(out/name).write_bytes(get('adaptive-O2/'+name))
  binding=json.loads((out/'application.binding').read_text());assert binding['executable_sha256']==sha(binary)and binding['grass_numerical_profile']=='thermal-control-1e-5C'
  origin=get('adaptive-O2/checkpoint-113.bin');target=get('adaptive-O2/checkpoint-117.bin');assert layout(origin)['clock']==113 and layout(target)['clock']==117
  (out/'origin.bin').write_bytes(origin);command=[str(exe),'117','retain-step','100000',str(out/'origin.bin'),'thermal-control'];start=time.monotonic()
  with(out/'stdout').open('wb')as so,(out/'stderr').open('wb')as se:
   try:r=subprocess.run(command,cwd=out,stdout=so,stderr=se,timeout=120);code=r.returncode;censored=False
   except subprocess.TimeoutExpired:code=None;censored=True
  report=dict(command=command,seconds=time.monotonic()-start,returncode=code,censored=censored,executable_sha256=sha(binary),origin_sha256=sha(origin),target_sha256=sha(target),canonical_modified=False)
  (out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n',newline='\n')
  assert code==0 and not censored
  assert(out/'origin.bin').read_bytes()==origin and(out/'checkpoint.bin').read_bytes()==target
  for name in ['budget.csv','crop.csv']:
   expected=get('adaptive-O2/'+name).splitlines();actual=(out/name).read_bytes().splitlines();assert actual==[expected[0]]+expected[114:118]
  report['status']='SPRINT03_AUTHENTIC_GROUNDWATER_RESTART113_117_EXACT';(out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n',newline='\n');print(json.dumps(report,indent=2))
if __name__=='__main__':main()

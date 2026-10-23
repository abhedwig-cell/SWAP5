"""Run admitted wet step-proposal inputs through the changed application."""
import argparse,json,runpy,subprocess,sys,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def main():
 p=argparse.ArgumentParser();p.add_argument('--bundle',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
 out=a.output.resolve();out.mkdir();bundle=json.loads((a.bundle/'bundle.json').read_text());opt=bundle['optimization']
 f=runpy.run_path(str(ROOT/'integration/performance/verify_native_proposal_successor.py'))['capsule']();prefix='qualified/'+opt+'-4x-on-0/'
 for name in ['input.nml','input.swp']:(out/name).write_bytes(f[prefix+name])
 cmd=[sys.executable,ROOT/'tools/solute/run_column.py','--exe',bundle['exe'],'--input',out/'input.nml','--swp',out/'input.swp','--output',out/'current'];t=time.perf_counter();r=subprocess.run(list(map(str,cmd)),cwd=ROOT,capture_output=True,timeout=300)
 for stream in ['stdout','stderr']:(out/stream).write_bytes(getattr(r,stream))
 assert r.returncode==0,r.stderr
 for name in ['budget.csv','state.csv','endpoint.csv','restart.bin']:assert (out/'current'/name).read_bytes()==f[prefix+name],name
 assert (out/'current/stdout').read_bytes().count(b'SWAP5_PROJECT_STEP_PROPOSAL_FALLBACK')==3
 (out/'result.json').write_text(json.dumps(dict(status='CURRENT_APPLICATION_WET_PROPOSAL_97_DAY_EXACT',optimization=opt,seconds=time.perf_counter()-t,command=list(map(str,cmd)),returncode=r.returncode),indent=2)+'\n')
if __name__=='__main__':main()

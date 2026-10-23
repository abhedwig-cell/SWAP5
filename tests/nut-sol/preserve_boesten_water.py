"""Small unmodified original Boesten process witness; water gate is separate."""
import argparse,hashlib,json,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def main():
 p=argparse.ArgumentParser();p.add_argument('--bundle',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();out=a.output.resolve();out.mkdir();b=json.loads((a.bundle/'bundle.json').read_text());m=json.loads((Path(b['exe']).parent/'build-complete.json').read_text());events=[];inputs={}
 def run(cmd):
  t=time.perf_counter();r=subprocess.run(list(map(str,cmd)),cwd=out,capture_output=True,timeout=180);idx=len(events)
  for stream in ['stdout','stderr']:(out/f'{idx:03}.{stream}').write_bytes(getattr(r,stream))
  events.append(dict(command=list(map(str,cmd)),returncode=r.returncode,seconds=time.perf_counter()-t));assert r.returncode==0,r.stderr.decode()+r.stdout.decode();return r
 def bind(p):inputs[str(p.relative_to(ROOT))]=hashlib.sha256(p.read_bytes()).hexdigest();return p
 flags=[f for f in m['flags']if not f.startswith('-J')]+['-I'+str(out),'-J'+str(out)];fc=m['compiler_command']
 process=out/'process';run(fc+flags+[bind(ROOT/'src/process/mod_restricted_surface_evaporation.f90'),bind(ROOT/'tests/fapp/test_ppa_wu04b_boesten_process.f90'),'-o',process]);run([process])
 (out/'result.json').write_text(json.dumps(dict(status='ORIGINAL_BOESTEN_PROCESS_PRESERVED',optimization=b['optimization'],events=events,inputs=inputs),indent=2)+'\n');print('ORIGINAL_BOESTEN_PROCESS_PRESERVED')
if __name__=='__main__':main()

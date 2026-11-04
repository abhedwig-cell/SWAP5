"""Selected original-input pressure-variant prefixes; never cross-variant seeds."""
import argparse,hashlib,json,re,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--parent',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--cap',type=float,choices=[.005,.0025],required=True);a=p.parse_args()
 parent=a.parent.resolve();out=a.output.resolve();out.mkdir();inputs=out/'inputs';inputs.mkdir()
 build=parent/'build-O2';record=json.loads((build/'BUILD.json').read_text())
 assert all(sha(Path(n))==h for n,h in record['source_sha256'].items())
 assert all(sha(build/n)==h for n,h in record['compiled_objects_sha256'].items())
 exe=build/'pressure-runtime.exe';assert sha(exe)==record['executable_sha256']
 for f in (parent/'full-O2').iterdir():
  if f.suffix in ('.swp','.crp','.met','.dra','.nml'):(inputs/f.name).write_bytes(f.read_bytes())
 f=inputs/'swap.swp';raw=f.read_bytes();pattern=rb'(?im)^(\s*DTMAX\s*=\s*)([\d.eE+\-]+)'
 matches=re.findall(pattern,raw);assert len(matches)==1 and float(matches[0][1])==.01
 changed=re.sub(pattern,lambda m:m[1]+str(a.cap).encode(),raw);f.write_bytes(changed)
 assert re.sub(pattern,lambda m:m[1]+b'CAP',raw)==re.sub(pattern,lambda m:m[1]+b'CAP',changed)
 cmd=[sys.executable,'-B',str(ROOT/'tests/dataqual15_hupsel/run_canopy_observation.py'),'--exe',str(exe),'--predecessor',str(inputs),'--output',str(out/'prefix-O2'),'--end','584','--timeout','3600','--from-start','--capture','120','365','494','524','537','566','583','584']
 r=subprocess.run(cmd,cwd=ROOT,capture_output=True);(out/'wrapper.stdout').write_bytes(r.stdout);(out/'wrapper.stderr').write_bytes(r.stderr)
 assert r.returncode==0,r.stderr
 result=json.loads((out/'prefix-O2/RESULT.json').read_text());assert result['returncode']==0 and result['from_start'] and result['restart_sha256'] is None
 (out/'COMPLETE.json').write_text(json.dumps(dict(cap=a.cap,actual_prefix_days=584,run=result,production_admission=False),indent=2)+'\n')

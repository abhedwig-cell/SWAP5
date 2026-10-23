"""Observe actual incumbent day470 failure without changing solver policy."""
import argparse,hashlib,json,subprocess,sys,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def main():
 p=argparse.ArgumentParser();p.add_argument('--optimization',choices=['O0','O2'],required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
 out=a.output.resolve();out.mkdir();bundle=Path('/tmp/perf01-typed-composed-'+a.optimization)
 prior=Path('/tmp/perf01-owner-native-drain-'+a.optimization);swp=prior/'project/project.swp'
 cmd=list(map(str,[sys.executable,ROOT/'tools/solute/run_project.py',swp,'--bundle',bundle,'--temporal-tolerance','.001',
  '--solute-transport','implicit_upwind','--water-conductivity','picard_continuous','--surface-exfiltration','historical_zero',
  '--stop-after','470','--output',out/'rejected']))
 start=time.perf_counter();cp=subprocess.run(cmd,cwd=ROOT,capture_output=True,timeout=300)
 for stream in ['stdout','stderr']:(out/stream).write_bytes(getattr(cp,stream))
 report=dict(command=cmd,returncode=cp.returncode,seconds=time.perf_counter()-start)
 (out/'events.json').write_text(json.dumps([report],indent=2)+'\n')
 assert cp.returncode!=0 and not(out/'rejected').exists()
 pending=list(out.glob('rejected.pending-*'));assert len(pending)==1
 assert(pending[0]/'diagnostic-rejected.bin').read_bytes()==(prior/'full/restart.bin').read_bytes()
 assert b'470'in(pending[0]/'stdout').read_bytes()
 report.update(status='CURRENT_DAY470_FAILURE_COMPLETE_COMMITTED_GENERATION_EXACT',optimization=a.optimization,
  committed_restart_sha256=hashlib.sha256((prior/'full/restart.bin').read_bytes()).hexdigest())
 (out/'result.json').write_text(json.dumps(report,indent=2)+'\n');print(report['status'])
if __name__=='__main__':main()

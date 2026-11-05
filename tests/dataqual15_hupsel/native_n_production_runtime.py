"""Fresh real current-source execution, reusing the qualified native driver."""
import argparse,json,os,subprocess
from pathlib import Path
import native_n_crc_runtime as physical
import native_n_production as policy
def current_inputs():
 policy.guard(development=True)
 r=json.loads((policy.ROOT/physical.REGISTER).read_text())
 for n in policy.SOURCES:r['source_sha256'][n]=policy.sha((policy.ROOT/n).read_bytes().replace(b'\r\n',b'\n'))
 return r
def main():
 p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);p.add_argument('--compiler',type=Path,required=True);p.add_argument('--optimization',choices=('O0','O2'),required=True);a=p.parse_args();os.environ['OMP_NUM_THREADS']='1'
 # Reuse literal fixture/driver/compiler construction only. The actual source
 # guard is the stricter two-postimage successor guard, not the old tree guard.
 physical.guard=current_inputs
 out=a.output.resolve();fixture,ordered,drivers=physical.prepare(out)
 exes,events=physical.build(out/'current',a.compiler.resolve(),a.optimization,fixture,ordered,drivers)
 results=physical.execute(exes,out/'current',events,True);policy.guard(development=True)
 r=dict(status='CURRENT_NATIVE_N_PRODUCTION_RUNTIME_COMPLETE',optimization=a.optimization,compiler=subprocess.check_output([a.compiler,'--version'],text=True).splitlines()[0],results={'current':results},production_source_changed=True,production_admission=False,whole_scientific_admission=False)
 (out/'RESULT.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r,indent=2))
if __name__=='__main__':main()

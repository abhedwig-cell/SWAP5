"""Measure actual runtime text-policy pairs with identical physical bindings."""
import argparse,hashlib,json,subprocess,sys,time,runpy
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sha=lambda b:hashlib.sha256(b).hexdigest()
STREAMS=['state.csv','temperature.csv','budget.csv','progress.csv','cost.csv','diagnostics.csv','restart.bin']
def main():
 p=argparse.ArgumentParser();p.add_argument('--optimization',choices=['O0','O2'],required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
 bundle=Path('/tmp/dq09-'+a.optimization);out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
 cases=json.loads((ROOT/'integration/dataqual09/cases.json').read_bytes());results=[]
 batch=runpy.run_path(str(ROOT/'tools/solute/run_dataqual_batch.py'));assess=batch['assess'];modify=batch['modify']
 import gzip
 for scenario in cases['scenarios']:
  case=out/scenario['id'];case.mkdir();inputs=case/'inputs';inputs.mkdir()
  for name in cases['input_files']:(inputs/name).write_bytes(gzip.decompress((ROOT/cases['source_directory']/('b111-'+name+'.gz')).read_bytes()))
  for op in scenario['transformations']:modify(inputs,op)
  target=scenario['stop_at_time']
  cmd=[sys.executable,str(ROOT/'tools/solute/run_native_water.py'),str(inputs/'swap.swp'),'--bundle',str(bundle),
   '--output','OUTPUT','--mode','experimental','--stop-after','2','--stop-at-time',repr(target),
   '--timeout-seconds','60','--anchored-cauchy','--entry-ramp-width-cm','0.0001','--source-surface-demand','--perched-jacobian','--conservative-macro-storage']
  pair={}
  for label in ['loud','quiet']:
   run=case/label;c=cmd.copy();c[c.index('OUTPUT')]=str(run)
   if label=='quiet':c+=['--quiet-macro-stages']
   cp=subprocess.run(c,cwd=ROOT,capture_output=True,timeout=150)
   (case/(label+'.stdout')).write_bytes(cp.stdout);(case/(label+'.stderr')).write_bytes(cp.stderr)
   m=json.loads((run/'manifest.json').read_bytes());native=next(e for e in m['events']if e['label']=='native');physical=assess(run,target)
   assert cp.returncode==0 and physical['physical_complete'],(scenario['id'],label,cp.stderr[-200:])
   pair[label]=dict(seconds=native['seconds'],binding=m['binding_sha256'],physical=physical,
      native_stdout_bytes=(run/'native.stdout').stat().st_size,native_stdout_lines=len((run/'native.stdout').read_bytes().splitlines()),
      hashes={n:sha((run/n).read_bytes())for n in STREAMS})
  assert pair['loud']['binding']==pair['quiet']['binding']
  assert pair['loud']['hashes']==pair['quiet']['hashes'],'diagnostics changed physical output'
  assert pair['quiet']['native_stdout_bytes']<pair['loud']['native_stdout_bytes']
  # The previous DATAQUAL07 capsule is the immutable numerical predecessor.
  prior=Path('/tmp/dq07-final-restarts-'+a.optimization)/scenario['id']/'run'
  for n in STREAMS[:-1]:assert (case/'loud'/n).read_bytes()==(prior/n).read_bytes(),n
  assert (case/'loud/restart.bin').read_bytes()[72:-4]==(prior/'restart.bin').read_bytes()[72:-4]
  record=dict(id=scenario['id'],optimization=a.optimization,pair=pair,predecessor_six_streams_exact=True,predecessor_physical_restart_exact=True,
     speed_ratio=pair['loud']['seconds']/pair['quiet']['seconds'],qualification='same executable exact7 files;predecessor exact6 streams and physical restart')
  results.append(record);(out/'RESULT.json').write_text(json.dumps(results,indent=2)+'\n');print(json.dumps(record),flush=True)
 # Cross-mode restart on one representative configuration: loud prefix,quiet suffix.
 scenario=cases['scenarios'][1];case=out/scenario['id'];m=json.loads((case/'loud/manifest.json').read_bytes());native=next(e['command']for e in m['events']if e['label']=='native')
 for label,end,restart,quiet in [('split',1.,'-',False),('resumed',scenario['stop_at_time'],str(case/'split/restart.bin'),True)]:
  folder=case/label;folder.mkdir()
  for n in ['input.nml','input.swp','macro.nml']:(folder/n).write_bytes((case/'loud'/n).read_bytes())
  c=native.copy();c[2]=restart;c[3]='2';c[7]=repr(end)
  if quiet:c.append('quiet-macro-stages')
  started=time.monotonic()
  with(folder/'native.stdout').open('wb')as so,(folder/'native.stderr').open('wb')as se:cp=subprocess.run(c,cwd=folder,stdout=so,stderr=se,timeout=60)
  assert cp.returncode==0
  (folder/'execution.json').write_text(json.dumps(dict(command=c,returncode=cp.returncode,seconds=time.monotonic()-started),indent=2)+'\n')
 for n in ['state.csv','temperature.csv','restart.bin']:assert (case/'quiet'/n).read_bytes()==(case/'resumed'/n).read_bytes()
 (out/'RESTART.json').write_text(json.dumps(dict(id=scenario['id'],loud_prefix_quiet_suffix_exact=True,files=['state.csv','temperature.csv','restart.bin']),indent=2)+'\n')
if __name__=='__main__':main()

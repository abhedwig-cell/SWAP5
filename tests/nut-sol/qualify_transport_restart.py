"""Native within-policy fresh restarts and cross-policy rejection at both layers."""
import argparse,csv,hashlib,json,subprocess,sys,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def rows(p):return [{k:float(v)for k,v in r.items()}for r in csv.DictReader(p.open())]
def main():
 ap=argparse.ArgumentParser()
 for opt in ['O0','O2']:ap.add_argument('--bundle-'+opt,type=Path,required=True)
 ap.add_argument('--single-fixture',type=Path,required=True);ap.add_argument('--output',type=Path,required=True)
 ap.add_argument('--water-conductivity',choices=['frozen','picard'],default='frozen');a=ap.parse_args()
 out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
 report=dict(status='RUNNING',inputs={p:sha(ROOT/p)for p in ['tests/nut-sol/qualify_transport_restart.py','tools/solute/run_project.py',
  'src/runtime/mod_fmr_b111_matrix_solute_route.f90','src/process/mod_b111_reactive_solute_substep.f90']},events=[],cases={},invalids=0,exact_restart_files=0)
 report['water_conductivity']=a.water_conductivity
 def save():(out/'result.json').write_text(json.dumps(report,indent=2)+'\n')
 def run(cmd,cwd,valid=True):
  start=time.perf_counter();r=subprocess.run(list(map(str,cmd)),cwd=cwd,capture_output=True,input=b'',timeout=120);i=len(report['events'])
  for stream in ['stdout','stderr']:(out/f'{i:04d}.{stream}').write_bytes(getattr(r,stream))
  report['events'].append(dict(command=list(map(str,cmd)),seconds=time.perf_counter()-start,returncode=r.returncode,expected_success=valid))
  if (r.returncode==0)!=valid:report['status']='FAILED'
  save();assert(r.returncode==0)==valid,(r.stdout,r.stderr)
  return r
 for opt in ['O0','O2']:
  bundle=getattr(a,'bundle_'+opt).resolve();meta=json.loads((bundle/'bundle.json').read_text());folder=out/opt;folder.mkdir()
  for sub in ['Crop Data','Weather Data']:
   (folder/sub).mkdir()
   for p in (a.single_fixture/sub).iterdir():
    if p.is_file():(folder/sub/p.name).write_bytes(p.read_bytes())
  (folder/'Project.SWP').write_bytes((a.single_fixture/'Project.SWP').read_bytes())
  base=[sys.executable,ROOT/'tools/solute/run_project.py',folder/'Project.SWP','--bundle',bundle]
  if a.water_conductivity!='frozen':base+=['--water-conductivity',a.water_conductivity]
  for mode in ['reference','implicit_upwind']:
   for name,extra in [('full',[]),('split',['--stop-after','3']),('resumed',['--restart',folder/(mode+'-split')])]:
    run(base+['--solute-transport',mode,'--output',folder/(mode+'-'+name)]+extra,folder)
   for f in ['state.csv','endpoint.csv','restart.bin']:
    assert(folder/(mode+'-full')/f).read_bytes()==(folder/(mode+'-resumed')/f).read_bytes();report['exact_restart_files']+=1
   assert rows(folder/(mode+'-full')/'budget.csv')[3:]==rows(folder/(mode+'-resumed')/'budget.csv')
  ref=rows(folder/'reference-full/budget.csv');positive=rows(folder/'implicit_upwind-full/budget.csv')
  for r,p in zip(ref,positive):
   for key in r:
    if not key.startswith('solute_'):assert r[key]==p[key],('water/root changed with transport policy',key)
  for mode,other in [('reference','implicit_upwind'),('implicit_upwind','reference')]:
   target=folder/('forbidden-public-'+mode)
   run(base+['--solute-transport',mode,'--restart',folder/(other+'-split'),'--output',target],folder,False)
   assert not target.exists();report['invalids']+=1
   stage=folder/('forbidden-native-'+mode);stage.mkdir()
   source=folder/(mode+'-full');foreign=folder/(other+'-split/restart.bin')
   for p in ['input.nml','input.swp']:(stage/p).write_bytes((source/p).read_bytes())
   (stage/'before.bin').write_bytes(foreign.read_bytes());before=sha(stage/'before.bin')
   r=run([meta['exe'],'input.nml','before.bin','8','input.swp'],stage,False)
   assert b'restart rejected'in r.stdout and not(stage/'budget.csv').exists()and not(stage/'restart.bin').exists()
   assert sha(stage/'before.bin')==before;report['invalids']+=1
  report['cases'][opt]=dict(days=8,modes=['reference','implicit_upwind'],water_root_fields_exact=True);save()
  if a.water_conductivity=='picard':
   target=folder/'forbidden-water-public'
   frozen=[x for x in base]
   frozen[frozen.index('picard')]='frozen'
   run(frozen+['--solute-transport','implicit_upwind','--restart',folder/'implicit_upwind-split','--output',target],folder,False)
   assert not target.exists()
 assert report['invalids']==8 and report['exact_restart_files']==12
 report['status']=('PICARD_'if a.water_conductivity=='picard'else'')+'TRANSPORT_NATIVE_WITHIN_POLICY_RESTART_CROSS_POLICY_REJECT_O0_O2_PASS';save();print(report['status'])
if __name__=='__main__':main()

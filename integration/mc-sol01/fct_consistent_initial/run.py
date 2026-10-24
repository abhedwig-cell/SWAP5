"""Native mesh observations with analytically consistent initial storage."""
import argparse,csv,hashlib,json,math,runpy,stat,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).resolve().parent
sha=lambda b:hashlib.sha256(b).hexdigest()
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--build-root',type=Path,required=True);ap.add_argument('--output',type=Path,required=True);a=ap.parse_args()
 out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
 old=runpy.run_path(str(HERE.parent/'fct_native_refinement/run.py'));original=old['fixture']()
 r=dict(status='RUNNING',baseline=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),runner_sha256=sha(Path(__file__).read_bytes()),builds={},cases=[])
 def save():(out/'RESULT.json').write_text(json.dumps(r,indent=2)+'\n')
 for opt in ['o0','o2']:
  build=a.build_root.resolve()/('fct-refine-'+opt);b=json.loads((build/'build.json').read_text());exe=build/'native_fct'
  assert b['status']=='BUILT_RESEARCH_NATIVE' and sha(exe.read_bytes())==b['executable_sha256']
  for p,h in b['inputs'].items():assert sha((ROOT/p).read_bytes())==h
  for p,h in b['generated'].items():assert sha((build/p).read_bytes())==h
  r['builds'][opt]=b
  for factor in [1,2,4]:
   case=out/f'{opt}-{factor}';case.mkdir();prepared=old['prepare'](original,factor,.4,.001,1.)
   swp=prepared['project.swp'];assert swp.count('CMLTB=0.,.2,-3.,.8')==1 and swp.count('HTB=0.,-100.,-120.,-200.')==1
   prepared['project.swp']=swp.replace('CMLTB=0.,.2,-3.,.8','CMLTB=0.,.2,-8.,.2,-12.,.8,-120.,.8').replace('HTB=0.,-100.,-120.,-200.','HTB=0.,-100.,-120.,-100.')
   prepared['input.nml']=prepared['input.nml'].replace('initial_pond_cm=.1,initial_pond_mass_mg_cm2=.02','initial_pond_cm=0,initial_pond_mass_mg_cm2=0')
   for p,v in prepared.items():(case/p).write_text(v)
   exe.chmod(exe.stat().st_mode|stat.S_IXUSR);cmd=[str(exe),str(case/'input.nml'),'-','4',str(case/'project.swp')];t=time.monotonic()
   try:cp=subprocess.run(cmd,cwd=case,capture_output=True,timeout=180);rc=cp.returncode;stdout=cp.stdout;stderr=cp.stderr
   except subprocess.TimeoutExpired as e:rc=None;stdout=e.stdout or b'';stderr=e.stderr or b''
   (case/'stdout').write_bytes(stdout);(case/'stderr').write_bytes(stderr)
   e=dict(opt=opt,factor=factor,command=cmd,returncode=rc,seconds=time.monotonic()-t);r['cases'].append(e);save();print(json.dumps(e),flush=True)
   assert rc==0,e
 r['status']='EXECUTIONS_COMPLETE';save()
if __name__=='__main__':main()

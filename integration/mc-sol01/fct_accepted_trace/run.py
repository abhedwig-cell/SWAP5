"""Fresh real Reference export and small research replay qualification."""
import argparse,hashlib,importlib.util,json,os,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
sha=lambda b:hashlib.sha256(b).hexdigest()
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--output',type=Path,required=True);a=ap.parse_args();out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
 dependency=ROOT/'tests/support/augment_bartholomeus_backend_sources.py'
 spec=importlib.util.spec_from_file_location('deps',dependency);deps=importlib.util.module_from_spec(spec);spec.loader.exec_module(deps)
 sources,_=deps.strict_closure(ROOT,[str(HERE/'water_driver.f90')],['app/solute_column/link_context.f90'])
 sources.append(ROOT/'src/legacy/b1_10_port/headcalc.f90')
 report=dict(status='BUILDING',baseline=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),inputs={str(p.relative_to(ROOT)):sha(p.read_bytes()) for p in [*sources,dependency,Path(__file__)]},water_provider_count=len(sources)-1,events=[],water_cases=[])
 def save():(out/'execution.json').write_text(json.dumps(report,indent=2)+'\n')
 def run(cmd,cwd,timeout=120):
  start=time.monotonic()
  try:cp=subprocess.run(list(map(str,cmd)),cwd=cwd,capture_output=True,timeout=timeout)
  except subprocess.TimeoutExpired as e:
   cp=subprocess.CompletedProcess(cmd,124,e.stdout or b'',e.stderr or b'');report['status']='CENSORED'
  e=dict(command=list(map(str,cmd)),returncode=cp.returncode,seconds=time.monotonic()-start)
  for stream in ['stdout','stderr']:
   raw=getattr(cp,stream);e[stream]=f'{len(report["events"]):03d}.{stream}';e[stream+'_sha256']=sha(raw);(out/e[stream]).write_bytes(raw)
  report['events'].append(e)
  if cp.returncode and report['status']!='CENSORED':report['status']='FAILED'
  save();assert cp.returncode==0,(e,cp.stdout[-1000:],cp.stderr[-2500:]);return e
 save();fc=os.environ.get('FC','gfortran');run([fc,'--version'],out)
 for opt in ['O0','O2']:
  folder=out/opt;folder.mkdir();exe=folder/'water'
  flags=['-'+opt,'-std=f2008','-ffree-line-length-none','-fopenmp','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow','-J'+str(folder)]
  run([fc,*flags,*sources,'-o',exe],folder,240)
  for n in [40,80,160]:
   for factor in [.8,1.2]:
    path=out/f'water-{opt}-{n}-{factor}.txt';e=run([exe,n,factor,path],folder)
    report['water_cases'].append(dict(**e,optimization=opt,n=n,factor=factor,path=path.name,sha256=sha(path.read_bytes())));save()
 report['status']='WATER_EXPORTED';save();print(json.dumps({k:report[k] for k in ['status','water_provider_count']},indent=2))
if __name__=='__main__':main()

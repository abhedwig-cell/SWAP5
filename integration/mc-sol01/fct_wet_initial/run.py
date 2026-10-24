"""Compare native water policies before interpreting rejected wet chemistry."""
import argparse,hashlib,json,runpy,stat,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).resolve().parent
sha=lambda b:hashlib.sha256(b).hexdigest()
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--scratch',type=Path,required=True);a=ap.parse_args();scratch=a.scratch.resolve();out=scratch/'wet-initial-diagnostic';out.mkdir(exist_ok=False)
 old=runpy.run_path(str(HERE.parent/'fct_native_refinement/run.py'));original=old['fixture']();report=dict(status='RUNNING',builds={},cases=[])
 for opt in ['o0','o2']:
  build=scratch/('fct-refine-'+opt);b=json.loads((build/'build.json').read_text());exe=build/'native_fct';assert sha(exe.read_bytes())==b['executable_sha256']
  for p,h in b['inputs'].items():assert sha((ROOT/p).read_bytes())==h,p
  for p,h in b['generated'].items():assert sha((build/p).read_bytes())==h
  report['builds'][opt]=b
  for head in ['uniform','sloping']:
   for policy,flags in [('frozen',''),('picard','picard_conductivity_iteration=.true.,'),('continuous','picard_conductivity_iteration=.true.,continuous_mvg=.true.,')]:
    case=out/f'{opt}-{head}-{policy}';case.mkdir();text=old['prepare'](original,1,.4,.001,1.)
    if head=='uniform':text['project.swp']=text['project.swp'].replace('HTB=0.,-100.,-120.,-200.','HTB=0.,-100.,-120.,-100.')
    text['input.nml']=text['input.nml'].replace('&column','&column\n '+flags)
    for p,v in text.items():(case/p).write_text(v)
    exe.chmod(exe.stat().st_mode|stat.S_IXUSR);cmd=[str(exe),str(case/'input.nml'),'-','4',str(case/'project.swp')];t=time.monotonic()
    try:cp=subprocess.run(cmd,cwd=case,capture_output=True,timeout=180);rc=cp.returncode;stdout=cp.stdout;stderr=cp.stderr
    except subprocess.TimeoutExpired as e:rc=None;stdout=e.stdout or b'';stderr=e.stderr or b''
    (case/'stdout').write_bytes(stdout);(case/'stderr').write_bytes(stderr)
    event=dict(opt=opt,head=head,policy=policy,command=cmd,returncode=rc,seconds=time.monotonic()-t);report['cases'].append(event);(out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(event),flush=True)
 report['status']='DIAGNOSTICS_COMPLETE';(out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n')
if __name__=='__main__':main()

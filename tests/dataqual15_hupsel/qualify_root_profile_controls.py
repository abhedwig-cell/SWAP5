"""Actual current numerical-selector, publication and immutable owner controls."""
import argparse,json,os,shutil,subprocess
from pathlib import Path
import production_diagnostic_native as native
import production_diagnostic_guards as owner

def main():
 p=argparse.ArgumentParser(description=__doc__)
 for name in ('build','case','output','compiler'):p.add_argument('--'+name,type=Path,required=True)
 p.add_argument('--short',action='store_true');a=p.parse_args();b=a.build.resolve();case=a.case.resolve();out=a.output.resolve();out.mkdir();os.environ['OMP_NUM_THREADS']='1'
 exe=b/('swap5_hupsel_germination.exe'if os.name=='nt'else'swap5_hupsel_germination')
 probe=native.writer_build(b,out/'writer-build',a.compiler,windows=False)
 native.measure(exe,probe,case,out/'publication')
 native.app_refusals(exe,case,out/'app-refusals')
 if not a.short:owner.qualify(b,case,case/'checkpoint.bin',out/'owner-controls')
 events=[]
 for kind,value in (('profile-switch','0'),('unknown-profile','2')):
  target=out/kind;target.mkdir()
  for path in case.iterdir():
   if path.suffix.lower()in('.swp','.nml','.crp','.dra','.met'):shutil.copyfile(path,target/path.name)
  swp=target/'swap.swp';raw=swp.read_bytes();assert raw.count(b'SWAP5_ROOT_ACCURACY = 1')==1
  swp.write_bytes(raw.replace(b'SWAP5_ROOT_ACCURACY = 1',('SWAP5_ROOT_ACCURACY = '+value).encode()))
  incoming=(case/'checkpoint.bin').read_bytes();seed=target/'seed.bin';seed.write_bytes(incoming)
  prior=target/'checkpoint.bin';prior.write_bytes(incoming)
  command=[str(exe),'input.nml',str(seed),'2','swap.swp','maize.crp']
  run=subprocess.run(command,cwd=target,capture_output=True,timeout=30,env=dict(os.environ,OMP_NUM_THREADS='1'))
  (target/'stdout').write_bytes(run.stdout);(target/'stderr').write_bytes(run.stderr)
  assert run.returncode!=0 and seed.read_bytes()==prior.read_bytes()==incoming
  assert not any((target/n).exists()for n in ('budget.csv','crop.csv','germination.csv'))
  events.append(dict(case=kind,returncode=run.returncode,command=command,prior_target_preserved=True))
 (out/'RESULT.json').write_text(json.dumps(dict(status='CURRENT_ROOT_PROFILE_WRITER_OWNER_APP_AND_SELECTOR_CONTROLS_PASS',writer=6,owner=0 if a.short else 37,app=11,profile=events,executable_sha256=native.sha(exe)),indent=2)+'\n')
if __name__=='__main__':main()

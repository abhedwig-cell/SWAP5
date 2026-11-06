"""Actual exact current baseline diagnostics; retain every old verdict."""
import argparse,json,os,subprocess,tempfile,zipfile
from pathlib import PurePosixPath
from pathlib import Path
import joint_production as g
from rotation_native_baseline import CASES

def main():
 p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);a=p.parse_args();assert os.name=='posix';g.source_guard();out=a.output.resolve();out.mkdir(parents=True)
 parent=Path(tempfile.mkdtemp(prefix='s5jp-before-')).resolve();view=g.immutable_view(parent,'baseline',g.BASE)
 commands={name:cmd for name,(cmd,_)in CASES.items()};commands.update({'thermal-owner':['python3','-B','tests/dataqual15/thermal_profile_production.py','--output',str(out/'thermal')],'logical-owner':['python3','-B','tests/dataqual15_hupsel/rotation_native_admission.py','--prepare-only','--output',str(out/'logical')],'native-layout':['python3','-B','tests/dataqual15/verify_native_restart_admission.py','--prepare-only','--output',str(out/'layout')],'mc-source':['python3','-B','integration/audits/verify_matrix_thermal.py']});events=[]
 for name,command in commands.items():
  try:
   cp=subprocess.run(command,cwd=view,capture_output=True,timeout=240,env=dict(os.environ,PYTHONDONTWRITEBYTECODE='1',OMP_NUM_THREADS='1'));stdout,stderr,code=cp.stdout,cp.stderr,cp.returncode;censored=False
  except subprocess.TimeoutExpired as e:stdout=e.stdout or b'';stderr=e.stderr or b'';code=None;censored=True
  for stream,raw in [('stdout',stdout),('stderr',stderr)]:(out/(name+'.'+stream)).write_bytes(raw)
  events.append(dict(case=name,command=command,returncode=code,censored=censored,stdout_sha256=g.sha(stdout),stderr_sha256=g.sha(stderr)))
  result=dict(output_root=str(out),producer_platform='posix',baseline=g.BASE,tree=g.git('rev-parse',g.BASE+'^{tree}'),events=events,old_gate_pass_claim=False,whole_scientific_admission=False)
  (out/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n');print(name,code,'CENSORED'if censored else'UNCENSORED',flush=True)
 assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=view,text=True).strip()==g.BASE
 assert len(events)==16 and not subprocess.check_output(['git','diff','HEAD','--'],cwd=view)
 target=g.ROOT/'integration/dataqual15_hupsel/JOINT_PRODUCTION_EXACT_BEFORE_20261106.zip'
 with zipfile.ZipFile(target,'w',zipfile.ZIP_DEFLATED)as z:
  for path in out.iterdir():
   if path.is_file():z.write(path,path.name)
 # Keep the exact view locally if any outcome was censored; do not present it
 # as qualification or discard the material needed for diagnosis.
 assert not any(e['censored']for e in events),'censored baseline outcome requires diagnosis'
 assert view.resolve().parent==parent and parent.parent==Path(tempfile.gettempdir()).resolve()
 subprocess.run(['git','worktree','remove','--force',str(view)],cwd=g.ROOT,capture_output=True,check=True)
 print('SIXTEEN_EXACT_BASELINE_OUTCOMES_RETAINED_NO_OLD_PASS_CLAIM')
def verify():
 path=g.ROOT/'integration/dataqual15_hupsel/JOINT_PRODUCTION_EXACT_BEFORE_20261106.zip'
 with zipfile.ZipFile(path)as z:files={n:z.read(n)for n in z.namelist()}
 r=json.loads(files['RESULT.json']);assert r['baseline']==g.BASE and r['tree']==g.git('rev-parse',g.BASE+'^{tree}')
 assert r['producer_platform']=='posix'and r['old_gate_pass_claim']is False and r['whole_scientific_admission']is False
 root=PurePosixPath(r['output_root']);commands={n:c for n,(c,_)in CASES.items()}
 commands.update({'thermal-owner':['python3','-B','tests/dataqual15/thermal_profile_production.py','--output',str(root/'thermal')],'logical-owner':['python3','-B','tests/dataqual15_hupsel/rotation_native_admission.py','--prepare-only','--output',str(root/'logical')],'native-layout':['python3','-B','tests/dataqual15/verify_native_restart_admission.py','--prepare-only','--output',str(root/'layout')],'mc-source':['python3','-B','integration/audits/verify_matrix_thermal.py']})
 assert len(r['events'])==len(commands)==16 and len(files)==33
 for row,(name,command)in zip(r['events'],commands.items()):
  assert row['case']==name and row['command']==command and row['censored']is False and type(row['returncode'])is int
  for stream in ('stdout','stderr'):assert g.sha(files[name+'.'+stream])==row[stream+'_sha256']
 return {e['case']:e['returncode']for e in r['events']}
if __name__=='__main__':
 import sys
 if '--verify'in sys.argv:print(json.dumps(verify(),sort_keys=True))
 else:main()


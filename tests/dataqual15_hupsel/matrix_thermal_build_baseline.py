"""Actual unchanged predecessor refusal; never relabel the broad science gate."""
import argparse,json,os,subprocess,sys
from pathlib import Path
import matrix_thermal_build as owner

def main():
 parser=argparse.ArgumentParser();parser.add_argument('--output',type=Path,required=True);a=parser.parse_args();owner.guard();out=a.output.resolve();view=owner.prepare(out)
 try:
  assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=view,text=True).strip()==owner.BASE
  command=[sys.executable,'-B','integration/audits/verify_matrix_thermal.py'];cp=subprocess.run(command,cwd=view,capture_output=True,env=dict(os.environ,PYTHONUTF8='1'),timeout=180)
  for stream in ('stdout','stderr'):(out/('baseline.'+stream)).write_bytes(getattr(cp,stream))
  text=cp.stderr.decode();assert cp.returncode!=0 and 'verify_dataqual12_current.py' in text and 'AssertionError: unreviewed delta' in text
  paths=['integration/audits/'+n+'.py' for n in ('verify_matrix_thermal','verify_dataqual09_current','verify_dataqual10_current','verify_dataqual12_current')]
  for path in paths:assert (owner.ROOT/path).read_bytes().replace(b'\r\n',b'\n')==(view/path).read_bytes()
  trees=lambda root:{area:subprocess.check_output(['git','rev-parse','HEAD:'+area],cwd=root,text=True).strip() for area in ('src','app','reference')}
  assert trees(owner.ROOT)==trees(view)
  (out/'RESULT.json').write_text(json.dumps(dict(status='ACTUAL_PREDECESSOR_DATAQUAL12_FIRST_SOURCE_REFUSAL_RETAINED_NO_SCIENCE_PASS',baseline=owner.BASE,command=command,returncode=cp.returncode,stderr_sha256=owner.private.sha(cp.stderr),unchanged_source_guard_files=paths,production_trees=trees(view),production_admission=False,whole_scientific_admission=False),indent=2)+'\n');print('ACTUAL_PREDECESSOR_DATAQUAL12_SOURCE_REFUSAL_RETAINED_NOT_PASS')
 finally:
  assert view.parent==out and view.name=='predecessor';subprocess.run(['git','worktree','remove','--force',str(view)],cwd=owner.ROOT,capture_output=True,check=True)
if __name__=='__main__':main()

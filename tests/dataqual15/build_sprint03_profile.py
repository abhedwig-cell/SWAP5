"""Fresh profile-builder interface smoke test; preserve full-run physical outputs."""
import argparse,csv,hashlib,io,json,subprocess,sys,tarfile,time
from pathlib import Path
from sprint03_evidence import ROOT,CAP,verify

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--compiler',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
 verify();out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
 with tarfile.open(ROOT/'integration/dataqual15/GRASS_UNION_FULL_EVIDENCE.tar.xz')as old:
  raw=old.extractfile('build/O2/libttutil.a').read();(out/'libttutil.a').write_bytes(raw)
 command=[sys.executable,'-B',str(ROOT/'tools/solute/build_grass_thermal.py'),'--compiler',str(a.compiler.resolve()),'--input-archive',str(out/'libttutil.a'),'--output',str(out/'build'),'--optimization','O2','--profile','checked','--end','.01'];start=time.monotonic()
 with(out/'stdout').open('wb')as so,(out/'stderr').open('wb')as se:
  try:r=subprocess.run(command,cwd=ROOT,stdout=so,stderr=se,timeout=600);code=r.returncode;censored=False
  except subprocess.TimeoutExpired:code=None;censored=True
 report=dict(command=command,seconds=time.monotonic()-start,returncode=code,censored=censored,canonical_modified=False)
 (out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n',newline='\n');assert code==0 and not censored
 build=json.loads((out/'build/BUILD.json').read_text());assert build['native_returncode']==0 and build['original_project_completed_days']==.01 and build['thermal_profile']=='thermal-control-1e-5C'
 command=[sys.executable,'-B',str(ROOT/'tests/dataqual15/run_thermal.py'),'--bundle',str(out/'build'),'--output',str(out/'native'),'--end','1','--capture','1','--timeout','60'];start=time.monotonic()
 with(out/'runner.stdout').open('wb')as so,(out/'runner.stderr').open('wb')as se:
  r=subprocess.run(command,cwd=ROOT,stdout=so,stderr=se,timeout=120)
 report['runner_command']=command;report['runner_seconds']=time.monotonic()-start;report['runner_returncode']=r.returncode
 (out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n',newline='\n');assert r.returncode==0
 native=json.loads((out/'native/RESULT.json').read_text());assert native['returncode']==0 and not native['censored']and native['completed_days']==1
 case=out/'native';binding=json.loads((case/'application.binding').read_text());assert binding['grass_numerical_profile']=='thermal-control-1e-5C'
 with tarfile.open(CAP)as archive:
  for name in ['budget.csv','crop.csv']:
   expected=list(csv.DictReader(io.StringIO(archive.extractfile('adaptive-O2/'+name).read().decode())));actual=list(csv.DictReader((case/name).open()));assert actual==expected[:1]
 report.update(status='SPRINT03_FRESH_PROFILE_BUILDER_ORIGINAL_DAY1_EXACT',compiler=build['compiler'],executable_sha256=build['executable_sha256'],source_sha256=build['source_sha256'],input_sha256=build['original_inputs_sha256']);(out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n',newline='\n');print(json.dumps({k:v for k,v in report.items()if k!='source_sha256'},indent=2))
if __name__=='__main__':main()

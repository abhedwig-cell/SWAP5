"""Qualify actual portable build integration; production sources stay frozen."""
import argparse,json,os,struct,subprocess,sys,time
from pathlib import Path
import matrix_thermal_native_policy as private
ROOT=private.ROOT;BASE='60700e1bd3f934bbf28b486f7019c707a2f2dda5'
RUNNER='tests/nut-sol/run_matrix_thermal.py'
REGISTER='integration/dataqual15_hupsel/MATRIX_THERMAL_BUILD_PREREGISTRATION_20261106.json'

def guard():
 r=json.loads((ROOT/REGISTER).read_text());assert r['baseline']==BASE and r['production_admission'] is False and r['whole_scientific_admission'] is False
 assert r['scope']=='ACTUAL_PORTABLE_COMPLETE_BUILD_INTEGRATION_WITHOUT_PRODUCTION_MODULE_DEPLOYMENT' and r['production_delta']==[]
 assert r['private_module_sha256']=='f4b2d12b3285b9517ad2ca2bc29cb47b8cd9bc129acb2825bd0e51d6f98d33be'
 frozen=['tests/dataqual15_hupsel/matrix_thermal_native_policy.py',*['integration/dataqual15_hupsel/MATRIX_THERMAL_NATIVE_'+n+'_20261106.json' for n in ('PREREGISTRATION','WINDOWS','POSIX','POSIX_WRITER')]]
 frozen+=['tests/dataqual15_hupsel/matrix_thermal_native_*.py','integration/dataqual15_hupsel/MATRIX_THERMAL_NATIVE_WINDOWS_20261106*','integration/dataqual15_hupsel/MATRIX_THERMAL_NATIVE_POSIX*']
 frozen+=['tests/nut-sol/'+n for n in ('test_matrix_thermal.f90','run_matrix_route.py','matrix_nonlinear_oracle.f90')]
 frozen+=['tests/modularity/low_air_consistent_grid_stubs.f90','tests/physics/test_ppa_wu05d2_mixed_application.f90']
 assert not subprocess.check_output(['git','diff',BASE,'--',*frozen],cwd=ROOT)
 assert not subprocess.check_output(['git','diff',BASE,'--','src','app','reference'],cwd=ROOT)
 assert not subprocess.check_output(['git','ls-files','--others','--exclude-standard','--','src','app','reference'],cwd=ROOT)
 assert private.sha((ROOT/RUNNER).read_bytes().replace(b'\r\n',b'\n'))==r['runner_postimage_sha256']
 assert private.sha(private.candidate().encode())==r['private_module_sha256']
 return r

def prepare(out):
 out.mkdir(parents=True,exist_ok=True);view=out/'predecessor';assert not view.exists()
 subprocess.run(['git','-c','core.autocrlf=false','worktree','add','--detach',str(view),BASE],cwd=ROOT,capture_output=True,check=True)
 return view

def main():
 parser=argparse.ArgumentParser();parser.add_argument('--output',type=Path,required=True);parser.add_argument('--prepare-only',action='store_true');parser.add_argument('--role',choices=('candidate','incumbent'));parser.add_argument('--compiler',type=Path);a=parser.parse_args();guard();out=a.output.resolve();view=prepare(out)
 if a.prepare_only:print(view);return
 assert a.role and a.compiler
 try:
  (view/RUNNER).write_bytes((ROOT/RUNNER).read_bytes().replace(b'\r\n',b'\n'))
  if a.role=='candidate':(view/private.SOURCE).write_text(private.candidate(),encoding='utf-8',newline='\n')
  changed=subprocess.check_output(['git','diff','--name-only'],cwd=view,text=True).splitlines();assert set(changed)=={RUNNER}|({private.SOURCE} if a.role=='candidate' else set())
  command=[sys.executable,'-B',str(view/RUNNER),'--output',str(out/'physical')];start=time.monotonic();cp=subprocess.run(command,cwd=view,env=dict(os.environ,FC=a.compiler.resolve().as_posix(),OMP_NUM_THREADS='1',PYTHONUTF8='1'),capture_output=True,timeout=1800)
  for stream in ('stdout','stderr'):(out/('physical.'+stream)).write_bytes(getattr(cp,stream))
  result=dict(baseline=BASE,role=a.role,platform=os.name,command=command,returncode=cp.returncode,seconds=time.monotonic()-start,runner_sha256=private.sha((view/RUNNER).read_bytes()),module_sha256=private.sha((view/private.SOURCE).read_bytes()),production_admission=False,whole_scientific_admission=False)
  if os.name=='nt' and a.role=='incumbent':
   assert cp.returncode!=0;report=json.loads((out/'physical/result.json').read_text());failed=next(e for e in report['events'] if e['returncode']!=0);assert failed['category']=='link'
   index=report['events'].index(failed);raw=(out/'physical'/f'{index:04d}.stderr').read_text();assert 'undefined reference' in raw and 'fsync' in raw
   result['status']='ACTUAL_ORIGINAL_WINDOWS_FSYNC_LINK_FAILURE_RETAINED'
  else:
   assert cp.returncode==0,cp.stderr[-4000:];report=json.loads((out/'physical/result.json').read_text());assert report['status']=='FOCUSED_PHYSICAL_PASS_REFINEMENT_ASSESSMENT_PENDING_NOT_ADMITTED'
   assert sum(e['category']=='compile_support' and e['returncode']==0 for e in report['events'])==2
   if os.name=='nt':
    for opt in ('O0','O2'):
     raw=(out/'physical'/opt/'thermal.exe').read_bytes();offset=struct.unpack_from('<I',raw,0x3c)[0];assert raw[offset:offset+4]==b'PE\0\0' and struct.unpack_from('<Q',raw,offset+24+72)[0]==67108864
   result['status']='ACTUAL_PORTABLE_BUILD_COMPLETE_O0_O2_NATIVE_PHYSICAL_PASS'
  (out/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n');print(result['status'])
 finally:
  assert view.parent==out and view.name=='predecessor';subprocess.run(['git','worktree','remove','--force',str(view)],cwd=ROOT,capture_output=True,check=True)
 guard()
if __name__=='__main__':main()

"""Exact executed S5MT postimage admission plus unmodified predecessor authority."""
import argparse,hashlib,json,os,subprocess,sys,tempfile
from pathlib import Path
import matrix_thermal_native_policy as private
ROOT=private.ROOT;BASE='fba220aede6b8e4a64f7c48d55065a50855943de'
SOURCE='src/adapter/mod_matrix_thermal_restart_file.f90';ENTRY='tests/dataqual15/verify_current_native_admission.py';STATUS='integration/dataqual15/STATUS.json'
KEY='matrix_thermal_native_successor_20261106';SCOPE='integration/dataqual15_hupsel/MATRIX_THERMAL_PRODUCTION_SCOPE_20261106.json'
BRIDGES={'.github/workflows/'+n+'.yml' for n in ('generation-publication','generation-crc','matrix-crc','native-n-production','matrix-thermal-native')}
GATES={ENTRY,*BRIDGES,'.github/workflows/matrix-thermal-production.yml','tests/dataqual15_hupsel/matrix_thermal_production.py','tests/dataqual15_hupsel/test_matrix_thermal_production.py','tests/dataqual15_hupsel/matrix_thermal_production_baseline.py'}
RECORDS={'integration/dataqual15_hupsel/'+n+'_20261106.json' for n in ('MATRIX_THERMAL_NATIVE_PREREGISTRATION','MATRIX_THERMAL_NATIVE_WINDOWS','MATRIX_THERMAL_NATIVE_POSIX','MATRIX_THERMAL_NATIVE_POSIX_WRITER','MATRIX_THERMAL_NATIVE_CANONICAL_RECEIPT','MATRIX_THERMAL_BUILD_PREREGISTRATION','MATRIX_THERMAL_BUILD_WINDOWS','MATRIX_THERMAL_BUILD_POSIX','MATRIX_THERMAL_BUILD_ADJUDICATION','MATRIX_THERMAL_BUILD_CANONICAL_RECEIPT')}
normal=lambda b:b.replace(b'\r\n',b'\n')
sha=lambda b:hashlib.sha256(b).hexdigest()
def git(*a):return subprocess.check_output(['git',*a],cwd=ROOT,text=True).strip()
def blob(ref,path):return git('rev-parse',ref+':'+path)

def guard():
 subprocess.run(['git','merge-base','--is-ancestor',BASE,'HEAD'],cwd=ROOT,capture_output=True,check=True)
 assert private.SOURCE==SOURCE
 for path in ('tests/dataqual15_hupsel/matrix_thermal_native_policy.py','tests/dataqual15_hupsel/rotation_native_baseline.py'):
  assert normal((ROOT/path).read_bytes())==subprocess.check_output(['git','show',BASE+':'+path],cwd=ROOT)
 assert set(git('diff','--name-only','--no-renames',BASE,'HEAD','--','src','app','reference').splitlines())=={SOURCE}
 assert not git('diff','HEAD','--','src','app','reference') and not git('ls-files','--others','--exclude-standard','--','src','app','reference')
 raw=normal((ROOT/SCOPE).read_bytes());assert raw==subprocess.check_output(['git','show','HEAD:'+SCOPE],cwd=ROOT);r=json.loads(raw)
 assert r['predecessor']==BASE and r['scope']=='SAME_PLATFORM_S5MT0001_NATIVE_LOGICAL_AND_RESTART_PUBLICATION'
 assert r['phase']=='EXECUTED_COMPLETE_WINDOWS_POSIX_O0_O2_NATIVE_POSTIMAGE' and r['whole_scientific_admission'] is False
 assert r['windows_path_scope']=='ASCII_ONLY' and r['binary_abi']=='SAME_PLATFORM_ONLY'
 assert r['posix_stage6']=='FAILURE_AFTER_REPLACEMENT' and r['windows_stage6']=='UNCHANGED_RESTART_API_SUCCESS'
 assert r['private_canonical']==dict(pr=1581,merge='60700e1bd3f934bbf28b486f7019c707a2f2dda5',tree='646ed8666a4624f481671e1954f0f52f3dbc2b76',all15_success=True)
 assert r['build_canonical']==dict(pr=1582,merge=BASE,tree='ac02481fd882553771ee893a42e2646aaca5f874',success=15,failed=1,broad_mc_verdict='FAILED_RETAINED')
 expected=private.candidate().encode();actual=normal((ROOT/SOURCE).read_bytes())
 assert actual==expected and sha(actual)==r['postimage_sha256']=='f4b2d12b3285b9517ad2ca2bc29cb47b8cd9bc129acb2825bd0e51d6f98d33be'
 assert r['predecessor_production_trees']=={area:blob(BASE,area) for area in ('src','app','reference')}
 assert set(r['production_delta'])=={SOURCE} and set(r['bridge_restore'])=={SOURCE,ENTRY,STATUS}|BRIDGES
 for path,pins in r['bridge_restore'].items():assert pins==dict(before=blob(BASE,path),after=blob('HEAD',path))
 assert r['production_delta'][SOURCE]==r['bridge_restore'][SOURCE]
 assert set(r['gate_source_sha256'])==GATES and set(r['qualified_artifact_records'])==RECORDS
 for key in ('gate_source_sha256','qualified_artifact_records'):
  for path,pin in r[key].items():
   data=normal((ROOT/path).read_bytes());assert sha(data)==pin and data==subprocess.check_output(['git','show','HEAD:'+path],cwd=ROOT)
   if key=='qualified_artifact_records' and subprocess.run(['git','cat-file','-e',BASE+':'+path],cwd=ROOT,capture_output=True).returncode==0:
    assert data==subprocess.check_output(['git','show',BASE+':'+path],cwd=ROOT)
 status=json.loads((ROOT/STATUS).read_text());previous=json.loads(subprocess.check_output(['git','show',BASE+':'+STATUS],cwd=ROOT))
 assert status.pop(KEY)==dict(scope=r['scope'],predecessor=BASE,whole_scientific_admission=False,windows_path_scope='ASCII_ONLY',posix_stage6='FAILURE_AFTER_REPLACEMENT') and status==previous
 return r

def prepare(out):
 out.mkdir(parents=True,exist_ok=True);view=out/'predecessor';assert not view.exists()
 subprocess.run(['git','-c','core.autocrlf=false','worktree','add','--detach',str(view),BASE],cwd=ROOT,capture_output=True,check=True)
 assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=view,text=True).strip()==BASE
 return view

def main():
 parser=argparse.ArgumentParser();parser.add_argument('--output',type=Path,required=True);parser.add_argument('--prepare-only',action='store_true');a=parser.parse_args();guard();out=a.output.resolve()
 if a.prepare_only:print(prepare(out));return
 view=prepare(out);events=[]
 def run(label,args,cwd=view,timeout=1200):
  command=[sys.executable,'-B',*args];cp=subprocess.run(command,cwd=cwd,env=dict(os.environ,PYTHONUTF8='1',OMP_NUM_THREADS='1'),capture_output=True,timeout=timeout)
  for stream in ('stdout','stderr'):(out/(label+'.'+stream)).write_bytes(getattr(cp,stream))
  events.append(dict(label=label,command=command,returncode=cp.returncode));(out/'EVENTS.json').write_text(json.dumps(events,indent=2)+'\n');assert cp.returncode==0,cp.stderr[-4000:]
 try:
  # These are the actual complete source/object/binary/native executions of
  # this exact full module and actual canonical build recipe, not snippets.
  run('windows-current-build',['tests/dataqual15_hupsel/matrix_thermal_build_evidence.py'])
  run('posix-current-build',['tests/dataqual15_hupsel/matrix_thermal_build_evidence.py','--stem','MATRIX_THERMAL_BUILD_POSIX_20261106'])
  run('broad-science-refusal',['tests/dataqual15_hupsel/matrix_thermal_build_adjudication.py'])
  historical=out/'private-authority'
  run('prepare-private',['tests/dataqual15_hupsel/matrix_thermal_build.py','--prepare-only','--output',str(historical)])
  private_view=historical/'predecessor'
  try:
   for label,extra in (('windows-reader-writer-termination',[]),('posix-original-refinement-sigkill',['--posix']),('posix-postcommit-failure',['--posix-writer'])):
    run(label,['tests/dataqual15_hupsel/matrix_thermal_native_evidence.py',*extra],cwd=private_view)
  finally:
   assert private_view.parent==historical and private_view.name=='predecessor';subprocess.run(['git','worktree','remove',str(private_view)],cwd=ROOT,capture_output=True,check=True)
  run('exact-unmodified-predecessor',[ENTRY,'--output',str(out/'old-admission')])
  guard();(out/'RESULT.json').write_text(json.dumps(dict(status='CURRENT_EXACT_COMPLETE_S5MT_NATIVE_POSTIMAGE_AND_UNMODIFIED_PREDECESSOR_PASS',current_source_head=git('rev-parse','HEAD'),current_source_sha256=sha(normal((ROOT/SOURCE).read_bytes())),events=events,old_entry_returncode=0,whole_scientific_admission=False,broad_mc_source_gate='FAILED_RETAINED',binary_abi='SAME_PLATFORM_ONLY'),indent=2)+'\n');print('CURRENT_EXACT_COMPLETE_S5MT_NATIVE_POSTIMAGE_AND_UNMODIFIED_PREDECESSOR_PASS')
 finally:
  assert view.parent==out and view.name=='predecessor';subprocess.run(['git','worktree','remove',str(view)],cwd=ROOT,capture_output=True,check=True)
if __name__=='__main__':main()

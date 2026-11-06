"""Exact executed S5PT production successor and unchanged predecessor authority."""
import argparse,hashlib,json,os,subprocess,sys,time
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
BASE='46505d617d4dae3053e6e72d63fae1c59baec2ab'
SOURCE='src/adapter/mod_pond_thermal_restart_file.f90'
ENTRY='tests/dataqual15/verify_current_native_admission.py'
STATUS='integration/dataqual15/STATUS.json'
KEY='pond_thermal_native_successor_20261106'
SCOPE='integration/dataqual15_hupsel/POND_THERMAL_PRODUCTION_SCOPE_20261106.json'
CURRENT_CAPSULES={'integration/dataqual15_hupsel/POND_THERMAL_PRODUCTION_'+host+'_20261106'+suffix for host in ('WINDOWS','POSIX') for suffix in ('.json','.tar.xz.part00')}
RECORDS={'integration/dataqual15_hupsel/POND_THERMAL_PRODUCTION_'+name+'_20261106'+suffix for name,suffix in (
 ('DIAGNOSTICS','.json'),('EXACT_BEFORE','.zip'),('BEFORE_POND_SOURCE','.json'),('BEFORE_POND_SOURCE','.zip'),
 ('INITIAL_FAILURES','.json'),('INITIAL_FAILURES','.zip'),('CURRENT_MC','.zip'),('EXECUTION_RECEIPT','.json'),('EXECUTION_LOGS','.zip'))}
BRIDGES={'.github/workflows/'+n+'.yml' for n in ('generation-publication','generation-crc','matrix-crc','native-n-production','matrix-thermal-native')}
BRIDGES.add('.github/workflows/pond-thermal-original.yml')
GATES={ENTRY,*BRIDGES,'tests/dataqual15_hupsel/pond_thermal_production.py','tests/dataqual15_hupsel/test_pond_thermal_production.py','.github/workflows/pond-thermal-production.yml'}
GATES.add('tests/dataqual15_hupsel/pond_thermal_production_baseline.py')
GATES.add('tests/dataqual15_hupsel/pond_thermal_production_diagnostics.py')
normal=lambda b:b.replace(b'\r\n',b'\n')
sha=lambda b:hashlib.sha256(b).hexdigest()
def git(*a):return subprocess.check_output(['git',*a],cwd=ROOT,text=True).strip()
def raw(ref,path):return subprocess.check_output(['git','show',ref+':'+path],cwd=ROOT)
def blob(ref,path):return git('rev-parse',ref+':'+path)
def frozen():
 return {p for p in git('ls-tree','-r','--name-only',BASE,'--','tests/dataqual15_hupsel','integration/dataqual15_hupsel').splitlines()
         if (Path(p).name.startswith('pond_thermal_') or Path(p).name.startswith('POND_THERMAL_'))
         and p!='integration/dataqual15_hupsel/POND_THERMAL_BUILD_RECOVERY_20261106.json'}

def guard():
 subprocess.run(['git','merge-base','--is-ancestor',BASE,'HEAD'],cwd=ROOT,check=True,capture_output=True)
 assert set(git('diff','--name-only','--no-renames',BASE,'HEAD','--','src','app','reference').splitlines())=={SOURCE},'production footprint'
 assert not git('diff','HEAD','--','src','app','reference'),'dirty production source'
 assert not git('ls-files','--others','--exclude-standard','--','src','app','reference'),'unknown production source'
 data=normal((ROOT/SCOPE).read_bytes());assert data==raw('HEAD',SCOPE),'dirty scope';r=json.loads(data)
 assert r['predecessor']==BASE and r['scope']=='SAME_PLATFORM_S5PT_NATIVE_LOGICAL_AND_PUBLICATION'
 assert r['phase']=='COMPLETE_EXECUTED_WINDOWS_POSIX_POSTIMAGE' and r['whole_scientific_admission'] is False
 assert r['binary_abi']=='SAME_PLATFORM_ONLY' and r['windows_path_scope']=='ASCII_ONLY'
 assert r['posix_stage6']=='FAILURE_AFTER_REPLACEMENT' and r['pending_retry']=='REFUSE_WITHOUT_OVERWRITE_OR_DELETE'
 assert r['private_canonical_merges']==['89a9e1cffc40b65339f9eba4b9451e7a574ccda6','8428323b15b126ba2a3422ef32d4d914b070db2f','88b66a5c604ac04df18d011eb659265ede3214d6',BASE]
 for ref in r['private_canonical_merges']:subprocess.run(['git','merge-base','--is-ancestor',ref,'HEAD'],cwd=ROOT,check=True,capture_output=True)
 expected=raw(BASE,'tests/dataqual15_hupsel/pond_thermal_native_candidate.f90')
 assert normal((ROOT/SOURCE).read_bytes())==expected and sha(expected)==r['postimage_sha256']=='91f397f612570d4dfac96bcacfc938d033f5325bfcce175e413960a8534d826b','postimage'
 assert r['predecessor_production_trees']=={p:blob(BASE,p) for p in ('src','app','reference')}
 assert set(r['production_delta'])=={SOURCE} and set(r['bridge_restore'])=={SOURCE,ENTRY,STATUS}|BRIDGES
 for path,pins in r['bridge_restore'].items():assert pins==dict(before=blob(BASE,path),after=blob('HEAD',path)),path
 assert r['production_delta'][SOURCE]==r['bridge_restore'][SOURCE]
 assert set(r['gate_source_sha256'])==GATES and set(r['frozen_authority'])==frozen()
 assert set(r['current_capsule_sha256'])==CURRENT_CAPSULES,'current execution evidence inventory'
 for path,pin in r['current_capsule_sha256'].items():
  content=(ROOT/path).read_bytes()
  if path.endswith('.json'):content=normal(content)
  assert sha(content)==pin and content==raw('HEAD',path),'current execution evidence identity: '+path
 assert set(r['qualified_record_sha256'])==RECORDS,'qualified record inventory'
 for path,pin in r['qualified_record_sha256'].items():
  content=(ROOT/path).read_bytes()
  if path.endswith('.json'):content=normal(content)
  assert sha(content)==pin and content==raw('HEAD',path),'qualified record identity: '+path
 for path,pin in r['gate_source_sha256'].items():assert sha(normal((ROOT/path).read_bytes()))==pin and normal((ROOT/path).read_bytes())==raw('HEAD',path),path
 for path,pin in r['frozen_authority'].items():
  content=(ROOT/path).read_bytes()
  if path.endswith(('.py','.f90','.json')):content=normal(content)
  assert blob(BASE,path)==pin==blob('HEAD',path) and content==raw(BASE,path),path
 current=json.loads((ROOT/STATUS).read_text());old=json.loads(raw(BASE,STATUS));canonical=lambda v:json.dumps(v,sort_keys=True,separators=(',',':'))
 addition=dict(scope=r['scope'],predecessor=BASE,whole_scientific_admission=False,binary_abi='SAME_PLATFORM_ONLY',windows_path_scope='ASCII_ONLY',posix_stage6='FAILURE_AFTER_REPLACEMENT')
 assert canonical(current.pop(KEY))==canonical(addition) and canonical(current)==canonical(old),'previous status/type authority'
 return r

def prepare(out):
 out.mkdir(parents=True,exist_ok=True);view=out/'predecessor';assert not view.exists()
 subprocess.run(['git','-c','core.autocrlf=false','worktree','add','--detach',str(view),BASE],cwd=ROOT,check=True,capture_output=True)
 assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=view,text=True).strip()==BASE
 return view

def execute(out,label,args,cwd=ROOT,timeout=2400):
 start=time.monotonic();cp=subprocess.run([sys.executable,'-B',*map(str,args)],cwd=cwd,capture_output=True,timeout=timeout,env=dict(os.environ,OMP_NUM_THREADS='1',PYTHONUTF8='1',PYTHONDONTWRITEBYTECODE='1'))
 for stream in ('stdout','stderr'):(out/(label+'.'+stream)).write_bytes(getattr(cp,stream))
 event=dict(label=label,command=[sys.executable,'-B',*map(str,args)],returncode=cp.returncode,seconds=time.monotonic()-start)
 with (out/'EVENTS.jsonl').open('a') as f:f.write(json.dumps(event)+'\n')
 assert cp.returncode==0,cp.stderr[-4000:];print(label,'PASS',flush=True)
 return event

def current_build(out):
 guard();out.mkdir(parents=True,exist_ok=False);view=out/'source';head=git('rev-parse','HEAD')
 subprocess.run(['git','-c','core.autocrlf=false','worktree','add','--detach','--no-checkout',str(view),head],cwd=ROOT,capture_output=True,check=True)
 paths=['src','app/support/restart_publish.c','tests/nut-sol/run_pond_thermal.py','tests/nut-sol/run_nonlinear_pond.py','tests/nut-sol/test_pond_thermal.f90','tests/nut-sol/matrix_nonlinear_oracle.f90','tests/modularity/low_air_consistent_grid_stubs.f90','tests/physics/test_ppa_wu05d2_mixed_application.f90','integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64']
 subprocess.run(['git','-c','core.autocrlf=false','checkout',head,'--',*paths],cwd=view,capture_output=True,check=True)
 assert (view/SOURCE).read_bytes()==normal((ROOT/SOURCE).read_bytes())
 events=[]
 for recipe in ('physical','black-rutter'):
  args=[view/'tests/nut-sol/run_pond_thermal.py','--output',out/recipe]
  if recipe=='black-rutter':args+=['--black-rutter','--resume-compilation',out/'physical']
  events.append(execute(out,recipe,args,cwd=view))
 (out/'CURRENT_BUILD_RESULT.json').write_text(json.dumps(dict(status='ACTUAL_CURRENT_SOURCE_ORIGINAL_COLD_RESUMED_O0_O2_PASS',head=head,production_trees={p:blob(head,p) for p in ('src','app','reference')},source_sha256=sha((view/SOURCE).read_bytes()),events=events,whole_scientific_admission=False),indent=2)+'\n');guard()

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);p.add_argument('--current-build',action='store_true');p.add_argument('--prepare-only',action='store_true');p.add_argument('--prepare-legacy-matrix',action='store_true');a=p.parse_args();guard();out=a.output.resolve()
 if a.prepare_only:print(prepare(out));return
 if a.current_build:current_build(out);return
 if a.prepare_legacy_matrix:
  view=prepare(out/'exact-s5pt-predecessor')
  execute(out,'unchanged-matrix-projection',['tests/dataqual15_hupsel/matrix_thermal_production.py','--prepare-only','--output',out],cwd=view);return
 out.mkdir(parents=True,exist_ok=True);view=prepare(out)
 import pond_thermal_original_evidence as evidence
 events=[]
 events.append(execute(out,'actual-source-before-diagnostics',['tests/dataqual15_hupsel/pond_thermal_production_diagnostics.py','--self-test']))
 # Exact current full source bytes, all unchanged dependencies, actual native files.
 for host,platform in [('WINDOWS','nt'),('POSIX','posix')]:
  stem='POND_THERMAL_PRODUCTION_'+host+'_20261106';m,files=evidence.load(stem)
  result=json.loads(files['CURRENT_BUILD_RESULT.json'])
  subprocess.run(['git','merge-base','--is-ancestor',result['head'],'HEAD'],cwd=ROOT,capture_output=True,check=True)
  assert result['status']=='ACTUAL_CURRENT_SOURCE_ORIGINAL_COLD_RESUMED_O0_O2_PASS' and result['whole_scientific_admission'] is False
  assert result['source_sha256']==sha(normal((ROOT/SOURCE).read_bytes()))
  assert result['production_trees']=={p:blob('HEAD',p) for p in ('src','app','reference')}
  events.append(dict(current_host=host,measurement=evidence.verify(stem,platform,True)))
 for family in ('native','layout','writer','original'):
  for host in ('WINDOWS','POSIX'):
   stem=('POND_THERMAL_ORIGINAL_WINDOWS_MEASUREMENT_20261106' if family=='original' and host=='WINDOWS' else 'POND_THERMAL_'+family.upper()+'_'+host+'_20261106')
   args=['tests/dataqual15_hupsel/pond_thermal_'+family+'_evidence.py','--stem',stem,'--self-test']
   if family=='original':args+=['--platform','nt' if host=='WINDOWS' else 'posix']
   events.append(execute(out,family+'-'+host,args,cwd=view))
 events.append(execute(out,'exact-unchanged-predecessor',[ENTRY,'--output',out/'old-admission'],cwd=view))
 guard();(out/'RESULT.json').write_text(json.dumps(dict(status='CURRENT_EXACT_COMPLETE_S5PT_AND_UNCHANGED_PREDECESSOR_PASS',head=git('rev-parse','HEAD'),source_sha256=sha(normal((ROOT/SOURCE).read_bytes())),events=events,whole_scientific_admission=False),indent=2)+'\n')

if __name__=='__main__':main()

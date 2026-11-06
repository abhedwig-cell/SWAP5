"""Admit the exact fully executed portable generation postimages, preserving history."""
import argparse,hashlib,json,os,subprocess,sys,tempfile
from pathlib import Path
import generation_publication_policy as candidate
import generation_crc_admission as previous
ROOT=candidate.ROOT;BASE='8da740df7b106d72045f34fa7cb5f351e129e1d5'
SOURCES=set([*candidate.SOURCES,candidate.C]);ENTRY=previous.ENTRY;STATUS=previous.STATUS
KEY='portable_generation_publication_successor_20261106'
SCOPE='integration/dataqual15_hupsel/GENERATION_PUBLICATION_SCOPE_20261106.json'
BRIDGES={'.github/workflows/'+n for n in ('generation-publication.yml','generation-crc.yml','matrix-crc.yml','native-n-production.yml')}
GATES={ENTRY,*BRIDGES,'tests/dataqual15_hupsel/generation_publication_admission.py','tests/dataqual15_hupsel/test_generation_publication_admission.py','tests/dataqual15_hupsel/generation_publication_policy.py','tests/dataqual15_hupsel/generation_publication_audit.py','tests/dataqual15_hupsel/generation_publication_capsule.py','tests/dataqual15_hupsel/generation_publication_models.py','tests/dataqual15_hupsel/generation_publication_c_probe.py','tests/dataqual15_hupsel/generation_publication_windows_faults.py','tests/dataqual15_hupsel/generation_publication_windows_crt.py','tests/nut-output/generation_publication_windows_test.c'}
RECORDS={'integration/dataqual15_hupsel/GENERATION_PUBLICATION_'+n+'_20261106.json' for n in ('WINDOWS','WINDOWS_COMPONENT','POSIX','PREREGISTRATION','DEPLOYMENT_PREREGISTRATION')}
sha=lambda b:hashlib.sha256(b).hexdigest()
normal=lambda b:b.replace(b'\r\n',b'\n')

def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()
def blob(ref,path):return git('rev-parse',ref+':'+path)

def guard():
 subprocess.run(['git','merge-base','--is-ancestor',BASE,'HEAD'],cwd=ROOT,check=True,capture_output=True)
 assert set(git('diff','--name-only','--no-renames',BASE,'HEAD','--','src','app','reference').splitlines())==SOURCES
 assert not git('diff','HEAD','--','src','app','reference') and not git('ls-files','--others','--exclude-standard','--','src','app','reference')
 raw=normal((ROOT/SCOPE).read_bytes());assert raw==subprocess.check_output(['git','show','HEAD:'+SCOPE],cwd=ROOT);r=json.loads(raw)
 assert r['predecessor']==BASE and r['scope']=='POSIX_AND_ASCII_WINDOWS_PRECOMMIT_COMPLETE_GENERATION_PUBLICATION'
 assert r['phase']=='QUALIFIED_FULL_NATIVE_WINDOWS_POSIX_O0_O2_AND_AUTHORITY_TERMINATION'
 assert r['whole_scientific_admission'] is False and r['windows_path_scope']=='ASCII_ONLY'
 assert r['generation_reported_failure_contract']=='BEFORE_AUTHORITATIVE_REPLACEMENT'
 assert r['restart_directory_sync_stage6']=='UNCHANGED_POST_REPLACEMENT_FAILURE'
 assert r['private_canonical']==dict(pr=1578,merge=BASE,qualified_head='eeb9f0e3cf73ac7080412bfcbff498e62d7aab68',tree='0abc22b8775e897608bcb05d89ea7e23901eb270',final_workflows=16,all_success=True)
 assert set(r['production_delta'])==SOURCES and set(r['bridge_restore'])==SOURCES|{ENTRY,STATUS}|BRIDGES
 assert r['predecessor_production_trees']=={p:blob(BASE,p) for p in ('src','app','reference')}
 assert blob('HEAD','reference')==blob(BASE,'reference')
 assert set(r['qualified_full_postimage_sha256'])==SOURCES
 for p in SOURCES:
  expected=(candidate.candidate_c() if p==candidate.C else candidate.candidate(p)).encode();actual=normal((ROOT/p).read_bytes())
  assert actual==expected and sha(actual)==r['qualified_full_postimage_sha256'][p]
  assert r['production_delta'][p]==r['bridge_restore'][p]
 for p,pins in r['bridge_restore'].items():assert pins==dict(before=blob(BASE,p),after=blob('HEAD',p))
 assert set(r['gate_source_sha256'])==GATES and set(r['qualified_artifact_records'])==RECORDS
 for key in ('gate_source_sha256','qualified_artifact_records'):
  for p,h in r[key].items():assert sha(normal((ROOT/p).read_bytes()))==h and normal((ROOT/p).read_bytes())==subprocess.check_output(['git','show','HEAD:'+p],cwd=ROOT)
 status=json.loads((ROOT/STATUS).read_text());old=json.loads(subprocess.check_output(['git','show',BASE+':'+STATUS],cwd=ROOT))
 assert status.pop(KEY)==dict(scope=r['scope'],predecessor=BASE,whole_scientific_admission=False,windows_path_scope='ASCII_ONLY',generation_failure_contract='BEFORE_AUTHORITATIVE_REPLACEMENT')
 assert status==old,'old admission fields changed'
 return r

def prepare(out):
 view=out/'predecessor';assert not view.exists();out.mkdir(parents=True,exist_ok=True)
 cp=subprocess.run(['git','-c','core.autocrlf=false','worktree','add','--detach',str(view),BASE],cwd=ROOT,env=previous.previous.predecessor.process_env(),capture_output=True)
 (out/'worktree.stdout').write_bytes(cp.stdout);(out/'worktree.stderr').write_bytes(cp.stderr);assert cp.returncode==0,cp.stderr
 assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=view,text=True).strip()==BASE
 return view

def current_proof():
 import generation_publication_capsule as evidence
 evidence.replay();evidence.posix()
 return dict(actual_windows_posix_full_postimages=True,actual_windows_precommit_failures=20,actual_windows_terminations=8,original_posix_kill_assertions=True,evidence_refusals_per_platform=4,whole_scientific_admission=False)

def main():
 p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);p.add_argument('--prepare-only',action='store_true');a=p.parse_args();guard();out=a.output.resolve();out.mkdir(parents=True,exist_ok=True)
 if a.prepare_only:print(prepare(out));return
 proof=current_proof()
 with tempfile.TemporaryDirectory(prefix='s5pub-own-') as temporary:
  work=Path(temporary).resolve();view=prepare(work)
  try:
   cp=subprocess.run([sys.executable,'-B',ENTRY,'--output',str(work/'old-admission')],cwd=view,env=dict(os.environ,PYTHONUTF8='1'),capture_output=True,timeout=1200)
   for stream in ('stdout','stderr'):(out/('old-admission.'+stream)).write_bytes(getattr(cp,stream))
   assert cp.returncode==0,cp.stderr[-4000:];guard()
   (out/'RESULT.json').write_text(json.dumps(dict(status='CURRENT_PORTABLE_GENERATION_FULL_POSTIMAGE_AND_EXACT_PREDECESSOR_PASS',current=proof,exact_predecessor=BASE,old_admission_returncode=0,whole_scientific_admission=False),indent=2)+'\n');print('CURRENT_PORTABLE_GENERATION_FULL_POSTIMAGE_AND_EXACT_PREDECESSOR_PASS')
  finally:
   assert view.parent==work and view.name=='predecessor';subprocess.run(['git','worktree','remove',str(view)],cwd=ROOT,check=True,capture_output=True)
if __name__=='__main__':main()

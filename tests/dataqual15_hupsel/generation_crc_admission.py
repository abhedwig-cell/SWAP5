"""Admit only the fully executed, existing POSIX complete-generation CRC scope."""
import argparse,hashlib,json,os,shutil,subprocess,sys,tempfile
from pathlib import Path
import generation_crc_runtime as runtime
import production_crop_logical_admission as previous
ROOT=runtime.ROOT;BASE=runtime.BASE;SOURCES=set(runtime.SOURCES.values())
ENTRY=previous.ENTRY;STATUS=previous.STATUS;KEY='generation_native_crc_successor_20261105'
SCOPE='integration/dataqual15_hupsel/GENERATION_CRC_SCOPE_20261105.json'
BRIDGES={'.github/workflows/matrix-crc.yml','.github/workflows/native-n-production.yml'}
GATES={ENTRY,'tests/dataqual15_hupsel/generation_crc_admission.py','tests/dataqual15_hupsel/generation_crc_runtime.py','tests/dataqual15_hupsel/generation_crc_evidence.py','tests/dataqual15_hupsel/generation_crc_posix_evidence.py','tests/dataqual15_hupsel/generation_crc_native_controls.py','tests/dataqual15_hupsel/generation_crc_controls_evidence.py','tests/dataqual15_hupsel/test_generation_crc_admission.py','.github/workflows/generation-crc.yml',*BRIDGES,'tests/dataqual15_hupsel/native_n_crc_runtime.py','tests/dataqual15_hupsel/native_n_crc_evidence.py','tests/dataqual15_hupsel/crc_family_runtime.py','integration/dataqual15_hupsel/GENERATION_CRC_PREREGISTRATION_20261105.json','integration/dataqual15_hupsel/GENERATION_CRC_CONTROLS_PREREGISTRATION_20261105.json','integration/dataqual15_hupsel/GENERATION_CRC_DEPLOYMENT_PREREGISTRATION_20261105.json'}
RECORDS={'integration/dataqual15_hupsel/GENERATION_CRC_WINDOWS_20261105_'+o+'.json'for o in ('O0','O2')}|{'integration/dataqual15_hupsel/GENERATION_CRC_POSIX_20261105.json','integration/dataqual15_hupsel/GENERATION_CRC_NATIVE_CONTROLS_20261105.json'}
sha=lambda b:hashlib.sha256(b).hexdigest()
def git(*a):return subprocess.check_output(['git',*a],cwd=ROOT,text=True).strip()
def blob(ref,path):return git('rev-parse',ref+':'+path)
def guard():
 subprocess.run(['git','merge-base','--is-ancestor',BASE,'HEAD'],cwd=ROOT,check=True,capture_output=True)
 assert set(git('diff','--name-only','--no-renames',BASE,'HEAD','--','src','app','reference').splitlines())==SOURCES
 assert not git('diff','HEAD','--','src','app','reference')and not git('ls-files','--others','--exclude-standard','--','src','app','reference')
 r=json.loads((ROOT/SCOPE).read_text());assert (ROOT/SCOPE).read_bytes().replace(b'\r\n',b'\n')==subprocess.check_output(['git','show','HEAD:'+SCOPE],cwd=ROOT)
 assert r['predecessor']==BASE and r['scope']=='EXISTING_SUPPORTED_POSIX_OUTPUT_SAVED_GENERATION_CRC32_ONLY'
 assert r['phase']=='QUALIFIED_COMPLETE_POSIX_O0_O2_AND32_PUBLIC_NATIVE_CONTROLS'
 assert r['whole_scientific_admission']is False and r['windows_native_publication_admission']is False
 assert r['windows_evidence_scope']=='COMPLETE_MODULE_COMPILATION_ONLY'
 assert set(r['production_delta'])==SOURCES and set(r['bridge_restore'])==SOURCES|{ENTRY,STATUS}|BRIDGES
 assert r['predecessor_production_trees']=={a:blob(BASE,a)for a in ('src','app','reference')}
 assert all(blob('HEAD',a)==blob(BASE,a)for a in ('app','reference'))
 assert set(r['qualified_full_postimage_sha256'])==SOURCES
 for p in SOURCES:
  raw=(ROOT/p).read_bytes().replace(b'\r\n',b'\n');assert raw==runtime.postimage(runtime.before(p).decode()).encode()
  assert sha(raw)==r['qualified_full_postimage_sha256'][p]and r['production_delta'][p]==r['bridge_restore'][p]
 for p,pins in r['bridge_restore'].items():
  assert pins==dict(before=blob(BASE,p),after=blob('HEAD',p))
  assert (ROOT/p).read_bytes().replace(b'\r\n',b'\n')==subprocess.check_output(['git','show','HEAD:'+p],cwd=ROOT)
 b=json.loads(runtime.before(STATUS));a=json.loads((ROOT/STATUS).read_text());assert a.pop(KEY)=={'scope':SCOPE}and a==b
 assert set(r['gate_source_sha256'])==GATES and all(sha((ROOT/p).read_bytes().replace(b'\r\n',b'\n'))==h for p,h in r['gate_source_sha256'].items())
 assert set(r['qualified_artifact_records'])==RECORDS and all(sha((ROOT/p).read_bytes().replace(b'\r\n',b'\n'))==h for p,h in r['qualified_artifact_records'].items())
 return r
def prepare(out):
 out.mkdir(parents=True,exist_ok=True);view=(out/'predecessor').resolve();assert view.parent==out.resolve()and not view.exists()
 env=previous.predecessor.process_env();p=subprocess.run(['git','-c','core.autocrlf=false','worktree','add','--detach',str(view),BASE],cwd=ROOT,env=env,capture_output=True)
 (out/'worktree.stdout').write_bytes(p.stdout);(out/'worktree.stderr').write_bytes(p.stderr);assert p.returncode==0,p.stderr
 assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=view,text=True).strip()==BASE
 return view
def current_proof():
 import generation_crc_evidence as compilation
 import generation_crc_posix_evidence as native
 import generation_crc_controls_evidence as controls
 compilation.local();record,files=native.unpack();proof=native.audit(files);refusals=native.controls(files);control=controls.qualified(files)
 assert proof==record['report']and control==json.loads((ROOT/'integration/dataqual15_hupsel/GENERATION_CRC_NATIVE_CONTROLS_20261105.json').read_text())['report']
 return dict(windows_complete_compilation=True,windows_native_publication_admission=False,posix=proof,data_refusals=refusals,native_public_controls=control)
def main():
 p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);p.add_argument('--prepare-only',action='store_true');a=p.parse_args();guard();out=a.output.resolve();out.mkdir(parents=True,exist_ok=True)
 if a.prepare_only:print(prepare(out));return
 current=current_proof();work=Path(tempfile.mkdtemp(prefix='s5gen-')).resolve()if os.name=='nt'else out;view=prepare(work)
 try:
  run=subprocess.run([sys.executable,'-B',ENTRY,'--output',str(work/'old-admission')],cwd=view,env=previous.predecessor.process_env(dict(os.environ,PYTHONUTF8='1')),capture_output=True,timeout=900)
  (out/'old-admission.stdout').write_bytes(run.stdout);(out/'old-admission.stderr').write_bytes(run.stderr);assert run.returncode==0,run.stderr[-3000:]
  guard();(out/'RESULT.json').write_text(json.dumps(dict(status='CURRENT_FULL_POSIX_GENERATION_POSTIMAGE_AND_EXACT_PREDECESSOR_PASS',current=current,exact_predecessor=BASE,old_admission_returncode=run.returncode,whole_scientific_admission=False),indent=2)+'\n');print('CURRENT_FULL_POSIX_GENERATION_POSTIMAGE_AND_EXACT_PREDECESSOR_PASS')
 finally:
  assert view.parent==work and view.name=='predecessor';subprocess.run(['git','worktree','remove',str(view)],cwd=ROOT,env=previous.predecessor.process_env(),check=True,capture_output=True)
  if work!=out:
   assert work.parent==Path(tempfile.gettempdir()).resolve()and work.name.startswith('s5gen-');shutil.rmtree(work)
if __name__=='__main__':main()

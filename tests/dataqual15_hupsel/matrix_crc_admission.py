"""Deploy only the complete matrix postimage actually executed on both platforms."""
import argparse,hashlib,json,os,shutil,subprocess,sys,tempfile
from pathlib import Path
import production_crop_logical_admission as previous
import matrix_crc_runtime as runtime
ROOT=runtime.ROOT;BASE=runtime.BASE;SOURCE=runtime.SOURCE
ENTRY=previous.ENTRY;STATUS=previous.STATUS;KEY='matrix_native_crc_successor_20261105'
SCOPE='integration/dataqual15_hupsel/MATRIX_CRC_SCOPE_20261105.json'
BRIDGE=('.github/workflows/native-n-production.yml',)
GATES=(ENTRY,'tests/dataqual15_hupsel/matrix_crc_admission.py','tests/dataqual15_hupsel/matrix_crc_runtime.py','tests/dataqual15_hupsel/matrix_crc_evidence.py','tests/dataqual15_hupsel/test_matrix_crc_admission.py','.github/workflows/matrix-crc.yml',*BRIDGE,'tests/dataqual15_hupsel/native_n_crc_runtime.py','tests/dataqual15_hupsel/native_n_crc_evidence.py','tests/dataqual15_hupsel/production_crop_logical_admission.py','integration/dataqual15_hupsel/MATRIX_CRC_PREREGISTRATION_20261105.json')
sha=lambda b:hashlib.sha256(b).hexdigest()
def git(*a):return subprocess.check_output(['git',*a],cwd=ROOT,text=True).strip()
def before(n):return subprocess.check_output(['git','show',BASE+':'+n],cwd=ROOT)
def guard():
 subprocess.run(['git','merge-base','--is-ancestor',BASE,'HEAD'],cwd=ROOT,check=True,capture_output=True)
 assert set(git('diff','--name-only','--no-renames',BASE,'HEAD','--','src','app','reference').splitlines())=={SOURCE}
 assert not git('diff','HEAD','--','src','app','reference')and not git('ls-files','--others','--exclude-standard','--','src','app','reference')
 assert(ROOT/SOURCE).read_bytes().replace(b'\r\n',b'\n')==runtime.postimage().encode()
 assert(ROOT/SCOPE).read_bytes().replace(b'\r\n',b'\n')==subprocess.check_output(['git','show','HEAD:'+SCOPE],cwd=ROOT)
 r=json.loads((ROOT/SCOPE).read_text());assert r['predecessor']==BASE and r['whole_scientific_admission']is False
 assert r['scope']=='CURRENT_MATRIX_NATIVE_CRC32_ISO_HDLC_ONLY'and r['phase']=='QUALIFIED_WINDOWS_AND_POSIX_FULL_POSTIMAGE'
 assert set(r['production_delta'])=={SOURCE}and set(r['bridge_restore'])=={SOURCE,ENTRY,STATUS,*BRIDGE}
 assert r['predecessor_production_trees']=={a:git('rev-parse',BASE+':'+a)for a in ('src','app','reference')}
 assert all(git('rev-parse','HEAD:'+a)==git('rev-parse',BASE+':'+a)for a in ('app','reference'))
 for n,pins in r['bridge_restore'].items():
  assert pins['before']==git('rev-parse',BASE+':'+n)and pins['after']==git('rev-parse','HEAD:'+n)
  assert(ROOT/n).read_bytes().replace(b'\r\n',b'\n')==subprocess.check_output(['git','show','HEAD:'+n],cwd=ROOT)
 assert r['production_delta'][SOURCE]==r['bridge_restore'][SOURCE]
 b=json.loads(before(STATUS));a=json.loads((ROOT/STATUS).read_text());assert a.pop(KEY)=={'scope':SCOPE}and a==b
 assert set(r['gate_source_sha256'])==set(GATES)
 assert all(sha((ROOT/n).read_bytes().replace(b'\r\n',b'\n'))==h for n,h in r['gate_source_sha256'].items())
 records={'integration/dataqual15_hupsel/MATRIX_CRC_WINDOWS_20261105_'+o+'.json'for o in ('O0','O2')}|{'integration/dataqual15_hupsel/MATRIX_CRC_POSIX_20261105.json'}
 assert set(r['qualified_artifact_records'])==records
 assert all(sha((ROOT/n).read_bytes().replace(b'\r\n',b'\n'))==h for n,h in r['qualified_artifact_records'].items())
 return r
def main():
 p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);p.add_argument('--prepare-only',action='store_true');a=p.parse_args();r=guard();out=a.output.resolve();out.mkdir(parents=True)
 work=Path(tempfile.mkdtemp(prefix='s5mx-')).resolve()if os.name=='nt'else out;view,projection=previous.prepare(r,work)
 try:
  if a.prepare_only:print(view);return
  import matrix_crc_evidence as evidence
  current=dict(windows=evidence.windows(),posix=evidence.posix())
  run=subprocess.run([sys.executable,'-B',ENTRY,'--output',str(work/'old-admission')],cwd=view,env=previous.predecessor.process_env(dict(os.environ,PYTHONUTF8='1')),capture_output=True)
  (out/'old-admission.stdout').write_bytes(run.stdout);(out/'old-admission.stderr').write_bytes(run.stderr);assert run.returncode==0,run.stderr[-3000:]
  guard();(out/'RESULT.json').write_text(json.dumps(dict(status='CURRENT_FULL_MATRIX_POSTIMAGE_AND_UNMODIFIED_PREDECESSOR_PASS',current=current,projection=projection,old_admission_returncode=run.returncode,whole_scientific_admission=False),indent=2)+'\n');print('CURRENT_FULL_MATRIX_POSTIMAGE_AND_UNMODIFIED_PREDECESSOR_PASS')
 finally:
  if not a.prepare_only:
   subprocess.run(['git','worktree','remove',str(view)],cwd=ROOT,env=previous.predecessor.process_env(),check=True,capture_output=True)
   if work!=out:
    assert work.parent==Path(tempfile.gettempdir()).resolve()and work.name.startswith('s5mx-');shutil.rmtree(work)
if __name__=='__main__':main()

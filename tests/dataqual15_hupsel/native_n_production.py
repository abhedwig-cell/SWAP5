"""Two exact native CRC source successors; prior admission runs unmodified."""
import argparse,hashlib,json,os,shutil,subprocess,sys,tempfile
from pathlib import Path
import production_crop_logical_admission as previous
ROOT=previous.ROOT;BASE='b41e1cda439a370a7e1966387412bdf55ca1b096'
SOURCES=('src/adapter/mod_mineral_joint_restart_file.f90','src/adapter/mod_reactive_n_joint_restart_file.f90')
ENTRY=previous.ENTRY;STATUS=previous.STATUS;KEY='native_n_crc_successor_20261105'
SCOPE='integration/dataqual15_hupsel/NATIVE_N_PRODUCTION_SCOPE_20261105.json'
BRIDGE=('.github/workflows/native-n-crc.yml',)
GATES=(ENTRY,'tests/dataqual15_hupsel/native_n_production.py','tests/dataqual15_hupsel/native_n_production_runtime.py','tests/dataqual15_hupsel/native_n_production_evidence.py','tests/dataqual15_hupsel/test_native_n_production.py','.github/workflows/native-n-production.yml',*BRIDGE,'tests/dataqual15_hupsel/native_n_crc_runtime.py','tests/dataqual15_hupsel/native_n_crc_evidence.py','tests/dataqual15_hupsel/crc_family_runtime.py','tests/dataqual15_hupsel/production_crop_logical_admission.py','integration/dataqual15_hupsel/NATIVE_N_PRODUCTION_PREREGISTRATION_20261105.json','integration/dataqual15_hupsel/NATIVE_N_CRC_WINDOWS_20261105_O0.json','integration/dataqual15_hupsel/NATIVE_N_CRC_WINDOWS_20261105_O2.json','integration/dataqual15_hupsel/NATIVE_N_CRC_POSIX_20261105.json')
sha=lambda b:hashlib.sha256(b).hexdigest()
def git(*a):return subprocess.check_output(['git',*a],cwd=ROOT,text=True).strip()
def before(name):return subprocess.check_output(['git','show',BASE+':'+name],cwd=ROOT)
def postimage(name):
 old=before(name).decode();start=old.index('  function crc32(bytes) result(crc)');end=old.index('  end function',start)+len('  end function\n');body=old[:start]+old[end:]
 marker='  use iso_fortran_env,only:real64,int64,int32,int8,iostat_end\n';assert body.count(marker)==1
 return body.replace(marker,marker+'  use mod_age_joint_restart_file,only:crc32\n',1)
def guard(development=False):
 assert set(git('diff','--name-only','--no-renames',BASE,'--','src','app','reference').splitlines())==set(SOURCES)
 assert not git('ls-files','--others','--exclude-standard','--','src','app','reference')
 for n in SOURCES:assert (ROOT/n).read_bytes().replace(b'\r\n',b'\n')==postimage(n).encode()
 for a in ('app','reference'):assert git('rev-parse','HEAD:'+a)==git('rev-parse',BASE+':'+a)
 if not development:
  assert not git('diff','HEAD','--','src','app','reference')
  assert (ROOT/SCOPE).read_bytes().replace(b'\r\n',b'\n')==subprocess.check_output(['git','show','HEAD:'+SCOPE],cwd=ROOT)
  r=json.loads((ROOT/SCOPE).read_text());assert r['predecessor']==BASE and r['whole_scientific_admission']is False
  assert r['scope']=='CURRENT_NATIVE_MINERAL_REACTIVE_CRC32_ISO_HDLC_ONLY'
  assert r['phase']in ('QUALIFIED_CURRENT_WINDOWS_AND_POSIX','QUALIFIED_CURRENT_WINDOWS_POSIX_PENDING')
  assert set(r['gate_source_sha256'])==set(GATES)
  assert set(r['production_delta'])==set(SOURCES)and set(r['bridge_restore'])=={*SOURCES,ENTRY,STATUS,*BRIDGE}
  assert r['predecessor_production_trees']=={a:git('rev-parse',BASE+':'+a)for a in ('src','app','reference')}
  for n,pins in r['bridge_restore'].items():
   assert pins['before']==git('rev-parse',BASE+':'+n)and pins['after']==git('rev-parse','HEAD:'+n)
   assert(ROOT/n).read_bytes().replace(b'\r\n',b'\n')==subprocess.check_output(['git','show','HEAD:'+n],cwd=ROOT)
  assert all(r['production_delta'][n]==r['bridge_restore'][n]for n in SOURCES)
  b=json.loads(before(STATUS));a=json.loads((ROOT/STATUS).read_text());assert a.pop(KEY)=={'scope':SCOPE}and a==b
  assert all(sha((ROOT/n).read_bytes().replace(b'\r\n',b'\n'))==h for n,h in r['gate_source_sha256'].items())
  records={'integration/dataqual15_hupsel/NATIVE_N_PRODUCTION_WINDOWS_20261105_'+o+'.json'for o in ('O0','O2')}
  if r['phase']=='QUALIFIED_CURRENT_WINDOWS_AND_POSIX':records.add('integration/dataqual15_hupsel/NATIVE_N_PRODUCTION_POSIX_20261105.json')
  assert set(r['qualified_artifact_records'])==records
  assert all(sha((ROOT/n).read_bytes().replace(b'\r\n',b'\n'))==h for n,h in r['qualified_artifact_records'].items())
 return True
def main():
 p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);p.add_argument('--prepare-only',action='store_true');a=p.parse_args();guard();out=a.output.resolve();out.mkdir(parents=True)
 r=json.loads((ROOT/SCOPE).read_text());work=Path(tempfile.mkdtemp(prefix='s5nn-')).resolve()if os.name=='nt'else out
 view,projection=previous.prepare(r,work)
 try:
  if a.prepare_only:print(view);return
  import native_n_production_evidence as evidence
  current=dict(windows=evidence.windows())
  if r['phase']=='QUALIFIED_CURRENT_WINDOWS_AND_POSIX':current['posix']=evidence.posix()
  else:assert r['phase']=='QUALIFIED_CURRENT_WINDOWS_POSIX_PENDING'
  run=subprocess.run([sys.executable,'-B',ENTRY,'--output',str(work/'old-admission')],cwd=view,env=previous.predecessor.process_env(dict(os.environ,PYTHONUTF8='1')),capture_output=True)
  (out/'old-admission.stdout').write_bytes(run.stdout);(out/'old-admission.stderr').write_bytes(run.stderr);assert run.returncode==0,run.stderr[-3000:]
  guard();(out/'RESULT.json').write_text(json.dumps(dict(status='CURRENT_NATIVE_N_CRC_AND_UNMODIFIED_PREDECESSOR_PASS',current=current,projection=projection,old_admission_returncode=run.returncode,whole_scientific_admission=False),indent=2)+'\n');print('CURRENT_NATIVE_N_CRC_AND_UNMODIFIED_PREDECESSOR_PASS')
 finally:
  if not a.prepare_only:
   subprocess.run(['git','worktree','remove',str(view)],cwd=ROOT,env=previous.predecessor.process_env(),check=True,capture_output=True)
   if work!=out:
    assert work.parent==Path(tempfile.gettempdir()).resolve()and work.name.startswith('s5nn-');shutil.rmtree(work)
if __name__=='__main__':main()

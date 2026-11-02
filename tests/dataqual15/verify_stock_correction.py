"""Verify CLOSURE16 corrected accounting evidence; retain physical and EB-I25 failures."""
import hashlib
import io
import json
from pathlib import Path
import subprocess
import tarfile

from qualify_energy_boundary import inputs, observe

ROOT=Path(__file__).resolve().parents[2]
sha=lambda raw:hashlib.sha256(raw).hexdigest()


def verify():
 m=json.loads((ROOT/'integration/dataqual15/STOCK_PRODUCTION_CORRECTION_20261102.json').read_text())
 assert m['production_source_changed'] and not m['full_energy_balance_complete'] and not m['whole_scientific_equivalence']
 archive=ROOT/m['archive'];raw=archive.read_bytes()
 assert len(raw)==m['archive_bytes'] and sha(raw)==m['archive_sha256']
 with tarfile.open(fileobj=io.BytesIO(raw))as t:
  members=t.getmembers();assert len({x.name for x in members})==len(members)
  assert all(x.isfile() and not Path(x.name).is_absolute() and '..'not in Path(x.name).parts for x in members)
  files={x.name:t.extractfile(x).read()for x in members}
 assert json.loads(files.pop('MANIFEST.json'))=={n:sha(b)for n,b in files.items()}
 for path,pin in m['source_sha256'].items():
  assert sha(files['sources/'+path])==pin
 for path,pin in m['current_component_source_sha256'].items():
  assert sha((ROOT/path).read_bytes())==pin,('current heat dependency changed',path)
 stock=json.loads(files['stock/RESULT.json']);energy=json.loads(files['energy/RESULT.json']);runtime=json.loads(files['runtime/RESULT.json'])
 module='src/process/mod_whole_column_sensible_energy_accounting.f90'
 assert files['stock/candidate/'+module]==files['sources/'+module]
 original=files['predecessor_accounting.f90']
 assert hashlib.sha1(b'blob '+str(len(original)).encode()+b'\0'+original).hexdigest()==stock['original_module_git_blob']
 assert original==subprocess.check_output(['git','cat-file','blob',stock['original_module_git_blob']],cwd=ROOT)
 assert stock['production_modified'] and not stock['production_admitted'] and not stock['full_energy_balance_complete']
 for opt in ['O0','O2']:
  expected_stdout=files['stock/'+opt+'-candidate/stdout']
  assert expected_stdout==files['energy/'+opt+'/stdout']
  assert sha(expected_stdout)==stock['builds'][opt+'-candidate']['stdout_sha256']
  for variant in ['candidate','fault']:
   report=stock['builds'][opt+'-'+variant]
   output=files['stock/'+opt+'-'+variant+'/stdout']
   assert sha(output)==report['stdout_sha256']
   assert sha(files['stock/'+opt+'-'+variant+'/driver'])==report['executable_sha256']
   observed=observe(output.decode(),inputs())
   assert all(observed[k]==v for k,v in report.items()if k in observed)
   assert observed['raw_storage_domain_rejections']==observed['missing_boundary_rejections']==864
   assert observed['projected_stock_roundoff_rejections']==(0 if variant=='candidate'else 864)
   assert observed['counterfactual_max_residual_j_cm2']['kind1_gauge0']==m['component']['physical_gap_j_cm2']
  assert sha(files['energy/'+opt+'/driver'])==energy['builds'][opt]['executable_sha256']
 assert files['energy/O0/stdout']==files['energy/O2/stdout']
 # Exact former candidate output establishes that no physical heat observation
 # changed when the isolated correction became actual current production.
 oldmeta=json.loads((ROOT/'integration/dataqual15/STOCK_PROJECTION_CANDIDATE_RESULT_20261102.json').read_text())
 assert sha(files['energy/O2/stdout'])==oldmeta['builds']['O2-candidate']['stdout_sha256']
 assert runtime['provider_count']==186 and len(runtime['results'])==8
 native=[e for e in runtime['events']if e['label'].startswith('native_')]
 assert len(native)==16 and sum(e['returncode']!=0 for e in native)==4
 assert all(e['returncode']==0 for e in runtime['events']if not e['label'].startswith('native_'))
 for key,r in runtime['results'].items():
  opt,test=key.split('/')
  expected=1 if '_i25_'in test else 0
  for variant in ['corrected','predecessor']:
   prefix='runtime/'+opt+'/'+test+'-'+variant
   assert sha(files[prefix+'.stdout'])==r[variant]['stdout_sha256']
   assert sha(files[prefix+'.stderr'])==r[variant]['stderr_sha256']
   assert r[variant]['returncode']==expected
  assert files['runtime/'+opt+'/'+test+'-corrected.stdout']==files['runtime/'+opt+'/'+test+'-predecessor.stdout']
  assert r['same_exit_and_stdout'] and r['same_error_stop_reason']
  if expected:
   assert r['qualification']=='FAIL_RETAINED_IDENTICAL_PREDECESSOR'
   assert b'EB_I25_TEST_FAIL external full-half outflow fixture rejected before commit' in files['runtime/'+opt+'/'+test+'-corrected.stdout']
  else:assert r['qualification']=='PASS'
 deltas=[path for path,pin in runtime['source_sha256'].items()if sha((ROOT/path).read_bytes())!=pin]
 if deltas:
  print('RUNTIME_MEASUREMENT_POSTIMAGE='+runtime['measurement_commit']+'; CURRENT_RUNTIME_EVIDENCE=NOT_INHERITED; CHANGED_DEPENDENCIES='+','.join(deltas))
 print('NUMERICAL_STOCK_CORRECTION_EVIDENCE=PASS; MEASURED_EB22/23/24=PASS; MEASURED_EB25=FAIL_RETAINED; PHYSICAL_ENERGY_AND_WHOLE_SCIENCE=OPEN')

if __name__=='__main__':verify()

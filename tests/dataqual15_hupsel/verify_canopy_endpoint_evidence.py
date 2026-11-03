"""Verify actual endpoint proof separately from historical science authority."""
import hashlib,json,subprocess,tarfile
from pathlib import Path,PurePosixPath,PureWindowsPath
ROOT=Path(__file__).resolve().parents[2]
BASE=ROOT/'integration/dataqual15_hupsel'
sha=lambda raw:hashlib.sha256(raw).hexdigest()

def verify():
 record=json.loads((BASE/'CANOPY_ENDPOINT_WINDOWS_20261103.tar.json').read_text())
 assert not record['whole_scientific_admission']
 archive=BASE/'CANOPY_ENDPOINT_WINDOWS_20261103.tar.xz'
 assert sha(archive.read_bytes())==record['archive_sha256']
 for name,pin in record['normalized_repository_source_sha256'].items():
  assert sha((ROOT/name).read_bytes().replace(b'\r\n',b'\n'))==pin,name
 with tarfile.open(archive)as t:
  members=t.getmembers()
  assert len({m.name for m in members})==len(members)
  assert all(m.isfile()and not PurePosixPath(m.name).is_absolute()and not PureWindowsPath(m.name).drive
             and '..'not in PurePosixPath(m.name).parts and '\\'not in m.name for m in members)
  files={m.name:t.extractfile(m).read()for m in members}
 assert {n:sha(b)for n,b in files.items()}==record['files_sha256']
 for name,pin in record['normalized_repository_source_sha256'].items():
  assert sha(files['sources/'+name].replace(b'\r\n',b'\n'))==pin,name
 prefix=json.loads(files['prefix/RESULT.json'])
 assert prefix['returncode']==0 and prefix['from_start'] and prefix['restart_sha256']is None
 for opt in ('O0','O2'):
  r=json.loads(files['native-'+opt+'/RESULT.json']);assert r==record['results'][opt]
  assert not r['full_scientific_qualification']
  assert [o['cut']for o in r['observations']]==[930,956,989,1033]
  build=json.loads(files['build-'+opt+'/BUILD.json'])
  assert build['executable_sha256']==r['current_executable_sha256']
  for o in r['observations']:
   assert o['same_build_restart_exact']and o['all_other_typed_owner_bytes_exact']
   assert o['stock_after']==o['accepted_capacity']and o['stock_before']>o['stock_after']
   assert abs(o['export_cm']-(o['stock_before']-o['stock_after']))<1e-14
   assert o['next_day_capacity_export_cm']==0
   assert abs(o['water_residual_cm'])<=1e-10 and abs(o['solute_residual_mg_cm2'])<=1e-10
   assert [c['decoded']for c in o['coherence_controls']]==[True,True,False]
   cut=str(o['cut'])
   assert files['native-'+opt+'/'+cut+'-continuous/checkpoint.bin']==files['native-'+opt+'/'+cut+'-resumed/checkpoint.bin']
  corrupt=json.loads(files['corrupt-'+opt+'/RESULT.json'])
  assert len(corrupt['events'])==37 and all(e['status']=='PASS'for e in corrupt['events'])
  assert json.loads(files['publication-'+opt+'/RESULT.json'])['status']=='NATIVE_TWO_DAY_PUBLICATION_RESTART_AND_CORRUPTION_PASS'
  assert json.loads(files['owner-'+opt+'/RESULT.json'])['status']=='ACTUAL_RUTTER_ENDPOINT_PHYSICAL_MASS_AND_COMPLETE_OWNER_BYTE_CONTROLS_PASS_NOT_WHOLE_SCIENCE'
 thermal_path=BASE/'CANOPY_CURRENT_THERMAL_20261103.tar.json'
 assert thermal_path.is_file(),'fresh shared kernel/backend thermal preservation required'
 if thermal_path.exists():
  thermal=json.loads(thermal_path.read_text())
  archive=BASE/'CANOPY_CURRENT_THERMAL_20261103.tar.xz'
  assert sha(archive.read_bytes())==thermal['archive_sha256']
  with tarfile.open(archive)as t:
   members=t.getmembers();assert len({m.name for m in members})==len(members)
   assert all(m.isfile()and not PurePosixPath(m.name).is_absolute()and not PureWindowsPath(m.name).drive
              and '..'not in PurePosixPath(m.name).parts and '\\'not in m.name for m in members)
   tf={m.name:t.extractfile(m).read()for m in members}
  assert {n:sha(b)for n,b in tf.items()}==thermal['files_sha256']
  tr=json.loads(tf['RESULT.json'])
  assert tr['status']=='ACTUAL_THERMAL_RECEIPTS_O0_O2_AND_EXISTING_EB_RUNTIME_PASS'
  assert not tr['full_energy_balance_complete']
  for name,blob in tr['source_git_blob'].items():
   assert subprocess.check_output(['git','rev-parse','HEAD:'+name],cwd=ROOT,text=True).strip()==blob,name
  assert tf['O0/receipts.csv']==tf['O2/receipts.csv']
  for i in range(4):
   assert tf['O0/test-'+str(i)+'.stdout']==tf['O2/test-'+str(i)+'.stdout']
   assert b'PASS'in tf['O0/test-'+str(i)+'.stdout']
 print('FOUR_NATIVE_CANOPY_ENDPOINTS_O0_O2_AND_COHERENT_RESTART_PASS_NOT_WHOLE_SCIENCE')
 return record

if __name__=='__main__':verify()

import hashlib,json,subprocess,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
DIGEST='14c4791409fca162a0aec4a3d97e20b9560f877e3b6be95019179ad0eace0a3e'
def main():
 path=ROOT/'integration/dataqual15_hupsel/MATRIX_CRC_COLUMN_POSIX_20261105.zip';assert hashlib.sha256(path.read_bytes()).hexdigest()==DIGEST
 sha=lambda b:hashlib.sha256(b).hexdigest()
 with zipfile.ZipFile(path)as z:
  assert len(z.namelist())==len(set(z.namelist()))
  r=json.loads(z.read('qualification/result.json'));assert r['status']=='PASS' and len(r['events'])==86
  for opt in ('O0','O2'):
   b=json.loads(z.read(opt+'/build-complete.json'));assert b['status']=='BUILT' and b['candidate']=='a76cb1143d3ee5f310e173ec1ef632b2e641b05c'
   assert '-'+opt in b['flags'] and '-fcheck=all'in b['flags']
   for p,h in b['input_sha256'].items():assert sha((ROOT/p).read_bytes().replace(b'\r\n',b'\n'))==h,p
   assert b['input_sha256']['src/adapter/mod_matrix_joint_restart_file.f90']==sha((ROOT/'src/adapter/mod_matrix_joint_restart_file.f90').read_bytes().replace(b'\r\n',b'\n'))
   for event in b['events']:
    assert event['returncode']==0
    for stream in ('stdout','stderr'):assert opt+'/'+event[stream]in z.namelist()
  for name,key in [('tests/nut-sol/test_column_input.py','test_sha256'),('tools/solute/run_column.py','runner_sha256'),('examples/solute_column/positive_pond.nml','input_sha256')]:
   assert sha((ROOT/name).read_bytes().replace(b'\r\n',b'\n'))==r[key],name
  for event in r['events']:
   for stream in ('stdout','stderr'):assert 'qualification/'+event[stream]in z.namelist()
 print('ACTUAL_CURRENT_COLUMN_O0_O2_FILE_RESTART_QUALIFICATION_REMEASURED_OLD_SURFACE_GUARD_STAYS_FAILED')
if __name__=='__main__':main()

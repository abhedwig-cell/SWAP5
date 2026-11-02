"""Verify sealed paired heat results against unchanged sources and B1 authority."""
import base64,hashlib,io,json,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sha=lambda b:hashlib.sha256(b).hexdigest()
def main():
 result=json.loads((ROOT/'integration/dataqual15/PAIRED_HEAT_OWNER_RESULT_20261102.json').read_text())
 assert not result['production_changed'] and not result['full_energy_complete']
 for p,h in result['source_sha256'].items():assert sha((ROOT/p).read_bytes())==h,('source changed',p)
 raw=(ROOT/result['archive']).read_bytes();assert sha(raw)==result['archive_sha256']
 with tarfile.open(fileobj=io.BytesIO(raw))as t:
  members=t.getmembers();assert len({m.name for m in members})==len(members)
  assert all(m.isfile()and not Path(m.name).is_absolute()and'..'not in Path(m.name).parts for m in members)
  files={m.name:t.extractfile(m).read()for m in members}
 manifest=json.loads(files.pop('MANIFEST.json'));assert manifest=={n:sha(b)for n,b in files.items()}
 measured=json.loads(files['RESULT.json']);assert all(result[k]==v for k,v in measured.items())
 for opt in ['O0','O2']:
  build=json.loads(files['original-'+opt+'/BUILD.json']);assert build['status']=='BUILT'
  for p,h in build['authority_sha256'].items():assert sha((ROOT/p).read_bytes())==h
  authority=ROOT/'integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64'
  with tarfile.open(fileobj=io.BytesIO(base64.b64decode(authority.read_bytes())))as t:
   assert sha(t.extractfile('SWAP/temperature.f90').read())==build['source_sha256']['source/SWAP/temperature.f90']
  raw=files[opt+'/stdout'];b=result['builds'][opt];assert sha(raw)==b['stdout_sha256']
  rows=[s.split(',')for s in raw.decode().splitlines()if s.startswith('PAIR,')]
  assert len(rows)==b['cases']==432
  assert {int(r[1])for r in rows}==set(range(1,433))and{int(r[2])for r in rows}==set(range(4))
  for column,key in [(3,'max_temperature_difference_c'),(4,'max_capacity_difference'),(8,'max_boundary_energy_difference_j_cm2')]:
   assert max(float(r[column])for r in rows)==b[key]
  assert b['max_temperature_difference_c']<1.1e-14 and b['max_capacity_difference']==0
  assert b['max_boundary_energy_difference_j_cm2']<5e-13
  for kind in range(4):assert max(abs(float(r[5]))for r in rows if int(r[2])==kind)==b['shared_physical_gap_j_cm2_by_kind'][str(kind)]
  assert b['shared_physical_gap_j_cm2_by_kind']['1']>1.45
 assert files['O0/stdout']==files['O2/stdout']and result['O0_O2_stdout_exact']
 print('PAIRED UNMODIFIED B111/CURRENT HEAT VERIFIED; SHARED PHYSICAL ENERGY LIMITATION RETAINED')
if __name__=='__main__':main()

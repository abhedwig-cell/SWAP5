"""Verify bounded weather repair evidence; this is not canonical admission."""
import hashlib,json,sys,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];sha=lambda raw:hashlib.sha256(raw).hexdigest()
def verify(files,source=lambda p:(ROOT/p).read_bytes()):
 manifest=json.loads(files['MANIFEST.json']);assert set(files)==set(manifest)|{'MANIFEST.json'}
 for p,h in manifest.items():assert sha(files[p])==h,p
 assert all(not raw.startswith(b'\x7fELF') for raw in files.values())
 for p,raw in files.items():
  if p.startswith('source/'):assert source(p[7:])==raw,p
 summary=json.loads(files['assessment.json']);assert summary['optimization_exact'] and summary['wet_reconstruction_exact']
 for name in ['final97','final-O0-97','final-ref97','final-coarse97','final-mid97','final-loose97','final-restart97']:
  r=json.loads(files['native/'+name+'/RESULT.json']);assert r['status']=='COMPLETE_NATIVE_OBSERVATION' and r['completed_days']==97 and r['returncode']==0
  for p,h in r['raw_sha256'].items():assert sha(files['native/'+name+'/'+p])==h
 for name in ['final-proof-O0','final-proof-O2','final-default-O0','final-default-O2']:
  r=json.loads(files['controls/'+name+'/RESULT.json']);assert 'PASS' in r['status'] or 'BYTE_EXACT' in r['status']
 r=json.loads(files['native/final-rollback/RESULT.json']);assert r['returncode']==0 and not r['timed_out'];assert b'WEATHER_SURFACE_ROLLBACK_PASS           1' in files['native/final-rollback/stdout']
 assert summary['hard_transaction_mass_gate_cm']==1e-14
 return {'status':'BOUNDED_WEATHER_REPAIR_CAPSULE_PASS','canonically_admitted':False,'members':len(files),'strict_refinement':summary['strict_refinement']['status']}
def main():
 p=ROOT/'benchmarks/performance/PERF01_WEATHER_SURFACE_REPAIR_EVIDENCE.tar.xz';idx=json.loads(p.with_suffix('.index.json').read_text());assert sha(p.read_bytes())==idx['sha256'] and p.stat().st_size==idx['bytes']
 with tarfile.open(p,'r:xz') as tar:
  assert all(m.isfile() and not m.name.startswith('/') and '..' not in Path(m.name).parts for m in tar.getmembers());files={m.name:tar.extractfile(m).read() for m in tar.getmembers()}
 result=verify(files)
 if '--self-test' in sys.argv:
  rejected=[]
  for label,key in [('missing native','native/final97/stdout'),('corrupt native','native/final-ref97/daily.csv'),('corrupt source','source/src/legacy/b1_10_port/headcalc.f90')]:
   altered=dict(files)
   if label.startswith('missing'):del altered[key]
   else:altered[key]+=b'!'
   try:verify(altered)
   except (AssertionError,KeyError):rejected.append(label)
   else:raise AssertionError('corruption accepted: '+label)
  try:verify(files,lambda p:(ROOT/p).read_bytes()+b'!')
  except AssertionError:rejected.append('current source drift')
  else:raise AssertionError('source drift accepted')
  result['negative_controls']=rejected;assert len(rejected)==4
 print(json.dumps(result))
if __name__=='__main__':main()

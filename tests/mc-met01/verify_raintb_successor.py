#!/usr/bin/env python3
from pathlib import Path
import base64,hashlib,io,json,subprocess,tarfile
ROOT=Path(__file__).resolve().parents[2]
BASE='c545077ab2d2839007a4ac202f7896575d0ad9ba'
PINS={'src/adapter/mod_swap_daily_weather_file_adapter.f90': 'cb53d90e9861bddf83b3ededf8993869cf5c8308', 'src/runtime/mod_fmr_production_application_bootstrap.f90': '2ae6e3aafe9f4987b562618443b0ccd48a133a4c'}
def git(*a):return subprocess.check_output(['git',*a],cwd=ROOT,text=True).strip()
assert git('merge-base','--is-ancestor',BASE,'HEAD')==''
assert not git('status','--porcelain','--','src','reference','tests/mc-met01','tests/fmig431','tests/frost','tests/support')
assert git('diff','--name-only',BASE,'HEAD','--','src').splitlines()==sorted(PINS)
for p,b in PINS.items():assert git('rev-parse','HEAD:'+p)==b,p
assert git('rev-parse','HEAD:reference')==git('rev-parse',BASE+':reference')
status=json.loads((ROOT/'integration/audits/MC_MET01_STATUS.json').read_text())
for key in ['focused_evidence','default_crop_evidence','fresh_frost_evidence']:
 r=status[key];raw=base64.b64decode((ROOT/r['path']).read_bytes());assert hashlib.sha256(raw).hexdigest()==r['decoded_sha256']
 with tarfile.open(fileobj=io.BytesIO(raw)) as t:
  m=json.load(t.extractfile('MANIFEST.json'));assert m['source_tree']==git('rev-parse','HEAD:src')
  for name,digest in m['member_sha256'].items():assert hashlib.sha256(t.extractfile(name).read()).hexdigest()==digest,name
  for path,blob in m['dependency_blobs'].items():assert git('rev-parse','HEAD:'+path)==blob,path
  if key=='focused_evidence':
   assert b'MC_MET01_LITERAL_RAINTB_O0_O2=PASS' in t.extractfile('source.log').read()
   assert b'MC_MET01_ACTUAL_RAINTB_PRODUCTION_O0_O2=PASS' in t.extractfile('production.log').read()
  elif key=='default_crop_evidence':
   assert b'CROP_FILE_WEATHER_PRODUCTION_O0_O2=PASS' in t.extractfile('default-crop.log').read()
  else:
   assert m['complete_configurations']==24 and m['fine_comparisons']==144
   original=base64.b64decode((ROOT/m['original_archive']).read_bytes());assert hashlib.sha256(original).hexdigest()==m['original_archive_sha256']
   with tarfile.open(fileobj=io.BytesIO(original)) as old:
    for route in ['normal','low-air']:
     for opt in [0,2]:
      a=t.extractfile(f'highest/{route}/o{opt}/output.txt').read()
      assert a==old.extractfile(f'highest/{route}/o{opt}/output.txt').read()
      assert a.count(b'_RUNTIME=PASS')==6 and a.count(b'FINE_COMPARISON')==36
print('MC_MET01_EXACT_TWO_SOURCE_AND_INDEPENDENT_FROST_EVIDENCE=PASS')

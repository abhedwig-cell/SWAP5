#!/usr/bin/env python3
"""Exact independently qualified daily-demand successor; unknown changes fail closed."""
from pathlib import Path
import base64,hashlib,io,json,subprocess,tarfile
ROOT=Path(__file__).resolve().parents[2]
BASE='bd17f0a9a7c19516e66af8f80e2b7128890b3aee'
PINS={'src/adapter/mod_swap_daily_weather_file_adapter.f90':'44b07cd1046632a38b36e9b1ed5608f67ca41fdd','src/process/mod_reference_et_demand_process.f90':'0a8fc91570c6297a54109740de3a26153dc44283','src/runtime/mod_fmr_production_application_bootstrap.f90':'8b480b09f47bb4443d755109c9093486853c0809'}
def git(*a):return subprocess.check_output(['git',*a],cwd=ROOT,text=True).strip()
assert git('merge-base','--is-ancestor',BASE,'HEAD')==''
assert not git('status','--porcelain','--','src','reference','tests/mc-met01','tests/fmig431','tests/frost','tests/support','tests/fvq/test_fvq35_reference_et_demand_oracle.f90')
assert git('diff','--name-only',BASE,'HEAD','--','src').splitlines()==sorted(PINS)
for p,b in PINS.items():assert git('rev-parse','HEAD:'+p)==b and git('hash-object',p)==b,p
assert git('rev-parse','HEAD:reference')==git('rev-parse',BASE+':reference')
# Existing reference implementation and declarations are byte retained;
# additive traditional routines cannot replace its incumbent equations.
p='src/process/mod_reference_et_demand_process.f90';old=subprocess.check_output(['git','show',BASE+':'+p],cwd=ROOT,text=True);current=(ROOT/p).read_text()
assert old.split('\ncontains\n',1)[0].rstrip()==current.split('  integer, parameter :: PM_IDENTITY_KIND',1)[0].rstrip()
assert old.split('\ncontains\n',1)[1].split('end module',1)[0].rstrip()==current.split('\ncontains\n',1)[1].split('  pure subroutine evaluate_traditional_pm_daily',1)[0].rstrip()
status=json.loads((ROOT/'integration/audits/MC_MET01_STATUS.json').read_text())['daily_demand_successor']
assert status['tested'] and status['source_postimages']==PINS
r=status['owner_evidence'];raw=base64.b64decode((ROOT/r['path']).read_bytes());assert hashlib.sha256(raw).hexdigest()==r['decoded_sha256']
with tarfile.open(fileobj=io.BytesIO(raw)) as t:
 m=json.load(t.extractfile('MANIFEST.json'));assert m['source_tree']==git('rev-parse','HEAD:src')
 for name,h in m['member_sha256'].items():assert hashlib.sha256(t.extractfile(name).read()).hexdigest()==h,name
 for p,b in m['dependency_blobs'].items():assert git('rev-parse','HEAD:'+p)==b and git('hash-object',p)==b,p
 for log,marker in [('source.log',b'MC_MET01_LITERAL_DAILY_DEMAND_O0_O2=PASS'),('reference.log',b'MC_MET01_INCUMBENT_LITERAL_REFERENCE_ET_PRESERVATION_O0_O2=PASS'),('focused.log',b'MC_MET01_ACTUAL_DAILY_DEMAND_PRODUCTION_O0_O2=PASS'),('default-crop.log',b'CROP_FILE_WEATHER_PRODUCTION_O0_O2=PASS'),('old-raintb.log',b'MC_MET01_ACTUAL_RAINTB_PRODUCTION_O0_O2=PASS')]:assert marker in t.extractfile(log).read(),log
 assert m['highest_configurations']==24 and m['fine_comparisons']==144
 old=m['unchanged_highest_output_archive'];prior=base64.b64decode((ROOT/old['path']).read_bytes());assert hashlib.sha256(prior).hexdigest()==old['decoded_sha256']
 with tarfile.open(fileobj=io.BytesIO(prior)) as oldtar:
  for route in ['normal','low-air']:
   for opt in [0,2]:
    b=t.extractfile(f'highest/{route}/o{opt}/output.txt').read();assert b==oldtar.extractfile(f'highest/{route}/o{opt}/output.txt').read()
    assert b.count(b'_RUNTIME=PASS')==6 and b.count(b'FINE_COMPARISON')==36
print('MC_MET01_EXACT_DAILY_DEMAND_SOURCE_OWNER_AND_HIGHEST_PRESERVATION=PASS')

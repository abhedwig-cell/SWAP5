#!/usr/bin/env python3
"""Exact independently qualified daily-demand successor; unknown changes fail closed."""
from pathlib import Path
import base64,hashlib,io,json,subprocess,tarfile,sys
ROOT=Path(__file__).resolve().parents[2]
if subprocess.check_output(['git','rev-parse','HEAD:src/runtime/mod_canonical_contracts.f90'],cwd=ROOT,text=True).strip()=='732cf70f9aeec59bb7dfb136ba4d6e61b918780b':
 assert sys.argv[1:] in [[],['--owner-only']]
 sys.path.insert(0,str(ROOT/'tests/modularity'))
 from verify_joint_preservation import verify_qualification
 verify_qualification() # Fresh full highest, all incumbent owner cases and coupling; missing proof rejects.
 print('MC_MET01_EXACT_JOINT_DAILY_DEMAND_OWNER_AND_HIGHEST_PREREQUISITE=PASS')
 sys.exit(0)
BASE='bd17f0a9a7c19516e66af8f80e2b7128890b3aee'
PINS={'src/adapter/mod_swap_daily_weather_file_adapter.f90':'44b07cd1046632a38b36e9b1ed5608f67ca41fdd','src/process/mod_reference_et_demand_process.f90':'0a8fc91570c6297a54109740de3a26153dc44283','src/runtime/mod_fmr_production_application_bootstrap.f90':'8b480b09f47bb4443d755109c9093486853c0809'}
def git(*a):return subprocess.check_output(['git',*a],cwd=ROOT,text=True).strip()
assert git('merge-base','--is-ancestor',BASE,'HEAD')==''
assert not git('status','--porcelain','--','src','reference','tests/mc-met01','tests/fmig431','tests/frost','tests/support','tests/fvq/test_fvq35_reference_et_demand_oracle.f90')
changed=git('diff','--name-only',BASE,'HEAD','--','src').splitlines()
bounded_repair=changed!=sorted(PINS)
fresh_owner=None
if bounded_repair:
 sys.path.insert(0,str(ROOT/'tests/modularity'))
 from backend_allocation_authority import BASE as REPAIR_BASE, BACKEND, PUBLICATION, verify_source
 from verify_backend_owner_evidence import verify_owner, verify_dependencies
 source=verify_source()
 assert changed==sorted([*PINS,*source['changed_paths']])
 fresh_owner=verify_owner() # Missing, partial, stale or corrupted proof fails closed.
else:
 assert changed==sorted(PINS)
for p,b in PINS.items():assert git('rev-parse','HEAD:'+p)==b and git('hash-object',p)==b,p
assert git('rev-parse','HEAD:reference')==git('rev-parse',BASE+':reference')
# Existing reference implementation and declarations are byte retained;
# additive traditional routines cannot replace its incumbent equations.
p='src/process/mod_reference_et_demand_process.f90';old=subprocess.check_output(['git','show',BASE+':'+p],cwd=ROOT,text=True);current=(ROOT/p).read_text()
assert old.split('\ncontains\n',1)[0].rstrip()==current.split('  integer, parameter :: PM_IDENTITY_KIND',1)[0].rstrip()
assert old.split('\ncontains\n',1)[1].split('end module',1)[0].rstrip()==current.split('\ncontains\n',1)[1].split('  pure subroutine evaluate_traditional_pm_daily',1)[0].rstrip()
assert sys.argv[1:] in [[],['--owner-only']]
owner_only=sys.argv[1:]==['--owner-only']
status=json.loads((ROOT/'integration/audits/MC_MET01_STATUS.json').read_text())['daily_demand_successor']
assert status['tested'] and status['source_postimages']==PINS
r=status['focused_evidence'] if owner_only else status['owner_evidence'];raw=base64.b64decode((ROOT/r['path']).read_bytes());assert hashlib.sha256(raw).hexdigest()==r['decoded_sha256']
with tarfile.open(fileobj=io.BytesIO(raw)) as t:
 m=json.load(t.extractfile('MANIFEST.json'))
 expected_tree=git('rev-parse',(REPAIR_BASE if bounded_repair else 'HEAD')+':src')
 assert m['source_tree']==expected_tree
 for name,h in m['member_sha256'].items():assert hashlib.sha256(t.extractfile(name).read()).hexdigest()==h,name
 if bounded_repair:
  # These exact changed inputs have fresh evidence rather than inherited PASS.
  # Publication is absent from all owner closures and has separate coupling gates.
  replacements={BACKEND,PUBLICATION,'tests/support/augment_bartholomeus_backend_sources.py',
                'tests/mc-met01/run_daily_demand_frost_successor.py',
                'tests/mc-met01/verify_daily_demand_successor.py'}
  retained={p:b for p,b in m['dependency_blobs'].items() if p not in replacements}
  verify_dependencies(retained)
  for p in replacements-{PUBLICATION}:
   assert fresh_owner['dependency_blobs'][p]==git('rev-parse','HEAD:'+p),p
 else:
  for p,b in m['dependency_blobs'].items():assert git('rev-parse','HEAD:'+p)==b and git('hash-object',p)==b,p
 for log,marker in [('source.log',b'MC_MET01_LITERAL_DAILY_DEMAND_O0_O2=PASS'),('reference.log',b'MC_MET01_INCUMBENT_LITERAL_REFERENCE_ET_PRESERVATION_O0_O2=PASS'),('focused.log',b'MC_MET01_ACTUAL_DAILY_DEMAND_PRODUCTION_O0_O2=PASS'),('default-crop.log',b'CROP_FILE_WEATHER_PRODUCTION_O0_O2=PASS'),('old-raintb.log',b'MC_MET01_ACTUAL_RAINTB_PRODUCTION_O0_O2=PASS')]:assert marker in t.extractfile(log).read(),log
 if not owner_only:
  assert m['highest_configurations']==24 and m['fine_comparisons']==144
  old=m['unchanged_highest_output_archive'];prior=base64.b64decode((ROOT/old['path']).read_bytes());assert hashlib.sha256(prior).hexdigest()==old['decoded_sha256']
  with tarfile.open(fileobj=io.BytesIO(prior)) as oldtar:
   for route in ['normal','low-air']:
    for opt in [0,2]:
     b=t.extractfile(f'highest/{route}/o{opt}/output.txt').read();assert b==oldtar.extractfile(f'highest/{route}/o{opt}/output.txt').read()
     assert b.count(b'_RUNTIME=PASS')==6 and b.count(b'FINE_COMPARISON')==36
print('MC_MET01_EXACT_DAILY_DEMAND_SOURCE_OWNER_PRESERVATION=PASS' if owner_only else 'MC_MET01_EXACT_DAILY_DEMAND_SOURCE_OWNER_AND_HIGHEST_PRESERVATION=PASS')

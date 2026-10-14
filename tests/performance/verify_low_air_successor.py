#!/usr/bin/env python3
"""Bounded exact numerical owner prerequisite, not moving F-CI/admission."""
import base64,hashlib,io,json,pathlib,subprocess,tarfile,sys
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parents[2]/"tools/performance"))
from low_air_successor_authority import ROOT,BASE,verify_source,blob,git
CAPSULE='integration/audits/evidence/LOW_AIR_10X_SUCCESSOR_20261014.tar.xz.b64'
CAPSULE_SHA='5da629e7532c3385f9e1bb73c5aded1c7921d8dc751b2e216b2cedb21c7a4ba2'

def check_complete_runs(report,read,opt):
 from verify_low_air_ab import verify
 import tempfile
 with tempfile.TemporaryDirectory(prefix='swap5-low-air-seal-')as tmp:
  folder=pathlib.Path(tmp);(folder/'RESULTS.json').write_text(json.dumps(report))
  for run in report['runs']:
   name=f"{run['round']}-{run['family']}-{run['policy']}.stdout"
   (folder/name).write_bytes(read(f'final-current-qualification/qual-o{opt}/'+name))
  result=verify(folder)
 if report['repeat']!=1 or result['trajectories']!=6 or result['fine_comparisons']!=36:raise ValueError('wrong current owning matrix')
 return result

def verify_successor():
 source=verify_source();raw=base64.b64decode((ROOT/CAPSULE).read_bytes(),validate=False)
 if hashlib.sha256(raw).hexdigest()!=CAPSULE_SHA:raise ValueError('successor capsule corruption')
 with tarfile.open(fileobj=io.BytesIO(raw))as t:
  read=lambda name:t.extractfile(name).read()
  index=json.loads(read('INDEX.json'))
  for name,h in index.items():
   if hashlib.sha256(read(name)).hexdigest()!=h:raise ValueError('member corruption '+name)
  owner=json.loads(read('OWNER.json'))
  if owner['baseline']!=BASE or owner['source_tree']!=source['source_tree']:raise ValueError('foreign numerical source')
  actual={line.split('\t')[1]:line.split()[2]for line in git('ls-tree','-r','HEAD','--','src').splitlines()}
  if owner['production_blobs']!=actual:raise ValueError('production surface drift')
  for path,h in actual.items():
   if blob((ROOT/path).read_bytes())!=h:raise ValueError('dirty production '+path)
  scientific={}
  for opt in [0,2]:
   report=json.loads(read(f'final-current-qualification/qual-o{opt}/RESULTS.json'))
   # The sealed production blob map and every compiled input bind execution.
   # Connector commit metadata can differ; local executed history is archived.
   if owner['source_tree']!=source['source_tree']:raise ValueError('executed postimage drift')
   scientific[opt]=check_complete_runs(report,read,opt)
   if read(f'final-current-qualification/build-o{opt}/mod_canonical_interval_runtime.f90')!=(ROOT/'src/runtime/mod_canonical_interval_runtime.f90').read_bytes():raise ValueError('compiled runtime provider drift')
   expected=(ROOT/'tests/frost/test_ppa_wu05b15_low_air_runtime.f90').read_text().replace('    config%transaction%retry_scale = 0.5_real64','    config%retain_accepted_step_proposal = .true.\n    config%transaction%retry_scale = 0.5_real64').replace('    cfg%numerical%transaction%retry_scale=.5_real64','    cfg%numerical%retain_accepted_step_proposal=.true.\n    cfg%numerical%transaction%retry_scale=.5_real64')
   if read(f'final-current-qualification/qual-o{opt}/candidate.f90').decode()!=expected:raise ValueError('owning driver/assertion mutation')
   for path,h in report['sources'].items():
    if '/SWAP5/src/'in path:
     relative='src/'+path.split('/SWAP5/src/',1)[1]
     if hashlib.sha256((ROOT/relative).read_bytes()).hexdigest()!=h:raise ValueError('provider source drift '+relative)
   for family in range(1,7):
    if read(f'final-current-qualification/qual-o0/0-{family}-candidate.stdout')!=read(f'final-current-qualification/qual-o2/0-{family}-candidate.stdout'):raise ValueError('O0/O2 science drift')
  contracts=json.loads(read('disabled-span-fixed/RESULTS.json'))
  if contracts['status']!='PASS' or {r['case']for r in contracts['records']}!={'low_air_policy','trajectory_exposure','trajectory_runtime'}:raise ValueError('missing current direct/F-KT owner')
  for case,marker in [('low_air_policy',b'LOW_AIR_STEP_POLICY_CONTRACT=PASS'),('trajectory_exposure',b'FKT22_DEFAULT_OFF_IDENTITY=PASS'),('trajectory_runtime',b'FKT22_FMR_SERIALIZED_RUNTIME_GATE=PASS')]:
   hashes=set()
   for opt in [0,2]:
    records=[r for r in contracts['records']if r['case']==case and r['optimization']==opt]
    if len(records)!=2:raise ValueError('missing cold/warm contract')
    for record in records:
     for path,h in record['inputs'].items():
      if hashlib.sha256((ROOT/path).read_bytes()).hexdigest()!=h:raise ValueError('contract input drift '+path)
     candidates=[read(n)for n in index if n.startswith('disabled-span-fixed/')and n.endswith('science.stdout')and hashlib.sha256(read(n)).hexdigest()==record['stdout_sha256']]
     if not candidates or marker not in candidates[0]:raise ValueError('missing executed contract output')
     hashes.add(record['stdout_sha256'])
   if len(hashes)!=1:raise ValueError('contract O0/O2 replay drift')
  driver=ROOT/owner['coupling_driver']
  if hashlib.sha256(driver.read_bytes()).hexdigest()!=owner['coupling_driver_sha256']:raise ValueError('coupling recipe drift')
  coupling=read('coupling-final.stdout')
  for opt in [0,2]:
   for name in ['multiswap_commit','single_tile_equivalence','multiswap_qualification','corrector_tile_fail_closed','permutation_determinism','multicell_isolation']:
    if coupling.count(f'FGC25_test_fgc25_{name}_O{opt}=PASS'.encode())!=1:raise ValueError('missing coupling original driver')
  if b'F-GC25 MULTISWAP GROUNDWATER COMPOSITION GATE PASS' not in coupling:raise ValueError('incomplete coupling')
  if read('canonical-owner-verified.stdout').strip()!=b'MODULAR_EXACT_REPAIRS_FRESH_OWNER_AND_COUPLING=PASS':raise ValueError('missing original-context owner proof')
 return {'source':source,'highest_programs':12,'original_fine_comparisons':72,'current_direct_and_fkt':'PASS','current_coupling':'PASS','original_context_default_owner':'VERIFIED_DISTINCT_CANONICAL_CONTEXT','scope':'Exact bounded numerical owner prerequisite only; full moving preservation and admission remain mandatory.','admitted':False}
if __name__=='__main__':print(json.dumps(verify_successor(),indent=2))

"""Compose separately admitted current physics with exact historical authority.

The original native I/O guard is unchanged and still refuses these successor
bytes directly. Current executable evidence and its historical projection have
distinct verdicts; neither confers whole scientific qualification.
"""
import argparse,hashlib,json,os,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
AREAS=['src','app','reference']
ENDPOINT_PATHS={'src/kernel/mod_kernel_transactions.f90',
 'src/runtime/mod_fmr_serialized_reference_backend.f90',
 'app/solute_project/main.f90','app/solute_project/hupsel_rotation_restart.f90'}
SCOPE='integration/dataqual15_hupsel/CANOPY_ENDPOINT_EVENT_SCOPE_20261103.json'
ENDPOINT_RECEIPT='integration/dataqual15_hupsel/CANOPY_ENDPOINT_CANONICAL_RECEIPT_20261103.json'
ROTATION_RECEIPT='integration/dataqual15_hupsel/CORRECTED_ROTATION_CANONICAL_RECEIPT_20261103.json'
NATIVE_STATUS='integration/dataqual15/STATUS.json'
REQUIRED_ASSETS={SCOPE,ENDPOINT_RECEIPT,ROTATION_RECEIPT,
 'tests/dataqual15/verify_native_restart_admission.py',
 'tests/dataqual15/test_native_restart_admission.py',
 'tests/dataqual15_hupsel/qualify_canopy_preservation.py',
 'tests/dataqual15_hupsel/verify_canopy_endpoint_evidence.py',
 'tests/dataqual15_hupsel/verify_corrected_rotation_evidence.py',
 *['integration/dataqual15_hupsel/'+name for name in (
  'CANOPY_ENDPOINT_WINDOWS_20261103.tar.json','CANOPY_ENDPOINT_POSIX_20261103.tar.json',
  'CANOPY_CURRENT_THERMAL_20261103.tar.json','CANOPY_CURRENT_NATIVE_COUPLED_20261103.tar.json',
  'CORRECTED_ROTATION_EVIDENCE_20261103.json')]}
CURRENT_GATES={'tests/dataqual15/verify_current_native_admission.py',
 'tests/dataqual15/test_current_native_admission.py'}

def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()
def blob(ref,path):return git('rev-parse',ref+':'+path)
def native_status_pin(ref=None):
 raw=subprocess.check_output(['git','show',ref+':'+NATIVE_STATUS],cwd=ROOT)if ref else (ROOT/NATIVE_STATUS).read_bytes()
 owned=json.loads(raw)['native_disk_restart_20261102']
 return hashlib.sha256(json.dumps(owned,sort_keys=True,separators=(',',':')).encode()).hexdigest()

def guard(record):
 assert record['schema']==1 and record['whole_scientific_admission']is False
 assert set(record['frozen_assets'])==REQUIRED_ASSETS,'missing or unknown frozen authority'
 assert set(record['current_gate_sha256'])==CURRENT_GATES,'missing or unknown current gate'
 assert len(record['canonical_merges'])==2
 subprocess.run(['git','merge-base','--is-ancestor',record['baseline'],'HEAD'],cwd=ROOT,check=True,capture_output=True)
 # Freeze this work unit's entire authority, not other chats' unrelated
 # research/status fields in the shared DATAQUAL15 register.
 pin=record['frozen_native_status_sha256']
 assert native_status_pin(record['baseline'])==pin,'native authority origin drift'
 assert native_status_pin('HEAD')==pin and native_status_pin()==pin,'native authority drift'
 for name,pin in record['frozen_assets'].items():
  assert blob(record['baseline'],name)==pin,'frozen origin drift: '+name
  assert blob('HEAD',name)==pin,name
  assert not git('diff','HEAD','--',name),'dirty admission asset: '+name
 for name,pin in record['current_gate_sha256'].items():
  assert hashlib.sha256((ROOT/name).read_bytes().replace(b'\r\n',b'\n')).hexdigest()==pin,name
 scope=json.loads((ROOT/SCOPE).read_text())
 assert scope['canonical_admission']and scope['physical_correction']and not scope['whole_scientific_admission']
 assert set(scope['production_delta'])==ENDPOINT_PATHS,'unexpected successor footprint'
 base=scope['predecessor']
 assert set(git('diff','--name-only','--no-renames',base,'HEAD','--',*AREAS).splitlines())==ENDPOINT_PATHS,'unreviewed production paths'
 assert not git('diff','HEAD','--',*AREAS),'uncommitted production source'
 assert not git('ls-files','--others','--exclude-standard','--',*AREAS),'untracked production source'
 for name,pins in scope['production_delta'].items():
  assert blob(base,name)==pins['before']and blob('HEAD',name)==pins['after'],name
 assert {area:blob(base,area)for area in AREAS}==scope['predecessor_production_trees']
 endpoint=json.loads((ROOT/ENDPOINT_RECEIPT).read_text())
 rotation=json.loads((ROOT/ROTATION_RECEIPT).read_text())
 assert not endpoint['whole_scientific_admission']and not rotation['whole_scientific_admission']
 assert endpoint['merge']==scope['canonical_merge']==record['canonical_merges'][0]
 assert rotation['merge']==record['canonical_merges'][1]
 for merge in record['canonical_merges']:
  subprocess.run(['git','merge-base','--is-ancestor',merge,'HEAD'],cwd=ROOT,check=True,capture_output=True)
 return scope

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
 out=a.output.resolve()
 if json.loads((ROOT/NATIVE_STATUS).read_text()).get('matrix_thermal_native_successor_20261106'):
  subprocess.run([sys.executable,'-B',str(ROOT/'tests/dataqual15_hupsel/matrix_thermal_production.py'),'--output',str(out)],cwd=ROOT,check=True)
  return
 if json.loads((ROOT/NATIVE_STATUS).read_text()).get('portable_generation_publication_successor_20261106'):
  subprocess.run([sys.executable,'-B',str(ROOT/'tests/dataqual15_hupsel/generation_publication_admission.py'),'--output',str(out)],cwd=ROOT,check=True)
  return
 if json.loads((ROOT/NATIVE_STATUS).read_text()).get('generation_native_crc_successor_20261105'):
  subprocess.run([sys.executable,'-B',str(ROOT/'tests/dataqual15_hupsel/generation_crc_admission.py'),'--output',str(out)],cwd=ROOT,check=True)
  return
 if json.loads((ROOT/NATIVE_STATUS).read_text()).get('matrix_native_crc_successor_20261105'):
  subprocess.run([sys.executable,'-B',str(ROOT/'tests/dataqual15_hupsel/matrix_crc_admission.py'),'--output',str(out)],cwd=ROOT,check=True)
  return
 if json.loads((ROOT/NATIVE_STATUS).read_text()).get('native_n_crc_successor_20261105'):
  subprocess.run([sys.executable,'-B',str(ROOT/'tests/dataqual15_hupsel/native_n_production.py'),'--output',str(out)],cwd=ROOT,check=True)
  return
 if json.loads((ROOT/NATIVE_STATUS).read_text()).get('root_numerical_accuracy_successor_20261105'):
  subprocess.run([sys.executable,'-B',str(ROOT/'tests/dataqual15_hupsel/root_accuracy_production.py'),'--output',str(out)],cwd=ROOT,check=True)
  return
 if json.loads((ROOT/NATIVE_STATUS).read_text()).get('registered_thermal_profile_successor_20261105'):
  subprocess.run([sys.executable,'-B',str(ROOT/'tests/dataqual15/thermal_profile_production.py'),'--output',str(out)],cwd=ROOT,check=True)
  return
 if json.loads((ROOT/NATIVE_STATUS).read_text()).get('native_rotation_crc_successor_20261105'):
  subprocess.run([sys.executable,'-B',str(ROOT/'tests/dataqual15_hupsel/rotation_native_admission.py'),'--output',str(out)],cwd=ROOT,check=True)
  return
 if json.loads((ROOT/NATIVE_STATUS).read_text()).get('native_crop_logical_successor_20261105'):
  subprocess.run([sys.executable,'-B',str(ROOT/'tests/dataqual15_hupsel/production_crop_logical_admission.py'),'--output',str(out)],cwd=ROOT,check=True)
  return
 if json.loads((ROOT/NATIVE_STATUS).read_text()).get('project_diagnostic_restart_successor_20261104'):
  # Fixed reviewed current route; the exact old entrypoint is retained in
  # the committed predecessor view, with every old assertion unchanged.
  subprocess.run([sys.executable,'-B',str(ROOT/'tests/dataqual15_hupsel/production_diagnostic_admission.py'),
                  '--output',str(out)],cwd=ROOT,check=True)
  return
 out.mkdir(parents=True,exist_ok=False)
 record=json.loads((ROOT/'integration/dataqual15_hupsel/CURRENT_NATIVE_ADMISSION_20261103.json').read_text())
 guard(record);events=[]
 def run(label,args):
  command=[sys.executable,'-B',*args]
  # Match the repository/CI UTF8 text contract while keeping every frozen
  # validator byte and assertion intact, including nested historical calls.
  cp=subprocess.run(command,cwd=ROOT,capture_output=True,env=dict(os.environ,PYTHONUTF8='1'))
  (out/(label+'.stdout')).write_bytes(cp.stdout);(out/(label+'.stderr')).write_bytes(cp.stderr)
  events.append(dict(label=label,command=command,returncode=cp.returncode))
  (out/'EVENTS.json').write_text(json.dumps(events,indent=2)+'\n')
  assert cp.returncode==0,(label,cp.stderr.decode(errors='replace')[-3000:])
 # This is actual current full diagnostic data, not a source-only exception.
 run('current-corrected-rotation',['tests/dataqual15_hupsel/verify_corrected_rotation_evidence.py'])
 # This existing gate checks actual current endpoint/shared-runtime evidence,
 # restores exactly the four previous production postimages in a separate Git
 # view, then runs the UNMODIFIED original guard, ten controls and seven legs.
 run('current-endpoint-and-exact-history',['tests/dataqual15_hupsel/qualify_canopy_preservation.py','--output',str(out/'composition')])
 guard(record)
 result=dict(status='CURRENT_ACCEPTED_ENDPOINT_AND_EXACT_HISTORICAL_NATIVE_AUTHORITY_PASS',
             candidate=git('rev-parse','HEAD'),events=events,
             historical_projection=json.loads((out/'composition/RESULT.json').read_text())['projection'],
             historical_scope='Exact predecessor science and I/O only; not current endpoint execution',
             current_scope='Separately admitted endpoint/shared runtime and corrected diagnostic1096 evidence',
             full_current_literal1827_execution=False,whole_scientific_admission=False)
 (out/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n');print(result['status'])

if __name__=='__main__':main()

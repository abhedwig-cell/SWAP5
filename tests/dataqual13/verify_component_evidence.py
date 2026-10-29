"""Verify persisted real-model, component and preservation evidence and its scope."""
import hashlib,io,json,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];sha=lambda b:hashlib.sha256(b).hexdigest()
def verify():
 s=json.loads((ROOT/'integration/dataqual13/STATUS.json').read_bytes())
 assert s['model_execution']['swap5_original_grassgrowth_days']>=5
 for p,h in s['source_sha256'].items():assert sha((ROOT/p).read_bytes())==h,p
 raw=(ROOT/'integration/dataqual13/EVIDENCE.tar.xz').read_bytes();assert sha(raw)==s['evidence_sha256']
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz') as t:
  members=t.getmembers();assert len(members)==len({m.name for m in members})
  assert all(m.isfile() and not Path(m.name).is_absolute() and '..' not in Path(m.name).parts for m in members)
  files={m.name:t.extractfile(m).read() for m in members}
 assert json.loads(files.pop('MANIFEST.json'))=={p:sha(b) for p,b in files.items()}
 def bound_source(p,h):
  marker='/SWAP5/'
  if marker in p:assert sha((ROOT/p.split(marker,1)[1]).read_bytes())==h,p
  else:assert h in {sha(b) for b in files.values()},p
 def result(folder):return json.loads(files['components/'+folder+'/RESULT.json'])
 for opt in ['O0','O2']:
  assert b'PRESCRIBED_GROUNDWATER_DIRECT_PASS' in files['components/dq13-groundwater-e/'+opt+'/stdout']
  r=result('dq13-grass-water-'+opt)
  assert r['status']=='BOUNDED_ORIGINAL_GRASS_WATER_AND_DISK_RESTART_PASS'
  assert r['days']==5 and r['restart_payload_exact'] and r['rejected_restart_controls']==5
  assert r['maximum_water_residual_cm']<1e-10 and r['maximum_heat_accounting_residual_j_cm2']<1e-8
  assert not r['complete_project_migration']
  for p,h in r['source_sha256'].items():bound_source(p,h)
  assert max(abs(x['water_difference_cm']) for x in r['reference_comparison'])<0.01
  assert max(abs(x['potential_transpiration_difference_cm']) for x in r['reference_comparison'])<1e-11
  base='components/dq13-grass-qualification-'+opt+'/'
  assert files[base+'full/checkpoint.bin']==files[base+'suffix/checkpoint.bin']
  assert files[base+'full/state.csv']==files[base+'suffix/state.csv']
 for name in ['state.csv','endpoint.csv','budget.csv']:
  assert files['components/dq13-grass-water-O0/full/'+name]==files['components/dq13-grass-water-O2/full/'+name]
 for folder in ['dq13-root-oxygen-density-final','dq13-oxygen-respiration-final','dq13-grass-solar-qualified','dq13-duration-interception-final']:
  assert 'PASS' in result(folder)['status']
 r=result('dq13-runtime-preservation-final');assert r['status']=='CURRENT_REFERENCE_GROUNDWATER_DEFAULT_AND_OXYGEN_PASS'
 assert len([e for e in r['events'] if e['label']=='native_existing_contract'])==6
 assert all(e['returncode']==0 for e in r['events'])
 for p,h in r['source_sha256'].items():bound_source(p,h)
 m=json.loads((ROOT/'integration/dataqual12/MIGRATION_MATRIX.json').read_text())
 assert m['denominator']['independent_original_projects']==3 and m['denominator']['complete_project_migrations']==0
 assert m['denominator']['projects_with_current_bounded_water_evidence']==3
 return {'source_bound_evidence':'PASS','original_Grassgrowth_water_qualified_days':5,'original_Grassgrowth_executed_days':s['model_execution']['swap5_original_grassgrowth_days'],'complete_original_migrations':'0/3'}
if __name__=='__main__':print(json.dumps(verify()))

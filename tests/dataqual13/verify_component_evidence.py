"""Read persisted component evidence; never promote it to original-project proof."""
import hashlib,io,json,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];sha=lambda b:hashlib.sha256(b).hexdigest()
def verify():
 s=json.loads((ROOT/'integration/dataqual13/STATUS.json').read_bytes())
 assert not s['canonical_admitted']and s['model_execution']['swap5_original_grassgrowth_days']==0
 for p,h in s['source_sha256'].items():assert sha((ROOT/p).read_bytes())==h,p
 raw=(ROOT/'integration/dataqual13/EVIDENCE.tar.xz').read_bytes();assert sha(raw)==s['evidence_sha256']
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz')as t:
  members=t.getmembers();assert len(members)==len({m.name for m in members})
  assert all(m.isfile()and not Path(m.name).is_absolute()and'..'not in Path(m.name).parts for m in members)
  files={m.name:t.extractfile(m).read()for m in members}
 assert json.loads(files.pop('MANIFEST.json'))=={p:sha(b)for p,b in files.items()}
 for opt in ['O0','O2']:
  assert b'PRESCRIBED_GROUNDWATER_DIRECT_PASS'in files['components/dq13-groundwater-e/'+opt+'/stdout']
  for name in ['groundwater','default']:
   output=files['components/dq13-groundwater-owner-checks/'+opt+'-'+name+'.stdout']
   assert (b'GROUNDWATER_FMR_TRANSACTION_PASS'if name=='groundwater'else b'PPA-WU01 PRODUCTION APPLICATION BOOTSTRAP GATE PASS')in output
  output=files['components/dq13-grass-growth-d/'+opt+'/stdout'];assert b'ORIGINAL_GRASS_BIOMASS_CANDIDATE_PASS'in output
  assert output.count(b'GRASS_BODY')==4
  for name in ['test_swap431_potential_shadow_daily','test_wofost81_one_day_candidate_integration','test_wofost81_leaf_structural_evolution']:
   assert b'PASS'in files['components/dq13-crop-preservation/'+opt+'/'+name+'.stdout']
  output=files['components/dq13-grass-profile-source/'+opt+'/stdout'];assert b'ORIGINAL_GRASS_PROFILE_IMPORTED'in output
  assert b'-88.'in output and b'217.01743631333005'in output
 a='components/dq13-groundwater-owner-checks/'
 assert files[a+'O0-groundwater.stdout']==files[a+'O2-groundwater.stdout']
 assert s['additional_qualification']['grass_biomass']['maximum_biomass_and_development_difference']==0
 return {'component_evidence':'PASS','original_Grassgrowth_days':0,'canonical_admitted':False}
if __name__=='__main__':print(json.dumps(verify()))

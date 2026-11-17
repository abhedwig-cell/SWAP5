"""Verify sealed bytes, all committed daily guards and full own-window receipts."""
from pathlib import Path
import argparse,hashlib,json,zipfile

def main():
 p=argparse.ArgumentParser();p.add_argument('package',type=Path);a=p.parse_args();root=a.package
 sha=lambda b:hashlib.sha256(b).hexdigest();seal=json.loads((root/'SEAL.json').read_text());raw=(root/'FILES.json').read_bytes();assert sha(raw)==seal['files_index_sha256'];idx=json.loads(raw);opened={}
 for n,v in seal['archives'].items():
  assert sha((root/n).read_bytes())==v['sha256'];opened[n]=zipfile.ZipFile(root/n)
 for digest,v in idx['assets'].items():assert sha(opened[v['archive']].read(v['member']))==digest
 def read(n):
  f=idx['files'][n];v=idx['assets'][f['sha256']];data=opened[v['archive']].read(v['member']);assert len(data)==f['bytes'];return data
 result=dict(status='SEALED_RAW_FULL_DAYS_AND_OWN_RECEIPTS_VERIFIED',fulls=0,days=0,full_own_windows=0,profiles={},science='NOT_QUALIFIED',heat_observer_exactness='OPEN',tolerances_changed=False)
 for platform,prefix in [('windows','windows/'),('ubuntu','ubuntu/wetting/')]:
  report=json.loads(read(prefix+'RESULT.json'))
  for key,profiles in report['cases'].items():
   for opt,v in profiles.items():
    rows=[json.loads(s) for s in read(prefix+key+'-'+opt+'-full/daily.jsonl').decode().splitlines()];assert [r['day'] for r in rows]==list(range(1,1097))
    for r in rows:
     assert r['committed'] and abs(r['independent_residual_cm'])<=1e-10 and abs(r['kernel_residual_cm'])<=1e-10
     assert abs(r.get('solute_independent_residual_mg_cm2',0))<=1e-10
    own=v['full']['own'];assert len(own)==8
    assert all(all(w[k] is True for k in ['exact_physical','exact_csv','exact_native','origin_unchanged']) for w in own)
    result['fulls']+=1;result['days']+=len(rows);result['full_own_windows']+=len(own)
    result['profiles'][platform+'/'+key+'/'+opt]=dict(days=len(rows),max_water_cm=max(abs(r['independent_residual_cm']) for r in rows),max_solute_mg_cm2=max(abs(r.get('solute_independent_residual_mg_cm2',0)) for r in rows))
 assert (result['fulls'],result['days'],result['full_own_windows'])==(8,8768,64)
 heat_profiles=0
 for prefix in ['windows/','ubuntu/wetting/']:
  if prefix+'HEAT.json' not in idx['files']:continue
  heat=json.loads(read(prefix+'HEAT.json'));assert not heat['full_energy_balance_complete'] and heat['energy_budget_j_cm2']==1e-9
  for v in heat['profiles'].values():
   assert v['physical_daily_exact'] and v['accepted_days']==1096 and not v['full_energy_balance_complete']
   assert v['maximum_cell_residual_j_cm2']<=1e-9 and v['maximum_global_step_residual_j_cm2']<=1e-9
   heat_profiles+=1
 if heat_profiles:
  assert heat_profiles==8;result['heat_observer_exactness']='EIGHT_FULL_NUMERICAL_CONDUCTION_PROFILES_EXACT';result['heat_profiles']=heat_profiles
 (root/'VERIFIED.json').write_text(json.dumps(result,indent=2));print(json.dumps({k:v for k,v in result.items() if k!='profiles'}))
if __name__=='__main__':main()

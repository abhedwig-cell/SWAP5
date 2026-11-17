"""Reread actual merged-source/native/heat evidence and its immutable parent."""
from pathlib import Path
import argparse,hashlib,io,json,zipfile
sha=lambda b:hashlib.sha256(b).hexdigest()
def package(root):
 seal=json.loads((root/'SEAL.json').read_bytes());raw=(root/'FILES.json').read_bytes();assert sha(raw)==seal['files_index_sha256'];idx=json.loads(raw);opened={}
 for n,v in seal['archives'].items():assert sha((root/n).read_bytes())==v['sha256'];opened[n]=zipfile.ZipFile(root/n)
 def read(name):
  m=idx['files'][name];a=idx['assets'][m['sha256']];data=opened[a['archive']].read(a['member']);assert sha(data)==m['sha256'];return data
 return read
def rows(read,name):return [json.loads(s) for s in read(name+'/daily.jsonl').decode().splitlines()]
def physical(data):return [{k:v for k,v in r.items() if k not in ('column','revision')} for r in data]
def csv_records(data):return [s for s in data.decode('cp1252').splitlines() if s.strip() and not s.startswith('*')]
def native(read,name):
 with zipfile.ZipFile(io.BytesIO(read(name))) as z:return tuple(z.read(n) for n in ('result.end','macro.bin'))
def main():
 p=argparse.ArgumentParser();p.add_argument('root',type=Path);a=p.parse_args();root=a.root;read=package(root);old=package(root.parent/'closure');report={'status':'REVIEW_POSTIMAGE_PHYSICAL_DEPENDENCIES_AND_FRESH_AFFECTED_COHORT_VERIFIED','tolerances_changed':False,'water_full_profiles_inherited':4,'chemical_full_profiles_fresh':0,'chemical_own_windows_fresh':0,'water_prefix_own_windows_fresh':0,'chemical_heat_profiles_fresh':0,'compile_link_seconds':'UNKNOWN; exact commands retained','profiles':{}}
 for platform,prefix,parent in [('windows','windows/','windows/'),('ubuntu','ubuntu/','ubuntu/wetting/')]:
  meta=json.loads(read(prefix+'RESULT.json'));assert meta['status']=='MERGE_POSTIMAGE_ALL_SELECTED_PHYSICAL_NATIVE_PASS';heat=json.loads(read(prefix+'HEAT.json'));assert not heat['full_energy_balance_complete']
  for name,v in meta['profiles'].items():
   iswater=name.startswith('water-');folder=prefix+name+('-prefix365' if iswater else '-full');data=rows(read,folder);prior=rows(old,parent+name+'-full');expected_days=365 if iswater else 1096;assert [r['day'] for r in data]==list(range(1,expected_days+1));assert physical(data)==physical(prior[:expected_days]);assert all(r['committed'] and abs(r['independent_residual_cm'])<=1e-10 and abs(r['kernel_residual_cm'])<=1e-10 and abs(r.get('solute_independent_residual_mg_cm2',0))<=1e-10 for r in data)
   for n,digest in v['generated_sources'].items():
    body=read(prefix+name+'-build/'+n);assert sha(body)==digest
    if iswater:assert body==old(parent+name+'-build/'+n)
   fresh=json.loads(read(prefix+name+'-build/BUILD.json'));previous=json.loads(old(parent+name+'-build/BUILD.json'));assert fresh['inputs']==previous['inputs'];assert all(fresh['identity'].get(k)==previous['identity'].get(k) for k in v['closure_fields_exact'])
   if iswater:
    assert not v['source_delta'];assert native(read,folder+'/accepted-column-1-day-365.zip')==native(old,parent+name+'-full/accepted-column-1-day-365.zip')
   else:
    assert set(v['source_delta'])=={'irrigation.f90','solute.f90','mod_subsurface_solute_source.f90'};assert csv_records(read(folder+'/original/result_output.csv'))==csv_records(old(parent+name+'-full/original/result_output.csv'));report['chemical_full_profiles_fresh']+=1
    h=heat['profiles'][name];assert h['physical_daily_exact'] and h['accepted_days']==1096 and h['maximum_cell_residual_j_cm2']<=1e-9 and h['maximum_global_step_residual_j_cm2']<=1e-9;assert physical(rows(read,prefix+name+'-heat2'))==physical(data);report['chemical_heat_profiles_fresh']+=1
   for own in v['coverage']['own']:
    s,e=own['start'],own['end'];cold=prefix+name+'-own'+str(s);assert all(own[k] for k in ['exact_physical','exact_csv','exact_native','origin_unchanged']);assert physical(rows(read,cold))==physical(data[s:e]);assert native(read,cold+'/accepted-column-1-day-'+str(e)+'.zip')==native(read,folder+'/accepted-column-1-day-'+str(e)+'.zip')
    if iswater:report['water_prefix_own_windows_fresh']+=1
    else:
     assert native(read,folder+'/accepted-column-1-day-'+str(e)+'.zip')==native(old,parent+name+'-full/accepted-column-1-day-'+str(e)+'.zip');report['chemical_own_windows_fresh']+=1
   report['profiles'][platform+'/'+name]={'days_fresh':len(data),'model_seconds':v['coverage']['model_seconds'],'physical_exact_to_parent':True};assert v['coverage']['model_seconds']<=30
  for opt in ('O0','O2'):
   water=rows(read,prefix+'water-surface-history-'+opt+'-prefix365');chemical=rows(read,prefix+'chemical-surface-history-'+opt+'-full')[:365];assert all(x['groundwater_cm']==y['groundwater_cm'] and x['pressure_head_cm']==y['pressure_head_cm'] for x,y in zip(water,chemical))
 assert (report['chemical_full_profiles_fresh'],report['chemical_own_windows_fresh'],report['water_prefix_own_windows_fresh'],report['chemical_heat_profiles_fresh'])==(4,32,8,4)
 (root/'VERIFIED.json').write_bytes(json.dumps(report,indent=2).encode());print(json.dumps(report,indent=2))
if __name__=='__main__':main()

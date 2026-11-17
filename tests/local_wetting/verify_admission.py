"""Verify actual admission rows/source/native payloads against sealed parents."""
from pathlib import Path
import argparse,json
from verify_review import package,rows,physical,native

def main():
 p=argparse.ArgumentParser();p.add_argument('root',type=Path);a=p.parse_args();root=a.root;read=package(root);old=package(root.parent/'review')
 report=dict(status='SELECTED_ADMISSION_VERIFIED',tolerances_changed=False,science='ORIGINAL_FULL_FAIL_PRESERVED',profiles={},prefix_days=0,exact_own_windows=0)
 for platform in ('windows','ubuntu'):
  prefix=platform+'/';result=json.loads(read(prefix+'RESULT.json'));assert result['status']=='SELECTED_CANONICAL_COMPOSITION_PASS'
  assert result['tolerances_changed'] is False and result['original_full_science']=='FAIL_PRESERVED'
  for name,v in result['profiles'].items():
   build=prefix+name+'-build/';fresh=json.loads(read(build+'BUILD.json'));prior=json.loads(old(build+'BUILD.json'));assert fresh['inputs']==prior['inputs']
   changed=sorted(k for k in set(fresh['identity'])|set(prior['identity']) if fresh['identity'].get(k)!=prior['identity'].get(k))
   assert changed==v['changed_identity_fields'];assert set(changed)<= {'host','experimental_input_adapter','restart_publisher'}
   assert 'conserved_aquifer_solute' not in fresh['identity'] and v['aquifer_enabled'] is False
   for source in v['generated_sources']:assert read(build+source)==old(build+source)
   folder=prefix+name+'-prefix365';parent=prefix+name+('-prefix365' if name.startswith('water-') else '-full');data=rows(read,folder)
   assert [r['day'] for r in data]==list(range(1,366));assert physical(data)==physical(rows(old,parent)[:365])
   assert all(r['committed'] and abs(r['independent_residual_cm'])<=1e-10 and abs(r['kernel_residual_cm'])<=1e-10 and abs(r.get('solute_independent_residual_mg_cm2',0))<=1e-10 for r in data)
   for day in (6,365):assert native(read,folder+'/accepted-column-1-day-'+str(day)+'.zip')==native(old,parent+'/accepted-column-1-day-'+str(day)+'.zip')
   for window in v['coverage']['own']:
    s,e=window['start'],window['end'];cold=prefix+name+'-own'+str(s);assert physical(rows(read,cold))==physical(data[s:e]);assert native(read,cold+'/accepted-column-1-day-'+str(e)+'.zip')==native(read,folder+'/accepted-column-1-day-'+str(e)+'.zip')
    assert all(window[k] for k in ('exact_physical','exact_csv','exact_native','origin_unchanged'));report['exact_own_windows']+=1
   report['prefix_days']+=len(data);assert v['coverage']['model_seconds']<=30
   report['profiles'][platform+'/'+name]=dict(model_seconds=v['coverage']['model_seconds'],build_seconds=v['build_seconds'],budgets=v['coverage']['budgets'],physical_source_exact=True)
 assert report['prefix_days']==2920 and report['exact_own_windows']==24
 (root/'VERIFIED.json').write_bytes(json.dumps(report,indent=2).encode());print(json.dumps(report,indent=2))
if __name__=='__main__':main()

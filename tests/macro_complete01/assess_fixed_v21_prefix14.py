"""Read-only fixed-V21 prefix, literal own suffix and context equivalence."""
from pathlib import Path
import json,zipfile,hashlib,math
R=Path('integration/macro-complete01');res=json.loads((R/'RESOURCE_PATHS.json').read_text());results=[];hashes={}
for opt in ['O0','O2']:
 b=Path(res[opt]['path']);rows=[];build=None
 for day in range(1,15):
  label='UPPERCOMPLETE_V21_FIXED_COLD2' if day<=2 else 'UPPERCOMPLETE_V21_FIXED_DAY'+str(day) if day<=12 else 'UPPERCOMPLETE_V21_FIXED_OWN12TO14'
  q=json.loads((b/label/'RESULT.json').read_text());assert q['status'] in ['FRESH_WINDOW_COMPLETE','OWN_RESTART_WINDOW_COMPLETE'] and q['elapsed_seconds']<20
  if build is None:build=q['build']
  else:assert q['build']==build
  x=next(x for x in q['rows'] if x['day']==day);assert x['committed'] and abs(x['independent_residual_cm'])<=1e-6
  if rows:assert rows[-1]['stock_end_cm']==x['stock_start_cm']
  rows.append(x)
  with zipfile.ZipFile(b/label/('accepted-column-1-day-'+str(day)+'.zip')) as z:
   for name in ['macro.bin','result.end']:
    v=hashlib.sha256(z.read(name)).hexdigest();key=str(day)+'_'+name
    if opt=='O0':hashes[key]=v
    else:assert hashes[key]==v
 z12=[zipfile.ZipFile(b/l/'accepted-column-1-day-12.zip') for l in ['UPPERCOMPLETE_V21_FIXED_DAY12','UPPERIN_V20_DAY12']]
 for name in ['macro.bin','result.end']:assert z12[0].read(name)==z12[1].read(name)
 assert json.loads(z12[0].read('checkpoint.json'))['receipt']==json.loads(z12[1].read('checkpoint.json'))['receipt']
 for day in [13,14]:
  labels=['UPPERCOMPLETE_V21_FIXED_OWN12TO14','UPPERCOMPLETE_V21_CONTEXT12TO14',('UPPERCOMPLETE_V21_CONTEXT12TO13' if day==13 else 'UPPERCOMPLETE_V21_OWN13TO14')]
  zz=[zipfile.ZipFile(b/l/('accepted-column-1-day-'+str(day)+'.zip')) for l in labels]
  for name in ['macro.bin','result.end']:assert all(z.read(name)==zz[0].read(name) for z in zz)
 residual=math.fsum([*rows[0]['stock_start_cm'],*(-v for v in rows[-1]['stock_end_cm']),*(v for x in rows for v in x['external_flux_cm'][:7]),*(-v for x in rows for v in x['external_flux_cm'][7:])]);assert abs(residual)<=14e-6
 results.append(dict(opt=opt,executed_fixed_candidate_original_days=14,max_day_inventory_error_cm=max(abs(x['independent_residual_cm']) for x in rows),complete_origin_to_day14_inventory_error_cm=residual,literal_target_own_source_binding_all_days=True,day12_context_native_and_receipt_exact=True,day13_14_context_split_and_literal_own_native_exact=True))
out=dict(scope='Actual fixedV21 original14days with normal source-bound native starts; no inherited prefix counted. Verified diagnosticcontext against literal own replay. Native all14days O0/O2exact; original1e-6cm dayguard unchanged. Not full481day or independent scenario qualification.',results=results,all_native_hashes=hashes,models_launched=0)
(R/'BLOCK22_FIXED_PREFIX14_QUALIFICATION.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps({k:v for k,v in out.items() if k!='all_native_hashes'}))

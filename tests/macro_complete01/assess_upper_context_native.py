from pathlib import Path
import json,zipfile,hashlib,sys,math
ROOT=Path(__file__).resolve().parents[2];R=ROOT/'integration/macro-complete01';res=json.loads((R/'RESOURCE_PATHS.json').read_text());sys.path[:0]=[str(ROOT/'app/hybrid_water'),str(ROOT/'tests/macro_complete01')]
import daily_host as h
from run_jacobian_context_window import compatible
results=[];states={}
for opt in ['O0','O2']:
 b=Path(res[opt]['path']);target=b/'worker-coupled-upper-complete-v21';parent=b/'worker-coupled-upper-inflow-v20';ref=Path(res['O2']['path'])/'original-worker-reference'
 tm,case,pm,proof=compatible(target,parent,ref)
 # Production still refuses an old source package under the target binding.
 old=b/'UPPERIN_V20_DAY12/accepted-column-1-day-12.zip'
 try:h.verify_checkpoint(old,12,tm['binding'],b/'SHOULD_NOT_BE_CREATED_FOREIGN_BINDING')
 except ValueError:strict=True
 else:raise AssertionError('Production source binding weakened')
 try:compatible(target,b/'worker-coupled-local-darcy-v16',ref)
 except ValueError as e:foreign=str(e)
 else:raise AssertionError('Other source-owner differences admitted')
 z=[zipfile.ZipFile(b/l/'accepted-column-1-day-14.zip') for l in ['UPPERCOMPLETE_V21_OWN13TO14','UPPERCOMPLETE_V21_CONTEXT12TO14']]
 for n in ['macro.bin','result.end']:
  assert z[0].read(n)==z[1].read(n)
  digest=hashlib.sha256(z[0].read(n)).hexdigest()
  if opt=='O0':states[n]=digest
  else:assert states[n]==digest
 r13=json.loads((b/'UPPERCOMPLETE_V21_CONTEXT12TO13/RESULT.json').read_text());r14=json.loads((b/'UPPERCOMPLETE_V21_OWN13TO14/RESULT.json').read_text());assert r13['status']=='COMPATIBLE_JACOBIAN_CONTEXT_WINDOW_COMPLETE' and not r13['fixed_target_own_prefix_qualified'];assert r14['status']=='OWN_RESTART_WINDOW_COMPLETE';assert r13['rows'][0]['stock_end_cm']==r14['rows'][0]['stock_start_cm']
 for r in [r13,r14]:assert r['elapsed_seconds']<20 and all(abs(x['independent_residual_cm'])<=1e-6 for x in r['rows'])
 results.append(dict(opt=opt,frozen_original_context_day13_complete=True,actual_target_own_restart13to14_complete=True,split_and_continuous_native14_exact=True,day13_inventory_error_cm=r13['rows'][0]['independent_residual_cm'],day14_inventory_error_cm=r14['rows'][0]['independent_residual_cm'],production_foreign_source_guard_still_refuses=strict,other_physical_source_delta_refused=foreign,target_own_prefix1to12_not_yet_run=True))
out=dict(results=results,native14=states,models_launched=0,scope='Verified compatible frozen original12 context, target freshday13 and own native14 versus continuous suffix; does not promote inheritedprefix to fixedV21 qualification')
(R/'BLOCK21_CONTEXT_NATIVE_QUALIFICATION.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(out))

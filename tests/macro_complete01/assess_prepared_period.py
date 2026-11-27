"""Continuous original physical V27 trajectory, prepared-publication-only continuation."""
from pathlib import Path
import sys,json,zipfile,math,hashlib
ROOT=Path(__file__).resolve().parents[2];R=ROOT/'integration/macro-complete01';res=json.loads((R/'RESOURCE_PATHS.json').read_text());end=int(sys.argv[1]);reports=[];native={}
def label(day):
 if day<=2:return 'ORDINARY_V27_FIXED_COLD2'
 if day<=26:return 'ORDINARY_V27_FIXED_DAY'+str(day)
 if day==27:return 'PREPARED_V31_CONTEXT26TO27'
 if day==28:return 'PREPARED_V31_OWN27TO28'
 return 'PREPARED_V31_DAY'+str(day)
for opt in ['O0','O2']:
 b=Path(res[opt]['path']);rows=[];times=[];v27=None;v31=None
 for day in range(1,end+1):
  p=b/label(day);q=json.loads((p/'RESULT.json').read_text());assert q['status'] in ['FRESH_WINDOW_COMPLETE','OWN_RESTART_WINDOW_COMPLETE','PREPARED_PUBLICATION_CONTEXT_WINDOW_COMPLETE'];assert q['elapsed_seconds']<20
  if day<=26:
   if v27 is None:v27=q['build']
   else:assert v27==q['build']
  else:
   if v31 is None:v31=q['build']
   else:assert v31==q['build']
  x=next(x for x in q['rows'] if x['day']==day);assert x['committed'] and abs(x['independent_residual_cm'])<=1e-6
  if rows:assert rows[-1]['stock_end_cm']==x['stock_start_cm']
  rows.append(x);times.append(q['elapsed_seconds'])
  with zipfile.ZipFile(p/f'accepted-column-1-day-{day}.zip') as z:
   for name in ['macro.bin','result.end']:
    digest=hashlib.sha256(z.read(name)).hexdigest();key=f'{day}/{name}'
    if opt=='O0':native[key]=digest
    else:assert native[key]==digest
 assert v27['identity']['donor_generated']==v31['identity']['donor_generated']
 assert v27['identity']['coupled_macro']['owner_objects_sha256']==v31['identity']['coupled_macro']['owner_objects_sha256']
 assert v27['executable_sha256']['kernel']==v31['executable_sha256']['kernel']
 bal=math.fsum([*rows[0]['stock_start_cm'],*(-v for v in rows[-1]['stock_end_cm']),*(v for x in rows for v in x['external_flux_cm'][:7]),*(-v for x in rows for v in x['external_flux_cm'][7:])]);assert abs(bal)<=end*1e-6
 reports.append(dict(opt=opt,original_days=end,physical_sources_and_owner_objects_unchanged_all_days=True,preparedpublication_from_day27=True,ownV31_initial_prefix_executed=False,full_period_inventory_error_cm=bal,max_day_inventory_error_cm=max(abs(x['independent_residual_cm']) for x in rows),max_model_route_seconds=max(times),last_day_receipt=rows[-1]))
out=dict(scope='Continuous originaltrajectory: actuallyexecuted fixedV27physicalprefix26 plus exactphysicalruntime-onlypreparedpublisher continuation. Originaldayguardunchanged, nativeeachdayO0/O2exact. Not full481days or science/admissionqualification.',results=reports,native_sha256=native,models_launched=0)
(R/f'BLOCK32_ORIGINAL_PREFIX{end}_QUALIFICATION.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps({**out,'native_sha256':'retained in report','results':[{k:v for k,v in x.items() if k!='last_day_receipt'} for x in reports]}))

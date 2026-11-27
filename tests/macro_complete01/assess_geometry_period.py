from pathlib import Path
import json,sys,zipfile,hashlib,math
ROOT=Path(__file__).resolve().parents[2];R=ROOT/'integration/macro-complete01';res=json.loads((R/'RESOURCE_PATHS.json').read_text());end=int(sys.argv[1]);reports=[];hashes={}
for opt in ['O0','O2']:
 b=Path(res[opt]['path']);rows=[];build=None;times=[]
 for day in range(42,end+1):
  label='GEOMETRY_V33_CONTEXT41TO42' if day==42 else 'GEOMETRY_V33_OWN42TO43' if day==43 else 'GEOMETRY_V33_DAY'+str(day);p=b/label;q=json.loads((p/'RESULT.json').read_text())
  assert q['status'] in ['COMPATIBLE_JACOBIAN_CONTEXT_WINDOW_COMPLETE','OWN_RESTART_WINDOW_COMPLETE'] and q['elapsed_seconds']<20
  if build is None:build=q['build']
  else:assert build==q['build']
  x=next(x for x in q['rows'] if x['day']==day);assert x['committed'] and abs(x['independent_residual_cm'])<=1e-6
  if rows:assert rows[-1]['stock_end_cm']==x['stock_start_cm']
  rows.append(x);times.append(q['elapsed_seconds'])
  with zipfile.ZipFile(p/f'accepted-column-1-day-{day}.zip') as z:
   for name in ['macro.bin','result.end']:
    key=f'{day}/{name}';h=hashlib.sha256(z.read(name)).hexdigest()
    if opt=='O0':hashes[key]=h
    else:assert hashes[key]==h
 parent=json.loads((b/'PREPARED_V31_DAY41/RESULT.json').read_text())['rows'][0];assert parent['stock_end_cm']==rows[0]['stock_start_cm']
 bal=math.fsum([*rows[0]['stock_start_cm'],*(-v for v in rows[-1]['stock_end_cm']),*(v for x in rows for v in x['external_flux_cm'][:7]),*(-v for x in rows for v in x['external_flux_cm'][7:])]);assert abs(bal)<len(rows)*1e-6
 reports.append(dict(opt=opt,initial_frozen_context_day=41,actual_current_candidate_days=list(range(42,end+1)),own_continuation_days=list(range(43,end+1)),same_build_all_current_days=True,initial_prefix_claimed_current_candidate_own=False,max_day_inventory_error_cm=max(abs(x['independent_residual_cm']) for x in rows),window_inventory_error_cm=bal,max_route_seconds=max(times),last_receipt=rows[-1]))
out=dict(scope='Originalfrozen41context->V33day42 plus literalcurrentcandidateowncontinuation. AllnativeO0/O2exact; no fixedV33initialprefix/full481/scientificadmissionclaim.',results=reports,native_sha256=hashes,models_launched=0)
(R/f'BLOCK34_V33_ORIGINAL41TO{end}_QUALIFICATION.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps({**out,'native_sha256':'retained in report','results':[{k:v for k,v in x.items() if k!='last_receipt'} for x in reports]}))

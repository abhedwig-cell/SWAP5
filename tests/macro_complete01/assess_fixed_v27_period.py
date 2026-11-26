"""Fixed V27 actual original prefix; independent balance and native equality."""
from pathlib import Path
import json,zipfile,hashlib,math,sys
ROOT=Path(__file__).resolve().parents[2];R=ROOT/'integration/macro-complete01';res=json.loads((R/'RESOURCE_PATHS.json').read_text());end=int(sys.argv[1]);reports=[];hashes={}
def native(p):
 with zipfile.ZipFile(p) as z:return {n:z.read(n) for n in ['macro.bin','result.end']},json.loads(z.read('checkpoint.json'))['receipt']
for opt in ['O0','O2']:
 b=Path(res[opt]['path']);rows=[];build=None;seconds=[]
 for day in range(1,end+1):
  label='ORDINARY_V27_FIXED_COLD2' if day<=2 else 'ORDINARY_V27_FIXED_DAY'+str(day)
  q=json.loads((b/label/'RESULT.json').read_text());assert q['status'] in ['FRESH_WINDOW_COMPLETE','OWN_RESTART_WINDOW_COMPLETE'] and q['elapsed_seconds']<20
  if build is None:build=q['build']
  else:assert build==q['build']
  x=next(x for x in q['rows'] if x['day']==day);assert x['committed'] and abs(x['independent_residual_cm'])<=1e-6
  if rows:assert rows[-1]['stock_end_cm']==x['stock_start_cm']
  rows.append(x);seconds.append(q['elapsed_seconds']);nv,rc=native(b/label/f'accepted-column-1-day-{day}.zip')
  for n,v in nv.items():
   key=f'{day}/{n}';sha=hashlib.sha256(v).hexdigest()
   if opt=='O0':hashes[key]=sha
   else:assert hashes[key]==sha
 comparisons=[]
 for day,label in [(22,'UPPERCOMPLETE_V21_FIXED_DAY22'),(23,'TWOSIDED_V25_CONTEXT22TO23'),(24,'ORDINARY_V27_CONTEXT23TO24'),(25,'ORDINARY_V27_OWN24TO25'),(26,'ORDINARY_V27_OWN25TO26')]:
  if day>end:continue
  p=b/f'ORDINARY_V27_FIXED_DAY{day}'/f'accepted-column-1-day-{day}.zip';nv,rc=native(p);other,orc=native(b/label/f'accepted-column-1-day-{day}.zip');comparisons.append(dict(day=day,prior_label=label,native_exact=nv==other,receipt_exact=rc==orc))
 residual=math.fsum([*rows[0]['stock_start_cm'],*(-v for v in rows[-1]['stock_end_cm']),*(v for x in rows for v in x['external_flux_cm'][:7]),*(-v for x in rows for v in x['external_flux_cm'][7:])]);assert abs(residual)<=end*1e-6
 reports.append(dict(opt=opt,executed_fixed_candidate_original_days=end,max_day_inventory_error_cm=max(abs(x['independent_residual_cm']) for x in rows),full_prefix_inventory_error_cm=residual,max_route_seconds=max(seconds),same_build_all_days=True,comparisons=comparisons))
out=dict(scope='Actual unchanged fixedV27 ownprefix from originalbalancebegin; allnative O0checked/O2exact, original1e-6cm/dayguard; no inheritedprefix counted, no full481day claim.',results=reports,native_sha256=hashes,models_launched=0)
(R/f'BLOCK28_FIXED_V27_PREFIX{end}_QUALIFICATION.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps({k:v for k,v in out.items() if k!='native_sha256'}))

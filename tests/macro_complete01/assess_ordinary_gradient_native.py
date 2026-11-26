from pathlib import Path
import json,hashlib,zipfile,math
ROOT=Path(__file__).resolve().parents[2];R=ROOT/'integration/macro-complete01';res=json.loads((R/'RESOURCE_PATHS.json').read_text());labels=['TWOSIDED_V25_CONTEXT22TO23','ORDINARY_V27_CONTEXT23TO24','ORDINARY_V27_OWN24TO25','ORDINARY_V27_OWN25TO26'];out=[]
for label in labels:
 qs=[json.loads((Path(res[o]['path'])/label/'RESULT.json').read_text()) for o in ['O0','O2']]
 assert qs[0]['rows']==qs[1]['rows']
 for q in qs:assert q['elapsed_seconds']<20 and all(x['committed'] and abs(x['independent_residual_cm'])<=1e-6 for x in q['rows'])
 native={}
 for day in [x['day'] for x in qs[0]['rows']]:
  zz=[zipfile.ZipFile(Path(res[o]['path'])/label/f'accepted-column-1-day-{day}.zip') for o in ['O0','O2']]
  for name in ['macro.bin','result.end']:
   assert zz[0].read(name)==zz[1].read(name);native[f'{day}/{name}']=hashlib.sha256(zz[0].read(name)).hexdigest()
 out.append(dict(label=label,day=qs[0]['end_day'],status=[q['status'] for q in qs],elapsed_seconds=[q['elapsed_seconds'] for q in qs],rows=qs[0]['rows'],native_sha256=native,O0_O2_rows_and_native_exact=True,inherited_prefix_counted_as_target_own=False))
q=dict(scope='V25 D1 lower correction day23 and V27 ordinary absorption day24; literal target-own native days25/26. No fixed V27 prefix or full481 claim.',results=out,models_launched=0,physics_budget_and_input_unchanged=True)
(R/'BLOCK27_CONTEXT_AND_OWN_QUALIFICATION.json').write_text(json.dumps(q,indent=2)+'\n');print(json.dumps([{k:v for k,v in x.items() if k not in ['rows','native_sha256']} for x in out]))

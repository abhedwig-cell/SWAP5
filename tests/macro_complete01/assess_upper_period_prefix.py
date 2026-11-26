"""Independent read-only complete available prefix inventory and O0/O2 native identity."""
from pathlib import Path
import json,zipfile,math,hashlib
R=Path('integration/macro-complete01');res=json.loads((R/'RESOURCE_PATHS.json').read_text());last=int(__import__('sys').argv[1]);reports=[];states={}
for opt in ['O0','O2']:
 b=Path(res[opt]['path']);rows=[]
 for day in range(1,last+1):
  label='UPPERIN_V20_COLD2' if day<=2 else 'UPPERIN_V20_DAY'+str(day)
  q=json.loads((b/label/'RESULT.json').read_text());x=next(x for x in q['rows'] if x['day']==day);assert x['committed']
  if rows:assert rows[-1]['stock_end_cm']==x['stock_start_cm']
  rows.append(x)
  with zipfile.ZipFile(b/label/('accepted-column-1-day-'+str(day)+'.zip')) as z:
   for n in ['macro.bin','result.end']:
    h=hashlib.sha256(z.read(n)).hexdigest();key=str(day)+'_'+n
    if opt=='O0':states[key]=h
    else:assert states[key]==h
 for x in rows:
  terms=[*x['external_flux_cm'][:7],*(-v for v in x['external_flux_cm'][7:]),*x['stock_start_cm'],*(-v for v in x['stock_end_cm'])]
  assert math.fsum(terms)==x['independent_residual_cm'];assert abs(math.fsum(terms))<=1e-6
 residual=math.fsum([*rows[0]['stock_start_cm'],*(-v for v in rows[-1]['stock_end_cm']),*(v for x in rows for v in x['external_flux_cm'][:7]),*(-v for x in rows for v in x['external_flux_cm'][7:])])
 assert abs(residual)<=last*1e-6
 reports.append(dict(opt=opt,days=last,max_day_residual_cm=max(abs(x['independent_residual_cm']) for x in rows),complete_prefix_inventory_residual_cm=residual,all_native_payloads_exact=True))
out=dict(scope='Actual available original prefix from balance origin with all6stocks and16externalflows; no full481day or scientific-equivalence verdict',results=reports,models_launched=0,native_payload_hashes=states)
(R/('BLOCK20_PREFIX_DAY'+str(last)+'_ASSESSMENT.json')).write_text(json.dumps(out,indent=2)+'\n');print(json.dumps({k:v for k,v in out.items() if k!='native_payload_hashes'}))

"""Read-only integrated contact and observer qualification; no models."""
from pathlib import Path
import json,math,hashlib,zipfile
ROOT=Path(__file__).resolve().parents[2];R=ROOT/'integration/macro-complete01';res=json.loads((R/'RESOURCE_PATHS.json').read_text());rows={};out=[]
for opt in ['O0','O2']:
 b=Path(res[opt]['path']);c=json.loads((b/'CONTACT_V5R3_COLD2/RESULT.json').read_text());o=json.loads((b/'CONTACT_V5R3_OWN2TO3/RESULT.json').read_text());d=json.loads((b/'OBSERVER06_COLD2/RESULT.json').read_text());e=json.loads((b/'OBSERVER06_OWN2TO3/RESULT.json').read_text())
 assert c['status']=='FRESH_WINDOW_COMPLETE' and len(c['rows'])==2 and d['rows']==c['rows'];rows[opt]=c['rows']
 for r in c['rows']:
  reconstructed=math.fsum([*r['external_flux_cm'][:7],*(-x for x in r['external_flux_cm'][7:]),*r['stock_start_cm'],*(-x for x in r['stock_end_cm'])])
  assert reconstructed==r['independent_residual_cm'] and abs(reconstructed)<=1e-6 and r['committed']
 for v,n in [(o,'CONTACT_V5R3'),(e,'OBSERVER06')]:
  assert v['status']=='FAILED' and v['initial_state_exact'] and not v['rows'] and v['elapsed_seconds']<20
  stderr=(b/(n+'_OWN2TO3')/'original/donor.stderr').read_text();assert 'FRESH_UNREDUCED_SCALE_REQUEST   35797.505000000005' in stderr
 payloads=[]
 for n in ['CONTACT_V5R3','OBSERVER06']:
  with zipfile.ZipFile(b/(n+'_COLD2')/'accepted-column-1-day-2.zip') as z:payloads.append({p:hashlib.sha256(z.read(p)).hexdigest() for p in ['macro.bin','result.end']})
 assert payloads[0]==payloads[1]
 hist=(b/'CONTACT_V5R3_OWN2TO3/original/macro_contact_history.txt').read_text().splitlines();increments=[float(x.split()[5]) for x in hist];assert all(x>0 for x in increments)
 out.append(dict(opt=opt,cold_seconds=c['elapsed_seconds'],own_seconds=o['elapsed_seconds'],observer_cold_seconds=d['elapsed_seconds'],observer_own_seconds=e['elapsed_seconds'],day_residuals_cm=[r['independent_residual_cm'] for r in c['rows']],history_events=len(hist),reference_increment_sum=math.fsum(increments),native_day2_payload=payloads[0],observer_preservation='physical rows and complete native payload exact'))
assert rows['O0']==rows['O2']
for n in ['macro_contact_history.txt','coupled_refusal_observer.txt']:
 sub='CONTACT_V5R3' if n=='macro_contact_history.txt' else 'OBSERVER06'
 assert (Path(res['O0']['path'])/(sub+'_OWN2TO3')/'original'/n).read_bytes()==(Path(res['O2']['path'])/(sub+'_OWN2TO3')/'original'/n).read_bytes()
q=dict(decision='CONTACT_AND_ACCEPTED_RATE_REFERENCE_TWO_DAY_PASS_OWN_PREFIX_TO_NEW_REFUSAL',results=out,next_blocker='Node35 D5 sorption two-cycle at35797.505 ondtmin;420actual operator records independently reconstruct to2.22e-16. DTMIN58 product update candidate.',full_day3_pass=False,scientific_equivalence='NOT_QUALIFIED',release_readiness='NOT_READY',optimization_scope='O0checked changed owners/O2; unchanged original physicalpoolO2',mass_scope='Legacy host1e-6cm; no modern1e-10 or full-period claim')
(R/'BLOCK04_RESULT.json').write_text(json.dumps(q,indent=2)+'\n');print(json.dumps(q))

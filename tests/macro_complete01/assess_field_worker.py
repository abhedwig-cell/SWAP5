"""Read-only field-v2 qualification; no models, no tolerance changes."""
from pathlib import Path
import json,zipfile,hashlib
ROOT=Path(__file__).resolve().parents[2];R=ROOT/'integration/macro-complete01';res=json.loads((R/'RESOURCE_PATHS.json').read_text())
sha=lambda data:hashlib.sha256(data).hexdigest()
results=[];payloads={};rows={}
for opt in ['O0','O2']:
 b=Path(res[opt]['path']); q={}
 for name in ['COLD1','OWN1TO2','COLD2','OWN2TO3']:
  d=b/('FIELD_V2_'+name);v=json.loads((d/'RESULT.json').read_text());q[name]=dict(status=v['status'],seconds=v['elapsed_seconds'],water=[r['independent_residual_cm'] for r in v['rows']])
  assert v['elapsed_seconds']<20
  if name!='OWN2TO3':
   assert v['status'] in ['FRESH_WINDOW_COMPLETE','OWN_RESTART_WINDOW_COMPLETE'] and all(r['committed'] and abs(r['independent_residual_cm'])<=1e-6 for r in v['rows'])
   rows[opt,name]=[{k:x for k,x in r.items() if k!='revision'} for r in v['rows']]
  else:
   assert v['status']=='FAILED' and v['initial_state_exact'] and not v['rows']
   e=(d/'original/donor.stderr').read_text();assert 'FRESH_UNREDUCED_SCALE_REQUEST' in e and '35797.071256456351' in e
  if name in ['OWN1TO2','COLD2']:
   with zipfile.ZipFile(d/'accepted-column-1-day-2.zip') as z:
    payloads[opt,name]={n:sha(z.read(n)) for n in ['result.end','macro.bin']}
 assert rows[opt,'OWN1TO2']==rows[opt,'COLD2'][1:]
 assert payloads[opt,'OWN1TO2']==payloads[opt,'COLD2']
 results.append(dict(opt=opt,windows=q,own_native_vs_continuous_exact=True,day2_payload=payloads[opt,'COLD2']))
for n in ['COLD1','OWN1TO2','COLD2']:assert rows['O0',n]==rows['O2',n]
assert payloads['O0','COLD2']==payloads['O2','COLD2']
q=dict(decision='FIELD_DARCY_TWO_DAY_AND_OWN_NATIVE_SCOPE_PASS_NEXT_KNOWN_NODE52_BLOCKER',results=results,optimization_scope='kernel and touched owners O0/O2; unchanged original physics poolO2',mass_scope='existing legacy host1e-6cm only, no modern1e-10 or full-period claim',full_migration=False,scientific_equivalence='NOT_QUALIFIED',next='Known DIAG19/NODE20 minimum-stock derivative; no exchange scaling accepted')
(R/'BLOCK02_FIELD_V2_RESULT.json').write_text(json.dumps(q,indent=2)+'\n');print(json.dumps(q))

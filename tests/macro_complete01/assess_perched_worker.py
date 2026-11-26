"""Read-only current perched recognition and first native windows."""
from pathlib import Path
import json,zipfile,hashlib
ROOT=Path(__file__).resolve().parents[2];R=ROOT/'integration/macro-complete01';res=json.loads((R/'RESOURCE_PATHS.json').read_text());out=[];rows={}
for opt in ['O0','O2']:
 b=Path(res[opt]['path']);comp=json.loads((R/('PERCHED_'+opt+'_COMPONENT_R1.json')).read_text());assert comp['status'].startswith('REAL_CALCGWL_COMPONENT_PASS')
 c=json.loads((b/'PERCHED_V7_COLD2/RESULT.json').read_text());d=json.loads((b/'OBSERVER09_COLD2/RESULT.json').read_text());o=json.loads((b/'PERCHED_V7_OWN2TO3/RESULT.json').read_text());assert c['status']=='FRESH_WINDOW_COMPLETE' and c['rows']==d['rows'];rows[opt]=c['rows'];assert o['status']=='FAILED' and o['initial_state_exact'] and not o['rows']
 with zipfile.ZipFile(b/'PERCHED_V7_COLD2/accepted-column-1-day-2.zip') as z:payload={n:hashlib.sha256(z.read(n)).hexdigest() for n in ['macro.bin','result.end']}
 stderr=(b/'PERCHED_V7_OWN2TO3/original/donor.stderr').read_text();assert 'FRESH_UNREDUCED_SCALE_REQUEST   35797.121777777887' in stderr
 lines=(b/'OBSERVER09_OWN2TO3/original/coupled_refusal_observer.txt').read_text().splitlines();last=lines[-9].split();assert int(last[9])==52 and int(last[18])==-1
 out.append(dict(opt=opt,cold_seconds=c['elapsed_seconds'],own_seconds=o['elapsed_seconds'],day_water_errors_cm=[r['independent_residual_cm'] for r in c['rows']],native_day2_payload=payload,next_refusal_node=52,next_refusal_time=35797.121777777887,perched_bottom=-1))
assert rows['O0']==rows['O2'] and out[0]['native_day2_payload']==out[1]['native_day2_payload']
a=(Path(res['O0']['path'])/'OBSERVER09_OWN2TO3/original/coupled_refusal_observer.txt').read_bytes();b=(Path(res['O2']['path'])/'OBSERVER09_OWN2TO3/original/coupled_refusal_observer.txt').read_bytes();assert a==b
q=dict(decision='DOCUMENTED_PERCHED_CLASSIFICATION_REAL_COMPONENT_AND_TWO_NATIVE_DAYS_PASS',results=out,positive_threshold_control='Same frozen states recognize true24..28 perched region on both sides with criterion0.01cm; actual model input remains0.1cm',nonmacro_scope='Literal unchanged no-macro branch and native component output exact; no full no-macro period claim',next='D3 W/V minimum-stock and positive contact potential; originalCOMBINED63 requires reconciliation for zero inflow and already-active local U derivative.',full_day3_pass=False,scientific_equivalence='NOT_QUALIFIED',release_readiness='NOT_READY',optimization_scope='Kernel and touched owners O0checked/O2; unchanged providerpoolO2')
(R/'BLOCK06_RESULT.json').write_text(json.dumps(q,indent=2)+'\n');print(json.dumps(q))

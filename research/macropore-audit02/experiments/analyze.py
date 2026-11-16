"""Independent byte/vector assertions on the actual bounded audit runs."""
import argparse,hashlib,json,struct,zipfile
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--workspace',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();r=a.workspace
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
physical=lambda row:{k:v for k,v in row.items() if k!='revision'}
report={'disposition':'KNOWN CAUSE','classification':'B: inconsistent nonlinear state/acceptance contract','production_correction':False,'full_runs':0,'noninterference':{},'rollback':{},'counterfactual':{}}
def records(run):return json.loads((r/run/'RESULT.json').read_text())['rows']
def exact(run,control):
 x=records(run);y=records(control);assert [physical(v) for v in x]==[physical(v) for v in y]
 endpoints={n:sha(r/run/'original'/n) for n in ['result.end','macro.bin']}
 assert endpoints=={n:sha(r/control/'original'/n) for n in endpoints}
 report['noninterference'][run]=endpoints
for run in ['rollback2-14to15','retry-final14to15']:exact(run,'control14to15')
exact('first433','control432to433')
# The 433->434 restart changes revision only and exactly reproduces the same day.
assert physical(records('first434')[0])==physical(records('trace-final432to438')[1])
with zipfile.ZipFile(Path(__file__).resolve().parents[2]/'hybrid-water01/original-macro-day438-evidence.zip') as z:
 expected=list(map(json.loads,z.read('control/daily.jsonl').decode().splitlines()))
 for run in ['trace-final432to438','counter432to438']:
  assert [physical(v) for v in records(run)]==[physical(v) for v in expected]
  report['noninterference'][run]={}
  for n in ['result.end','macro.bin']:
   assert z.read('control/original/'+n)==(r/run/'original'/n).read_bytes()
   report['noninterference'][run][n]=sha(r/run/'original'/n)
# Full static module/SAVE byte inventory, including rate-only hidden locals.
symbols=json.loads((r/'rollback2-build/symbols.json').read_text())
raw={tag:(r/'rollback2-14to15/original'/f'rollback-{tag}.bin').read_bytes() for tag in ['origin','trial','restored','retry']}
assert all(len(v)==sum(s['size'] for s in symbols) for v in raw.values())
changed=[]
for s in symbols:
 o=s['offset'];n=s['size'];old=raw['origin'][o:o+n];new=raw['restored'][o:o+n]
 if old!=new:
  d={'symbol':s['name'],'changed_bytes':sum(x!=y for x,y in zip(old,new)),'size':n}
  if s['name'].startswith('__mod_') and n%8==0:
   xx=struct.unpack('<'+'d'*(n//8),old);yy=struct.unpack('<'+'d'*(n//8),new)
   d['max_abs_float_delta']=max(abs(x-y) for x,y in zip(xx,yy))
  changed.append(d)
assert len(changed)==39
for name in ['icpbtdm','vlmpdmcp','waunmpdmcp','frmpwalwet','frmpwalwetold','flendsrpevt','timabscumdmcp','wasrmpdm','hybrid_integral_wall_previous']:
 s=next(s for s in symbols if s['name']=='__mod_macropore_MOD_'+name)
 o=s['offset'];n=s['size'];assert raw['origin'][o:o+n]==raw['restored'][o:o+n],name
for name in ['h','theta','gwl','pond']:
 s=next(s for s in symbols if s['name']=='__variables_MOD_'+name);o=s['offset'];n=s['size'];assert raw['origin'][o:o+n]==raw['restored'][o:o+n]
left=(r/'retry-final14to15/original/retry-eval-0.txt').read_bytes();right=(r/'retry-final14to15/original/retry-eval-1.txt').read_bytes();assert left==right
report['rollback']={'static_symbols':len(symbols),'static_bytes_per_snapshot':len(raw['origin']),'all_static_state_exact':False,'changed_symbols':changed,'matrix_and_named_physical_history_exact':True,'macro_origin_restore_fields':len((r/'retry-build/restore-names.txt').read_text().splitlines()),'pristine_macro_origin_retry_Q_and_F_exact':True,'retry_metadata':left.decode().splitlines()[0],'day15_budget_retries':records('control14to15')[0]['budget_step_retries'],'scope':'First actual day15 internal rejection, no universal rollback qualification'}
# Earliest observed divergence is within the FIRST HeadCalc of the selected day433.
first=(r/'first433/original/first-divergence.txt').read_text().splitlines();v=first[0].split();report['first_selected_divergence']={'t1900':float(v[0]),'dt':float(v[1]),'iteration':int(v[2]),'backtrack':int(v[3]),'stage':int(v[4]),'cached_Fmax':float(v[5]),'fresh_Fmax':float(v[6]),'delta_Qmax':float(v[7]),'scope':'First step after native432; not claimed earliest in all preceding432days'}
assert float(v[0])==36227 and float(v[5])<1e-6<float(v[6])
lines=(r/'counter432to438/original/trace02.txt').read_text().splitlines()
d={x.split()[0]:list(map(float,x.split()[1:])) for x in lines if x.split()[0] in ['ACCEPT_H','CACHE_H','ACCEPT_F','FRESH_F','CACHE_Q','FRESH_Q']}
for mode in [1,2,3]:
 c={l.split()[0]:list(map(float,l.split()[1:])) for l in (r/f'counter432to438/original/counter-{mode}.txt').read_text().splitlines()}
 report['counterfactual'][str(mode)]={'Q_vs_cached':max(abs(x-y) for x,y in zip(c['Q'],d['CACHE_Q'])),'Q_vs_fresh':max(abs(x-y) for x,y in zip(c['Q'],d['FRESH_Q'])),'F_vs_fresh':max(abs(x-y) for x,y in zip(c['F'],d['FRESH_F']))}
assert report['counterfactual']['1']['Q_vs_fresh']==report['counterfactual']['1']['F_vs_fresh']==0
assert report['counterfactual']['2']['Q_vs_cached']==0
assert report['counterfactual']['3']['Q_vs_fresh']==0
report['day438']={'cached_Fmax':max(map(abs,d['ACCEPT_F'])),'fresh_Fmax':max(map(abs,d['FRESH_F'])),'failing_nodes':sum(abs(x)>1e-6 for x in d['FRESH_F']),'max_pressure_change_since_last_macro_evaluation':max(abs(x-y) for x,y in zip(d['ACCEPT_H'],d['CACHE_H'])),'exchange_attribution_error':max(abs((f-o)+(q-c)) for f,o,q,c in zip(d['FRESH_F'],d['ACCEPT_F'],d['FRESH_Q'],d['CACHE_Q'])),'GWL_cm':records('counter432to438')[-1]['groundwater_cm']}
report['measured_windows_seconds']={run:json.loads((r/run/'RESULT.json').read_text())['seconds'] for run in ['control4to14b','control14to15','rollback2-14to15','retry-final14to15','control432to433','first433','first434','trace-final432to438','counter432to438']}
a.output.write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({k:report[k] for k in ['disposition','first_selected_divergence','day438','counterfactual']}))

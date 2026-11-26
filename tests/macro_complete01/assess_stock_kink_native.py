"""Read-only actual stock-kink location and own native-route identities."""
from pathlib import Path
import json,zipfile,math,hashlib
R=Path('integration/macro-complete01');res=json.loads((R/'RESOURCE_PATHS.json').read_text());q=dict(models_launched=0,scope='Original first4days, independent1e-6cm day guards, own native split routes and exact kink geometry; no wholeperiod/rollback claim',results=[],identities={})
for opt in ['O0','O2']:
 b=Path(res[opt]['path']);count=0;err=0.;domains={}
 for label in ['KINK_V13_COLD2','KINK_V13_OWN2TO3','KINK_V13_OWN3TO4']:
  r=json.loads((b/label/'RESULT.json').read_text());assert r['status'] in ['FRESH_WINDOW_COMPLETE','OWN_RESTART_WINDOW_COMPLETE'];assert all(abs(x['independent_residual_cm'])<=1e-6 for x in r['rows'])
  p=b/label/'original/macro_stock_kink_steps.txt'
  if not p.exists():continue
  for line in p.read_text().splitlines():
   t,dt,it,d,up,low,zu,zl,hu,hl,du,dl,cap,f,zm,V,W=map(float,line.split());assert 0<f<1 and cap>0
   a=hu-f*cap*du;c=hl-f*cap*dl;assert a<0<c
   gwl=zl+c/(c-a)*(zu-zl);e=abs(gwl-zm);err=max(err,e);assert e<=128*math.ulp(max(abs(gwl),abs(zm),1.))
   count+=1;domains[int(d)]=domains.get(int(d),0)+1
 rr=json.loads((b/'KINK_V13_OWN1TO4/RESULT.json').read_text());q.setdefault('long_route_status',{})[opt]=rr['status']
 z=[zipfile.ZipFile(b/label/'accepted-column-1-day-4.zip') for label in ['KINK_V13_OWN3TO4','KINK_V13_OWN2TO4']]
 if rr['status']=='OWN_RESTART_WINDOW_COMPLETE':z.append(zipfile.ZipFile(b/'KINK_V13_OWN1TO4/accepted-column-1-day-4.zip'))
 for n in ['result.end','macro.bin']:
  assert all(a.read(n)==z[0].read(n) for a in z);q['identities'][opt+'_'+n]=hashlib.sha256(z[0].read(n)).hexdigest()
 # The censored route retained day3: validate accepted prefix without rerunning it.
 z3=[zipfile.ZipFile(b/label/'accepted-column-1-day-3.zip') for label in ['KINK_V13_OWN1TO4','KINK_V13_OWN2TO3']]
 for n in ['result.end','macro.bin']:assert z3[0].read(n)==z3[1].read(n)
 q['results'].append(dict(opt=opt,kink_steps=count,domain_counts=domains,max_kink_gwl_error_cm=err,day_residuals_cm=[x['independent_residual_cm'] for l in ['KINK_V13_COLD2','KINK_V13_OWN2TO4'] for x in json.loads((b/l/'RESULT.json').read_text())['rows']]))
for n in ['result.end','macro.bin']:assert q['identities']['O0_'+n]==q['identities']['O2_'+n]
q['whole_period_pass']=False
(R/'BLOCK12_NATIVE_KINK_QUALIFICATION.json').write_text(json.dumps(q,indent=2)+'\n');print(json.dumps(q))

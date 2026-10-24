"""Independent initial quadrature, constitutive and conservative-profile checks."""
import base64,csv,hashlib,io,json,math,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).resolve().parent
sha=lambda b:hashlib.sha256(b).hexdigest()
def assess(files):
 assert files['validation/run.py']==(HERE/'run.py').read_bytes()
 r=json.loads(files['runs/RESULT.json']);assert r['status']=='EXECUTIONS_COMPLETE' and len(r['cases'])==6
 index=json.loads((HERE.parent/'fct_native_refinement/EVIDENCE_INDEX.json').read_text())
 raw=base64.b64decode((HERE.parent/'fct_native_refinement/EVIDENCE.tar.xz.b64').read_bytes());assert sha(raw)==index['sha256']
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz') as t:
  for opt in ['o0','o2']:assert r['builds'][opt]==json.loads(t.extractfile('build-'+opt+'/build.json').read())
 theta=[tr+(ts-tr)/(1+(alpha*100)**n)**(1-1/n) for tr,ts,alpha,n in [(.032,.423,.0135,1.455),(.04,.45,.02,1.6)]]
 expected_water=40*theta[0]+80*theta[1];expected_solute=26*(theta[0]+.26)+64*(theta[1]+.6)
 profiles={};initial=[];maxima=[0.,0.]
 def rows(p):
  values=[{k:float(v) for k,v in row.items()} for row in csv.DictReader(io.StringIO(files[p].decode()))]
  assert all(math.isfinite(v) for row in values for v in row.values());return values
 for e in r['cases']:
  opt,f=e['opt'],e['factor'];assert e['returncode']==0 and f in [1,2,4]
  b=r['builds'][opt]
  for p,h in b['inputs'].items():assert sha((ROOT/p).read_bytes())==h,p
  base=f'runs/{opt}-{f}/';swp=files[base+'project.swp'];assert b'HTB=0.,-100.,-120.,-100.' in swp and b'CMLTB=0.,.2,-8.,.2,-12.,.8,-120.,.8' in swp
  assert b'initial_pond_cm=0,initial_pond_mass_mg_cm2=0' in files[base+'input.nml']
  state=rows(base+'state.csv');budget=rows(base+'budget.csv');end=rows(base+'endpoint.csv')[0]
  assert len(state)==41*f and len(budget)==4 and end['time_day']==.4
  initial.append((budget[0]['water_start_cm'],budget[0]['solute_start_mg_cm2']))
  assert abs(initial[-1][0]-expected_water)<1e-11 and abs(initial[-1][1]-expected_solute)<1e-11
  for row in budget:
   for i,(s,u) in enumerate([('water','cm'),('solute','mg_cm2')]):
    residual=row[f'{s}_end_{u}']-row[f'{s}_start_{u}']-row[f'{s}_in_{u}']+row[f'{s}_out_{u}'];maxima[i]=max(maxima[i],abs(residual));assert abs(residual)<1e-10
   assert abs(row['water_in_cm']-.0005)<1e-10 and abs(row['solute_in_mg_cm2']-.0000875)<1e-10
   assert abs(row['water_out_cm']-.000205-row['actual_transpiration_cm']-row['runoff_cm'])<1e-10
  for i,v in enumerate(state):
   h,t,c,d,s=[v[k] for k in ['dz_cm','theta','concentration_mg_cm3','dissolved_mg_cm2','sorbed_mg_cm2']]
   assert min(h,t,c,d,s)>=0 and abs(d-h*t*c)<1e-11 and abs(s-h*c*(.26 if i<20*f else .6))<1e-11
  assert abs(sum(v['theta']*v['dz_cm'] for v in state)+end['pond_cm']-end['total_water_cm'])<1e-10
  assert abs(sum(v['dissolved_mg_cm2']+v['sorbed_mg_cm2'] for v in state)+end['pond_solute_mg_cm2']-end['total_solute_mg_cm2'])<1e-10
  profiles[opt,f]=[[sum(v[k] for v in state[i*f:(i+1)*f]) for k in ['dissolved_mg_cm2','sorbed_mg_cm2']] for i in range(41)]
 assert set(profiles)=={(o,f) for o in ['o0','o2'] for f in [1,2,4]}
 diff=max(abs(a-b) for f in [1,2,4] for x,y in zip(profiles['o0',f],profiles['o2',f]) for a,b in zip(x,y));assert diff<1e-12
 comparisons={f'{41*a}-{41*b}':sum(abs(sum(x)-sum(y)) for x,y in zip(profiles['o2',a],profiles['o2',b])) for a,b in [(1,2),(2,4)]}
 return dict(status='CONSISTENT_INITIAL_NATIVE_OBSERVATIONS_PASS',cases=6,initial_water_cm=expected_water,initial_solute_mg_cm2=expected_solute,initial_water_spread_cm=max(x[0] for x in initial)-min(x[0] for x in initial),initial_solute_spread_mg_cm2=max(x[1] for x in initial)-min(x[1] for x in initial),max_water_residual_cm=maxima[0],max_solute_residual_mg_cm2=maxima[1],O0_O2_difference=diff,profile_total_solute_l1=comparisons,general_accuracy_qualified=False)
def unpack():
 raw=base64.b64decode((HERE/'EVIDENCE.tar.xz.b64').read_bytes());assert sha(raw)==json.loads((HERE/'EVIDENCE_INDEX.json').read_text())['sha256']
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz') as t:f={m.name:t.extractfile(m).read() for m in t.getmembers()}
 assert json.loads(f.pop('MANIFEST.json'))=={p:sha(b) for p,b in f.items()};return f
if __name__=='__main__':print(json.dumps(assess(unpack()),indent=2))

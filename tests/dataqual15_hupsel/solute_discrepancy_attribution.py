"""Independent retained-solute discrepancy identities; no model correction.

Reuses actual accepted checkpoints and immutable original-reference outputs.
Native aggregate export is never relabeled a measured drainage component.
"""
import argparse,collections,copy,datetime,hashlib,json,math,subprocess,sys,tarfile
from pathlib import Path
from full_profile_evidence import DAYS,unpack
from inspect_profiles import profile
from scientific_followup import rows

ROOT=Path(__file__).resolve().parents[2]
BASE=ROOT/'integration/dataqual15_hupsel'
STEM='SOLUTE_ATTRIBUTION_20261104'
ORIGIN='b78ae8c8673814b497fa5612bfee0c3cf423c494'
sha=lambda b:hashlib.sha256(b).hexdigest()
norm=lambda p:sha(p.read_bytes().replace(b'\r\n',b'\n'))

def difference_identity(native,source):
 assert len(native)==1096 and len(source)==1097
 start=datetime.date.fromisoformat(source[0]['DATE'])
 n0=native[0]['start'];s0=float(source[0]['S_STOT']);nd=[];sd=[];din=[];dout=[];history=[]
 for day,(n,s,old) in enumerate(zip(native,source[1:],source),1):
  assert n['day']==day and datetime.date.fromisoformat(s['DATE'])==start+datetime.timedelta(days=day)
  assert all(math.isfinite(n[k]) for k in ('start','end','input','output'))
  assert n['input']>=0 and n['output']>=0
  if day>1:assert abs(n['start']-native[day-2]['end'])<=1e-10
  si=float(s['S_RAIN'])+float(s['S_IRRIG']);so=float(s['S_DRN'])+float(s['S_UPT'])
  defect_n=n['end']-n['start']-n['input']+n['output']
  defect_s=float(s['S_STOT'])-float(old['S_STOT'])-si+so
  assert abs(defect_n)<=1e-10 and abs(defect_s)<=1e-10,'daily conservation'
  nd.append(defect_n);sd.append(defect_s);din.append(n['input']-si);dout.append(n['output']-so)
  observed=n['end']-float(s['S_STOT'])
  predicted=n0-s0+math.fsum(din)-math.fsum(dout)+math.fsum(nd)-math.fsum(sd)
  assert abs(observed-predicted)<=1e-10,'difference identity'
  history.append(dict(day=day,date=s['DATE'],native_stock=n['end'],reference_stock=float(s['S_STOT']),
                      stock_difference=observed,cumulative_input_difference=math.fsum(din),
                      cumulative_export_difference=math.fsum(dout),native_cumulative_closure=math.fsum(nd),
                      reference_cumulative_closure=math.fsum(sd),identity_error=observed-predicted))
 assert abs(math.fsum(nd))<=1e-8 and abs(math.fsum(sd))<=1e-8,'cumulative conservation'
 return dict(history=history,maximum_native_daily_closure=max(map(abs,nd)),
             maximum_reference_daily_closure=max(map(abs,sd)),
             native_external_input=math.fsum(n['input'] for n in native),
             native_external_export=math.fsum(n['output'] for n in native),
             reference_external_input=math.fsum(float(s['S_RAIN'])+float(s['S_IRRIG']) for s in source[1:]),
             reference_drainage_export=math.fsum(float(s['S_DRN']) for s in source[1:]),
             reference_uptake_export=math.fsum(float(s['S_UPT']) for s in source[1:]))

def balance(delta,concentration,water):
 assert abs(delta-math.fsum([concentration,water]))<=1e-10,'primitive product attribution'

def primitives(points,source_profiles,source):
 assert sorted(points)==list(DAYS)
 report=[]
 for day,n in sorted(points.items()):
  assert n['day']==day
  r=sorted(source_profiles[day],key=lambda x:int(x['node']))
  assert [int(x['node']) for x in r]==list(range(1,35))
  for k in ('z_cm','dz_cm'):assert n[k]==[float(x[k]) for x in r]
  assert math.fsum(n['sorbed_mg_cm2'])==0 and n['surface_solute_mg_cm2']==0,'unobserved extra stock'
  assert max(abs(t*c*d-m) for t,c,d,m in zip(n['theta'],n['concentration_mg_cm3'],n['dz_cm'],n['dissolved_mg_cm2']))<=1e-10
  native=math.fsum(n['dissolved_mg_cm2']);original=math.fsum(float(x['water_content'])*float(x['concentration_mg_cm3'])*float(x['dz_cm']) for x in r)
  assert abs(native-n['solute_stock_mg_cm2'])<=1e-10
  assert abs(original-float(source[day]['S_STOT']))<=1e-10,'reference primitive stock'
  nodes=[]
  for i,(tn,cn,d,x) in enumerate(zip(n['theta'],n['concentration_mg_cm3'],n['dz_cm'],r),1):
   tr=float(x['water_content']);cr=float(x['concentration_mg_cm3'])
   dc=.5*(tn+tr)*(cn-cr)*d;dt=.5*(cn+cr)*(tn-tr)*d
   balance((tn*cn-tr*cr)*d,dc,dt)
   nodes.append(dict(node=i,z_cm=n['z_cm'][i-1],concentration_contribution=dc,water_content_contribution=dt))
  dc=math.fsum(x['concentration_contribution'] for x in nodes);dt=math.fsum(x['water_content_contribution'] for x in nodes)
  balance(native-original,dc,dt)
  report.append(dict(day=day,primitive_stock_difference=native-original,
                     concentration_contribution=dc,water_content_contribution=dt,nodes=nodes,
                     native_primitive_error=native-n['solute_stock_mg_cm2'],
                     reference_primitive_error=original-float(source[day]['S_STOT'])))
 return report

def measure(files,reference):
 windows=rows(files['case/budget.csv']);grouped=collections.defaultdict(list)
 for w in windows:grouped[int(math.ceil(float(w['t1_day'])-1e-9))].append(w)
 assert sorted(grouped)==list(range(1,1097))
 native=[dict(day=day,start=float(p[0]['solute_start_mg_cm2']),end=float(p[-1]['solute_end_mg_cm2']),
              input=math.fsum(float(x['solute_in_mg_cm2']) for x in p),output=math.fsum(float(x['solute_out_mg_cm2']) for x in p)) for day,p in sorted(grouped.items())]
 source=rows(reference['original/dtmax-0.0003125/result_output.csv'])
 donor=collections.defaultdict(list)
 for x in rows(reference['original/dtmax-0.0003125/hupsel_profiles.csv']):donor[int(x['day'])].append(x)
 points={d:profile(files[f'case/checkpoint-{d}.bin']) for d in DAYS}
 ledger=difference_identity(native,source);primitive=primitives(points,donor,source)
 # Keep the observed floating-point input difference in the identity above.
 # The inherited complete cumulative mass threshold is1e-8, not exact decimal
 # equality after summing independent adaptive substeps.
 assert abs(ledger['native_external_input']-48)<=1e-8 and abs(ledger['reference_external_input']-48)<=1e-8
 assert ledger['reference_uptake_export']==0
 bounds=json.loads(reference['science/FROZEN_BOUNDS_BEFORE_HOLDOUT.json'])
 accepted=json.loads(files['MEASURED.json']);history=ledger['history']
 worst=max(history,key=lambda h:abs(h['stock_difference']))
 first=next(h for h in history if abs(h['stock_difference'])>bounds['solute_stock']['limit'])
 export_error=abs(ledger['native_external_export']-ledger['reference_drainage_export'])
 assert abs(worst['stock_difference'])==accepted['assessment']['solute_stock']['error']
 assert export_error==accepted['assessment']['export_total']['error']
 # The failure is retained, never converted into an accepted science verdict.
 assert abs(worst['stock_difference'])>bounds['solute_stock']['limit']
 assert export_error>bounds['export_total']['limit']
 controls=[]
 for label in ('missing_day','shifted_day','native_export','reference_export','external_input'):
  n,s=copy.deepcopy((native,source))
  if label=='missing_day':n.pop(100)
  elif label=='shifted_day':n[100]['day']+=1
  elif label=='native_export':n[100]['output']+=1e-6
  elif label=='reference_export':s[101]['S_DRN']=str(float(s[101]['S_DRN'])+1e-6)
  else:n[100]['input']+=1e-6
  try:difference_identity(n,s)
  except AssertionError:controls.append(dict(control=label,rejected=True))
  else:raise AssertionError('accepted '+label)
 for label in ('native_concentration_donor','reference_concentration_donor','missing_profile'):
  n,d=copy.deepcopy((points,donor))
  if label=='native_concentration_donor':n[120]['concentration_mg_cm3'][0]+=1e-5
  elif label=='reference_concentration_donor':d[120][0]['concentration_mg_cm3']=str(float(d[120][0]['concentration_mg_cm3'])+1e-5)
  else:del n[120]
  try:primitives(n,d,source)
  except AssertionError:controls.append(dict(control=label,rejected=True))
  else:raise AssertionError('accepted '+label)
 # Day636 has opposite signed theta/concentration contributions. Omitting
 # either term would hide a real cancellation in this actual measured state.
 p=next(p for p in primitive if p['day']==636)
 try:balance(p['primitive_stock_difference'],p['concentration_contribution'],0.)
 except AssertionError:controls.append(dict(control='omitted_water_content_product',rejected=True))
 else:raise AssertionError('accepted incomplete product attribution')
 return dict(status='RETAINED_SOLUTE_DISCREPANCY_LEDGER_AND_PRIMITIVE_ATTRIBUTION_PASS',
             ledger=ledger,primitive_profiles=primitive,negative_controls=controls,
             first_frozen_stock_crossing=first,worst_frozen_stock_discrepancy=worst,
             unchanged_stock_limit=bounds['solute_stock']['limit'],export_error=export_error,
             unchanged_export_limit=bounds['export_total']['limit'],
             final_primitive_attribution=primitive[-1],native_export_route_separation_measured=False,
             physical_transport_mechanism_qualified=False,production_correction_qualified=False,
             whole_scientific_admission=False)

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--seal',action='store_true');a=p.parse_args()
 subprocess.run([sys.executable,'-B',str(ROOT/'tests/dataqual15_hupsel/full_profile_evidence.py')],cwd=ROOT,check=True)
 subprocess.run(['git','merge-base','--is-ancestor',ORIGIN,'HEAD'],cwd=ROOT,check=True)
 inherited=json.loads((BASE/'FULL_PROFILE_EVIDENCE_20261104.json').read_text())
 for name in ('FULL_PROFILE_EVIDENCE_20261104.json','FULL_PROFILE_CANONICAL_RECEIPT_20261104.json','SPRINT03_SCIENCE_MANIFEST.json'):
  origin=subprocess.check_output(['git','show',ORIGIN+':integration/dataqual15_hupsel/'+name],cwd=ROOT)
  assert sha(origin.replace(b'\r\n',b'\n'))==norm(BASE/name),name+' immutable origin'
 files=unpack(BASE/'FULL_PROFILE_EVIDENCE_20261104.tar.xz',inherited['files_sha256'])
 m=json.loads((BASE/'SPRINT03_SCIENCE_MANIFEST.json').read_text());archive=BASE/m['archive'];assert sha(archive.read_bytes())==m['archive_sha256']
 with tarfile.open(archive) as t:
  ref={n:t.extractfile(n).read() for n in ('original/dtmax-0.0003125/result_output.csv','original/dtmax-0.0003125/hupsel_profiles.csv','science/FROZEN_BOUNDS_BEFORE_HOLDOUT.json')}
 assert all(sha(raw)==m['members'][n] for n,raw in ref.items())
 result=measure(files,ref)
 path=BASE/(STEM+'.json')
 if a.seal:
  dependencies=dict(inherited['normalized_repository_dependency_sha256'])
  for n in ('tests/dataqual15_hupsel/solute_discrepancy_attribution.py','.github/workflows/hupsel-solute-attribution.yml',
            'integration/dataqual15_hupsel/SOLUTE_ATTRIBUTION_PREREGISTRATION_20261104.json'):
   dependencies[n]=norm(ROOT/n)
  record=dict(status=result['status'],baseline=ORIGIN,candidate=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
              normalized_repository_dependency_sha256=dependencies,
              actual_native_capsule_sha256=inherited['archive_sha256'],reference_capsule_sha256=m['archive_sha256'],
              result=result,whole_scientific_admission=False)
  path.write_text(json.dumps(record,indent=2)+'\n',encoding='utf-8')
 else:
  record=json.loads(path.read_text());assert record['baseline']==ORIGIN and record['whole_scientific_admission'] is False
  for n,h in record['normalized_repository_dependency_sha256'].items():assert norm(ROOT/n)==h,n
  assert record['actual_native_capsule_sha256']==inherited['archive_sha256'] and record['reference_capsule_sha256']==m['archive_sha256']
  assert result==record['result']
 print(result['status']);print(json.dumps(dict(first_crossing_day=result['first_frozen_stock_crossing']['day'],
  final_stock_difference=result['ledger']['history'][-1]['stock_difference'],final_concentration_component=result['final_primitive_attribution']['concentration_contribution'],
  final_theta_component=result['final_primitive_attribution']['water_content_contribution'],whole_scientific_admission=False)))

if __name__=='__main__':main()

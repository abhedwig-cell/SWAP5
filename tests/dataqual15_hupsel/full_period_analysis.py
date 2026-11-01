"""Recompute measured Hupsel differences; preserve every frozen failed criterion."""
import argparse,collections,hashlib,json,math,re
from pathlib import Path
from scientific_followup import ROOT,native_data,features,distance,rows
from inspect_profiles import profile
sha=lambda raw:hashlib.sha256(raw).hexdigest()

def reference(case):
 scalar=rows((case/'result_output.csv').read_bytes());p=collections.defaultdict(list)
 for row in rows((case/'hupsel_profiles.csv').read_bytes()):p[int(row['day'])].append(row)
 assert len(scalar)==1097 and sorted(p)==list(range(1097))and all(len(v)==34 for v in p.values())
 return scalar,p

def diagnostic_native(folder,required_days):
 report=json.loads((folder/'RESULT.json').read_text());assert report['status']=='DIAGNOSTIC_FULL_EXECUTIONS_COMPLETE'and report['phase']=='native'
 assert all(e['returncode']==0 and not e['censored']for e in report['events'])
 case=folder/'native-dtmax-0.01';assert sha((folder/'swap5_hupsel').read_bytes())==report['executable_sha256']
 pattern=rb'(?im)^(\s*DTMAX\s*=\s*)[\d.eE+\-]+'
 for name in ['swap.swp','maize.crp','potato.crp','grass.crp','283.met','swap.dra']:
  current=(case/name).read_bytes();original=(ROOT/'reference/swap-4.3.1/projects/1.hupselbrook'/name).read_bytes()
  if name=='swap.swp':
   assert len(re.findall(pattern,current))==1 and float(re.search(rb'(?im)^\s*DTMAX\s*=\s*([\d.eE+\-]+)',current)[1])==.01
   normalize=lambda raw:re.sub(pattern,lambda m:m[1]+b'NUMERICAL_DTMAX',raw)
   assert normalize(current)==normalize(original)
  else:assert current==original,name
 budget=rows((case/'budget.csv').read_bytes());crop=rows((case/'crop.csv').read_bytes());points={};grouped=collections.defaultdict(list)
 for p in case.glob('checkpoint*.bin'):
  state=profile(p.read_bytes());points[state['day']]=state
 assert set(required_days)<=set(points),(set(required_days)-set(points));assert points[1096]['day']==1096
 for r in budget:grouped[int(math.ceil(float(r['t1_day'])-1e-9))].append(r)
 assert sorted(grouped)==list(range(1,1097));daily=[]
 for day,parts in sorted(grouped.items()):
  assert float(parts[0]['t0_day'])==day-1 and float(parts[-1]['t1_day'])==day
  for a,b in zip(parts,parts[1:]):assert a['t1_day']==b['t0_day']
  row={k:math.fsum(float(r[k])for r in parts)for k in parts[0]if k not in ['window','t0_day','t1_day']}
  for k in ['water_start_cm','solute_start_mg_cm2']:row[k]=float(parts[0][k])
  for k in ['water_end_cm','solute_end_mg_cm2']:row[k]=float(parts[-1][k])
  row['day']=day;daily.append(row)
 for r in budget:
  for prefix,unit in [('water','cm'),('solute','mg_cm2')]:assert abs(float(r[prefix+'_end_'+unit])-float(r[prefix+'_start_'+unit])-float(r[prefix+'_in_'+unit])+float(r[prefix+'_out_'+unit]))<1e-10
 for day,state in points.items():
  for prefix,unit in [('water','cm'),('solute','mg_cm2')]:assert abs(state[prefix+'_stock_'+unit]-daily[day-1][prefix+'_end_'+unit])<1e-10
 supplied=math.fsum(r['solute_in_mg_cm2']for r in daily);exported=math.fsum(r['solute_out_mg_cm2']for r in daily)
 assert abs(supplied-48)<1e-8 and abs(points[1096]['solute_stock_mg_cm2']+exported-48)<1e-8
 return daily,crop,{d:points[d]for d in required_days},dict(full_days=1096,external_input_mg_cm2=supplied,external_output_mg_cm2=exported,independent_final_stock_mg_cm2=points[1096]['solute_stock_mg_cm2'],independent_chemical_closure_mg_cm2=points[1096]['solute_stock_mg_cm2']+exported-48,numerical_variant='DTMAX0.01',literal_swp_byte_identity=False,physical_swp_except_numerical_dtmax_identity=True)

def analyze(study,original=None,native=None):
 daily,crop,points,old,accounting,swp=native_data();report=json.loads((study/'RESULT.json').read_text());assert report['status']=='FULL1096_HUPSEL_SCIENTIFIC_MEASUREMENTS_COMPLETE'
 bounds=json.loads((study/'FROZEN_BOUNDS_BEFORE_HOLDOUT.json').read_text());series={}
 for cap in [.04,.02,.01,.005,.0025,.00125]:series[cap]=reference(study/('dtmax-'+str(cap)))
 assert series[.04][0]==old
 a,b=series[.01],series[.005];n,coarse,floor,unit=features(*a,daily,crop,points);_,fine,_,_=features(*b,daily,crop,points)
 controls=['crop_dvs','crop_tsum','crop_pwrt','crop_pwlv','crop_pwst','crop_pwso','crop_rdpot','crop_potential_harvested_dry_matter']
 expected={k:dict(training_change=distance(k,coarse[k],fine[k]),floor=floor[k],limit=floor[k]if k in controls else 3*distance(k,coarse[k],fine[k])+floor[k],unit=unit[k])for k in n};assert bounds==expected
 previous={k:v['training_change']for k,v in bounds.items()};assessment={}
 for cap in [.0025,.00125]:
  n,ref,_,_=features(*series[cap],daily,crop,points);_,prior,_,_=features(*series[cap*2],daily,crop,points);fields={}
  for key,bound in bounds.items():
   error=distance(key,n[key],ref[key]);change=distance(key,prior[key],ref[key]);fields[key]=dict(native_error=error,limit=bound['limit'],inside_frozen_bound=error<=bound['limit'],reference_change=change,previous_change=previous[key],reference_change_decreases=change<=previous[key]+bound['floor']);previous[key]=change
  assessment[str(cap)]=fields
 assert assessment==report['assessment'];gate=all(v['inside_frozen_bound']and v['reference_change_decreases']for fields in assessment.values()for v in fields.values());assert gate==report['registered_gate_pass']
 answer=dict(status='FULL_PERIOD_RAW_COMPARISON_RECOMPUTED',original_frozen_gate_pass=gate,original_gate_unchanged=True,literal_native_full_days=1096,accounting=accounting,original_reference_control_exact=True,frozen_assessment=assessment)
 # Additional observations do not alter the already failed registered gate.
 initial=daily[0]['water_start_cm'];final=points[1096]['water_stock_cm'];incoming=math.fsum(r['water_in_cm']for r in daily);outgoing=math.fsum(r['water_out_cm']for r in daily)
 answer['independent_water_ledger']=dict(initial_receipt_cm=initial,final_primitive_stock_cm=final,external_input_cm=incoming,external_output_cm=outgoing,closure_cm=final-initial-incoming+outgoing)
 assert abs(answer['independent_water_ledger']['closure_cm'])<1e-8
 answer['supplemental_observations']={}
 for cap,(scalar,profiles)in series.items():
  answer['supplemental_observations'][str(cap)]=dict(groundwater_16_profile_max_difference_cm=max(abs(p['groundwater_cm']-float(scalar[day]['GWL']))for day,p in points.items()),reference_rain_cm=math.fsum(float(r['RAIN'])for r in scalar[1:]),reference_irrigation_cm=math.fsum(float(r['IRRIG'])for r in scalar[1:]),reference_drainage_cm=math.fsum(float(r['DRN'])for r in scalar[1:]),reference_final_solute_stock_mg_cm2=float(scalar[-1]['S_STOT']),reference_external_solute_input_mg_cm2=math.fsum(float(r['S_RAIN'])+float(r['S_IRRIG'])for r in scalar[1:]),reference_external_solute_output_mg_cm2=math.fsum(float(r['S_DRN'])+float(r['S_UPT'])for r in scalar[1:]))
 answer['native_cumulative_flux_cm']={key:math.fsum(r[key]for r in daily)for key in ['infiltration_cm','runon_cm','runoff_cm','pond_evaporation_cm','soil_evaporation_cm','potential_transpiration_cm','actual_transpiration_cm','drought_reduction_cm','oxygen_reduction_cm','salinity_reduction_cm','drainage_cm']}
 if original:
  r=json.loads((original/'RESULT.json').read_text());assert r['status']=='DIAGNOSTIC_FULL_EXECUTIONS_COMPLETE'and r['phase']=='reference'
  assert all(e['returncode']==100 and not e['censored']for e in r['events'])
  for cap in [.000625,.0003125]:series[cap]=reference(original/('dtmax-'+str(cap)))
  finest=min(series);n,ref,_,_=features(*series[finest],daily,crop,points);_,prior,_,_=features(*series[finest*2],daily,crop,points)
  answer['finest_reference_dtmax']=finest;answer['coarse_native_vs_finest']={k:dict(error=distance(k,n[k],ref[k]),original_frozen_limit=bounds[k]['limit'],inside_original_frozen_bound=distance(k,n[k],ref[k])<=bounds[k]['limit'],latest_reference_change=distance(k,prior[k],ref[k]))for k in n}
  if native:
   fd,fc,fp,fa=diagnostic_native(native,sorted(points));fn,fr,_,_=features(*series[finest],fd,fc,fp);answer['fine_native_accounting']=fa
   answer['fine_native_vs_finest']={k:dict(error=distance(k,fn[k],fr[k]),coarse_error=distance(k,n[k],ref[k]),original_frozen_limit=bounds[k]['limit'],inside_original_frozen_bound=distance(k,fn[k],fr[k])<=bounds[k]['limit'])for k in fn}
 return answer

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--study',type=Path,required=True);p.add_argument('--original',type=Path);p.add_argument('--native',type=Path);p.add_argument('--output',type=Path,required=True);a=p.parse_args();result=analyze(a.study,a.original,a.native);a.output.write_text(json.dumps(result,indent=2)+'\n',newline='\n');print(json.dumps({k:v for k,v in result.items()if k not in ['accounting','frozen_assessment','coarse_native_vs_finest','fine_native_vs_finest']},indent=2))

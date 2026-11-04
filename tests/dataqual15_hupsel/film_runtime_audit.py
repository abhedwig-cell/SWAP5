"""Bounded584-day complete ledger and observational/own-restart audit."""
import argparse,collections,csv,hashlib,json,math
from pathlib import Path
from film_runtime_profiles import profile4

def rows(path):
 with path.open(newline='')as stream:return list(csv.DictReader(stream))

def ledger(windows,crops,point,state):
 assert windows and windows[0]['t0_day']==0 and windows[-1]['t1_day']==584
 assert all(a['t1_day']==b['t0_day']for a,b in zip(windows,windows[1:]))
 assert all(r['t1_day']>r['t0_day']and all(math.isfinite(x)for x in r.values())for r in windows)
 grouped=collections.defaultdict(list);proof={}
 for r in windows:grouped[int(math.ceil(r['t1_day']-1e-9))].append(r)
 assert sorted(grouped)==list(range(1,585))
 daily=[]
 for day,parts in sorted(grouped.items()):
  assert parts[0]['t0_day']==day-1 and parts[-1]['t1_day']==day
  row={k:math.fsum(r[k]for r in parts)for k in parts[0]};row['t0_day']=day-1;row['t1_day']=day
  for p,u in [('water','cm'),('solute','mg_cm2')]:row[p+'_start_'+u]=parts[0][p+'_start_'+u];row[p+'_end_'+u]=parts[-1][p+'_end_'+u]
  daily.append(row)
 for p,u in [('water','cm'),('solute','mg_cm2')]:
  names=[p+'_'+x+'_'+u for x in ('start','end','in','out')]
  defects=[abs(r[names[1]]-r[names[0]]-r[names[2]]+r[names[3]])for r in windows]
  reported=max(abs(r[p+'_residual_'+u])for r in windows)
  continuity=max(abs(a[names[1]]-b[names[0]])for a,b in zip(windows,windows[1:]))
  daily_defect=max(abs(r[names[1]]-r[names[0]]-r[names[2]]+r[names[3]])for r in daily)
  cumulative=windows[-1][names[1]]-windows[0][names[0]]-math.fsum(r[names[2]]for r in windows)+math.fsum(r[names[3]]for r in windows)
  assert max(defects)<=1e-10 and reported<=1e-10 and continuity<=1e-10 and daily_defect<=1e-10 and abs(cumulative)<=1e-8
  proof[p]=dict(maximum_interval_defect=max(defects),maximum_reported_residual=reported,maximum_continuity_defect=continuity,maximum_daily_defect=daily_defect,cumulative_defect=cumulative)
 assert [int(r['day'])for r in crops]==list(range(495,585))
 byday={int(r['day']):r for r in crops}
 for r in crops:
  stock,capacity=float(r['accepted_canopy_stock_cm']),float(r['post_management_capacity_cm'])
  assert math.isfinite(stock)and math.isfinite(capacity)and 0<=stock<=capacity
 for r in daily:
  export=r['canopy_capacity_export_cm'];assert 0<=export<=r['water_out_cm']+1e-10
  if r['t1_day']<495:assert export==0
  else:
   canopy_out=r['water_out_cm']-math.fsum(r[k]for k in ('soil_evaporation_cm','pond_evaporation_cm','actual_transpiration_cm','drainage_cm','runoff_cm'))
   assert export<=canopy_out+1e-10
 assert point['day']==584 and len(state)==34
 for key in ('z_cm','dz_cm','head_cm','theta','concentration_mg_cm3','dissolved_mg_cm2','sorbed_mg_cm2'):assert point[key]==[float(r[key])for r in state],key
 assert abs(point['water_stock_cm']-daily[-1]['water_end_cm'])<=1e-10
 assert abs(point['solute_stock_mg_cm2']-daily[-1]['solute_end_mg_cm2'])<=1e-10
 assert point['canopy_cm']==float(byday[584]['accepted_canopy_stock_cm'])
 return dict(status='COMPLETE584_INTERVAL_DAILY_MASS_CROP_AND_TYPED_PRIMITIVES_PASS',days=584,intervals=len(windows),crop_rows=len(crops),ledgers=proof,wet_cut_scope='930/956/989/1033_OUTSIDE_PREFIX_NOT_EXERCISED',production_admission=False,whole_scientific_admission=False)

def audit(folder):
 case=folder/'unobserved584';run=json.loads((case/'RESULT.json').read_text());build=json.loads((folder/'build/BUILD.json').read_text())
 sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
 assert run['scope']=='ORIGINAL_INPUT_INITIALIZATION'and run['returncode']==0 and run['restart_sha256']is None and not run['diagnostic_override']
 assert run['executable_sha256']==build['executable_sha256']
 assert all(sha(case/n)==pin for n,pin in run['inputs'].items())
 windows=[{k:float(v)for k,v in row.items()}for row in rows(case/'budget.csv')]
 result=ledger(windows,rows(case/'crop.csv'),profile4((case/'checkpoint.bin').read_bytes()),rows(case/'state.csv'))
 strict=folder/'strict584';restart=json.loads((strict/'RESULT.json').read_text())
 assert restart['scope']=='STRICT_OWN_BUILD_RESTART'and restart['executable_sha256']==run['executable_sha256']and restart['returncode']==0 and not restart['diagnostic_override']
 assert (strict/'checkpoint.bin').read_bytes()==(case/'checkpoint.bin').read_bytes()
 for name in ('budget.csv','crop.csv'):
  suffix=rows(strict/name);assert suffix;key=next(iter(suffix[0]));whole={r[key]:r for r in rows(case/name)};assert all(r==whole[r[key]]for r in suffix)
 result['strict_own583_endpoint_and_suffix_exact']=True
 if(folder/'observed584').exists():
  observed=folder/'observed584'
  for name in ('checkpoint.bin','budget.csv','crop.csv','state.csv'):assert (case/name).read_bytes()==(observed/name).read_bytes()
  receipts=rows(observed/'film_runtime_receipts.csv');last=receipts[-1];assert float(last['time_day'])==584 and int(last['calls'])>0
  assert int(last['max_level'])<=24 and int(last['refinements'])<=23*int(last['calls'])
  assert all(int(b['calls'])>=int(a['calls'])for a,b in zip(receipts,receipts[1:]))
  result['observation']=dict(scope='ATTEMPTED_CALLS_INCLUDE_REJECTED_TRIALS_NOT_ACCEPTED_FLUX',physical_outputs_exact=True,final_receipt=last)
 else:result['observation']='O0_COUNTER_TRAJECTORY_NOT_SELECTED'
 return result

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--runtime',type=Path,required=True);a=p.parse_args();result=audit(a.runtime.resolve());(a.runtime/'AUDIT.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))

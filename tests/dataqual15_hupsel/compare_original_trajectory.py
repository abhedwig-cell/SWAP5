"""Compare actual original Hupsel receipts; does not run or qualify a model."""
import argparse,collections,csv,datetime,hashlib,json,math,re
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--donor',type=Path,required=True);p.add_argument('--native',type=Path,nargs='+',required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();a.output.mkdir(exist_ok=True)
lines=(a.donor/'result_output.csv').read_text().splitlines();header=next(i for i,s in enumerate(lines) if s.startswith('DATE,'));donor={r['DATE'].strip():r for r in csv.DictReader(lines[header:])}
start=datetime.date.fromisoformat(re.search(r'^\s*TSTART\s*=\s*(\d{4}-\d{2}-\d{2})',(a.native[0]/'swap.swp').read_text(),re.M).group(1))
water=[];crop=[];source_files=[];intervals=0;bindings=[]
for direct in a.native:
 record_file=direct/('RESULT.json' if (direct/'RESULT.json').exists() else 'CENSOR.json')
 record=json.loads(record_file.read_text())
 builddir=Path(record['command'][0]).parent if 'command' in record else Path(record['source_build'])
 build_file=builddir/'BUILD.json';build=json.loads(build_file.read_text());exe=builddir/'swap5_hupsel_germination'
 actual_exe_hash=hashlib.sha256(exe.read_bytes()).hexdigest();assert actual_exe_hash==build['executable_sha256']
 inputs=[direct/n for n in ['swap.swp','maize.crp','potato.crp','grass.crp','swap.dra','283.met']]
 bindings.append({'receipt':str(direct),'build':str(build_file),'executable':str(exe),'executable_sha256':actual_exe_hash,'compiler':build['compiler'],'flags':build['flags'],'source_sha256':build['source_sha256'],'executed_input_sha256':{str(f):hashlib.sha256(f.read_bytes()).hexdigest() for f in inputs},'original_input_sha256':record.get('original_inputs_sha256'),'record_sha256':hashlib.sha256(record_file.read_bytes()).hexdigest()})
 source_files.append(build_file);source_files.extend(inputs)
 grouped=collections.defaultdict(list)
 for r in csv.DictReader((direct/'budget.csv').open()):
  grouped[math.ceil(float(r['t1_day'])-1e-9)].append(r);intervals+=1
 for day,parts in sorted(grouped.items()):
  assert abs(float(parts[0]['t0_day'])-(day-1))<1e-9 and abs(float(parts[-1]['t1_day'])-day)<1e-9,'Only complete accepted days are comparable'
  for left,right in zip(parts,parts[1:]):assert abs(float(left['t1_day'])-float(right['t0_day']))<1e-9
  date=str(start+datetime.timedelta(days=day-1));d=donor[date];r=parts[-1]
  n=lambda k:sum(float(x[k]) for x in parts)
  f=lambda k:float(d[k])
  # The native simple-maize interceptor is outside the water carrier. Rutter
  # potato interception is inside it. Both consume the same original gross
  # rainfall/manual gifts; restore the external maize interception to total ET.
  outside_interception=f('RAIN')+f('IRRIG')-n('water_in_cm')
  et=n('water_out_cm')-n('drainage_cm')-n('runoff_cm')+outside_interception
  eic=et-n('soil_evaporation_cm')-n('pond_evaporation_cm')-n('actual_transpiration_cm')
  total=f('WTOT')+f('PD_VOL')+f('IC_VOL')
  w=dict(day=day,date=date,source=str(direct),water=float(r['water_end_cm']),donor_water=total,solute=float(r['solute_end_mg_cm2']),donor_solute=f('S_STOT'))
  w.update(water_diff=w['water']-total,solute_diff=w['solute']-f('S_STOT'),outside_carrier_interception_cm=outside_interception,eact_diff=n('soil_evaporation_cm')-f('EACT'),ptra_diff=n('potential_transpiration_cm')-f('TPOT'),tra_diff=n('actual_transpiration_cm')-f('TACT'),epd_diff=n('pond_evaporation_cm')-f('EPD'),eic_diff=eic-f('EIC'),total_et_diff=et-sum(f(k) for k in ['EIC','EPD','EACT','TACT']),runoff_diff=n('runoff_cm')-f('RUNOFF'),drainage_diff=n('drainage_cm')-f('DRN'),solute_external_out_diff=n('solute_out_mg_cm2')-f('S_DRN')-f('S_UPT'),solute_external_in_diff=n('solute_in_mg_cm2')-f('S_RAIN')-f('S_IRRIG'),maximum_daily_water_mass_residual=max(abs(float(x['water_residual_cm'])) for x in parts),maximum_daily_solute_mass_residual=max(abs(float(x['solute_residual_mg_cm2'])) for x in parts))
  water.append(w)
 for r in csv.DictReader((direct/'crop.csv').open()):
  day=int(r['day'])
  if day<524:continue # inactive donor crop uses the historical -999.999 sentinel
  date=str(start+datetime.timedelta(days=day-1));d=donor[date];out=dict(day=day,date=date,source=str(direct))
  for k in ['dvs','tsum','lai','wrt','wlv','wst','wso','pwrt','pwlv','pwst','pwso','rd','rdpot']:
   out[k]=float(r[k]);out['donor_'+k]=float(d[k.upper()]);out[k+'_diff']=out[k]-out['donor_'+k]
  crop.append(out)
 source_files.extend([direct/'budget.csv',direct/'crop.csv',direct/'swap.swp',direct/'potato.crp'])
 source_files.extend(f for f in [direct/'RESULT.json',direct/'CENSOR.json'] if f.exists())
assert len({r['day'] for r in water})==len(water),'Overlapping native receipts require explicit candidate selection'
for name,rows in [('water',water),('crop',crop)]:
 with (a.output/(name+'.csv')).open('w') as f:w=csv.DictWriter(f,fieldnames=rows[0].keys());w.writeheader();w.writerows(rows)
def summarize(rows,lo,hi):
 rr=[r for r in rows if lo<=r['day']<=hi]
 if not rr:return None
 diffs=[k for k in rr[0] if k.endswith('_diff')]
 return {'requested_days':[lo,hi],'observed_days':len(rr),'signed_difference_at_largest_absolute':{k:{'difference':max(rr,key=lambda x:abs(x[k]))[k],'day':max(rr,key=lambda x:abs(x[k]))['day']} for k in diffs},'endpoint':rr[-1],'sum_daily_et_difference_over_observed_days_only':sum(r.get('total_et_diff',0) for r in rr)}
periods=[(1,120),(121,365),(366,494),(495,523),(524,537),(538,543),(549,566)]
manifest={'status':'OBSERVED_ORIGINAL_RECEIPT_COMPARISON_NO_EQUIVALENCE_CLAIM','donor_binding':json.loads((a.donor/'LAUNCH.json').read_text()),'native_sources':[str(d) for d in a.native],'source_and_executable_bindings':bindings,'accepted_intervals_aggregated':intervals,'complete_observed_days':len(water),'continuous_potato_crop_days':len(crop),'crop_missing_days':[d for d in range(524,567) if d not in {r['day'] for r in crop}],'missing_days':[d for d in range(1,max(r['day'] for r in water)+1) if d not in {r['day'] for r in water}],'water_summary':[summarize(water,*v) for v in periods],'crop_summary':[x for v in periods if (x:=summarize(crop,*v))],'water_all_observed':summarize(water,1,566),'crop_all_observed':summarize(crop,524,566),'input_sha256':{str(f):hashlib.sha256(f.read_bytes()).hexdigest() for f in source_files+[a.donor/'result_output.csv']},'not_compared':['native groundwater head not in receipts','soil profile moisture distribution','heat profile and donor energy balance','maize biomass: not in native crop receipt','water/solute budgets days544-548 unflushed after censored process; crop observations are present','corrected PONDMX/RSRO source34976ba: not these earlier receipts'],'total_stock_definition':'native carrier soil+pond+Rutter canopy versus donor WTOT+PD_VOL+IC_VOL; source SWBOTB6 no bottom water flux; no macropores or snow','et_definition':'soil+pond+transpiration+canopy; restore simple maize interception outside native carrier using identical original gross rain/manual gifts; canopy ET within Rutter carrier is derived from other measured outputs'}
(a.output/'COMPARISON.json').write_text(json.dumps(manifest,indent=2)+'\n');print(json.dumps({k:manifest[k] for k in ['status','accepted_intervals_aggregated','complete_observed_days','missing_days']},indent=2))

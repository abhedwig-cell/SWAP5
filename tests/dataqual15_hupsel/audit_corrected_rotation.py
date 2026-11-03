"""Independent complete ledger of the corrected native diagnostic rotation.

Reads real outputs/typed streams only. Frozen original-reference limits are
reused verbatim; their failures and the whole-science refusal remain explicit.
"""
import argparse,collections,copy,csv,hashlib,json,math,re,tarfile
from pathlib import Path
from inspect_profiles import profile
from scientific_followup import features,distance,rows
ROOT=Path(__file__).resolve().parents[2]
sha=lambda raw:hashlib.sha256(raw).hexdigest()

def ledger(daily,crops,points,days):
 assert len(daily)==days and [r['t1_day']for r in daily]==list(range(1,days+1))
 assert [r['t0_day']for r in daily]==list(range(days))
 assert all(math.isfinite(x)for r in daily for x in r.values())
 checks={};previous=None
 for prefix,unit in [('water','cm'),('solute','mg_cm2')]:
  names=[prefix+'_'+part+'_'+unit for part in ('start','end','in','out')]
  residual=prefix+'_residual_'+unit
  defects=[r[names[1]]-r[names[0]]-r[names[2]]+r[names[3]]for r in daily]
  assert max(map(abs,defects))<=1e-10 and max(abs(r[residual])for r in daily)<=1e-10
  continuity=max((abs(a[names[1]]-b[names[0]])for a,b in zip(daily,daily[1:])),default=0.)
  assert continuity<=1e-10
  cumulative=daily[-1][names[1]]-daily[0][names[0]]-math.fsum(r[names[2]]for r in daily)+math.fsum(r[names[3]]for r in daily)
  assert abs(cumulative)<=1e-8
  checks[prefix]=dict(maximum_independent_daily_defect=max(map(abs,defects)),maximum_continuity_defect=continuity,cumulative_independent_defect=cumulative)
 byday={int(r['day']):r for r in crops};assert len(byday)==len(crops)
 assert all(1<=d<=days for d in byday)
 for r in crops:
  stock,capacity=float(r['accepted_canopy_stock_cm']),float(r['post_management_capacity_cm'])
  assert math.isfinite(stock)and math.isfinite(capacity)and 0<=stock<=capacity
 for r in daily:
  export=r['canopy_capacity_export_cm'];assert export>=0
  canopy_out=r['water_out_cm']-math.fsum(r[k]for k in ['soil_evaporation_cm','pond_evaporation_cm','actual_transpiration_cm','drainage_cm','runoff_cm'])
  assert export<=canopy_out+1e-10
 cuts=[]
 for day in (930,956,989,1033):
  r=daily[day-1];crop=byday[day]
  assert float(crop['cut_index'])>float(byday[day-1]['cut_index'])
  assert r['canopy_capacity_export_cm']>0
  assert float(crop['accepted_canopy_stock_cm'])==float(crop['post_management_capacity_cm'])
  assert daily[day]['canopy_capacity_export_cm']==0
  cuts.append(dict(day=day,export_cm=r['canopy_capacity_export_cm'],accepted_stock_cm=float(crop['accepted_canopy_stock_cm'])))
 stock_checks=[]
 for day,p in sorted(points.items()):
  r=daily[day-1]
  dw=p['water_stock_cm']-r['water_end_cm'];ds=p['solute_stock_mg_cm2']-r['solute_end_mg_cm2']
  assert abs(dw)<=1e-10 and abs(ds)<=1e-10
  assert p['canopy_cm']==float(byday[day]['accepted_canopy_stock_cm'])
  stock_checks.append(dict(day=day,independent_water_stock_error_cm=dw,independent_solute_stock_error_mg_cm2=ds))
 return dict(ledgers=checks,wet_cuts=cuts,typed_primitive_stock_checks=stock_checks,total_capacity_export_cm=math.fsum(r['canopy_capacity_export_cm']for r in daily))

def audit(case,bundle):
 result=json.loads((case/'RESULT.json').read_text());build=json.loads((bundle/'BUILD.json').read_text())
 assert result['returncode']==0 and result['from_start']and result['restart_sha256']is None
 assert result['executable_sha256']==build['executable_sha256']
 for path,pin in build['source_sha256'].items():assert sha(Path(path).read_bytes())==pin,path
 assert all(sha((case/n).read_bytes())==pin for n,pin in result['inputs'].items())
 original=ROOT/'reference/swap-4.3.1/projects/1.hupselbrook'
 pattern=rb'(?im)^(\s*DTMAX\s*=\s*)([\d.eE+\-]+)'
 current=(case/'swap.swp').read_bytes();assert len(re.findall(pattern,current))==1
 assert float(re.search(pattern,current)[2])==.01
 normalize=lambda raw:re.sub(pattern,lambda m:m[1]+b'REGISTERED_DTMAX',raw)
 assert normalize(current)==normalize((original/'swap.swp').read_bytes())
 for name in ('maize.crp','potato.crp','grass.crp','283.met','swap.dra'):assert (case/name).read_bytes()==(original/name).read_bytes(),name
 daily=[{k:float(v)for k,v in row.items()}for row in csv.DictReader((case/'budget.csv').open())]
 crops=list(csv.DictReader((case/'crop.csv').open()))
 points={d:profile((case/f'checkpoint-{d}.bin').read_bytes())for d in (930,956,989,1033,1058,1077,1096)}
 assert all(p['day']==d for d,p in points.items())
 assert (case/'checkpoint.bin').read_bytes()==(case/'checkpoint-1096.bin').read_bytes()
 proof=ledger(daily,crops,points,1096)
 negatives=[]
 for name in ('water_export','solute_export','continuity','canopy_bound','duplicate_cut_export','primitive_stock'):
  d,c,p=copy.deepcopy((daily,crops,points))
  if name=='water_export':d[100]['water_out_cm']+=1e-6
  elif name=='solute_export':d[100]['solute_out_mg_cm2']+=1e-6
  elif name=='continuity':d[100]['water_start_cm']+=1e-6;d[100]['water_end_cm']+=1e-6
  elif name=='canopy_bound':c[-1]['accepted_canopy_stock_cm']=str(float(c[-1]['post_management_capacity_cm'])+1e-6)
  elif name=='duplicate_cut_export':d[930]['water_in_cm']+=1e-6;d[930]['water_out_cm']+=1e-6;d[930]['canopy_capacity_export_cm']=1e-6
  else:p[1096]['water_stock_cm']+=1e-6
  try:ledger(d,c,p,1096)
  except AssertionError:negatives.append(dict(control=name,rejected=True))
  else:raise AssertionError('independent auditor accepted injected defect: '+name)
 manifest=json.loads((ROOT/'integration/dataqual15_hupsel/SPRINT03_SCIENCE_MANIFEST.json').read_text())
 archive=ROOT/'integration/dataqual15_hupsel'/manifest['archive'];assert sha(archive.read_bytes())==manifest['archive_sha256']
 with tarfile.open(archive)as t:
  def get(n):
   raw=t.extractfile(n).read();assert sha(raw)==manifest['members'][n],n;return raw
  bounds_raw=get('science/FROZEN_BOUNDS_BEFORE_HOLDOUT.json');bounds=json.loads(bounds_raw)
  reference=rows(get('original/dtmax-0.0003125/result_output.csv'))
  profiles=collections.defaultdict(list)
  for r in rows(get('original/dtmax-0.0003125/hupsel_profiles.csv')):profiles[int(r['day'])].append(r)
 native,donor,_,_=features(reference,profiles,daily,crops,points)
 assert native.keys()==bounds.keys()
 assessment={key:dict(error=distance(key,native[key],donor[key]),limit=bounds[key]['limit'],inside_frozen_bound=distance(key,native[key],donor[key])<=bounds[key]['limit'])for key in native}
 return dict(status='COMPLETE_CORRECTED_CURRENT_DIAGNOSTIC_ROTATION_LEDGER_AND_CANOPY_PASS',days=1096,build=build,run=result,proof=proof,negative_controls=negatives,
             reference_archive_sha256=manifest['archive_sha256'],frozen_bounds_sha256=sha(bounds_raw),assessment=assessment,selected_profile_days=sorted(points),
             full_original_profile_schedule_qualified=False,whole_scientific_admission=False,
             scope='Current full diagnostic DTMAX0.01 trajectory, independent complete mass and canopy audit; frozen scalar comparisons and seven selected profile observations retain failures')

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--case',type=Path,required=True);p.add_argument('--bundle',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
 r=audit(a.case.resolve(),a.bundle.resolve());a.output.write_text(json.dumps(r,indent=2)+'\n');print(r['status']);print(json.dumps(r['assessment']['water_global']))

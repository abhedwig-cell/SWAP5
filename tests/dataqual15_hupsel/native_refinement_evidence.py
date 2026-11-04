"""Independent full-trajectory refinement audit; failures remain failures."""
import argparse,collections,copy,csv,hashlib,io,json,math,re,subprocess,sys,tarfile
from pathlib import Path
from inspect_profiles import profile
from scientific_followup import features,distance,rows
from full_profile_evidence import unpack,DAYS
ROOT=Path(__file__).resolve().parents[2];BASE=ROOT/'integration/dataqual15_hupsel'
STEM='NATIVE_REFINEMENT_EVIDENCE_20261104'
sha=lambda b:hashlib.sha256(b).hexdigest()
norm=lambda p:sha(p.read_bytes().replace(b'\r\n',b'\n'))
csv_rows=lambda b:list(csv.DictReader(io.StringIO(b.decode())))
PATTERN=rb'(?im)^(\s*DTMAX\s*=\s*)([\d.eE+\-]+)'

def inputs(files,cap,prior):
 raw=files['full-O2/swap.swp'];found=re.findall(PATTERN,raw);assert len(found)==1 and float(found[0][1])==cap
 normalize=lambda b:re.sub(PATTERN,lambda m:m[1]+b'REGISTERED_NUMERIC_DTMAX',b)
 assert normalize(raw)==normalize(prior['case/swap.swp'])
 for n in ('input.nml','maize.crp','potato.crp','grass.crp','283.met','swap.dra'):assert files['full-O2/'+n]==prior['case/'+n],n
 for phase in ('full-O2','strict-O2-1088','compatible-O0-1077','strict-O0-1088'):
  r=json.loads(files[phase+'/RESULT.json']);assert r['returncode']==0
  for n,pin in r['inputs'].items():
   assert files[phase+'/'+n]==files['full-O2/'+n] and sha(files[phase+'/'+n])==pin
  if phase=='full-O2':assert r['from_start'] and r['restart_sha256'] is None and r['scope']=='FROM_INPUT_MEASUREMENT'
  else:
   seed=('full-O2/checkpoint-1077.bin' if phase=='compatible-O0-1077' else
         ('compatible-O0-1077/checkpoint-1088.bin' if phase=='strict-O0-1088' else 'full-O2/checkpoint-1088.bin'))
   assert not r['from_start'] and r['restart_sha256']==sha(files[seed])
   expected='INPUT_BOUND_SAME_PLATFORM_PRIOR_BUILD_CODEC_CONTROL_NOT_RESTART_QUALIFICATION' if phase=='compatible-O0-1077' else 'STRICT_SAME_BUILD_RESTART_MEASUREMENT'
   assert r['scope']==expected

def conservation(daily,crops,points):
 assert len(daily)==1096 and [r['t1_day'] for r in daily]==list(range(1,1097))
 assert [r['t0_day'] for r in daily]==list(range(1096))
 assert all(math.isfinite(x) for r in daily for x in r.values())
 result={}
 for prefix,unit in [('water','cm'),('solute','mg_cm2')]:
  start=prefix+'_start_'+unit;end=prefix+'_end_'+unit;incoming=prefix+'_in_'+unit;outgoing=prefix+'_out_'+unit
  defects=[r[end]-r[start]-r[incoming]+r[outgoing] for r in daily]
  assert max(map(abs,defects))<=1e-10 and max(abs(r[prefix+'_residual_'+unit]) for r in daily)<=1e-10
  assert max(abs(a[end]-b[start]) for a,b in zip(daily,daily[1:]))<=1e-10
  cumulative=daily[-1][end]-daily[0][start]-math.fsum(r[incoming] for r in daily)+math.fsum(r[outgoing] for r in daily)
  assert abs(cumulative)<=1e-8
  result[prefix]=dict(maximum_independent_daily_defect=max(map(abs,defects)),cumulative_independent_defect=cumulative)
 assert [int(r['day']) for r in crops]==list(range(495,1097))
 for r in crops:
  stock=float(r['accepted_canopy_stock_cm']);capacity=float(r['post_management_capacity_cm'])
  assert math.isfinite(stock) and math.isfinite(capacity) and 0<=stock<=capacity
 assert sorted(points)==list(DAYS)
 primitive=[]
 for day,p in sorted(points.items()):
  assert p['day']==day
  dw=p['water_stock_cm']-daily[day-1]['water_end_cm'];ds=p['solute_stock_mg_cm2']-daily[day-1]['solute_end_mg_cm2']
  assert abs(dw)<=1e-10 and abs(ds)<=1e-10
  if day>=495:assert p['canopy_cm']==float(crops[day-495]['accepted_canopy_stock_cm'])
  primitive.append(dict(day=day,water_error_cm=dw,solute_error_mg_cm2=ds))
 for r in daily:assert 0<=r['canopy_capacity_export_cm']<=r['water_out_cm']+1e-10
 return dict(complete_ledgers=result,primitive_profiles=primitive)

def measure(files,cap,prior,reference,builds):
 inputs(files,cap,prior)
 assert json.loads(files['full-O2/RESULT.json'])['executable_sha256']==builds['O2']['executable_sha256']
 for p in ('strict-O2-1088','compatible-O0-1077','strict-O0-1088'):
  assert json.loads(files[p+'/RESULT.json'])['executable_sha256']==builds['O2' if p.startswith('strict-O2') else 'O0']['executable_sha256']
 windows=[{k:float(v) for k,v in r.items()} for r in csv_rows(files['full-O2/budget.csv'])]
 old=csv_rows(prior['case/budget.csv'])
 assert [(r['t0_day'],r['t1_day']) for r in windows]==[(float(r['t0_day']),float(r['t1_day'])) for r in old]
 grouped=collections.defaultdict(list)
 for r in windows:
  assert r['t1_day']>r['t0_day'] and all(math.isfinite(v) for v in r.values())
  for p,u in [('water','cm'),('solute','mg_cm2')]:assert abs(r[p+'_end_'+u]-r[p+'_start_'+u]-r[p+'_in_'+u]+r[p+'_out_'+u])<=1e-10
  grouped[int(math.ceil(r['t1_day']-1e-9))].append(r)
 daily=[]
 for day,parts in sorted(grouped.items()):
  assert parts[0]['t0_day']==day-1 and parts[-1]['t1_day']==day
  assert all(a['t1_day']==b['t0_day'] for a,b in zip(parts,parts[1:]))
  r={k:math.fsum(x[k] for x in parts) for k in parts[0]};r['t0_day']=day-1;r['t1_day']=day
  for p,u in [('water','cm'),('solute','mg_cm2')]:r[p+'_start_'+u]=parts[0][p+'_start_'+u];r[p+'_end_'+u]=parts[-1][p+'_end_'+u]
  daily.append(r)
 crops=csv_rows(files['full-O2/crop.csv']);points={d:profile(files[f'full-O2/checkpoint-{d}.bin']) for d in DAYS}
 assert files['full-O2/checkpoint.bin']==files['full-O2/checkpoint-1096.bin']
 proof=conservation(daily,crops,points)
 controls=[]
 for label in ('missing_day','water_export','solute_export','profile_stock','missing_profile','canopy_bound'):
  d,c,p=copy.deepcopy((daily,crops,points))
  if label=='missing_day':d.pop(100)
  elif label=='water_export':d[100]['water_out_cm']+=1e-6
  elif label=='solute_export':d[100]['solute_out_mg_cm2']+=1e-6
  elif label=='profile_stock':p[120]['solute_stock_mg_cm2']+=1e-6
  elif label=='missing_profile':del p[120]
  else:c[-1]['accepted_canopy_stock_cm']=str(float(c[-1]['post_management_capacity_cm'])+1e-6)
  try:conservation(d,c,p)
  except AssertionError:controls.append(dict(control=label,rejected=True))
  else:raise AssertionError('accepted refinement defect '+label)
 for whole,tail in [('full-O2','strict-O2-1088'),('compatible-O0-1077','strict-O0-1088')]:
  assert files[whole+'/checkpoint.bin']==files[tail+'/checkpoint.bin']
  for n,clock in [('budget.csv','t1_day'),('crop.csv','day')]:
   assert [r for r in csv_rows(files[whole+'/'+n]) if float(r[clock])>1088]==csv_rows(files[tail+'/'+n])
 source=rows(reference['original/dtmax-0.0003125/result_output.csv']);profiles=collections.defaultdict(list)
 for r in rows(reference['original/dtmax-0.0003125/hupsel_profiles.csv']):profiles[int(r['day'])].append(r)
 native,donor,_,_=features(source,profiles,daily,crops,points);bounds=json.loads(reference['science/FROZEN_BOUNDS_BEFORE_HOLDOUT.json'])
 assessment={k:dict(error=distance(k,native[k],donor[k]),limit=bounds[k]['limit'],inside_frozen_bound=distance(k,native[k],donor[k])<=bounds[k]['limit']) for k in native}
 assert assessment.keys()==bounds.keys()
 return dict(cap_day=cap,proof=proof,negative_controls=controls,assessment=assessment,
             retained_failures=[k for k,v in assessment.items() if not v['inside_frozen_bound']],
             feature_values=native,source_window_count=len(windows),days=1096,
             run=json.loads(files['full-O2/RESULT.json']),strict_O0_O2_own_tails_exact=True,
             whole_scientific_admission=False)

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--capture',type=Path);a=p.parse_args()
 subprocess.run([sys.executable,'-B',str(ROOT/'tests/dataqual15_hupsel/matched_solute_evidence.py')],cwd=ROOT,check=True)
 prior_record=json.loads((BASE/'FULL_PROFILE_EVIDENCE_20261104.json').read_text());prior=unpack(BASE/'FULL_PROFILE_EVIDENCE_20261104.tar.xz',prior_record['files_sha256'])
 build_record=json.loads((BASE/'CORRECTED_ROTATION_EVIDENCE_20261103.json').read_text());build_files=unpack(BASE/'CORRECTED_ROTATION_EVIDENCE_20261103.tar.xz',build_record['files_sha256'])
 builds={opt:json.loads(build_files[('build-O0' if opt=='O0' else 'build')+'/BUILD.json']) for opt in ('O0','O2')}
 m=json.loads((BASE/'SPRINT03_SCIENCE_MANIFEST.json').read_text());archive=BASE/m['archive'];assert sha(archive.read_bytes())==m['archive_sha256']
 with tarfile.open(archive) as t:
  ref={n:t.extractfile(n).read() for n in ('original/dtmax-0.0003125/result_output.csv','original/dtmax-0.0003125/hupsel_profiles.csv','science/FROZEN_BOUNDS_BEFORE_HOLDOUT.json')}
 assert all(sha(b)==m['members'][n] for n,b in ref.items())
 if a.capture:
  files={}
  for f in a.capture.resolve().rglob('*'):
   if f.is_file() and (f.suffix in ('.json','.bin','.csv','.nml','.swp','.crp','.met','.dra','.stdout','.stderr') or f.name in ('stdout','stderr')):
    files[f.relative_to(a.capture.resolve()).as_posix()]=f.read_bytes()
 else:
  record=json.loads((BASE/(STEM+'.json')).read_text());assert record['whole_scientific_admission'] is False
  for n,h in record['normalized_repository_dependency_sha256'].items():assert norm(ROOT/n)==h,n
  archive=BASE/(STEM+'.tar.xz');assert sha(archive.read_bytes())==record['archive_sha256'];files=unpack(archive,record['files_sha256'])
 reports={}
 for cap in (.005,.0025):
  prefix='cap-'+str(cap)+'/'
  subset={n[len(prefix):]:b for n,b in files.items() if n.startswith(prefix)}
  reports[str(cap)]=measure(subset,cap,prior,ref,builds)
  # A foreign cap's input ledger cannot be substituted, even if a codec can
  # represent the same physical state across numerical policies.
  other=.0025 if cap==.005 else .005;changed=dict(subset);changed['full-O2/swap.swp']=files['cap-'+str(other)+'/full-O2/swap.swp']
  try:inputs(changed,cap,prior)
  except AssertionError:reports[str(cap)]['foreign_variant_input_rejected']=True
  else:raise AssertionError('accepted foreign refinement source')
 baseline=json.loads(prior['MEASURED.json']);bounds=json.loads(ref['science/FROZEN_BOUNDS_BEFORE_HOLDOUT.json'])
 # Baseline feature values are reconstructed with the same original collector;
 # compare error trends, not a newly fitted acceptance limit.
 comparison={k:dict(unchanged_limit=bounds[k]['limit'],baseline_0_01_error=baseline['assessment'][k]['error'],
                   refined_0_005_error=reports['0.005']['assessment'][k]['error'],refined_0_0025_error=reports['0.0025']['assessment'][k]['error'],
                   error_decreases_each_refinement=baseline['assessment'][k]['error']>=reports['0.005']['assessment'][k]['error']>=reports['0.0025']['assessment'][k]['error']) for k in bounds}
 result=dict(status='ACTUAL_FULL_NATIVE_TEMPORAL_REFINEMENT_CONTROLS_AND_LEDGER_AUDITS_PASS',variants=reports,
             original_frozen_error_comparison=comparison,production_correction_qualified=False,whole_scientific_admission=False)
 if a.capture:
  files['AUDIT.json']=(json.dumps(result,indent=2)+'\n').encode();archive=BASE/(STEM+'.tar.xz')
  with tarfile.open(archive,'w:xz') as t:
   for n,b in sorted(files.items()):
    entry=tarfile.TarInfo(n);entry.size=len(b);entry.mtime=0;t.addfile(entry,io.BytesIO(b))
  inherited=json.loads((BASE/'MATCHED_SOLUTE_EVIDENCE_20261104.json').read_text());deps=dict(inherited['normalized_repository_dependency_sha256'])
  for n in ('tests/dataqual15_hupsel/qualify_native_refinement.py','tests/dataqual15_hupsel/native_refinement_evidence.py',
            '.github/workflows/hupsel-native-refinement.yml','integration/dataqual15_hupsel/NATIVE_REFINEMENT_PREREGISTRATION_20261104.json'):deps[n]=norm(ROOT/n)
  record=dict(status=result['status'],archive_sha256=sha(archive.read_bytes()),files_sha256={n:sha(b) for n,b in files.items()},
              normalized_repository_dependency_sha256=deps,whole_scientific_admission=False)
  (BASE/(STEM+'.json')).write_text(json.dumps(record,indent=2)+'\n',encoding='utf-8')
 else:assert result==json.loads(files['AUDIT.json'])
 print(result['status']);print(json.dumps({k:v['retained_failures'] for k,v in reports.items()}))

if __name__=='__main__':main()

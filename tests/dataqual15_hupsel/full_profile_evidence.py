"""Complete original profile schedule on the admitted diagnostic trajectory.

Actual Windows execution and portable data remeasurement remain distinct.
Neither a profile comparison nor its frozen-bound failure promotes physics.
"""
import argparse,collections,copy,csv,hashlib,io,json,math,subprocess,sys,tarfile,tempfile
from pathlib import Path,PurePosixPath,PureWindowsPath
from audit_corrected_rotation import audit
from inspect_profiles import profile
from scientific_followup import features,distance,rows
from verify_corrected_rotation_evidence import verify as verify_prior

ROOT=Path(__file__).resolve().parents[2]
BASE=ROOT/'integration/dataqual15_hupsel'
STEM='FULL_PROFILE_EVIDENCE_20261104'
DAYS=(120,365,494,524,537,566,584,591,603,636,730,731,868,1058,1077,1096)
sha=lambda b:hashlib.sha256(b).hexdigest()
normalized=lambda p:sha(p.read_bytes().replace(b'\r\n',b'\n'))

def unpack(path,pins):
 with tarfile.open(path) as t:
  members=t.getmembers()
  assert len({m.name for m in members})==len(members)
  assert all(m.isfile() and not PurePosixPath(m.name).is_absolute() and not PureWindowsPath(m.name).drive
             and '..' not in PurePosixPath(m.name).parts and '\\' not in m.name for m in members)
  files={m.name:t.extractfile(m).read() for m in members}
 assert {n:sha(b) for n,b in files.items()}==pins
 return files

def check_points(points,daily,geometry):
 assert sorted(points)==list(DAYS),'incomplete or expanded original schedule'
 proof=[]
 for day,p in sorted(points.items()):
  assert p['day']==day,'profile clock'
  for key in ('z_cm','dz_cm'):assert p[key]==geometry[key],key
  assert len(p['theta'])==34
  r=daily[day-1]
  dw=p['water_stock_cm']-r['water_end_cm'];ds=p['solute_stock_mg_cm2']-r['solute_end_mg_cm2']
  assert abs(dw)<=1e-10 and abs(ds)<=1e-10,'primitive profile stock versus daily owner'
  proof.append(dict(day=day,nodes=34,water_error_cm=dw,solute_error_mg_cm2=ds))
 return proof

def measure(case,bundle,prior_files,live):
 # The accepted independent complete-ledger/canopy auditor stays unchanged.
 inherited=audit(case,bundle,live_providers=live)
 for name in ('budget.csv','crop.csv','checkpoint.bin','state.csv','temperature.csv','endpoint.csv','germination.csv'):
  assert (case/name).read_bytes()==prior_files['case/'+name],name+' changed from accepted corrected trajectory'
 assert inherited['run']['executable_sha256']==json.loads(prior_files['build/BUILD.json'])['executable_sha256']
 points={d:profile((case/f'checkpoint-{d}.bin').read_bytes()) for d in DAYS}
 assert (case/'checkpoint-1096.bin').read_bytes()==(case/'checkpoint.bin').read_bytes()
 grouped=collections.defaultdict(list)
 for r in csv.DictReader((case/'budget.csv').open()):
  grouped[int(math.ceil(float(r['t1_day'])-1e-9))].append(r)
 daily=[{k:float(parts[-1][k]) for k in ('water_end_cm','solute_end_mg_cm2')} for _,parts in sorted(grouped.items())]
 geometry=profile(prior_files['case/checkpoint.bin']);proof=check_points(points,daily,geometry)
 controls=[]
 for name in ('missing_profile','misbound_clock','water_stock','solute_stock','geometry'):
  altered=copy.deepcopy(points)
  if name=='missing_profile':del altered[120]
  elif name=='misbound_clock':altered[120]['day']=121
  elif name=='water_stock':altered[120]['water_stock_cm']+=1e-6
  elif name=='solute_stock':altered[120]['solute_stock_mg_cm2']+=1e-6
  else:altered[120]['dz_cm'][0]+=1e-6
  try:check_points(altered,daily,geometry)
  except AssertionError:controls.append(dict(control=name,rejected=True))
  else:raise AssertionError('auditor accepted '+name)
 raw=bytearray((case/'checkpoint-120.bin').read_bytes());raw[30]^=1
 try:profile(bytes(raw))
 except AssertionError:controls.append(dict(control='raw_stream_corruption',rejected=True))
 else:raise AssertionError('accepted corrupt typed stream')
 manifest=json.loads((BASE/'SPRINT03_SCIENCE_MANIFEST.json').read_text())
 archive=BASE/manifest['archive'];assert sha(archive.read_bytes())==manifest['archive_sha256']
 with tarfile.open(archive) as t:
  def get(n):
   raw=t.extractfile(n).read();assert sha(raw)==manifest['members'][n];return raw
  bounds_raw=get('science/FROZEN_BOUNDS_BEFORE_HOLDOUT.json');bounds=json.loads(bounds_raw)
  reference=rows(get('original/dtmax-0.0003125/result_output.csv'))
  donor=collections.defaultdict(list)
  for r in rows(get('original/dtmax-0.0003125/hupsel_profiles.csv')):donor[int(r['day'])].append(r)
 # Profile feature extraction needs the accepted full daily rows; retain the
 # same original clock grouping and all original scalar/crop comparisons.
 full=[]
 for day,parts in sorted(grouped.items()):
  r={k:math.fsum(float(p[k]) for p in parts) for k in parts[0]}
  for prefix,unit in [('water','cm'),('solute','mg_cm2')]:
   r[prefix+'_start_'+unit]=float(parts[0][prefix+'_start_'+unit]);r[prefix+'_end_'+unit]=float(parts[-1][prefix+'_end_'+unit])
  full.append(r)
 native,original,_,_=features(reference,donor,full,list(csv.DictReader((case/'crop.csv').open())),points)
 assessment={k:dict(error=distance(k,native[k],original[k]),limit=bounds[k]['limit'],inside_frozen_bound=distance(k,native[k],original[k])<=bounds[k]['limit']) for k in native}
 per_day={}
 for day,p in sorted(points.items()):
  values=sorted(donor[day],key=lambda r:int(r['node']));assert len(values)==34
  per_day[str(day)]={}
  for key,column in [('head_cm','head_cm'),('theta','water_content'),('temperature_c','temperature_c'),('concentration_mg_cm3','concentration_mg_cm3')]:
   metric='profile_'+key;a=p[key];b=[float(r[column]) for r in values]
   errors=[distance(metric,[x],[y]) for x,y in zip(a,b)]
   index=max(range(34),key=errors.__getitem__)
   per_day[str(day)][key]=dict(maximum_error=errors[index],node=index+1,z_cm=p['z_cm'][index],
                              actual=a[index],reference=b[index],limit=bounds[metric]['limit'],
                              inside_frozen_bound=errors[index]<=bounds[metric]['limit'])
 return dict(status='COMPLETE_ORIGINAL16_PROFILE_MEASUREMENT_AND_EXACT_TRAJECTORY_PASS',days=list(DAYS),
             nodes_per_day=34,primitive_stock_proof=proof,negative_controls=controls,
             original_reference_profile_errors_by_day=per_day,
             assessment=assessment,retained_failures=[k for k,v in assessment.items() if not v['inside_frozen_bound']],
             reference_archive_sha256=manifest['archive_sha256'],frozen_bounds_sha256=sha(bounds_raw),
             accepted_seven_profile_audit=inherited,full_schedule_measured=True,
             full_schedule_inside_all_frozen_bounds=all(v['inside_frozen_bound'] for k,v in assessment.items() if k.startswith('profile_')),
             native_execution_platform='Windows checked O2; POSIX remeasures data only',whole_scientific_admission=False)

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--capture',action='store_true')
 p.add_argument('--case',type=Path);p.add_argument('--bundle',type=Path);a=p.parse_args()
 prior=verify_prior();prior_archive=BASE/'CORRECTED_ROTATION_EVIDENCE_20261103.tar.xz'
 old=unpack(prior_archive,prior['files_sha256'])
 if a.capture:
  assert a.case and a.bundle
  case=a.case.resolve();bundle=a.bundle.resolve()
  build=json.loads((bundle/'BUILD.json').read_text());assert build==json.loads(old['build/BUILD.json'])
  assert sha((bundle/'swap5_hupsel_germination.exe').read_bytes())==build['executable_sha256']
  measured=measure(case,bundle,old,True)
  files={'case/'+f.name:f.read_bytes() for f in case.iterdir() if f.is_file() and (f.suffix in ('.csv','.bin','.nml','.swp','.crp','.met','.dra','.json') or f.name in ('stdout','stderr'))}
  files['MEASURED.json']=(json.dumps(measured,indent=2)+'\n').encode()
  archive=BASE/(STEM+'.tar.xz')
  with tarfile.open(archive,'w:xz') as t:
   for n,b in sorted(files.items()):
    m=tarfile.TarInfo(n);m.size=len(b);m.mtime=0;t.addfile(m,io.BytesIO(b))
  deps=dict(prior['normalized_repository_dependency_sha256'])
  for n in ('tests/dataqual15_hupsel/full_profile_evidence.py','tests/dataqual15_hupsel/test_full_profile_evidence.py',
            '.github/workflows/hupsel-full-profile.yml','integration/dataqual15_hupsel/FULL_PROFILE_PREREGISTRATION_20261104.json'):
   deps[n]=normalized(ROOT/n)
  record=dict(status=measured['status'],baseline='4416bde2f3b1fbf04bac9edfe36ab7d758ad69b1',candidate=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
              archive_sha256=sha(archive.read_bytes()),files_sha256={n:sha(b) for n,b in files.items()},
              normalized_repository_dependency_sha256=deps,prior_manifest_sha256=normalized(BASE/'CORRECTED_ROTATION_EVIDENCE_20261103.json'),
              full_schedule_measured=True,retained_failures=measured['retained_failures'],whole_scientific_admission=False)
  (BASE/(STEM+'.json')).write_text(json.dumps(record,indent=2)+'\n',encoding='utf-8')
 else:
  record=json.loads((BASE/(STEM+'.json')).read_text());assert not record['whole_scientific_admission']
  for n,h in record['normalized_repository_dependency_sha256'].items():assert normalized(ROOT/n)==h,n
  assert normalized(BASE/'CORRECTED_ROTATION_EVIDENCE_20261103.json')==record['prior_manifest_sha256']
  archive=BASE/(STEM+'.tar.xz');assert sha(archive.read_bytes())==record['archive_sha256']
  files=unpack(archive,record['files_sha256'])
  with tempfile.TemporaryDirectory(prefix='swap5-full-profile-') as temp:
   root=Path(temp)
   for n,b in {**{n:b for n,b in old.items() if n.startswith('build/')},**files}.items():
    f=root/n;f.parent.mkdir(parents=True,exist_ok=True);f.write_bytes(b)
   measured=measure(root/'case',root/'build',old,False)
  assert measured==json.loads(files['MEASURED.json'])
  assert measured['retained_failures']==record['retained_failures'] and measured['full_schedule_measured'] is True
 print('SEALED_ORIGINAL16_PROFILE_MEASUREMENT_PASS_NOT_WHOLE_SCIENCE')
 print(json.dumps(measured['retained_failures']))

if __name__=='__main__':main()

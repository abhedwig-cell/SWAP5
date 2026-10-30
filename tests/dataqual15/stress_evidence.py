"""Package and independently check the measured Grassgrowth numerical study.

Keeps raw observations, paired real-owner outputs, immutable build bindings and
both successful and failed frozen gates. No executable is run by verification.
"""
import argparse,csv,hashlib,io,json,math,struct,subprocess,tarfile
from pathlib import Path,PurePosixPath,PureWindowsPath
from checkpoint_layout import layout,payload
from qualify_donor_timestep import register_envelope,assess_envelope
ROOT=Path(__file__).resolve().parents[2]
DEST=ROOT/'integration/dataqual15/STRESS_EVIDENCE.tar.xz'
MANIFEST=DEST.with_name('STRESS_EVIDENCE_MANIFEST.json')
sha=lambda raw:hashlib.sha256(raw).hexdigest()

def package(observations,whole,donor,thermal=None):
 files={};sources={};bindings={};origins={}
 def add(path,name):
  assert Path(path).is_file(),path;raw=Path(path).read_bytes();assert name not in files;files[name]=raw
 def tree(folder,prefix):
  for p in sorted(folder.rglob('*')):
   if p.is_file()and(p.suffix in ['.json','.csv','.bin','.f90','.dat','.swp','.crp','.met','.bbc','.dra','.stdout','.stderr']or p.name in ['stdout','stderr','application.binding','swap.ok','swap.log']):add(p,prefix+'/'+p.relative_to(folder).as_posix())
 for case in ['coarse','half','quarter']:
  folder=observations/case;add(folder/'observed_grass.f90','observations/'+case+'/observed_grass.f90')
  for name in ['BUILD.json','swap5_grass_startup','original_input_helpers.f90']:add(folder/'build'/name,'observations/'+case+'/build/'+name)
  tree(folder/'native','observations/'+case+'/native')
 add(observations/'observed_backend.f90','observations/observed_backend.f90');add(observations/'RESULT.json','observations/RESULT.json')
 for name in ['RESULT.json','grass.crp','accepted-oxygen-inputs.dat']:add(whole/name,'whole/'+name)
 tree(whole/'prepared-inputs','whole/prepared-inputs')
 for opt in ['O0','O2']:
  add(whole/('original-'+opt)/'BUILD.json','whole/original-'+opt+'/BUILD.json')
  for name in ['paired','accepted-oxygen.stdout',*[f'day-{d}.stdout'for d in [25,72,73,127]]]:add(whole/opt/name,'whole/'+opt+'/'+name)
 tree(donor,'donor');add(donor/'swap431','donor/swap431')
 if thermal:
  add(thermal/'RESULT.json','thermal/RESULT.json');add(thermal/'refined_grass.f90','thermal/refined_grass.f90');tree(thermal/'native','thermal/native')
  for name in ['BUILD.json','swap5_grass_startup','original_input_helpers.f90']:add(thermal/'build'/name,'thermal/build/'+name)
 # Resolve each executed source to the repository or an exact generated member.
 generated={sha(raw):name for name,raw in files.items()if name.endswith('.f90')}
 for member,raw in list(files.items()):
  if not member.endswith(('/BUILD.json','/application.binding','/RESULT.json')):continue
  record=json.loads(raw)
  mapping=record.get('source_sha256',{})
  if not mapping or member.startswith('whole/original-'):continue
  for path,digest in mapping.items():
   if path.startswith('/home/runner/work/SWAP5/SWAP5/'):relative=path.split('/home/runner/work/SWAP5/SWAP5/',1)[1]
   elif path.startswith(('src/','app/','tests/','tools/','reference/')):relative=path
   else:
    assert digest in generated,('unbound generated source',path);bindings[path+'#'+digest]=generated[digest];continue
   if sha((ROOT/relative).read_bytes())!=digest:
    assert relative=='tests/dataqual15/stress_oracle.f90',relative
    historical=subprocess.check_output(['git','show','e11ab92f4:'+relative],cwd=ROOT)
    assert sha(historical)==digest,('historical output-only oracle',relative)
    member='historical/'+digest+'-stress_oracle.f90';files[member]=historical;bindings[path+'#'+digest]=member
   else:sources[relative]=digest;bindings[path+'#'+digest]='repo:'+relative
 for path in ['tests/dataqual15/qualify_donor_timestep.py','tests/dataqual15/stress_oracle.f90','tests/dataqual15/stress_observations.inc','integration/dataqual15/STRESS_ATTRIBUTION_PREREGISTRATION.json','integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64','integration/audits/evidence/SWAP431_TTUTIL_AUTHORITY.zip.b64']:
  sources[path]=sha((ROOT/path).read_bytes())
 files['MANIFEST.json']=(json.dumps({name:sha(raw)for name,raw in sorted(files.items())},indent=2)+'\n').encode()
 with tarfile.open(DEST,'w:xz',preset=6)as tar:
  for name,raw in sorted(files.items()):
   info=tarfile.TarInfo(name);info.size=len(raw);info.mode=0o644;info.mtime=0;tar.addfile(info,io.BytesIO(raw))
 manifest=dict(status='MEASURED_EVIDENCE_WITH_FAILED_FROZEN_GATE',scope='SCIENTIFIC_ATTRIBUTION_NOT_WHOLE_MODEL_EQUIVALENCE',capsule_sha256=sha(DEST.read_bytes()),archive_files=len(files),source_sha256=sources,source_bindings=bindings,inherited_full_capsule_sha256=sha((ROOT/'integration/dataqual15/GRASS_UNION_FULL_EVIDENCE.tar.xz').read_bytes()),scientific_equivalence=False,original_preregistered_gate_pass=False,has_native_thermal=thermal is not None,github_runs=dict(observations=41069788879,whole=41071975005,donor=41074182323))
 MANIFEST.write_text(json.dumps(manifest,indent=2)+'\n',newline='\n');print('PACKAGED',len(files),'files',DEST.stat().st_size,'bytes',flush=True)

def verify():
 manifest=json.loads(MANIFEST.read_text());assert not manifest['scientific_equivalence']and not manifest['original_preregistered_gate_pass']
 for path,digest in manifest['source_sha256'].items():assert sha((ROOT/path).read_bytes())==digest,path
 raw=DEST.read_bytes();assert sha(raw)==manifest['capsule_sha256']
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz')as tar:
  members=tar.getmembers();assert len(members)==manifest['archive_files']==len({m.name for m in members})
  assert all(m.isfile()and not PurePosixPath(m.name).is_absolute()and not PureWindowsPath(m.name).drive and '..'not in PurePosixPath(m.name).parts and '\\'not in m.name for m in members)
  files={m.name:tar.extractfile(m).read()for m in members}
 assert json.loads(files.pop('MANIFEST.json'))=={name:sha(raw)for name,raw in sorted(files.items())}
 load=lambda name:json.loads(files[name])
 rows=lambda name:list(csv.DictReader(io.StringIO(files[name].decode())))
 for member,raw in files.items():
  if not member.endswith(('/BUILD.json','/application.binding','/RESULT.json'))or member.startswith('whole/original-'):continue
  record=json.loads(raw)
  for path,digest in record.get('source_sha256',{}).items():
   bound=manifest['source_bindings'][path+'#'+digest];actual=(ROOT/bound[5:]).read_bytes()if bound.startswith('repo:')else files[bound]
   assert sha(actual)==digest,(member,path)
 observations=load('observations/RESULT.json');whole=load('whole/RESULT.json');donor=load('donor/RESULT.json')
 assert observations['coarse_output_only_trajectory_exact']and observations['status']==whole['status']=='PAIRED_OXYGEN_AND_REFINEMENT_MEASURED'
 assert whole['accepted_pair_selection']['cases']==2922
 assert sha(files['whole/accepted-oxygen-inputs.dat'])==whole['accepted_pair_selection']['batch_sha256']
 trial=files['observations/coarse/native/stress-trials.dat'];assert sha(trial)==whole['accepted_pair_selection']['trial_observation_sha256']
 for case in ['coarse','half','quarter']:
  prefix='observations/'+case;build=load(prefix+'/build/BUILD.json');binding=load(prefix+'/native/application.binding')
  assert sha(files[prefix+'/build/swap5_grass_startup'])==build['executable_sha256']==binding['executable_sha256']
  assert build['flags'][0]=='-O2'and'-fcheck=all'in build['flags']
  budget=rows(prefix+'/native/budget.csv');crop=rows(prefix+'/native/crop.csv');assert len(budget)==len(crop)==140
  for day,(b,c)in enumerate(zip(budget,crop),1):
   assert int(b['day'])==int(c['day'])==day
   assert all(math.isfinite(float(v))for v in [*b.values(),*c.values()])
   assert abs(float(b['residual_cm']))<1e-10 and abs(float(b['heat_residual_j_cm2']))<1e-8
   assert abs(float(b['potential_cm'])-float(b['uptake_cm'])-float(b['oxygen_cm'])-float(b['drought_cm']))<1e-10
  assert layout(files[prefix+'/native/checkpoint.bin'])['clock']==140
  project=ROOT/'reference/swap-4.3.1/projects/2.grassgrowth'
  for name,original in {'input.swp':'swap.swp','grass.crp':'grass.crp','input.met':'260.met','swap.bbc':'swap.bbc','swap.dra':'swap.dra'}.items():assert files[prefix+'/native/'+name]==(project/original).read_bytes()
 # Recheck the accepted receipt coverage and recompute whole-owner integrals.
 receipts=[]
 for line in files['observations/coarse/native/stdout'].decode().splitlines():
  fields=line.split()
  if fields and fields[0]=='STRESS_ACCEPTED':receipts.append((int(fields[1]),list(map(float,fields[2:]))))
 assert len(receipts)==2922
 assert whole['paired']['O0']==whole['paired']['O2']
 for opt in ['O0','O2']:
  stdout=files['whole/'+opt+'/accepted-oxygen.stdout'];assert opt in whole['paired']
  pairs=[list(map(float,line.split()[1:]))for line in stdout.decode().splitlines()if line.startswith('PAIRED_WHOLE_UPTAKE ')]
  assert len(pairs)==len(receipts)
  for day in [25,72,73,127]:
   selected=[(r,p)for(d,r),p in zip(receipts,pairs)if d==day];measured=whole['paired'][opt]['accepted_substeps'][str(day)]
   assert abs(math.fsum(r[1]-r[0]for r,p in selected)-1)<1e-10
   for key,index in [('whole_original_uptake_cm',0),('whole_current_uptake_cm',1)]:assert abs(math.fsum(p[index]*(r[1]-r[0])for r,p in selected)-measured[key])<1e-12
   assert measured['maximum_current_reproduction_error']==0 and measured['maximum_factor_difference']<=1e-4
   assert abs(measured['whole_current_uptake_cm']-measured['current_uptake_cm'])<1e-10
   assert abs(measured['whole_original_uptake_cm']-measured['original_oxygen_on_native_uptake_cm'])<1e-10
 assert files['whole/O0/accepted-oxygen.stdout']==files['whole/O2/accepted-oxygen.stdout']
 # Recompute the preregistered numerical test, including its failures.
 full=ROOT/'integration/dataqual15/GRASS_UNION_FULL_EVIDENCE.tar.xz';assert sha(full.read_bytes())==manifest['inherited_full_capsule_sha256']
 with tarfile.open(full)as tar:
  spec=json.load(tar.extractfile('SPEC.json'));base=spec['full']
  budget=list(csv.DictReader(io.StringIO(tar.extractfile(base+'/budget.csv').read().decode())));crop=list(csv.DictReader(io.StringIO(tar.extractfile(base+'/crop.csv').read().decode())))
  checkpoints={}
  for name in tar.getnames():
   if name.startswith(base+'/checkpoint')and name.endswith('.bin'):
    raw=tar.extractfile(name).read();checkpoints[int(layout(raw)['clock'])]=raw
  assert rows('observations/coarse/native/budget.csv')==budget[:140]and rows('observations/coarse/native/crop.csv')==crop[:140]
  assert payload(files['observations/coarse/native/checkpoint.bin'])==payload(checkpoints[140])
  literal_scalar=tar.extractfile(spec['reference_B0']+'/result_output.csv').read()
  original_exe=tar.extractfile('original431/swap431_profiles').read();assert original_exe==files['donor/swap431']
 def scalar(raw):return list(csv.DictReader(line for line in raw.decode().splitlines()if line.strip()and not line.startswith('*')))
 series={};profiles={}
 for cap in ['0.04','0.005','0.0025','0.00125','0.000625']:
  prefix='donor/dtmax-'+cap;record=donor['runs'][cap];series[cap]=scalar(files[prefix+'/result_output.csv']);profiles[cap]={}
  assert record['completed_days']==1827 and record['returncode']==100 and not record['censored']and not record['physical_input_changes']
  assert sha(files[prefix+'/result_output.csv'])==record['scalar_sha256']and sha(files[prefix+'/nodal_profiles.csv'])==record['profiles_sha256']
  for row in rows(prefix+'/nodal_profiles.csv'):profiles[cap].setdefault(int(row['day']),[]).append(row)
 assert series['0.04']==scalar(literal_scalar)
 registration=load('donor/PREREGISTRATION.json');assert sha(files['donor/PREREGISTRATION.json'])==donor['preregistration_sha256']
 assert registration['script_sha256']==sha((ROOT/'tests/dataqual15/qualify_donor_timestep.py').read_bytes())
 recomputed=register_envelope(series['0.005'],series['0.0025'],profiles['0.005'],profiles['0.0025'],budget,crop,checkpoints)
 assert recomputed['bounds']==registration['bounds']
 previous={key:value['training_change']for key,value in registration['bounds'].items()};failures={}
 for old,new in [('0.0025','0.00125'),('0.00125','0.000625')]:
  assessment=assess_envelope(registration,series[old],series[new],profiles[old],profiles[new],budget,crop,checkpoints,previous)
  assert assessment==donor['runs'][new]['resolution_assessment'];assert not assessment['pass'];previous=assessment['reference_change']
  failures[new]=[key for key,v in assessment['fields'].items()if not(v['inside_frozen_envelope']and v['reference_change_decreases'])]
 assert donor['numerical_resolution_gate_pass']is False
 result=dict(status='SOURCE_BOUND_STRESS_ATTRIBUTION_EVIDENCE_PASS',accepted_cases=2922,stressed_node_evaluations=sum(v['stressed_nodes']for v in whole['paired']['O2']['accepted_substeps'].values()),frozen_resolution_gate_pass=False,frozen_gate_failures=failures,scientific_equivalence=False)
 if manifest['has_native_thermal']:
  thermal=load('thermal/RESULT.json');assert thermal['status']=='NATIVE_THERMAL_REFINEMENT_MEASURED'and thermal['completed_days']==1827
  assert thermal['registration_sha256']==donor['preregistration_sha256']and thermal['profiles_sha256']==donor['runs']['0.000625']['profiles_sha256']
  actual={}
  for day in checkpoints:
   if day not in profiles['0.000625']:continue
   member='thermal/native/'+('checkpoint.bin'if day==1827 else f'checkpoint-{day}.bin');raw=files[member];s=layout(raw);assert s['clock']==day
   n=s['nodes'];v=struct.unpack_from('='+str(n)+'d',raw,s['physical']+16*n+16);ref=[float(r['temperature_c'])for r in sorted(profiles['0.000625'][day],key=lambda r:int(r['node']))]
   error=max(abs(a-b)for a,b in zip(v,ref));assert error==thermal['profiles'][str(day)]['refined']['maximum_temperature_error_c'];actual[day]=error
  maximum=max(actual.values());assert maximum==thermal['maximum_refined_temperature_error_c'];assert thermal['refined_inside_original_thermal_envelope']==(maximum<=registration['bounds']['PROFILE_temperature_c']['limit'])
  result['native_thermal_refinement']=dict(maximum_temperature_error_c=maximum,inside_frozen_envelope=thermal['refined_inside_original_thermal_envelope'])
 print(json.dumps(result,indent=2));return result

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--package',action='store_true');p.add_argument('--observations',type=Path);p.add_argument('--whole',type=Path);p.add_argument('--donor',type=Path);p.add_argument('--thermal',type=Path);a=p.parse_args()
 if a.package:package(a.observations,a.whole,a.donor,a.thermal)
 verify()

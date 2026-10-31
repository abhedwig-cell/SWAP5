"""Compact raw Sprint03 archive and independent read-only consumer."""
import argparse,csv,hashlib,io,json,math,struct,subprocess,tarfile
from pathlib import Path,PurePosixPath,PureWindowsPath
from checkpoint_layout import layout,payload
from qualify_donor_timestep import vectors,distance
ROOT=Path(__file__).resolve().parents[2]
CAP=ROOT/'integration/dataqual15/SPRINT03_EVIDENCE.tar.xz'
META=CAP.with_name('SPRINT03_EVIDENCE_MANIFEST.json')
sha=lambda b:hashlib.sha256(b).hexdigest()
rows=lambda raw:list(csv.DictReader(line for line in raw.decode().splitlines()if line.strip()and not line.startswith('*')))

def package(out):
 out=out.resolve();files={}
 for p in sorted(out.rglob('*')):
  if not p.is_file():continue
  rel=p.relative_to(out).as_posix()
  if any(x in rel.split('/')for x in ['source','selected','swobj','ttobj']):continue
  if p.suffix in ['.json','.csv','.bin','.dat','.args','.stdout','.stderr','.swp','.crp','.met','.bbc','.dra','.f90']or p.name in ['application.binding','swap5_grass_startup','swap431','swap.ok']:
   files[rel]=p.read_bytes()
 files['MANIFEST.json']=(json.dumps({p:sha(raw)for p,raw in sorted(files.items())},indent=2)+'\n').encode()
 with tarfile.open(CAP,'w:xz',preset=6)as archive:
  for name,raw in sorted(files.items()):
   info=tarfile.TarInfo(name);info.size=len(raw);info.mode=0o644;info.mtime=0;archive.addfile(info,io.BytesIO(raw))
 sources={}
 for opt in ['O0','O2']:
  build=out/('build-'+opt)/'BUILD.json'
  if not build.exists():continue
  for path,digest in json.loads(build.read_text())['source_sha256'].items():
   p=Path(path)
   if p.is_relative_to(ROOT):sources[p.relative_to(ROOT).as_posix()]=digest
 for name in ['tests/dataqual15/qualify_sprint03.py','tests/dataqual15/sprint03_evidence.py','tests/dataqual15/qualify_thermal_runtime.py','tests/dataqual15/thermal_temporal_driver.f90','tests/dataqual15/qualify_donor_timestep.py','tests/dataqual15/checkpoint_layout.py','tests/dataqual15/original_sources.py','integration/dataqual15/SPRINT03_PREREGISTRATION.json']:
  sources[name]=sha((ROOT/name).read_bytes())
 record=dict(archive_sha256=sha(CAP.read_bytes()),archive_files=len(files),source_sha256=sources,production_trees={name:subprocess.check_output(['git','rev-parse','HEAD:'+name],cwd=ROOT,text=True).strip()for name in ['src','app','reference']},predecessor_capsules={name:sha((ROOT/f'integration/dataqual15/{name}_EVIDENCE.tar.xz').read_bytes())for name in ['GRASS_UNION_FULL','STRESS','SPRINT02']},canonical_modified=False,production_promotion=False)
 META.write_text(json.dumps(record,indent=2)+'\n',newline='\n');print('PACKAGED',len(files),CAP.stat().st_size)

def verify():
 m=json.loads(META.read_text());assert sha(CAP.read_bytes())==m['archive_sha256']
 for name,digest in m['source_sha256'].items():assert sha((ROOT/name).read_bytes())==digest,name
 for name,oid in m['production_trees'].items():assert subprocess.check_output(['git','rev-parse','HEAD:'+name],cwd=ROOT,text=True).strip()==oid
 assert not subprocess.check_output(['git','diff','HEAD','--','src','app','reference'],cwd=ROOT)
 archives={}
 for name,digest in m['predecessor_capsules'].items():
  path=ROOT/f'integration/dataqual15/{name}_EVIDENCE.tar.xz';assert sha(path.read_bytes())==digest;archives[name]=tarfile.open(path)
 with tarfile.open(CAP)as archive:
  members=archive.getmembers();assert len(members)==m['archive_files']==len({v.name for v in members})
  assert all(v.isfile()and not PurePosixPath(v.name).is_absolute()and not PureWindowsPath(v.name).drive and '..'not in PurePosixPath(v.name).parts and '\\'not in v.name for v in members)
  f={v.name:archive.extractfile(v).read()for v in members}
 assert json.loads(f.pop('MANIFEST.json'))=={name:sha(raw)for name,raw in f.items()}
 load=lambda name:json.loads(f[name]);get=lambda t,name:t.extractfile(name).read()
 result=load('RESULT.json');plan=load('PREREGISTRATION.json');assert f['PREREGISTRATION.json']==(ROOT/'integration/dataqual15/SPRINT03_PREREGISTRATION.json').read_bytes();assert result['registration_sha256']==sha(f['PREREGISTRATION.json'])
 assert result['status']=='SPRINT03_THERMAL_POLICY_MEASURED'and not result['original_gate_pass']and not result['production_promoted']and not result['canonical_modified']
 assert all(not e['censored']and e['returncode']==(100 if e['label'].startswith('reference-0.')else e['returncode']if e['label'].startswith('missing-profile-')else 0)for e in result['events'])
 for event in result['events']:
  if event['label'].startswith('missing-profile-'):assert event['returncode']!=0
 full,old,prior=[archives[name]for name in ['GRASS_UNION_FULL','STRESS','SPRINT02']];spec=json.loads(get(full,'SPEC.json'));frozen=json.loads(get(old,'donor/PREREGISTRATION.json'))
 assert frozen['bounds']==plan['criteria']['frozen_bounds']and sha(get(old,'donor/PREREGISTRATION.json'))==plan['criteria']['frozen_registration_sha256']
 original_budget=rows(get(full,spec['full']+'/budget.csv'));original_crop=rows(get(full,spec['full']+'/crop.csv'));original_points={}
 for name in full.getnames():
  if name.startswith(spec['full']+'/checkpoint')and name.endswith('.bin'):
   raw=get(full,name);original_points[int(layout(raw)['clock'])]=raw
 native={}
 for opt in ['O0','O2']:
  build=load('build-'+opt+'/BUILD.json');assert sha(f['build-'+opt+'/swap5_grass_startup'])==build['executable_sha256'];assert all(e['returncode']==0 for e in build['events'])
  for policy,end in [('default',140),('adaptive',140 if opt=='O0'else 1827)]:
   case=policy+'-'+opt;budget=rows(f[case+'/budget.csv']);crop=rows(f[case+'/crop.csv']);assert len(budget)==len(crop)==end
   binding=load(case+'/application.binding');assert binding['executable_sha256']==build['executable_sha256']and binding['source_sha256']==build['source_sha256']
   assert(binding.get('grass_numerical_profile')=='thermal-control-1e-5C')==(policy=='adaptive')
   for name in ['input.swp','grass.crp','input.met','swap.bbc','swap.dra']:assert sha(f[case+'/'+name])==build['original_inputs_sha256'][name]and f[case+'/'+name]==get(full,spec['full']+'/'+name)
   points={}
   for name,raw in f.items():
    if name.startswith(case+'/checkpoint')and name.endswith('.bin'):
     s=layout(raw);pos=8
     for item in ['input.swp','grass.crp','input.met','swap.bbc','swap.dra','application.binding']:
      size=struct.unpack_from('=i',raw,pos)[0];pos+=4;assert raw[pos:pos+size]==f[case+'/'+item];pos+=size
     points[int(s['clock'])]=raw
   assert max(abs(float(r['residual_cm']))for r in budget)<1e-10 and max(abs(float(r['heat_residual_j_cm2']))for r in budget)<1e-8
   if policy=='default':assert budget==original_budget[:140]and crop==original_crop[:140]and all(payload(raw)==payload(original_points[day])for day,raw in points.items())
   else:native[opt]=dict(budget=budget,crop=crop,checkpoints=points)
 assert native['O0']['budget']==native['O2']['budget'][:140]and native['O0']['crop']==native['O2']['crop'][:140]
 assert all(payload(raw)==payload(native['O2']['checkpoints'][day])for day,raw in native['O0']['checkpoints'].items())
 data=native['O2'];assert set(plan['native_capture_days'])<=set(data['checkpoints'])
 for first,last in result['restarts']:
  case=f'restart-{first}-{last}';assert f[case+'/origin.bin']==data['checkpoints'][first]and f[case+'/checkpoint.bin']==data['checkpoints'][last]
  assert rows(f[case+'/budget.csv'])==data['budget'][first:last]and rows(f[case+'/crop.csv'])==data['crop'][first:last]
 def stock(raw):
  s=layout(raw);n=s['nodes'];dz=struct.unpack_from('='+str(n)+'d',raw,s['header']+48+8*n);theta=struct.unpack_from('='+str(n)+'d',raw,s['physical']+8*n);pond=struct.unpack_from('=d',raw,s['physical']+16*n)[0];return math.fsum(a*b for a,b in zip(dz,theta))+pond
 maximum=0.;days=sorted(data['checkpoints'])
 for a,b in zip(days,days[1:]):maximum=max(maximum,abs(stock(data['checkpoints'][b])-stock(data['checkpoints'][a])-math.fsum(float(r['input_cm'])-float(r['output_cm'])for r in data['budget'][a:b])))
 assert maximum==result['maximum_independent_stock_flux_residual_cm']and maximum<1e-10
 original=get(prior,'heldout/reference/swapoutput_profiles.f90').decode();old_dates=sorted([0]+plan['old_profile_days']);needle='['+','.join(map(str,old_dates))+']';all_dates=sorted(set(old_dates+plan['new_profile_days']));assert original.count(needle)==1
 assert f['reference/swapoutput_profiles.f90']==original.replace(needle,'['+','.join(map(str,all_dates))+']').encode()
 assert sha(f['reference/swap431'])==result['reference_build']['executable_sha256']
 provider=load('reference/providers/BUILD.json');previous=json.loads(get(old,'whole/original-O2/BUILD.json'))
 for key in ['source_sha256','selected_sha256','authority_sha256','manifest_sha256']:assert provider[key]==previous[key]
 scalar={};nodal={}
 for cap in [.000625,.0003125]:
  case='reference/'+str(cap);base='heldout/'+case;scalar[cap]=rows(f[case+'/result_output.csv']);assert len(scalar[cap])==1828 and scalar[cap]==rows(get(prior,base+'/result_output.csv'))
  for name in ['swap.swp','grass.crp','260.met','swap.bbc','swap.dra']:assert f[case+'/'+name]==get(prior,base+'/'+name)
  profile=rows(f[case+'/nodal_profiles.csv']);assert [r for r in profile if int(r['day'])in old_dates]==rows(get(prior,base+'/nodal_profiles.csv'));nodal[cap]={}
  for row in profile:nodal[cap].setdefault(int(row['day']),[]).append(row)
  assert set(nodal[cap])==set(all_dates)
 observed,ref,units,floors=vectors(scalar[.0003125],nodal[.0003125],**data);_,previous,_,_=vectors(scalar[.000625],nodal[.000625],**data);assessment={}
 for key,bound in frozen['bounds'].items():
  assert all(math.isfinite(v)for v in observed[key]+ref[key]+previous[key]);error=distance(key,observed[key],ref[key]);change=distance(key,previous[key],ref[key]);limit=bound['limit'];resolution_limit=limit/3+bound['floor']
  assessment[key]=dict(native_error=error,limit=limit,inside_frozen_envelope=error<=limit,reference_change=change,reference_resolution_limit=resolution_limit,reference_resolution_pass=not key.startswith('PROFILE_')or change<=resolution_limit,unit=units[key])
 assert assessment==result['assessment'];passed=all(v['inside_frozen_envelope']and v['reference_resolution_pass']for v in assessment.values());assert passed==result['registered_gate_pass']
 answer=dict(status='SOURCE_BOUND_SPRINT03_RAW_EVIDENCE_PASS',registered_thermal_configuration_pass=passed,full_days=1827,old_gate_pass=False,canonical_modified=False,production_promotion=False,independent_water_stock_flux_residual_cm=maximum)
 print(json.dumps(answer,indent=2));return answer

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--package',type=Path);a=p.parse_args()
 if a.package:package(a.package)
 else:verify()

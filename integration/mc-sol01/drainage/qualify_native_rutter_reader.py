"""Original crop/weather preparation, additive reader mode, and default preservation."""
import argparse,csv,gzip,hashlib,json,re,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];BASE='e15d5ffd1b28701eb96da7ae817f85c47a15a597';sha=lambda b:hashlib.sha256(b).hexdigest();p=argparse.ArgumentParser();p.add_argument('--fc',required=True);p.add_argument('--project-reader',type=Path,required=True);p.add_argument('--archive',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();out=a.output.resolve();out.mkdir();events=[];inputs={};results={}
common=['src/crop/mod_crop_fixed_phenology.f90','src/crop/mod_crop_rotation_calendar.f90','src/crop/mod_wofost_rate_table.f90','src/crop/mod_crop_et_canopy_view_provider.f90','src/crop/mod_crop_root_depth_dvs.f90','src/process/mod_reference_et_demand_process.f90','app/solute_crop/read_swp_crop.f90'];source_dir=ROOT/'tests/qualification/ppa-wu05-migmac10-canonical-20261006'
def run(cmd,stage,label,ok=True):
 start=time.monotonic();cp=subprocess.run(list(map(str,cmd)),cwd=stage,capture_output=True,timeout=60)
 for stream in ['stdout','stderr']:(out/(label+'.'+stream)).write_bytes(getattr(cp,stream))
 events.append(dict(label=label,command=list(map(str,cmd)),returncode=cp.returncode,expected_success=ok,seconds=time.monotonic()-start));(out/'events.json').write_text(json.dumps(events,indent=2)+'\n');assert(cp.returncode==0)==ok,(label,cp.stdout.decode()[-1000:],cp.stderr.decode()[-2000:]);return cp
stage=out/'original-preparation';stage.mkdir()
raw={}
for path in sorted(source_dir.glob('b111-*.gz')):
 name=path.name[len('b111-'):-len('.gz')]
 if name in ['swap.swp','swap.bbc','swap.dra','wintcer1.crp','wintcer2.crp','andelst_meteo.998','andelst_meteo.999','andelst_rain.998','andelst_rain.999']:
  raw[name]=gzip.decompress(path.read_bytes());inputs[str(path.relative_to(ROOT))]=sha(path.read_bytes())
# Navigation projection only; no water/chemistry executable is run here. Retain
# original SWSOLU0, all original crop bytes and original meteorology/rain.
project,n=re.subn(rb'(?m)^(\s*SWMACRO\s*=\s*)1',rb'\g<1>0',raw['swap.swp']);assert n==1
(stage/'input.swp').write_bytes(project);run([a.project_reader,'input.swp','scan','native-heat'],stage,'project-scan')
refs=list(csv.DictReader((stage/'project.csv').open()))
for r in refs:
 kind=r['kind'];name=r['value'].strip()
 if kind not in ['bbc','crop','met','rain','drain']:continue
 if kind=='bbc':dest='input.bbc'
 else:dest={'crop':'crop-','met':'weather-','rain':'rain-','drain':'drain-'}[kind]+r['index']+{'crop':'.crp','met':'.met','rain':'.rain','drain':'.dra'}[kind]
 (stage/dest).write_bytes(raw[name])
run([a.project_reader,'input.swp','prepare','native-heat'],stage,'project-prepare')
plans={}
for opt in ['O0','O2']:
 readers={}
 for variant in ['current','preimage']:
  build=out/(opt+'-'+variant);build.mkdir();sources=[]
  for name in common:
   if variant=='preimage'and name in ['src/process/mod_reference_et_demand_process.f90','app/solute_crop/read_swp_crop.f90']:
    q=build/Path(name).name;q.write_bytes(subprocess.check_output(['git','show',BASE+':'+name],cwd=ROOT));sources.append(q)
   else:sources.append(ROOT/name)
   inputs[name]=sha((ROOT/name).read_bytes())
  exe=build/'reader';run([a.fc,'-'+opt,'-std=f2008','-ffree-line-length-none','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow','-J'+str(build),'-I'+str(build),*sources,a.archive,'-o',exe],build,opt+'-'+variant+'-link');readers[variant]=exe
 for ref in [r for r in refs if r['kind']=='crop']:
  index=ref['index'];key=opt+'-period'+index;work=out/key;work.mkdir();swp='period-'+index+'.swp';crp='crop-'+index+'.crp'
  for name in [swp,crp,'weather.met']:(work/name).write_bytes((stage/name).read_bytes())
  original=(work/crp).read_bytes();run([readers['current'],swp,crp,'weather.met'],work,key+'-default-reject',False);assert not(work/'crop_daily.csv').exists()
  run([readers['current'],swp,crp,'weather.met','native-rutter'],work,key+'-rutter');plan=(work/'crop_daily.csv').read_bytes();rutter=(work/'rutter_daily.csv').read_bytes();rows=list(csv.DictReader(rutter.decode().splitlines()));dry=list(csv.DictReader(plan.decode().splitlines()));assert len(rows)==len(dry)==481
  cap=float(re.search(rb'(?im)^\s*SICCAPLAI\s*=\s*([\d.]+)',original)[1]);assert cap==.02
  for x,y in zip(rows,dry):
   assert float(x['t1900'])==float(y['t1900'])and float(x['initial_storage_cm'])==0
   assert abs(float(x['capacity_cm'])-cap*float(y['lai']))<1e-16
   assert float(x['dry_transpiration_cm_day'])==float(y['transpiration_cm_day'])
   assert abs(float(x['wet_transpiration_cm_day'])-.5*float(x['dry_transpiration_cm_day']))<1e-16
   assert float(x['wet_transpiration_cm_day'])==float(x['interception_evaporation_cm_day'])
  assert any(float(x['capacity_cm'])>0 for x in rows)
  (work/'crop_daily.csv').unlink();(work/'rutter_daily.csv').unlink()
  for label,source in [('bad-cap',re.sub(rb'(?im)^(\s*SICCAPLAI\s*=\s*)[\d.]+',rb'\g<1>.6',original)),('missing-cap',re.sub(rb'(?im)^\s*SICCAPLAI\s*=.*$',b'',original))]:
   (work/crp).write_bytes(source);run([readers['current'],swp,crp,'weather.met','native-rutter'],work,key+'-'+label,False);assert not(work/'crop_daily.csv').exists()and not(work/'rutter_daily.csv').exists()
  changed_initial,count=re.subn(rb'(?im)^(\s*SICACT\s*=\s*)[\d.]+',rb'\g<1>999.',original);assert count==1
  (work/crp).write_bytes(changed_initial);run([readers['current'],swp,crp,'weather.met','native-rutter'],work,key+'-source-initial-reset');assert(work/'rutter_daily.csv').read_bytes()==rutter;(work/'crop_daily.csv').unlink();(work/'rutter_daily.csv').unlink()
  supported,n=re.subn(rb'(?im)^(\s*SWINTER\s*=\s*)3',rb'\g<1>0',original);assert n==1;(work/crp).write_bytes(supported)
  old=[]
  for variant in ['current','preimage']:
   run([readers[variant],swp,crp,'weather.met'],work,key+'-plain-'+variant);old.append((work/'crop_daily.csv').read_bytes());(work/'crop_daily.csv').unlink()
  assert old[0]==old[1]==plan
  plans[key]=dict(crop_sha256=sha(plan),rutter_sha256=sha(rutter),days=len(rows),capacity_max_cm=max(float(x['capacity_cm'])for x in rows))
  (work/'qualified-crop.csv').write_bytes(plan);(work/'qualified-rutter.csv').write_bytes(rutter)
for ref in [r for r in refs if r['kind']=='crop']:assert plans['O0-period'+ref['index']]==plans['O2-period'+ref['index']]
inputs[str(Path(__file__).relative_to(ROOT))]=sha(Path(__file__).read_bytes());record=dict(status='ORIGINAL_RUTTER_CROP_WEATHER481_O0_O2_PREPARATION_PASS',baseline=BASE,input_sha256=inputs,original_raw_sha256={n:sha(b)for n,b in raw.items()},navigation_projection='SWMACRO1 to0 in metadata preparation only; no water application; original SWSOLU0 and CRP/weather/rain unchanged',crop_periods=len([r for r in refs if r['kind']=='crop']),results=plans,events=events,ttutil_archive_sha256=sha(a.archive.read_bytes()),project_reader_sha256=sha(a.project_reader.read_bytes()),full_original_Andelst=False,qualified=False,canonically_admitted=False);(out/'RESULT.json').write_text(json.dumps(record,indent=2)+'\n');print(record['status'])

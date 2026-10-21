"""Actual Reference/crop/fallow/N fractional clock with native input and restart."""
from pathlib import Path
import argparse,hashlib,json,os,subprocess,time
ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser(description=__doc__)
for key in ['physical','native','output']:p.add_argument('--'+key,type=Path,required=True)
a=p.parse_args();OUT=a.output.resolve();OUT.mkdir(exist_ok=False);physical=a.physical.resolve()
sha=lambda b:hashlib.sha256(b).hexdigest()
report=json.loads((physical/'result.json').read_text());assert report['status']=='HIST_BOUNDED_PHYSICAL_PASS_NOT_FULL_MIGRATION'
for path,h in report['input_sha256'].items():assert sha((ROOT/path).read_bytes())==h,path
events=[];inputs=dict(report['input_sha256']);results={};FC=os.environ.get('FC','gfortran')
def run(c,b,category):
 c=list(map(str,c));exe=Path(c[0])
 if exe.is_file()and exe.is_relative_to(OUT)and exe.read_bytes()[:4]==b'\x7fELF':exe.chmod(0o755)
 t=time.perf_counter();r=subprocess.run(c,cwd=b,capture_output=True)
 e=dict(command=c,category=category,returncode=r.returncode,seconds=time.perf_counter()-t)
 for key in ['stdout','stderr']:
  name=f'{len(events):04d}.{key}';v=getattr(r,key);(OUT/name).write_bytes(v);e[key]=name;e[key+'_sha256']=sha(v)
 events.append(e);(OUT/'events.json').write_text(json.dumps(events,indent=2)+'\n')
 if r.returncode:raise RuntimeError(r.stdout.decode()+r.stderr.decode())
 return r.stdout.decode()
driver=ROOT/'tests/nut-crop/test_b112_retained_joint.f90';include=ROOT/'tests/nut-crop/negative_joint.inc'
text=driver.read_text();anchor=" if(trim(selected)=='source-profile'.or."
assert text.count(anchor)==1
index=text.index(anchor);text=text[:index]+" if(trim(selected)=='negative-low'.or.trim(selected)=='negative-high')then\n  call negative_joint()\n  stop\n end if\n"+text[index:]
text=text.replace(' implicit none',' use mod_soil_n_unified_input\n implicit none',1)
text=text.replace('only:soil_n_historical_selection_t','only:soil_n_historical_selection_t,soil_n_historical_initial_t, &\n soil_n_historical_rates_t,bind_historical_soil_n_rates',1)
assert text.count('\ncontains\n')==1
text=text.replace('\ncontains\n',"\ncontains\n include 'timestamp_joint.inc'\n",1)
body=include.read_text().replace('  integer::first,d,u,code',
 '''  type(soil_n_amendment_calendar_t)::native_plan
  type(soil_n_historical_initial_t)::native_initial
  type(soil_n_historical_rates_t)::native_rates
  type(reactive_parameters_t)::clock_parameters
  real(real64)::source_root,source_lai
  character(512)::native_path
  integer::first,d,u,code,source_line''',1)
needle='  cp%harvest%crop_end=0d0';assert body.count(needle)==1
body=body.replace(needle,'''  call get_command_argument(6,native_path)
  call read_soil_n_snm_keyword_file(trim(native_path),'1900-12-30',native_plan, &
       native_initial,native_rates,code,source_line)
  call require(code==0,'fractional source native startup')
  call bind_historical_soil_n_rates(native_rates,sp,clock_parameters,source_root,source_lai,code)
  call require(code==0,'fractional native rates bind real immutable owner')
  sp=clock_parameters
  print *,'BOUND_FRACTIONAL_CLOCK',sp%hum_exp_start_day,sp%hum_exp_daily
'''+needle,1)
needle='spread(0d0,1,8),1d-4,0d0,';assert body.count(needle)==1
body=body.replace(needle,'spread(0d0,1,8),1d-4,40d0,',1)
(OUT/'driver.f90').write_text(text);(OUT/'timestamp_joint.inc').write_text(body)
base=(a.native.resolve()/'0.snm').read_text().replace('RateconHum_exp = .1','RateconHum_exp = .1').replace('tstartHumexp = 1901-01-01','tstartHumexp = 1900-01-07_12:00')
base=base.replace('cNH4N_top = 0.','cNH4N_top = .002').replace('cNO3N_top = 0.','cNO3N_top = .005')
base=base.replace('RateConNitrif_ref = .02','RateConNitrif_ref = .2').replace('RateConDenitr_ref = .03','RateConDenitr_ref = .25')
for label,clock in [('fractional','1900-01-07_12:00'),('ceil','1900-01-08'),('floor','1900-01-07')]:
 (OUT/(label+'.snm')).write_text(base.replace('1900-01-07_12:00',clock))
old=json.loads((physical/'events.json').read_text())
for opt in ['O0','O2']:
 b=OUT/opt;b.mkdir();providers=physical/opt
 link=next(e['command']for e in old if e['category']=='link'and e['command'][-1]==str(providers/'hist'))
 objects=[c for c in link if c.endswith('.o')][:-1]
 flags=link[1:link.index(objects[0])]+['-I'+str(OUT)]
 obj=b/'driver.o';exe=b/'joint';run([FC,*flags,'-c',OUT/'driver.f90','-o',obj],b,'compile')
 run([FC,*flags,*objects,obj,'-o',exe],b,'link')
 for name in ['negative-low','negative-high']:
  path=b/(name+'.restart');end=b/(name+'.end');source=OUT/'fractional.snm'
  output=run([exe,'write',path,end,name,'0',source],b,'native')
  assert 'FINITE_DONOR_ACTUAL_RICHARDS_RETIRED_CROP_N_RESTART=PASS'in output
  for day in [3,7]:assert Path(str(path)+'.before-'+str(day)).read_bytes()==Path(str(path)+'.water-reject-'+str(day)).read_bytes()==Path(str(path)+'.chemical-reject-'+str(day)).read_bytes()
  for day in [1,6]:
   fresh=b/(name+'.fresh-'+str(day));run([exe,'resume',str(path)+'.'+str(day),fresh,name,str(day),source],b,'restart')
   for suffix in ['', '.ledger']:assert Path(str(end)+suffix).read_bytes()==Path(str(fresh)+suffix).read_bytes()
  for label in ['ceil','floor']:
   control=b/(name+'.'+label);run([exe,'write',b/(name+'.'+label+'.restart'),control,name,'0',OUT/(label+'.snm')],b,'clock_control')
   same=Path(str(end)+'.ledger').read_bytes()==Path(str(control)+'.ledger').read_bytes()
   assert same==(label=='ceil'),'fractional endpoint predicate discriminant'
  results[opt+'/'+name]=dict(stdout=output,endpoint_sha256=sha(end.read_bytes()),ledger_sha256=sha(Path(str(end)+'.ledger').read_bytes()))
for name in ['negative-low','negative-high']:assert results['O0/'+name]==results['O2/'+name]
for path in [driver,include,Path(__file__)]:inputs[str(path.relative_to(ROOT))]=sha(path.read_bytes())
(OUT/'result.json').write_text(json.dumps(dict(status='FRACTIONAL_NATIVE_ACTUAL_RICHARDS_CROP_FALLOW_N_RESTART_PASS',results=results,input_sha256=inputs,physical_result_sha256=sha((physical/'result.json').read_bytes()),generated_driver_sha256=sha(text.encode()),generated_include_sha256=sha(body.encode())),indent=2)+'\n')
print('FRACTIONAL_NATIVE_ACTUAL_RICHARDS_CROP_FALLOW_N_RESTART_PASS')

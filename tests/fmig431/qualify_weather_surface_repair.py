"""Focused native preservation using exact, already compiled weather providers."""
import argparse
from decimal import Decimal,localcontext
import hashlib,json,os,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--build',type=Path,required=True);ap.add_argument('--output',type=Path,required=True);a=ap.parse_args()
build,out=a.build.resolve(),a.output.resolve();out.mkdir(parents=True,exist_ok=False)
b=json.loads((build/'BUILD.json').read_text());assert b['status']=='BUILT' and sha(build/'weather')==b['executable_sha256']
overrides={'tests/fsi/fsi04_real_headcalc_stubs.f90':'grid_stubs.f90','src/runtime/mod_fmr_serialized_multiswap_runtime.f90':'observed_serial_runtime.f90','src/runtime/mod_fmr_production_application_bootstrap.f90':'observed_bootstrap.f90'}
for p,h in b['sources'].items():assert sha(build/overrides[p] if p in overrides else ROOT/p)==h,p
assert sha(ROOT/'src/legacy/b1_10_port/headcalc.f90')==b['headcalc_sha256']
events=[]
def run(cmd,label,input_bytes=None,directory=None):
 t=time.monotonic();p=subprocess.run(list(map(str,cmd)),cwd=directory or out,input=input_bytes,capture_output=True,timeout=120,env={**os.environ,'OMP_NUM_THREADS':'1'})
 for stream in ('stdout','stderr'):(out/(label+'.'+stream)).write_bytes(getattr(p,stream))
 events.append(dict(command=list(map(str,cmd)),label=label,returncode=p.returncode,seconds=time.monotonic()-t));(out/'events.json').write_text(json.dumps(events,indent=2)+'\n');p.check_returncode();return p.stdout
shell=(ROOT/'tests/fmig431/run_crop_file_weather_production.sh').read_text();preparation=shell.split('python3 - "$BUILD" <<\'PY\'\n',1)[1].split('\nPY\n',1)[0]
run(['python','-',out],'prepare',preparation.encode(),ROOT);assert sha(out/'grid_stubs.f90')==sha(build/'grid_stubs.f90')
flags=[x for x in b['flags'] if not x.startswith(('-I','-J'))]+['-I'+str(build),'-J'+str(out)];objects=[build/f'{i:04d}.o' for i in range(len(b['sources']))];fc=b['compiler_command'];driver=ROOT/'tests/fmig431/test_crop_file_weather_production.f90'
run(fc+flags+[driver,ROOT/'src/legacy/b1_10_port/headcalc.f90',*sorted(out.glob('*_oracle.f90')),*objects,'-o',out/'original-weather'],'link-original')
outputs={}
for moisture in ('neutral','dry','hydraulic'):
 for mode in ('continuous','restart'):
  label=moisture+'-'+mode;outputs[label]=run([out/'original-weather',out/'weather.999',out/'altered.999',out/'bad.999',out/'backup.999',mode,moisture],label);assert b'CROP_FILE_WEATHER_PRODUCTION=PASS' in outputs[label]
 assert outputs[moisture+'-continuous']==outputs[moisture+'-restart']
for source,name in [('tests/fsi/test_weather_surface_continuous_mvg.f90','continuous-mvg'),('tests/fsi/test_fsi39_b110_ksatexm.f90','legacy-mvg')]:
 run(fc+flags+[ROOT/source,objects[1],objects[2],'-o',out/name],'link-'+name);data=run([out/name],name)
 if name=='continuous-mvg':
  lines=data.decode().splitlines();tr,delta,slope,m=[Decimal(float(x)) for x in lines[0].split()[1:]];errors=[]
  with localcontext() as context:
   context.prec=80
   for line in lines[1:]:
    if not line.startswith('MVG_ROW'):continue
    h,w,k,old=map(float,line.split()[1:]);hd=Decimal(h)
    if h>=0:expected=Decimal('4.75')
    else:
     se=(1+slope*hd/delta) if h>-.01 else (Decimal(w)-tr)/delta
     expected=Decimal('4.75')*se**Decimal(float(.365))*(1-(1-se**(1/m))**m)**2
    error=abs(k-float(expected));assert error<5e-10,(h,error);errors.append(error)
  (out/'mualem-oracle.json').write_text(json.dumps(dict(precision_digits=80,max_abs_error=max(errors)))+'\n')
run(fc+flags+[ROOT/'tests/fsi/test_weather_surface_desaturation.f90',ROOT/'src/legacy/b1_10_port/headcalc.f90',*objects,'-o',out/'desaturation'],'link-desaturation')
assert b'WEATHER_SURFACE_DESATURATION_PASS' in run([out/'desaturation'],'desaturation')
run(fc+flags+[ROOT/'tests/fsi/test_weather_surface_top_derivative.f90',ROOT/'src/legacy/b1_10_port/headcalc.f90',*objects,'-o',out/'top-derivative'],'link-top-derivative')
top_data=run([out/'top-derivative'],'top-derivative').decode().splitlines()
assert any('WEATHER_SURFACE_TOP_DERIVATIVE_PASS' in x for x in top_data)
delta,slope,m=[Decimal(float(x)) for x in top_data[0].split()[1:]]
with localcontext() as context:
 context.prec=80
 def top_flux(h):
  se=1+slope*h/delta
  k=Decimal('4.75') if h>=0 else Decimal('4.75')*se**Decimal(float(.365))*(1-(1-se**(1/m))**m)**2
  face=(Decimal('4.75')+k)/2;dt=Decimal(float(1e-4));d=Decimal('2.5')
  pond=(Decimal(float(.007397))+(Decimal(float(.2))-Decimal(float(.029)))*dt-face*dt+face*dt*h/d)/(1+face*dt/d+dt)
  return -face*((pond-h)/d+1)
 errors=[]
 for line in top_data[1:]:
  if not line.startswith('TOP_ROW'):continue
  h,k,dk,q,dq=map(float,line.split()[1:]);hd=Decimal(h)
  perturb=abs(hd)*Decimal('1e-8') if h!=0 else Decimal('1e-12')
  exact=(top_flux(hd+perturb)-top_flux(hd-perturb))/(2*perturb) if h<0 else (top_flux(hd+perturb)-top_flux(hd))/perturb
  error=abs((Decimal(dq)-exact)/exact);assert error<Decimal('5e-8'),(h,error);errors.append(float(error))
 (out/'top-derivative-oracle.json').write_text(json.dumps(dict(precision_digits=80,max_relative_error=max(errors)))+'\n')
result=dict(status='WEATHER_SURFACE_NATIVE_PRESERVATION_PASS',parent_build=str(build),native_original_profiles=6,original_same_process_restart_pairs=3,small_provider_contracts=2,desaturation_contracts=1,analytic_top_contracts=1,events=events,input_sha256={str(p.relative_to(ROOT)):sha(p) for p in [driver,ROOT/'src/legacy/b1_10_port/headcalc.f90',ROOT/'tests/fsi/test_weather_surface_continuous_mvg.f90',ROOT/'tests/fsi/test_weather_surface_desaturation.f90',ROOT/'tests/fsi/test_weather_surface_top_derivative.f90']},raw_sha256={p.name:sha(p) for p in out.iterdir() if p.is_file() and p.suffix in ('.stdout','.stderr','.json')})
(out/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n');print(result['status'])

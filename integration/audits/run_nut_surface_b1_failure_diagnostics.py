"""Measured hydrological fixture alternatives with immutable production providers.

The existing accepted-step proposal is selected; every strict full/half and
mass gate remains active. No production source changes. A result is exploratory and never an admission or full-rotation PASS.
"""
from pathlib import Path
import hashlib,json,os,subprocess,time
ROOT=Path(__file__).resolve().parents[2]
BASE=Path(os.environ['N_SURFACE_PROVIDERS']).resolve()
OUT=Path(os.environ['N_SURFACE_PROBE_DIR']).resolve();OUT.mkdir(exist_ok=False)
OPT=os.environ.get('N_SURFACE_PROBE_OPT','O2');assert OPT in ['O0','O2']
VARIANT=os.environ.get('N_SURFACE_PROBE_VARIANT','clay');assert VARIANT in ['clay','field-loam']
DAYS=int(os.environ.get('N_SURFACE_PROBE_DAYS','730'));assert 1<=DAYS<=730
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();self_sha=sha(Path(__file__))
prior=json.loads((BASE/'result.json').read_text());assert prior['status']=='SURFACE_N_B1_ACTUAL_PHYSICAL_PASS_NOT_ADMITTED'
for p,h in prior['input_sha256'].items():assert sha(ROOT/p)==h,p
assert sha(BASE/'generated_driver.f90')==prior['generated_driver_sha256']
events=json.loads((BASE/'events.json').read_text());assert all(e['returncode']==0 for e in events)
text=(BASE/'generated_driver.f90').read_text()
if VARIANT=='field-loam':
 for i in [3,10,12]:
  line=f'  cfg%tiles(1)%parameters%cofgen({i},:)=cfg%tiles(1)%parameters%cofgen({i},:)*1d-3\n'
  assert text.count(line)==1;text=text.replace(line,'')
 old='  cfg%tiles(1)%initial_state%ponding_depth=.2d0';assert text.count(old)==1
 text=text.replace(old,'  cfg%tiles(1)%initial_state%ponding_depth=0d0')
 old='     forcing%pond_input%rain_rate_cm_day=.05d0*(1d0+.4d0*season)';assert text.count(old)==1
 text=text.replace(old,'     forcing%pond_input%rain_rate_cm_day=merge(.5d0,.05d0,mod(d,7)==6)*(1d0+.4d0*season)')
old='  cfg%numerical%transaction%temporal_tolerance=1d-6';assert text.count(old)==1
text=text.replace(old,old+'\n  cfg%numerical%retain_accepted_step_proposal=.true.')
needle="    call require(r%status==0,'rotation actual daily Richards crop Soil-N')"
assert text.count(needle)==1
text=text.replace(needle,"\n    print *,'SURFACE_DAY_NUMERICS',d+1,r%joint%joint%diagnostics%accepted_substeps, &\n      r%joint%joint%diagnostics%attempts,r%joint%joint%diagnostics%temporal_rejections, &\n      r%joint%joint%diagnostics%solver_rejections,r%joint%joint%diagnostics%max_abs_step_mass_residual, &\n      r%joint%joint%water%completed_t\n"+needle)
a=text.index(' subroutine rotation_continuation(');z=text.index(' subroutine report_water_state(',a);body=text[a:z]
needle='   integer::d,first,code,last';assert body.count(needle)==1
body=body.replace(needle,'   type(fmr_serialized_physical_observation_t)::failure_observation\n'+needle)
needle='\n    n_before=crop_soil_whole_n(state)\n';assert body.count(needle)==1
body=body.replace(needle,'\n    before_state=state;before_water=water'+needle)
needle="    if(r%status/=0)print *,'ROTATION_FAILURE'";assert body.count(needle)==1
body=body.replace(needle,"""    if(r%status/=0)then
     call write_crop_soil_n_joint_restart_file(trim(path)//'.failure-before',column,cfg%tiles(1)%template, &
       670001_int64,before_water,before_state,code)
     call require(code==0,'failure before-state serialization')
     call write_crop_soil_n_joint_restart_file(trim(path)//'.failure-after',column,cfg%tiles(1)%template, &
       670001_int64,water,state,code)
     call require(code==0,'failure after-state serialization')
     call report_water_state('rejected-day-state',d)
     print *,'REJECTION_CLOCK',d+1,r%joint%joint%water%completed_t, &
       r%joint%joint%diagnostics%min_accepted_substep_duration,r%joint%joint%diagnostics%max_temporal_indicator
     print *,'REJECTION_CROP_VIEW',r%joint%joint%chemical%actual_root_cm, &
       r%joint%joint%chemical%potential_root_cm,r%joint%joint%chemical%prepared%corrected_rates%relative_transpiration_used
     print *,'REJECTION_CROP_PREPARED',r%joint%joint%chemical%prepared%ready, &
       r%joint%joint%chemical%prepared%nitrogen_request%status,r%joint%joint%chemical%prepared%candidate%validate()
     failure_observation=backend%observation()
     print *,'REJECTION_LAST_SOLVER',failure_observation%solver_diagnostics%route, &
       failure_observation%solver_equation_residual,failure_observation%solver_equation_residual_available
    endif
"""+needle)
text=text[:a]+body+text[z:]
driver=OUT/'test_surface_n_hydrology.f90';driver.write_text(text)
b=BASE/OPT;ce=[e for e in events if e['category']=='compile'and '-'+OPT in e['command']]
driver_event=next(e for e in ce if Path(e['command'][e['command'].index('-c')+1]).name=='test_surface_n_rotation.f90')
command=driver_event['command'].copy();command[command.index('-c')+1]=str(driver);command[command.index('-o')+1]=str(OUT/'driver.o')
command=[('-J'+str(OUT)if x.startswith('-J')else x)for x in command]
link=next(e['command']for e in events if e['category']=='link'and str(b/'hist')in e['command']).copy()
oldobj=driver_event['command'][-1];assert link.count(oldobj)==1
link=[str(OUT/'driver.o')if x==oldobj else x for x in link];link[link.index('-o')+1]=str(OUT/'hist')
artifacts={str(p):sha(p)for p in b.iterdir()if p.is_file()and p.suffix in ['.o','.mod','.smod']}
records=[]
def run(c,kind):
 t=time.perf_counter()
 with (OUT/(kind+'.stdout')).open('wb')as so,(OUT/(kind+'.stderr')).open('wb')as se:
  r=subprocess.run(c,cwd=OUT,stdout=so,stderr=se,env={**os.environ,'GFORTRAN_UNBUFFERED_ALL':'1','OMP_NUM_THREADS':'1'})
 records.append(dict(command=c,category=kind,seconds=time.perf_counter()-t,returncode=r.returncode))
 (OUT/'events.json').write_text(json.dumps(records,indent=2)+'\n');assert r.returncode==0 if kind!='native' else r.returncode==1,(kind,r.returncode)
run(command,'driver_compile');run(link,'link');run([str(OUT/'hist'),'write',str(OUT/'state.restart'),str(OUT/'endpoint'),'surface-profile','0',str(DAYS)],'native')
assert (OUT/'state.restart.failure-before').read_bytes()==(OUT/'state.restart.failure-after').read_bytes(),'rejected physical/crop/N/native inventory changed'
for p,h in artifacts.items():assert sha(Path(p))==h,p
for p,h in prior['input_sha256'].items():assert sha(ROOT/p)==h,p
assert sha(Path(__file__))==self_sha
r=dict(status='EXPECTED_REJECTION_DIAGNOSTIC_WITH_NATIVE_ROLLBACK_NOT_PHYSICAL_PASS',variant=VARIANT,opt=OPT,days=DAYS,events=records,source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),input_sha256=prior['input_sha256'],provider_artifacts=artifacts,provider_result_sha256=sha(BASE/'result.json'),driver_sha256=sha(driver),runner_sha256=self_sha)
(OUT/'result.json').write_text(json.dumps(r,indent=2)+'\n');print(r['status'])

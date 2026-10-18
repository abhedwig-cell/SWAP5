"""Observe the qualified rotation's full accepted water/N carrier budget.

Only the generated driver gains diagnostics. Production artifacts are source-
and byte-bound to the fresh qualified closure; every native command runs anew.
"""
from pathlib import Path
import hashlib,json,os,shutil,subprocess,time
PROFILE='surface-profile'
DAYS=int(os.environ.get('N_SURFACE_DAYS','730'));assert 1<=DAYS<=730
BOUNDARY=os.environ.get('N_SURFACE_AUDIT_BOUNDARY','provider');assert BOUNDARY in ['provider','fixed-head']
ROOT=Path(__file__).resolve().parents[2];BASE=Path(os.environ['N_SURFACE_PROVIDERS']).resolve();OUT=Path(os.environ['N_SURFACE_ROTATION_DIR']).resolve();OUT.mkdir(exist_ok=False)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
prior=json.loads((BASE/'result.json').read_text());original=json.loads((BASE/'events.json').read_text())
assert prior['status']=='SURFACE_N_B1_ACTUAL_PHYSICAL_PASS_NOT_ADMITTED'
assert sha(BASE/'generated_driver.f90')==prior['generated_driver_sha256']
SELF_SHA=sha(Path(__file__))
for p,h in prior['input_sha256'].items():assert sha(ROOT/p)==h,p
source=(BASE/'generated_driver.f90').read_text();start=source.index(' subroutine rotation_continuation(');end=source.index(' subroutine report_water_state(',start);body=source[start:end]
def replace(a,b):
 global body
 assert body.count(a)==1,a;body=body.replace(a,b)
replace('   integer::d,first,code,last','''   type(mineral_state_t)::audit_mineral
   type(mineral_daily_carrier_t)::audit_carrier
   type(fmr_serialized_physical_observation_t)::audit_observation
   class(transaction_state_t),allocatable::audit_snapshot
   logical::audit_available
   real(real64)::water_flux(5),water_initial,water_final,water_residual,n_flow(8),boundary_n(3),positive_surface
   real(real64)::chemical_flow(4)
   real(real64)::surface_water_flow(6),pond_initial,pond_final,pond_residual,whole_water_residual
   real(real64)::surface_n_flow(2,3),surface_n_initial(2),surface_n_final(2),surface_n_residual(2)
   real(real64)::theta_min,theta_max,head_min,head_max,min_dt,max_indicator
   integer::accepted_total,rejected_total,solver_total,retry_total
   integer::d,first,code,last''')
replace('   do d=first,last-1','''   chemical_flow=0d0
   surface_water_flow=0d0;surface_n_flow=0d0;surface_n_initial=0d0;surface_n_final=0d0
   pond_initial=0d0;pond_final=0d0
   boundary_n=0d0
   water_flux=0d0;n_flow=0d0;water_initial=0d0;water_final=0d0
   theta_min=1d0;theta_max=0d0;head_min=huge(1d0);head_max=-huge(1d0)
   accepted_total=0;rejected_total=0;solver_total=0;retry_total=0;min_dt=1d0;max_indicator=0d0
   do d=first,last-1
    before_state=state''')
replace("    max_w=max(max_w,r%joint%joint%diagnostics%max_abs_step_mass_residual)",'''    call before_state%snapshot(ss,cc);call ss%mineral_snapshot(audit_mineral)
    audit_observation=backend%observation()
    call aggregate_mineral_trace(audit_mineral,audit_observation%accepted_water_flux_substeps, &
      audit_carrier,code,clean_surface_water=.not.atmospheric,atmospheric_n_surface=atmospheric)
    call require(code==0,'audit accepted carrier')
    block
     integer::j,m
     real(real64)::step_dt
     m=size(audit_observation%accepted_water_flux_substeps)
     if(d==first)then
      pond_initial=audit_observation%accepted_water_flux_substeps(1)%pond_start_cm
      surface_n_initial=r%joint%joint%chemical%soil%surface%before
     end if
     pond_final=audit_observation%accepted_water_flux_substeps(m)%pond_end_cm
     do j=1,m
      associate(step=>audit_observation%accepted_water_flux_substeps(j))
       step_dt=step%t1-step%t0
       surface_water_flow=surface_water_flow+[step_dt*step%converged_rain_rate_cm_day, &
        step_dt*step%converged_irrigation_rate_cm_day,step_dt*step%converged_runon_rate_cm_day, &
        step_dt*step%converged_pond_evaporation_cm_day,step%converged_runoff_depth_cm,-step_dt*step%top_flux]
      end associate
     end do
    end block
    surface_n_flow(:,1)=surface_n_flow(:,1)+r%joint%joint%chemical%soil%surface%input
    surface_n_flow(:,2)=surface_n_flow(:,2)+r%joint%joint%chemical%soil%surface%infiltrated
    surface_n_flow(:,3)=surface_n_flow(:,3)+r%joint%joint%chemical%soil%surface%runoff
    surface_n_final=r%joint%joint%chemical%soil%surface%after
    associate(exchange=>r%joint%joint%chemical%soil%process%exchange)
     chemical_flow=chemical_flow+[exchange%nh4_nitrified_kg_m2,exchange%no3_denitrified_kg_m2, &
      exchange%nh4_outflow_kg_m2,exchange%no3_outflow_kg_m2]
    end associate
    boundary_n=boundary_n+[sum(r%joint%joint%chemical%soil%surface%input), &
      audit_carrier%in_bottom*sum(sp%mineral%c_bottom),audit_carrier%in_lateral*sum(sp%mineral%c_lateral)]
    if(d==first)water_initial=audit_carrier%water_start*sp%mineral%inventory%depth_m*100d0
    water_final=audit_carrier%water_end*sp%mineral%inventory%depth_m*100d0
    water_flux=water_flux+100d0*[audit_carrier%surface_water,audit_carrier%in_bottom, &
      audit_carrier%in_lateral,audit_carrier%outflow,audit_carrier%root_water]
    n_flow=n_flow+[r%joint%materials%gross_n,r%joint%materials%volatilized_n, &
      r%joint%joint%chemical%soil%external_in,r%joint%joint%chemical%soil%external_out- &
      r%joint%joint%chemical%internal_supply_kg_m2,r%joint%joint%chemical%fixation_kg_m2, &
      0d0,0d0,r%joint%joint%chemical%internal_supply_kg_m2]
    accepted_total=accepted_total+r%joint%joint%diagnostics%accepted_substeps
    rejected_total=rejected_total+r%joint%joint%diagnostics%temporal_rejections
    solver_total=solver_total+r%joint%joint%diagnostics%solver_rejections
    retry_total=retry_total+r%joint%joint%diagnostics%retries
    min_dt=min(min_dt,r%joint%joint%diagnostics%min_accepted_substep_duration)
    max_indicator=max(max_indicator,r%joint%joint%diagnostics%max_temporal_indicator)
    call water%snapshot(audit_snapshot,audit_available)
    call require(audit_available,'audit water snapshot')
    select type(s=>audit_snapshot)
    class is(fmr_b110_physical_state_t)
     theta_min=min(theta_min,minval(s%water_content));theta_max=max(theta_max,maxval(s%water_content))
     head_min=min(head_min,minval(s%pressure_head));head_max=max(head_max,maxval(s%pressure_head))
    class default
     error stop 'audit unexpected water state'
    end select
    max_w=max(max_w,r%joint%joint%diagnostics%max_abs_step_mass_residual)''')
replace('     n_output=n_output+sum(harvest_record%exported_n)*1d-4','''     n_output=n_output+sum(harvest_record%exported_n)*1d-4
     n_flow(6)=n_flow(6)+sum(harvest_record%exported_n)*1d-4''')
replace('     n_input=n_input+crop_soil_whole_n(state)-n_before','''     n_input=n_input+crop_soil_whole_n(state)-n_before
     n_flow(7)=n_flow(7)+crop_soil_whole_n(state)-n_before''')
replace("   print *,'ROTATION_730_DAYS_PASS',first,uptake,max_n,max_w",'''   water_residual=water_initial+sum(water_flux(:3))-sum(water_flux(4:))-water_final
   call require(abs(water_residual)<=1d-10,'audit cumulative water hard budget')
   pond_residual=pond_initial+sum(surface_water_flow(:3))-sum(surface_water_flow(4:))-pond_final
   whole_water_residual=water_residual+pond_residual
   surface_n_residual=surface_n_initial+surface_n_flow(:,1)-sum(surface_n_flow(:,2:3),dim=2)-surface_n_final
   call require(abs(pond_residual)<=1d-10.and.abs(whole_water_residual)<=1d-10,'audit whole water hard budget')
   call require(maxval(abs(surface_n_residual))<=1d-12,'audit independent surface species budgets')
   print *,'AUDIT_SURFACE_WATER_CM',pond_initial,surface_water_flow,pond_final,pond_residual,whole_water_residual
   print *,'AUDIT_SURFACE_N_KG_M2',surface_n_initial,surface_n_flow,surface_n_final,surface_n_residual
   print *,'AUDIT_WATER_CM',water_initial,water_flux,water_final,water_residual
   print *,'AUDIT_N_KG_M2',n_flow
   print *,'AUDIT_CHEMICAL_KG_M2',chemical_flow
   call require(abs(sum(boundary_n)-n_flow(3))<=1d-12,'audit separately integrated boundary nitrogen')
   if(atmospheric)call require(boundary_n(1)>0d0,'audit positive atmospheric nitrogen')
   print *,'AUDIT_BOUNDARY_N_KG_M2',boundary_n
   print *,'AUDIT_STATE_RANGE',theta_min,theta_max,head_min,head_max
   print *,'AUDIT_NUMERICAL',accepted_total,rejected_total,solver_total,retry_total,min_dt,max_indicator
   print *,'ROTATION_730_DAYS_PASS',first,uptake,max_n,max_w''')
if BOUNDARY=='fixed-head':
 assert prior.get('hydrology')=='field-loam' and prior.get('max_committed_substeps')==10000
 # Every day has a complete native checkpoint. Fresh transition windows can
 # compare whole native states rather than re-executing years after each restart.
 replace('    if(d+1==1.or.d+1==120.or.d+1==121.or.d+1==365.or.d+1==366.or.d+1==500)then',
         '    if(.true.)then')
 replace('     forcing%bottom_flux=sum(forcing%root_extraction_sink)-.003d0',
         '     forcing%bottom_head=-75d0 ! independently responding prescribed-head mode 5')
source=source[:start]+body+source[end:]
if BOUNDARY=='fixed-head':
 old='  cfg%tiles(1)%initial_state%ponding_depth=0d0';assert source.count(old)==1
 source=source.replace(old,old+'\n  cfg%tiles(1)%parameters%bottom_mode=5\n  cfg%tiles(1)%base_forcing%bottom_head=-75d0')
generated=OUT/'water_audit.f90';generated.write_text(source)
events=[];results={};artifacts={}
def run(c,b,category):
 c=list(map(str,c));t=time.perf_counter();i=len(events)
 if category=='native':
  with(OUT/f'{i}.stdout').open('wb')as so,(OUT/f'{i}.stderr').open('wb')as se:
   r=subprocess.run(c,cwd=b,stdout=so,stderr=se,env={**os.environ,'GFORTRAN_UNBUFFERED_ALL':'1','OMP_NUM_THREADS':'1'})
  r.stdout=(OUT/f'{i}.stdout').read_bytes();r.stderr=(OUT/f'{i}.stderr').read_bytes()
 else:r=subprocess.run(c,cwd=b,capture_output=True)
 for stream in ['stdout','stderr']:(OUT/f'{i}.{stream}').write_bytes(getattr(r,stream))
 events.append(dict(command=c,category=category,returncode=r.returncode,seconds=time.perf_counter()-t,stdout=f'{i}.stdout',stderr=f'{i}.stderr'));(OUT/'events.json').write_text(json.dumps(events,indent=2)+'\n')
 assert r.returncode==0,r.stdout.decode()+r.stderr.decode();return r.stdout.decode()
for opt in ['O0','O2']:
 b=OUT/opt;b.mkdir();base=BASE/opt
 for name in ['matrix_fixture.inc','crop_oracle.inc','material_oracle.inc']:
  if(base/name).exists():shutil.copyfile(base/name,b/name)
 ce=[e for e in original if e['category']=='compile'and'-'+opt in e['command']]
 flags=ce[-1]['command'][1:ce[-1]['command'].index('-c')];flags=[x.replace('-J'+str(base),'-J'+str(b))for x in flags]+['-I'+str(b)]
 for p in base.glob('*.mod'):artifacts[str(p)]=sha(p)
 objects=[Path(e['command'][-1])for e in ce[:-1]]
 for p in objects:artifacts[str(p)]=sha(p)
 obj=b/'audit.o';exe=b/'audit';run(['gfortran',*flags,'-c',generated,'-o',obj],b,'driver_compile');run(['gfortran',*flags,*objects,obj,'-o',exe],b,'link')
 stdout=run([exe,'write',b/'restart',b/'endpoint',PROFILE,'0',str(DAYS)],b,'native')
 # Full original-driver endpoint comparison occurs in the companion baseline phase.
 assert 'SURFACE_N_B1_PHYSICAL_DAYS' in stdout
 rows={}
 for line in stdout.splitlines():
  if line.strip().startswith('AUDIT_'):
   fields=line.split();rows[fields[0]]=[float(x.replace('D','E'))for x in fields[1:]]
 assert set(rows)=={'AUDIT_WATER_CM','AUDIT_N_KG_M2','AUDIT_STATE_RANGE','AUDIT_NUMERICAL','AUDIT_BOUNDARY_N_KG_M2','AUDIT_SURFACE_WATER_CM','AUDIT_SURFACE_N_KG_M2','AUDIT_CHEMICAL_KG_M2'}
 results[opt]=dict(endpoint=sha(b/'endpoint'),stdout=stdout,metrics=rows)
assert results['O0']==results['O2']
for p,h in artifacts.items():assert sha(Path(p))==h,p
for p,h in prior['input_sha256'].items():assert sha(ROOT/p)==h,p
assert sha(Path(__file__))==SELF_SHA
r=dict(status='SURFACE_N_B1_ROTATION_WATER_N_AUDIT_PASS_NOT_ADMITTED',days=DAYS,boundary=BOUNDARY,execution_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),profile=PROFILE,provider_result_sha256=sha(BASE/'result.json'),input_sha256={**prior['input_sha256'],str(Path(__file__).relative_to(ROOT)):sha(Path(__file__))},generated_driver_sha256=sha(generated),artifacts=artifacts,results=results,cost_seconds={c:sum(e['seconds']for e in events if e['category']==c)for c in ['driver_compile','link','native']})
(OUT/'result.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r['results']['O0']['metrics'],indent=2))

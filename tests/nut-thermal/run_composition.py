"""Retain BASE assertions and add accepted thermal physical/restart composition.

Generate from the admitted calendar driver. Prescribed-environment-only rejection
cases remain executed in the unchanged BASE driver. Thermal oracle temperatures
come from the literal source loop over the actual accepted profile.
"""
from pathlib import Path
import hashlib,json,os,sys
ROOT=Path(__file__).resolve().parents[2]
OUT=Path(os.environ['N_THERMAL_COMPOSITION_DIR']).resolve();OUT.mkdir(exist_ok=False)
(OUT/'drivers').mkdir()
sha=lambda b:hashlib.sha256(b).hexdigest()
original=ROOT/'tests/nut-calendar/test_calendar_joint.f90';s=original.read_text()
inputs={str(original.relative_to(ROOT)):sha(original.read_bytes())}
def replace(old,new):
 global s
 assert s.count(old)==1,(old,s.count(old));s=s.replace(old,new)
replace('program test_calendar_joint','program test_thermal_joint')
replace(' use mod_fmr_crop_soil_n_calendar_application',' use mod_fmr_crop_soil_n_thermal_application\n use mod_fmr_soil_n_accepted_temperature\n use mod_crop_soil_n_calendar_day,only:select_calendar_material_batch\n use mod_soil_temperature_contract\n use mod_restricted_soil_temperature,only:initialize_soil_temperature_parameters\n use mod_fmr_crop_soil_n_calendar_application')
for old,new in [('crop_soil_n_joint_restart_t','crop_soil_n_thermal_restart_t'),('export_crop_soil_n_joint_restart(','export_crop_soil_n_thermal_restart('),('restore_crop_soil_n_joint_restart(','restore_crop_soil_n_thermal_restart(')]:s=s.replace(old,new)
replace(' call initialize_application_config(cfg,-75d0,k)',' call initialize_application_config(cfg,-75d0,k)\n call enable_heat()')
# Native decode must verify the persisted certificate against the actual immutable
# parameters; no certificate is reconstructed from supplied parameters alone.
s=s.replace('sp,cp,water,state,status)','sp,cp,water,state,status,cfg%tiles(1)%parameters)')
replace(" call fmr_new_b110_temporal_indicator_committed_state(water,column%column_id,cfg%tiles(1)%initial_state,0d0,ok, &\n   spread(0d0,1,numnod));call require(ok,'water initialize')"," call initialize_thermal_water(water)")
start=s.index(' block\n  integer::i\n  do i=1,5');end=s.index(' end block',start)+len(' end block')
s=s[:start]+''' ! Prescribed-temperature negatives execute in the unchanged BASE driver.
 block
  type(kernel_committed_state_t)::uncertified
  type(fmr_b110_physical_parameters_t)::wrong
  type(soil_n_day_environment_t)::sampled
  real(real64)::depth
  call fmr_new_b110_temporal_indicator_committed_state(uncertified,column%column_id,cfg%tiles(1)%initial_state,0d0,ok,spread(0d0,1,numnod))
  call run_crop_soil_n_thermal_interval(backend,column,cfg%tiles(1)%template,cfg%tiles(1)%parameters,uncertified, &
   cfg%tiles(1)%base_forcing,cfg%numerical,state,weather,0d0,1d0,items,split,policy,result)
  call require(result%status/=0,'uncertified heat rejected');call unchanged()
  wrong=cfg%tiles(1)%parameters;wrong%z(1)=wrong%z(1)-.01d0
  other_water=water;other_state=state
  call run_crop_soil_n_thermal_interval(backend,column,cfg%tiles(1)%template,wrong,other_water, &
   cfg%tiles(1)%base_forcing,cfg%numerical,other_state,weather,0d0,1d0,items,split,policy,result)
  call require(result%status/=0.and.other_water%current_revision()==water%current_revision(),'same-size changed certified grid rejects')
  call sample_accepted_soil_n_environment(water,999_int64,0_int64,-1d0,0d0,.3d0,sampled,depth,status)
  call require(status/=0,'stale lineage read rejects')
  call sample_accepted_soil_n_environment(water,water%current_lineage_id(),1_int64,-1d0,0d0,.3d0,sampled,depth,status)
  call require(status/=0,'stale revision read rejects')
  call sample_accepted_soil_n_environment(water,water%current_lineage_id(),0_int64,0d0,1d0,.3d0,sampled,depth,status)
  call require(status/=0,'stale time read rejects')
 end block'''+s[end:]
start=s.index('  ! Stale day-one forcing');end=s.index('  end block',start)+len('  end block')
s=s[:start]+s[end:]
replace('  oracle_p=sp;oracle_p%environment%temperature_c=5d0','  oracle_p=sp;oracle_p%environment%temperature_c=accepted_literal_temperature(water,0d0,1d0)')
replace('result%joint%joint%chemical%soil%temperature_used_c==5d0','result%joint%joint%chemical%soil%temperature_used_c==oracle_p%environment%temperature_c')
replace('  oracle_p=sp;oracle_p%environment%temperature_c=30d0','  oracle_p=sp;oracle_p%environment%temperature_c=accepted_literal_temperature(w,1d0,2d0)')
replace('r%joint%joint%chemical%soil%temperature_used_c==30d0','r%joint%joint%chemical%soil%temperature_used_c==accepted_literal_temperature(w,1d0,2d0)')
replace('  forcing=cfg%tiles(1)%base_forcing;forcing%bottom_flux=.1d0;forcing%drainage_flux_by_level=0d0','  forcing=cfg%tiles(1)%base_forcing;forcing%bottom_flux=.1d0;forcing%drainage_flux_by_level=0d0\n  forcing%soil_temperature%prescribed_surface_temperature_c=30d0')
start=s.index('  type(soil_n_amendment_calendar_t)::plan',s.index(' subroutine run_selected'))
end=s.index('\n end subroutine',start)
s=s[:start]+'''  type(soil_n_amendment_calendar_t)::plan
  type(soil_n_material_input_t),allocatable::batch(:)
  integer::code
  result=senescence_joint_result_t()
  if(trim(profile)=='manual')then
   batch=items
  else
   call make_calendar(items,plan,code);if(code/=0)return
   call select_calendar_material_batch(plan,t0,t1,batch,code);if(code/=0)return
  end if
  call run_crop_soil_n_thermal_interval(backend,column,template,parameters,water,forcing,config, &
   chemical,weather,t0,t1,batch,split,policy,result)'''+s[end:]
replace(" print '(A)','CALENDAR_ACTUAL_RICHARDS_DELAYED_LITERAL_ATOMIC_PENDING_OPAQUE_DISK=PASS'"," print '(A)','THERMAL_ACTUAL_RICHARDS_DELAYED_LITERAL_ATOMIC_PENDING_OPAQUE_DISK=PASS'")
replace("  call require(water%current_revision()==initial_water%current_revision(),'water revision unchanged')", "  call require(water%current_revision()==initial_water%current_revision(),'water revision unchanged')\n  call thermal_water_unchanged(water,initial_water)")
fixture=ROOT/'tests/nut-thermal/thermal_fixture.inc';inputs[str(fixture.relative_to(ROOT))]=sha(fixture.read_bytes())
replace(" include 'matrix_fixture.inc'"," include 'matrix_fixture.inc'\n"+fixture.read_text())
target=OUT/'drivers/test_thermal_joint.f90';target.write_text(s)
p=ROOT/'tests/nut-calendar/run_calendar.py';runner=p.read_text();inputs[str(p.relative_to(ROOT))]=sha(p.read_bytes())
old="if mode=='joint':drivers += [ROOT/'tests/nut-calendar/test_calendar_joint.f90']"
assert runner.count(old)==1;runner=runner.replace(old,old+"+[OUT/'drivers/test_thermal_joint.f90']")
runner=runner.replace("inputs[str(d.relative_to(ROOT))]=sha(d)","inputs[str(d.relative_to(ROOT)) if d.is_relative_to(ROOT) else 'generated/'+d.name]=sha(d)")
runner=runner.replace("if d.stem!='test_calendar_joint':","if d.stem not in ['test_calendar_joint','test_thermal_joint']:")
needle="for profile in ['manual','calendar']:\n   first="
assert runner.count(needle)==1
runner=runner.replace(needle,"for profile in ['manual','calendar']:\n   prefix='' if d.stem=='test_calendar_joint' else 'thermal-'\n   first=")
runner=runner.replace("(profile+'-","(prefix+profile+'-")
runner=runner.replace("(b/('manual-'+suffix))","(b/(prefix+'manual-'+suffix))").replace("(b/('calendar-'+suffix))","(b/(prefix+'calendar-'+suffix))")
# Check cross-optimization native endpoint bytes for both real physical routes.
needle="assert result['runs']['O0']['drivers']['test_calendar_joint'][profile]['endpoint_sha256']==result['runs']['O2']['drivers']['test_calendar_joint'][profile]['endpoint_sha256']"
assert runner.count(needle)==1
runner=runner.replace(needle,needle+"\n  assert result['runs']['O0']['drivers']['test_thermal_joint'][profile]['endpoint_sha256']==result['runs']['O2']['drivers']['test_thermal_joint'][profile]['endpoint_sha256']")
# The literal profile oracle is extracted by the small driver and pinned here.
profile=Path(os.environ['N_THERMAL_LITERAL_PROFILE']).read_bytes()
for opt in ['O0','O2']:
 b=OUT/opt;b.mkdir();(b/'literal_profile.inc').write_bytes(profile)
(OUT/'executed_runner.py').write_text(runner)
(OUT/'GENERATION.json').write_text(json.dumps(dict(inputs=inputs,generated_driver_sha256=sha(s.encode()),runner_sha256=sha(runner.encode()),profile_oracle_sha256=sha(profile)),indent=2)+'\n')
if os.environ.get('N_THERMAL_GENERATE_ONLY'):
 print('THERMAL_DRIVER_GENERATED');sys.exit(0)
os.environ['CALENDAR_RESULT_DIR']=str(OUT);sys.argv=[__file__,'joint']
exec(compile(runner,str(OUT/'executed_runner.py'),'exec'),globals())

! Explicit bounded daily application: stage science + diagnostics, save, publish.
module mod_crop_soil_n_saved_cycle_output
 use iso_fortran_env,only:real64,int64
 use ieee_arithmetic,only:ieee_is_finite
 use mod_crop_ext_saved_residue
 use mod_crop_n_saved_generation
 use mod_crop_soil_n_saved_harvest
 use mod_crop_soil_n_saved_output,only:run_crop_soil_n_saved_harvest
 use mod_crop_soil_n_thermal_saved_output,only:run_crop_soil_n_thermal_saved_harvest,capture_crop_soil_n_thermal_saved_harvest
 use mod_crop_soil_n_configuration,only:crop_n_configuration_t
 use mod_wofost81_crop_owner_state,only:wofost81_crop_owner_state_t
 use mod_crop_soil_n_output_day,only:OUTPUT_DAY_OK,OUTPUT_DAY_INVALID,OUTPUT_DAY_SAVE_FAILED,OUTPUT_DAY_VIEW_FAILED
 use mod_soil_n_crop_extended_output
 use mod_crop_n_output_generation
 use mod_crop_ext_csv_file
 use mod_crop_senescence_residue,only:crop_residue_pending_t
 use mod_fmr_crop_soil_n_senescence_application
 use mod_fmr_crop_soil_n_thermal_application,only:soil_n_thermal_template,run_crop_soil_n_thermal_interval,thermal_crop_soil_states_match
 use mod_fmr_crop_soil_n_joint_application,only:JOINT_OK,JOINT_COMMIT_REJECTED,crop_soil_n_joint_states_match
 use mod_canonical_contracts,only:canonical_numerical_config_t
 use mod_fmr_runtime_core,only:fmr_logical_column_t,fmr_template_t
 use mod_fmr_serialized_reference_backend,only:fmr_serialized_reference_backend_t, &
   fmr_b110_physical_parameters_t,fmr_b110_physical_forcing_t
 use mod_kernel_transactions,only:kernel_committed_state_t
 use mod_crop_soil_n_day,only:crop_soil_state_t,crop_soil_harvest_receipt_t,crop_soil_harvest_observation_t, &
  initialize_crop_soil_successor,harvest_crop_soil_boundary,CROP_SOIL_INVALID
 use mod_crop_soil_n_material_day,only:soil_n_material_input_t
 use mod_crop_senescence_residue,only:crop_senescence_policy_t
 use mod_b111_soil_n_addition,only:b111_soil_n_split_parameters_t
 use mod_wofost_one_day_structural_evolution,only:wofost_one_day_forcing_t
 use mod_soil_n_day_environment,only:soil_n_day_environment_t
 implicit none
 private
 public::run_crop_soil_n_saved_cycle_day,run_crop_soil_n_saved_successor,run_crop_soil_n_saved_cycle_harvest
contains
 subroutine run_crop_soil_n_saved_cycle_day(path,date,report,water_id,backend,column,template,parameters,water, &
     forcing,config,chemical,weather,t0,t1,items,split,policy,output,saved,dates,rows,result,status,environment,csv_path)
  character(*),intent(in)::path,date
  logical,intent(in)::report
  integer(int64),intent(in)::water_id
  type(fmr_serialized_reference_backend_t),intent(inout)::backend
  type(fmr_logical_column_t),intent(in)::column
  type(fmr_template_t),intent(in)::template
  type(fmr_b110_physical_parameters_t),target,intent(in)::parameters
  type(kernel_committed_state_t),intent(inout)::water
  type(fmr_b110_physical_forcing_t),intent(in)::forcing
  type(canonical_numerical_config_t),intent(in)::config
  type(crop_soil_state_t),intent(inout)::chemical
  type(wofost_one_day_forcing_t),intent(in)::weather
  real(real64),intent(in)::t0,t1
  type(soil_n_material_input_t),intent(in)::items(:)
  type(b111_soil_n_split_parameters_t),intent(in)::split
  type(crop_senescence_policy_t),intent(in)::policy
  type(crop_ext_state_t),intent(inout)::output
  type(crop_ext_saved_residue_t),intent(inout)::saved
  character(10),allocatable,intent(inout)::dates(:)
  type(crop_ext_row_t),allocatable,intent(inout)::rows(:)
  type(senescence_joint_result_t),intent(out)::result
  integer,intent(out)::status
  type(soil_n_day_environment_t),intent(in),optional::environment
  character(*),intent(in),optional::csv_path
  type(kernel_committed_state_t)::water_trial
  type(crop_soil_state_t)::chemical_trial
  type(crop_ext_state_t)::output_trial
  type(crop_ext_saved_residue_t)::saved_trial
  type(crop_residue_pending_t)::pending
  type(crop_ext_row_t)::row
  type(crop_ext_row_t),allocatable::rows_trial(:)
  character(10),allocatable::dates_trial(:)
  real(real64)::v(17),sv(9),dm(4),nitrogen(4),up(2)
  character(128)::line
  integer::code,n
  logical::ready,thermal,has
  result=senescence_joint_result_t();status=OUTPUT_DAY_INVALID
  if(.not.all(ieee_is_finite([t0,t1])))return
  if(t1-t0/=1d0)return
  thermal=soil_n_thermal_template(template)
  ! The thermal route owns its accepted profile; explicit day temperature is
  ! not a competing forcing authority for that route.
  if(thermal.and.present(environment))return
  if(.not.allocated(rows).or..not.allocated(dates))return
  if(.not.output_history_valid(dates,rows))return
  call output%snapshot(v(1),v(2:9),v(10:17),ready)
  if(.not.ready.or.v(1)/=t0)return
  call saved%snapshot(sv,ready)
  if(.not.ready.or.sv(1)/=t0)return
  if(.not.states_match(water,chemical,thermal))return
  if(report)then
   row%emitted=.true.
   call format_crop_ext_row(date,row,line,code);if(code/=0)return
   if(size(dates)>0)then
    if(date<=dates(size(dates)))return
   end if
  end if
  water_trial=water;chemical_trial=chemical;output_trial=output;saved_trial=saved
  if(thermal)then
   call run_crop_soil_n_thermal_interval(backend,column,template,parameters,water_trial,forcing,config, &
     chemical_trial,weather,t0,t1,items,split,policy,result)
  else
   call run_crop_soil_n_senescence_interval(backend,column,template,parameters,water_trial,forcing,config, &
     chemical_trial,weather,t0,t1,items,split,policy,result,environment)
  end if
  if(result%status/=JOINT_OK)return
  if(.not.states_match(water_trial,chemical_trial,thermal))then;result%status=JOINT_COMMIT_REJECTED;return;end if
  dm=0d0;nitrogen=0d0
  call chemical_trial%pending_snapshot(pending,has)
  if(has)then
   if(.not.pending%valid().or.pending%clock/=t1)then;result%status=JOINT_COMMIT_REJECTED;return;end if
   dm(1:3)=pending%dry_matter_kg_ha;nitrogen(1:3)=pending%nitrogen_kg_ha
  end if
  associate(exchange=>result%joint%joint%chemical%soil%process%exchange)
   up=[exchange%nh4_crop_uptake_kg_m2,exchange%no3_crop_uptake_kg_m2]
  end associate
  call observe_crop_ext_saved_residue(output_trial,saved_trial,t0,t1,up,dm,nitrogen,report,row,code)
  if(code/=0)then;result%status=JOINT_COMMIT_REJECTED;return;end if
  n=size(rows);allocate(dates_trial(n+merge(1,0,report)),rows_trial(n+merge(1,0,report)))
  dates_trial(:n)=dates;rows_trial(:n)=rows
  if(report)then
   dates_trial(n+1)=date;rows_trial(n+1)=row
  end if
  call write_crop_n_saved_generation(path,column,template,water_id,water_trial,chemical_trial, &
    output_trial,saved_trial,dates_trial,rows_trial,code)
  if(code/=0)then;result%status=JOINT_COMMIT_REJECTED;status=OUTPUT_DAY_SAVE_FAILED;return;end if
  ! The generation is authoritative before any caller memory is published.
  water=water_trial;chemical=chemical_trial;output=output_trial;saved=saved_trial
  call move_alloc(dates_trial,dates);call move_alloc(rows_trial,rows)
  status=OUTPUT_DAY_OK
  if(present(csv_path))then
   call write_crop_ext_csv_file(csv_path,dates,rows,output,code)
   if(code/=0)status=OUTPUT_DAY_VIEW_FAILED
  end if
 end subroutine

 logical function states_match(water,chemical,thermal)result(ok)
  type(kernel_committed_state_t),intent(in)::water
  type(crop_soil_state_t),intent(in)::chemical
  logical,intent(in)::thermal
  if(thermal)then
   ok=thermal_crop_soil_states_match(water,chemical)
  else
   ok=crop_soil_n_joint_states_match(water,chemical)
  end if
 end function
 logical function clocks_match(water,output,saved)result(ok)
  type(kernel_committed_state_t),intent(in)::water
  type(crop_ext_state_t),intent(in)::output
  type(crop_ext_saved_residue_t),intent(in)::saved
  real(real64)::o(17),v(9),time
  logical::ready
  ok=.false.
  call water%current_time(time,ready);if(.not.ready)return
  call output%snapshot(o(1),o(2:9),o(10:17),ready);if(.not.ready)return
  call saved%snapshot(v,ready);if(.not.ready)return
  ok=time==o(1).and.time==v(1)
 end function
 subroutine run_crop_soil_n_saved_successor(path,column,template,water_id,water,chemical,crop,cp,crop_id, &
   output,saved,dates,rows,result,status)
  character(*),intent(in)::path,dates(:)
  type(fmr_logical_column_t),intent(in)::column
  type(fmr_template_t),intent(in)::template
  integer(int64),intent(in)::water_id,crop_id
  type(kernel_committed_state_t),intent(in)::water
  type(crop_soil_state_t),intent(inout)::chemical
  type(wofost81_crop_owner_state_t),intent(in)::crop
  type(crop_n_configuration_t),intent(in)::cp
  type(crop_ext_state_t),intent(in)::output
  type(crop_ext_saved_residue_t),intent(in)::saved
  type(crop_ext_row_t),intent(in)::rows(:)
  type(crop_soil_harvest_receipt_t),intent(out)::result
  integer,intent(out)::status
  type(crop_soil_state_t)::trial
  integer::code
  result=crop_soil_harvest_receipt_t();status=OUTPUT_DAY_INVALID
  if(.not.clocks_match(water,output,saved))return
  if(.not.states_match(water,chemical,soil_n_thermal_template(template)))return
  trial=chemical
  call initialize_crop_soil_successor(trial,crop,cp,crop_id,result)
  if(result%status/=0)return
  call write_crop_n_saved_generation(path,column,template,water_id,water,trial,output,saved,dates,rows,code)
  if(code/=0)then;result%status=CROP_SOIL_INVALID;status=OUTPUT_DAY_SAVE_FAILED;return;end if
  chemical=trial;status=OUTPUT_DAY_OK
 end subroutine
 subroutine run_crop_soil_n_saved_cycle_harvest(path,phase,column,template,water_id,water,chemical, &
   output,saved,dates,rows,result,status,observation)
  character(*),intent(in)::path,dates(:)
  integer,intent(in)::phase
  type(fmr_logical_column_t),intent(in)::column
  type(fmr_template_t),intent(in)::template
  integer(int64),intent(in)::water_id
  type(kernel_committed_state_t),intent(in)::water
  type(crop_soil_state_t),intent(inout)::chemical
  type(crop_ext_state_t),intent(in)::output
  type(crop_ext_saved_residue_t),intent(inout)::saved
  type(crop_ext_row_t),intent(in)::rows(:)
  type(crop_soil_harvest_receipt_t),intent(out)::result
  integer,intent(out)::status
  type(crop_soil_harvest_observation_t),optional,intent(in)::observation
  type(crop_soil_state_t)::trial
  type(crop_ext_saved_residue_t)::captured
  type(crop_residue_pending_t)::pending
  real(real64)::v(9),dm(4),nitrogen(4)
  logical::ready,has,thermal
  integer::code
  result=crop_soil_harvest_receipt_t();status=OUTPUT_DAY_INVALID
  thermal=soil_n_thermal_template(template)
  if(phase/=1)then
   if(thermal)then
    call run_crop_soil_n_thermal_saved_harvest(path,phase,column,template,water_id,water,chemical, &
      output,saved,dates,rows,result,status,observation)
   else
    call run_crop_soil_n_saved_harvest(path,phase,column,template,water_id,water,chemical, &
      output,saved,dates,rows,result,status,observation)
   end if
   return
  end if
  if(.not.clocks_match(water,output,saved))return
  if(.not.states_match(water,chemical,thermal))return
  ! A completed active day saves exactly its current physical mortality.
  ! Replace it only after checking that identity, then merge harvest returns.
  call saved%snapshot(v,ready);dm=0d0;nitrogen=0d0
  call chemical%pending_snapshot(pending,has)
  if(has)then
   if(.not.pending%valid().or.pending%clock/=v(1))return
   dm(1:3)=pending%dry_matter_kg_ha;nitrogen(1:3)=pending%nitrogen_kg_ha
  end if
  if(any(v(2:5)/=dm).or.any(v(6:9)/=nitrogen))return
  trial=chemical;call harvest_crop_soil_boundary(trial,result)
  if(result%status/=0)return
  if(thermal)then
   call capture_crop_soil_n_thermal_saved_harvest(water,trial,output,captured,code)
  else
   call capture_crop_soil_n_saved_harvest(water,trial,output,captured,code)
  end if
  if(code/=0)then;result%status=CROP_SOIL_INVALID;return;end if
  call write_crop_n_saved_generation(path,column,template,water_id,water,trial,output,captured,dates,rows,code)
  if(code/=0)then;result%status=CROP_SOIL_INVALID;status=OUTPUT_DAY_SAVE_FAILED;return;end if
  chemical=trial;saved=captured;status=OUTPUT_DAY_OK
 end subroutine
end module

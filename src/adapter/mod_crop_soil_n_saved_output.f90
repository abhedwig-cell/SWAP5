! Explicit heat-OFF harvest -> retired/fallow output route. No default dispatch.
module mod_crop_soil_n_saved_output
 use iso_fortran_env,only:real64,int64
 use ieee_arithmetic,only:ieee_is_finite
 use mod_crop_ext_saved_residue
 use mod_crop_soil_n_saved_harvest
 use mod_crop_n_saved_generation
 use mod_soil_n_crop_extended_output
 use mod_crop_n_output_generation,only:output_history_valid
 use mod_crop_ext_csv_file,only:write_crop_ext_csv_file
 use mod_crop_soil_n_output_day,only:OUTPUT_DAY_OK,OUTPUT_DAY_INVALID,OUTPUT_DAY_SAVE_FAILED,OUTPUT_DAY_VIEW_FAILED
 use mod_crop_soil_n_output_harvest,only:OUTPUT_HARVEST_STAGE,OUTPUT_HARVEST_INCORPORATE,OUTPUT_HARVEST_RETIRE
 use mod_crop_soil_n_day
 use mod_kernel_transactions,only:kernel_committed_state_t
 use mod_fmr_runtime_core,only:fmr_logical_column_t,fmr_template_t
 use mod_fmr_serialized_reference_backend,only:fmr_serialized_reference_backend_t, &
   fmr_b110_physical_parameters_t,fmr_b110_physical_forcing_t
 use mod_canonical_contracts,only:canonical_numerical_config_t
 use mod_fmr_crop_soil_n_material_application
 use mod_fmr_crop_soil_n_joint_application,only:JOINT_OK,JOINT_COMMIT_REJECTED,crop_soil_n_joint_states_match
 use mod_fmr_crop_soil_n_thermal_application,only:soil_n_thermal_template
 use mod_crop_soil_n_material_day,only:soil_n_material_input_t
 use mod_b111_soil_n_addition,only:b111_soil_n_split_parameters_t
 use mod_wofost_one_day_structural_evolution,only:wofost_one_day_forcing_t
 use mod_soil_n_day_environment,only:soil_n_day_environment_t
 implicit none
 private
 public::run_crop_soil_n_saved_harvest,run_crop_soil_n_saved_fallow_day
contains
 subroutine run_crop_soil_n_saved_harvest(path,phase,column,template,water_id,water,chemical, &
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
  type(crop_soil_state_t)::ct
  type(crop_ext_saved_residue_t)::st
  real(real64)::v(9)
  logical::ready
  integer::code
  result=crop_soil_harvest_receipt_t();status=OUTPUT_DAY_INVALID
  if(soil_n_thermal_template(template))return
  if(.not.crop_soil_n_joint_states_match(water,chemical))return
  ct=chemical;st=saved;call st%snapshot(v,ready)
  select case(phase)
  case(OUTPUT_HARVEST_STAGE)
   if(ready)return
   call harvest_crop_soil_boundary(ct,result)
   if(result%status/=0)return
   call capture_crop_soil_n_saved_harvest(water,ct,output,st,code)
   if(code/=0)then;result%status=CROP_SOIL_INVALID;return;end if
  case(OUTPUT_HARVEST_INCORPORATE)
   if(.not.ready)return
   call consume_crop_soil_harvest_pending(ct,result)
  case(OUTPUT_HARVEST_RETIRE)
   if(.not.ready.or..not.present(observation))return
   call acknowledge_crop_soil_harvest(ct,observation,result)
  case default
   return
  end select
  if(result%status/=0)return
  call write_crop_n_saved_generation(path,column,template,water_id,water,ct,output,st,dates,rows,code)
  if(code/=0)then;result%status=CROP_SOIL_INVALID;status=OUTPUT_DAY_SAVE_FAILED;return;end if
  chemical=ct;saved=st;status=OUTPUT_DAY_OK
 end subroutine
 subroutine run_crop_soil_n_saved_fallow_day(path,date,report,water_id,backend,column,template,parameters,water, &
   forcing,config,chemical,weather,t0,t1,items,split,output,saved,dates,rows,result,status,environment,csv_path)
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
  type(crop_ext_state_t),intent(inout)::output
  type(crop_ext_saved_residue_t),intent(inout)::saved
  character(10),allocatable,intent(inout)::dates(:)
  type(crop_ext_row_t),allocatable,intent(inout)::rows(:)
  type(material_joint_result_t),intent(out)::result
  integer,intent(out)::status
  type(soil_n_day_environment_t),intent(in),optional::environment
  character(*),intent(in),optional::csv_path
  type(kernel_committed_state_t)::wt
  type(crop_soil_state_t)::ct
  type(crop_ext_state_t)::ot
  type(crop_ext_saved_residue_t)::st
  type(crop_ext_row_t)::row
  type(crop_ext_row_t),allocatable::rt(:)
  character(10),allocatable::dt(:)
  real(real64)::v(9),o(17),up(2)
  logical::ready
  character(128)::line
  integer::code,n
  result=material_joint_result_t();status=OUTPUT_DAY_INVALID
  if(.not.all(ieee_is_finite([t0,t1])))return
  if(soil_n_thermal_template(template))return
  if(.not.allocated(rows).or..not.allocated(dates))return
  if(.not.output_history_valid(dates,rows))return
  call saved%snapshot(v,ready);if(.not.ready)return
  call output%snapshot(o(1),o(2:9),o(10:17),ready);if(.not.ready)return
  if(t0/=v(1).or.t0/=o(1).or.t1-t0/=1d0)return
  if(report)then
   row%emitted=.true.
   call format_crop_ext_row(date,row,line,code);if(code/=0)return
   if(size(dates)>0)then
    if(date<=dates(size(dates)))return
   end if
  end if
  wt=water;ct=chemical;ot=output;st=saved
  call run_crop_soil_n_material_interval(backend,column,template,parameters,wt,forcing,config, &
   ct,weather,t0,t1,items,split,result,environment,fallow=.true.)
  if(result%status/=JOINT_OK)return
  associate(exchange=>result%joint%chemical%soil%process%exchange)
   up=[exchange%nh4_crop_uptake_kg_m2,exchange%no3_crop_uptake_kg_m2]
  end associate
  ! No crop exists on this route: the physical owner enforces retired + zero roots.
  if(any(up/=0d0))then;result%status=JOINT_COMMIT_REJECTED;return;end if
  call observe_crop_ext_saved_residue(ot,st,t0,t1,up,[0d0,0d0,0d0,0d0],[0d0,0d0,0d0,0d0],report,row,code)
  if(code/=0)then;result%status=JOINT_COMMIT_REJECTED;return;end if
  n=size(rows);allocate(dt(n+merge(1,0,report)),rt(n+merge(1,0,report)))
  dt(:n)=dates;rt(:n)=rows
  if(report)then;dt(n+1)=date;rt(n+1)=row;end if
  call write_crop_n_saved_generation(path,column,template,water_id,wt,ct,ot,st,dt,rt,code)
  if(code/=0)then;result%status=JOINT_COMMIT_REJECTED;status=OUTPUT_DAY_SAVE_FAILED;return;end if
  water=wt;chemical=ct;output=ot;saved=st
  call move_alloc(dt,dates);call move_alloc(rt,rows);status=OUTPUT_DAY_OK
  if(present(csv_path))then
   call write_crop_ext_csv_file(csv_path,dates,rows,output,code)
   if(code/=0)status=OUTPUT_DAY_VIEW_FAILED
  end if
 end subroutine
end module

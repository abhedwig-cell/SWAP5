! Biological boundary at an accepted clock, not a new hydraulic/diagnostic day.
module mod_crop_soil_n_output_harvest
 use iso_fortran_env,only:int64
 use mod_crop_soil_n_day,only:crop_soil_state_t,crop_soil_harvest_receipt_t,CROP_SOIL_INVALID, &
  crop_soil_harvest_observation_t,harvest_crop_soil_boundary,consume_crop_soil_harvest_pending, &
  acknowledge_crop_soil_harvest
 use mod_kernel_transactions,only:kernel_committed_state_t
 use mod_fmr_runtime_core,only:fmr_logical_column_t,fmr_template_t
 use mod_soil_n_crop_extended_output,only:crop_ext_state_t,crop_ext_row_t
 use mod_crop_n_output_generation,only:write_crop_n_output_generation
 use mod_crop_ext_csv_file,only:write_crop_ext_csv_file
 use mod_crop_soil_n_output_day,only:OUTPUT_DAY_OK,OUTPUT_DAY_INVALID,OUTPUT_DAY_SAVE_FAILED,OUTPUT_DAY_VIEW_FAILED
 implicit none
 private
 integer,parameter,public::OUTPUT_HARVEST_STAGE=1,OUTPUT_HARVEST_INCORPORATE=2,OUTPUT_HARVEST_RETIRE=3
 public::run_crop_soil_n_output_harvest
contains
 subroutine run_crop_soil_n_output_harvest(path,phase,column,template,water_id,water,chemical, &
   output,dates,rows,result,status,observation,csv_path)
  character(*),intent(in)::path
  integer,intent(in)::phase
  type(fmr_logical_column_t),intent(in)::column
  type(fmr_template_t),intent(in)::template
  integer(int64),intent(in)::water_id
  type(kernel_committed_state_t),intent(in)::water
  type(crop_soil_state_t),intent(inout)::chemical
  type(crop_ext_state_t),intent(in)::output
  character(10),intent(in)::dates(:)
  type(crop_ext_row_t),intent(in)::rows(:)
  type(crop_soil_harvest_receipt_t),intent(out)::result
  integer,intent(out)::status
  type(crop_soil_harvest_observation_t),optional,intent(in)::observation
  character(*),optional,intent(in)::csv_path
  type(crop_soil_state_t)::trial
  integer::code
  result=crop_soil_harvest_receipt_t();status=OUTPUT_DAY_INVALID
  trial=chemical
  select case(phase)
  case(OUTPUT_HARVEST_STAGE)
   call harvest_crop_soil_boundary(trial,result)
  case(OUTPUT_HARVEST_INCORPORATE)
   call consume_crop_soil_harvest_pending(trial,result)
  case(OUTPUT_HARVEST_RETIRE)
   if(.not.present(observation))return
   call acknowledge_crop_soil_harvest(trial,observation,result)
  case default
   return
  end select
  if(result%status/=0)return
  ! Diagnostic clock, interval sums, extrema and report history stay unchanged.
  ! The existing physical codec validates the exact crop phase and inventories.
  call write_crop_n_output_generation(path,column,template,water_id,water,trial,output,dates,rows,code)
  if(code/=0)then
   result%status=CROP_SOIL_INVALID;status=OUTPUT_DAY_SAVE_FAILED;return
  end if
  chemical=trial;status=OUTPUT_DAY_OK
  if(present(csv_path))then
   call write_crop_ext_csv_file(csv_path,dates,rows,output,code)
   if(code/=0)status=OUTPUT_DAY_VIEW_FAILED
  end if
 end subroutine
end module

program g5b_transaction_bridge
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_external_surface_water_transaction
  implicit none
  character(len=80) :: case_id, arg
  real(real64) :: head_cm, requested, realized
  type(external_surface_water_origin_t) :: origin
  type(external_surface_water_request_t) :: request
  type(external_surface_water_realization_t) :: realization
  type(external_surface_water_transaction_result_t) :: result, recomposed

  call get_command_argument(1,case_id)
  call get_command_argument(2,arg); read(arg,*) head_cm
  call get_command_argument(3,arg); read(arg,*) requested
  call get_command_argument(4,arg); read(arg,*) realized

  origin%swap_revision=11_int64
  origin%ribasim_origin_id=901_int64
  origin%ribasim_revision=17_int64
  request%origin=origin
  request%accepted_surface_water_head_cm=head_cm
  request%requested_signed_soil_to_surface_volume_m3=requested
  realization%origin=origin
  realization%realized_signed_soil_to_surface_volume_m3=realized

  call evaluate_external_surface_water_transaction(origin,request,realization,result)

  select case(trim(case_id))
  case('E1_POSITIVE_DRAINAGE','E2_NEGATIVE_INFILTRATION_SUFFICIENT')
    if(result%disposition/=EXT_SW_TX_COMMIT_READY) error stop 'full realization not commit-ready'
    if(.not.result%exactly_once_transfer_ready) error stop 'full realization not bookable'
  case('E3_NEGATIVE_INFILTRATION_LIMITED')
    if(result%disposition/=EXT_SW_TX_RECOMPOSITION_REQUIRED) error stop 'limited realization did not recompose'
    if(result%swap_may_commit .or. result%ribasim_may_commit) error stop 'limited first candidate commit leak'
    request%requested_signed_soil_to_surface_volume_m3=realized
    call evaluate_external_surface_water_transaction(origin,request,realization,recomposed)
    if(recomposed%disposition/=EXT_SW_TX_COMMIT_READY) error stop 'recomposed candidate not ready'
    if(.not.recomposed%exactly_once_transfer_ready) error stop 'recomposed transfer not bookable'
  case default
    error stop 'unknown G5B case'
  end select

  write(*,'(A,A)') 'SW_RIB_ADM01_G5B_TRANSACTION_CASE_PASS=',trim(case_id)
end program g5b_transaction_bridge

program test_rutter_interception_process
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_rutter_interception_process
  implicit none
  type(rutter_state_t) :: state
  type(rutter_interval_input_t) :: input
  type(rutter_interval_result_t) :: result
  type(rutter_diagnostics_t) :: d
  real(real64), parameter :: tol=1.0e-12_real64

  input%gross_rain_cm_per_day=0.56_real64
  input%vegetation_cover_fraction=0.5_real64
  input%canopy_storage_capacity_cm=0.12_real64
  input%interception_evaporation_capacity_cm_per_day=0.01_real64
  input%potential_transpiration_dry_cm_per_day=0.011621209174202582_real64
  input%potential_transpiration_wet_cm_per_day=0.0047014973566050335_real64
  input%interval_days=0.04_real64
  state%canopy_storage_cm=0.02_real64
  call evaluate_rutter_interval(state,input,result,d)
  call require(d%status==RUTTER_OK .and. d%result_produced,1)
  call require(abs(result%reservoir_inflow_cm_per_day-0.28_real64)<tol,2)
  call require(abs(result%reservoir_outflow_cm_per_day-0.01_real64)<tol,3)
  call require(abs(result%net_rain_cm_per_day-0.28_real64)<tol,4)
  call require(abs(result%wet_canopy_fraction-1.0_real64)<tol,5)
  call require(abs(result%candidate_state%canopy_storage_cm-0.0308_real64)<tol,6)
  call require(abs(state%canopy_storage_cm-0.02_real64)<tol,7)

  input%gross_rain_cm_per_day=0.0_real64
  input%vegetation_cover_fraction=0.5_real64
  input%interception_evaporation_capacity_cm_per_day=0.1_real64
  state%canopy_storage_cm=0.0_real64
  call evaluate_rutter_interval(state,input,result,d)
  call require(d%status==RUTTER_OK .and. abs(result%wet_canopy_fraction)<tol,8)

  input%gross_rain_cm_per_day=0.02_real64
  call evaluate_rutter_interval(state,input,result,d)
  call require(d%status==RUTTER_OK,9)
  call require(abs(result%reservoir_inflow_cm_per_day-0.01_real64)<tol,10)
  call require(abs(result%reservoir_outflow_cm_per_day-0.01_real64)<tol,11)
  call require(abs(result%wet_canopy_fraction-0.1_real64)<tol,12)

  input%gross_rain_cm_per_day=-1.0_real64
  call evaluate_rutter_interval(state,input,result,d)
  call require(d%status==RUTTER_INVALID_INPUT .and. .not.d%result_produced,13)

  print '(A)','F-APP05_RUTTER_UNIT_PASS'
contains
  subroutine require(ok,n)
    logical,intent(in)::ok
    integer,intent(in)::n
    if(.not.ok) then
      write(*,'(A,I0)') 'FAIL=',n
      error stop 1
    end if
  end subroutine
end program

program test_fci48_fmr41_optional_state_layout_contract
  use, intrinsic :: iso_fortran_env, only: int64
  use mod_fmr_runtime_core, only: fmr_template_t, FMR_BACKEND_SERIALIZED_REFERENCE, &
       FMR_NUMERICAL_CONTINUATION_NONE, FMR_OPTIONAL_STATE_LAYOUT_BASE, &
       FMR_OPTIONAL_STATE_LAYOUT_SNOW, FMR_OPTIONAL_STATE_LAYOUT_RESTRICTED_SOIL_TEMPERATURE, &
       fmr_optional_state_layout_known
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t
  use mod_fmr_restart_state_contract, only: fmr_restart_state_matches_template
  implicit none

  integer(int64), parameter :: UNKNOWN_LAYOUT = 390502_int64
  type(fmr_template_t) :: template
  type(fmr_b110_physical_state_t) :: state

  template%template_id = 480001_int64
  template%compatible_backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
  template%numerical_continuation_layout_id = FMR_NUMERICAL_CONTINUATION_NONE
  state%active_nodes = 2

  call expect(fmr_optional_state_layout_known(FMR_OPTIONAL_STATE_LAYOUT_BASE), 'base identity known')
  call expect(fmr_optional_state_layout_known(FMR_OPTIONAL_STATE_LAYOUT_SNOW), 'snow identity known')
  call expect(fmr_optional_state_layout_known(FMR_OPTIONAL_STATE_LAYOUT_RESTRICTED_SOIL_TEMPERATURE), &
       'thermal identity known')
  call expect(.not. fmr_optional_state_layout_known(UNKNOWN_LAYOUT), 'unknown identity rejected')
  call expect(.not. fmr_optional_state_layout_known(1_int64), 'arbitrary positive identity rejected')

  template%optional_state_layout_id = FMR_OPTIONAL_STATE_LAYOUT_BASE
  call expect(fmr_restart_state_matches_template(state, template), 'base layout accepts base state')
  template%optional_state_layout_id = FMR_OPTIONAL_STATE_LAYOUT_SNOW
  call expect(fmr_restart_state_matches_template(state, template), 'snow layout accepts inactive column')
  template%optional_state_layout_id = FMR_OPTIONAL_STATE_LAYOUT_RESTRICTED_SOIL_TEMPERATURE
  call expect(fmr_restart_state_matches_template(state, template), 'thermal layout accepts inactive column')

  template%optional_state_layout_id = UNKNOWN_LAYOUT
  call expect(.not. fmr_restart_state_matches_template(state, template), 'unknown layout fails closed')
  template%optional_state_layout_id = 1_int64
  call expect(.not. fmr_restart_state_matches_template(state, template), 'arbitrary positive layout fails closed')

  allocate(state%snow)
  template%optional_state_layout_id = FMR_OPTIONAL_STATE_LAYOUT_SNOW
  call expect(fmr_restart_state_matches_template(state, template), 'snow state matches snow layout')
  template%optional_state_layout_id = FMR_OPTIONAL_STATE_LAYOUT_BASE
  call expect(.not. fmr_restart_state_matches_template(state, template), 'snow state rejected by base layout')
  template%optional_state_layout_id = FMR_OPTIONAL_STATE_LAYOUT_RESTRICTED_SOIL_TEMPERATURE
  call expect(.not. fmr_restart_state_matches_template(state, template), 'snow state rejected by thermal layout')
  template%optional_state_layout_id = UNKNOWN_LAYOUT
  call expect(.not. fmr_restart_state_matches_template(state, template), 'snow state rejected by unknown layout')
  deallocate(state%snow)

  print '(a)', 'FCI48_KNOWN_LAYOUT_IDENTITY_MATRIX=PASS'
  print '(a)', 'FCI48_INACTIVE_TYPED_CAPABILITY_SEMANTICS=PASS'
  print '(a)', 'FCI48_SNOW_LAYOUT_RESTART_IDENTITY=PASS'
  print '(a)', 'FCI48_UNKNOWN_POSITIVE_LAYOUT_FAIL_CLOSED=PASS'
  print '(a)', 'FCI48_OPTIONAL_STATE_LAYOUT_CONTRACT_TEST PASS'

contains

  subroutine expect(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(a,1x,a)') 'FCI48_ASSERT_FAIL', trim(label)
      error stop 48
    end if
  end subroutine expect

end program test_fci48_fmr41_optional_state_layout_contract

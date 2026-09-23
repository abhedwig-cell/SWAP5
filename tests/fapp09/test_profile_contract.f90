program test_fapp09_profile_contract
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_fmr_drainage_response_binding, only: fmr_drainage_response_level_control_t
  use mod_ribasim_surface_water_profile
  implicit none

  type(ribasim_surface_water_profile_t) :: profile
  type(accepted_ribasim_surface_water_head_view_t) :: view
  type(fmr_drainage_response_level_control_t) :: controls(2)
  integer :: status

  allocate(view%level_head_cm(2))
  view%accepted = .true.
  view%accepted_revision = 7_int64
  view%accepted_time = 1234.5_real64
  view%level_head_cm = [-45.0_real64, -20.0_real64]

  call bind_accepted_ribasim_heads(profile, view, controls, status)
  call require(status == RSW_PROFILE_OK, 'valid profile')
  call require(.not. controls(1)%drain_head_supplied, 'generic drain head disabled')
  call require(controls(1)%resolved_surface_water_head_supplied, 'external head 1 supplied')
  call require(controls(2)%resolved_surface_water_head_supplied, 'external head 2 supplied')
  call require(controls(1)%resolved_surface_water_head_cm == -45.0_real64, 'head 1 identity')
  call require(controls(2)%resolved_surface_water_head_cm == -20.0_real64, 'head 2 identity')
  write(*,'(A)') 'FAPP09_VALID_EXTERNAL_OWNER_BINDING=PASS'

  profile%internal_swap_fixed_weir_state_active = .true.
  call bind_accepted_ribasim_heads(profile, view, controls, status)
  call require(status == RSW_PROFILE_DUPLICATE_OWNER, 'duplicate owner must fail')
  call require(all(.not. controls%resolved_surface_water_head_supplied), 'duplicate owner no controls')
  write(*,'(A)') 'FAPP09_OWNER_XOR_FAIL_CLOSED=PASS'
  profile%internal_swap_fixed_weir_state_active = .false.

  profile%storage_geometry_epsilon_m = 1.0e-5_real64
  status = validate_ribasim_surface_water_profile(profile)
  call require(status == RSW_PROFILE_INVALID_GEOMETRY_EPSILON, 'geometry epsilon frozen')
  write(*,'(A)') 'FAPP09_GEOMETRY_EPSILON_FAIL_CLOSED=PASS'
  profile%storage_geometry_epsilon_m = RSW_PROFILE_STORAGE_GEOMETRY_EPSILON_M

  profile%exact_nonlinear_swqhr1_parity_required = .true.
  status = validate_ribasim_surface_water_profile(profile)
  call require(status == RSW_PROFILE_UNQUALIFIED_NONLINEAR_PARITY, 'nonlinear parity excluded')
  write(*,'(A)') 'FAPP09_NONLINEAR_PARITY_FAIL_CLOSED=PASS'
  profile%exact_nonlinear_swqhr1_parity_required = .false.

  profile%accept_with_clip_allowed = .true.
  status = validate_ribasim_surface_water_profile(profile)
  call require(status == RSW_PROFILE_ACCEPT_WITH_CLIP_FORBIDDEN, 'accept with clip forbidden')
  write(*,'(A)') 'FAPP09_ACCEPT_WITH_CLIP_FAIL_CLOSED=PASS'
  profile%accept_with_clip_allowed = .false.

  view%accepted = .false.
  call bind_accepted_ribasim_heads(profile, view, controls, status)
  call require(status == RSW_PROFILE_UNACCEPTED_HEAD_VIEW, 'trial head rejected')
  call require(all(.not. controls%resolved_surface_water_head_supplied), 'trial head no controls')
  write(*,'(A)') 'FAPP09_TRIAL_HEAD_FAIL_CLOSED=PASS'
  view%accepted = .true.

  deallocate(view%level_head_cm)
  allocate(view%level_head_cm(1))
  view%level_head_cm = [-45.0_real64]
  call bind_accepted_ribasim_heads(profile, view, controls, status)
  call require(status == RSW_PROFILE_HEAD_SHAPE_MISMATCH, 'head shape mismatch')
  write(*,'(A)') 'FAPP09_HEAD_SHAPE_FAIL_CLOSED=PASS'

  deallocate(view%level_head_cm)
  allocate(view%level_head_cm(2))
  view%level_head_cm = [-45.0_real64, ieee_value(0.0_real64, ieee_quiet_nan)]
  call bind_accepted_ribasim_heads(profile, view, controls, status)
  call require(status == RSW_PROFILE_NONFINITE_HEAD, 'nonfinite head')
  write(*,'(A)') 'FAPP09_NONFINITE_HEAD_FAIL_CLOSED=PASS'

  write(*,'(A)') 'FAPP09_PROFILE_CONTRACT=PASS'

contains
  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'FAPP09_PROFILE_TEST_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require
end program test_fapp09_profile_contract

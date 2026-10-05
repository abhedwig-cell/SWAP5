module mod_fmr_tillage_profile_restart
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_tillage_constitutive_process, only: tillage_vg_parameters_t
  use mod_fmr_tillage_event_owner, only: tillage_owner_state_t, tillage_owner_restart_t, &
       export_tillage_owner, restore_tillage_owner, TILLAGE_OWNER_OK
  implicit none
  private
  integer, parameter, public :: TILLAGE_PROFILE_RESTART_SCHEMA = 1
  integer, parameter, public :: TILLAGE_PROFILE_RESTART_OK = 0
  integer, parameter, public :: TILLAGE_PROFILE_RESTART_INVALID = 1
  type, public :: tillage_profile_state_t
    type(tillage_owner_state_t) :: owner
    real(real64), allocatable :: event_density(:)
    real(real64), allocatable :: density(:)
    real(real64), allocatable :: water_content(:)
    real(real64), allocatable :: pressure_head_cm(:)
    type(tillage_vg_parameters_t), allocatable :: vg(:)
    real(real64) :: ponding_depth_cm = 0.0_real64
  end type
  type, public :: tillage_profile_restart_record_t
    integer :: schema = 0
    integer :: event_count = 0
    integer :: profile_nodes = 0
    type(tillage_owner_restart_t) :: owner
    real(real64), allocatable :: event_density(:)
    real(real64), allocatable :: density(:)
    real(real64), allocatable :: water_content(:)
    real(real64), allocatable :: pressure_head_cm(:)
    type(tillage_vg_parameters_t), allocatable :: vg(:)
    real(real64) :: ponding_depth_cm = 0.0_real64
  end type
  public :: export_tillage_profile, restore_tillage_profile
contains
  pure subroutine export_tillage_profile(state,event_count,record,status)
    type(tillage_profile_state_t), intent(in) :: state
    integer, intent(in) :: event_count
    type(tillage_profile_restart_record_t), intent(out) :: record
    integer, intent(out) :: status
    integer :: owner_status
    record = tillage_profile_restart_record_t()
    status = TILLAGE_PROFILE_RESTART_INVALID
    if (.not. valid_profile(state)) return
    call export_tillage_owner(state%owner,event_count,record%owner,owner_status)
    if (owner_status /= TILLAGE_OWNER_OK) return
    record%schema = TILLAGE_PROFILE_RESTART_SCHEMA
    record%event_count = event_count
    record%profile_nodes = size(state%density)
    record%event_density = state%event_density
    record%density = state%density
    record%water_content = state%water_content
    record%pressure_head_cm = state%pressure_head_cm
    record%vg = state%vg
    record%ponding_depth_cm = state%ponding_depth_cm
    status = TILLAGE_PROFILE_RESTART_OK
  end subroutine

  pure subroutine restore_tillage_profile(record,expected_events,expected_nodes,state,status)
    type(tillage_profile_restart_record_t), intent(in) :: record
    integer, intent(in) :: expected_events,expected_nodes
    type(tillage_profile_state_t), intent(out) :: state
    integer, intent(out) :: status
    integer :: owner_status
    state = tillage_profile_state_t()
    status = TILLAGE_PROFILE_RESTART_INVALID
    if (record%schema /= TILLAGE_PROFILE_RESTART_SCHEMA .or. &
        record%event_count /= expected_events .or. record%profile_nodes /= expected_nodes) return
    call restore_tillage_owner(record%owner,expected_events,state%owner,owner_status)
    if (owner_status /= TILLAGE_OWNER_OK) return
    if (.not. allocated(record%event_density) .or. .not. allocated(record%density) .or. &
        .not. allocated(record%water_content) .or. .not. allocated(record%pressure_head_cm) .or. &
        .not. allocated(record%vg)) then
      state = tillage_profile_state_t()
      return
    end if
    state%event_density = record%event_density
    state%density = record%density
    state%water_content = record%water_content
    state%pressure_head_cm = record%pressure_head_cm
    state%vg = record%vg
    state%ponding_depth_cm = record%ponding_depth_cm
    if (.not. valid_profile(state) .or. size(state%density) /= expected_nodes) then
      state = tillage_profile_state_t()
      return
    end if
    status = TILLAGE_PROFILE_RESTART_OK
  end subroutine

  pure logical function valid_profile(state)
    type(tillage_profile_state_t), intent(in) :: state
    integer :: n,i
    real(real64) :: reconstructed
    valid_profile = .false.
    if (.not. allocated(state%event_density) .or. .not. allocated(state%density) .or. &
        .not. allocated(state%water_content) .or. .not. allocated(state%pressure_head_cm) .or. &
        .not. allocated(state%vg)) return
    n = size(state%density)
    if (n < 1 .or. size(state%event_density) /= n .or. size(state%water_content) /= n .or. &
        size(state%pressure_head_cm) /= n .or. size(state%vg) /= n) return
    if (.not. ieee_is_finite(state%ponding_depth_cm) .or. state%ponding_depth_cm < 0.0_real64) return
    if (any(.not. ieee_is_finite(state%event_density)) .or. any(.not. ieee_is_finite(state%density)) .or. &
        any(.not. ieee_is_finite(state%water_content)) .or. &
        any(.not. ieee_is_finite(state%pressure_head_cm))) return
    if (any(state%event_density <= 0.0_real64) .or. any(state%event_density >= 2650.0_real64) .or. &
        any(state%density <= 0.0_real64) .or. &
        any(state%density >= 2650.0_real64)) return
    do i=1,n
      if (.not. all(ieee_is_finite([state%vg(i)%theta_residual,state%vg(i)%theta_saturated, &
           state%vg(i)%alpha,state%vg(i)%n,state%vg(i)%m]))) return
      if (state%vg(i)%theta_residual < 0.0_real64 .or. &
          state%vg(i)%theta_saturated <= state%vg(i)%theta_residual .or. &
          state%vg(i)%theta_saturated > 1.0_real64 .or. state%vg(i)%alpha <= 0.0_real64 .or. &
          state%vg(i)%n <= 1.0_real64 .or. state%vg(i)%m <= 0.0_real64) return
      if (abs(state%vg(i)%m-(1.0_real64-1.0_real64/state%vg(i)%n)) > 1.e-12_real64) return
      if (state%pressure_head_cm(i) >= 0.0_real64) then
        reconstructed = state%vg(i)%theta_saturated
      else
        reconstructed = state%vg(i)%theta_residual+ &
             (state%vg(i)%theta_saturated-state%vg(i)%theta_residual)* &
             (1.0_real64+(state%vg(i)%alpha*abs(state%pressure_head_cm(i)))** &
             state%vg(i)%n)**(-state%vg(i)%m)
      end if
      if (abs(reconstructed-state%water_content(i)) > 1.e-10_real64) return
    end do
    valid_profile = .true.
  end function
end module

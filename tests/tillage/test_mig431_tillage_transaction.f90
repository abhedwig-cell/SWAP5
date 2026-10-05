program test_mig431_tillage_transaction
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_tillage_constitutive_process, only: tillage_vg_parameters_t
  use mod_fmr_tillage_event_owner, only: tillage_owner_state_t, initialize_tillage_owner, TILLAGE_OWNER_OK
  use mod_fmr_tillage_event_transaction
  use mod_fmr_tillage_profile_restart
  use mod_fmr_tillage_depth_binding, only: bind_tillage_event_depth, TILLAGE_DEPTH_OK
  implicit none
  type(tillage_vg_parameters_t) :: vg(2)
  type(tillage_event_input_t) :: event(1)
  type(tillage_owner_state_t) :: owner
  type(tillage_event_candidate_t) :: candidate
  type(tillage_event_candidate_t) :: after_event
  type(tillage_compatibility_t) :: compatibility
  type(tillage_profile_state_t) :: profile, restored
  type(tillage_profile_restart_record_t) :: record
  integer :: status
  real(real64), parameter :: days(1) = [2.0_real64]
  real(real64), parameter :: density(2) = [1400.0_real64,1500.0_real64]
  real(real64), parameter :: theta(2) = [0.2_real64,0.3_real64]
  real(real64), parameter :: head(2) = [-100.0_real64,-30.0_real64]
  real(real64), parameter :: thickness(2) = [10.0_real64,20.0_real64]
  real(real64), parameter :: texture(2) = [0.3_real64,0.3_real64]
  real(real64), parameter :: slope(2) = [0.0_real64,0.0_real64]

  vg%theta_residual = 0.05_real64
  vg%theta_saturated = 0.4_real64
  vg%alpha = 0.02_real64
  vg%n = 2.0_real64
  vg%m = 0.5_real64
  vg%saturated_conductivity = 10.0_real64
  allocate(event(1)%affected(2),event(1)%target_density(2))
  call bind_tillage_event_depth(thickness,[1,2],10.0_real64,event(1)%affected,status)
  if (status /= TILLAGE_DEPTH_OK) error stop 25
  event(1)%target_density = [1200.0_real64,1500.0_real64]
  event(1)%intensity = 0.5_real64
  event(1)%n_model = 1
  event(1)%redistribution_mode = 1
  call initialize_tillage_owner(days,1.0_real64,owner,status)
  if (status /= TILLAGE_OWNER_OK) error stop 1
  call step(1.0_real64,3.0_real64,status)
  if (status /= TILLAGE_TRANSACTION_SPLIT .or. owner%next_event /= 1) error stop 2
  call step(1.0_real64,2.0_real64,status)
  if (status /= TILLAGE_TRANSACTION_OK .or. candidate%applied_event_index /= 0) error stop 3
  owner = candidate%owner
  call step(2.0_real64,3.0_real64,status)
  if (status /= TILLAGE_TRANSACTION_OK .or. candidate%applied_event_index /= 1) error stop 4
  if (abs(candidate%density(1)-1300.0_real64) > 1.e-12_real64 .or. &
      candidate%density(2) /= density(2)) error stop 5
  if (abs(candidate%hydraulic%mass_residual_cm) > 1.e-12_real64) error stop 6
  if (candidate%owner%next_event /= 2 .or. owner%next_event /= 1) error stop 7
  after_event = candidate
  profile%owner = after_event%owner
  profile%event_density = after_event%density
  profile%density = after_event%density
  profile%water_content = after_event%hydraulic%water_content
  profile%pressure_head_cm = after_event%hydraulic%pressure_head_cm
  profile%vg = after_event%hydraulic_parameters
  profile%ponding_depth_cm = after_event%hydraulic%ponding_depth_cm
  call export_tillage_profile(profile,1,record,status)
  if (status /= TILLAGE_PROFILE_RESTART_OK) error stop 20
  call restore_tillage_profile(record,1,2,restored,status)
  if (status /= TILLAGE_PROFILE_RESTART_OK) error stop 21
  call restore_tillage_profile(record,1,3,restored,status)
  if (status /= TILLAGE_PROFILE_RESTART_INVALID) error stop 22
  call restore_tillage_profile(record,1,2,restored,status)
  if (status /= TILLAGE_PROFILE_RESTART_OK) error stop 23
  call evaluate_tillage_consolidation_transaction(days,3.0_real64,4.0_real64,0.3_real64, &
       restored%owner,restored%event_density,[1400.0_real64,1500.0_real64], &
       [0.1_real64,0.1_real64],restored%density,restored%vg, &
       restored%water_content,restored%pressure_head_cm,thickness, &
       restored%ponding_depth_cm,texture,texture,slope,1,1,compatibility,candidate,status)
  if (status /= TILLAGE_TRANSACTION_OK) error stop 16
  if (abs(candidate%density(1)-(1400.0_real64-100.0_real64*exp(-0.4_real64))) > 1.e-10_real64) error stop 17
  if (abs(candidate%hydraulic%mass_residual_cm) > 1.e-12_real64) error stop 18
  if (abs(candidate%owner%accepted_net_rain_since_event_cm-0.4_real64) > 1.e-14_real64) error stop 19
  record%water_content(1) = -1.0_real64
  call restore_tillage_profile(record,1,2,restored,status)
  if (status /= TILLAGE_PROFILE_RESTART_INVALID) error stop 24
  event(1)%n_model = 2
  call step(2.0_real64,3.0_real64,status)
  if (status /= TILLAGE_TRANSACTION_OK) error stop 8
  event(1)%n_model = 1
  event(1)%redistribution_mode = 0
  call step(2.0_real64,3.0_real64,status)
  if (status /= TILLAGE_TRANSACTION_INVALID .or. allocated(candidate%density)) error stop 9
  event(1)%redistribution_mode = 1
  compatibility%macropore_enabled = .true.
  call step(2.0_real64,3.0_real64,status)
  if (status /= TILLAGE_TRANSACTION_INVALID .or. allocated(candidate%density)) error stop 10
  compatibility = tillage_compatibility_t()
  compatibility%hysteresis_enabled = .true.
  call step(2.0_real64,3.0_real64,status)
  if (status /= TILLAGE_TRANSACTION_INVALID) error stop 11
  compatibility = tillage_compatibility_t()
  compatibility%solute_enabled = .true.
  call step(2.0_real64,3.0_real64,status)
  if (status /= TILLAGE_TRANSACTION_INVALID) error stop 12
  compatibility = tillage_compatibility_t()
  compatibility%physical_oxygen_enabled = .true.
  call step(2.0_real64,3.0_real64,status)
  if (status /= TILLAGE_TRANSACTION_INVALID) error stop 13
  compatibility = tillage_compatibility_t()
  compatibility%extended_saturated_conductivity = .true.
  call step(2.0_real64,3.0_real64,status)
  if (status /= TILLAGE_TRANSACTION_INVALID) error stop 14
  compatibility = tillage_compatibility_t()
  compatibility%vertical_discretization_enabled = .true.
  call step(2.0_real64,3.0_real64,status)
  if (status /= TILLAGE_TRANSACTION_INVALID) error stop 15
  print '(a)', 'F_MIG431_TILLAGE_EVENT_TRANSACTION=PASS'
contains
  subroutine step(t0,t1,result_status)
    real(real64), intent(in) :: t0,t1
    integer, intent(out) :: result_status
    call evaluate_tillage_event_transaction(days,t0,t1,0.1_real64,owner,event,density,vg,theta,head, &
         thickness,0.0_real64,texture,texture,slope,compatibility,candidate,result_status)
  end subroutine
end program

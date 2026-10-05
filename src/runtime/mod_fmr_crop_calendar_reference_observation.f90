module mod_fmr_crop_calendar_reference_observation
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, &
       fmr_b110_physical_parameters_t
  use mod_soil_temperature_contract, only: copy_soil_temperature_profile, SOIL_TEMP_OK
  use mod_crop_calendar_management_process, only: crop_calendar_management_observation_t
  use mod_fmr_crop_calendar_observation_binding, only: bind_crop_calendar_observation, CROP_OBSERVATION_OK
  implicit none
  private
  integer, parameter, public :: CROP_REFERENCE_OBSERVATION_OK = 0
  integer, parameter, public :: CROP_REFERENCE_OBSERVATION_INVALID = 1
  public :: bind_crop_calendar_reference_observation
contains
  subroutine bind_crop_calendar_reference_observation(parameters,state,preparation_depth_cm, &
       sowing_depth_cm,germination_depth_cm,temperature_depth_cm,daily_air_temperature_c, &
       observation,status)
    type(fmr_b110_physical_parameters_t), intent(in) :: parameters
    type(fmr_b110_physical_state_t), intent(in) :: state
    real(real64), intent(in) :: preparation_depth_cm,sowing_depth_cm,germination_depth_cm
    real(real64), intent(in) :: temperature_depth_cm,daily_air_temperature_c
    type(crop_calendar_management_observation_t), intent(out) :: observation
    integer, intent(out) :: status
    real(real64), allocatable :: soil_temperature(:)
    integer :: temperature_status,observer_status,n

    observation = crop_calendar_management_observation_t()
    status = CROP_REFERENCE_OBSERVATION_INVALID
    n = parameters%active_nodes
    if (n < 1 .or. state%active_nodes /= n .or. .not. parameters%soil_temperature_active) return
    if (.not. allocated(parameters%dz) .or. .not. allocated(state%pressure_head) .or. &
        .not. allocated(state%soil_temperature)) return
    if (size(parameters%dz) /= n .or. size(state%pressure_head) /= n) return
    call copy_soil_temperature_profile(state%soil_temperature,soil_temperature,temperature_status)
    if (temperature_status /= SOIL_TEMP_OK) return
    if (.not. allocated(soil_temperature)) return
    if (size(soil_temperature) /= n) return
    call bind_crop_calendar_observation(parameters%dz,state%pressure_head,soil_temperature, &
         preparation_depth_cm,sowing_depth_cm,germination_depth_cm,temperature_depth_cm, &
         daily_air_temperature_c,observation,observer_status)
    if (observer_status /= CROP_OBSERVATION_OK) return
    status = CROP_REFERENCE_OBSERVATION_OK
  end subroutine
end module

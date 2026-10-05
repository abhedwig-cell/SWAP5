module mod_fmr_crop_calendar_reference_observation
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, &
       fmr_b110_physical_parameters_t
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_transaction_reference, only: transaction_state_t
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t
  use mod_soil_temperature_contract, only: copy_soil_temperature_profile, SOIL_TEMP_OK
  use mod_crop_calendar_management_process, only: crop_calendar_management_observation_t
  use mod_fmr_crop_calendar_observation_binding, only: bind_crop_calendar_observation, CROP_OBSERVATION_OK
  implicit none
  private
  integer, parameter, public :: CROP_REFERENCE_OBSERVATION_OK = 0
  integer, parameter, public :: CROP_REFERENCE_OBSERVATION_INVALID = 1
  public :: bind_crop_calendar_reference_observation, bind_accepted_crop_calendar_reference_observation
contains
  subroutine bind_accepted_crop_calendar_reference_observation(parameters,committed,result, &
       preparation_depth_cm,sowing_depth_cm,germination_depth_cm,temperature_depth_cm, &
       daily_air_temperature_c,observation,status)
    type(fmr_b110_physical_parameters_t), intent(in) :: parameters
    type(kernel_committed_state_t), intent(in) :: committed
    type(fmr_serialized_column_result_t), intent(in) :: result
    real(real64), intent(in) :: preparation_depth_cm,sowing_depth_cm,germination_depth_cm
    real(real64), intent(in) :: temperature_depth_cm,daily_air_temperature_c
    type(crop_calendar_management_observation_t), intent(out) :: observation
    integer, intent(out) :: status
    class(transaction_state_t), allocatable :: physical
    logical :: available,time_available
    real(real64) :: committed_time

    observation = crop_calendar_management_observation_t()
    status = CROP_REFERENCE_OBSERVATION_INVALID
    if (.not. result%committed .or. .not. result%completed .or. .not. result%mass%complete .or. &
        .not. result%final_committed_time_bound .or. .not. committed%time_is_bound()) return
    call committed%current_time(committed_time,time_available)
    if (.not. time_available) return
    if (result%column_id /= committed%current_lineage_id() .or. &
        result%final_revision /= committed%current_revision() .or. &
        result%final_committed_time /= committed_time) return
    call committed%snapshot(physical,available)
    if (.not. available .or. .not. allocated(physical)) return
    select type(physical)
    class is(fmr_b110_physical_state_t)
      call bind_crop_calendar_reference_observation(parameters,physical,preparation_depth_cm, &
           sowing_depth_cm,germination_depth_cm,temperature_depth_cm, &
           daily_air_temperature_c,observation,status)
    class default
      return
    end select
  end subroutine

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

module mod_ppa_wu04c_vonhhbraden_forcing_adapter
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_b110_dynamic_top_boundary_provider, only: b110_dynamic_top_boundary_request_t
  use mod_vonhhbraden_interception, only: vonhhbraden_source_window_t, &
       apportion_vonhhbraden_interception, VONHHBRADEN_AVAILABLE
  implicit none
  private

  integer, parameter, public :: PPA_WU04C_BIND_OK = 0
  integer, parameter, public :: PPA_WU04C_BIND_INVALID_INPUT = 1
  integer, parameter, public :: PPA_WU04C_BIND_PARTITION_REJECTED = 2
  public :: bind_ppa_wu04c_vonhhbraden_dynamic_top

contains

  subroutine bind_ppa_wu04c_vonhhbraden_dynamic_top(base_request, source, source_aggregate_cm_per_day, &
       interval_rain_cm_per_day, interval_irrigation_cm_per_day, bound_request, interception_cm_per_day, status)
    type(b110_dynamic_top_boundary_request_t), intent(in) :: base_request
    type(vonhhbraden_source_window_t), intent(in) :: source
    real(real64), intent(in) :: source_aggregate_cm_per_day, interval_rain_cm_per_day, interval_irrigation_cm_per_day
    type(b110_dynamic_top_boundary_request_t), intent(out) :: bound_request
    real(real64), intent(out) :: interception_cm_per_day
    integer, intent(out) :: status
    real(real64) :: net_rain, net_irrigation
    integer :: partition_status

    bound_request = b110_dynamic_top_boundary_request_t()
    interception_cm_per_day = 0.0_real64
    status = PPA_WU04C_BIND_INVALID_INPUT
    if (.not. ieee_is_finite(source_aggregate_cm_per_day) .or. source_aggregate_cm_per_day < 0.0_real64) return
    call apportion_vonhhbraden_interception(source, source_aggregate_cm_per_day, interval_rain_cm_per_day, &
         interval_irrigation_cm_per_day, interception_cm_per_day, net_rain, net_irrigation, partition_status)
    if (partition_status /= VONHHBRADEN_AVAILABLE) then
      status = PPA_WU04C_BIND_PARTITION_REJECTED
      return
    end if
    if (.not. ieee_is_finite(net_rain) .or. .not. ieee_is_finite(net_irrigation) .or. net_rain < 0.0_real64 .or. &
         net_irrigation < 0.0_real64) return
    bound_request = base_request
    ! Dynamic top remains the only accepted surface-water mass owner.
    bound_request%precipitation_rate_cm_per_day = net_rain
    bound_request%irrigation_rate_cm_per_day = net_irrigation
    status = PPA_WU04C_BIND_OK
  end subroutine bind_ppa_wu04c_vonhhbraden_dynamic_top
end module mod_ppa_wu04c_vonhhbraden_forcing_adapter

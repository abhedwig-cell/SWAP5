module mod_ppa_irr_rate_materialization
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: IRR_RATE_MATERIALIZATION_OK = 0
  integer, parameter, public :: IRR_RATE_MATERIALIZATION_INVALID_INPUT = 1

  public :: materialize_irrigation_rate

contains

  pure subroutine materialize_irrigation_rate(depth_cm, rate_cm_per_day, is_subsurface, active_nodes, &
                                              effective_rate, event_duration_days, node_rates, rate_sum, status)
    real(real64), intent(in) :: depth_cm, rate_cm_per_day
    logical, intent(in) :: is_subsurface
    integer, intent(in) :: active_nodes
    real(real64), intent(out) :: effective_rate, event_duration_days, rate_sum
    real(real64), allocatable, intent(out) :: node_rates(:)
    integer, intent(out) :: status

    effective_rate = 0.0_real64
    event_duration_days = 0.0_real64
    rate_sum = 0.0_real64
    status = IRR_RATE_MATERIALIZATION_INVALID_INPUT
    if (.not. ieee_is_finite(depth_cm) .or. .not. ieee_is_finite(rate_cm_per_day)) return
    if (depth_cm < 0.0_real64 .or. rate_cm_per_day < 0.0_real64 .or. rate_cm_per_day > 240.0_real64) return
    if (is_subsurface .and. active_nodes <= 0) return

    if (rate_cm_per_day > 0.0_real64) then
      if (depth_cm/rate_cm_per_day > 1.0_real64) then
        effective_rate = depth_cm
        event_duration_days = 1.0_real64
      else
        effective_rate = rate_cm_per_day
        event_duration_days = depth_cm/rate_cm_per_day
      end if
    else
      effective_rate = depth_cm
      event_duration_days = 1.0_real64
    end if

    if (is_subsurface) then
      allocate(node_rates(active_nodes))
      node_rates = effective_rate
      rate_sum = sum(node_rates)
    end if
    status = IRR_RATE_MATERIALIZATION_OK
  end subroutine materialize_irrigation_rate

end module mod_ppa_irr_rate_materialization

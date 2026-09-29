module mod_ppa_irr_fixed_input_normalization
  use, intrinsic :: iso_fortran_env, only: real64
  implicit none
  private

  public :: normalize_fixed_irrigation_input

contains

  pure subroutine normalize_fixed_irrigation_input(depth_mm, supplied_rate_mm_per_hour, has_rate, &
                                                   application_type, ssdi_node_count, depth_cm, &
                                                   rate_cm_per_day, event_duration_day)
    real(real64), intent(in) :: depth_mm, supplied_rate_mm_per_hour
    logical, intent(in) :: has_rate
    integer, intent(in) :: application_type, ssdi_node_count
    real(real64), intent(out) :: depth_cm, rate_cm_per_day, event_duration_day
    real(real64) :: input_depth_mm, input_rate_mm_per_hour

    input_depth_mm = depth_mm
    if (has_rate) then
      input_rate_mm_per_hour = supplied_rate_mm_per_hour
    else
      input_rate_mm_per_hour = depth_mm / 24.0_real64
    end if

    if (application_type == 2) input_depth_mm = input_depth_mm / real(ssdi_node_count, real64)
    depth_cm = 0.1_real64 * input_depth_mm
    rate_cm_per_day = 0.1_real64 * 24.0_real64 * input_rate_mm_per_hour
    event_duration_day = depth_cm / rate_cm_per_day
  end subroutine normalize_fixed_irrigation_input

end module mod_ppa_irr_fixed_input_normalization

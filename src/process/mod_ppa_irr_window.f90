module mod_ppa_irr_window
  use, intrinsic :: iso_fortran_env, only: real64
  implicit none
  private

  public :: scheduled_irrigation_window_open

contains

  pure logical function scheduled_irrigation_window_open(crop_year_active, current_date, start_date, end_date)
    logical, intent(in) :: crop_year_active
    real(real64), intent(in) :: current_date, start_date, end_date

    if (crop_year_active) then
      scheduled_irrigation_window_open = (current_date-start_date) > 1.0e-3_real64 .and. &
                                         (current_date-end_date) <= 1.0e-3_real64
    else
      scheduled_irrigation_window_open = (current_date-start_date) >= -1.0e-3_real64 .and. &
                                         (current_date-end_date) <= 1.0e-3_real64
    end if
  end function scheduled_irrigation_window_open

end module mod_ppa_irr_window

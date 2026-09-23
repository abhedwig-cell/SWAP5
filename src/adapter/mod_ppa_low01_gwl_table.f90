module mod_ppa_low01_gwl_table
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: PPA_LOW01_GWL_OK = 0
  integer, parameter, public :: PPA_LOW01_GWL_INVALID_INPUT = 1
  public :: evaluate_ppa_low01_gwl_table

contains

  ! SWBOTB=1 numeric DATE1/GWLEVEL validation and runtime GWLINP AFGEN law.
  ! Hybrid/head-correction transitions remain with the solver's GWL state owner.
  subroutine evaluate_ppa_low01_gwl_table(date_t1900, gwlevel, simulation_start_t1900, &
      simulation_end_t1900, query_t1900, lowest_allowed_gwl, gwlinp, status)
    real(real64), intent(in) :: date_t1900(:), gwlevel(:)
    real(real64), intent(in) :: simulation_start_t1900, simulation_end_t1900, query_t1900
    real(real64), intent(in) :: lowest_allowed_gwl
    real(real64), intent(out) :: gwlinp
    integer, intent(out) :: status
    integer :: upper
    real(real64) :: slope

    gwlinp = 0.0_real64
    status = PPA_LOW01_GWL_INVALID_INPUT
    if (size(date_t1900) == 0 .or. size(date_t1900) /= size(gwlevel)) return
    if (.not. all(ieee_is_finite([simulation_start_t1900, simulation_end_t1900, &
                                  query_t1900, lowest_allowed_gwl]))) return
    if (.not. all(ieee_is_finite(date_t1900)) .or. .not. all(ieee_is_finite(gwlevel))) return
    if (simulation_start_t1900 > simulation_end_t1900) return
    if (any(gwlevel < -10000.0_real64) .or. any(gwlevel > 1000.0_real64)) return
    if (any(gwlevel > lowest_allowed_gwl)) return
    if (.not. any(date_t1900 >= simulation_start_t1900 .and. date_t1900 <= simulation_end_t1900)) return
    if (size(date_t1900) > 1) then
      if (any(date_t1900(2:) <= date_t1900(:size(date_t1900)-1))) return
    end if

    if (query_t1900 <= date_t1900(1)) then
      gwlinp = gwlevel(1)
    else if (query_t1900 > date_t1900(size(date_t1900))) then
      gwlinp = gwlevel(size(gwlevel))
    else
      do upper = 2, size(date_t1900)
        if (date_t1900(upper) >= query_t1900) exit
      end do
      slope = (gwlevel(upper) - gwlevel(upper-1)) / (date_t1900(upper) - date_t1900(upper-1))
      gwlinp = gwlevel(upper-1) + (query_t1900 - date_t1900(upper-1)) * slope
    end if
    if (.not. ieee_is_finite(gwlinp)) then
      gwlinp = 0.0_real64
      return
    end if
    status = PPA_LOW01_GWL_OK
  end subroutine evaluate_ppa_low01_gwl_table

end module mod_ppa_low01_gwl_table

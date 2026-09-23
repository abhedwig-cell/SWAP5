module mod_ppa_low04_qh_table
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: PPA_LOW04_QH_OK = 0
  integer, parameter, public :: PPA_LOW04_QH_INVALID_INPUT = 1
  public :: evaluate_ppa_low04_qh_table

contains

  ! SWBOTB=4 / SWQHBOT=2: B1.11 builds qbotab x-values as abs(htab),
  ! then evaluates AFGEN at abs(gwl). Inputs are the raw Htab/Qtab vectors.
  subroutine evaluate_ppa_low04_qh_table(head_table, flux_table, gwl, qbot, status)
    real(real64), intent(in) :: head_table(:), flux_table(:), gwl
    real(real64), intent(out) :: qbot
    integer, intent(out) :: status
    real(real64), allocatable :: abs_head_table(:)
    integer :: upper
    real(real64) :: slope, query

    qbot = 0.0_real64
    status = PPA_LOW04_QH_INVALID_INPUT
    if (size(head_table) == 0 .or. size(head_table) /= size(flux_table)) return
    if (.not. ieee_is_finite(gwl) .or. .not. all(ieee_is_finite(head_table)) .or. &
        .not. all(ieee_is_finite(flux_table))) return
    if (any(head_table < -10000.0_real64) .or. any(head_table > 0.0_real64)) return
    if (any(flux_table < -100.0_real64) .or. any(flux_table > 100.0_real64)) return

    allocate(abs_head_table(size(head_table)))
    abs_head_table = abs(head_table)
    if (size(head_table) > 1) then
      if (any(abs_head_table(2:) <= abs_head_table(:size(head_table)-1))) return
    end if
    query = abs(gwl)

    if (query < abs_head_table(1)) then
      qbot = flux_table(1)
    else if (query >= abs_head_table(size(head_table))) then
      qbot = flux_table(size(flux_table))
    else
      do upper = 2, size(head_table)
        if (abs_head_table(upper) >= query) exit
      end do
      slope = (flux_table(upper) - flux_table(upper-1)) / &
              (abs_head_table(upper) - abs_head_table(upper-1))
      qbot = flux_table(upper-1) + (query - abs_head_table(upper-1)) * slope
    end if
    if (.not. ieee_is_finite(qbot)) then
      qbot = 0.0_real64
      return
    end if
    status = PPA_LOW04_QH_OK
  end subroutine evaluate_ppa_low04_qh_table

end module mod_ppa_low04_qh_table

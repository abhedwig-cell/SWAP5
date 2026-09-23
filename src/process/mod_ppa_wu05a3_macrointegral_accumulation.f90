! Candidate-only MACROINTEGRAL accumulators; explicit input rates and history.
module mod_ppa_wu05a3_macrointegral_accumulation
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private
  integer, parameter, public :: MP_IN_INTER=1, MP_IN_MATRIX=2, MP_OUT_SAT=3, MP_OUT_UNSAT=4, MP_TOP=5
  integer, parameter, public :: MP_VERTICAL=1, MP_LATERAL=2
  type, public :: macrointegral_history
    ! Cell layout: channel, main/internal group, cell.
    real(real64), allocatable :: cell(:,:,:), exchange(:,:), rapid(:), wet(:,:)
    real(real64) :: top(2,2)=0.0_real64, cumulative_top(2,2)=0.0_real64
    real(real64) :: cumulative_cell(4,2)=0.0_real64
    real(real64) :: rapid_total=0.0_real64, cumulative_rapid=0.0_real64
  end type
  public :: accumulate_macrointegral
contains
  subroutine accumulate_macrointegral(n,ic_top,dt,top_rate,cell_rate,rapid_rate,wet_rate,previous,candidate,status)
    integer, intent(in) :: n,ic_top
    real(real64), intent(in) :: dt,top_rate(:,:),cell_rate(:,:,:),rapid_rate(:),wet_rate(:,:)
    type(macrointegral_history), intent(in) :: previous
    type(macrointegral_history), intent(out) :: candidate
    integer, intent(out) :: status
    integer :: ic,g,k
    status=1
    if(n<1 .or. ic_top<1 .or. ic_top>n) return
    if(.not.ieee_is_finite(dt)) return
    if(dt<=0.0_real64) return
    if(any(shape(top_rate)/=[2,2]) .or. any(shape(cell_rate)/=[5,2,n]) .or. &
        size(rapid_rate)/=n .or. any(shape(wet_rate)/=[2,n])) return
    if(.not.allocated(previous%cell) .or. .not.allocated(previous%exchange) .or. &
        .not.allocated(previous%rapid) .or. .not.allocated(previous%wet)) return
    if(any(shape(previous%cell)/=[5,2,n]) .or. any(shape(previous%exchange)/=[2,n]) .or. &
        size(previous%rapid)/=n .or. any(shape(previous%wet)/=[2,n])) return
    if(.not.all(ieee_is_finite(top_rate)) .or. .not.all(ieee_is_finite(cell_rate)) .or. &
        .not.all(ieee_is_finite(rapid_rate)) .or. .not.all(ieee_is_finite(wet_rate))) return
    if(.not.finite_history(previous)) return

    candidate=previous
    candidate%top=previous%top+top_rate*dt
    do ic=max(ic_top-1,1),n
      do g=1,2
        do k=1,5
          candidate%cell(k,g,ic)=previous%cell(k,g,ic)+cell_rate(k,g,ic)*dt
        end do
        candidate%exchange(g,ic)=-candidate%cell(MP_IN_INTER,g,ic)-candidate%cell(MP_IN_MATRIX,g,ic)+ &
            candidate%cell(MP_OUT_SAT,g,ic)+candidate%cell(MP_OUT_UNSAT,g,ic)
        candidate%wet(g,ic)=previous%wet(g,ic)+wet_rate(g,ic)*dt
      end do
      candidate%rapid(ic)=previous%rapid(ic)+rapid_rate(ic)*dt
      candidate%rapid_total=candidate%rapid_total+rapid_rate(ic)*dt
    end do
    ! Preserve ascending cell additions, rather than replacing them by SUM(rate)*dt.
    do ic=max(ic_top-1,1),n
      do g=1,2
        do k=1,4
          candidate%cumulative_cell(k,g)=candidate%cumulative_cell(k,g)+cell_rate(k,g,ic)*dt
        end do
      end do
      candidate%cumulative_rapid=candidate%cumulative_rapid+rapid_rate(ic)*dt
    end do
    candidate%cumulative_top=previous%cumulative_top+top_rate*dt
    if(.not.finite_history(candidate)) then
      candidate=macrointegral_history()
      return
    end if
    status=0
  end subroutine

  logical function finite_history(h)
    type(macrointegral_history), intent(in) :: h
    finite_history=all(ieee_is_finite(h%cell)) .and. all(ieee_is_finite(h%exchange)) .and. &
        all(ieee_is_finite(h%rapid)) .and. all(ieee_is_finite(h%wet)) .and. &
        all(ieee_is_finite(h%top)) .and. all(ieee_is_finite(h%cumulative_top)) .and. &
        all(ieee_is_finite(h%cumulative_cell)) .and. ieee_is_finite(h%rapid_total) .and. &
        ieee_is_finite(h%cumulative_rapid)
  end function
end module

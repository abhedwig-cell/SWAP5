module mod_b111_nfixation_policy
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: B111_NFIX_OK = 0
  integer, parameter, public :: B111_NFIX_INVALID = 1

  type, public :: b111_nfixation_result_t
    integer :: status = B111_NFIX_OK
    real(real64) :: vegetative_demand = 0.0_real64
    real(real64) :: fixation = 0.0_real64
    real(real64) :: soil_demand = 0.0_real64
  end type b111_nfixation_result_t

  public :: evaluate_b111_nfixation

contains

  pure subroutine evaluate_b111_nfixation(dvs, dvsnlt, reltr, nfixf, &
       nmaxlv, nmaxst, nmaxrt, wlv, wst, wrt, anlv, anst, anrt, result)
    real(real64), intent(in) :: dvs, dvsnlt, reltr, nfixf
    real(real64), intent(in) :: nmaxlv, nmaxst, nmaxrt
    real(real64), intent(in) :: wlv, wst, wrt, anlv, anst, anrt
    type(b111_nfixation_result_t), intent(out) :: result
    real(real64) :: ndeml, ndems, ndemr

    result = b111_nfixation_result_t()
    if (.not. all(ieee_is_finite([dvs,dvsnlt,reltr,nfixf,nmaxlv,nmaxst,nmaxrt, &
                                  wlv,wst,wrt,anlv,anst,anrt]))) then
      result%status = B111_NFIX_INVALID
      return
    end if
    if (dvsnlt < 0.0_real64 .or. reltr < 0.0_real64 .or. nfixf < 0.0_real64 .or. nfixf > 1.0_real64 .or. &
        min(nmaxlv,nmaxst,nmaxrt,wlv,wst,wrt,anlv,anst,anrt) < 0.0_real64) then
      result%status = B111_NFIX_INVALID
      return
    end if

    ndeml = max(0.0_real64, nmaxlv*wlv - anlv)
    ndems = max(0.0_real64, nmaxst*wst - anst)
    ndemr = max(0.0_real64, nmaxrt*wrt - anrt)
    result%vegetative_demand = ndeml + ndems + ndemr

    if (dvs < dvsnlt .and. reltr > 0.01_real64) then
      result%fixation = nfixf*result%vegetative_demand
      result%soil_demand = max(0.0_real64, result%vegetative_demand-result%fixation)
    end if
  end subroutine evaluate_b111_nfixation

end module mod_b111_nfixation_policy

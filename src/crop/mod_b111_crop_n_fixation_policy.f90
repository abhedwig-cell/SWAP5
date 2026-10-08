module mod_b111_crop_n_fixation_policy
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: B111_NFIX_OK = 0
  integer, parameter, public :: B111_NFIX_INVALID = 1

  type, public :: b111_nfix_request_t
    integer :: status = B111_NFIX_OK
    real(real64) :: vegetative_demand = 0.0_real64
    real(real64) :: fixation_request = 0.0_real64
  end type

  type, public :: b111_nfix_state_t
    real(real64) :: fixation_total = 0.0_real64
  end type

  type, public :: b111_nfix_receipt_t
    integer :: status = B111_NFIX_OK
    real(real64) :: fixed_n = 0.0_real64
  end type

  public :: prepare_b111_nfix_request, apply_b111_nfixation

contains

  pure subroutine prepare_b111_nfix_request(dvs, reltr, dvsnlt, nfixf, &
      wlv, wst, wrt, nmaxlv, nmaxst, nmaxrt, anlv, anst, anrt, request)
    real(real64), intent(in) :: dvs, reltr, dvsnlt, nfixf
    real(real64), intent(in) :: wlv, wst, wrt, nmaxlv, nmaxst, nmaxrt
    real(real64), intent(in) :: anlv, anst, anrt
    type(b111_nfix_request_t), intent(out) :: request
    real(real64) :: ndeml, ndems, ndemr

    request = b111_nfix_request_t()
    if (.not. all(ieee_is_finite([dvs, reltr, dvsnlt, nfixf, wlv, wst, wrt, &
                                  nmaxlv, nmaxst, nmaxrt, anlv, anst, anrt]))) then
      request%status = B111_NFIX_INVALID
      return
    end if
    if (nfixf < 0.0_real64 .or. nfixf > 1.0_real64 .or. &
        min(wlv,wst,wrt,nmaxlv,nmaxst,nmaxrt,anlv,anst,anrt) < 0.0_real64) then
      request%status = B111_NFIX_INVALID
      return
    end if

    ndeml = max(0.0_real64, nmaxlv*wlv - anlv)
    ndems = max(0.0_real64, nmaxst*wst - anst)
    ndemr = max(0.0_real64, nmaxrt*wrt - anrt)
    request%vegetative_demand = ndeml + ndems + ndemr

    if (dvs < dvsnlt .and. reltr > 0.01_real64) then
      request%fixation_request = nfixf*request%vegetative_demand
    end if
  end subroutine

  pure subroutine apply_b111_nfixation(committed, request, candidate, receipt)
    type(b111_nfix_state_t), intent(in) :: committed
    type(b111_nfix_request_t), intent(in) :: request
    type(b111_nfix_state_t), intent(out) :: candidate
    type(b111_nfix_receipt_t), intent(out) :: receipt

    candidate = committed
    receipt = b111_nfix_receipt_t()
    if (request%status /= B111_NFIX_OK .or. .not. ieee_is_finite(committed%fixation_total) .or. &
        committed%fixation_total < 0.0_real64 .or. .not. ieee_is_finite(request%fixation_request) .or. &
        request%fixation_request < 0.0_real64) then
      receipt%status = B111_NFIX_INVALID
      return
    end if
    receipt%fixed_n = request%fixation_request
    candidate%fixation_total = committed%fixation_total + receipt%fixed_n
  end subroutine
end module

module mod_ppa_wu05d2_jarvis_compositor
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: PPA_WU05D2_OK = 0
  integer, parameter, public :: PPA_WU05D2_INVALID_INPUT = 1
  public :: ppa_wu05d2_apply_jarvis

contains

  subroutine ppa_wu05d2_apply_jarvis(ptra, alphacrit, stress_selector, qrot_in, qred_stress, &
      qrot_out, qrosum_out, qred_stress_out, status)
    real(real64), intent(in) :: ptra, alphacrit
    integer, intent(in) :: stress_selector
    real(real64), intent(in) :: qrot_in(:), qred_stress(4)
    real(real64), intent(out) :: qrot_out(:), qrosum_out, qred_stress_out(4)
    integer, intent(out) :: status
    real(real64) :: qrosum, qred, alptot, alptotcom, scale, factor(4)
    integer :: selected

    qrot_out = 0.0_real64
    qrosum_out = 0.0_real64
    qred_stress_out = 0.0_real64
    status = PPA_WU05D2_INVALID_INPUT
    if (size(qrot_out) /= size(qrot_in)) return
    if (size(qrot_in) == 0 .or. stress_selector < 1 .or. stress_selector > 5) return
    if (.not. ieee_is_finite(ptra) .or. .not. ieee_is_finite(alphacrit)) return
    if (ptra <= 0.0_real64 .or. alphacrit < 0.2_real64 .or. alphacrit > 1.0_real64) return
    if (any(.not. ieee_is_finite(qrot_in)) .or. any(.not. ieee_is_finite(qred_stress))) return
    if (any(qrot_in < 0.0_real64) .or. any(qred_stress < 0.0_real64)) return

    qrosum = sum(qrot_in)
    if (.not. ieee_is_finite(qrosum) .or. qrosum > ptra) return
    qred = ptra - qrosum
    status = PPA_WU05D2_OK
    qrot_out = qrot_in
    qrosum_out = qrosum
    qred_stress_out = qred_stress
    if (abs(alphacrit - 1.0_real64) < 1.0e-14_real64 .or. qred <= 1.0e-14_real64) return
    if (sum(qred_stress) <= 1.0e-14_real64) return
    if (abs(sum(qred_stress) - qred) > 1.0e-10_real64 * max(1.0_real64, qred)) then
      status = PPA_WU05D2_INVALID_INPUT
      qrot_out = 0.0_real64
      qrosum_out = 0.0_real64
      qred_stress_out = 0.0_real64
      return
    end if

    alptot = qrosum / ptra
    if (alptot < 1.0e-14_real64) return
    factor = alptot ** (qred_stress / qred)
    if (stress_selector == 1) then
      alptotcom = min(alptot / alphacrit, 1.0_real64)
    else
      selected = stress_selector - 1
      factor(selected) = min(factor(selected) / alphacrit, 1.0_real64)
      alptotcom = product(factor)
    end if
    scale = alptotcom / alptot
    qrot_out = scale * qrot_in
    qrosum_out = ptra * alptotcom
    qred_stress_out = qred_stress * ((ptra - qrosum_out) / qred)
  end subroutine ppa_wu05d2_apply_jarvis

end module mod_ppa_wu05d2_jarvis_compositor

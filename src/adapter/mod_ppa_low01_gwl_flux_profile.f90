module mod_ppa_low01_gwl_flux_profile
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: PPA_LOW01_FLUX_OK = 0
  integer, parameter, public :: PPA_LOW01_FLUX_INVALID_INPUT = 1
  public :: evaluate_ppa_low01_gwl_flux_profile

contains

  ! Source-shaped converged SWBOTB=1 in-profile vertical flux and saturated-head reconstruction.
  subroutine evaluate_ppa_low01_gwl_flux_profile(nn, qtop, dt, dz, macro_fraction, theta, theta_previous, &
      sink, source, qrot, disnod, kmean, head_in, qv, head_out, qbot, status)
    integer, intent(in) :: nn
    real(real64), intent(in) :: qtop, dt, dz(:), macro_fraction(:), theta(:), theta_previous(:)
    real(real64), intent(in) :: sink(:), source(:), qrot(:), disnod(:), kmean(:), head_in(:)
    real(real64), intent(out) :: qv(:), head_out(:), qbot
    integer, intent(out) :: status
    integer :: n, i

    qv = 0.0_real64
    head_out = 0.0_real64
    qbot = 0.0_real64
    status = PPA_LOW01_FLUX_INVALID_INPUT
    n = size(dz)
    if (n < 2 .or. nn < 1 .or. nn >= n) return
    if (size(qv) /= n+1 .or. size(head_out) /= n .or. size(macro_fraction) /= n .or. &
        size(theta) /= n .or. size(theta_previous) /= n .or. size(sink) /= n .or. &
        size(source) /= n .or. size(qrot) /= n .or. size(disnod) /= n .or. &
        size(kmean) /= n .or. size(head_in) /= n) return
    if (.not. ieee_is_finite(dt) .or. .not. ieee_is_finite(qtop)) return
    if (dt <= 0.0_real64) return
    if (.not. all(ieee_is_finite(dz)) .or. .not. all(ieee_is_finite(macro_fraction)) .or. &
        .not. all(ieee_is_finite(theta)) .or. .not. all(ieee_is_finite(theta_previous)) .or. &
        .not. all(ieee_is_finite(sink)) .or. .not. all(ieee_is_finite(source)) .or. &
        .not. all(ieee_is_finite(qrot)) .or. .not. all(ieee_is_finite(disnod)) .or. &
        .not. all(ieee_is_finite(kmean)) .or. .not. all(ieee_is_finite(head_in))) return
    if (any(dz <= 0.0_real64) .or. any(disnod(nn+1:n) <= 0.0_real64) .or. &
        any(kmean(nn+1:n) <= 0.0_real64)) return

    head_out = head_in
    qv(1) = qtop
    do i = 1, n
      qv(i+1) = qv(i) + dz(i)*macro_fraction(i)*(theta(i)-theta_previous(i))/dt + &
          sink(i) - source(i) + qrot(i)
      if (.not. ieee_is_finite(qv(i+1))) then
        qv = 0.0_real64
        head_out = 0.0_real64
        qbot = 0.0_real64
        return
      end if
    end do
    qbot = qv(n+1)
    do i = nn + 1, n
      head_out(i) = head_out(i-1) + disnod(i)*(qv(i)/kmean(i) + 1.0_real64)
      if (.not. ieee_is_finite(head_out(i))) then
        qv = 0.0_real64
        head_out = 0.0_real64
        qbot = 0.0_real64
        return
      end if
    end do
    status = PPA_LOW01_FLUX_OK
  end subroutine evaluate_ppa_low01_gwl_flux_profile

end module mod_ppa_low01_gwl_flux_profile

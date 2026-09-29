module mod_ppa_low01_gwl_surface_profile
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: PPA_LOW01_SURFACE_OK = 0
  integer, parameter, public :: PPA_LOW01_SURFACE_INVALID_INPUT = 1
  public :: evaluate_ppa_low01_gwl_surface_profile

contains

  ! Source-shaped SWBOTB=1 saturated profile branch when GWL reaches the surface.
  ! qv(1) is the already-composed top flux after pond/runoff balance.
  subroutine evaluate_ppa_low01_gwl_surface_profile(gwlinp, qv1, dt, dz, macro_fraction, theta, &
      theta_previous, sink, source, qrot, disnod, kmean, qv, head, qbot, status)
    real(real64), intent(in) :: gwlinp, qv1, dt, dz(:), macro_fraction(:), theta(:), theta_previous(:)
    real(real64), intent(in) :: sink(:), source(:), qrot(:), disnod(:), kmean(:)
    real(real64), intent(out) :: qv(:), head(:), qbot
    integer, intent(out) :: status
    integer :: n, i

    qv = 0.0_real64
    head = 0.0_real64
    qbot = 0.0_real64
    status = PPA_LOW01_SURFACE_INVALID_INPUT
    n = size(dz)
    if (n < 1) return
    if (size(qv) /= n+1 .or. size(head) /= n .or. size(macro_fraction) /= n .or. &
        size(theta) /= n .or. size(theta_previous) /= n .or. size(sink) /= n .or. &
        size(source) /= n .or. size(qrot) /= n .or. size(disnod) /= n .or. size(kmean) /= n) return
    if (.not. all(ieee_is_finite([gwlinp, qv1, dt]))) return
    if (.not. all(ieee_is_finite(dz)) .or. .not. all(ieee_is_finite(macro_fraction)) .or. &
        .not. all(ieee_is_finite(theta)) .or. .not. all(ieee_is_finite(theta_previous)) .or. &
        .not. all(ieee_is_finite(sink)) .or. .not. all(ieee_is_finite(source)) .or. &
        .not. all(ieee_is_finite(qrot)) .or. .not. all(ieee_is_finite(disnod)) .or. &
        .not. all(ieee_is_finite(kmean))) return
    if (dt <= 0.0_real64 .or. any(dz <= 0.0_real64) .or. any(disnod <= 0.0_real64) .or. &
        any(kmean <= 0.0_real64)) return

    qv(1) = qv1
    head(1) = gwlinp + disnod(1)*(qv(1)/kmean(1)+1.0_real64)
    do i = 1, n
      qv(i+1) = qv(i) + dz(i)*macro_fraction(i)*(theta(i)-theta_previous(i))/dt + &
          sink(i)-source(i)+qrot(i)
      if (.not. ieee_is_finite(qv(i+1))) then
        qv = 0.0_real64
        head = 0.0_real64
        qbot = 0.0_real64
        return
      end if
    end do
    do i = 2, n
      head(i) = head(i-1) + disnod(i)*(qv(i)/kmean(i)+1.0_real64)
      if (.not. ieee_is_finite(head(i))) then
        qv = 0.0_real64
        head = 0.0_real64
        qbot = 0.0_real64
        return
      end if
    end do
    qbot = qv(n+1)
    status = PPA_LOW01_SURFACE_OK
  end subroutine evaluate_ppa_low01_gwl_surface_profile

end module mod_ppa_low01_gwl_surface_profile

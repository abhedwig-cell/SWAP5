module MOD_wofost81_assimilation

   use iso_fortran_env, only: real64
   implicit none
   private

   public :: totass81
   public :: assim81

contains

   pure subroutine totass81(amax_lnb, amax_ref, amax_slp, dayl, co2amax, tmpf, eff, kn, lai, nlv, &
                            kdif, avrad, difpp, dsinbe, sinld, cosld, dtga)
      ! Source-faithful Fortran implementation of the WOFOST 8.1
      ! canopy-assimilation equations in PCSE 6.0.13 totass8/assim8.
      real(real64), intent(in) :: amax_lnb, amax_ref, amax_slp
      real(real64), intent(in) :: dayl, co2amax, tmpf, eff, kn
      real(real64), intent(in) :: lai, nlv, kdif, avrad
      real(real64), intent(in) :: difpp, dsinbe, sinld, cosld
      real(real64), intent(out) :: dtga

      integer :: i
      real(real64) :: hour, sinb, par, pardif, pardir, fgros
      real(real64), parameter :: pi = acos(-1.0_real64)
      real(real64), dimension(3), parameter :: xgauss = &
         [0.1127017_real64, 0.5000000_real64, 0.8872983_real64]
      real(real64), dimension(3), parameter :: wgauss = &
         [0.2777778_real64, 0.4444444_real64, 0.2777778_real64]

      dtga = 0.0_real64
      if (lai > 0.0_real64 .and. dayl > 0.0_real64) then
         do i = 1, 3
            hour = 12.0_real64 + 0.5_real64 * dayl * xgauss(i)
            sinb = max(0.0_real64, sinld + cosld * cos(2.0_real64*pi*(hour + 12.0_real64)/24.0_real64))
            par = 0.5_real64 * avrad * sinb * (1.0_real64 + 0.4_real64*sinb) / dsinbe
            pardif = min(par, sinb*difpp)
            pardir = par - pardif
            call assim81(amax_lnb, amax_ref, amax_slp, co2amax, tmpf, eff, kn, lai, nlv, kdif, &
                         sinb, pardir, pardif, fgros)
            dtga = dtga + fgros*wgauss(i)
         end do
         dtga = dtga * dayl
      end if
   end subroutine totass81

   pure subroutine assim81(amax_lnb, amax_ref, amax_slp, co2amax, tmpf, eff, kn, lai, nlv, kdif, &
                           sinb, pardir, pardif, fgros)
      real(real64), intent(in) :: amax_lnb, amax_ref, amax_slp
      real(real64), intent(in) :: co2amax, tmpf, eff, kn
      real(real64), intent(in) :: lai, nlv, kdif, sinb, pardir, pardif
      real(real64), intent(out) :: fgros

      integer :: i
      real(real64) :: refh, refs, kdirbl, kdirt, laic, sln, amax
      real(real64) :: visdf, vist, visd, visshd, fgrsh, vispp, fgrsun, fslla, fgl
      real(real64), parameter :: scv = 0.2_real64
      real(real64), parameter :: sqrt_scv = sqrt(1.0_real64 - scv)
      real(real64), dimension(3), parameter :: xgauss = &
         [0.1127017_real64, 0.5000000_real64, 0.8872983_real64]
      real(real64), dimension(3), parameter :: wgauss = &
         [0.2777778_real64, 0.4444444_real64, 0.2777778_real64]

      refh = (1.0_real64 - sqrt_scv) / (1.0_real64 + sqrt_scv)
      refs = refh * 2.0_real64 / (1.0_real64 + 1.6_real64*sinb)
      kdirbl = (0.5_real64/sinb) * kdif / (0.8_real64*sqrt_scv)
      kdirt = kdirbl * sqrt_scv

      fgros = 0.0_real64
      do i = 1, 3
         laic = lai*xgauss(i)

         if (lai >= 0.01_real64) then
            sln = nlv * kn * exp(-kn*laic) / (1.0_real64 - exp(-kn*lai))
         else
            sln = nlv/lai
         end if

         amax = co2amax * tmpf * min(amax_ref, max(0.0_real64, amax_slp*(sln - amax_lnb)))

         visdf = (1.0_real64 - refs) * pardif * kdif * exp(-kdif*laic)
         vist = (1.0_real64 - refs) * pardir * kdirt * exp(-kdirt*laic)
         visd = (1.0_real64 - scv) * pardir * kdirbl * exp(-kdirbl*laic)

         visshd = visdf + vist - visd
         fgrsh = amax * (1.0_real64 - exp(-visshd*eff/max(2.0_real64, amax)))

         vispp = (1.0_real64 - scv) * pardir / sinb
         if (vispp <= 0.0_real64) then
            fgrsun = fgrsh
         else
            fgrsun = amax * (1.0_real64 - (amax - fgrsh) * &
                     (1.0_real64 - exp(-vispp*eff/max(2.0_real64, amax))) / (eff*vispp))
         end if

         fslla = exp(-kdirbl*laic)
         fgl = fslla*fgrsun + (1.0_real64 - fslla)*fgrsh
         fgros = fgros + fgl*wgauss(i)
      end do

      fgros = fgros*lai
   end subroutine assim81

end module MOD_wofost81_assimilation

program test_wofost81_assimilation_driver
   use iso_fortran_env, only: real64
   use MOD_wofost81_assimilation, only: totass81
   implicit none

   integer :: i, n, ios
   real(real64) :: amax_lnb, amax_ref, amax_slp, dayl, co2amax, tmpf, eff, kn
   real(real64) :: lai, nlv, kdif, avrad, difpp, dsinbe, sinld, cosld, dtga

   read (*, *, iostat=ios) n
   if (ios /= 0 .or. n < 0) error stop 1
   do i = 1, n
      read (*, *, iostat=ios) amax_lnb, amax_ref, amax_slp, dayl, co2amax, tmpf, eff, kn, &
                             lai, nlv, kdif, avrad, difpp, dsinbe, sinld, cosld
      if (ios /= 0) error stop 2
      call totass81(amax_lnb, amax_ref, amax_slp, dayl, co2amax, tmpf, eff, kn, lai, nlv, &
                    kdif, avrad, difpp, dsinbe, sinld, cosld, dtga)
      write (*, '(ES25.17E3)') dtga
   end do
end program test_wofost81_assimilation_driver

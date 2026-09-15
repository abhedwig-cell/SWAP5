program test_wofost81_nitrogen_driver
   use iso_fortran_env, only: real64
   use MOD_wofost81_nitrogen
   implicit none

   type(WOFOST81_n_param) :: p
   type(WOFOST81_n_state) :: s, c
   type(WOFOST81_n_request) :: q
   type(WOFOST81_n_flux) :: f
   integer :: ios
   real(real64) :: dvs, nmaxlv, wlv, wst, wrt, wso, grlv, grst, grrt, grso, rftra
   real(real64) :: drlv, drst, drrt, soil_supply

   do
      read (*, *, iostat=ios) p%nmaxst_fr, p%nmaxrt_fr, p%nmaxso, p%nresidlv, p%nresidst, p%nresidrt, &
                             p%tcnt, p%nfix_fr, p%rnuptakemax, p%dvs_n_transl, &
                             s%namountlv, s%namountst, s%namountrt, s%namountso, &
                             s%nuptake_total, s%nfix_total, s%nlosses_total, s%initial_total, &
                             dvs, nmaxlv, wlv, wst, wrt, wso, grlv, grst, grrt, grso, rftra, &
                             drlv, drst, drrt, soil_supply
      if (ios < 0) exit
      if (ios > 0) error stop 1

      call prepare_wofost81_n_request(p, s, dvs, nmaxlv, wlv, wst, wrt, wso, grlv, grst, grrt, grso, rftra, q)
      call apply_wofost81_n_supply(p, s, q, wlv, wst, wrt, drlv, drst, drrt, soil_supply, c, f)

      write (*, '(*(G0,1X))') q%status, f%status, &
         q%ndemandlv, q%ndemandst, q%ndemandrt, q%ndemandso, q%ndemand, &
         q%rnfixation, q%rntranslocationlv, q%rntranslocationst, q%rntranslocationrt, q%rntranslocation, q%soil_request, &
         c%namountlv, c%namountst, c%namountrt, c%namountso, c%nuptake_total, c%nfix_total, c%nlosses_total, c%initial_total, &
         f%rnuptake, f%rnfixation, f%rntranslocationlv_applied, f%rntranslocationst_applied, &
         f%rntranslocationrt_applied, f%rntranslocation_applied, &
         f%rnuptakelv, f%rnuptakest, f%rnuptakert, f%rnuptakeso, &
         f%rndeathlv, f%rndeathst, f%rndeathrt, f%rnloss, f%balance_residual
   end do
end program test_wofost81_nitrogen_driver

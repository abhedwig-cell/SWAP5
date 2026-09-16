program test_wofost81_nitrogen_edges
   use iso_fortran_env, only: real64
   use MOD_wofost81_nitrogen
   implicit none
   type(WOFOST81_n_param) :: p
   type(WOFOST81_n_state) :: s,c
   type(WOFOST81_n_request) :: q
   type(WOFOST81_n_flux) :: f
   integer :: status

   p%nmaxst_fr=.5_real64; p%nmaxrt_fr=.5_real64; p%nmaxso=.0176_real64
   p%nresidlv=.004_real64; p%nresidst=.002_real64; p%nresidrt=.002_real64
   p%tcnt=10._real64; p%nfix_fr=.2_real64; p%rnuptakemax=4.26_real64; p%dvs_n_transl=.8_real64

   call initialize_wofost81_n_state(1000._real64,800._real64,600._real64,.03_real64,p,s,status)
   call check(status==WOFN81_OK,'init status')
   call check(abs(s%namountlv-30._real64)<1e-12_real64,'init leaf N')
   call check(abs(s%namountst-12._real64)<1e-12_real64,'init stem N')
   call check(abs(s%namountrt-9._real64)<1e-12_real64,'init root N')

   call prepare_wofost81_n_request(p,s,1.2_real64,.03_real64,1000._real64,800._real64,600._real64,200._real64, &
                                   20._real64,20._real64,10._real64,30._real64,1._real64,q)
   call apply_wofost81_n_supply(p,s,q,1000._real64,800._real64,600._real64,5._real64,4._real64,3._real64, &
                                0._real64,c,f)
   call check(f%status==WOFN81_OK,'zero-soil apply status')
   call check(abs(f%rnuptake)<1e-12_real64,'zero-soil uptake')
   call check(abs(f%balance_residual)<=f%balance_tolerance,'zero-soil balance')

   call apply_wofost81_n_supply(p,s,q,1000._real64,800._real64,600._real64,5._real64,4._real64,3._real64, &
                                q%soil_request,c,f)
   call check(f%status==WOFN81_OK,'full-soil apply status')
   call check(abs(f%rnuptake-q%soil_request)<1e-12_real64,'full-soil uptake')
   call check(abs(f%balance_residual)<=f%balance_tolerance,'full-soil balance')

   ! Same-step donor arbitration: complete leaf senescence leaves no old leaf N
   ! available for translocation. New uptake remains in the new leaf biomass.
   s = WOFOST81_n_state()
   s%namountlv = 0.006850010112345595_real64
   s%namountst = 2.0375261333043295_real64
   s%namountrt = 0.4221544087059237_real64
   s%namountso = 26.564893684299076_real64
   s%initial_total = s%namountlv+s%namountst+s%namountrt+s%namountso
   call prepare_wofost81_n_request(p,s,1.9_real64,.014_real64,1.5522960948511446_real64, &
                                   810.1159928239257_real64,180.20513210356495_real64,1800._real64, &
                                   1.1_real64,5._real64,1._real64,30._real64,1._real64,q)
   call apply_wofost81_n_supply(p,s,q,1.5522960948511446_real64,810.1159928239257_real64, &
                                180.20513210356495_real64,1.5522960948511446_real64, &
                                16.202319856478514_real64,3.604102642071299_real64, &
                                0.016884862609608604_real64,c,f)
   call check(f%status==WOFN81_OK,'full-leaf-death arbitration status')
   call check(abs(f%rntranslocationlv_applied)<1e-14_real64,'full-leaf-death leaf translocation clipped')
   call check(c%namountlv>=0._real64,'full-leaf-death non-negative leaf N')
   call check(abs(f%balance_residual)<=f%balance_tolerance,'full-leaf-death balance')

   ! Rejected apply cannot mutate committed state.
   call apply_wofost81_n_supply(p,s,q,1000._real64,800._real64,600._real64,5000._real64,4000._real64,3000._real64, &
                                q%soil_request,c,f)
   call check(f%status==WOFN81_NEGATIVE_CANDIDATE,'negative candidate status')
   call check(abs(c%namountlv-s%namountlv)<1e-12_real64,'rejected trial leaf rollback')
   call check(abs(c%namountst-s%namountst)<1e-12_real64,'rejected trial stem rollback')

   print '(A)', 'SWAP431_WOF81_04_EDGE_PASS'
contains
   subroutine check(ok,label)
      logical,intent(in)::ok
      character(len=*),intent(in)::label
      if(.not.ok) then
         print '(A)',trim(label)//' failed'
         error stop 1
      end if
   end subroutine
end program test_wofost81_nitrogen_edges

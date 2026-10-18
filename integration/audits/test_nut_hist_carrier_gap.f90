! Diagnostic witness only. Does not extend the accepted surface contract.
program test_hist_carrier_gap
 use iso_fortran_env,only:real64,int64
 use mod_b111_soil_n_mineral_owner
 use mod_soil_n_pool_state
 use MOD_texture_orgmat,only:bdens
 implicit none
 type(mineral_parameters_t)::p
 type(mineral_state_t)::s,before
 type(soil_n_pool_state_t)::pools,after
 type(mineral_receipt_t)::r
 real(real64)::rain,evap,net,theta,ce,ca,prod,initial_c,expected,mass,t,w
 integer::code,i,j
 integer(int64)::rev
 p%dz_cm=[30d0];p%inventory%depth_m=.3d0;p%inventory%nfrac_fom=[.01d0]
 p%inventory%nfrac_biomass=.03d0;p%inventory%nfrac_humus=.04d0
 p%drybd=1300d0;p%sorption=0d0;p%c_top=[.005d0,.015d0];bdens(1)=p%drybd
 call initialize_soil_n_pool_state(p%inventory,[0d0],0d0,0d0,.002d0,.003d0,pools,code)
 call check(code==0,'pool init')
 ! A: dry day. B: 4 mm rain and 4 mm evaporation. C: 8 mm and 8 mm.
 ! Identical accepted net water and endpoints, different source N input.
 do j=0,2
  rain=.004d0*j;evap=rain;net=rain-evap;theta=.3d0
  call initialize_mineral(p,9_int64,0d0,theta,pools,s,code)
  call check(code==0,'owner init')
  call advance_mineral_day(s,0d0,1d0,theta,0d0,0d0,0d0,0d0,r,surface_water=net)
  call check(r%status==0.and.r%external_in==0d0,'net-only owner conserves its admitted input')
  call s%snapshot(t,w,after,rev)
  call check(after%ammonium_n_kg_m2==pools%ammonium_n_kg_m2,'net NH4 unchanged')
  call check(after%nitrate_n_kg_m2==pools%nitrate_n_kg_m2,'net NO3 unchanged')
  do i=1,2
   mass=pools%ammonium_n_kg_m2
   if(i==2)mass=pools%nitrate_n_kg_m2
   initial_c=mass/(.3d0*theta)
   ! Unmodified original transport: independent Wflux_inTop=rain;
   ! evaporation is already represented by unchanged water content.
   call Wofost_SoilWaterN(.3d0,1d0,theta,theta,0d0,0d0,0d0,rain,0d0, &
     0d0,0d0,0d0,prod,0d0,0d0,p%c_top(i),0d0,initial_c,ce,ca)
   expected=mass+rain*p%c_top(i)
   call check(abs(ce*.3d0*theta-expected)<1d-15,'original gross source balance')
   write(*,'(A,I1,A,I1,3ES25.16)')'CASE=',j,' SPECIES=',i,mass,ce*.3d0*theta,rain*p%c_top(i)
  end do
  ! Supplying rain as if it were net is not a valid workaround: reject
  ! because water storage did not increase. Confirm no publication.
  if(j>0)then
   call initialize_mineral(p,9_int64,0d0,theta,pools,s,code);before=s
   call advance_mineral_day(s,0d0,1d0,theta,0d0,0d0,0d0,0d0,r,surface_water=rain)
   call check(r%status/=0,'gross substituted for net fails water closure')
   call s%snapshot(t,w,after,rev)
   call check(t==0d0.and.rev==0_int64.and.w==theta,'rejection clock/water unchanged')
   call check(after%ammonium_n_kg_m2==pools%ammonium_n_kg_m2.and. &
     after%nitrate_n_kg_m2==pools%nitrate_n_kg_m2,'rejection mineral inventory unchanged')
  end if
 end do
 print '(A)','HIST_GROSS_NET_INFORMATION_LOSS_WITNESS=PASS'
 print '(A)','FULL_HIST_CAPABILITY=NOT_QUALIFIED'
contains
 subroutine check(ok,label)
  logical,intent(in)::ok
  character(*),intent(in)::label
  if(.not.ok)then
   print *,label;error stop 1
  end if
 end subroutine
end program

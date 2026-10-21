module MOD_texture_orgmat
 implicit none
 real(8)::bdens(1)
end module
subroutine swap_error(a,b)
 implicit none
 character(*),intent(in)::a,b
 print *,a,b
 error stop 1
end subroutine
program test_negative_boundary
 use iso_fortran_env,only:real64,int64
 use MOD_texture_orgmat
 use mod_b111_soil_n_transport
 use mod_b111_soil_n_mineral_owner
 use mod_soil_n_pool_state
 implicit none
 real(real64)::x(18),ce,ca,actual,unmet,tau,t,w
 integer::code,ios,count
 type(b111_soil_n_transport_result_t)::r
 type(mineral_parameters_t)::p
 type(mineral_state_t)::s,initial,resumed
 type(mineral_restart_t)::disk
 type(mineral_receipt_t)::receipt
 type(soil_n_pool_state_t)::pool,got
 integer(int64)::revision
 count=0
 do
  read(*,*,iostat=ios)x
  if(ios/=0)exit
  bdens(1)=x(18)
  call Wofost_SoilWaterN_Negative(x(1),x(2),x(3),x(4),x(5),x(6),x(7),x(8),x(9), &
       x(10),x(11),x(12),x(13),x(14),x(15),x(16),x(17),ce,ca,actual,unmet,tau,code)
  call evaluate_b111_soil_n_negative_boundary(x(1),x(2),x(3),x(4),x(5),x(7),x(8),x(9), &
       x(11),x(12),x(18),x(13),x(14),x(15),x(16),x(17),r)
  call require(code==r%status,'reference/production status')
  if(code==0)then
   call require(maxval(abs([r%concentration_end-ce,r%concentration_average-ca,r%top_actual_rate-actual, &
        r%top_unmet-unmet,r%depletion_time-tau]))<1d-14,'corrected reference all fields')
  end if
  count=count+1
 end do
 call require(count==84,'complete original coefficient/stock/input matrix')
 p%inventory%depth_m=.3d0;p%dz_cm=[30d0];p%inventory%nfrac_fom=[.02d0]
 p%inventory%nfrac_biomass=.04d0;p%inventory%nfrac_humus=.02d0
 p%drybd=1300d0;p%sorption=.0002d0;p%c_top=[.002d0,.005d0]
 call initialize_soil_n_pool_state(p%inventory,[0d0],0d0,0d0,1d-5,2d-5,pool,code)
 call require(code==0,'pool init')
 call initialize_mineral(p,31_int64,0d0,.3d0,pool,s,code)
 call require(code==0,'mineral init');initial=s
 call advance_mineral_day(s,0d0,1d0,.3d0,0d0,0d0,0d0,0d0,receipt,historical_top_water=-.04d0)
 call require(receipt%status/=0,'negative input requires explicit corrected contract')
 call s%snapshot(t,w,got,revision)
 call require(t==0d0.and.revision==0.and.got%ammonium_n_kg_m2==pool%ammonium_n_kg_m2,'default rejection atomic')
 call advance_mineral_day(s,0d0,1d0,.3d0,0d0,0d0,0d0,0d0,receipt, &
      historical_top_water=-.04d0,finite_donor_top=.true.)
 call require(receipt%status==0.and.sum(receipt%top_unmet)>0d0,'finite donor accepted')
 call require(abs(receipt%external_out-3d-5)<1d-16.and.receipt%external_in==0d0,'actual output independently known')
 call require(abs(receipt%residual)<1d-15,'whole inventory')
 call s%snapshot(t,w,got,revision)
 call require(got%ammonium_n_kg_m2==0d0.and.got%nitrate_n_kg_m2==0d0,'donors exactly exhausted')
 call export_mineral_restart(s,disk,code);call require(code==0,'opaque checkpoint')
 call restore_mineral_restart(disk,31_int64,resumed,code);call require(code==0,'opaque reconstruction')
 call advance_mineral_day(s,1d0,2d0,.3d0,0d0,0d0,0d0,0d0,receipt, &
      historical_top_water=-.04d0,finite_donor_top=.true.)
 call require(receipt%status==0.and.receipt%external_out==0d0,'empty donor cannot export')
 call advance_mineral_day(resumed,1d0,2d0,.3d0,0d0,0d0,0d0,0d0,receipt, &
      historical_top_water=-.04d0,finite_donor_top=.true.)
 call require(receipt%status==0.and.receipt%external_out==0d0,'resumed empty donor')
 print '(A)','FINITE_DONOR_REFERENCE_84_OWNER_ATOMIC_OPAQUE=PASS'
contains
 subroutine require(ok,label)
  logical,intent(in)::ok
  character(*),intent(in)::label
  if(.not.ok)then
   print *,label
   error stop 1
  end if
 end subroutine
end program

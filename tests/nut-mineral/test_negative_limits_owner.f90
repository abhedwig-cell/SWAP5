program test_negative_limits_owner
 use iso_fortran_env,only:real64,int64
 use mod_b111_soil_n_mineral_owner
 use mod_soil_n_pool_state
 implicit none
 type(mineral_parameters_t)::p
 type(mineral_state_t)::s,resumed
 type(mineral_restart_t)::disk
 type(mineral_receipt_t)::r,rr
 type(soil_n_pool_state_t)::pool,got,other
 real(real64)::t,w,tr,wr,theta,delta,before
 integer::code,d,j
 integer(int64)::revision,rrv
 p%inventory%depth_m=.3d0;p%dz_cm=[30d0];p%inventory%nfrac_fom=[.02d0]
 p%inventory%nfrac_biomass=.04d0;p%inventory%nfrac_humus=.02d0
 p%drybd=1300d0;p%sorption=.0002d0;p%c_top=[.002d0,.005d0]
 do j=1,2
  call initialize_soil_n_pool_state(p%inventory,[0d0],0d0,0d0, &
   merge(1d-5,.02d0,j==1),merge(2d-5,.03d0,j==1),pool,code)
  call require(code==0,'pool initialization')
  call initialize_mineral(p,31_int64,0d0,.3d0,pool,s,code)
  call require(code==0,'owner initialization')
  theta=.3d0
  do d=0,5
   call s%snapshot(t,w,got,revision)
   before=got%ammonium_n_kg_m2+got%nitrate_n_kg_m2
   delta=merge(1d-10,-1d-10,mod(d,2)==0)
   call advance_mineral_day(s,real(d,real64),real(d+1,real64),theta+delta,0d0,0d0,0d0,0d0,r, &
    surface_water=.3d0*delta,historical_top_water=-.04d0)
   call require(r%status/=0,'default still rejects negative loading')
   call s%snapshot(tr,wr,other,rrv)
   call require(tr==t.and.wr==w.and.rrv==revision.and. &
    got%ammonium_n_kg_m2==other%ammonium_n_kg_m2.and.got%nitrate_n_kg_m2==other%nitrate_n_kg_m2, &
    'rejected default leaves inventory and clock exact')
   ! An incorrect hydraulic budget must also reject before chemical publication.
   call advance_mineral_day(s,real(d,real64),real(d+1,real64),theta+delta,0d0,0d0,0d0,0d0,r, &
    surface_water=.01d0,historical_top_water=-.04d0,finite_donor_top=.true.)
   call require(r%status/=0,'bad water budget rejects')
   call s%snapshot(tr,wr,other,rrv)
   call require(tr==t.and.wr==w.and.rrv==revision.and. &
    got%ammonium_n_kg_m2==other%ammonium_n_kg_m2.and.got%nitrate_n_kg_m2==other%nitrate_n_kg_m2, &
    'bad budget leaves inventory and clock exact')
   call export_mineral_restart(s,disk,code);call require(code==0,'checkpoint')
   call restore_mineral_restart(disk,31_int64,resumed,code);call require(code==0,'restore')
   call advance_mineral_day(s,real(d,real64),real(d+1,real64),theta+delta,0d0,0d0,0d0,0d0,r, &
    surface_water=.3d0*delta,historical_top_water=-.04d0,finite_donor_top=.true.)
   call advance_mineral_day(resumed,real(d,real64),real(d+1,real64),theta+delta,0d0,0d0,0d0,0d0,rr, &
    surface_water=.3d0*delta,historical_top_water=-.04d0,finite_donor_top=.true.)
   call require(r%status==MINERAL_OK.and.rr%status==MINERAL_OK,'near-limit owner commits')
   call require(all(r%solution_class==6),'actual new coefficient class')
   call require(all(r%concentration_end==rr%concentration_end).and. &
    all(r%concentration_average==rr%concentration_average).and.all(r%top_actual==rr%top_actual).and. &
    all(r%top_unmet==rr%top_unmet),'restored owner exact receipt')
   call s%snapshot(t,w,got,revision);call resumed%snapshot(tr,wr,other,rrv)
   call require(t==tr.and.w==wr.and.revision==rrv.and. &
    got%ammonium_n_kg_m2==other%ammonium_n_kg_m2.and.got%nitrate_n_kg_m2==other%nitrate_n_kg_m2, &
    'restored owner exact inventory')
   call require(abs(before+r%external_in-r%external_out-got%ammonium_n_kg_m2-got%nitrate_n_kg_m2)<1d-12, &
    'independent complete mineral balance')
   call require(abs(r%residual)<1d-12,'owning hard mass gate')
   if(j==1)call require(any(r%top_unmet>0d0),'low donor depletion observed')
   write(*,'(2(I0,1X),5(ES26.17E3,1X))')j,d,t,got%ammonium_n_kg_m2,got%nitrate_n_kg_m2, &
    r%external_out,r%residual
   theta=theta+delta
  end do
 end do
 print '(A)','FINITE_DONOR_LIMIT_OWNER_RESTART_ROLLBACK_BALANCE=PASS'
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

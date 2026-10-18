program test_mineral_owner
 use iso_fortran_env,only:real64,int64
 use ieee_arithmetic,only:ieee_value,ieee_quiet_nan
 use mod_b111_soil_n_mineral_owner
 use mod_soil_n_pool_state
 use mod_b111_soil_n_transport
 use MOD_texture_orgmat,only:bdens
 implicit none
 type(mineral_parameters_t)::p,bad
 type(mineral_state_t)::state,initial,restored
 type(mineral_restart_t)::restart
 type(soil_n_pool_state_t)::pools,saved,empty
 type(mineral_receipt_t)::r
 type(b111_soil_n_transport_result_t)::tr
 real(real64)::time,water,ce,ca,pa,theta1,qout,qin,root,initialc(2),sorp(2),nan
 integer(int64)::rev
 integer::status,j,i,expected(5)
 p%dz_cm=[30d0,30d0];p%inventory%depth_m=.6d0;p%inventory%nfrac_fom=[.01d0,.02d0]
 p%inventory%nfrac_biomass=.03d0;p%inventory%nfrac_humus=.04d0
 p%drybd=1300d0;p%sorption=.0002d0;p%c_bottom=[.1d0,.2d0];p%c_lateral=[.3d0,.4d0]
 call initialize_soil_n_pool_state(p%inventory,[10d0,20d0],5d0,40d0,.02d0,.03d0,pools,status)
 call check(status==0,'pool init')
 call check(.not.empty%valid(),'unallocated pool safely rejected')
 call initialize_mineral(p,9_int64,0d0,.3d0,pools,state,status)
 call check(status==0,'mineral init');initial=state
 ! Literal historical executable, all five analytical classes, with independent inputs.
 expected=[1,2,3,4,5];bdens(1)=p%drybd
 do j=1,5
   select case(j)
   case(1);theta1=.29d0;qout=.003d0;qin=0d0;root=.003d0
   case(2);theta1=.31d0;qout=0d0;qin=.006d0;root=0d0
   case(3);theta1=.3d0;qout=.006d0;qin=.006d0;root=0d0
   case(4);theta1=.29d0;qout=.006d0;qin=0d0;root=0d0
   case(5);theta1=.3d0;qout=0d0;qin=0d0;root=0d0
   end select
   call evaluate_b111_soil_n_transport(.6d0,1d0,theta1,.3d0,qout,root,qin,0d0,0d0,0d0,0d0,0d0, &
     p%drybd,p%sorption,.1d0,0d0,0d0,.05d0,tr)
   call Wofost_SoilWaterN(.6d0,1d0,theta1,.3d0,qout,root,qin,0d0,0d0,0d0,0d0,0d0,pa, &
     p%sorption,.1d0,0d0,0d0,.05d0,ce,ca)
   call check(tr%status==0.and.tr%solution_class==expected(j),'literal class')
   call near(tr%concentration_end,ce,'literal end');call near(tr%concentration_average,ca,'literal average')
 end do
 ! Owner outflow then inflow, root-water-only and organic inventories unchanged.
 initialc=[.02d0/(.6d0*(.3d0+1300d0*.0002d0)),.03d0/(.6d0*.3d0)];sorp=[p%sorption,0d0]
 call advance_mineral_day(state,0d0,1d0,.29d0,.003d0,0d0,0d0,.003d0,r)
 call check(r%status==0,'daily outflow');call near(r%residual,0d0,'whole N')
 do i=1,2
   call Wofost_SoilWaterN(.6d0,1d0,.29d0,.3d0,.003d0,.003d0,0d0,0d0,0d0,0d0,0d0,0d0,pa, &
     sorp(i),p%c_bottom(i),0d0,p%c_lateral(i),initialc(i),ce,ca)
   call near(r%concentration_end(i),ce,'owner literal end');call near(r%concentration_average(i),ca,'owner literal mean')
 end do
 call state%snapshot(time,water,saved,rev)
 call check(all(saved%fom_kg_m3==pools%fom_kg_m3).and.saved%humus_kg_m3==pools%humus_kg_m3.and. &
   saved%biomass_kg_m3==pools%biomass_kg_m3,'organic unchanged')
 call export_mineral_restart(state,restart,status);call check(status==0,'restart export')
 call restore_mineral_restart(restart,10_int64,restored,status);call check(status/=0,'wrong id')
 call restore_mineral_restart(restart,9_int64,restored,status);call check(status==0,'restore')
 call advance_mineral_day(state,1d0,2d0,.30d0,0d0,.006d0,0d0,0d0,r);call check(r%status==0,'inflow')
 call advance_mineral_day(restored,1d0,2d0,.30d0,0d0,.006d0,0d0,0d0,r);call check(r%status==0,'restored inflow')
 call compare(state,restored)
 call advance_mineral_day(state,1d0,2d0,.30d0,0d0,.006d0,0d0,0d0,r);call check(r%status/=0,'replay')
 call compare(state,restored)
 call advance_mineral_day(state,2d0,3d0,.30d0,.01d0,.01d0,0d0,0d0,r);call check(r%status/=0,'mixed directions')
 call compare(state,restored)
 call advance_mineral_day(state,2d0,3d0,.31d0,0d0,0d0,0d0,0d0,r);call check(r%status/=0,'unbooked water')
 call compare(state,restored)
 nan=ieee_value(0d0,ieee_quiet_nan)
 bad=p;bad%inventory%depth_m=nan
 call initialize_mineral(bad,9_int64,0d0,.3d0,pools,initial,status);call check(status/=0,'NaN params')
 call advance_mineral_day(state,2d0,nan,.3d0,0d0,0d0,0d0,0d0,r);call check(r%status/=0,'NaN time')
 call compare(state,restored)
 ! Signed clean surface-water extension: an explicit opt-in amount, never
 ! inferred from a failed water budget. Rain dilutes and evaporation concentrates.
 call initialize_mineral(p,9_int64,0d0,.3d0,pools,initial,status)
 call check(status==0,'clean surface initial owner')
 restored=initial
 call advance_mineral_day(initial,0d0,1d0,.31d0,0d0,0d0,0d0,0d0,r,surface_water=.006d0)
 call check(r%status==0,'clean rain water carrier')
 call initial%snapshot(time,water,saved,rev)
 call near(saved%ammonium_n_kg_m2,pools%ammonium_n_kg_m2,'rain no dissolved NH4 input')
 call near(saved%nitrate_n_kg_m2,pools%nitrate_n_kg_m2,'rain no dissolved NO3 input')
 call advance_mineral_day(initial,1d0,2d0,.3d0,0d0,0d0,0d0,0d0,r,surface_water=-.006d0)
 call check(r%status==0,'evaporation excludes advective N removal')
 call initial%snapshot(time,water,saved,rev)
 call near(saved%ammonium_n_kg_m2,pools%ammonium_n_kg_m2,'evaporation NH4 conservation')
 call near(saved%nitrate_n_kg_m2,pools%nitrate_n_kg_m2,'evaporation NO3 conservation')
 state=initial
 call advance_mineral_day(initial,2d0,3d0,.31d0,0d0,0d0,0d0,0d0,r,surface_water=-.006d0)
 call check(r%status/=0,'wrong signed surface flux rejected')
 call compare(state,initial)
 call advance_mineral_day(initial,2d0,3d0,.3d0,0d0,0d0,0d0,0d0,r,surface_water=nan)
 call check(r%status/=0,'NaN surface flux rejected')
 call compare(state,initial)
 print '(A)','MINERAL_FOUR_PROVIDER_LITERAL_ALL_CLASSES_OWNER_BALANCE_ROLLBACK_RESTART=PASS'
contains
 subroutine compare(a,b)
 type(mineral_state_t),intent(in)::a,b
 type(soil_n_pool_state_t)::x,y
 real(real64)::t,w,u,v
 integer(int64)::ra,rb
 call a%snapshot(t,w,x,ra);call b%snapshot(u,v,y,rb)
 call check(t==u.and.w==v.and.ra==rb.and.x%ammonium_n_kg_m2==y%ammonium_n_kg_m2.and. &
    x%nitrate_n_kg_m2==y%nitrate_n_kg_m2,'rollback/restart exact')
 end subroutine
 subroutine near(a,b,label)
 real(real64),intent(in)::a,b
 character(*),intent(in)::label
 call check(abs(a-b)<=1d-12*max(1d0,abs(a),abs(b)),label)
 end subroutine
 subroutine check(ok,label)
 logical,intent(in)::ok
 character(*),intent(in)::label
 if(.not.ok)then;print *,label;error stop 1;end if
 end subroutine
end program

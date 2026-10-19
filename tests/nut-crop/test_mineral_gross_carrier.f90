program test_mineral_gross_carrier
 use iso_fortran_env,only:real64,int64
 use mod_b111_soil_n_mineral_owner
 use mod_soil_n_pool_state
 use MOD_texture_orgmat,only:bdens
 implicit none
 type(mineral_parameters_t)::p
 type(mineral_state_t)::s
 type(soil_n_pool_state_t)::pools,after
 type(mineral_receipt_t)::r
 real(real64)::clock,water,rain,ce,ca,prod,c0,old
 integer::code,j
 integer(int64)::revision
 p%dz_cm=[30d0]
 p%inventory%depth_m=.3d0
 p%inventory%nfrac_fom=[.01d0]
 p%inventory%nfrac_biomass=.03d0
 p%inventory%nfrac_humus=.04d0
 p%drybd=1300d0
 bdens(1)=p%drybd
 p%sorption=0d0
 p%c_top=[.005d0,.015d0]
 call initialize_soil_n_pool_state(p%inventory,[0d0],0d0,0d0,.002d0,.003d0,pools,code)
 if(code/=0)error stop 'init'
 do j=0,2
   rain=.004d0*j
   call initialize_mineral(p,9_int64,0d0,.3d0,pools,s,code)
   if(code/=MINERAL_OK)error stop 'mineral init'
   call advance_mineral_day(s,0d0,1d0,.3d0,0d0,0d0,0d0,0d0,r, &
       surface_water=0d0,gross_surface_n_carrier=rain)
   if(r%status/=MINERAL_OK)error stop 'gross surface N owner'
   if(abs(r%external_in-rain*sum(p%c_top))>1d-12)error stop 'gross N input ledger'
   call s%snapshot(clock,water,after,revision)
   if(abs(after%ammonium_n_kg_m2-.002d0-rain*p%c_top(1))>1d-12)error stop 'NH4 gross'
   if(abs(after%nitrate_n_kg_m2-.003d0-rain*p%c_top(2))>1d-12)error stop 'NO3 gross'
   if(abs(water-.3d0)>1d-12.or.revision/=1_int64)error stop 'hydraulic water changed'
   if(abs(r%residual)>1d-12)error stop 'total N closure'
   ! Literal historical source checks the analytical endpoint independently.
   old=pools%ammonium_n_kg_m2
   c0=old/(.3d0*.3d0)
   call Wofost_SoilWaterN(.3d0,1d0,.3d0,.3d0,0d0,0d0,0d0,rain,0d0, &
     0d0,0d0,0d0,prod,0d0,0d0,p%c_top(1),0d0,c0,ce,ca)
   if(abs(ce*.09d0-after%ammonium_n_kg_m2)>1d-12)error stop 'literal original NH4'
   old=pools%nitrate_n_kg_m2
   c0=old/(.3d0*.3d0)
   call Wofost_SoilWaterN(.3d0,1d0,.3d0,.3d0,0d0,0d0,0d0,rain,0d0, &
     0d0,0d0,0d0,prod,0d0,0d0,p%c_top(2),0d0,c0,ce,ca)
   if(abs(ce*.09d0-after%nitrate_n_kg_m2)>1d-12)error stop 'literal original NO3'
 end do
 call initialize_mineral(p,9_int64,0d0,.3d0,pools,s,code)
 call advance_mineral_day(s,0d0,1d0,.3d0,0d0,0d0,0d0,0d0,r, &
     surface_water=0d0,gross_surface_n_carrier=-.004d0)
 if(r%status==MINERAL_OK)error stop 'negative gross N accepted'
 call s%snapshot(clock,water,after,revision)
 if(revision/=0_int64.or.clock/=0d0)error stop 'failed gross changed commit'
 print '(A)','MC_NUT01_MINERAL_GROSS_SOURCE_O0_O2=PASS'
end program

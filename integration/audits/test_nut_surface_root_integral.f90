program surface_root_integral
 use iso_fortran_env,only:real64,int64
 use mod_b111_soil_n_mineral_owner
 use mod_soil_n_pool_state
 use mod_fmr_b111_mineral_route
 use mod_fmr_serialized_reference_backend,only:fmr_water_flux_substep_trace_t
 implicit none
 type(mineral_parameters_t)::p
 type(mineral_state_t)::state
 type(soil_n_pool_state_t)::pool
 type(mineral_daily_carrier_t)::c
 type(fmr_water_flux_substep_trace_t),allocatable::steps(:)
 integer::code,i,n,mode,k
 integer,parameter::counts(3)=[1000,2048,4096]
 real(real64)::naive,expected,dt
 p%dz_cm=[30d0];p%inventory%depth_m=.3d0;p%inventory%nfrac_fom=[.01d0]
 p%inventory%nfrac_biomass=.03d0;p%inventory%nfrac_humus=.04d0
 p%drybd=1300d0;p%sorption=.0002d0
 call initialize_soil_n_pool_state(p%inventory,[1d0],5d0,40d0,.02d0,.03d0,pool,code)
 call require(code==0,'pool')
 do k=1,3
  n=counts(k)
  allocate(steps(n));naive=0d0
  do i=1,n
   steps(i)%t0=363d0+real(i-1,real64)/n;steps(i)%t1=363d0+real(i,real64)/n
   steps(i)%top_flux=0d0;steps(i)%bottom_flux=.08d0
   steps(i)%water_start=[.3d0];steps(i)%water_end=[.3d0]
   steps(i)%root_sink=[.08d0];steps(i)%net_node_source=[-.08d0]
   allocate(steps(i)%drainage_sink_by_level(1,1));steps(i)%drainage_sink_by_level=0d0
   dt=steps(i)%t1-steps(i)%t0;naive=naive+dt*.08d0*.01d0
  end do
  do mode=0,1
   p%surface_n_enabled=mode==1
   call initialize_mineral(p,1_int64,363d0,.3d0,pool,state,code);call require(code==0,'initialize')
   call aggregate_mineral_trace(state,steps,c,code);call require(code==0,'real trace aggregation')
   if(mode==0)then
    call require(c%root_water==naive,'default accumulation bytes unchanged')
   else
    expected=.08d0*.01d0
    call require(abs(c%root_water-expected)<=4d0*epsilon(1d0)*expected,'accepted integral matches independent constant flux')
    call require(abs(100d0*c%root_water-.08d0)<=8d0*epsilon(1d0)*.08d0,'existing crop eight-unit equality envelope')
   endif
  enddo
  print *,'ROOT_INTEGRAL',n,naive-expected,c%root_water-expected
  deallocate(steps)
 enddo
 print '(A)','SURFACE_ROOT_ACCEPTED_INTEGRAL_AND_DEFAULT_IDENTITY=PASS'
contains
 subroutine require(ok,label)
  logical,intent(in)::ok
  character(*),intent(in)::label
  if(.not.ok)then
   print *,label;error stop 1
  endif
 end subroutine
end program

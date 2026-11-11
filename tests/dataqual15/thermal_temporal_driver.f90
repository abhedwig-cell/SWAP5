program thermal_temporal_contract
 use iso_fortran_env,only:real64
 use ieee_arithmetic,only:ieee_value,ieee_quiet_nan
 use mod_fmr_serialized_reference_backend,only:evaluate_fmr_thermal_temporal_error, &
  fmr_serialized_reference_backend_t,fmr_b110_physical_state_t,distribute_fmr_scalar_drainage
 use mod_fixed_flux_top_boundary_provider,only:fixed_flux_top_boundary_provider_t
 use mod_soil_temperature_contract,only:initialize_soil_temperature_state,copy_soil_temperature_profile
 use mod_drainage_spatial_distribution,only:drainage_distribution_parameters_t,drainage_node_transfer_t, &
  drainage_distribution_diagnostics_t,distribute_single_level_signed_divdra,DRAIN_DIST_OK, &
  DRAIN_DIST_TRANSFER_BELOW_ADMITTED_MAGNITUDE
 use mod_process_hydraulic_view,only:process_hydraulic_view_t
 implicit none
 real(real64)::thermal_tolerance,water_tolerance
 type(fmr_serialized_reference_backend_t)::backend
 type(fixed_flux_top_boundary_provider_t),target::top
 type(fmr_b110_physical_state_t)::full,half
 real(real64),allocatable::before(:),after(:)
 real(real64)::water,error,nan
 integer::code
 logical::ok
 nan=ieee_value(0d0,ieee_quiet_nan)
 call backend%configure_soil_temperature_temporal_tolerance(1d-5,ok)
 call check(.not.ok,'requires initialized instance')
 call backend%initialize(top)
 call backend%configure_soil_temperature_temporal_tolerance(-1d-5,ok)
 call check(.not.ok,'negative rejected')
 call backend%configure_soil_temperature_temporal_tolerance(nan,ok)
 call check(.not.ok,'nonfinite rejected without trap')
 call backend%configure_soil_temperature_temporal_tolerance(1d-5,ok)
 call check(ok,'explicit configuration')
 call check(backend%soil_temperature_substep_count()==1,'default one heat step')
 call backend%configure_soil_temperature_temporal_tolerance(1d-5,ok,4)
 call check(ok.and.backend%soil_temperature_substep_count()==4,'explicit four heat steps')
 call backend%configure_soil_temperature_temporal_tolerance(1d-5,ok,2)
 call check(.not.ok.and.backend%soil_temperature_substep_count()==4,'invalid count atomic')
 call backend%configure_soil_temperature_temporal_tolerance(0d0,ok,4)
 call check(.not.ok.and.backend%soil_temperature_substep_count()==4,'four requires positive thermal budget')
 call backend%configure_soil_temperature_temporal_tolerance(1d-5,ok,16)
 call check(ok.and.backend%soil_temperature_substep_count()==16,'explicit sixteen heat steps')
 call backend%configure_soil_temperature_temporal_tolerance(0d0,ok,16)
 call check(.not.ok.and.backend%soil_temperature_substep_count()==16,'sixteen positive budget atomic')
 call backend%configure_soil_temperature_temporal_tolerance(1d-5,ok,8)
 call check(.not.ok.and.backend%soil_temperature_substep_count()==16,'unsupported count leaves sixteen')
 call backend%initialize(top)
 call check(backend%soil_temperature_substep_count()==1,'reinitialization restores one step')
 call backend%configure_soil_temperature_temporal_tolerance(0d0,ok)
 call check(ok,'explicit disabled compatibility')
 thermal_tolerance=0d0;water_tolerance=1d-4
 full%active_nodes=2;allocate(full%pressure_head(2),full%water_content(2),full%soil_temperature)
 full%pressure_head=-10d0;full%water_content=.3d0
 call initialize_soil_temperature_state([10d0,11d0],full%soil_temperature,code)
 call check(code==0,'real thermal state')
 half=full
 call initialize_soil_temperature_state([10d0+4d-5,11d0],half%soil_temperature,code)
 water=evaluate_fmr_thermal_temporal_error(full,half,0d0,water_tolerance,thermal_tolerance)
 call check(water==0d0,'incumbent ignores temperature, unchanged')
 call copy_soil_temperature_profile(half%soil_temperature,before,code)
 thermal_tolerance=1d-5
 error=evaluate_fmr_thermal_temporal_error(full,half,0d0,water_tolerance,thermal_tolerance)
 call check(abs(error-4d-4)<2d-14,'thermal-only rejection and normalized ratio')
 call check(evaluate_fmr_thermal_temporal_error(full,half,0d0,1d-4,0d0)==0d0,'disabled instance unaffected')
 call initialize_soil_temperature_state([10d0+2d-6,11d0],half%soil_temperature,code)
 call check(abs(evaluate_fmr_thermal_temporal_error(full,half,0d0,water_tolerance,thermal_tolerance)-2d-5)<2d-14,'subthreshold candidate accepted')
 water=.1d0
 call check(evaluate_fmr_thermal_temporal_error(full,half,water,water_tolerance,thermal_tolerance)==water, &
  'existing water indicator cannot be weakened')
 deallocate(half%soil_temperature)
 call check(evaluate_fmr_thermal_temporal_error(full,half,0d0,water_tolerance,thermal_tolerance)>1d100,'missing thermal state fails closed')
 allocate(half%soil_temperature)
 call initialize_soil_temperature_state([10d0,11d0,12d0],half%soil_temperature,code)
 call check(evaluate_fmr_thermal_temporal_error(full,half,0d0,water_tolerance,thermal_tolerance)>1d100,'node mismatch fails closed')
 call initialize_soil_temperature_state([10d0,11d0],half%soil_temperature,code)
 thermal_tolerance=nan
 call check(evaluate_fmr_thermal_temporal_error(full,half,0d0,water_tolerance,thermal_tolerance)>1d100,'invalid direct policy fails closed')
 thermal_tolerance=1d-5
 water_tolerance=nan
 call check(evaluate_fmr_thermal_temporal_error(full,half,0d0,water_tolerance,thermal_tolerance)>1d100,'invalid scaling fails closed')
 call copy_soil_temperature_profile(full%soil_temperature,after,code)
 call check(all(after==[10d0,11d0]),'candidate assessment never mutates full state')
 call test_tiny_drainage()
 print '(a)','THERMAL_TEMPORAL_REAL_BACKEND_CONTRACT_PASS'
contains
 subroutine test_tiny_drainage()
  type(drainage_distribution_parameters_t)::p
  type(process_hydraulic_view_t)::view
  type(drainage_node_transfer_t)::legacy,unit,actual
  type(drainage_distribution_diagnostics_t)::d,du,da
  real(real64)::q,levels(3),scalars(6)
  integer::i,j
  p%active_nodes=4;p%dz=[2d0,4d0,6d0,8d0];p%zbotcp=[-2d0,-6d0,-12d0,-20d0]
  p%saturated_conductivity=[1d0,2d0,4d0,8d0];p%horizontal_anisotropy_factor=[1d0,1d0,1d0,1d0];p%drain_spacing=100d0
  view%active_nodes=4;view%pressure_head=[-3d0,0d0,5d0,13d0];view%water_content=[.3d0,.3d0,.3d0,.3d0]
  levels=[-5d0,-6d0-5d-11,-6d0+5d-11];scalars=[1d-11,-1d-11,1d-18,-1d-18,1d-25,-1d-25]
  do i=1,3
   view%groundwater_level=levels(i)
   do j=1,6
    q=scalars(j)
    call distribute_single_level_signed_divdra(p,view,q,legacy,d)
    call check(d%status==DRAIN_DIST_TRANSFER_BELOW_ADMITTED_MAGNITUDE,'legacy small-transfer contract retained')
    call distribute_fmr_scalar_drainage(p,view,q,actual,da,.false.)
    call check(da%status==d%status,'default policy does not extend legacy domain')
    call distribute_single_level_signed_divdra(p,view,sign(1d0,q),unit,du)
    call check(du%status==DRAIN_DIST_OK,'unit geometry valid including legacy edge seam')
    call distribute_fmr_scalar_drainage(p,view,q,actual,da,.true.)
    call check(da%status==DRAIN_DIST_OK.and.da%evaluated.and..not.da%zero_transfer,'explicit extension keeps nonzero flux')
    call check(abs(sum(actual%soil_to_drain_rate)-q)<=8d0*epsilon(q)*abs(q),'authoritative signed scalar exactly conserved')
    call check(maxval(abs(actual%soil_to_drain_rate-abs(q)*unit%soil_to_drain_rate))<=8d0*epsilon(q)*abs(q), &
      'same original DIVDRA geometry, no clipping')
   end do
   q=1d-8
   call distribute_single_level_signed_divdra(p,view,q,legacy,d)
   call distribute_fmr_scalar_drainage(p,view,q,actual,da,.true.)
   call check(da%status==d%status.and.all(actual%soil_to_drain_rate==legacy%soil_to_drain_rate),'admitted domain bit exact')
  end do
 end subroutine test_tiny_drainage
 subroutine check(yes,label)
  logical,intent(in)::yes
  character(*),intent(in)::label
  if(.not.yes)then
   print *,label;error stop 1
  end if
 end subroutine
end program

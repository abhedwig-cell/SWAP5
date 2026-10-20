program test_historical_atmosphere_trace
 use iso_fortran_env,only:real64
 use ieee_arithmetic,only:ieee_value,ieee_quiet_nan
 use mod_fmr_serialized_reference_backend,only:fmr_water_flux_substep_trace_t
 use mod_fmr_crop_soil_n_joint_application,only:historical_crop_soil_top_from_trace
 implicit none
 type(fmr_water_flux_substep_trace_t)::base(2),bad(2)
 real(real64)::top,nan
 integer::i,status
 nan=ieee_value(0d0,ieee_quiet_nan)
 do i=1,2
  base(i)%t0=10d0+real(i-1,real64)*.5d0;base(i)%t1=base(i)%t0+.5d0
  base(i)%pond_storage_available=.true.
  base(i)%converged_surface_available=.true.
  base(i)%converged_gross_sources_available=.true.
  base(i)%converged_rain_rate_cm_day=.4d0
  base(i)%converged_irrigation_rate_cm_day=.1d0
  base(i)%converged_runon_rate_cm_day=.05d0
  base(i)%converged_runoff_depth_cm=.02d0
 end do
 call historical_crop_soil_top_from_trace(base,10d0,11d0,top,status)
 if(status/=0.or.abs(top-.0051d0)>1d-17)error stop 'source integration or units'
 ! Evaporation/top_flux are independent: they must never enter gross N.
 base%top_flux=1d0;base%converged_pond_evaporation_cm_day=1d0
 call historical_crop_soil_top_from_trace(base,10d0,11d0,top,status)
 if(status/=0.or.abs(top-.0051d0)>1d-17)error stop 'net/gross confusion'
 do i=1,18
  bad=base
  select case(i)
  case(1);bad(1)%pond_storage_available=.false.
  case(2);bad(1)%converged_surface_available=.false.
  case(3);bad(1)%converged_gross_sources_available=.false.
  case(4);bad(1)%converged_rain_rate_cm_day=nan
  case(5);bad(1)%converged_irrigation_rate_cm_day=-.1d0
  case(6);bad(1)%converged_runon_rate_cm_day=1d5
  case(7);bad(1)%converged_runoff_depth_cm=1d0
  case(8);bad(1)%converged_snowmelt_rate_cm_day=.01d0
  case(9);bad(1)%pond_start_cm=.01d0
  case(10);bad(1)%pond_end_cm=.01d0
  case(11);bad(1)%pond_end_cm=nan
  case(12);bad(2)%t0=10.6d0
  case(13);bad(2)%t0=10.4d0
  case(14);bad(2)%t1=12d0
  case(15);bad(2)%t1=10.5d0
  case(16);bad(1)%t0=nan
  case(17);bad(2)%t1=10.9d0
  case(18);bad(1)%converged_runoff_depth_cm=-.01d0
  end select
  call historical_crop_soil_top_from_trace(bad,10d0,11d0,top,status)
  if(status==0.or.top/=0d0)error stop 'invalid trace accepted'
 end do
 call historical_crop_soil_top_from_trace(base(:0),10d0,11d0,top,status)
 if(status==0)error stop 'empty trace accepted'
 call historical_crop_soil_top_from_trace(base,10d0,10.5d0,top,status)
 if(status==0)error stop 'partial day accepted'
 call historical_crop_soil_top_from_trace(base,nan,11d0,top,status)
 if(status==0)error stop 'nonfinite clock accepted'
 print '(A)','HISTORICAL_ATMOSPHERE_TRACE_21_INVALID_AND_GROSS_UNITS=PASS'
end program

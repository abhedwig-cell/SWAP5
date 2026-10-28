program test_surface_conductivity
 use iso_fortran_env,only:real64,real128
 use ieee_arithmetic,only:ieee_value,ieee_quiet_nan
 use mod_soil_water_solver_contract
 use mod_b110_default_mvg_provider
 use mod_b110_dynamic_top_boundary_solver_adapter
 implicit none
 type(soil_water_parameter_set_t),target::g
 type(b110_default_mvg_parameters_t),target::hp
 type(b110_dynamic_top_boundary_solver_provider_t)::p,ref
 type(soil_water_boundary_conditions_t)::b
 type(soil_water_top_boundary_result_t)::r,s
 real(real64)::c(24,1),a,d,k,err,maxerr,delta
 real(real128)::oracle
 real(real64),parameter::areas(9)=[0d0,1d-6,1d-4,.001d0,.003d0,.01d0,.03d0,.1d0,.6d0], &
  diameters(3)=[.1d0,1d0,10d0],exponents(3)=[.5d0,1d0,2d0]
 integer::ia,id,ie,it,n,negative
 character(16)::mode
 call get_command_argument(1,mode)
 g%active_nodes=1;g%dz=[1d0];g%node_distance=[.5d0]
 c=0d0;c(1,1)=.05d0;c(2,1)=.45d0;c(3,1)=1d0;c(4,1)=.02d0;c(5,1)=.5d0;c(6,1)=1.6d0;c(7,1)=1d0-1d0/1.6d0
 c(8,1)=.02d0;c(9,1)=0d0;c(10,1)=1d0;c(11,1)=.999d0;c(12,1)=.99d0;c(22,1)=-1d6;c(23,1)=1d-12
 call initialize_b110_default_mvg_parameters(hp,c)
 maxerr=0d0;n=0
 do ia=1,size(areas)
 do id=1,size(diameters)
 do ie=1,size(exponents)
 do it=1,2
 a=areas(ia);d=diameters(id)
 call bind_b110_dynamic_top_boundary_solver_provider(p,g,hp,1,1d0,.01d0*it,2d0,0d0,0d0,0d0,0d0,0d0, &
  .01d0,.01d0,exponents(ie),.1d0)
 p%macropore_pond_donor_active=.true.;p%matrix_source_area_partition=.true.
 p%macropore_pond_threshold=.001d0;p%macropore_surface_conductivity=1000d0
 b%macropore_surface_area_fraction=a
 ref=p
 k=min(max(2d0*7.2d8*(d*(1d0-sqrt(1d0-a)))**3/d,1d-14),1000d0)
 oracle=min(max(2.0_real128*7.2e8_real128*real(d,real128)**2* &
  (1.0_real128-sqrt(1.0_real128-real(a,real128)))**3,1e-14_real128),1000.0_real128)
 if(abs(k-real(oracle,real64))>2d-9*max(k,1d-14))error stop 'independent conductivity oracle'
 if(trim(mode)/='disabled')then
 p%source_surface_diameter_cm=d
 ref%macropore_surface_conductivity=k
 end if
 call p%evaluate(-.1d0,.4d0,1d0,b,r);call ref%evaluate(-.1d0,.4d0,1d0,b,s)
 if(r%status/=SW_TOP_BOUNDARY_AVAILABLE.or.s%status/=SW_TOP_BOUNDARY_AVAILABLE)error stop 'adapter unavailable'
 if(r%actual_top_flux/=s%actual_top_flux.or.r%candidate_ponding_depth/=s%candidate_ponding_depth.or. &
  r%macropore_pond_requested_lateral_cm/=s%macropore_pond_requested_lateral_cm)error stop 'source law adapter disagreement'
 err=abs(r%candidate_ponding_depth-1d0-.01d0*it*(r%net_potential_surface_flux+r%actual_top_flux)+r%runoff_depth)
 maxerr=max(maxerr,err);if(err>2d-12)error stop 'coupled surface conservation'
 n=n+1
 if(trim(mode)=='disabled')write(*,'(4es26.17)')r%actual_top_flux,r%candidate_ponding_depth,r%runoff_depth,r%macropore_pond_requested_lateral_cm
 end do
 end do
 end do
 end do
 if(trim(mode)=='disabled')stop
 negative=0
 p%source_surface_diameter_cm=-1d0
 call p%evaluate(-.1d0,.4d0,1d0,b,r);if(r%status/=SW_TOP_BOUNDARY_UNAVAILABLE)error stop 'negative diameter';negative=negative+1
 p%source_surface_diameter_cm=ieee_value(0d0,ieee_quiet_nan)
 call p%evaluate(-.1d0,.4d0,1d0,b,r);if(r%status/=SW_TOP_BOUNDARY_UNAVAILABLE)error stop 'nan diameter';negative=negative+1
 p%source_surface_diameter_cm=1d0;b%macropore_surface_area_fraction=-1d0
 call p%evaluate(-.1d0,.4d0,1d0,b,r);if(r%status/=SW_TOP_BOUNDARY_UNAVAILABLE)error stop 'missing area';negative=negative+1
 b%macropore_surface_area_fraction=.7d0
 call p%evaluate(-.1d0,.4d0,1d0,b,r);if(r%status/=SW_TOP_BOUNDARY_UNAVAILABLE)error stop 'invalid area';negative=negative+1
 write(*,'(a,i0,a,i0,es26.17)')'SURFACE_CONDUCTIVITY_PASS ',n,' NEGATIVE ',negative,maxerr
end program

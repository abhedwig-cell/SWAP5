program test_surface_conductivity
 use iso_fortran_env,only:real64
 use ieee_arithmetic,only:ieee_value,ieee_quiet_nan
 use mod_soil_water_solver_contract,only:soil_water_parameter_set_t,soil_water_boundary_conditions_t, &
  soil_water_top_boundary_result_t,SW_TOP_BOUNDARY_AVAILABLE
 use mod_b110_default_mvg_provider,only:b110_default_mvg_parameters_t,initialize_b110_default_mvg_parameters
 use mod_b110_dynamic_top_boundary_provider
 use mod_b110_dynamic_top_boundary_solver_adapter
 implicit none
 type(soil_water_parameter_set_t),target::g
 type(b110_default_mvg_parameters_t),target::hp
 type(b110_dynamic_top_boundary_request_t)::q,qfixed,qp,qm
 type(b110_dynamic_top_boundary_result_t)::r,f,rp,rm
 type(b110_dynamic_top_boundary_solver_provider_t)::adapter
 type(soil_water_boundary_conditions_t)::bc
 type(soil_water_top_boundary_result_t)::ar,ap,am
 real(real64)::c(24,1),k,expected,area,diameter,fd,delta,balance,maxbalance,maxfd,nan
 real(real64),parameter::areas(7)=[0d0,1d-8,1d-5,.001d0,.01d0,.1d0,.6d0], &
  diameters(5)=[.001d0,1d0,5d0,20d0,100d0],steps(3)=[1d-5,.01d0,.2d0]
 integer::ia,id,it,ie,ih,n
 logical::ok
 g%active_nodes=1;g%dz=[1d0];g%node_distance=[.5d0]
 c=0d0;c(1,1)=.05d0;c(2,1)=.45d0;c(3,1)=1d0;c(4,1)=.02d0;c(5,1)=.5d0;c(6,1)=1.6d0;c(7,1)=1d0-1d0/1.6d0
 c(8,1)=.02d0;c(9,1)=0d0;c(10,1)=1d0;c(11,1)=.999d0;c(12,1)=.99d0;c(22,1)=-1d6;c(23,1)=1d-12
 call initialize_b110_default_mvg_parameters(hp,c)
 n=0;maxbalance=0d0;maxfd=0d0;delta=1d-5
 do ia=1,size(areas)
 do id=1,size(diameters)
  area=areas(ia);diameter=diameters(id)
  ! Literal assignment from archived original MPVOLUME(case1), no new approximation.
  expected=2d0*7.2d8*(diameter*(1d0-sqrt(1d0-area)))**3/diameter
  expected=min(max(expected,1d-14),1d3)
  call evaluate_source_macropore_surface_conductivity(area,diameter,k,ok)
  if(.not.ok.or.k/=expected)error stop 'source law'
 do it=1,3
 do ie=1,3
 do ih=1,3
  q=b110_dynamic_top_boundary_request_t()
  q%conductivity_mean_method=1;q%pressure_head_top_cm=-.1d0*ih;q%water_content_top=.4d0
  q%previous_ponding_depth_cm=1d0;q%step_duration_day=steps(it);q%precipitation_rate_cm_per_day=2d0
  q%ponding_max_cm=.05d0;q%runoff_resistance_day=.01d0;q%runoff_exponent=1d0
  if(ie==1)q%runoff_exponent=.5d0
  if(ie==2)q%runoff_exponent=1d0
  if(ie==3)q%runoff_exponent=2d0
  q%fixed_top_node_conductivity_cm_per_day=.1d0
  q%macropore_surface_area_fraction=area;q%matrix_source_area_partition=.true.
  q%macropore_pond_donor_active=.true.;q%macropore_pond_threshold_cm=.01d0
  q%macropore_surface_conductivity_cm_per_day=1000d0;q%macropore_polygon_diameter_cm=diameter
  call evaluate_b110_dynamic_top_boundary(g,hp,q,r)
  if(r%status/=B110_DYN_TOP_AVAILABLE)error stop 'variable boundary unavailable'
  qfixed=q;qfixed%macropore_polygon_diameter_cm=0d0;qfixed%macropore_surface_conductivity_cm_per_day=expected
  call evaluate_b110_dynamic_top_boundary(g,hp,qfixed,f)
  if(f%status/=r%status.or.f%actual_top_flux_cm_per_day/=r%actual_top_flux_cm_per_day.or. &
   f%macropore_pond_requested_lateral_cm/=r%macropore_pond_requested_lateral_cm.or. &
   f%candidate_ponding_depth_cm/=r%candidate_ponding_depth_cm.or.f%runoff_depth_cm/=r%runoff_depth_cm)error stop 'fixed oracle'
  balance=abs(r%candidate_ponding_depth_cm-q%previous_ponding_depth_cm-q%step_duration_day* &
   (r%net_potential_surface_flux_cm_per_day+r%actual_top_flux_cm_per_day)+r%runoff_depth_cm)
  maxbalance=max(maxbalance,balance)
  if(balance>2d-13)error stop 'surface balance'
  qp=q;qm=q;qp%pressure_head_top_cm=q%pressure_head_top_cm+delta;qm%pressure_head_top_cm=q%pressure_head_top_cm-delta
  call evaluate_b110_dynamic_top_boundary(g,hp,qp,rp);call evaluate_b110_dynamic_top_boundary(g,hp,qm,rm)
  fd=(rp%surface_head_cm-rm%surface_head_cm)/(2*delta)
  maxfd=max(maxfd,abs(fd-r%surface_head_dpressure_head_top))
  if(abs(fd-r%surface_head_dpressure_head_top)>5d-10)error stop 'head derivative'
  call bind_b110_dynamic_top_boundary_solver_provider(adapter,g,hp,1,1d0,steps(it),2d0,0d0,0d0,0d0, &
   0d0,0d0,.05d0,.01d0,q%runoff_exponent,.1d0,.01d0,1000d0)
  adapter%macropore_polygon_diameter=diameter;adapter%matrix_source_area_partition=.true.
  bc%macropore_surface_area_fraction=area
  call adapter%evaluate(q%pressure_head_top_cm,.4d0,0d0,bc,ar)
  if(ar%status/=SW_TOP_BOUNDARY_AVAILABLE.or.ar%actual_top_flux/=r%actual_top_flux_cm_per_day)error stop 'adapter'
  n=n+1
 end do
 end do
 end do
 end do
 end do
 nan=ieee_value(0d0,ieee_quiet_nan)
 call evaluate_source_macropore_surface_conductivity(nan,1d0,k,ok)
 if(ok)error stop 'NaN area'
 call evaluate_source_macropore_surface_conductivity(.61d0,1d0,k,ok)
 if(ok)error stop 'area bound'
 call evaluate_source_macropore_surface_conductivity(.1d0,0d0,k,ok)
 if(ok)error stop 'diameter bound'
 q%macropore_polygon_diameter_cm=nan
 call evaluate_b110_dynamic_top_boundary(g,hp,q,r)
 if(r%status==B110_DYN_TOP_AVAILABLE)error stop 'NaN request'
 print '(a,i0,2es25.16)','SURFACE_CONDUCTIVITY_PASS ',n,maxbalance,maxfd
end program

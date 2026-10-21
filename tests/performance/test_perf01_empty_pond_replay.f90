program test_perf01_empty_pond_replay
 use iso_fortran_env,only:real64
 use mod_soil_water_solver_contract,only:soil_water_parameter_set_t
 use mod_b110_default_mvg_provider,only:b110_default_mvg_parameters_t,initialize_b110_default_mvg_parameters, &
   evaluate_b110_default_mvg_conductivity
 use mod_b110_dynamic_top_boundary_provider,only:old_request=>b110_dynamic_top_boundary_request_t, &
   old_result=>b110_dynamic_top_boundary_result_t,old_evaluate=>evaluate_b110_dynamic_top_boundary
 use mod_perf01_candidate_surface_boundary,only:new_request=>b110_dynamic_top_boundary_request_t, &
   new_result=>b110_dynamic_top_boundary_result_t,new_evaluate=>evaluate_b110_dynamic_top_boundary
 implicit none
 type(soil_water_parameter_set_t)::geometry
 type(b110_default_mvg_parameters_t)::hydraulics
 type(old_request)::a
 type(new_request)::b
 type(old_result)::of,oh1,oh2
 type(new_result)::nf,nh1,nh2
 real(real64)::cof(24,1),ktop,ksat,face,capacity,dt,head,amount,old_spread,delta
 logical::ok
 integer::j,k,observations
 real(real64),parameter::steps(3)=[1d-2,1d-5,1d-8]
 real(real64),parameter::capacities(5)=[.9d0,.95d0,.975d0,1d0,1.05d0]
 cof=0d0;cof(1,:)=.032d0;cof(2,:)=.423d0;cof(3,:)=.00475d0
 cof(4,:)=.0135d0;cof(5,:)=.365d0;cof(6,:)=1.455d0;cof(7,:)=1d0-1d0/1.455d0
 cof(8,:)=.0135d0;cof(10,:)=.00475d0;cof(11,:)=.999d0;cof(12,:)=.99d0*.00475d0
 cof(22,:)=-1d6;cof(23,:)=1d-12
 call initialize_b110_default_mvg_parameters(hydraulics,cof)
 geometry%active_nodes=1;geometry%dz=[.5d0];geometry%node_distance=[.25d0]
 call evaluate_b110_default_mvg_conductivity(hydraulics,1,-103.0958d0,ktop,ok)
 if(.not.ok)error stop 'initial K'
 call evaluate_b110_default_mvg_conductivity(hydraulics,1,0d0,ksat,ok)
 if(.not.ok)error stop 'saturated K'
 face=.5d0*(ktop+ksat)
 observations=0;old_spread=0d0
 do k=1,size(capacities)
  capacity=capacities(k);head=.25d0*(1d0-capacity/face)
  do j=1,size(steps)
   dt=steps(j)
   a=old_request();b=new_request()
   a%conductivity_mean_method=1;b%conductivity_mean_method=1
   a%pressure_head_top_cm=head;b%pressure_head_top_cm=head
   a%water_content_top=.32d0;b%water_content_top=.32d0
   a%step_duration_day=dt;b%step_duration_day=dt
   a%runon_rate_cm_per_day=1d0;b%runon_rate_cm_per_day=1d0
   a%potential_pond_evaporation_cm_per_day=.05d0;b%potential_pond_evaporation_cm_per_day=.05d0
   a%ponding_max_cm=.50001d0;b%ponding_max_cm=.50001d0
   a%runoff_resistance_day=.001d0;b%runoff_resistance_day=.001d0
   a%fixed_top_node_conductivity_cm_per_day=ktop;b%fixed_top_node_conductivity_cm_per_day=ktop
   call old_evaluate(geometry,hydraulics,a,of)
   call new_evaluate(geometry,hydraulics,b,nf)
   call check_surface(b,nf)
   a%step_duration_day=.5d0*dt;b%step_duration_day=.5d0*dt
   call old_evaluate(geometry,hydraulics,a,oh1)
   call new_evaluate(geometry,hydraulics,b,nh1)
   call check_surface(b,nh1)
   a%previous_ponding_depth_cm=oh1%candidate_ponding_depth_cm
   b%previous_ponding_depth_cm=nh1%candidate_ponding_depth_cm
   call old_evaluate(geometry,hydraulics,a,oh2)
   call new_evaluate(geometry,hydraulics,b,nh2)
   call check_surface(b,nh2)
   if(k==3)then
    amount=dt*nf%ponded_water_evaporation_cm_per_day
    if(abs(amount-.025d0*dt)>1d-15)error stop 'independent active-constraint evaporation'
    if(abs(nf%actual_top_flux_cm_per_day+capacity)>1d-14)error stop 'independent zero-head capacity'
    if(abs(amount-.5d0*dt*(nh1%ponded_water_evaporation_cm_per_day+nh2%ponded_water_evaporation_cm_per_day))>1d-15) &
      error stop 'frozen-head full/half evaporation inconsistency'
    old_spread=max(old_spread,abs(of%ponded_water_evaporation_cm_per_day- &
      .5d0*(oh1%ponded_water_evaporation_cm_per_day+oh2%ponded_water_evaporation_cm_per_day)))
   endif
   observations=observations+3
   b%previous_ponding_depth_cm=0d0
   call new_evaluate(geometry,hydraulics,b,nh1)
   b%previous_ponding_depth_cm=2d-10
   call new_evaluate(geometry,hydraulics,b,nh2)
   delta=2d-10/b%step_duration_day
   if(abs(nh2%ponded_water_evaporation_cm_per_day-nh1%ponded_water_evaporation_cm_per_day)>delta+1d-12) &
     error stop 'pond-classification discontinuity'
  enddo
 enddo
 if(old_spread<.024999d0)error stop 'incumbent split-source counterexample missing'
 print '(A,I0)','EMPTY_POND_CONSERVATION_BOUNDS_SPLIT_SOURCE_CONTINUITY_PASS=',observations
 print '(A,ES25.17E3)','INCUMBENT_FULL_HALF_EVAP_RATE_SPREAD=',old_spread
contains
 subroutine check_surface(request,result)
  type(new_request),intent(in)::request
  type(new_result),intent(in)::result
  real(real64)::residual
  if(result%status/=1)error stop 'surface unavailable'
  residual=result%candidate_ponding_depth_cm-request%previous_ponding_depth_cm- &
    (1d0-result%ponded_water_evaporation_cm_per_day+result%actual_top_flux_cm_per_day)*request%step_duration_day+ &
    result%runoff_depth_cm
  if(abs(residual)>1d-13)error stop 'surface conservation'
  if(result%candidate_ponding_depth_cm<0d0.or.result%ponded_water_evaporation_cm_per_day<0d0.or. &
     result%ponded_water_evaporation_cm_per_day>.05d0)error stop 'water/demand bounds'
  if(result%candidate_ponding_depth_cm>1d-13.and.abs(result%ponded_water_evaporation_cm_per_day-.05d0)>1d-14) &
    error stop 'positive pond must satisfy demand'
 end subroutine
end program

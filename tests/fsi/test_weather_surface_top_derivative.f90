program test_weather_surface_top_derivative
 use iso_fortran_env,only:real64,int64
 use, intrinsic::ieee_arithmetic,only:ieee_is_finite
 use mod_soil_water_solver_contract
 use mod_b110_default_mvg_provider
 use mod_b110_dynamic_top_boundary_solver_adapter
 implicit none
 type(soil_water_parameter_set_t),target::geometry
 type(b110_default_mvg_parameters_t),target::hp
 type(b110_dynamic_top_boundary_solver_provider_t)::top
 type(soil_water_boundary_conditions_t)::boundary
 type(soil_water_top_boundary_result_t)::result
 real(real64)::cof(24,1),node_k,node_dk,closure
 real(real64),parameter::heads(6)=[-1d-27,-1d-12,-1d-5,-.001d0,0d0,.001d0]
 logical::ok
 integer::i
 geometry%parameter_set_id=1_int64;geometry%active_nodes=1
 geometry%dz=[5d0];geometry%z=[-2.5d0];geometry%node_distance=[2.5d0]
 cof=0d0;cof(1,1)=.032d0;cof(2,1)=.423d0;cof(3,1)=4.75d0
 cof(4,1)=.0135d0;cof(5,1)=.365d0;cof(6,1)=1.455d0;cof(7,1)=1d0-1d0/cof(6,1)
 call initialize_b110_default_mvg_parameters(hp,cof);hp%continuous_saturation_conductivity=.true.
 call bind_b110_dynamic_top_boundary_solver_provider(top,geometry,hp,1,.007397d0,1d-4,.2d0,0d0,0d0,0d0,.029d0,.029d0,0d0,1d0,1d0,implicit_conductivity=.true.)
 write(*,'(a,3(1x,es25.17e3))')'TOP_COEFS',hp%cofgen(25,1),hp%cofgen(27,1),hp%cofgen(7,1)
 do i=1,size(heads)
  call evaluate_b110_default_mvg_conductivity(hp,1,heads(i),node_k,ok,node_dk)
  if(.not.ok.or..not.ieee_is_finite(node_dk))error stop 'analytic node derivative unavailable'
  call top%evaluate(heads(i),.423d0,.007397d0,boundary,result)
  if(result%status/=SW_TOP_BOUNDARY_AVAILABLE.or..not.result%top_flux_derivative_available)error stop 'top derivative unavailable'
  if(result%regime/=SW_TOP_BOUNDARY_REGIME_HEAD)error stop 'wet head discriminator inactive'
  closure=result%candidate_ponding_depth-.007397d0-(.2d0-.029d0)*1d-4+result%runoff_depth-result%actual_top_flux*1d-4
  if(abs(closure)>1d-15)error stop 'top balance closure'
  if(i==1.and.abs(result%top_flux_dpressure_head_top)<1d12)error stop 'singular-slope discriminator inactive'
  write(*,'(a,5(1x,es25.17e3))')'TOP_ROW',heads(i),node_k,node_dk,result%actual_top_flux,result%top_flux_dpressure_head_top
 end do
 print *, 'WEATHER_SURFACE_TOP_DERIVATIVE_PASS'
end program

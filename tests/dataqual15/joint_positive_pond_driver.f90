program joint_positive_pond_driver
 use iso_fortran_env,only:real64,int64
 use mod_soil_water_solver_contract,only:soil_water_parameter_set_t
 use mod_b110_default_mvg_provider,only:b110_default_mvg_parameters_t,initialize_b110_default_mvg_parameters
 use mod_b110_dynamic_top_boundary_provider
 use mod_b111_profile_groundwater_projection
 use mod_fmr_macropore_top_input,only:fmr_macropore_pond_donor_request_t,evaluate_fmr_macropore_pond_donor
 implicit none
 type(soil_water_parameter_set_t)::g
 type(b110_default_mvg_parameters_t)::hp
 type(b110_dynamic_top_boundary_request_t)::r
 type(b110_dynamic_top_boundary_result_t)::base,wet
 type(b111_profile_groundwater_projection_t)::projection
 type(fmr_macropore_pond_donor_request_t)::owner
 real(real64)::c(24,2),head(2),q,dt,balance,amount(2)
 integer::i
 logical::ok
 g%parameter_set_id=26110701_int64;g%active_nodes=2
 g%z=[-.5d0,-1.5d0];g%dz=[1d0,1d0];g%node_distance=[.5d0,1d0]
 c=0d0;c(1,:)=.05d0;c(2,:)=.405d0;c(3,:)=1.4d0;c(4,:)=.03d0
 c(5,:)=.5d0;c(6,:)=1.45d0;c(7,:)=1d0-1d0/1.45d0;c(8,:)=.03d0
 c(10,:)=1.4d0;c(11,:)=.999d0;c(12,:)=.99d0*1.4d0;c(22,:)=-1d6;c(23,:)=1d-12
 call initialize_b110_default_mvg_parameters(hp,c)
 r%conductivity_mean_method=1;r%pressure_head_top_cm=.018d0;r%water_content_top=.405d0
 r%previous_ponding_depth_cm=3.4649030622879591d-9;r%precipitation_rate_cm_per_day=16d0
 r%ponding_max_cm=1d0;r%runoff_resistance_day=.001d0
 r%fixed_top_node_conductivity_cm_per_day=1.4d0;r%macropore_surface_area_fraction=.02d0
 r%macropore_surface_conductivity_cm_per_day=1000d0
 do i=1,2
  dt=7.6294099926599301d-9/real(i,real64);r%step_duration_day=dt
  r%macropore_pond_donor_active=.false.;r%macropore_pond_threshold_cm=0d0
  call evaluate_b110_dynamic_top_boundary(g,hp,r,base)
  if(base%status/=B110_DYN_TOP_AVAILABLE.or.base%regime/=B110_DYN_TOP_REGIME_HEAD)error stop 'base ponded route'
  r%macropore_pond_donor_active=.true.
  call evaluate_b110_dynamic_top_boundary(g,hp,r,wet)
  if(wet%status/=B110_DYN_TOP_AVAILABLE.or.wet%regime/=B110_DYN_TOP_REGIME_HEAD)error stop 'donor ponded route'
  owner%no_macro_ponding_depth_cm=base%candidate_ponding_depth_cm
  owner%threshold_cm=0d0;owner%surface_conductance_step=base%surface_face_conductivity_cm_per_day*dt/g%node_distance(1)
  owner%macropore_surface_conductivity_cm_per_day=r%macropore_surface_conductivity_cm_per_day
  owner%step_duration_day=dt
  call evaluate_fmr_macropore_pond_donor(owner,q,ok)
  if(.not.ok.or.q<=0d0.or.q>base%candidate_ponding_depth_cm)error stop 'positive bounded donor missing'
  if(abs(q-wet%macropore_pond_requested_lateral_cm)>1d-18)error stop 'trial and owner disagree'
  balance=wet%candidate_ponding_depth_cm-r%previous_ponding_depth_cm+wet%runoff_depth_cm &
       -dt*(wet%net_potential_surface_flux_cm_per_day+wet%actual_top_flux_cm_per_day)
  if(abs(balance)>1d-18)error stop 'surface water not conserved'
  amount(i)=q
  r%macropore_pond_threshold_cm=base%candidate_ponding_depth_cm;owner%threshold_cm=r%macropore_pond_threshold_cm
  call evaluate_b110_dynamic_top_boundary(g,hp,r,wet)
  call evaluate_fmr_macropore_pond_donor(owner,q,ok)
  if(.not.ok.or.wet%status/=B110_DYN_TOP_AVAILABLE.or.q/=0d0.or. &
     wet%macropore_pond_requested_lateral_cm/=0d0)error stop 'physical threshold changed'
 end do
 if(amount(1)<=1d-7.or.amount(2)>=1d-7)error stop 'did not straddle old numerical quantum'
 head=[.018d0,1d0]
 call evaluate_b111_profile_groundwater_projection(g%z,g%node_distance,head,1d-9,projection)
 if(.not.projection%valid.or..not.projection%level_present.or.projection%level_cm/=1d-9)error stop 'positive pond projected below surface'
 call evaluate_b111_profile_groundwater_projection(g%z,g%node_distance,head,2d-8,projection)
 if(.not.projection%valid.or.projection%level_cm/=2d-8)error stop 'wet endpoint changed'
 call evaluate_b111_profile_groundwater_projection(g%z,g%node_distance,head,0d0,projection)
 if(.not.projection%valid.or.projection%level_cm/=g%z(1)+head(1))error stop 'exact dry endpoint changed'
 print '(a)','POSITIVE_POND_BOTH_OWNERS_CONSERVATION_FREE_SURFACE_AND_DRY_ENDPOINT_PASS'
end program

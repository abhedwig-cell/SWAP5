program test_ppa_wu05a16_rfm_matrix_share_rebinding
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, initialize_b110_default_mvg_parameters, &
       evaluate_b110_default_mvg_conductivity
  use mod_b110_dynamic_top_boundary_provider, only: b110_dynamic_top_boundary_request_t, &
       b110_dynamic_top_boundary_result_t, evaluate_b110_dynamic_top_boundary, B110_DYN_TOP_AVAILABLE, &
       B110_DYN_TOP_REGIME_FLUX
  use mod_rfm_unponded_surface_composition, only: rfm_unponded_surface_composition_result_t, &
       RFM_SURFACE_COMPOSITION_AVAILABLE
  use mod_rfm_matrix_share_dynamic_top_binding
  implicit none

  integer, parameter :: NN=16, NBINS=200, IBASE=100, J0=101, J1=199
  real(real64), parameter :: TR=0.02_real64, TS=0.427494_real64
  real(real64), parameter :: ALPHA=0.021659_real64, NPAR=1.734737_real64
  real(real64), parameter :: KS=31.225016_real64, LAM=0.98087_real64
  real(real64), parameter :: DT=10.0_real64/86400.0_real64
  real(real64), parameter :: TOL=1.0e-12_real64
  real(real64), parameter :: MATRIX_SHARE=5.961748798503473_real64

  type(soil_water_parameter_set_t) :: geometry
  type(b110_default_mvg_parameters_t) :: hp
  type(b110_dynamic_top_boundary_request_t) :: base_request,rebound_request
  type(b110_dynamic_top_boundary_result_t) :: base_result,rebound_result
  type(rfm_unponded_surface_composition_result_t) :: receipt
  type(rfm_matrix_rebind_diagnostics_t) :: diag
  real(real64) :: cofgen(24,NN),theta_top,h_top,fixed_ktop
  logical :: fixed_ok

  call initialize_geometry_and_hydraulics(geometry,hp,cofgen)
  call initial_top_state(theta_top,h_top)
  call evaluate_b110_default_mvg_conductivity(hp,1,h_top,fixed_ktop,fixed_ok)
  call require(fixed_ok,'A16 fixed K')

  call make_request(base_request,8.0_real64,h_top,theta_top,fixed_ktop)
  call evaluate_b110_dynamic_top_boundary(geometry,hp,base_request,base_result)
  call require(base_result%status==B110_DYN_TOP_AVAILABLE,'A16 base available')
  call require(base_result%regime==B110_DYN_TOP_REGIME_FLUX,'A16 base not flux')
  call require(abs(base_result%candidate_ponding_depth_cm)<=TOL,'A16 base ponding')
  call require(abs(base_result%runoff_depth_cm)<=TOL,'A16 base runoff')
  call require(abs(base_result%net_potential_surface_flux_cm_per_day-8.0_real64)<=TOL,'A16 base supply')

  ! B1.11's direct matrix surface source is the complement of the candidate
  ! macro area share. Runon remains a separate, unpartitioned owner.
  base_request%irrigation_rate_cm_per_day=2.0_real64
  base_request%snowmelt_rate_cm_per_day=1.0_real64
  base_request%runon_rate_cm_per_day=0.2_real64
  base_request%macropore_surface_area_fraction=0.2_real64
  call evaluate_b110_dynamic_top_boundary(geometry,hp,base_request,base_result)
  call require(base_result%status==B110_DYN_TOP_AVAILABLE,'A16 area split available')
  call require(abs(base_result%net_potential_surface_flux_cm_per_day-9.0_real64)<=TOL, &
       'A16 complementary matrix source and unpartitioned runon')
  call require(abs((8.0_real64+2.0_real64+1.0_real64)*0.2_real64 + &
       (8.0_real64+2.0_real64+1.0_real64)*0.8_real64-11.0_real64)<=TOL, &
       'A16 matrix plus macro source closure')
  print '(a)', 'PPA_WU05A16_SOURCE_AREA_PARTITION=PASS'

  call make_request(base_request,8.0_real64,h_top,theta_top,fixed_ktop)
  receipt%status=RFM_SURFACE_COMPOSITION_AVAILABLE
  receipt%effective_supply_cm_per_day=8.0_real64
  receipt%matrix_supply_cm_per_day=MATRIX_SHARE
  receipt%preferential_supply_cm_per_day=8.0_real64-MATRIX_SHARE

  call build_rfm_matrix_share_dynamic_top_request(base_request,receipt,TOL,rebound_request,diag)
  call require(diag%status==RFM_MATRIX_REBIND_AVAILABLE .and. diag%request_produced,'A16 bind failed')
  call require(abs(rebound_request%precipitation_rate_cm_per_day-MATRIX_SHARE)<=TOL,'A16 matrix source')
  call require(abs(rebound_request%irrigation_rate_cm_per_day)<=TOL,'A16 irrigation double count')
  call require(abs(rebound_request%snowmelt_rate_cm_per_day)<=TOL,'A16 snow double count')
  call require(abs(rebound_request%runon_rate_cm_per_day)<=TOL,'A16 runon double count')
  call require(abs(rebound_request%potential_bare_soil_evaporation_cm_per_day)<=TOL,'A16 bare evap double count')
  call require(abs(rebound_request%potential_pond_evaporation_cm_per_day)<=TOL,'A16 pond evap double count')
  call require(rebound_request%conductivity_mean_method==base_request%conductivity_mean_method,'A16 method changed')
  call require(abs(rebound_request%pressure_head_top_cm-base_request%pressure_head_top_cm)<=TOL,'A16 head changed')
  call require(abs(rebound_request%step_duration_day-base_request%step_duration_day)<=TOL,'A16 dt changed')
  call require(abs(rebound_request%ponding_max_cm-base_request%ponding_max_cm)<=TOL,'A16 pmax changed')
  call require(abs(rebound_request%runoff_resistance_day-base_request%runoff_resistance_day)<=TOL,'A16 runoff R changed')

  call evaluate_b110_dynamic_top_boundary(geometry,hp,rebound_request,rebound_result)
  call verify_rfm_matrix_share_dynamic_top_result(receipt,rebound_result,TOL,diag)
  call require(diag%status==RFM_MATRIX_REBIND_AVAILABLE .and. diag%rebound_verified,'A16 rebound rejected')
  call require(rebound_result%regime==B110_DYN_TOP_REGIME_FLUX,'A16 rebound not flux')
  call require(abs(rebound_result%candidate_ponding_depth_cm)<=TOL,'A16 rebound ponding')
  call require(abs(rebound_result%runoff_depth_cm)<=TOL,'A16 rebound runoff')
  call require(abs(rebound_result%net_potential_surface_flux_cm_per_day-MATRIX_SHARE)<=TOL,'A16 rebound supply')

  base_request%previous_ponding_depth_cm=1.0e-4_real64
  call build_rfm_matrix_share_dynamic_top_request(base_request,receipt,TOL,rebound_request,diag)
  call require(diag%status==RFM_MATRIX_REBIND_REFERENCE_REQUIRED,'A16 previous ponding not rejected')

  call make_request(base_request,8.0_real64,h_top,theta_top,fixed_ktop)
  receipt%matrix_supply_cm_per_day=100.0_real64
  receipt%effective_supply_cm_per_day=100.0_real64
  receipt%preferential_supply_cm_per_day=0.0_real64
  call build_rfm_matrix_share_dynamic_top_request(base_request,receipt,TOL,rebound_request,diag)
  call require(diag%status==RFM_MATRIX_REBIND_AVAILABLE,'A16 excessive bind unavailable')
  call evaluate_b110_dynamic_top_boundary(geometry,hp,rebound_request,rebound_result)
  call verify_rfm_matrix_share_dynamic_top_result(receipt,rebound_result,TOL,diag)
  call require(diag%status==RFM_MATRIX_REBIND_REFERENCE_REQUIRED,'A16 head fallback failed')

  print '(a)', 'PPA_WU05A16_RFM_MATRIX_SHARE_REBINDING=PASS'

contains

  subroutine make_request(req,rain,h,theta,fixed_k)
    type(b110_dynamic_top_boundary_request_t),intent(out)::req
    real(real64),intent(in)::rain,h,theta,fixed_k
    req=b110_dynamic_top_boundary_request_t()
    req%conductivity_mean_method=1
    req%pressure_head_top_cm=h
    req%water_content_top=theta
    req%candidate_ponding_depth_cm=0.0_real64
    req%previous_ponding_depth_cm=0.0_real64
    req%step_duration_day=DT
    req%precipitation_rate_cm_per_day=rain
    req%ponding_max_cm=KS*DT
    req%runoff_resistance_day=0.001_real64
    req%runoff_exponent=1.0_real64
    req%fixed_top_node_conductivity_cm_per_day=fixed_k
  end subroutine make_request

  subroutine initialize_geometry_and_hydraulics(g,h,c)
    type(soil_water_parameter_set_t),intent(out)::g
    type(b110_default_mvg_parameters_t),intent(out)::h
    real(real64),intent(out)::c(24,NN)
    real(real64)::mm
    integer::n
    mm=1.0_real64-1.0_real64/NPAR
    g%parameter_set_id=26100116_int64
    g%active_nodes=NN
    allocate(g%z(NN),g%dz(NN),g%node_distance(NN))
    do n=1,NN
      g%z(n)=-10.0_real64*(real(n,real64)-0.5_real64)
    end do
    g%dz=10.0_real64
    g%node_distance=10.0_real64
    c=0.0_real64
    do n=1,NN
      c(1,n)=TR;c(2,n)=TS;c(3,n)=KS;c(4,n)=ALPHA;c(5,n)=LAM;c(6,n)=NPAR
      c(7,n)=mm;c(8,n)=ALPHA;c(9,n)=0.0_real64;c(10,n)=KS
      c(11,n)=0.999_real64;c(12,n)=0.99_real64*KS;c(22,n)=-1.0e6_real64;c(23,n)=1.0e-12_real64
    end do
    call initialize_b110_default_mvg_parameters(h,c)
  end subroutine initialize_geometry_and_hydraulics

  subroutine initial_top_state(theta,h)
    real(real64),intent(out)::theta,h
    real(real64)::dtheta,zfront,overlap,mm,se
    integer::j
    dtheta=(TS-TR)/real(NBINS,real64)
    theta=TR+real(IBASE,real64)*dtheta
    do j=J0,J1
      zfront=120.0_real64+(10.0_real64-120.0_real64)*real(j-J0,real64)/real(J1-J0,real64)
      overlap=max(0.0_real64,min(zfront,10.0_real64))
      theta=theta+dtheta*overlap/10.0_real64
    end do
    mm=1.0_real64-1.0_real64/NPAR
    se=(theta-TR)/(TS-TR)
    h=-(se**(-1.0_real64/mm)-1.0_real64)**(1.0_real64/NPAR)/ALPHA
  end subroutine initial_top_state

  subroutine require(ok,msg)
    logical,intent(in)::ok
    character(*),intent(in)::msg
    if(.not.ok)then
      write(*,'(a,1x,a)') 'PPA_WU05A16_FAIL',trim(msg)
      error stop 1
    end if
  end subroutine require

end program test_ppa_wu05a16_rfm_matrix_share_rebinding

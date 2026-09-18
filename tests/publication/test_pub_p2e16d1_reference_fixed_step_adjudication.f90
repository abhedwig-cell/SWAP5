program test_pub_p2e16d1_reference_fixed_step_adjudication
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_solve_request_t, &
       soil_water_solve_result_t, SW_SOLVE_CONVERGED
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, &
       reference_richards_legacy_workspace_t
  use mod_rossfast_d3r_model_binding, only: rossfast_d3r_material_t, rossfast_d3r_material_from_id, &
       ROSSFAST_D3R_N_CELLS, ROSSFAST_D3R_DZ_CM, ROSSFAST_D3R_HARD_MASS_TOL_CM, &
       ROSSFAST_D3R_H_MIN_CM, ROSSFAST_D3R_H_MAX_CM, ROSSFAST_D3R_BOUNDARY_ENVELOPE_FRACTION
  use mod_rossfast_d3r_execution_policy, only: ROSSFAST_D3R_OUTER_HORIZON_DAY
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  implicit none

  integer, parameter :: n=ROSSFAST_D3R_N_CELLS, ncases=5
  real(real64), parameter :: reference_internal_balance_rate_tol_cm_per_day=1.0e-12_real64
  real(real64), parameter :: scale_floor=1.0e-12_real64
  integer, parameter :: case_ids(ncases)=[576,612,1220,1248,1257]
  character(len=3), parameter :: material_ids(ncases)=[character(len=3) :: 'B16','B17','O16','O17','O17']
  real(real64), parameter :: se_values(ncases)=[0.96_real64,0.96_real64,0.96_real64,0.85_real64,0.96_real64]
  real(real64), parameter :: rho_values(ncases)=[1.05_real64,1.05_real64,-1.0_real64,1.05_real64,-0.95_real64]

  integer :: i
  do i=1,ncases
    call diagnose_case(case_ids(i),material_ids(i),se_values(i),rho_values(i))
  end do

  write(*,'(A,I0)') 'PUB_P2E16D1_CASE_COUNT=',ncases
  write(*,'(A)') 'PUB_P2E16D1_ROSSFAST_SOLVER_EXECUTED=FALSE'
  write(*,'(A)') 'PUB_P2E16D1_THRESHOLDS_CHANGED=FALSE'
  write(*,'(A)') 'PUB_P2E16D1_REFERENCE_ADJUDICATION_GATE=PASS'

contains

  subroutine diagnose_case(case_id,material_id,se,rho)
    integer,intent(in) :: case_id
    character(len=*),intent(in) :: material_id
    real(real64),intent(in) :: se,rho
    type(soil_water_parameter_set_t),target :: parameters
    type(soil_water_solve_request_t) :: request
    type(soil_water_solve_result_t) :: result
    type(reference_richards_legacy_solver_t) :: solver
    type(reference_richards_legacy_workspace_t) :: workspace
    type(rossfast_d3r_material_t) :: material
    type(b110_default_mvg_parameters_t),target :: hydraulic_parameters
    type(b110_default_mvg_provider_t),target :: constitutive
    type(b110_source_sink_provider_t),target :: source_sink
    type(fixed_flux_top_boundary_provider_t),target :: top_boundary
    real(real64),target :: drainage(1,n),irrigation(n),root_sink(n)
    real(real64) :: cofgen(24,n),heads(n),theta0(n),conductivity(n),capacity(n),dkdh(n)
    real(real64) :: h0,k_top,k_bottom,qtop_ref_internal,qbottom_ref,bottom_scale,bottom_limit
    real(real64) :: top_flux,bottom_flux,hmin,hmax,tmin,tmax
    logical :: found,status_ok,route_ok,mass_avail,mass_finite,mass_ok,rate_avail,rate_finite
    logical :: state_alloc,state_size,state_finite,head_domain,theta_domain,ponding_finite
    logical :: top_identity,bottom_identity,final_valid
    character(len=40) :: first_failed

    call rossfast_d3r_material_from_id(material_id,material,found)
    call require(found,'frozen material exists')
    h0=head_from_effective_saturation(se,material)
    call initialize_parameter_contract(parameters,cofgen,material,case_id)
    call initialize_b110_default_mvg_parameters(hydraulic_parameters,cofgen)
    call bind_b110_default_mvg_provider(constitutive,hydraulic_parameters,ROSSFAST_D3R_OUTER_HORIZON_DAY)
    heads=h0
    call constitutive%evaluate(heads,theta0,conductivity,capacity,dkdh)
    call require(all(ieee_is_finite(theta0)) .and. all(ieee_is_finite(conductivity)) .and. all(conductivity>0.0_real64), &
         'initial constitutive state valid')

    k_top=conductivity(1); k_bottom=conductivity(n)
    qtop_ref_internal=0.01_real64*k_top
    qbottom_ref=-0.004_real64*k_bottom
    bottom_scale=max(abs(qbottom_ref),abs(k_bottom),scale_floor)
    bottom_limit=ROSSFAST_D3R_BOUNDARY_ENVELOPE_FRACTION*bottom_scale
    top_flux=-qtop_ref_internal
    bottom_flux=qbottom_ref+rho*bottom_limit

    drainage=0.0_real64; irrigation=0.0_real64; root_sink=0.0_real64
    call bind_b110_source_sink_provider(source_sink,drainage,irrigation,root_sink)
    call initialize_request(request,parameters,constitutive,source_sink,top_boundary,theta0,h0,top_flux,bottom_flux)
    call solver%solve(request,workspace,result)

    status_ok=result%status==SW_SOLVE_CONVERGED
    route_ok=trim(result%diagnostics%route)=='legacy-reference-bound'
    mass_avail=result%integrated_mass_balance_residual_available
    mass_finite=.false.; mass_ok=.false.
    if (mass_avail) then
      mass_finite=ieee_is_finite(result%integrated_mass_balance_residual_cm)
      if (mass_finite) mass_ok=abs(result%integrated_mass_balance_residual_cm)<=ROSSFAST_D3R_HARD_MASS_TOL_CM
    end if
    rate_avail=result%native_balance_rate_residual_available
    rate_finite=.false.
    if (rate_avail) rate_finite=ieee_is_finite(result%native_balance_rate_residual_cm_per_day)

    state_alloc=allocated(result%candidate_state%pressure_head) .and. allocated(result%candidate_state%water_content)
    state_size=.false.; state_finite=.false.; head_domain=.false.; theta_domain=.false.; ponding_finite=.false.
    hmin=huge(0.0_real64); hmax=-huge(0.0_real64); tmin=huge(0.0_real64); tmax=-huge(0.0_real64)
    if (state_alloc) then
      state_size=size(result%candidate_state%pressure_head)==n .and. size(result%candidate_state%water_content)==n
      if (state_size) then
        state_finite=all(ieee_is_finite(result%candidate_state%pressure_head)) .and. &
             all(ieee_is_finite(result%candidate_state%water_content))
        if (state_finite) then
          hmin=minval(result%candidate_state%pressure_head); hmax=maxval(result%candidate_state%pressure_head)
          tmin=minval(result%candidate_state%water_content); tmax=maxval(result%candidate_state%water_content)
          head_domain=all(result%candidate_state%pressure_head>ROSSFAST_D3R_H_MIN_CM) .and. &
               all(result%candidate_state%pressure_head<ROSSFAST_D3R_H_MAX_CM)
          theta_domain=all(result%candidate_state%water_content>material%theta_r) .and. &
               all(result%candidate_state%water_content<material%theta_s)
        end if
        ponding_finite=ieee_is_finite(result%candidate_state%ponding_depth)
      end if
    end if

    top_identity=same_real(result%top_flux,request%boundary%top_flux)
    bottom_identity=same_real(result%bottom_flux,request%boundary%bottom_flux)

    final_valid=status_ok .and. route_ok .and. mass_avail .and. mass_finite .and. mass_ok .and. &
         rate_avail .and. rate_finite .and. state_alloc .and. state_size .and. state_finite .and. &
         head_domain .and. theta_domain .and. ponding_finite .and. top_identity .and. bottom_identity

    first_failed='NONE'
    if (.not.status_ok) then; first_failed='STATUS_NOT_CONVERGED'
    else if (.not.route_ok) then; first_failed='ROUTE'
    else if (.not.mass_avail) then; first_failed='MASS_UNAVAILABLE'
    else if (.not.mass_finite) then; first_failed='MASS_NONFINITE'
    else if (.not.mass_ok) then; first_failed='MASS_HARD_GATE'
    else if (.not.rate_avail) then; first_failed='RATE_UNAVAILABLE'
    else if (.not.rate_finite) then; first_failed='RATE_NONFINITE'
    else if (.not.state_alloc) then; first_failed='STATE_UNALLOCATED'
    else if (.not.state_size) then; first_failed='STATE_SIZE'
    else if (.not.state_finite) then; first_failed='STATE_NONFINITE'
    else if (.not.head_domain) then; first_failed='HEAD_DOMAIN'
    else if (.not.theta_domain) then; first_failed='THETA_DOMAIN'
    else if (.not.ponding_finite) then; first_failed='PONDING_NONFINITE'
    else if (.not.top_identity) then; first_failed='TOP_FLUX_IDENTITY'
    else if (.not.bottom_identity) then; first_failed='BOTTOM_FLUX_IDENTITY'
    end if

    write(*,'(*(g0))') 'PUB_P2E16D1_CASE|CASE=',case_id,'|M=',trim(material_id),'|SE=',se,'|AXIS=BOTTOM|RHO=',rho, &
         '|STATUS=',result%status,'|ROUTE=',trim(result%diagnostics%route),'|STATUS_OK=',status_ok,'|ROUTE_OK=',route_ok, &
         '|MASS_AVAILABLE=',mass_avail,'|MASS_FINITE=',mass_finite,'|MASS_OK=',mass_ok, &
         '|RATE_AVAILABLE=',rate_avail,'|RATE_FINITE=',rate_finite, &
         '|STATE_ALLOC=',state_alloc,'|STATE_SIZE=',state_size,'|STATE_FINITE=',state_finite, &
         '|HEAD_DOMAIN=',head_domain,'|THETA_DOMAIN=',theta_domain,'|PONDING_FINITE=',ponding_finite, &
         '|TOP_IDENTITY=',top_identity,'|BOTTOM_IDENTITY=',bottom_identity,'|FINAL_VALID=',final_valid, &
         '|FIRST_FAILED=',trim(first_failed),'|HMIN=',hmin,'|HMAX=',hmax,'|THETA_MIN=',tmin,'|THETA_MAX=',tmax

    if (mass_avail) write(*,'(*(g0))') 'PUB_P2E16D1_MASS|CASE=',case_id,'|CM=',result%integrated_mass_balance_residual_cm
    if (rate_avail) write(*,'(*(g0))') 'PUB_P2E16D1_RATE|CASE=',case_id,'|CM_PER_DAY=',result%native_balance_rate_residual_cm_per_day
  end subroutine diagnose_case

  pure real(real64) function head_from_effective_saturation(se,material) result(head_cm)
    real(real64),intent(in) :: se
    type(rossfast_d3r_material_t),intent(in) :: material
    real(real64) :: m
    m=1.0_real64-1.0_real64/material%n
    head_cm=-(se**(-1.0_real64/m)-1.0_real64)**(1.0_real64/material%n)/material%alpha_per_cm
  end function head_from_effective_saturation

  subroutine initialize_parameter_contract(parameter_set,cofgen_out,mat,case_id)
    type(soil_water_parameter_set_t),target,intent(out) :: parameter_set
    real(real64),intent(out) :: cofgen_out(24,n)
    type(rossfast_d3r_material_t),intent(in) :: mat
    integer,intent(in) :: case_id
    real(real64) :: m
    integer :: j
    m=1.0_real64-1.0_real64/mat%n
    parameter_set%parameter_set_id=921600+case_id; parameter_set%active_nodes=n
    allocate(parameter_set%z(n),parameter_set%dz(n),parameter_set%node_distance(n))
    do j=1,n
      parameter_set%z(j)=-ROSSFAST_D3R_DZ_CM*(real(j,real64)-0.5_real64)
    end do
    parameter_set%dz=ROSSFAST_D3R_DZ_CM; parameter_set%node_distance=ROSSFAST_D3R_DZ_CM
    cofgen_out=0.0_real64
    do j=1,n
      cofgen_out(1,j)=mat%theta_r; cofgen_out(2,j)=mat%theta_s; cofgen_out(3,j)=mat%ksatfit_cm_per_day
      cofgen_out(4,j)=mat%alpha_per_cm; cofgen_out(5,j)=mat%lambda; cofgen_out(6,j)=mat%n; cofgen_out(7,j)=m
      cofgen_out(8,j)=mat%alpha_per_cm; cofgen_out(9,j)=mat%h_enpr_cm; cofgen_out(10,j)=mat%ksatfit_cm_per_day
      cofgen_out(11,j)=0.999_real64; cofgen_out(12,j)=0.99_real64*mat%ksatfit_cm_per_day
      cofgen_out(22,j)=-1.0e6_real64; cofgen_out(23,j)=1.0e-12_real64
    end do
  end subroutine initialize_parameter_contract

  subroutine initialize_request(req,parameter_set,hydraulic_provider,source_provider,top_provider,theta,h0,qtop,qbot)
    type(soil_water_solve_request_t),intent(out) :: req
    type(soil_water_parameter_set_t),target,intent(in) :: parameter_set
    type(b110_default_mvg_provider_t),target,intent(in) :: hydraulic_provider
    type(b110_source_sink_provider_t),target,intent(in) :: source_provider
    type(fixed_flux_top_boundary_provider_t),target,intent(in) :: top_provider
    real(real64),intent(in) :: theta(n),h0,qtop,qbot
    req%parameters=>parameter_set; req%base_state%active_nodes=n
    allocate(req%base_state%pressure_head(n),req%base_state%water_content(n))
    req%base_state%pressure_head=h0; req%base_state%water_content=theta
    req%base_state%ponding_depth=0.0_real64; req%base_state%groundwater_level=-999.0_real64
    req%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX; req%boundary%bottom_mode=2
    req%boundary%top_flux=qtop; req%boundary%top_head=h0
    req%boundary%bottom_flux=qbot; req%boundary%bottom_head=-999999.0_real64
    req%physical%macropore_active=.false.
    req%numerical%max_iterations=16; req%numerical%max_backtracking=8
    req%numerical%conductivity_implicit_mode=0; req%numerical%conductivity_mean_method=1
    req%numerical%min_step_duration=1.0e-8_real64
    req%numerical%compartment_balance_tolerance=reference_internal_balance_rate_tol_cm_per_day
    req%numerical%total_balance_tolerance=reference_internal_balance_rate_tol_cm_per_day
    req%numerical%head_abs_tolerance=1.0e-12_real64; req%numerical%head_rel_tolerance=1.0e-12_real64
    req%numerical%ponding_tolerance=1.0e-12_real64
    req%step_duration=ROSSFAST_D3R_OUTER_HORIZON_DAY; req%request_interface_sensitivity=.false.
    req%evaluation%constitutive=>hydraulic_provider
    req%evaluation%source_sink=>source_provider
    req%evaluation%top_boundary=>top_provider
  end subroutine initialize_request

  pure logical function same_real(a,b)
    real(real64),intent(in) :: a,b
    real(real64) :: scale
    scale=max(1.0_real64,abs(a),abs(b))
    same_real=abs(a-b)<=32.0_real64*epsilon(1.0_real64)*scale
  end function same_real

  subroutine require(condition,label)
    logical,intent(in) :: condition
    character(len=*),intent(in) :: label
    if (.not.condition) then
      write(*,'(A,1X,A)') 'PUB_P2E16D1_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_pub_p2e16d1_reference_fixed_step_adjudication

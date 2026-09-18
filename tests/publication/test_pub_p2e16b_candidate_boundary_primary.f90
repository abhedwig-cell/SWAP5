program test_pub_p2e16b_candidate_boundary_primary
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_solve_request_t, &
       soil_water_solve_result_t, SW_SOLVE_CONVERGED
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, &
       reference_richards_legacy_workspace_t
  use mod_rossfast_d3r_soil_water_solver, only: rossfast_d3r_soil_water_solver_t, &
       rossfast_d3r_soil_water_workspace_t
  use mod_rossfast_d3r_model_binding, only: rossfast_d3r_material_t, rossfast_d3r_material_from_id, &
       ROSSFAST_D3R_N_CELLS, ROSSFAST_D3R_DZ_CM, ROSSFAST_D3R_HARD_MASS_TOL_CM, &
       ROSSFAST_D3R_H_MIN_CM, ROSSFAST_D3R_H_MAX_CM, ROSSFAST_D3R_BOUNDARY_ENVELOPE_FRACTION
  use mod_rossfast_d3r_execution_policy, only: ROSSFAST_D3R_OUTER_HORIZON_DAY
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  implicit none

  integer, parameter :: n=ROSSFAST_D3R_N_CELLS
  integer, parameter :: nmat=36,nse=3,naxis=2,nrho=6,ncases=nmat*nse*naxis*nrho
  integer, parameter :: n_unauthorized=14
  real(real64), parameter :: reference_internal_balance_rate_tol_cm_per_day=1.0e-12_real64
  real(real64), parameter :: scale_floor=1.0e-12_real64

  character(len=3), parameter :: material_ids(nmat)=[character(len=3) :: &
       'B01','B02','B03','B04','B05','B06','B07','B08','B09','B10','B11','B12','B13','B14','B15','B16','B17','B18', &
       'O01','O02','O03','O04','O05','O06','O07','O08','O09','O10','O11','O12','O13','O14','O15','O16','O17','O18']
  character(len=6), parameter :: axis_ids(naxis)=[character(len=6) :: 'TOP   ','BOTTOM']
  real(real64), parameter :: se_levels(nse)=[0.65_real64,0.85_real64,0.96_real64]
  real(real64), parameter :: rho_values(nrho)=[-1.05_real64,-1.0_real64,-0.95_real64,0.95_real64,1.0_real64,1.05_real64]
  integer, parameter :: unauthorized_case_ids(n_unauthorized)=[154,155,166,167,171,172,173,178,179,442,443,454,455,646]

  real(real64), parameter :: th_h_inf(nse)=[ &
       0.009310899886486368_real64,0.05684414280500505_real64,0.7386357920248865_real64]
  real(real64), parameter :: th_h_rms(nse)=[ &
       0.004264337561059986_real64,0.02309047189054667_real64,0.19122530959872563_real64]
  real(real64), parameter :: th_theta_inf(nse)=[ &
       0.000017908123244203544_real64,0.00024393588764148877_real64,0.0012274135237608785_real64]
  real(real64), parameter :: th_theta_rms(nse)=[ &
       0.000006578609068585418_real64,0.00008095278187597767_real64,0.00035749599085978164_real64]
  real(real64), parameter :: th_storage(nse)=[ &
       2.1316282072803006e-14_real64,2.8421709430404007e-14_real64,2.8421709430404007e-14_real64]

  integer :: imat,ise,iaxis,irho,case_id
  integer :: ref_valid_count,ref_invalid_count
  integer :: ross_valid_inside,ross_valid_boundary,ross_valid_outside
  integer :: ross_invalid_inside,ross_invalid_boundary,ross_invalid_outside
  integer :: auth_admissible_inside,auth_admissible_boundary
  integer :: auth_fail_inside,auth_fail_boundary
  integer :: unauth_route_valid_inside,unauth_route_valid_boundary
  integer :: route_mismatch_inside,route_mismatch_boundary,route_mismatch_outside
  integer :: fallback_count
  logical :: ref_valid,ross_valid,authorized,metrics_available,metrics_pass,fallback
  character(len=48) :: classification
  real(real64) :: dh_inf,dh_rms,dtheta_inf,dtheta_rms,dstorage
  real(real64) :: max_ratio_authorized(5), ratio(5)

  ref_valid_count=0; ref_invalid_count=0
  ross_valid_inside=0; ross_valid_boundary=0; ross_valid_outside=0
  ross_invalid_inside=0; ross_invalid_boundary=0; ross_invalid_outside=0
  auth_admissible_inside=0; auth_admissible_boundary=0
  auth_fail_inside=0; auth_fail_boundary=0
  unauth_route_valid_inside=0; unauth_route_valid_boundary=0
  route_mismatch_inside=0; route_mismatch_boundary=0; route_mismatch_outside=0
  fallback_count=0; max_ratio_authorized=0.0_real64; case_id=0

  do imat=1,nmat
    do ise=1,nse
      do iaxis=1,naxis
        do irho=1,nrho
          case_id=case_id+1
          authorized=pairwise_authorized(case_id) .and. abs(rho_values(irho))<=1.0_real64
          call run_case(case_id,ise,material_ids(imat),se_levels(ise),trim(axis_ids(iaxis)),rho_values(irho),authorized, &
               classification,ref_valid,ross_valid,fallback,metrics_available,metrics_pass, &
               dh_inf,dh_rms,dtheta_inf,dtheta_rms,dstorage)

          if (ref_valid) then
            ref_valid_count=ref_valid_count+1
          else
            ref_invalid_count=ref_invalid_count+1
          end if
          if (fallback) fallback_count=fallback_count+1

          select case(trim(classify_rho(rho_values(irho))))
          case('INSIDE')
            if (ross_valid) then
              ross_valid_inside=ross_valid_inside+1
            else
              ross_invalid_inside=ross_invalid_inside+1
            end if
            if (ref_valid .and. .not.ross_valid) route_mismatch_inside=route_mismatch_inside+1
            if (ref_valid .and. ross_valid .and. authorized) then
              if (metrics_pass) then
                auth_admissible_inside=auth_admissible_inside+1
              else
                auth_fail_inside=auth_fail_inside+1
              end if
            else if (ref_valid .and. ross_valid .and. .not.authorized) then
              unauth_route_valid_inside=unauth_route_valid_inside+1
            end if
          case('BOUNDARY')
            if (ross_valid) then
              ross_valid_boundary=ross_valid_boundary+1
            else
              ross_invalid_boundary=ross_invalid_boundary+1
            end if
            if (ref_valid .and. .not.ross_valid) route_mismatch_boundary=route_mismatch_boundary+1
            if (ref_valid .and. ross_valid .and. authorized) then
              if (metrics_pass) then
                auth_admissible_boundary=auth_admissible_boundary+1
              else
                auth_fail_boundary=auth_fail_boundary+1
              end if
            else if (ref_valid .and. ross_valid .and. .not.authorized) then
              unauth_route_valid_boundary=unauth_route_valid_boundary+1
            end if
          case('OUTSIDE')
            if (ross_valid) then
              ross_valid_outside=ross_valid_outside+1
            else
              ross_invalid_outside=ross_invalid_outside+1
            end if
            if (ref_valid .and. ross_valid) route_mismatch_outside=route_mismatch_outside+1
          end select

          if (authorized .and. ref_valid .and. ross_valid .and. metrics_available) then
            ratio=[dh_inf/th_h_inf(ise),dh_rms/th_h_rms(ise),dtheta_inf/th_theta_inf(ise), &
                   dtheta_rms/th_theta_rms(ise),dstorage/th_storage(ise)]
            max_ratio_authorized=max(max_ratio_authorized,ratio)
          end if
        end do
      end do
    end do
  end do

  call require(case_id==ncases,'exact 1296-case candidate boundary matrix attempted')
  call require(ref_valid_count+ref_invalid_count==ncases,'every case has Reference route classification')
  call require(ross_valid_inside+ross_invalid_inside==432,'all inside candidate cases classified')
  call require(ross_valid_boundary+ross_invalid_boundary==432,'all boundary candidate cases classified')
  call require(ross_valid_outside+ross_invalid_outside==432,'all outside candidate cases classified')

  write(*,'(A,I0)') 'PUB_P2E16B_CASE_COUNT=',case_id
  write(*,'(A,I0)') 'PUB_P2E16B_REFERENCE_VALID_COUNT=',ref_valid_count
  write(*,'(A,I0)') 'PUB_P2E16B_REFERENCE_INVALID_COUNT=',ref_invalid_count
  write(*,'(A,I0)') 'PUB_P2E16B_ROSS_VALID_INSIDE=',ross_valid_inside
  write(*,'(A,I0)') 'PUB_P2E16B_ROSS_INVALID_INSIDE=',ross_invalid_inside
  write(*,'(A,I0)') 'PUB_P2E16B_ROSS_VALID_BOUNDARY=',ross_valid_boundary
  write(*,'(A,I0)') 'PUB_P2E16B_ROSS_INVALID_BOUNDARY=',ross_invalid_boundary
  write(*,'(A,I0)') 'PUB_P2E16B_ROSS_VALID_OUTSIDE=',ross_valid_outside
  write(*,'(A,I0)') 'PUB_P2E16B_ROSS_INVALID_OUTSIDE=',ross_invalid_outside
  write(*,'(A,I0)') 'PUB_P2E16B_ROUTE_MISMATCH_INSIDE=',route_mismatch_inside
  write(*,'(A,I0)') 'PUB_P2E16B_ROUTE_MISMATCH_BOUNDARY=',route_mismatch_boundary
  write(*,'(A,I0)') 'PUB_P2E16B_ROUTE_MISMATCH_OUTSIDE=',route_mismatch_outside
  write(*,'(A,I0)') 'PUB_P2E16B_AUTH_ADMISSIBLE_INSIDE=',auth_admissible_inside
  write(*,'(A,I0)') 'PUB_P2E16B_AUTH_DISCREPANCY_FAIL_INSIDE=',auth_fail_inside
  write(*,'(A,I0)') 'PUB_P2E16B_AUTH_ADMISSIBLE_BOUNDARY=',auth_admissible_boundary
  write(*,'(A,I0)') 'PUB_P2E16B_AUTH_DISCREPANCY_FAIL_BOUNDARY=',auth_fail_boundary
  write(*,'(A,I0)') 'PUB_P2E16B_UNAUTHORIZED_ROUTE_VALID_INSIDE=',unauth_route_valid_inside
  write(*,'(A,I0)') 'PUB_P2E16B_UNAUTHORIZED_ROUTE_VALID_BOUNDARY=',unauth_route_valid_boundary
  write(*,'(A,I0)') 'PUB_P2E16B_FALLBACK_COUNT=',fallback_count
  write(*,'(*(g0))') 'PUB_P2E16B_MAX_AUTHORIZED_THRESHOLD_FRACTION|D_H_INF=',max_ratio_authorized(1), &
       '|D_H_RMS=',max_ratio_authorized(2),'|D_THETA_INF=',max_ratio_authorized(3), &
       '|D_THETA_RMS=',max_ratio_authorized(4),'|D_STORAGE=',max_ratio_authorized(5)
  write(*,'(A)') 'PUB_P2E16B_P2E14_THRESHOLDS_CHANGED=FALSE'
  write(*,'(A)') 'PUB_P2E16B_STAGE_A_AUTHORIZATION_CHANGED=FALSE'
  write(*,'(A)') 'PUB_P2E16B_PERFORMANCE_CLAIM_EVALUATED=FALSE'
  write(*,'(A)') 'PUB_P2E16B_SCIENTIFIC_FAILURE_IS_CI_FAILURE=FALSE'
  write(*,'(A)') 'PUB_P2E16B_CANDIDATE_BOUNDARY_PRIMARY_GATE=PASS'

contains

  subroutine run_case(case_id,ise,material_id,se,axis_id,rho,authorized,classification,ref_valid,ross_valid,fallback, &
       metrics_available,metrics_pass,dh_inf,dh_rms,dtheta_inf,dtheta_rms,dstorage)
    integer,intent(in) :: case_id,ise
    character(len=*),intent(in) :: material_id,axis_id
    real(real64),intent(in) :: se,rho
    logical,intent(in) :: authorized
    character(len=*),intent(out) :: classification
    logical,intent(out) :: ref_valid,ross_valid,fallback,metrics_available,metrics_pass
    real(real64),intent(out) :: dh_inf,dh_rms,dtheta_inf,dtheta_rms,dstorage

    type(soil_water_parameter_set_t),target :: parameters
    type(soil_water_solve_request_t) :: request
    type(soil_water_solve_result_t) :: reference_result,alternative_result
    type(reference_richards_legacy_solver_t) :: reference_solver
    type(reference_richards_legacy_workspace_t) :: reference_workspace
    type(rossfast_d3r_soil_water_solver_t) :: alternative_solver
    type(rossfast_d3r_soil_water_workspace_t) :: alternative_workspace
    type(rossfast_d3r_material_t) :: material
    type(b110_default_mvg_parameters_t),target :: hydraulic_parameters
    type(b110_default_mvg_provider_t),target :: constitutive
    type(b110_source_sink_provider_t),target :: source_sink
    type(fixed_flux_top_boundary_provider_t),target :: top_boundary
    real(real64),target :: drainage(1,n),irrigation(n),root_sink(n)
    real(real64) :: cofgen(24,n),heads(n),theta0(n),conductivity(n),capacity(n),dkdh(n)
    real(real64) :: h0,k_top,k_bottom,qtop_ref_internal,qbottom_ref,top_scale,bottom_scale,top_limit,bottom_limit
    real(real64) :: top_flux,bottom_flux,reconstructed_rho,storage_reference,storage_alternative
    logical :: found,initialized
    integer :: provider_status

    classification='UNCLASSIFIED'
    ref_valid=.false.; ross_valid=.false.; fallback=.false.
    metrics_available=.false.; metrics_pass=.false.
    dh_inf=0.0_real64; dh_rms=0.0_real64; dtheta_inf=0.0_real64; dtheta_rms=0.0_real64; dstorage=0.0_real64

    call rossfast_d3r_material_from_id(material_id,material,found)
    call require(found,'preregistered material authority available')
    h0=head_from_effective_saturation(se,material)
    call require(ieee_is_finite(h0) .and. h0>ROSSFAST_D3R_H_MIN_CM .and. h0<ROSSFAST_D3R_H_MAX_CM, &
         'preregistered initial state inside E0 head domain')

    call initialize_parameter_contract(parameters,cofgen,material,case_id)
    call initialize_b110_default_mvg_parameters(hydraulic_parameters,cofgen)
    call bind_b110_default_mvg_provider(constitutive,hydraulic_parameters,ROSSFAST_D3R_OUTER_HORIZON_DAY)
    heads=h0
    call constitutive%evaluate(heads,theta0,conductivity,capacity,dkdh)
    call require(all(ieee_is_finite(theta0)) .and. all(ieee_is_finite(conductivity)) .and. all(conductivity>0.0_real64), &
         'common initial constitutive state finite and positive')

    k_top=conductivity(1); k_bottom=conductivity(n)
    qtop_ref_internal=0.01_real64*k_top
    qbottom_ref=-0.004_real64*k_bottom
    top_scale=max(abs(qtop_ref_internal),abs(k_top),scale_floor)
    bottom_scale=max(abs(qbottom_ref),abs(k_bottom),scale_floor)
    top_limit=ROSSFAST_D3R_BOUNDARY_ENVELOPE_FRACTION*top_scale
    bottom_limit=ROSSFAST_D3R_BOUNDARY_ENVELOPE_FRACTION*bottom_scale
    select case(trim(axis_id))
    case('TOP')
      top_flux=-(qtop_ref_internal+rho*top_limit)
      bottom_flux=qbottom_ref
      reconstructed_rho=((-top_flux)-qtop_ref_internal)/top_limit
    case('BOTTOM')
      top_flux=-qtop_ref_internal
      bottom_flux=qbottom_ref+rho*bottom_limit
      reconstructed_rho=(bottom_flux-qbottom_ref)/bottom_limit
    case default
      call require(.false.,'unknown boundary axis')
    end select
    call require(abs(reconstructed_rho-rho)<=1.0e-12_real64,'constructed forcing reproduces preregistered rho')

    drainage=0.0_real64; irrigation=0.0_real64; root_sink=0.0_real64
    call bind_b110_source_sink_provider(source_sink,drainage,irrigation,root_sink)
    call initialize_common_request(request,parameters,constitutive,source_sink,top_boundary,theta0,h0,top_flux,bottom_flux)

    call reference_solver%solve(request,reference_workspace,reference_result)
    call alternative_solver%initialize('assets/rossfast/d3r',material_id,initialized,provider_status)
    if (initialized) call alternative_solver%solve(request,alternative_workspace,alternative_result)

    ref_valid=reference_route_valid(reference_result,request,material)
    if (initialized) ross_valid=rossfast_route_valid(alternative_result,request,material)
    fallback = initialized .and. trim(alternative_result%diagnostics%route)=='legacy-reference-bound'

    if (ref_valid .and. ross_valid) then
      metrics_available=.true.
      storage_reference=sum(parameters%dz*reference_result%candidate_state%water_content)+reference_result%candidate_state%ponding_depth
      storage_alternative=sum(parameters%dz*alternative_result%candidate_state%water_content)+alternative_result%candidate_state%ponding_depth
      dh_inf=maxval(abs(alternative_result%candidate_state%pressure_head-reference_result%candidate_state%pressure_head))
      dh_rms=sqrt(sum((alternative_result%candidate_state%pressure_head-reference_result%candidate_state%pressure_head)**2)/real(n,real64))
      dtheta_inf=maxval(abs(alternative_result%candidate_state%water_content-reference_result%candidate_state%water_content))
      dtheta_rms=sqrt(sum((alternative_result%candidate_state%water_content-reference_result%candidate_state%water_content)**2)/real(n,real64))
      dstorage=abs(storage_alternative-storage_reference)
      metrics_pass=dh_inf<=th_h_inf(ise) .and. dh_rms<=th_h_rms(ise) .and. &
           dtheta_inf<=th_theta_inf(ise) .and. dtheta_rms<=th_theta_rms(ise) .and. dstorage<=th_storage(ise)
    end if

    if (.not.ref_valid) then
      if (.not.ross_valid) then
        classification='BOTH_ROUTES_INVALID'
      else
        classification='REFERENCE_ROUTE_INVALID'
      end if
    else
      select case(trim(classify_rho(rho)))
      case('INSIDE')
        if (.not.ross_valid) then
          classification='INSIDE_UNEXPECTED_ROSSFAST_REJECTION'
        else if (.not.authorized) then
          classification='INSIDE_ROUTE_VALID_THRESHOLD_TRANSFER_UNAUTHORIZED'
        else if (metrics_pass) then
          classification='INSIDE_ROUTE_VALID_AUTHORIZED_ADMISSIBLE'
        else
          classification='INSIDE_ROUTE_VALID_AUTHORIZED_DISCREPANCY_FAIL'
        end if
      case('BOUNDARY')
        if (.not.ross_valid) then
          classification='BOUNDARY_UNEXPECTED_ROSSFAST_REJECTION'
        else if (.not.authorized) then
          classification='BOUNDARY_ROUTE_VALID_THRESHOLD_TRANSFER_UNAUTHORIZED'
        else if (metrics_pass) then
          classification='BOUNDARY_ROUTE_VALID_AUTHORIZED_ADMISSIBLE'
        else
          classification='BOUNDARY_ROUTE_VALID_AUTHORIZED_DISCREPANCY_FAIL'
        end if
      case('OUTSIDE')
        if (ross_valid) then
          classification='OUTSIDE_UNEXPECTED_ROSSFAST_ADMISSION'
        else
          classification='OUTSIDE_EXPECTED_FAIL_CLOSED'
        end if
      end select
    end if

    write(*,'(*(g0))') 'PUB_P2E16B_CASE|CASE=',case_id,'|M=',trim(material_id),'|SE=',se,'|AXIS=',trim(axis_id), &
         '|RHO=',rho,'|RHO_CLASS=',trim(classify_rho(rho)),'|AUTHORIZED=',authorized, &
         '|CLASS=',trim(classification),'|REF_VALID=',ref_valid,'|ROSS_INIT=',initialized,'|ROSS_VALID=',ross_valid, &
         '|FALLBACK=',fallback,'|METRICS=',metrics_available,'|METRICS_PASS=',metrics_pass, &
         '|D_H_INF=',dh_inf,'|D_H_RMS=',dh_rms,'|D_THETA_INF=',dtheta_inf,'|D_THETA_RMS=',dtheta_rms,'|D_STORAGE=',dstorage

    if (reference_result%integrated_mass_balance_residual_available) then
      write(*,'(*(g0))') 'PUB_P2E16B_REFERENCE_MASS|CASE=',case_id,'|CM=',reference_result%integrated_mass_balance_residual_cm
    end if
    if (initialized .and. alternative_result%integrated_mass_balance_residual_available) then
      write(*,'(*(g0))') 'PUB_P2E16B_ROSSFAST_MASS|CASE=',case_id,'|CM=',alternative_result%integrated_mass_balance_residual_cm
    end if
  end subroutine run_case

  logical function pairwise_authorized(case_id) result(ok)
    integer,intent(in) :: case_id
    ok=.not.any(unauthorized_case_ids==case_id)
  end function pairwise_authorized

  character(len=16) function classify_rho(rho) result(label)
    real(real64),intent(in) :: rho
    if (abs(rho)<1.0_real64) then
      label='INSIDE'
    else if (abs(rho)==1.0_real64) then
      label='BOUNDARY'
    else
      label='OUTSIDE'
    end if
  end function classify_rho

  logical function reference_route_valid(result,request,material) result(ok)
    type(soil_water_solve_result_t),intent(in) :: result
    type(soil_water_solve_request_t),intent(in) :: request
    type(rossfast_d3r_material_t),intent(in) :: material
    ok=.false.
    if (result%status/=SW_SOLVE_CONVERGED) return
    if (trim(result%diagnostics%route)/='legacy-reference-bound') return
    if (.not.result%integrated_mass_balance_residual_available) return
    if (.not.result%native_balance_rate_residual_available) return
    if (.not.ieee_is_finite(result%integrated_mass_balance_residual_cm)) return
    if (.not.ieee_is_finite(result%native_balance_rate_residual_cm_per_day)) return
    if (abs(result%integrated_mass_balance_residual_cm)>ROSSFAST_D3R_HARD_MASS_TOL_CM) return
    if (.not.state_valid(result,material)) return
    if (.not.same_real(result%top_flux,request%boundary%top_flux)) return
    if (.not.same_real(result%bottom_flux,request%boundary%bottom_flux)) return
    ok=.true.
  end function reference_route_valid

  logical function rossfast_route_valid(result,request,material) result(ok)
    type(soil_water_solve_result_t),intent(in) :: result
    type(soil_water_solve_request_t),intent(in) :: request
    type(rossfast_d3r_material_t),intent(in) :: material
    ok=.false.
    if (result%status/=SW_SOLVE_CONVERGED) return
    if (trim(result%diagnostics%route)/='rossfast-d3r') return
    if (.not.result%integrated_mass_balance_residual_available) return
    if (result%native_balance_rate_residual_available) return
    if (.not.ieee_is_finite(result%integrated_mass_balance_residual_cm)) return
    if (abs(result%integrated_mass_balance_residual_cm)>ROSSFAST_D3R_HARD_MASS_TOL_CM) return
    if (.not.state_valid(result,material)) return
    if (.not.same_real(result%top_flux,request%boundary%top_flux)) return
    if (.not.same_real(result%bottom_flux,request%boundary%bottom_flux)) return
    ok=.true.
  end function rossfast_route_valid

  logical function state_valid(result,material) result(ok)
    type(soil_water_solve_result_t),intent(in) :: result
    type(rossfast_d3r_material_t),intent(in) :: material
    ok=.false.
    if (result%candidate_state%active_nodes/=n) return
    if (.not.allocated(result%candidate_state%pressure_head) .or. .not.allocated(result%candidate_state%water_content)) return
    if (size(result%candidate_state%pressure_head)/=n .or. size(result%candidate_state%water_content)/=n) return
    if (any(.not.ieee_is_finite(result%candidate_state%pressure_head)) .or. any(.not.ieee_is_finite(result%candidate_state%water_content))) return
    if (any(result%candidate_state%pressure_head<=ROSSFAST_D3R_H_MIN_CM) .or. any(result%candidate_state%pressure_head>=ROSSFAST_D3R_H_MAX_CM)) return
    if (any(result%candidate_state%water_content<=material%theta_r) .or. any(result%candidate_state%water_content>=material%theta_s)) return
    if (.not.ieee_is_finite(result%candidate_state%ponding_depth)) return
    ok=.true.
  end function state_valid

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
    integer :: i
    m=1.0_real64-1.0_real64/mat%n
    parameter_set%parameter_set_id=921600+case_id; parameter_set%active_nodes=n
    allocate(parameter_set%z(n),parameter_set%dz(n),parameter_set%node_distance(n))
    do i=1,n
      parameter_set%z(i)=-ROSSFAST_D3R_DZ_CM*(real(i,real64)-0.5_real64)
    end do
    parameter_set%dz=ROSSFAST_D3R_DZ_CM; parameter_set%node_distance=ROSSFAST_D3R_DZ_CM
    cofgen_out=0.0_real64
    do i=1,n
      cofgen_out(1,i)=mat%theta_r; cofgen_out(2,i)=mat%theta_s; cofgen_out(3,i)=mat%ksatfit_cm_per_day
      cofgen_out(4,i)=mat%alpha_per_cm; cofgen_out(5,i)=mat%lambda; cofgen_out(6,i)=mat%n; cofgen_out(7,i)=m
      cofgen_out(8,i)=mat%alpha_per_cm; cofgen_out(9,i)=mat%h_enpr_cm; cofgen_out(10,i)=mat%ksatfit_cm_per_day
      cofgen_out(11,i)=0.999_real64; cofgen_out(12,i)=0.99_real64*mat%ksatfit_cm_per_day
      cofgen_out(22,i)=-1.0e6_real64; cofgen_out(23,i)=1.0e-12_real64
    end do
  end subroutine initialize_parameter_contract

  subroutine initialize_common_request(req,parameter_set,hydraulic_provider,source_provider,top_provider,theta,h0,qtop,qbot)
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
  end subroutine initialize_common_request

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
      write(*,'(A,1X,A)') 'PUB_P2E16B_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_pub_p2e16b_candidate_boundary_primary

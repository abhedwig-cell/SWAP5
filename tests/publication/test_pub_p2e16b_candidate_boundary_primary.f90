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
  integer, parameter :: nmat=36,nse=3,naxis=2,nrho=6,expected_cases=nmat*nse*naxis*nrho
  integer, parameter :: n_transfer_invalid=27
  real(real64), parameter :: reference_internal_balance_rate_tol_cm_per_day=1.0e-12_real64
  character(len=3), parameter :: material_ids(nmat)=[character(len=3) :: &
       'B01','B02','B03','B04','B05','B06','B07','B08','B09','B10','B11','B12', &
       'B13','B14','B15','B16','B17','B18','O01','O02','O03','O04','O05','O06', &
       'O07','O08','O09','O10','O11','O12','O13','O14','O15','O16','O17','O18']
  character(len=6), parameter :: axis_ids(naxis)=[character(len=6) :: 'TOP   ','BOTTOM']
  real(real64), parameter :: se_levels(nse)=[0.65_real64,0.85_real64,0.96_real64]
  real(real64), parameter :: rho_levels(nrho)=[-1.05_real64,-1.0_real64,-0.95_real64, &
       0.95_real64,1.0_real64,1.05_real64]
  integer, parameter :: transfer_invalid_ids(n_transfer_invalid)=[ &
       145,154,155,156,157,166,167,168,169,171,172,173,174,178,179,180, &
       433,442,443,444,445,454,455,456,576,646,1207 ]

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
  integer :: inside_count,boundary_count,outside_count
  integer :: transfer_valid_count,transfer_invalid_count,authorized_science_count
  integer :: reference_invalid_count,rossfast_init_failure_count
  integer :: route_expected_valid_count,route_expected_invalid_count,route_actual_valid_count,route_actual_invalid_count
  integer :: route_mismatch_count,inside_rejected_count,boundary_rejected_count,outside_unexpected_admission_count
  integer :: outside_fail_closed_count,route_identity_violation_count
  integer :: authorized_pairwise_valid_count,authorized_admissible_count,authorized_discrepancy_fail_count
  integer :: authorized_route_invalid_count,authorized_reference_invalid_count
  integer :: fail_h_inf,fail_h_rms,fail_theta_inf,fail_theta_rms,fail_storage

  case_id=0
  inside_count=0; boundary_count=0; outside_count=0
  transfer_valid_count=0; transfer_invalid_count=0; authorized_science_count=0
  reference_invalid_count=0; rossfast_init_failure_count=0
  route_expected_valid_count=0; route_expected_invalid_count=0
  route_actual_valid_count=0; route_actual_invalid_count=0
  route_mismatch_count=0; inside_rejected_count=0; boundary_rejected_count=0
  outside_unexpected_admission_count=0; outside_fail_closed_count=0; route_identity_violation_count=0
  authorized_pairwise_valid_count=0; authorized_admissible_count=0; authorized_discrepancy_fail_count=0
  authorized_route_invalid_count=0; authorized_reference_invalid_count=0
  fail_h_inf=0; fail_h_rms=0; fail_theta_inf=0; fail_theta_rms=0; fail_storage=0

  do ise=1,nse
    write(*,'(*(g0))') 'PUB_P2E16B_THRESHOLD|SE=',se_levels(ise), &
         '|D_H_INF=',th_h_inf(ise),'|D_H_RMS=',th_h_rms(ise), &
         '|D_THETA_INF=',th_theta_inf(ise),'|D_THETA_RMS=',th_theta_rms(ise), &
         '|D_STORAGE=',th_storage(ise)
  end do

  do imat=1,nmat
    do ise=1,nse
      do iaxis=1,naxis
        do irho=1,nrho
          case_id=case_id+1
          call run_case(case_id,ise,material_ids(imat),se_levels(ise),axis_ids(iaxis),rho_levels(irho))
        end do
      end do
    end do
  end do

  call require(case_id==expected_cases,'exact 1296-case matrix attempted')
  call require(inside_count==432,'inside case cardinality preserved')
  call require(boundary_count==432,'boundary case cardinality preserved')
  call require(outside_count==432,'outside case cardinality preserved')
  call require(transfer_invalid_count==27,'Stage-A threshold-transfer invalid mask preserved')
  call require(transfer_valid_count==1269,'Stage-A threshold-transfer valid count preserved')
  call require(authorized_science_count==850,'pairwise scientific claim population preserved')
  call require(route_expected_valid_count==864,'expected route-valid population preserved')
  call require(route_expected_invalid_count==432,'expected route-invalid population preserved')

  write(*,'(A,I0)') 'PUB_P2E16B_CASE_COUNT=',case_id
  write(*,'(A,I0)') 'PUB_P2E16B_INSIDE_COUNT=',inside_count
  write(*,'(A,I0)') 'PUB_P2E16B_BOUNDARY_COUNT=',boundary_count
  write(*,'(A,I0)') 'PUB_P2E16B_OUTSIDE_COUNT=',outside_count
  write(*,'(A,I0)') 'PUB_P2E16B_TRANSFER_VALID_COUNT=',transfer_valid_count
  write(*,'(A,I0)') 'PUB_P2E16B_TRANSFER_INVALID_COUNT=',transfer_invalid_count
  write(*,'(A,I0)') 'PUB_P2E16B_AUTHORIZED_SCIENCE_COUNT=',authorized_science_count
  write(*,'(A,I0)') 'PUB_P2E16B_REFERENCE_INVALID_COUNT=',reference_invalid_count
  write(*,'(A,I0)') 'PUB_P2E16B_ROSSFAST_INIT_FAILURE_COUNT=',rossfast_init_failure_count
  write(*,'(A,I0)') 'PUB_P2E16B_ROUTE_EXPECTED_VALID_COUNT=',route_expected_valid_count
  write(*,'(A,I0)') 'PUB_P2E16B_ROUTE_EXPECTED_INVALID_COUNT=',route_expected_invalid_count
  write(*,'(A,I0)') 'PUB_P2E16B_ROUTE_ACTUAL_VALID_COUNT=',route_actual_valid_count
  write(*,'(A,I0)') 'PUB_P2E16B_ROUTE_ACTUAL_INVALID_COUNT=',route_actual_invalid_count
  write(*,'(A,I0)') 'PUB_P2E16B_ROUTE_MISMATCH_COUNT=',route_mismatch_count
  write(*,'(A,I0)') 'PUB_P2E16B_INSIDE_REJECTED_COUNT=',inside_rejected_count
  write(*,'(A,I0)') 'PUB_P2E16B_BOUNDARY_REJECTED_COUNT=',boundary_rejected_count
  write(*,'(A,I0)') 'PUB_P2E16B_OUTSIDE_FAIL_CLOSED_COUNT=',outside_fail_closed_count
  write(*,'(A,I0)') 'PUB_P2E16B_OUTSIDE_UNEXPECTED_ADMISSION_COUNT=',outside_unexpected_admission_count
  write(*,'(A,I0)') 'PUB_P2E16B_ROUTE_IDENTITY_VIOLATION_COUNT=',route_identity_violation_count
  write(*,'(A,I0)') 'PUB_P2E16B_AUTHORIZED_PAIRWISE_VALID_COUNT=',authorized_pairwise_valid_count
  write(*,'(A,I0)') 'PUB_P2E16B_AUTHORIZED_ADMISSIBLE_COUNT=',authorized_admissible_count
  write(*,'(A,I0)') 'PUB_P2E16B_AUTHORIZED_DISCREPANCY_FAIL_COUNT=',authorized_discrepancy_fail_count
  write(*,'(A,I0)') 'PUB_P2E16B_AUTHORIZED_ROUTE_INVALID_COUNT=',authorized_route_invalid_count
  write(*,'(A,I0)') 'PUB_P2E16B_AUTHORIZED_REFERENCE_INVALID_COUNT=',authorized_reference_invalid_count
  write(*,'(A,I0)') 'PUB_P2E16B_FAIL_D_H_INF_COUNT=',fail_h_inf
  write(*,'(A,I0)') 'PUB_P2E16B_FAIL_D_H_RMS_COUNT=',fail_h_rms
  write(*,'(A,I0)') 'PUB_P2E16B_FAIL_D_THETA_INF_COUNT=',fail_theta_inf
  write(*,'(A,I0)') 'PUB_P2E16B_FAIL_D_THETA_RMS_COUNT=',fail_theta_rms
  write(*,'(A,I0)') 'PUB_P2E16B_FAIL_D_STORAGE_COUNT=',fail_storage
  write(*,'(A)') 'PUB_P2E16B_LAYER=A_FIXED_INTERVAL_SOLVER_SEAM'
  write(*,'(A)') 'PUB_P2E16B_STEP_DURATION_DAY=0.0016'
  write(*,'(A)') 'PUB_P2E16B_P2E14_THRESHOLDS_CHANGED=FALSE'
  write(*,'(A)') 'PUB_P2E16B_STAGE_A_MASK_CHANGED=FALSE'
  write(*,'(A)') 'PUB_P2E16B_PERFORMANCE_CLAIM_EVALUATED=FALSE'
  write(*,'(A)') 'PUB_P2E16B_SCIENTIFIC_RESULT_IS_CI_FAILURE=FALSE'
  write(*,'(A)') 'PUB_P2E16B_CANDIDATE_BOUNDARY_PRIMARY_GATE=PASS'

contains

  subroutine run_case(id,ise,material_id,se,axis_id,rho)
    integer,intent(in) :: id,ise
    character(len=*),intent(in) :: material_id,axis_id
    real(real64),intent(in) :: se,rho

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
    real(real64) :: h0,k_top,k_bottom,top_ref_internal,top_limit,bottom_ref,bottom_limit,qtop,qbot
    real(real64) :: storage_reference,storage_alternative
    real(real64) :: dh_inf,dh_rms,dtheta_inf,dtheta_rms,dstorage
    logical :: found,initialized,reference_valid,rossfast_valid,transfer_valid,authorized
    logical :: pass_h_inf,pass_h_rms,pass_theta_inf,pass_theta_rms,pass_storage,all_pass
    logical :: expected_valid,outside_case,boundary_case,route_identity_ok
    character(len=48) :: route_status,science_status

    call rossfast_d3r_material_from_id(material_id,material,found)
    call require(found,'material authority available')

    h0=head_from_effective_saturation(se,material)
    call require(ieee_is_finite(h0) .and. h0>ROSSFAST_D3R_H_MIN_CM .and. h0<ROSSFAST_D3R_H_MAX_CM, &
         'initial state inside E0 head domain')

    call initialize_parameter_contract(parameters,cofgen,material,id)
    call initialize_b110_default_mvg_parameters(hydraulic_parameters,cofgen)
    call bind_b110_default_mvg_provider(constitutive,hydraulic_parameters,ROSSFAST_D3R_OUTER_HORIZON_DAY)
    heads=h0
    call constitutive%evaluate(heads,theta0,conductivity,capacity,dkdh)
    call require(all(ieee_is_finite(theta0)) .and. all(ieee_is_finite(conductivity)) .and. all(conductivity>0.0_real64), &
         'initial constitutive state finite and positive')
    k_top=conductivity(1)
    k_bottom=conductivity(n)

    top_ref_internal=0.01_real64*k_top
    top_limit=ROSSFAST_D3R_BOUNDARY_ENVELOPE_FRACTION*max(abs(top_ref_internal),abs(k_top),1.0e-12_real64)
    bottom_ref=-0.004_real64*k_bottom
    bottom_limit=ROSSFAST_D3R_BOUNDARY_ENVELOPE_FRACTION*max(abs(bottom_ref),abs(k_bottom),1.0e-12_real64)

    select case(trim(axis_id))
    case('TOP')
      qtop=-(top_ref_internal+rho*top_limit)
      qbot=bottom_ref
    case('BOTTOM')
      qtop=-top_ref_internal
      qbot=bottom_ref+rho*bottom_limit
    case default
      call require(.false.,'known boundary axis')
    end select

    drainage=0.0_real64; irrigation=0.0_real64; root_sink=0.0_real64
    call bind_b110_source_sink_provider(source_sink,drainage,irrigation,root_sink)
    call initialize_common_request(request,parameters,constitutive,source_sink,top_boundary,theta0,h0,qtop,qbot)

    call reference_solver%solve(request,reference_workspace,reference_result)
    call alternative_solver%initialize('assets/rossfast/d3r',material_id,initialized)
    if (.not.initialized) then
      rossfast_init_failure_count=rossfast_init_failure_count+1
    else
      call alternative_solver%solve(request,alternative_workspace,alternative_result)
    end if

    reference_valid=reference_route_valid(reference_result,request,material)
    rossfast_valid=.false.
    if (initialized) rossfast_valid=rossfast_route_valid(alternative_result,request,material)

    if (.not.reference_valid) reference_invalid_count=reference_invalid_count+1
    if (rossfast_valid) then
      route_actual_valid_count=route_actual_valid_count+1
    else
      route_actual_invalid_count=route_actual_invalid_count+1
    end if

    outside_case=abs(rho)>1.0_real64
    boundary_case=abs(rho)==1.0_real64
    expected_valid=.not.outside_case
    if (expected_valid) then
      route_expected_valid_count=route_expected_valid_count+1
    else
      route_expected_invalid_count=route_expected_invalid_count+1
    end if

    if (abs(rho)<1.0_real64) then
      inside_count=inside_count+1
    else if (boundary_case) then
      boundary_count=boundary_count+1
    else
      outside_count=outside_count+1
    end if

    transfer_valid=threshold_transfer_valid(id)
    if (transfer_valid) then
      transfer_valid_count=transfer_valid_count+1
    else
      transfer_invalid_count=transfer_invalid_count+1
    end if
    authorized=transfer_valid .and. expected_valid
    if (authorized) authorized_science_count=authorized_science_count+1

    route_identity_ok=.true.
    if (initialized) then
      if (rossfast_valid) then
        route_identity_ok=trim(alternative_result%diagnostics%route)=='rossfast-d3r'
      else
        route_identity_ok=trim(alternative_result%diagnostics%route)=='rossfast-d3r-rejected'
      end if
    end if
    if (.not.route_identity_ok) route_identity_violation_count=route_identity_violation_count+1

    route_status='UNCLASSIFIED'
    if (.not.reference_valid .and. .not.rossfast_valid) then
      route_status='BOTH_ROUTES_INVALID'
    else if (.not.reference_valid) then
      route_status='REFERENCE_ROUTE_INVALID'
    else if (outside_case) then
      if (rossfast_valid) then
        route_status='UNEXPECTED_OUTSIDE_ADMITTED'
        outside_unexpected_admission_count=outside_unexpected_admission_count+1
        route_mismatch_count=route_mismatch_count+1
      else
        route_status='EXPECTED_OUTSIDE_REJECTED'
        if (route_identity_ok .and. initialized) outside_fail_closed_count=outside_fail_closed_count+1
      end if
    else if (boundary_case) then
      if (rossfast_valid) then
        route_status='EXPECTED_BOUNDARY_ADMITTED'
      else
        route_status='UNEXPECTED_BOUNDARY_REJECTED'
        boundary_rejected_count=boundary_rejected_count+1
        route_mismatch_count=route_mismatch_count+1
      end if
    else
      if (rossfast_valid) then
        route_status='EXPECTED_INSIDE_ADMITTED'
      else
        route_status='UNEXPECTED_INSIDE_REJECTED'
        inside_rejected_count=inside_rejected_count+1
        route_mismatch_count=route_mismatch_count+1
      end if
    end if

    science_status='NOT_APPLICABLE'
    dh_inf=0.0_real64; dh_rms=0.0_real64
    dtheta_inf=0.0_real64; dtheta_rms=0.0_real64; dstorage=0.0_real64
    pass_h_inf=.false.; pass_h_rms=.false.; pass_theta_inf=.false.; pass_theta_rms=.false.; pass_storage=.false.

    if (.not.transfer_valid) then
      science_status='NOT_AUTHORIZED_TRANSFER_INVALID'
    else if (outside_case) then
      science_status='NOT_APPLICABLE_OUTSIDE'
    else if (.not.reference_valid) then
      science_status='NOT_APPLICABLE_REFERENCE_INVALID'
      if (authorized) authorized_reference_invalid_count=authorized_reference_invalid_count+1
    else if (.not.rossfast_valid) then
      science_status='NOT_APPLICABLE_ROUTE_INVALID'
      if (authorized) authorized_route_invalid_count=authorized_route_invalid_count+1
    else
      authorized_pairwise_valid_count=authorized_pairwise_valid_count+1
      storage_reference=sum(parameters%dz*reference_result%candidate_state%water_content)+ &
           reference_result%candidate_state%ponding_depth
      storage_alternative=sum(parameters%dz*alternative_result%candidate_state%water_content)+ &
           alternative_result%candidate_state%ponding_depth
      dh_inf=maxval(abs(alternative_result%candidate_state%pressure_head-reference_result%candidate_state%pressure_head))
      dh_rms=sqrt(sum((alternative_result%candidate_state%pressure_head-reference_result%candidate_state%pressure_head)**2)/real(n,real64))
      dtheta_inf=maxval(abs(alternative_result%candidate_state%water_content-reference_result%candidate_state%water_content))
      dtheta_rms=sqrt(sum((alternative_result%candidate_state%water_content-reference_result%candidate_state%water_content)**2)/real(n,real64))
      dstorage=abs(storage_alternative-storage_reference)
      call require(ieee_is_finite(dh_inf) .and. ieee_is_finite(dh_rms) .and. ieee_is_finite(dtheta_inf) .and. &
           ieee_is_finite(dtheta_rms) .and. ieee_is_finite(dstorage),'authorized paired metrics finite')

      pass_h_inf=dh_inf<=th_h_inf(ise)
      pass_h_rms=dh_rms<=th_h_rms(ise)
      pass_theta_inf=dtheta_inf<=th_theta_inf(ise)
      pass_theta_rms=dtheta_rms<=th_theta_rms(ise)
      pass_storage=dstorage<=th_storage(ise)
      all_pass=pass_h_inf .and. pass_h_rms .and. pass_theta_inf .and. pass_theta_rms .and. pass_storage
      if (all_pass) then
        science_status='PAIRWISE_ADMISSIBLE'
        authorized_admissible_count=authorized_admissible_count+1
      else
        science_status='PAIRWISE_DISCREPANCY_FAIL'
        authorized_discrepancy_fail_count=authorized_discrepancy_fail_count+1
      end if
      if (.not.pass_h_inf) fail_h_inf=fail_h_inf+1
      if (.not.pass_h_rms) fail_h_rms=fail_h_rms+1
      if (.not.pass_theta_inf) fail_theta_inf=fail_theta_inf+1
      if (.not.pass_theta_rms) fail_theta_rms=fail_theta_rms+1
      if (.not.pass_storage) fail_storage=fail_storage+1
    end if

    write(*,'(*(g0))') 'PUB_P2E16B_CASE|CASE=',id,'|M=',trim(material_id),'|SE=',se, &
         '|AXIS=',trim(axis_id),'|RHO=',rho,'|TRANSFER_VALID=',transfer_valid,'|QTOP=',qtop,'|QBOT=',qbot, &
         '|REF_VALID=',reference_valid,'|ROSS_INIT=',initialized,'|ROSS_VALID=',rossfast_valid, &
         '|ROUTE=',trim(route_status),'|SCIENCE=',trim(science_status), &
         '|D_H_INF=',dh_inf,'|D_H_RMS=',dh_rms,'|D_THETA_INF=',dtheta_inf,'|D_THETA_RMS=',dtheta_rms, &
         '|D_STORAGE=',dstorage,'|PASS_H_INF=',pass_h_inf,'|PASS_H_RMS=',pass_h_rms, &
         '|PASS_THETA_INF=',pass_theta_inf,'|PASS_THETA_RMS=',pass_theta_rms,'|PASS_STORAGE=',pass_storage

    if (reference_result%integrated_mass_balance_residual_available) then
      write(*,'(*(g0))') 'PUB_P2E16B_REFERENCE_MASS|CASE=',id,'|CM=',reference_result%integrated_mass_balance_residual_cm, &
           '|RATE_AVAILABLE=',reference_result%native_balance_rate_residual_available, &
           '|RATE=',reference_result%native_balance_rate_residual_cm_per_day
    else
      write(*,'(*(g0))') 'PUB_P2E16B_REFERENCE_MASS|CASE=',id,'|AVAILABLE=FALSE'
    end if
    if (initialized .and. alternative_result%integrated_mass_balance_residual_available) then
      write(*,'(*(g0))') 'PUB_P2E16B_ROSSFAST_MASS|CASE=',id,'|CM=',alternative_result%integrated_mass_balance_residual_cm, &
           '|RATE_AVAILABLE=',alternative_result%native_balance_rate_residual_available, &
           '|ROUTE=',trim(alternative_result%diagnostics%route)
    else if (initialized) then
      write(*,'(*(g0))') 'PUB_P2E16B_ROSSFAST_MASS|CASE=',id,'|AVAILABLE=FALSE|ROUTE=', &
           trim(alternative_result%diagnostics%route)
    else
      write(*,'(*(g0))') 'PUB_P2E16B_ROSSFAST_MASS|CASE=',id,'|INITIALIZED=FALSE'
    end if
  end subroutine run_case

  logical function threshold_transfer_valid(id) result(ok)
    integer,intent(in) :: id
    ok=.not.any(transfer_invalid_ids==id)
  end function threshold_transfer_valid

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
    if (any(.not.ieee_is_finite(result%candidate_state%pressure_head)) .or. &
        any(.not.ieee_is_finite(result%candidate_state%water_content))) return
    if (any(result%candidate_state%pressure_head<=ROSSFAST_D3R_H_MIN_CM) .or. &
        any(result%candidate_state%pressure_head>=ROSSFAST_D3R_H_MAX_CM)) return
    if (any(result%candidate_state%water_content<=material%theta_r) .or. &
        any(result%candidate_state%water_content>=material%theta_s)) return
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

  subroutine initialize_parameter_contract(parameter_set,cofgen_out,mat,id)
    type(soil_water_parameter_set_t),target,intent(out) :: parameter_set
    real(real64),intent(out) :: cofgen_out(24,n)
    type(rossfast_d3r_material_t),intent(in) :: mat
    integer,intent(in) :: id
    real(real64) :: m
    integer :: i
    m=1.0_real64-1.0_real64/mat%n
    parameter_set%parameter_set_id=922000+id
    parameter_set%active_nodes=n
    allocate(parameter_set%z(n),parameter_set%dz(n),parameter_set%node_distance(n))
    do i=1,n
      parameter_set%z(i)=-ROSSFAST_D3R_DZ_CM*(real(i,real64)-0.5_real64)
    end do
    parameter_set%dz=ROSSFAST_D3R_DZ_CM
    parameter_set%node_distance=ROSSFAST_D3R_DZ_CM
    cofgen_out=0.0_real64
    do i=1,n
      cofgen_out(1,i)=mat%theta_r; cofgen_out(2,i)=mat%theta_s; cofgen_out(3,i)=mat%ksatfit_cm_per_day
      cofgen_out(4,i)=mat%alpha_per_cm; cofgen_out(5,i)=mat%lambda; cofgen_out(6,i)=mat%n
      cofgen_out(7,i)=m; cofgen_out(8,i)=mat%alpha_per_cm; cofgen_out(9,i)=mat%h_enpr_cm
      cofgen_out(10,i)=mat%ksatfit_cm_per_day; cofgen_out(11,i)=0.999_real64
      cofgen_out(12,i)=0.99_real64*mat%ksatfit_cm_per_day
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
    req%parameters=>parameter_set
    req%base_state%active_nodes=n
    allocate(req%base_state%pressure_head(n),req%base_state%water_content(n))
    req%base_state%pressure_head=h0
    req%base_state%water_content=theta
    req%base_state%ponding_depth=0.0_real64
    req%base_state%groundwater_level=-999.0_real64
    req%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX
    req%boundary%bottom_mode=2
    req%boundary%top_flux=qtop
    req%boundary%top_head=h0
    req%boundary%bottom_flux=qbot
    req%boundary%bottom_head=-999999.0_real64
    req%physical%macropore_active=.false.
    req%numerical%max_iterations=16
    req%numerical%max_backtracking=8
    req%numerical%conductivity_implicit_mode=0
    req%numerical%conductivity_mean_method=1
    req%numerical%min_step_duration=1.0e-8_real64
    req%numerical%compartment_balance_tolerance=reference_internal_balance_rate_tol_cm_per_day
    req%numerical%total_balance_tolerance=reference_internal_balance_rate_tol_cm_per_day
    req%numerical%head_abs_tolerance=1.0e-12_real64
    req%numerical%head_rel_tolerance=1.0e-12_real64
    req%numerical%ponding_tolerance=1.0e-12_real64
    req%step_duration=ROSSFAST_D3R_OUTER_HORIZON_DAY
    req%request_interface_sensitivity=.false.
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
      write(*,'(A,1X,A)') 'PUB_P2E16B_HARNESS_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_pub_p2e16b_candidate_boundary_primary

program test_pub_p2e17_top_boundary_primary
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
       ROSSFAST_D3R_H_MIN_CM, ROSSFAST_D3R_H_MAX_CM
  use mod_rossfast_d3r_execution_policy, only: ROSSFAST_D3R_OUTER_HORIZON_DAY
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  implicit none

  integer, parameter :: n = ROSSFAST_D3R_N_CELLS
  integer, parameter :: nmat=36, nse=3, nforcing=3, expected_cases=nmat*nse*nforcing
  real(real64), parameter :: reference_internal_balance_rate_tol_cm_per_day = 1.0e-12_real64
  character(len=3), parameter :: material_ids(nmat) = [character(len=3) :: &
       'B01','B02','B03','B04','B05','B06','B07','B08','B09','B10','B11','B12','B13','B14','B15','B16','B17','B18', &
       'O01','O02','O03','O04','O05','O06','O07','O08','O09','O10','O11','O12','O13','O14','O15','O16','O17','O18']
  character(len=8), parameter :: forcing_ids(nforcing) = [character(len=8) :: 'INSIDE  ','BOUNDARY','OUTSIDE ']
  real(real64), parameter :: se_levels(nse) = [0.65_real64,0.85_real64,0.96_real64]
  real(real64), parameter :: qtop_factor(nforcing) = [0.009_real64,0.010_real64,0.011_real64]
  real(real64), parameter :: qbot_factor(nforcing) = [-0.004_real64,-0.004_real64,-0.004_real64]

  real(real64), parameter :: th_h_inf(nse) = [ &
       0.009310899886486368_real64, 0.05684414280500505_real64, 0.738635792031854_real64 ]
  real(real64), parameter :: th_h_rms(nse) = [ &
       0.004266323114394112_real64, 0.023100142698779337_real64, 0.19122535147617015_real64 ]
  real(real64), parameter :: th_theta_inf(nse) = [ &
       0.000017908123244203544_real64, 0.00024393588764148877_real64, 0.0012274135237742567_real64 ]
  real(real64), parameter :: th_theta_rms(nse) = [ &
       0.000006579479242237575_real64, 0.00008095669952969204_real64, 0.00035749635175526273_real64 ]
  real(real64), parameter :: th_storage(nse) = [ &
       1.4210854715202004e-14_real64, 2.8421709430404007e-14_real64, 2.8421709430404007e-14_real64 ]

  integer :: imat, ise, iforce, case_id
  integer :: count_admissible, count_discrepancy_fail, count_reference_invalid, count_rossfast_invalid, count_both_invalid
  integer :: fail_h_inf, fail_h_rms, fail_theta_inf, fail_theta_rms, fail_storage
  integer :: label_admissible(nforcing), label_discrepancy_fail(nforcing)
  integer :: label_reference_invalid(nforcing), label_rossfast_invalid(nforcing), label_both_invalid(nforcing)
  integer :: route_expectation_match, route_expectation_mismatch
  character(len=40) :: classification
  real(real64) :: dh_inf, dh_rms, dtheta_inf, dtheta_rms, dstorage
  logical :: metrics_available
  logical :: pass_h_inf, pass_h_rms, pass_theta_inf, pass_theta_rms, pass_storage

  count_admissible=0
  count_discrepancy_fail=0
  count_reference_invalid=0
  count_rossfast_invalid=0
  count_both_invalid=0
  fail_h_inf=0
  fail_h_rms=0
  fail_theta_inf=0
  fail_theta_rms=0
  fail_storage=0
  label_admissible=0; label_discrepancy_fail=0
  label_reference_invalid=0; label_rossfast_invalid=0; label_both_invalid=0
  route_expectation_match=0; route_expectation_mismatch=0
  case_id=0

  do ise=1,nse
    write(*,'(*(g0))') 'PUB_P2E17_THRESHOLD|SE=',se_levels(ise), &
         '|D_H_INF=',th_h_inf(ise),'|D_H_RMS=',th_h_rms(ise), &
         '|D_THETA_INF=',th_theta_inf(ise),'|D_THETA_RMS=',th_theta_rms(ise), &
         '|D_STORAGE=',th_storage(ise)
  end do

  do imat=1,nmat
    do ise=1,nse
      do iforce=1,nforcing
        case_id=case_id+1
        call run_case(case_id,ise,material_ids(imat),se_levels(ise),forcing_ids(iforce), &
             qtop_factor(iforce),qbot_factor(iforce),classification,metrics_available, &
             dh_inf,dh_rms,dtheta_inf,dtheta_rms,dstorage, &
             pass_h_inf,pass_h_rms,pass_theta_inf,pass_theta_rms,pass_storage)

        select case(trim(classification))
        case('PAIRED_VALID_ADMISSIBLE')
          count_admissible=count_admissible+1
          label_admissible(iforce)=label_admissible(iforce)+1
        case('PAIRED_VALID_DISCREPANCY_FAIL')
          count_discrepancy_fail=count_discrepancy_fail+1
          label_discrepancy_fail(iforce)=label_discrepancy_fail(iforce)+1
        case('REFERENCE_ROUTE_INVALID')
          count_reference_invalid=count_reference_invalid+1
          label_reference_invalid(iforce)=label_reference_invalid(iforce)+1
        case('ROSSFAST_ROUTE_INVALID')
          count_rossfast_invalid=count_rossfast_invalid+1
          label_rossfast_invalid(iforce)=label_rossfast_invalid(iforce)+1
        case('BOTH_ROUTES_INVALID')
          count_both_invalid=count_both_invalid+1
          label_both_invalid(iforce)=label_both_invalid(iforce)+1
        case default
          call require(.false.,'unknown scientific classification')
        end select

        if (iforce <= 2) then
          if (trim(classification)=='PAIRED_VALID_ADMISSIBLE' .or. &
              trim(classification)=='PAIRED_VALID_DISCREPANCY_FAIL') then
            route_expectation_match=route_expectation_match+1
          else
            route_expectation_mismatch=route_expectation_mismatch+1
          end if
        else
          if (trim(classification)=='ROSSFAST_ROUTE_INVALID') then
            route_expectation_match=route_expectation_match+1
          else
            route_expectation_mismatch=route_expectation_mismatch+1
          end if
        end if

        if (metrics_available) then
          if (.not.pass_h_inf) fail_h_inf=fail_h_inf+1
          if (.not.pass_h_rms) fail_h_rms=fail_h_rms+1
          if (.not.pass_theta_inf) fail_theta_inf=fail_theta_inf+1
          if (.not.pass_theta_rms) fail_theta_rms=fail_theta_rms+1
          if (.not.pass_storage) fail_storage=fail_storage+1
        end if
      end do
    end do
  end do

  call require(case_id==expected_cases,'exact 324-case top-boundary matrix attempted')
  call require(count_admissible+count_discrepancy_fail+count_reference_invalid+count_rossfast_invalid+count_both_invalid == &
       expected_cases,'every broad case classified exactly once')

  write(*,'(A,I0)') 'PUB_P2E17_CASE_COUNT=',case_id
  write(*,'(A,I0)') 'PUB_P2E17_ADMISSIBLE_COUNT=',count_admissible
  write(*,'(A,I0)') 'PUB_P2E17_DISCREPANCY_FAIL_COUNT=',count_discrepancy_fail
  write(*,'(A,I0)') 'PUB_P2E17_REFERENCE_INVALID_COUNT=',count_reference_invalid
  write(*,'(A,I0)') 'PUB_P2E17_ROSSFAST_INVALID_COUNT=',count_rossfast_invalid
  write(*,'(A,I0)') 'PUB_P2E17_BOTH_INVALID_COUNT=',count_both_invalid
  write(*,'(A,I0)') 'PUB_P2E17_FAIL_D_H_INF_COUNT=',fail_h_inf
  write(*,'(A,I0)') 'PUB_P2E17_FAIL_D_H_RMS_COUNT=',fail_h_rms
  write(*,'(A,I0)') 'PUB_P2E17_FAIL_D_THETA_INF_COUNT=',fail_theta_inf
  write(*,'(A,I0)') 'PUB_P2E17_FAIL_D_THETA_RMS_COUNT=',fail_theta_rms
  write(*,'(A,I0)') 'PUB_P2E17_FAIL_D_STORAGE_COUNT=',fail_storage
  write(*,'(A,I0)') 'PUB_P2E17_ROUTE_EXPECTATION_MATCH_COUNT=',route_expectation_match
  write(*,'(A,I0)') 'PUB_P2E17_ROUTE_EXPECTATION_MISMATCH_COUNT=',route_expectation_mismatch
  do iforce=1,nforcing
    write(*,'(*(g0))') 'PUB_P2E17_LABEL_SUMMARY|LABEL=',trim(forcing_ids(iforce)), &
         '|ADMISSIBLE=',label_admissible(iforce),'|DISCREPANCY_FAIL=',label_discrepancy_fail(iforce), &
         '|REFERENCE_INVALID=',label_reference_invalid(iforce),'|ROSSFAST_INVALID=',label_rossfast_invalid(iforce), &
         '|BOTH_INVALID=',label_both_invalid(iforce)
  end do
  write(*,'(A)') 'PUB_P2E17_LAYER=A_FIXED_INTERVAL_SOLVER_SEAM'
  write(*,'(A)') 'PUB_P2E17_STEP_DURATION_DAY=0.0016'
  write(*,'(A)') 'PUB_P2E17_THRESHOLDS_RETUNED=FALSE'
  write(*,'(A)') 'PUB_P2E17_BOUNDARY_MOVED=FALSE'
  write(*,'(A)') 'PUB_P2E17_TRANSACTION_LEVEL_PAIR_EXECUTED=FALSE'
  write(*,'(A)') 'PUB_P2E17_PERFORMANCE_CLAIM_EVALUATED=FALSE'
  write(*,'(A)') 'PUB_P2E17_TOP_BOUNDARY_PRIMARY_GATE=PASS'

contains

  subroutine run_case(case_id,ise,material_id,se,forcing_id,top_factor,bottom_factor,classification,metrics_available, &
       dh_inf,dh_rms,dtheta_inf,dtheta_rms,dstorage,pass_h_inf,pass_h_rms,pass_theta_inf,pass_theta_rms,pass_storage)
    integer,intent(in) :: case_id,ise
    character(len=*),intent(in) :: material_id,forcing_id
    real(real64),intent(in) :: se,top_factor,bottom_factor
    character(len=*),intent(out) :: classification
    logical,intent(out) :: metrics_available
    real(real64),intent(out) :: dh_inf,dh_rms,dtheta_inf,dtheta_rms,dstorage
    logical,intent(out) :: pass_h_inf,pass_h_rms,pass_theta_inf,pass_theta_rms,pass_storage

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
    real(real64) :: h0,k0,storage_reference,storage_alternative
    logical :: found,initialized,reference_valid,rossfast_valid
    integer :: provider_status

    classification='UNCLASSIFIED'
    metrics_available=.false.
    dh_inf=0.0_real64; dh_rms=0.0_real64
    dtheta_inf=0.0_real64; dtheta_rms=0.0_real64; dstorage=0.0_real64
    pass_h_inf=.false.; pass_h_rms=.false.
    pass_theta_inf=.false.; pass_theta_rms=.false.; pass_storage=.false.

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
    k0=conductivity(1)

    drainage=0.0_real64; irrigation=0.0_real64; root_sink=0.0_real64
    call bind_b110_source_sink_provider(source_sink,drainage,irrigation,root_sink)
    call initialize_common_request(request,parameters,constitutive,source_sink,top_boundary,theta0,h0, &
         top_factor*k0,bottom_factor*k0)

    call reference_solver%solve(request,reference_workspace,reference_result)

    call alternative_solver%initialize('assets/rossfast/d3r',material_id,initialized,provider_status)
    if (initialized) then
      call alternative_solver%solve(request,alternative_workspace,alternative_result)
    end if

    reference_valid=reference_route_valid(reference_result,request,material)
    rossfast_valid=initialized
    if (rossfast_valid) rossfast_valid=rossfast_route_valid(alternative_result,request,material)

    if (.not.reference_valid .and. .not.rossfast_valid) then
      classification='BOTH_ROUTES_INVALID'
    else if (.not.reference_valid) then
      classification='REFERENCE_ROUTE_INVALID'
    else if (.not.rossfast_valid) then
      classification='ROSSFAST_ROUTE_INVALID'
    else
      metrics_available=.true.
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
           ieee_is_finite(dtheta_rms) .and. ieee_is_finite(dstorage),'paired discrepancy metrics finite')

      pass_h_inf=dh_inf<=th_h_inf(ise)
      pass_h_rms=dh_rms<=th_h_rms(ise)
      pass_theta_inf=dtheta_inf<=th_theta_inf(ise)
      pass_theta_rms=dtheta_rms<=th_theta_rms(ise)
      pass_storage=dstorage<=th_storage(ise)

      if (pass_h_inf .and. pass_h_rms .and. pass_theta_inf .and. pass_theta_rms .and. pass_storage) then
        classification='PAIRED_VALID_ADMISSIBLE'
      else
        classification='PAIRED_VALID_DISCREPANCY_FAIL'
      end if
    end if

    write(*,'(*(g0))') 'PUB_P2E17_CASE|CASE=',case_id,'|M=',trim(material_id),'|SE=',se, &
         '|F=',trim(forcing_id),'|DT=',ROSSFAST_D3R_OUTER_HORIZON_DAY,'|CLASS=',trim(classification), &
         '|REF_STATUS=',reference_result%status,'|ROSS_INIT=',initialized,'|METRICS=',metrics_available, &
         '|D_H_INF=',dh_inf,'|D_H_RMS=',dh_rms,'|D_THETA_INF=',dtheta_inf,'|D_THETA_RMS=',dtheta_rms, &
         '|D_STORAGE=',dstorage,'|PASS_H_INF=',pass_h_inf,'|PASS_H_RMS=',pass_h_rms, &
         '|PASS_THETA_INF=',pass_theta_inf,'|PASS_THETA_RMS=',pass_theta_rms,'|PASS_STORAGE=',pass_storage

    if (reference_result%integrated_mass_balance_residual_available) then
      write(*,'(*(g0))') 'PUB_P2E17_REFERENCE_MASS|CASE=',case_id,'|CM=',reference_result%integrated_mass_balance_residual_cm, &
           '|RATE_AVAILABLE=',reference_result%native_balance_rate_residual_available, &
           '|RATE=',reference_result%native_balance_rate_residual_cm_per_day
    else
      write(*,'(*(g0))') 'PUB_P2E17_REFERENCE_MASS|CASE=',case_id,'|AVAILABLE=FALSE'
    end if

    if (initialized .and. alternative_result%integrated_mass_balance_residual_available) then
      write(*,'(*(g0))') 'PUB_P2E17_ROSSFAST_MASS|CASE=',case_id,'|CM=',alternative_result%integrated_mass_balance_residual_cm, &
           '|RATE_AVAILABLE=',alternative_result%native_balance_rate_residual_available
    else
      write(*,'(*(g0))') 'PUB_P2E17_ROSSFAST_MASS|CASE=',case_id,'|AVAILABLE=FALSE'
    end if
  end subroutine run_case

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
    parameter_set%parameter_set_id=921000+case_id
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
      write(*,'(A,1X,A)') 'PUB_P2E17_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_pub_p2e17_top_boundary_primary

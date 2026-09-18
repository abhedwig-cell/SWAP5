program test_ross20_all_material_adaptive
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
  integer, parameter :: nmat=36, nse=3, nforcing=2, expected_cases=nmat*nse*nforcing
  real(real64), parameter :: reference_internal_balance_rate_tol_cm_per_day = 1.0e-12_real64
  character(len=3), parameter :: material_ids(nmat) = [character(len=3) :: &
       'B01','B02','B03','B04','B05','B06','B07','B08','B09', &
       'B10','B11','B12','B13','B14','B15','B16','B17','B18', &
       'O01','O02','O03','O04','O05','O06','O07','O08','O09', &
       'O10','O11','O12','O13','O14','O15','O16','O17','O18']
  character(len=7), parameter :: forcing_ids(nforcing) = [character(len=7) :: 'DRYING ','NOMINAL']
  real(real64), parameter :: se_levels(nse) = [0.65_real64,0.85_real64,0.98_real64]
  real(real64), parameter :: qtop_factor(nforcing) = [-0.005_real64,0.010_real64]
  real(real64), parameter :: qbot_factor(nforcing) = [-0.019_real64,-0.004_real64]

  real(real64), parameter :: th_h_inf(nse) = [ &
       0.002329984405367469_real64, 0.024875926496918055_real64, 1.0304935719866082_real64 ]
  real(real64), parameter :: th_h_rms(nse) = [ &
       0.0008461192168990192_real64, 0.008913060711649613_real64, 0.26027530243065616_real64 ]
  real(real64), parameter :: th_theta_inf(nse) = [ &
       0.000014036839159875525_real64, 0.00009940338552821837_real64, 0.0006060020680420108_real64 ]
  real(real64), parameter :: th_theta_rms(nse) = [ &
       0.000005088115857112092_real64, 0.00003496499657040913_real64, 0.00017540588521301983_real64 ]
  real(real64), parameter :: th_storage(nse) = [ &
       2.1316282072803006e-14_real64, 2.1316282072803006e-14_real64, 2.842170943040401e-14_real64 ]

  integer :: imat, ise, iforce, case_id
  integer :: count_admissible, count_discrepancy_fail, count_reference_invalid, count_rossfast_invalid, count_both_invalid
  integer :: fail_h_inf, fail_h_rms, fail_theta_inf, fail_theta_rms, fail_storage
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
  case_id=0
  do ise=1,nse
    write(*,'(*(g0))') 'PUB_P2E10_THRESHOLD|SE=',se_levels(ise), &
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
        case('PAIRED_VALID_DISCREPANCY_FAIL')
          count_discrepancy_fail=count_discrepancy_fail+1
        case('REFERENCE_ROUTE_INVALID')
          count_reference_invalid=count_reference_invalid+1
        case('ROSSFAST_ROUTE_INVALID')
          count_rossfast_invalid=count_rossfast_invalid+1
        case('BOTH_ROUTES_INVALID')
          count_both_invalid=count_both_invalid+1
        case default
          call require(.false.,'unknown scientific classification')
        end select

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

  call require(case_id==expected_cases,'exact 216-case all-material production domain attempted')
  call require(count_reference_invalid==0 .and. count_both_invalid==0,'Reference authority must remain valid')
  write(*,'(A,I0)') 'F_ROSS20_CASE_COUNT=',case_id
  write(*,'(*(g0))') 'F_ROSS20_COUNTS|ADMISSIBLE=',count_admissible,'|DISCFAIL=',count_discrepancy_fail, &
       '|ROSSINVALID=',count_rossfast_invalid,'|REFINVALID=',count_reference_invalid,'|BOTHINVALID=',count_both_invalid
  write(*,'(A)') 'F_ROSS20_MATRIX_GATE=PASS'

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
    logical :: found,initialized,reference_valid,rossfast_valid,certificate_available
    integer :: provider_status,i
    real(real64) :: temporal_indicator

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
    certificate_available=.false.
    temporal_indicator=huge(0.0_real64)
    if (initialized) then
      call alternative_solver%solve(request,alternative_workspace,alternative_result)
      call alternative_solver%temporal_certificate_snapshot(certificate_available,temporal_indicator)
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

    if (rossfast_valid) then
      call require(certificate_available,'RossFast temporal certificate available')
      call require(ieee_is_finite(temporal_indicator) .and. temporal_indicator>=0.0_real64,'finite temporal indicator')
      call require(alternative_result%diagnostics%linear_solves==6 .or. &
           alternative_result%diagnostics%linear_solves==18,'adaptive RossFast work count must be 6 or 18')
      call require(alternative_result%diagnostics%internal_retries==0,'zero RossFast internal retries')
      call require(alternative_result%diagnostics%alternative_solver_calls==0,'zero RossFast alternative solver calls')
      write(*,'(*(g0))') 'F_ROSS20_CASE|CASE=',case_id,'|ISE=',ise,'|M=',trim(material_id),'|F=',trim(forcing_id), &
           '|CLASS=',trim(classification), &
           '|LIN=',alternative_result%diagnostics%linear_solves, &
           '|RETRY=',alternative_result%diagnostics%internal_retries, &
           '|ALT=',alternative_result%diagnostics%alternative_solver_calls, &
           '|FALLBACK=',merge(1,0,alternative_result%diagnostics%linear_solves==18), &
           '|MASS=',alternative_result%integrated_mass_balance_residual_cm, &
           '|TEMP=',temporal_indicator, &
           '|HINF=',dh_inf,'|HRMS=',dh_rms,'|TINF=',dtheta_inf,'|TRMS=',dtheta_rms,'|STORAGE=',dstorage
      write(*,'(A,I0,A)',advance='no') 'F_ROSS20_H|CASE=',case_id,'|'
      do i=1,n
        write(*,'(ES24.16E3,1X)',advance='no') alternative_result%candidate_state%pressure_head(i)
      end do
      write(*,*)
      write(*,'(A,I0,A)',advance='no') 'F_ROSS20_T|CASE=',case_id,'|'
      do i=1,n
        write(*,'(ES24.16E3,1X)',advance='no') alternative_result%candidate_state%water_content(i)
      end do
      write(*,*)
    else
      write(*,'(*(g0))') 'F_ROSS20_CASE|CASE=',case_id,'|ISE=',ise,'|M=',trim(material_id),'|F=',trim(forcing_id), &
           '|CLASS=',trim(classification),'|LIN=-1|RETRY=-1|ALT=-1|FALLBACK=-1|MASS=NaN|TEMP=NaN', &
           '|HINF=',dh_inf,'|HRMS=',dh_rms,'|TINF=',dtheta_inf,'|TRMS=',dtheta_rms,'|STORAGE=',dstorage
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
      write(*,'(A,1X,A)') 'F_ROSS20_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_ross20_all_material_adaptive

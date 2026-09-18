program test_pub_p2e16c_reference_fixed_step_adjudication
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_solve_request_t, &
       soil_water_solve_result_t, SW_SOLVE_CONVERGED, SW_SOLVE_RETRY_ADVISED
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, &
       reference_richards_legacy_workspace_t
  use mod_rossfast_d3r_model_binding, only: rossfast_d3r_material_t, rossfast_d3r_material_from_id, &
       ROSSFAST_D3R_N_CELLS, ROSSFAST_D3R_DZ_CM, ROSSFAST_D3R_H_MIN_CM, ROSSFAST_D3R_H_MAX_CM, &
       ROSSFAST_D3R_BOUNDARY_ENVELOPE_FRACTION
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  implicit none

  integer, parameter :: n=ROSSFAST_D3R_N_CELLS
  integer, parameter :: ncase=5, ndt=7, nseq=5
  real(real64), parameter :: publication_mass_tol_cm=1.0e-12_real64
  real(real64), parameter :: reference_balance_rate_tol=1.0e-12_real64
  integer, parameter :: original_case_id(ncase)=[576,612,1220,1248,1257]
  character(len=3), parameter :: material_id(ncase)=[character(len=3) :: 'B16','B17','O16','O17','O17']
  real(real64), parameter :: se_value(ncase)=[0.96_real64,0.96_real64,0.96_real64,0.85_real64,0.96_real64]
  real(real64), parameter :: rho_value(ncase)=[1.05_real64,1.05_real64,-1.0_real64,1.05_real64,-0.95_real64]
  logical, parameter :: stage_a_transfer_valid(ncase)=[.false.,.true.,.true.,.true.,.true.]
  logical, parameter :: p2e16b_rossfast_valid(ncase)=[.false.,.false.,.true.,.false.,.true.]
  real(real64), parameter :: dt_ladder(ndt)=[0.0064_real64,0.0032_real64,0.0016_real64, &
       0.0008_real64,0.0004_real64,0.0002_real64,0.0001_real64]
  integer, parameter :: nsub_values(nseq)=[1,2,4,8,16]

  integer :: ic,idt,isq
  integer :: single_valid_count,single_retry_count,single_failed_count
  integer :: sequence_valid_count,sequence_invalid_count
  integer :: p2e16b_dt_invalid_reproduced
  integer :: valid_at_larger_and_invalid_at_0016
  integer :: recovered_with_substeps_count

  single_valid_count=0
  single_retry_count=0
  single_failed_count=0
  sequence_valid_count=0
  sequence_invalid_count=0
  p2e16b_dt_invalid_reproduced=0
  valid_at_larger_and_invalid_at_0016=0
  recovered_with_substeps_count=0

  do ic=1,ncase
    call run_single_ladder(ic)
    call run_horizon_sequences(ic)
  end do

  write(*,'(A,I0)') 'PUB_P2E16C_CASE_COUNT=',ncase
  write(*,'(A,I0)') 'PUB_P2E16C_SINGLE_SOLVE_COUNT=',ncase*ndt
  write(*,'(A,I0)') 'PUB_P2E16C_SEQUENCE_COUNT=',ncase*nseq
  write(*,'(A,I0)') 'PUB_P2E16C_SINGLE_VALID_COUNT=',single_valid_count
  write(*,'(A,I0)') 'PUB_P2E16C_SINGLE_RETRY_COUNT=',single_retry_count
  write(*,'(A,I0)') 'PUB_P2E16C_SINGLE_FAILED_COUNT=',single_failed_count
  write(*,'(A,I0)') 'PUB_P2E16C_SEQUENCE_VALID_COUNT=',sequence_valid_count
  write(*,'(A,I0)') 'PUB_P2E16C_SEQUENCE_INVALID_COUNT=',sequence_invalid_count
  write(*,'(A,I0)') 'PUB_P2E16C_P2E16B_DT_INVALID_REPRODUCED=',p2e16b_dt_invalid_reproduced
  write(*,'(A,I0)') 'PUB_P2E16C_VALID_LARGER_INVALID_0016_COUNT=',valid_at_larger_and_invalid_at_0016
  write(*,'(A,I0)') 'PUB_P2E16C_RECOVERED_WITH_SUBSTEPS_COUNT=',recovered_with_substeps_count
  write(*,'(A)') 'PUB_P2E16C_ROSSFAST_EXECUTED=FALSE'
  write(*,'(A)') 'PUB_P2E16C_NUMERICAL_CONTROLS_CHANGED=FALSE'
  write(*,'(A)') 'PUB_P2E16C_PRIMARY_RESULT_CHANGED=FALSE'
  write(*,'(A)') 'PUB_P2E16C_DIAGNOSTIC_RESULT_IS_CI_FAILURE=FALSE'
  write(*,'(A)') 'PUB_P2E16C_REFERENCE_FIXED_STEP_ADJUDICATION_GATE=PASS'

contains

  subroutine run_single_ladder(icase)
    integer,intent(in) :: icase
    type(soil_water_parameter_set_t),target :: parameters
    type(reference_richards_legacy_solver_t) :: solver
    type(reference_richards_legacy_workspace_t) :: workspace
    type(soil_water_solve_request_t) :: request
    type(soil_water_solve_result_t) :: result
    type(rossfast_d3r_material_t) :: material
    type(b110_default_mvg_parameters_t),target :: hydraulic_parameters
    type(b110_default_mvg_provider_t),target :: constitutive
    type(b110_source_sink_provider_t),target :: source_sink
    type(fixed_flux_top_boundary_provider_t),target :: top_boundary
    real(real64),target :: drainage(1,n),irrigation(n),root_sink(n)
    real(real64) :: cofgen(24,n),theta0(n),h0,qtop,qbot
    logical :: valid,found,large_valid,dt0016_valid
    integer :: j

    call prepare_case(icase,parameters,hydraulic_parameters,constitutive,source_sink,top_boundary, &
         drainage,irrigation,root_sink,cofgen,material,theta0,h0,qtop,qbot,found)
    call require(found,'single-ladder case preparation')

    large_valid=.false.
    dt0016_valid=.false.
    do j=1,ndt
      call bind_b110_default_mvg_provider(constitutive,hydraulic_parameters,dt_ladder(j))
      call initialize_request(request,parameters,constitutive,source_sink,top_boundary,theta0,h0,qtop,qbot,dt_ladder(j))
      call solver%solve(request,workspace,result)
      valid=reference_result_valid(result,request,material)

      if (valid) then
        single_valid_count=single_valid_count+1
      else if (result%status==SW_SOLVE_RETRY_ADVISED .or. result%retry_advised) then
        single_retry_count=single_retry_count+1
      else
        single_failed_count=single_failed_count+1
      end if

      if (j<=2 .and. valid) large_valid=.true.
      if (j==3) then
        dt0016_valid=valid
        if (.not.valid) p2e16b_dt_invalid_reproduced=p2e16b_dt_invalid_reproduced+1
      end if

      call report_single(icase,dt_ladder(j),request,result,valid,material)
    end do

    if (large_valid .and. .not.dt0016_valid) valid_at_larger_and_invalid_at_0016=valid_at_larger_and_invalid_at_0016+1
  end subroutine run_single_ladder

  subroutine run_horizon_sequences(icase)
    integer,intent(in) :: icase
    type(soil_water_parameter_set_t),target :: parameters
    type(reference_richards_legacy_solver_t) :: solver
    type(reference_richards_legacy_workspace_t) :: workspace
    type(soil_water_solve_request_t) :: request
    type(soil_water_solve_result_t) :: result
    type(rossfast_d3r_material_t) :: material
    type(b110_default_mvg_parameters_t),target :: hydraulic_parameters
    type(b110_default_mvg_provider_t),target :: constitutive
    type(b110_source_sink_provider_t),target :: source_sink
    type(fixed_flux_top_boundary_provider_t),target :: top_boundary
    real(real64),target :: drainage(1,n),irrigation(n),root_sink(n)
    real(real64) :: cofgen(24,n),theta0(n),h0,qtop,qbot,subdt,max_mass,terminal_storage
    logical :: valid,found,seq_valid,n1_valid,recovered
    integer :: j,k,first_fail,status_at_fail
    character(len=32) :: route_at_fail

    call prepare_case(icase,parameters,hydraulic_parameters,constitutive,source_sink,top_boundary, &
         drainage,irrigation,root_sink,cofgen,material,theta0,h0,qtop,qbot,found)
    call require(found,'sequence case preparation')

    n1_valid=.false.
    recovered=.false.
    do j=1,nseq
      subdt=0.0016_real64/real(nsub_values(j),real64)
      call bind_b110_default_mvg_provider(constitutive,hydraulic_parameters,subdt)
      call initialize_request(request,parameters,constitutive,source_sink,top_boundary,theta0,h0,qtop,qbot,subdt)
      seq_valid=.true.
      first_fail=0
      status_at_fail=0
      route_at_fail='none'
      max_mass=0.0_real64

      do k=1,nsub_values(j)
        call solver%solve(request,workspace,result)
        valid=reference_result_valid(result,request,material)
        if (.not.valid) then
          seq_valid=.false.
          first_fail=k
          status_at_fail=result%status
          route_at_fail=result%diagnostics%route
          exit
        end if
        if (result%integrated_mass_balance_residual_available) then
          max_mass=max(max_mass,abs(result%integrated_mass_balance_residual_cm))
        end if
        request%base_state=result%candidate_state
      end do

      if (seq_valid) then
        sequence_valid_count=sequence_valid_count+1
        terminal_storage=sum(parameters%dz*request%base_state%water_content)+request%base_state%ponding_depth
      else
        sequence_invalid_count=sequence_invalid_count+1
        terminal_storage=0.0_real64
      end if

      if (j==1) n1_valid=seq_valid
      if (j>1 .and. seq_valid) recovered=.true.

      write(*,'(*(g0))') 'PUB_P2E16C_SEQUENCE|ORIG_CASE=',original_case_id(icase), &
           '|M=',material_id(icase),'|SE=',se_value(icase),'|RHO=',rho_value(icase), &
           '|NSUB=',nsub_values(j),'|SUBDT=',subdt,'|VALID=',seq_valid, &
           '|FIRST_FAIL=',first_fail,'|FAIL_STATUS=',status_at_fail,'|FAIL_ROUTE=',trim(route_at_fail), &
           '|MAX_MASS_CM=',max_mass,'|TERMINAL_STORAGE_CM=',terminal_storage
    end do

    if (.not.n1_valid .and. recovered) recovered_with_substeps_count=recovered_with_substeps_count+1
  end subroutine run_horizon_sequences

  subroutine prepare_case(icase,parameters,hydraulic_parameters,constitutive,source_sink,top_boundary, &
       drainage,irrigation,root_sink,cofgen,material,theta0,h0,qtop,qbot,ok)
    integer,intent(in) :: icase
    type(soil_water_parameter_set_t),target,intent(out) :: parameters
    type(b110_default_mvg_parameters_t),target,intent(out) :: hydraulic_parameters
    type(b110_default_mvg_provider_t),target,intent(out) :: constitutive
    type(b110_source_sink_provider_t),target,intent(out) :: source_sink
    type(fixed_flux_top_boundary_provider_t),target,intent(out) :: top_boundary
    real(real64),target,intent(out) :: drainage(1,n),irrigation(n),root_sink(n)
    real(real64),intent(out) :: cofgen(24,n),theta0(n),h0,qtop,qbot
    type(rossfast_d3r_material_t),intent(out) :: material
    logical,intent(out) :: ok
    real(real64) :: heads(n),conductivity(n),capacity(n),dkdh(n),k_top,k_bottom,bottom_ref,bottom_limit
    logical :: found

    ok=.false.
    call rossfast_d3r_material_from_id(material_id(icase),material,found)
    if (.not.found) return
    h0=head_from_effective_saturation(se_value(icase),material)
    if (.not.ieee_is_finite(h0) .or. h0<=ROSSFAST_D3R_H_MIN_CM .or. h0>=ROSSFAST_D3R_H_MAX_CM) return

    call initialize_parameter_contract(parameters,cofgen,material,original_case_id(icase))
    call initialize_b110_default_mvg_parameters(hydraulic_parameters,cofgen)
    call bind_b110_default_mvg_provider(constitutive,hydraulic_parameters,0.0016_real64)
    heads=h0
    call constitutive%evaluate(heads,theta0,conductivity,capacity,dkdh)
    if (any(.not.ieee_is_finite(theta0)) .or. any(.not.ieee_is_finite(conductivity)) .or. any(conductivity<=0.0_real64)) return

    k_top=conductivity(1)
    k_bottom=conductivity(n)
    qtop=-0.01_real64*k_top
    bottom_ref=-0.004_real64*k_bottom
    bottom_limit=ROSSFAST_D3R_BOUNDARY_ENVELOPE_FRACTION*max(abs(bottom_ref),abs(k_bottom),1.0e-12_real64)
    qbot=bottom_ref+rho_value(icase)*bottom_limit

    drainage=0.0_real64
    irrigation=0.0_real64
    root_sink=0.0_real64
    call bind_b110_source_sink_provider(source_sink,drainage,irrigation,root_sink)
    ok=.true.
  end subroutine prepare_case

  subroutine report_single(icase,dt,request,result,valid,material)
    integer,intent(in) :: icase
    real(real64),intent(in) :: dt
    type(soil_water_solve_request_t),intent(in) :: request
    type(soil_water_solve_result_t),intent(in) :: result
    logical,intent(in) :: valid
    type(rossfast_d3r_material_t),intent(in) :: material
    logical :: candidate_valid,flux_match
    real(real64) :: mass_cm,native_rate

    candidate_valid=state_valid(result,material)
    flux_match=same_real(result%top_flux,request%boundary%top_flux) .and. &
         same_real(result%bottom_flux,request%boundary%bottom_flux)
    mass_cm=0.0_real64
    native_rate=0.0_real64
    if (result%integrated_mass_balance_residual_available) mass_cm=result%integrated_mass_balance_residual_cm
    if (result%native_balance_rate_residual_available) native_rate=result%native_balance_rate_residual_cm_per_day

    write(*,'(*(g0))') 'PUB_P2E16C_SINGLE|ORIG_CASE=',original_case_id(icase), &
         '|M=',material_id(icase),'|SE=',se_value(icase),'|RHO=',rho_value(icase), &
         '|STAGE_A_TRANSFER_VALID=',stage_a_transfer_valid(icase),'|P2E16B_ROSS_VALID=',p2e16b_rossfast_valid(icase), &
         '|DT=',dt,'|VALID=',valid,'|STATUS=',result%status,'|RETRY=',result%retry_advised, &
         '|ROUTE=',trim(result%diagnostics%route),'|NLI=',result%diagnostics%nonlinear_iterations, &
         '|JAC=',result%diagnostics%jacobian_builds,'|LIN=',result%diagnostics%linear_solves, &
         '|BACKTRACK=',result%diagnostics%backtracking_attempts,'|ALT=',result%diagnostics%alternative_solver_calls, &
         '|MASS_AVAILABLE=',result%integrated_mass_balance_residual_available,'|MASS_CM=',mass_cm, &
         '|RATE_AVAILABLE=',result%native_balance_rate_residual_available,'|RATE=',native_rate, &
         '|CANDIDATE_VALID=',candidate_valid,'|FLUX_MATCH=',flux_match
  end subroutine report_single

  logical function reference_result_valid(result,request,material) result(ok)
    type(soil_water_solve_result_t),intent(in) :: result
    type(soil_water_solve_request_t),intent(in) :: request
    type(rossfast_d3r_material_t),intent(in) :: material
    ok=.false.
    if (result%status/=SW_SOLVE_CONVERGED) return
    if (trim(result%diagnostics%route)/='legacy-reference-bound') return
    if (.not.result%integrated_mass_balance_residual_available) return
    if (.not.ieee_is_finite(result%integrated_mass_balance_residual_cm)) return
    if (abs(result%integrated_mass_balance_residual_cm)>publication_mass_tol_cm) return
    if (.not.result%native_balance_rate_residual_available) return
    if (.not.ieee_is_finite(result%native_balance_rate_residual_cm_per_day)) return
    if (.not.state_valid(result,material)) return
    if (.not.same_real(result%top_flux,request%boundary%top_flux)) return
    if (.not.same_real(result%bottom_flux,request%boundary%bottom_flux)) return
    ok=.true.
  end function reference_result_valid

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
    parameter_set%parameter_set_id=923000+id
    parameter_set%active_nodes=n
    allocate(parameter_set%z(n),parameter_set%dz(n),parameter_set%node_distance(n))
    do i=1,n
      parameter_set%z(i)=-ROSSFAST_D3R_DZ_CM*(real(i,real64)-0.5_real64)
    end do
    parameter_set%dz=ROSSFAST_D3R_DZ_CM
    parameter_set%node_distance=ROSSFAST_D3R_DZ_CM
    cofgen_out=0.0_real64
    do i=1,n
      cofgen_out(1,i)=mat%theta_r
      cofgen_out(2,i)=mat%theta_s
      cofgen_out(3,i)=mat%ksatfit_cm_per_day
      cofgen_out(4,i)=mat%alpha_per_cm
      cofgen_out(5,i)=mat%lambda
      cofgen_out(6,i)=mat%n
      cofgen_out(7,i)=m
      cofgen_out(8,i)=mat%alpha_per_cm
      cofgen_out(9,i)=mat%h_enpr_cm
      cofgen_out(10,i)=mat%ksatfit_cm_per_day
      cofgen_out(11,i)=0.999_real64
      cofgen_out(12,i)=0.99_real64*mat%ksatfit_cm_per_day
      cofgen_out(22,i)=-1.0e6_real64
      cofgen_out(23,i)=1.0e-12_real64
    end do
  end subroutine initialize_parameter_contract

  subroutine initialize_request(req,parameter_set,hydraulic_provider,source_provider,top_provider,theta,h0,qtop,qbot,dt)
    type(soil_water_solve_request_t),intent(out) :: req
    type(soil_water_parameter_set_t),target,intent(in) :: parameter_set
    type(b110_default_mvg_provider_t),target,intent(in) :: hydraulic_provider
    type(b110_source_sink_provider_t),target,intent(in) :: source_provider
    type(fixed_flux_top_boundary_provider_t),target,intent(in) :: top_provider
    real(real64),intent(in) :: theta(n),h0,qtop,qbot,dt
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
    req%numerical%compartment_balance_tolerance=reference_balance_rate_tol
    req%numerical%total_balance_tolerance=reference_balance_rate_tol
    req%numerical%head_abs_tolerance=1.0e-12_real64
    req%numerical%head_rel_tolerance=1.0e-12_real64
    req%numerical%ponding_tolerance=1.0e-12_real64
    req%step_duration=dt
    req%request_interface_sensitivity=.false.
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
      write(*,'(A,1X,A)') 'PUB_P2E16C_HARNESS_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_pub_p2e16c_reference_fixed_step_adjudication

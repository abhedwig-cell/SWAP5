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
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  implicit none

  integer, parameter :: n=ROSSFAST_D3R_N_CELLS,ncase=5,ndirect=7,nrefine=5
  real(real64), parameter :: reference_internal_balance_rate_tol_cm_per_day=1.0e-12_real64
  integer, parameter :: original_case_ids(ncase)=[576,612,1220,1248,1257]
  character(len=3), parameter :: material_ids(ncase)=[character(len=3) :: 'B16','B17','O16','O17','O17']
  real(real64), parameter :: se_levels(ncase)=[0.96_real64,0.96_real64,0.96_real64,0.85_real64,0.96_real64]
  character(len=6), parameter :: axis_ids(ncase)=[character(len=6) :: 'BOTTOM','BOTTOM','BOTTOM','BOTTOM','BOTTOM']
  real(real64), parameter :: rho_levels(ncase)=[1.05_real64,1.05_real64,-1.0_real64,1.05_real64,-0.95_real64]
  real(real64), parameter :: direct_dt(ndirect)=[0.0064_real64,0.0032_real64,0.0016_real64, &
       0.0008_real64,0.0004_real64,0.0002_real64,0.0001_real64]
  integer, parameter :: refine_substeps(nrefine)=[1,2,4,8,16]

  integer :: icase,idur,ilevel,direct_records,refine_records
  logical :: direct_valid(ncase,ndirect),refine_complete(ncase,nrefine)

  direct_valid=.false.
  refine_complete=.false.
  direct_records=0
  refine_records=0

  do icase=1,ncase
    do idur=1,ndirect
      call run_direct_case(icase,direct_dt(idur),direct_valid(icase,idur))
      direct_records=direct_records+1
    end do
    do ilevel=1,nrefine
      call run_refined_horizon(icase,refine_substeps(ilevel),refine_complete(icase,ilevel))
      refine_records=refine_records+1
    end do
  end do

  call require(direct_records==35,'exact direct-duration record count')
  call require(refine_records==25,'exact same-horizon refinement record count')

  write(*,'(A,I0)') 'PUB_P2E16D1_CASE_COUNT=',ncase
  write(*,'(A,I0)') 'PUB_P2E16D1_DIRECT_DURATION_COUNT=',ndirect
  write(*,'(A,I0)') 'PUB_P2E16D1_DIRECT_RECORD_COUNT=',direct_records
  write(*,'(A,I0)') 'PUB_P2E16D1_REFINEMENT_LEVEL_COUNT=',nrefine
  write(*,'(A,I0)') 'PUB_P2E16D1_REFINEMENT_RECORD_COUNT=',refine_records
  write(*,'(A)') 'PUB_P2E16D1_ROSSFAST_EXECUTED=FALSE'
  write(*,'(A)') 'PUB_P2E16D1_P2E16B_PRIMARY_RECLASSIFIED=FALSE'
  write(*,'(A)') 'PUB_P2E16D1_REFERENCE_TOLERANCES_RETUNED=FALSE'
  write(*,'(A)') 'PUB_P2E16D1_REFERENCE_FIXED_STEP_ADJUDICATION_GATE=PASS'

contains

  subroutine run_direct_case(icase,dt,valid)
    integer,intent(in) :: icase
    real(real64),intent(in) :: dt
    logical,intent(out) :: valid
    type(soil_water_parameter_set_t),target :: parameters
    type(b110_default_mvg_parameters_t),target :: hydraulic_parameters
    type(b110_default_mvg_provider_t),target :: constitutive
    type(b110_source_sink_provider_t),target :: source_sink
    type(fixed_flux_top_boundary_provider_t),target :: top_boundary
    type(soil_water_solve_request_t) :: request
    type(soil_water_solve_result_t) :: result
    type(rossfast_d3r_material_t) :: material
    real(real64),target :: drainage(1,n),irrigation(n),root_sink(n)
    real(real64) :: cofgen(24,n),h0,theta0(n),heads(n),conductivity(n),capacity(n),dkdh(n),qtop,qbot
    logical :: found

    call setup_case(icase,parameters,hydraulic_parameters,constitutive,source_sink,top_boundary, &
         drainage,irrigation,root_sink,cofgen,material,h0,theta0,conductivity,qtop,qbot,found)
    call require(found,'direct material found')
    call initialize_request(request,parameters,constitutive,source_sink,top_boundary,theta0,spread(h0,1,n),qtop,qbot,dt)
    call execute_reference(request,result)
    valid=reference_route_valid(result,request,material)

    write(*,'(*(g0))') 'PUB_P2E16D1_DIRECT|ORIGINAL_CASE=',original_case_ids(icase), &
         '|M=',material_ids(icase),'|SE=',se_levels(icase),'|AXIS=',trim(axis_ids(icase)),'|RHO=',rho_levels(icase), &
         '|DT=',dt,'|STATUS=',result%status,'|VALID=',valid, &
         '|MASS_AVAILABLE=',result%integrated_mass_balance_residual_available, &
         '|MASS_CM=',result%integrated_mass_balance_residual_cm, &
         '|RATE_AVAILABLE=',result%native_balance_rate_residual_available, &
         '|RATE=',result%native_balance_rate_residual_cm_per_day, &
         '|NITER=',result%diagnostics%nonlinear_iterations,'|JAC=',result%diagnostics%jacobian_builds, &
         '|LINEAR=',result%diagnostics%linear_solves,'|BACKTRACK=',result%diagnostics%backtracking_attempts, &
         '|ROUTE=',trim(result%diagnostics%route)
  end subroutine run_direct_case

  subroutine run_refined_horizon(icase,nsub,complete)
    integer,intent(in) :: icase,nsub
    logical,intent(out) :: complete
    type(soil_water_parameter_set_t),target :: parameters
    type(b110_default_mvg_parameters_t),target :: hydraulic_parameters
    type(b110_default_mvg_provider_t),target :: constitutive
    type(b110_source_sink_provider_t),target :: source_sink
    type(fixed_flux_top_boundary_provider_t),target :: top_boundary
    type(soil_water_solve_request_t) :: request
    type(soil_water_solve_result_t) :: result
    type(rossfast_d3r_material_t) :: material
    real(real64),target :: drainage(1,n),irrigation(n),root_sink(n)
    real(real64) :: cofgen(24,n),h0,theta0(n),heads0(n),conductivity(n),capacity(n),dkdh(n),qtop,qbot
    real(real64) :: current_h(n),current_theta(n),dt,total_mass,final_storage
    logical :: found,valid
    integer :: istep,total_niter,total_linear,total_backtrack

    call setup_case(icase,parameters,hydraulic_parameters,constitutive,source_sink,top_boundary, &
         drainage,irrigation,root_sink,cofgen,material,h0,theta0,conductivity,qtop,qbot,found)
    call require(found,'refinement material found')
    current_h=h0
    current_theta=theta0
    dt=0.0016_real64/real(nsub,real64)
    total_mass=0.0_real64
    total_niter=0; total_linear=0; total_backtrack=0
    complete=.true.

    do istep=1,nsub
      call initialize_request(request,parameters,constitutive,source_sink,top_boundary,current_theta,current_h,qtop,qbot,dt)
      call execute_reference(request,result)
      valid=reference_route_valid(result,request,material)
      total_niter=total_niter+result%diagnostics%nonlinear_iterations
      total_linear=total_linear+result%diagnostics%linear_solves
      total_backtrack=total_backtrack+result%diagnostics%backtracking_attempts
      if (.not.valid) then
        complete=.false.
        exit
      end if
      total_mass=total_mass+result%integrated_mass_balance_residual_cm
      current_h=result%candidate_state%pressure_head
      current_theta=result%candidate_state%water_content
    end do

    if (complete) then
      final_storage=sum(parameters%dz*current_theta)
    else
      final_storage=0.0_real64
    end if

    write(*,'(*(g0))') 'PUB_P2E16D1_REFINED|ORIGINAL_CASE=',original_case_ids(icase), &
         '|M=',material_ids(icase),'|SE=',se_levels(icase),'|AXIS=',trim(axis_ids(icase)),'|RHO=',rho_levels(icase), &
         '|NSUB=',nsub,'|DT=',dt,'|COMPLETE=',complete,'|TOTAL_MASS_CM=',total_mass, &
         '|FINAL_STORAGE=',final_storage,'|TOTAL_NITER=',total_niter,'|TOTAL_LINEAR=',total_linear, &
         '|TOTAL_BACKTRACK=',total_backtrack
  end subroutine run_refined_horizon

  subroutine setup_case(icase,parameters,hydraulic_parameters,constitutive,source_sink,top_boundary, &
       drainage,irrigation,root_sink,cofgen,material,h0,theta0,conductivity,qtop,qbot,found)
    integer,intent(in) :: icase
    type(soil_water_parameter_set_t),target,intent(out) :: parameters
    type(b110_default_mvg_parameters_t),target,intent(out) :: hydraulic_parameters
    type(b110_default_mvg_provider_t),target,intent(out) :: constitutive
    type(b110_source_sink_provider_t),target,intent(out) :: source_sink
    type(fixed_flux_top_boundary_provider_t),target,intent(out) :: top_boundary
    real(real64),target,intent(out) :: drainage(1,n),irrigation(n),root_sink(n)
    real(real64),intent(out) :: cofgen(24,n),h0,theta0(n),conductivity(n),qtop,qbot
    type(rossfast_d3r_material_t),intent(out) :: material
    logical,intent(out) :: found
    real(real64) :: heads(n),capacity(n),dkdh(n),k_top,k_bottom,top_ref_internal,top_limit,bottom_ref,bottom_limit

    call rossfast_d3r_material_from_id(material_ids(icase),material,found)
    if (.not.found) return
    h0=head_from_effective_saturation(se_levels(icase),material)
    call require(ieee_is_finite(h0) .and. h0>ROSSFAST_D3R_H_MIN_CM .and. h0<ROSSFAST_D3R_H_MAX_CM,'diagnostic h0 valid')
    call initialize_parameter_contract(parameters,cofgen,material,original_case_ids(icase))
    call initialize_b110_default_mvg_parameters(hydraulic_parameters,cofgen)
    call bind_b110_default_mvg_provider(constitutive,hydraulic_parameters,0.0064_real64)
    heads=h0
    call constitutive%evaluate(heads,theta0,conductivity,capacity,dkdh)
    call require(all(ieee_is_finite(theta0)) .and. all(ieee_is_finite(conductivity)) .and. all(conductivity>0.0_real64), &
         'diagnostic constitutive state valid')
    k_top=conductivity(1); k_bottom=conductivity(n)
    top_ref_internal=0.01_real64*k_top
    top_limit=ROSSFAST_D3R_BOUNDARY_ENVELOPE_FRACTION*max(abs(top_ref_internal),abs(k_top),1.0e-12_real64)
    bottom_ref=-0.004_real64*k_bottom
    bottom_limit=ROSSFAST_D3R_BOUNDARY_ENVELOPE_FRACTION*max(abs(bottom_ref),abs(k_bottom),1.0e-12_real64)
    if (trim(axis_ids(icase))=='TOP') then
      qtop=-(top_ref_internal+rho_levels(icase)*top_limit)
      qbot=bottom_ref
    else
      qtop=-top_ref_internal
      qbot=bottom_ref+rho_levels(icase)*bottom_limit
    end if
    drainage=0.0_real64; irrigation=0.0_real64; root_sink=0.0_real64
    call bind_b110_source_sink_provider(source_sink,drainage,irrigation,root_sink)
  end subroutine setup_case

  subroutine execute_reference(request,result)
    type(soil_water_solve_request_t),intent(in) :: request
    type(soil_water_solve_result_t),intent(out) :: result
    type(reference_richards_legacy_solver_t) :: solver
    type(reference_richards_legacy_workspace_t) :: workspace
    call solver%solve(request,workspace,result)
  end subroutine execute_reference

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
      cofgen_out(1,i)=mat%theta_r; cofgen_out(2,i)=mat%theta_s; cofgen_out(3,i)=mat%ksatfit_cm_per_day
      cofgen_out(4,i)=mat%alpha_per_cm; cofgen_out(5,i)=mat%lambda; cofgen_out(6,i)=mat%n
      cofgen_out(7,i)=m; cofgen_out(8,i)=mat%alpha_per_cm; cofgen_out(9,i)=mat%h_enpr_cm
      cofgen_out(10,i)=mat%ksatfit_cm_per_day; cofgen_out(11,i)=0.999_real64
      cofgen_out(12,i)=0.99_real64*mat%ksatfit_cm_per_day
      cofgen_out(22,i)=-1.0e6_real64; cofgen_out(23,i)=1.0e-12_real64
    end do
  end subroutine initialize_parameter_contract

  subroutine initialize_request(req,parameter_set,hydraulic_provider,source_provider,top_provider,theta,heads,qtop,qbot,dt)
    type(soil_water_solve_request_t),intent(out) :: req
    type(soil_water_parameter_set_t),target,intent(in) :: parameter_set
    type(b110_default_mvg_provider_t),target,intent(in) :: hydraulic_provider
    type(b110_source_sink_provider_t),target,intent(in) :: source_provider
    type(fixed_flux_top_boundary_provider_t),target,intent(in) :: top_provider
    real(real64),intent(in) :: theta(n),heads(n),qtop,qbot,dt
    req%parameters=>parameter_set
    req%base_state%active_nodes=n
    allocate(req%base_state%pressure_head(n),req%base_state%water_content(n))
    req%base_state%pressure_head=heads
    req%base_state%water_content=theta
    req%base_state%ponding_depth=0.0_real64
    req%base_state%groundwater_level=-999.0_real64
    req%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX
    req%boundary%bottom_mode=2
    req%boundary%top_flux=qtop
    req%boundary%top_head=heads(1)
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
      write(*,'(A,1X,A)') 'PUB_P2E16D1_HARNESS_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_pub_p2e16d1_reference_fixed_step_adjudication

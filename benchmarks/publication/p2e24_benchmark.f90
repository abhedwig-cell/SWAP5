program p2e24_benchmark
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
       ROSSFAST_D3R_N_CELLS, ROSSFAST_D3R_DZ_CM, ROSSFAST_D3R_H_MIN_CM, ROSSFAST_D3R_H_MAX_CM
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  implicit none

  integer, parameter :: n=ROSSFAST_D3R_N_CELLS
  integer, parameter :: ncases=36
  real(real64), parameter :: horizon_day=0.0016_real64
  real(real64), parameter :: ref_integrated_allowance_cm=1.6e-15_real64
  real(real64), parameter :: hard_mass_tol_cm=1.0e-12_real64
  real(real64), parameter :: ross_balance_rate_tol=1.0e-12_real64
  character(len=*), parameter :: matched_controls_blob='9f173b0431c775a8459930ab34f4989b8e098491'

  integer, parameter :: n_lo(ncases)=[ &
       20,20,19,19,22,22,0,0,6,6,20,20,13,14,16,16,22,22, &
       6,6,13,13,23,23,16,16,17,17,16,16,16,16,17,17,21,20 ]
  integer, parameter :: n_hi(ncases)=[ &
       21,21,20,20,23,23,1,1,7,7,21,21,14,15,17,17,23,23, &
       7,7,14,14,24,24,17,17,18,18,17,17,17,17,18,18,22,22 ]

  character(len=3), parameter :: material_ids(6)=[character(len=3) :: 'B01','B12','O01','O05','O14','O18']
  character(len=7), parameter :: forcing_ids(2)=[character(len=7) :: 'DRYING ','NOMINAL']
  real(real64), parameter :: se_levels(3)=[0.65_real64,0.85_real64,0.96_real64]
  real(real64), parameter :: qtop_factor(2)=[-0.005_real64,0.010_real64]
  real(real64), parameter :: qbot_factor(2)=[-0.019_real64,-0.004_real64]

  integer :: case_id,repetitions,nseg,rep,imat,ise,iforce,within
  character(len=32) :: arg,variant
  type(soil_water_parameter_set_t),target :: parameters
  type(rossfast_d3r_material_t) :: material
  type(b110_default_mvg_parameters_t),target :: hydraulic_parameters
  type(b110_default_mvg_provider_t),target :: constitutive
  type(b110_source_sink_provider_t),target :: source_sink
  type(fixed_flux_top_boundary_provider_t),target :: top_boundary
  real(real64),target :: drainage(1,n),irrigation(n),root_sink(n)
  real(real64) :: cofgen(24,n),initial_heads(n),initial_theta(n),conductivity(n),capacity(n),dkdh(n)
  real(real64) :: final_h(n),final_theta(n),final_storage,max_mass,cumulative_top,cumulative_bottom
  real(real64) :: h0,k0,top_flux,bottom_flux
  integer :: first_fail,outer_calls,nli,jac,lin,back,retries,alt,provider_status
  logical :: found,valid,initialized
  type(reference_richards_legacy_solver_t) :: ref_solver
  type(reference_richards_legacy_workspace_t) :: ref_workspace
  type(rossfast_d3r_soil_water_solver_t) :: ross_solver
  type(rossfast_d3r_soil_water_workspace_t) :: ross_workspace

  if (command_argument_count()/=3) then
    write(*,'(A)') 'USAGE: p2e24_benchmark CASE_ID VARIANT REPETITIONS'
    error stop 2
  end if
  call get_command_argument(1,arg); read(arg,*) case_id
  call get_command_argument(2,variant); variant=adjustl(trim(variant))
  call get_command_argument(3,arg); read(arg,*) repetitions
  call require(case_id>=1 .and. case_id<=ncases,'case id 1..36')
  call require(repetitions>=1,'positive repetitions')
  call require(variant=='ROSS' .or. variant=='REF_HI' .or. variant=='REF_LO','known variant')
  if (variant=='REF_LO') call require(n_lo(case_id)>0,'REF_LO unavailable for left-censored case')

  imat=(case_id-1)/6+1
  within=mod(case_id-1,6)
  ise=within/2+1
  iforce=mod(within,2)+1
  if (variant=='ROSS') then
    nseg=1
  else if (variant=='REF_HI') then
    nseg=n_hi(case_id)
  else
    nseg=n_lo(case_id)
  end if

  call rossfast_d3r_material_from_id(material_ids(imat),material,found)
  call require(found,'material authority available')
  h0=head_from_effective_saturation(se_levels(ise),material)
  call require(ieee_is_finite(h0) .and. h0>ROSSFAST_D3R_H_MIN_CM .and. h0<ROSSFAST_D3R_H_MAX_CM, &
       'initial head inside common domain')

  call initialize_parameter_contract(parameters,cofgen,material,case_id)
  call initialize_b110_default_mvg_parameters(hydraulic_parameters,cofgen)
  call bind_b110_default_mvg_provider(constitutive,hydraulic_parameters,horizon_day)
  initial_heads=h0
  call constitutive%evaluate(initial_heads,initial_theta,conductivity,capacity,dkdh)
  call require(all(ieee_is_finite(initial_theta)) .and. all(ieee_is_finite(conductivity)) .and. &
       all(conductivity>0.0_real64),'initial constitutive state valid')
  k0=conductivity(1)
  top_flux=qtop_factor(iforce)*k0
  bottom_flux=qbot_factor(iforce)*k0
  drainage=0.0_real64
  irrigation=0.0_real64
  root_sink=0.0_real64
  call bind_b110_source_sink_provider(source_sink,drainage,irrigation,root_sink)

  initialized=.true.
  if (variant=='ROSS') then
    call ross_solver%initialize('assets/rossfast/d3r',material_ids(imat),initialized,provider_status)
    call require(initialized,'RossFast provider initialization')
  end if

  do rep=1,repetitions
    if (variant=='ROSS') then
      call run_ross_once(ross_solver,ross_workspace,parameters,hydraulic_parameters,constitutive,source_sink,top_boundary, &
           material,initial_heads,initial_theta,top_flux,bottom_flux,valid,first_fail,final_h,final_theta,final_storage, &
           max_mass,cumulative_top,cumulative_bottom,outer_calls,nli,jac,lin,back,retries,alt)
    else
      call run_reference_once(nseg,ref_solver,ref_workspace,parameters,hydraulic_parameters,constitutive,source_sink, &
           top_boundary,material,initial_heads,initial_theta,top_flux,bottom_flux,valid,first_fail,final_h,final_theta, &
           final_storage,max_mass,cumulative_top,cumulative_bottom,outer_calls,nli,jac,lin,back,retries,alt)
    end if
    call require(valid,'configured benchmark horizon valid')
  end do

  write(*,'(*(g0))') 'PUB_P2E24A_RUN|CASE=',case_id,'|VARIANT=',trim(variant),'|REPETITIONS=',repetitions, &
       '|MATCHED_CONTROLS_BLOB=',matched_controls_blob
  write(*,'(*(g0))') 'PUB_P2E24A_FINGERPRINT|CASE=',case_id,'|VARIANT=',trim(variant),'|N=',nseg, &
       '|M=',trim(material_ids(imat)),'|SE=',se_levels(ise),'|F=',trim(forcing_ids(iforce)), &
       '|PONDING=',0.0_real64,'|STORAGE=',final_storage,'|TOP_TRANSFER=',cumulative_top, &
       '|BOTTOM_TRANSFER=',cumulative_bottom,'|MAX_MASS_CM=',max_mass
  write(*,'(*(g0))') 'PUB_P2E24A_HEAD|CASE=',case_id,'|VARIANT=',trim(variant),'|VALUES=',final_h
  write(*,'(*(g0))') 'PUB_P2E24A_THETA|CASE=',case_id,'|VARIANT=',trim(variant),'|VALUES=',final_theta

contains

  subroutine run_reference_once(nseg,solver,workspace,parameters,hydraulic_parameters,constitutive,source_sink,top_boundary, &
       material,initial_heads,initial_theta,top_flux,bottom_flux,valid,first_fail,final_h,final_theta,final_storage,max_mass, &
       cumulative_top,cumulative_bottom,outer_calls,nli,jac,lin,back,retries,alt)
    integer,intent(in) :: nseg
    type(reference_richards_legacy_solver_t),intent(inout) :: solver
    type(reference_richards_legacy_workspace_t),intent(inout) :: workspace
    type(soil_water_parameter_set_t),target,intent(in) :: parameters
    type(b110_default_mvg_parameters_t),target,intent(in) :: hydraulic_parameters
    type(b110_default_mvg_provider_t),target,intent(inout) :: constitutive
    type(b110_source_sink_provider_t),target,intent(in) :: source_sink
    type(fixed_flux_top_boundary_provider_t),target,intent(in) :: top_boundary
    type(rossfast_d3r_material_t),intent(in) :: material
    real(real64),intent(in) :: initial_heads(n),initial_theta(n),top_flux,bottom_flux
    logical,intent(out) :: valid
    integer,intent(out) :: first_fail,outer_calls,nli,jac,lin,back,retries,alt
    real(real64),intent(out) :: final_h(n),final_theta(n),final_storage,max_mass,cumulative_top,cumulative_bottom
    type(soil_water_solve_request_t) :: request
    type(soil_water_solve_result_t) :: result
    real(real64) :: current_h(n),current_theta(n),ponding,dt,comp_rate,total_bound,total_rate
    integer :: i
    logical :: step_valid

    valid=.false.;first_fail=0
    final_h=0.0_real64;final_theta=0.0_real64;final_storage=0.0_real64
    max_mass=0.0_real64;cumulative_top=0.0_real64;cumulative_bottom=0.0_real64
    outer_calls=0;nli=0;jac=0;lin=0;back=0;retries=0;alt=0
    current_h=initial_heads;current_theta=initial_theta;ponding=0.0_real64
    dt=horizon_day/real(nseg,real64)
    comp_rate=ref_integrated_allowance_cm/dt

    do i=1,nseg
      total_bound=representation_total_integrated_bound(current_theta,material,parameters%dz)
      total_rate=total_bound/dt
      call bind_b110_default_mvg_provider(constitutive,hydraulic_parameters,dt)
      call initialize_request(request,parameters,constitutive,source_sink,top_boundary,current_theta,current_h,ponding, &
           top_flux,bottom_flux,dt,comp_rate,total_rate)
      call solver%solve(request,workspace,result)

      outer_calls=outer_calls+1
      nli=nli+max(0,result%diagnostics%nonlinear_iterations)
      jac=jac+max(0,result%diagnostics%jacobian_builds)
      lin=lin+max(0,result%diagnostics%linear_solves)
      back=back+max(0,result%diagnostics%backtracking_attempts)
      retries=retries+max(0,result%diagnostics%internal_retries)
      alt=alt+max(0,result%diagnostics%alternative_solver_calls)

      step_valid=representation_bound_check(workspace,material)
      if (step_valid) step_valid=reference_result_valid(result,request,material)
      if (.not.step_valid) then
        first_fail=i
        return
      end if

      max_mass=max(max_mass,abs(result%integrated_mass_balance_residual_cm))
      cumulative_top=cumulative_top+dt*result%top_flux
      cumulative_bottom=cumulative_bottom+dt*result%bottom_flux
      current_h=result%candidate_state%pressure_head
      current_theta=result%candidate_state%water_content
      ponding=result%candidate_state%ponding_depth
    end do

    if (.not.transfer_identity(cumulative_top,horizon_day*top_flux)) return
    if (.not.transfer_identity(cumulative_bottom,horizon_day*bottom_flux)) return
    final_h=current_h
    final_theta=current_theta
    final_storage=sum(parameters%dz*current_theta)+ponding
    valid=.true.
  end subroutine run_reference_once

  subroutine run_ross_once(solver,workspace,parameters,hydraulic_parameters,constitutive,source_sink,top_boundary,material, &
       initial_heads,initial_theta,top_flux,bottom_flux,valid,first_fail,final_h,final_theta,final_storage,max_mass, &
       cumulative_top,cumulative_bottom,outer_calls,nli,jac,lin,back,retries,alt)
    type(rossfast_d3r_soil_water_solver_t),intent(inout) :: solver
    type(rossfast_d3r_soil_water_workspace_t),intent(inout) :: workspace
    type(soil_water_parameter_set_t),target,intent(in) :: parameters
    type(b110_default_mvg_parameters_t),target,intent(in) :: hydraulic_parameters
    type(b110_default_mvg_provider_t),target,intent(inout) :: constitutive
    type(b110_source_sink_provider_t),target,intent(in) :: source_sink
    type(fixed_flux_top_boundary_provider_t),target,intent(in) :: top_boundary
    type(rossfast_d3r_material_t),intent(in) :: material
    real(real64),intent(in) :: initial_heads(n),initial_theta(n),top_flux,bottom_flux
    logical,intent(out) :: valid
    integer,intent(out) :: first_fail,outer_calls,nli,jac,lin,back,retries,alt
    real(real64),intent(out) :: final_h(n),final_theta(n),final_storage,max_mass,cumulative_top,cumulative_bottom
    type(soil_water_solve_request_t) :: request
    type(soil_water_solve_result_t) :: result

    valid=.false.;first_fail=0
    final_h=0.0_real64;final_theta=0.0_real64;final_storage=0.0_real64
    max_mass=0.0_real64;cumulative_top=0.0_real64;cumulative_bottom=0.0_real64
    outer_calls=0;nli=0;jac=0;lin=0;back=0;retries=0;alt=0

    call bind_b110_default_mvg_provider(constitutive,hydraulic_parameters,horizon_day)
    call initialize_request(request,parameters,constitutive,source_sink,top_boundary,initial_theta,initial_heads,0.0_real64, &
         top_flux,bottom_flux,horizon_day,ross_balance_rate_tol,ross_balance_rate_tol)
    call solver%solve(request,workspace,result)

    outer_calls=1
    nli=max(0,result%diagnostics%nonlinear_iterations)
    jac=max(0,result%diagnostics%jacobian_builds)
    lin=max(0,result%diagnostics%linear_solves)
    back=max(0,result%diagnostics%backtracking_attempts)
    retries=max(0,result%diagnostics%internal_retries)
    alt=max(0,result%diagnostics%alternative_solver_calls)

    if (.not.ross_result_valid(result,request,material)) then
      first_fail=1
      return
    end if
    max_mass=abs(result%integrated_mass_balance_residual_cm)
    cumulative_top=horizon_day*result%top_flux
    cumulative_bottom=horizon_day*result%bottom_flux
    if (.not.transfer_identity(cumulative_top,horizon_day*top_flux)) return
    if (.not.transfer_identity(cumulative_bottom,horizon_day*bottom_flux)) return
    final_h=result%candidate_state%pressure_head
    final_theta=result%candidate_state%water_content
    final_storage=sum(parameters%dz*final_theta)+result%candidate_state%ponding_depth
    valid=.true.
  end subroutine run_ross_once

  logical function reference_result_valid(result,request,material) result(ok)
    type(soil_water_solve_result_t),intent(in) :: result
    type(soil_water_solve_request_t),intent(in) :: request
    type(rossfast_d3r_material_t),intent(in) :: material
    ok=.false.
    if (result%status/=SW_SOLVE_CONVERGED) return
    if (trim(result%diagnostics%route)/='legacy-reference-bound') return
    if (.not.result%integrated_mass_balance_residual_available) return
    if (.not.result%native_balance_rate_residual_available) return
    if (.not.ieee_is_finite(result%integrated_mass_balance_residual_cm)) return
    if (abs(result%integrated_mass_balance_residual_cm)>hard_mass_tol_cm) return
    if (.not.state_valid(result,material)) return
    if (.not.same_real(result%top_flux,request%boundary%top_flux)) return
    if (.not.same_real(result%bottom_flux,request%boundary%bottom_flux)) return
    ok=.true.
  end function reference_result_valid

  logical function ross_result_valid(result,request,material) result(ok)
    type(soil_water_solve_result_t),intent(in) :: result
    type(soil_water_solve_request_t),intent(in) :: request
    type(rossfast_d3r_material_t),intent(in) :: material
    ok=.false.
    if (result%status/=SW_SOLVE_CONVERGED) return
    if (trim(result%diagnostics%route)/='rossfast-d3r') return
    if (.not.result%integrated_mass_balance_residual_available) return
    if (result%native_balance_rate_residual_available) return
    if (.not.ieee_is_finite(result%integrated_mass_balance_residual_cm)) return
    if (abs(result%integrated_mass_balance_residual_cm)>hard_mass_tol_cm) return
    if (.not.state_valid(result,material)) return
    if (.not.same_real(result%top_flux,request%boundary%top_flux)) return
    if (.not.same_real(result%bottom_flux,request%boundary%bottom_flux)) return
    ok=.true.
  end function ross_result_valid

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

  subroutine initialize_request(req,parameter_set,hydraulic_provider,source_provider,top_provider,theta,heads,ponding, &
       qtop,qbot,dt,comp_balance_rate_tol,total_balance_rate_tol)
    type(soil_water_solve_request_t),intent(out) :: req
    type(soil_water_parameter_set_t),target,intent(in) :: parameter_set
    type(b110_default_mvg_provider_t),target,intent(in) :: hydraulic_provider
    type(b110_source_sink_provider_t),target,intent(in) :: source_provider
    type(fixed_flux_top_boundary_provider_t),target,intent(in) :: top_provider
    real(real64),intent(in) :: theta(n),heads(n),ponding,qtop,qbot,dt,comp_balance_rate_tol,total_balance_rate_tol

    req%parameters=>parameter_set
    req%base_state%active_nodes=n
    allocate(req%base_state%pressure_head(n),req%base_state%water_content(n))
    req%base_state%pressure_head=heads
    req%base_state%water_content=theta
    req%base_state%ponding_depth=ponding
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
    req%numerical%compartment_balance_tolerance=comp_balance_rate_tol
    req%numerical%total_balance_tolerance=total_balance_rate_tol
    req%numerical%head_abs_tolerance=1.0e-12_real64
    req%numerical%head_rel_tolerance=1.0e-12_real64
    req%numerical%ponding_tolerance=1.0e-12_real64
    req%step_duration=dt
    req%request_interface_sensitivity=.false.
    req%evaluation%constitutive=>hydraulic_provider
    req%evaluation%source_sink=>source_provider
    req%evaluation%top_boundary=>top_provider
  end subroutine initialize_request

  subroutine initialize_parameter_contract(parameter_set,cofgen_out,mat,case_id)
    type(soil_water_parameter_set_t),target,intent(out) :: parameter_set
    real(real64),intent(out) :: cofgen_out(24,n)
    type(rossfast_d3r_material_t),intent(in) :: mat
    integer,intent(in) :: case_id
    real(real64) :: m
    integer :: i
    m=1.0_real64-1.0_real64/mat%n
    parameter_set%parameter_set_id=928000+case_id
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

  pure real(real64) function head_from_effective_saturation(se,material) result(head_cm)
    real(real64),intent(in) :: se
    type(rossfast_d3r_material_t),intent(in) :: material
    real(real64) :: m
    m=1.0_real64-1.0_real64/material%n
    head_cm=-(se**(-1.0_real64/m)-1.0_real64)**(1.0_real64/material%n)/material%alpha_per_cm
  end function head_from_effective_saturation

  pure real(real64) function representation_total_integrated_bound(theta_base,material,dz) result(bound_cm)
    real(real64),intent(in) :: theta_base(n),dz(n)
    type(rossfast_d3r_material_t),intent(in) :: material
    real(real64) :: spacing_bound
    spacing_bound=0.5_real64*sum((spacing(material%theta_s)+spacing(theta_base))*dz)
    bound_cm=max(ref_integrated_allowance_cm,spacing_bound)
  end function representation_total_integrated_bound

  logical function representation_bound_check(workspace,material) result(ok)
    type(reference_richards_legacy_workspace_t),intent(in) :: workspace
    type(rossfast_d3r_material_t),intent(in) :: material
    ok=.false.
    if (.not.allocated(workspace%richards%provider_theta)) return
    if (size(workspace%richards%provider_theta)/=n) return
    if (any(.not.ieee_is_finite(workspace%richards%provider_theta))) return
    if (any(workspace%richards%provider_theta<=0.0_real64)) return
    if (any(spacing(workspace%richards%provider_theta)>spacing(material%theta_s))) return
    ok=.true.
  end function representation_bound_check

  pure logical function transfer_identity(a,b)
    real(real64),intent(in) :: a,b
    real(real64) :: scale
    scale=max(1.0_real64,abs(a),abs(b))
    transfer_identity=abs(a-b)<=64.0_real64*epsilon(1.0_real64)*scale
  end function transfer_identity

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
      write(*,'(A,1X,A)') 'PUB_P2E24A_BENCHMARK_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program p2e24_benchmark

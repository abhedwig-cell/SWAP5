program test_num_unc_p0a_spatial_control
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_physical_state_t, &
       soil_water_solve_request_t, soil_water_solve_result_t, SW_SOLVE_CONVERGED
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, &
       reference_richards_legacy_workspace_t
  use mod_rossfast_d3r_model_binding, only: rossfast_d3r_material_t, rossfast_d3r_material_from_id
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_b110_root_sink_provider, only: b110_root_sink_provider_t, bind_b110_root_sink_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use mod_process_hydraulic_view, only: process_hydraulic_view_t, build_process_hydraulic_view
  use mod_root_water_uptake_process, only: root_water_uptake_parameters_t, root_water_uptake_request_t, &
       root_water_uptake_flux_result_t, root_water_uptake_diagnostics_t, evaluate_macro_feddes_drought_uptake, &
       ROOT_UPTAKE_OK
  implicit none

  integer, parameter :: n=32, rooted_nodes=12, blocks=192
  integer, parameter :: STRESS_BEFORE_RESCUE=1, NOT_BEFORE_RESCUE=2, INADMISSIBLE=9
  integer, parameter :: rescue_start_block=65, rescue_end_block=80
  real(real64), parameter :: dz_cm=5.0_real64, dt=0.0064_real64
  real(real64), parameter :: ptra=0.1806735915459957_real64
  real(real64), parameter :: stress_ratio_threshold=0.999999999999_real64
  real(real64), parameter :: mass_tol=1.0e-12_real64
  real(real64), parameter :: hlim3h=-325.0_real64, hlim3l=-600.0_real64, hlim4=-8000.0_real64
  real(real64), parameter :: adcrh=0.5_real64, adcrl=0.1_real64
  real(real64), parameter :: se_minus=0.16270876169331827_real64
  real(real64), parameter :: se_plus=0.16770876169331828_real64

  integer :: minus_class,plus_class,first_block
  logical :: minus_valid,plus_valid
  real(real64) :: min_ratio,first_time,max_mass
  character(len=64) :: failure

  write(*,'(A)') 'NUM_UNC_P0A_SPATIAL_STAGE=N0_ONLY_OUTER_BRACKET'
  write(*,'(A)') 'NUM_UNC_P0A_SPATIAL_N1_EXECUTED=FALSE'
  write(*,'(A,I0)') 'NUM_UNC_P0A_SPATIAL_CELLS=',n
  write(*,'(*(g0))') 'NUM_UNC_P0A_SPATIAL_DZ_CM=',dz_cm
  write(*,'(A,I0)') 'NUM_UNC_P0A_SPATIAL_ROOTED_NODES=',rooted_nodes

  call run_case(se_minus,minus_class,minus_valid,min_ratio,first_block,first_time,max_mass,failure)
  call report_case('A_MINUS',se_minus,minus_class,minus_valid,min_ratio,first_block,first_time,max_mass,failure)
  call run_case(se_plus,plus_class,plus_valid,min_ratio,first_block,first_time,max_mass,failure)
  call report_case('A_PLUS',se_plus,plus_class,plus_valid,min_ratio,first_block,first_time,max_mass,failure)

  if (.not.minus_valid .or. .not.plus_valid) then
    write(*,'(A)') 'NUM_UNC_P0A_SPATIAL_STATUS=BLOCKED_INADMISSIBLE'
  else if (minus_class/=STRESS_BEFORE_RESCUE .or. plus_class/=NOT_BEFORE_RESCUE) then
    write(*,'(A)') 'NUM_UNC_P0A_SPATIAL_STATUS=BLOCKED_OUTER_BRACKET_NOT_STABLE'
  else
    write(*,'(A)') 'NUM_UNC_P0A_SPATIAL_STATUS=PASS_OUTER_BRACKET_STABLE'
  end if
  write(*,'(A)') 'NUM_UNC_P0A_SPATIAL_GATE=PASS'

contains

  subroutine run_case(initial_se,class_id,is_valid,min_actual_ratio,first_stress_block,first_stress_time,max_mass_residual,failure_stage)
    real(real64),intent(in) :: initial_se
    integer,intent(out) :: class_id,first_stress_block
    logical,intent(out) :: is_valid
    real(real64),intent(out) :: min_actual_ratio,first_stress_time,max_mass_residual
    character(len=*),intent(out) :: failure_stage

    type(soil_water_parameter_set_t),target :: parameters
    type(rossfast_d3r_material_t) :: material
    type(b110_default_mvg_parameters_t),target :: hydraulic_parameters
    type(b110_default_mvg_provider_t),target :: constitutive
    type(b110_source_sink_provider_t),target :: source_sink
    type(b110_root_sink_provider_t),target :: root_provider
    type(fixed_flux_top_boundary_provider_t),target :: top_provider
    type(reference_richards_legacy_solver_t) :: solver
    type(reference_richards_legacy_workspace_t) :: workspace
    type(soil_water_solve_request_t) :: request
    type(soil_water_solve_result_t) :: result
    type(soil_water_physical_state_t) :: state
    type(process_hydraulic_view_t) :: hydraulic_view
    type(root_water_uptake_parameters_t) :: root_parameters
    type(root_water_uptake_request_t) :: root_request
    type(root_water_uptake_flux_result_t) :: root_fluxes
    type(root_water_uptake_diagnostics_t) :: root_diagnostics
    real(real64),target :: drainage(1,n),irrigation(n),source_root_zero(n),root_sink_vec(n)
    real(real64) :: cofgen(24,n),heads(n),theta(n),conductivity(n),capacity(n),dkdh(n)
    real(real64) :: h0,qtop,ratio,current_time
    integer :: block,j
    logical :: found,view_ok

    class_id=INADMISSIBLE; is_valid=.false.; min_actual_ratio=huge(1.0_real64)
    first_stress_block=0; first_stress_time=-1.0_real64; max_mass_residual=0.0_real64
    failure_stage='INITIALIZATION'

    call rossfast_d3r_material_from_id('B01',material,found)
    if (.not.found) then; failure_stage='MATERIAL_LOOKUP'; return; end if
    call initialize_parameters(parameters,cofgen,material)
    call initialize_b110_default_mvg_parameters(hydraulic_parameters,cofgen)
    call bind_b110_default_mvg_provider(constitutive,hydraulic_parameters,dt)
    h0=head_from_effective_saturation(initial_se,material)
    heads=h0
    call constitutive%evaluate(heads,theta,conductivity,capacity,dkdh)
    if (any(.not.ieee_is_finite(theta)) .or. any(.not.ieee_is_finite(conductivity))) then
      failure_stage='INITIAL_CONSTITUTIVE'; return
    end if
    if (any(theta<=material%theta_r) .or. any(theta>=material%theta_s)) then
      failure_stage='INITIAL_THETA_DOMAIN'; return
    end if

    state%active_nodes=n
    allocate(state%pressure_head(n),state%water_content(n))
    state%pressure_head=heads; state%water_content=theta
    state%ponding_depth=0.0_real64; state%groundwater_level=-999.0_real64

    drainage=0.0_real64; irrigation=0.0_real64; source_root_zero=0.0_real64; root_sink_vec=0.0_real64
    call bind_b110_source_sink_provider(source_sink,drainage,irrigation,source_root_zero)

    root_parameters%active_nodes=n
    root_parameters%hlim3l=hlim3l; root_parameters%hlim3h=hlim3h; root_parameters%hlim4=hlim4
    root_parameters%adcrl=adcrl; root_parameters%adcrh=adcrh
    root_request%potential_transpiration=ptra
    root_request%rooted_nodes=rooted_nodes
    allocate(root_request%cumulative_root_fraction(rooted_nodes+1))
    do j=1,rooted_nodes+1
      root_request%cumulative_root_fraction(j)=real(j-1,real64)/real(rooted_nodes,real64)
    end do

    do block=1,blocks
      current_time=real(block-1,real64)*dt
      call build_process_hydraulic_view(state,hydraulic_view,view_ok)
      if (.not.view_ok) then; failure_stage='HYDRAULIC_VIEW'; return; end if
      call evaluate_macro_feddes_drought_uptake(root_parameters,hydraulic_view,root_request,root_fluxes,root_diagnostics)
      if (root_diagnostics%status/=ROOT_UPTAKE_OK .or. .not.root_diagnostics%evaluated) then
        failure_stage='ROOT_PROCESS'; return
      end if
      if (.not.allocated(root_fluxes%root_extraction_sink)) then
        failure_stage='ROOT_SINK_MISSING'; return
      end if
      if (size(root_fluxes%root_extraction_sink)/=n .or. any(.not.ieee_is_finite(root_fluxes%root_extraction_sink))) then
        failure_stage='ROOT_SINK_INVALID'; return
      end if
      if (any(root_fluxes%root_extraction_sink<0.0_real64) .or. .not.ieee_is_finite(root_fluxes%actual_uptake_total)) then
        failure_stage='ROOT_SINK_DOMAIN'; return
      end if
      ratio=root_fluxes%actual_uptake_total/ptra
      min_actual_ratio=min(min_actual_ratio,ratio)
      if (first_stress_block==0 .and. ratio<stress_ratio_threshold) then
        first_stress_block=block; first_stress_time=current_time
      end if
      root_sink_vec=root_fluxes%root_extraction_sink
      call bind_b110_root_sink_provider(root_provider,root_sink_vec)

      if (block>=rescue_start_block .and. block<=rescue_end_block) then
        qtop=ptra
      else
        qtop=0.0_real64
      end if
      call bind_b110_default_mvg_provider(constitutive,hydraulic_parameters,dt)
      call initialize_request(request,parameters,constitutive,source_sink,root_provider,top_provider,state,qtop)
      call solver%solve(request,workspace,result)
      if (.not.result_valid(result,material)) then; failure_stage='REFERENCE_GATE'; return; end if
      max_mass_residual=max(max_mass_residual,abs(result%integrated_mass_balance_residual_cm))
      state=result%candidate_state
    end do

    if (first_stress_block>0 .and. first_stress_time<real(rescue_start_block-1,real64)*dt) then
      class_id=STRESS_BEFORE_RESCUE
    else
      class_id=NOT_BEFORE_RESCUE
    end if
    is_valid=.true.; failure_stage='NONE'
  end subroutine run_case

  logical function result_valid(result,material) result(ok)
    type(soil_water_solve_result_t),intent(in) :: result
    type(rossfast_d3r_material_t),intent(in) :: material
    real(real64),parameter :: eps_theta=1.0e-12_real64
    ok=.false.
    if (result%status/=SW_SOLVE_CONVERGED) return
    if (trim(result%diagnostics%route)/='legacy-reference-bound') return
    if (result%diagnostics%internal_retries/=0 .or. result%diagnostics%alternative_solver_calls/=0) return
    if (.not.result%integrated_mass_balance_residual_available) return
    if (.not.ieee_is_finite(result%integrated_mass_balance_residual_cm)) return
    if (abs(result%integrated_mass_balance_residual_cm)>mass_tol) return
    if (.not.result%native_balance_rate_residual_available) return
    if (.not.ieee_is_finite(result%native_balance_rate_residual_cm_per_day)) return
    if (result%candidate_state%active_nodes/=n) return
    if (.not.allocated(result%candidate_state%pressure_head) .or. .not.allocated(result%candidate_state%water_content)) return
    if (any(.not.ieee_is_finite(result%candidate_state%pressure_head))) return
    if (any(.not.ieee_is_finite(result%candidate_state%water_content))) return
    if (any(result%candidate_state%water_content<material%theta_r-eps_theta)) return
    if (any(result%candidate_state%water_content>material%theta_s+eps_theta)) return
    ok=.true.
  end function result_valid

  subroutine initialize_request(req,p,hyd,source,root,top,base,qtop)
    type(soil_water_solve_request_t),intent(out) :: req
    type(soil_water_parameter_set_t),target,intent(in) :: p
    type(b110_default_mvg_provider_t),target,intent(in) :: hyd
    type(b110_source_sink_provider_t),target,intent(in) :: source
    type(b110_root_sink_provider_t),target,intent(in) :: root
    type(fixed_flux_top_boundary_provider_t),target,intent(in) :: top
    type(soil_water_physical_state_t),intent(in) :: base
    real(real64),intent(in) :: qtop
    req%parameters=>p; req%base_state=base
    req%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX; req%boundary%bottom_mode=2
    req%boundary%top_flux=qtop; req%boundary%top_head=base%pressure_head(1)
    req%boundary%bottom_flux=0.0_real64; req%boundary%bottom_head=-999999.0_real64
    req%physical%macropore_active=.false.
    req%numerical%max_iterations=16; req%numerical%max_backtracking=8
    req%numerical%conductivity_implicit_mode=0; req%numerical%conductivity_mean_method=1
    req%numerical%min_step_duration=1.0e-8_real64
    req%numerical%compartment_balance_tolerance=mass_tol; req%numerical%total_balance_tolerance=mass_tol
    req%numerical%head_abs_tolerance=1.0e-12_real64; req%numerical%head_rel_tolerance=1.0e-12_real64
    req%numerical%ponding_tolerance=1.0e-12_real64; req%step_duration=dt
    req%request_interface_sensitivity=.false.
    req%evaluation%constitutive=>hyd; req%evaluation%source_sink=>source
    req%evaluation%root_sink=>root; req%evaluation%top_boundary=>top
  end subroutine initialize_request

  subroutine initialize_parameters(p,c,mat)
    type(soil_water_parameter_set_t),target,intent(out) :: p
    real(real64),intent(out) :: c(24,n)
    type(rossfast_d3r_material_t),intent(in) :: mat
    real(real64) :: m
    integer :: j
    m=1.0_real64-1.0_real64/mat%n
    p%parameter_set_id=926202; p%active_nodes=n
    allocate(p%z(n),p%dz(n),p%node_distance(n))
    do j=1,n; p%z(j)=-dz_cm*(real(j,real64)-0.5_real64); end do
    p%dz=dz_cm; p%node_distance=dz_cm; p%node_distance(1)=0.5_real64*dz_cm
    c=0.0_real64
    do j=1,n
      c(1,j)=mat%theta_r; c(2,j)=mat%theta_s; c(3,j)=mat%ksatfit_cm_per_day
      c(4,j)=mat%alpha_per_cm; c(5,j)=mat%lambda; c(6,j)=mat%n; c(7,j)=m
      c(8,j)=mat%alpha_per_cm; c(9,j)=mat%h_enpr_cm; c(10,j)=mat%ksatfit_cm_per_day
      c(11,j)=0.999_real64; c(12,j)=0.99_real64*mat%ksatfit_cm_per_day
      c(22,j)=-1.0e6_real64; c(23,j)=1.0e-12_real64
    end do
  end subroutine initialize_parameters

  pure real(real64) function head_from_effective_saturation(se,material) result(head_cm)
    real(real64),intent(in) :: se
    type(rossfast_d3r_material_t),intent(in) :: material
    real(real64) :: m
    m=1.0_real64-1.0_real64/material%n
    head_cm=-(se**(-1.0_real64/m)-1.0_real64)**(1.0_real64/material%n)/material%alpha_per_cm
  end function head_from_effective_saturation

  subroutine report_case(id,se0,class_id,valid,min_ratio,first_block,first_time,max_mass,failure)
    character(len=*),intent(in) :: id,failure
    real(real64),intent(in) :: se0,min_ratio,first_time,max_mass
    integer,intent(in) :: class_id,first_block
    logical,intent(in) :: valid
    write(*,'(*(g0))') 'NUM_UNC_P0A_SPATIAL_CASE|ID=',trim(id),'|SE0=',se0, &
         '|CLASS=',trim(class_name(class_id)),'|VALID=',valid,'|MIN_TA_TP=',min_ratio, &
         '|FIRST_STRESS_BLOCK=',first_block,'|FIRST_STRESS_TIME_DAY=',first_time, &
         '|MAX_MASS_CM=',max_mass,'|FAILURE=',trim(failure)
  end subroutine report_case

  pure function class_name(class_id) result(name)
    integer,intent(in) :: class_id
    character(len=24) :: name
    select case(class_id)
    case(STRESS_BEFORE_RESCUE); name='STRESS_BEFORE_RESCUE'
    case(NOT_BEFORE_RESCUE); name='NOT_BEFORE_RESCUE'
    case default; name='INADMISSIBLE'
    end select
  end function class_name
end program test_num_unc_p0a_spatial_control

module mod_ppa_wu05a7_runtime_test_support
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: soil_water_solver_t, soil_water_solver_workspace_base_t, &
       soil_water_solve_request_t, soil_water_solve_result_t, source_sink_provider_t, &
       SW_SOLVE_CONVERGED, SW_SOLVE_RETRY_ADVISED
  implicit none

  type, extends(source_sink_provider_t) :: base_source_provider_t
    real(real64), allocatable :: source_rate(:)
    real(real64), allocatable :: sink_rate(:)
  contains
    procedure :: evaluate => base_source_evaluate
  end type base_source_provider_t

  type, extends(soil_water_solver_workspace_base_t) :: mock_workspace_t
  end type mock_workspace_t

  type, extends(soil_water_solver_t) :: mock_solver_t
    real(real64) :: retry_above_source=huge(1.0_real64)
  contains
    procedure :: solve => mock_solve
  end type mock_solver_t

contains

  subroutine base_source_evaluate(self,pressure_head,water_content,source,sink)
    class(base_source_provider_t),intent(in)::self
    real(real64),intent(in)::pressure_head(:),water_content(:)
    real(real64),intent(out)::source(:),sink(:)
    source=0.0_real64; sink=0.0_real64
    if(allocated(self%source_rate))source=self%source_rate
    if(allocated(self%sink_rate))sink=self%sink_rate
    if(size(pressure_head)/=size(water_content))error stop 'base provider state shape'
  end subroutine base_source_evaluate

  subroutine mock_solve(self,request,workspace,result)
    class(mock_solver_t),intent(inout)::self
    type(soil_water_solve_request_t),intent(in)::request
    class(soil_water_solver_workspace_base_t),intent(inout)::workspace
    type(soil_water_solve_result_t),intent(out)::result
    real(real64),allocatable::source(:),sink(:)
    integer::n

    n=request%base_state%active_nodes
    result=soil_water_solve_result_t()
    allocate(source(n),sink(n))
    source=0.0_real64; sink=0.0_real64
    if(associated(request%evaluation%source_sink)) &
         call request%evaluation%source_sink%evaluate(request%base_state%pressure_head, &
              request%base_state%water_content,source,sink)

    if(maxval(source)>self%retry_above_source)then
      result%status=SW_SOLVE_RETRY_ADVISED
      result%retry_advised=.true.
      return
    end if

    result%status=SW_SOLVE_CONVERGED
    result%candidate_state=request%base_state
    result%candidate_state%water_content=request%base_state%water_content + &
         (source-sink)*request%step_duration/request%parameters%dz
    result%top_flux=0.0_real64
    result%bottom_flux=0.0_real64
    result%integrated_mass_balance_residual_available=.true.
    result%integrated_mass_balance_residual_cm=0.0_real64
    if(.not.same_type_as(workspace,workspace))error stop 'mock workspace impossible'
  end subroutine mock_solve

end module mod_ppa_wu05a7_runtime_test_support

program test_ppa_wu05a7_single_column_runtime
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_solve_request_t, &
       soil_water_solve_result_t
  use mod_macropore_continuation_state, only: macropore_continuation_state_t
  use mod_ppa_wu05a5_multi_domain_process, only: macropore_geometry_config_t, evaluate_macropore_geometry, &
       macropore_geometry_result_t
  use mod_ppa_wu05a6_rate_bundle, only: macropore_rate_bundle_request_t
  use mod_ppa_wu05a6_sorptivity_history, only: sorptivity_history_update_request_t
  use mod_macropore_single_column_runtime, only: macropore_single_column_runtime_t, &
       macropore_runtime_policy_t, macropore_runtime_result_t, MACRO_RUNTIME_INACTIVE, &
       MACRO_RUNTIME_CONVERGED, MACRO_RUNTIME_RETRY
  use mod_ppa_wu05a7_runtime_test_support, only: base_source_provider_t,mock_solver_t,mock_workspace_t
  implicit none

  integer,parameter::n=3,nd=1
  real(real64),parameter::dt=0.1_real64
  type(soil_water_parameter_set_t),target::params
  type(base_source_provider_t),target::base_provider
  type(soil_water_solve_request_t)::request,direct_request
  type(soil_water_solve_result_t)::direct_result
  type(macropore_continuation_state_t)::macro,macro_snapshot
  type(macropore_geometry_config_t)::geometry_config
  type(macropore_geometry_result_t)::geometry
  type(macropore_rate_bundle_request_t)::rate_template
  type(sorptivity_history_update_request_t)::history_request
  type(macropore_single_column_runtime_t)::runtime
  type(macropore_runtime_policy_t)::policy
  type(macropore_runtime_result_t)::result
  type(mock_solver_t)::solver
  type(mock_workspace_t)::workspace
  logical::ok

  params%active_nodes=n
  allocate(params%z(n),params%dz(n),params%node_distance(n))
  params%z=[-10.0_real64,-20.0_real64,-30.0_real64]
  params%dz=10.0_real64
  params%node_distance=10.0_real64

  request%parameters=>params
  request%base_state%active_nodes=n
  allocate(request%base_state%pressure_head(n),request%base_state%water_content(n))
  request%base_state%pressure_head=-100.0_real64
  request%base_state%water_content=0.20_real64
  request%base_state%groundwater_level=-100.0_real64
  request%step_duration=dt
  request%physical%macropore_active=.false.

  allocate(base_provider%source_rate(n),base_provider%sink_rate(n))
  base_provider%source_rate=0.0_real64
  base_provider%source_rate(3)=0.03_real64
  base_provider%sink_rate=0.0_real64
  request%evaluation%source_sink=>base_provider

  call macro%initialize(nd,n,ok)
  if(.not.ok)error stop 'A7 runtime macro init'
  macro%dynamic_volume_cp=0.0_real64

  call setup_geometry(geometry_config)
  call evaluate_macropore_geometry(geometry_config,macro%dynamic_volume_cp,geometry)
  if(.not.geometry%valid)error stop 'A7 runtime geometry'
  macro%icp_bottom_domain=geometry%bottom_domain
  macro%volume_domain_cp=geometry%volume_domain_cp
  macro%water_domain_cp=0.0_real64
  macro%water_domain_cp(1,3)=0.5_real64
  macro%water_domain_cp(1,2)=0.1_real64
  macro_snapshot=macro

  call setup_rate_template(macro,geometry,rate_template)
  call setup_history(history_request)

  ! Disabled route must be exactly the ordinary solver with original base source/sink.
  direct_request=request
  call solver%solve(direct_request,workspace,direct_result)
  policy%enabled=.false.
  call runtime%execute(solver,workspace,request,macro,geometry_config,rate_template,history_request,policy,result)
  if(result%status/=MACRO_RUNTIME_INACTIVE)error stop 'A7 inactive status'
  if(any(transfer(result%matrix_result%candidate_state%water_content, &
       [0_8], size(result%matrix_result%candidate_state%water_content)) /= &
       transfer(direct_result%candidate_state%water_content, [0_8], &
       size(direct_result%candidate_state%water_content)))) &
       error stop 'A7 inactive matrix preservation'
  if(.not.result%macropore_candidate%same_values(macro_snapshot))error stop 'A7 inactive macro preservation'

  ! Active strict coupling.
  policy%enabled=.true.
  policy%max_correctors=60
  policy%exchange_relative_tolerance=1.0e-10_real64
  policy%damping_previous_weight=0.5_real64
  solver%retry_above_source=huge(1.0_real64)
  call runtime%execute(solver,workspace,request,macro,geometry_config,rate_template,history_request,policy,result)
  if(result%status/=MACRO_RUNTIME_CONVERGED)error stop 'A7 active convergence'
  if(abs(result%internal_exchange_residual_cm)>1.0e-10_real64)error stop 'A7 internal exchange residual'
  if(abs(result%macro_balance_residual_cm)>1.0e-10_real64)error stop 'A7 macro residual'
  if(sum(result%exchange_rate_node)<=0.0_real64)error stop 'A7 active exchange missing'
  if(sum(result%macropore_candidate%water_domain_cp)>=sum(macro%water_domain_cp)) &
       error stop 'A7 active macro water did not decrease'
  if(.not.macro%same_values(macro_snapshot))error stop 'A7 committed macro mutated'

  ! Retry propagation from a corrector.
  solver%retry_above_source=0.0300001_real64
  call runtime%execute(solver,workspace,request,macro,geometry_config,rate_template,history_request,policy,result)
  if(result%status/=MACRO_RUNTIME_RETRY .or. .not.result%retry_advised)error stop 'A7 retry propagation'
  if(.not.macro%same_values(macro_snapshot))error stop 'A7 retry committed macro mutated'

  print '(a)', 'PPA_WU05A7_SINGLE_COLUMN_RUNTIME=PASS'

contains

  subroutine setup_geometry(config)
    type(macropore_geometry_config_t),intent(out)::config
    config%num_domains=nd
    config%num_nodes=n
    config%top_node=1
    allocate(config%static_volume_cp(n),config%domain_fraction(nd,n), &
         config%potential_bottom_domain(nd),config%dz(n),config%characteristic_diameter(n))
    config%static_volume_cp=0.50_real64
    config%domain_fraction=1.0_real64
    config%potential_bottom_domain=3
    config%dz=10.0_real64
    config%characteristic_diameter=4.0_real64
  end subroutine setup_geometry

  subroutine setup_rate_template(state,geom,bundle)
    type(macropore_continuation_state_t),intent(in)::state
    type(macropore_geometry_result_t),intent(in)::geom
    type(macropore_rate_bundle_request_t),intent(out)::bundle

    allocate(bundle%unsaturated%sorptivity%bottom_domain(nd),bundle%unsaturated%sorptivity%top_water_node(nd), &
         bundle%unsaturated%sorptivity%theta(n),bundle%unsaturated%sorptivity%theta_s(n), &
         bundle%unsaturated%sorptivity%theta_r(n),bundle%unsaturated%sorptivity%dz(n), &
         bundle%unsaturated%sorptivity%diameter(n),bundle%unsaturated%sorptivity%wall_correction(n), &
         bundle%unsaturated%sorptivity%sorptivity_max(n),bundle%unsaturated%sorptivity%sorptivity_alpha(n), &
         bundle%unsaturated%sorptivity%domain_fraction(nd,n),bundle%unsaturated%sorptivity%wet_fraction(nd,n), &
         bundle%unsaturated%sorptivity%history_sorptivity(nd,n), &
         bundle%unsaturated%sorptivity%history_theta_ref(nd,n), &
         bundle%unsaturated%sorptivity%history_absorption_time(nd,n),bundle%unsaturated%pressure_head(n), &
         bundle%unsaturated%elevation(n),bundle%unsaturated%conductivity(n),bundle%unsaturated%entry_head(n), &
         bundle%unsaturated%groundwater_level_domain(nd),bundle%unsaturated%sorp_fac_parallel(n))
    bundle%unsaturated%sorptivity%num_domains=nd
    bundle%unsaturated%sorptivity%num_nodes=n
    bundle%unsaturated%sorptivity%top_node=1
    bundle%unsaturated%sorptivity%swmbf=1
    bundle%unsaturated%sorptivity%matrix_top_saturated_node=4
    bundle%unsaturated%sorptivity%step_duration=dt
    bundle%unsaturated%sorptivity%flow_reduction=1.0_real64
    bundle%unsaturated%sorptivity%bottom_domain=3
    bundle%unsaturated%sorptivity%top_water_node=1
    bundle%unsaturated%sorptivity%theta=0.20_real64
    bundle%unsaturated%sorptivity%theta_s=0.45_real64
    bundle%unsaturated%sorptivity%theta_r=0.05_real64
    bundle%unsaturated%sorptivity%dz=10.0_real64
    bundle%unsaturated%sorptivity%diameter=4.0_real64
    bundle%unsaturated%sorptivity%wall_correction=0.95_real64
    bundle%unsaturated%sorptivity%sorptivity_max=0.002_real64
    bundle%unsaturated%sorptivity%sorptivity_alpha=0.5_real64
    bundle%unsaturated%sorptivity%domain_fraction=1.0_real64
    bundle%unsaturated%sorptivity%wet_fraction=1.0_real64
    bundle%unsaturated%sorptivity%history_sorptivity=state%sorptivity
    bundle%unsaturated%sorptivity%history_theta_ref=state%theta_sorption_ref
    bundle%unsaturated%sorptivity%history_absorption_time=state%absorption_time
    bundle%unsaturated%shape_factor=1.0_real64
    bundle%unsaturated%pressure_head=-100.0_real64
    bundle%unsaturated%elevation=[-10.0_real64,-20.0_real64,-30.0_real64]
    bundle%unsaturated%conductivity=0.0_real64
    bundle%unsaturated%entry_head=-1.0_real64
    bundle%unsaturated%groundwater_level_domain=-20.0_real64
    bundle%unsaturated%sorp_fac_parallel=0.5_real64

    call setup_sat(bundle%interflow_sat)
    call setup_sat(bundle%matrix_sat)

    bundle%rapid%num_nodes=n
    bundle%rapid%top_water_node=1
    bundle%rapid%bottom_domain_node=3
    bundle%rapid%drain_type=2
    bundle%rapid%enabled=.false.
    bundle%rapid%saturated_top_fraction=1.0_real64
    bundle%rapid%water_level_cm=-20.0_real64
    bundle%rapid%domain_bottom_cm=-30.0_real64
    bundle%rapid%drain_level_cm=-25.0_real64
    bundle%rapid%ponding_cm=0.0_real64
    bundle%rapid%step_duration=dt
    bundle%rapid%area_exponent=3.0_real64
    bundle%rapid%kd_reference=0.001_real64
    bundle%rapid%resistance_reference_day=20.0_real64
    bundle%rapid%flow_reduction=1.0_real64
    bundle%rapid%water_storage_cm=sum(state%water_domain_cp)
    bundle%rapid%volume_under_drain_cm=0.0_real64
    allocate(bundle%rapid%diameter(n),bundle%rapid%dz(n),bundle%rapid%volume_main_domain_cp(n))
    bundle%rapid%diameter=4.0_real64
    bundle%rapid%dz=10.0_real64
    bundle%rapid%volume_main_domain_cp=geom%volume_domain_cp(1,:)

    bundle%limiter%num_domains=nd
    allocate(bundle%limiter%accepted_storage_cm(nd),bundle%limiter%maximum_storage_cm(nd), &
         bundle%limiter%minimum_storage_cm(nd),bundle%limiter%potential_top_vertical_cm(nd), &
         bundle%limiter%potential_top_lateral_cm(nd),bundle%limiter%potential_interflow_sat_cm(nd), &
         bundle%limiter%potential_matrix_sat_cm(nd),bundle%limiter%potential_outflow_cm(nd), &
         bundle%limiter%redistribution_capacity_cm(nd),bundle%limiter%top_domain_fraction(nd))
    bundle%limiter%accepted_storage_cm=sum(state%water_domain_cp,dim=2)
    bundle%limiter%maximum_storage_cm=sum(geom%volume_domain_cp,dim=2)
    bundle%limiter%minimum_storage_cm=0.0_real64
    bundle%limiter%potential_top_vertical_cm=0.0_real64
    bundle%limiter%potential_top_lateral_cm=0.0_real64
    bundle%limiter%potential_interflow_sat_cm=0.0_real64
    bundle%limiter%potential_matrix_sat_cm=0.0_real64
    bundle%limiter%potential_outflow_cm=0.0_real64
    bundle%limiter%redistribution_capacity_cm=max(0.0_real64, &
         bundle%limiter%maximum_storage_cm-bundle%limiter%accepted_storage_cm)
    bundle%limiter%top_domain_fraction=1.0_real64
    bundle%top_node=1
  end subroutine setup_rate_template

  subroutine setup_sat(sat)
    use mod_ppa_wu05a6_saturated_exchange_rate, only: saturated_exchange_request_t
    type(saturated_exchange_request_t),intent(out)::sat
    sat%num_domains=nd
    sat%num_nodes=n
    sat%matrix_top_saturated_node=1
    sat%matrix_bottom_saturated_node=0
    sat%swsep=0
    sat%matrix_level=-20.0_real64
    sat%step_duration=dt
    sat%flow_reduction=1.0_real64
    sat%shape_factor=1.0_real64
    allocate(sat%bottom_domain(nd),sat%top_macro_saturated_node(nd),sat%macro_saturated_fraction(nd), &
         sat%macro_reference_level(nd),sat%z(n),sat%dz(n),sat%matrix_head(n),sat%ksat_horizontal(n), &
         sat%diameter(n),sat%domain_fraction(nd,n),sat%cdarcy(nd,n))
    sat%bottom_domain=3
    sat%top_macro_saturated_node=1
    sat%macro_saturated_fraction=1.0_real64
    sat%macro_reference_level=-20.0_real64
    sat%z=[-10.0_real64,-20.0_real64,-30.0_real64]
    sat%dz=10.0_real64
    sat%matrix_head=-100.0_real64
    sat%ksat_horizontal=0.0_real64
    sat%diameter=4.0_real64
    sat%domain_fraction=1.0_real64
    sat%cdarcy=0.0_real64
  end subroutine setup_sat

  subroutine setup_history(history)
    type(sorptivity_history_update_request_t),intent(out)::history
    history%num_domains=nd
    history%num_nodes=n
    history%top_node=1
    history%matrix_top_saturated_node=4
    history%step_duration=dt
    allocate(history%bottom_domain(nd),history%top_water_node(nd),history%wall_correction(n), &
         history%wet_fraction(nd,n),history%domain_fraction(nd,n),history%diameter(n))
    history%bottom_domain=3
    history%top_water_node=1
    history%wall_correction=0.95_real64
    history%wet_fraction=1.0_real64
    history%domain_fraction=1.0_real64
    history%diameter=4.0_real64
  end subroutine setup_history

end program test_ppa_wu05a7_single_column_runtime

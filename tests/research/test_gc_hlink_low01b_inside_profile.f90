program test_gc_hlink_low01b_inside_profile
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_physical_state_t, &
       soil_water_solve_request_t, hydraulic_evaluation_context_t, soil_water_boundary_conditions_t, &
       soil_water_numerical_config_t, soil_water_physical_config_t
  use mod_reference_richards_workspace, only: reference_richards_workspace_t, initialize_reference_workspace, &
       reset_reference_workspace
  use mod_reference_richards_state_binding, only: reference_richards_state_binding_t, &
       initialize_reference_state_binding, FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_a23bu_worker_execution_context, only: a23bu_worker_context_t, a23bu_solver_history_t, &
       a23bu_initialize_worker, a23bu_reset_attempt_diagnostics, a23bu_reset_attempt_control
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  implicit none

  real(real64), parameter :: dt_day=1.0e-2_real64
  real(real64), parameter :: mass_tol=1.0e-10_real64
  real(real64), parameter :: gwl_cases(2)=[-1.0_real64,-2.0_real64]
  integer, parameter :: expected_nn(2)=[2,3]
  real(real64), parameter :: qtop_cases(2)=[0.0_real64,-1.0e-4_real64]

  type(soil_water_parameter_set_t), target :: parameters
  type(b110_default_mvg_parameters_t), target :: hydraulic_parameters
  type(b110_default_mvg_provider_t), target :: constitutive
  type(b110_source_sink_provider_t), target :: source_sink
  type(fixed_flux_top_boundary_provider_t), target :: top_provider
  real(real64), allocatable, target :: drainage(:,:),subsurface(:),root_sink(:)
  real(real64), allocatable :: cofgen(:,:)
  integer :: ig,iq

  interface
    subroutine headcalc(worker, fsi_workspace, history, state_binding, evaluation_context, boundary_conditions, &
                        numerical_config, physical_config, explicit_step_duration, parameter_set)
      use mod_a23bu_worker_execution_context, only: a23bu_worker_context_t, a23bu_solver_history_t
      use mod_reference_richards_workspace, only: reference_richards_workspace_t
      use mod_reference_richards_state_binding, only: reference_richards_state_binding_t
      use mod_soil_water_solver_contract, only: hydraulic_evaluation_context_t, soil_water_boundary_conditions_t, &
           soil_water_numerical_config_t, soil_water_physical_config_t, soil_water_parameter_set_t
      type(a23bu_worker_context_t), intent(inout), optional :: worker
      type(reference_richards_workspace_t), target, intent(inout), optional :: fsi_workspace
      type(a23bu_solver_history_t), target, intent(inout), optional :: history
      type(reference_richards_state_binding_t), target, intent(inout), optional :: state_binding
      type(hydraulic_evaluation_context_t), intent(in), optional :: evaluation_context
      type(soil_water_boundary_conditions_t), intent(in), optional :: boundary_conditions
      type(soil_water_numerical_config_t), intent(in), optional :: numerical_config
      type(soil_water_physical_config_t), intent(in), optional :: physical_config
      real(8), intent(in), optional :: explicit_step_duration
      type(soil_water_parameter_set_t), target, intent(in), optional :: parameter_set
    end subroutine headcalc
  end interface

  call configure_problem()

  do ig=1,size(gwl_cases)
    call require(derive_nn(gwl_cases(ig))==expected_nn(ig),'independent NN oracle')
    do iq=1,size(qtop_cases)
      call run_and_replay(ig,iq,gwl_cases(ig),qtop_cases(iq),expected_nn(ig))
    end do
  end do

  write(*,'(A)') 'GC_LOW01B_ACTIVE_DOMAIN_TRUNCATION=PASS'
  write(*,'(A)') 'GC_LOW01B_SATURATED_CONTINUATION=PASS'
  write(*,'(A)') 'GC_LOW01B_QBOT_OUTPUT_AND_MASS=PASS'
  write(*,'(A)') 'GC_LOW01B_REPLAY_DETERMINISM=PASS'
  write(*,'(A)') 'GC_LOW01B_LIVE_GATE=PASS'

contains

  subroutine run_and_replay(gcase,qcase,gwl,qtop,nn)
    integer, intent(in) :: gcase,qcase,nn
    real(real64), intent(in) :: gwl,qtop
    type(soil_water_solve_request_t) :: request
    type(soil_water_physical_state_t) :: origin,origin_copy
    type(reference_richards_state_binding_t) :: first,replay
    type(reference_richards_workspace_t) :: ws1,ws2
    type(a23bu_worker_context_t) :: worker1,worker2
    type(a23bu_solver_history_t) :: history1,history2
    real(real64) :: storage0,storage1,mass_residual,stiffness
    integer :: i

    call build_origin(gwl,nn,origin)
    origin_copy=origin
    call build_request(gwl,qtop,origin,request)

    call run_headcalc(request,first,ws1,worker1,history1)
    call run_headcalc(request,replay,ws2,worker2,history2)

    call require(.not.first%fldecdt,'first trial no timestep reduction')
    call require(.not.replay%fldecdt,'replay no timestep reduction')
    call require(.not.first%fllowgwl,'inside-profile fllowgwl false')
    call require(.not.replay%fllowgwl,'replay inside-profile fllowgwl false')

    do i=nn+1,numnod
      call require(close_fp(first%theta(i),cofgen(2,i)),'saturated theta continuation')
      call require(ieee_is_finite(first%h(i)),'finite saturated continuation head')
    end do

    stiffness=first%kmean(nn+1)/(parameters%z(nn)-gwl)
    call require(ieee_is_finite(stiffness) .and. stiffness>0.0_real64,'positive inside-profile boundary stiffness')

    storage0=sum(origin%water_content*parameters%dz)+origin%ponding_depth
    storage1=sum(first%theta*parameters%dz)+first%pond
    mass_residual=(storage1-storage0)-(first%qbot-first%qtop)*dt_day
    call require(abs(mass_residual)<=mass_tol,'whole-profile qbot mass identity')
    call require(ieee_is_finite(first%qbot),'finite qbot output')

    call compare_state(first,replay,'replay')
    call compare_origin(origin,origin_copy)

    write(*,'(A,I0,A,I0,A,ES26.17E3,A,I0,A,ES26.17E3,A,ES26.17E3,A,ES26.17E3)') &
         'GC_LOW01B_CASE_G',gcase,'_Q',qcase,':GWL=',gwl,':NN=',nn,':QTOP=',qtop, &
         ':QBOT=',first%qbot,':MASS=',mass_residual
  end subroutine run_and_replay

  subroutine run_headcalc(request,state,workspace,worker,history)
    type(soil_water_solve_request_t), intent(in) :: request
    type(reference_richards_state_binding_t), intent(out) :: state
    type(reference_richards_workspace_t), intent(inout) :: workspace
    type(a23bu_worker_context_t), intent(inout) :: worker
    type(a23bu_solver_history_t), intent(inout) :: history
    integer :: n

    n=request%parameters%active_nodes
    call a23bu_initialize_worker(worker,n)
    call a23bu_reset_attempt_diagnostics(worker)
    call a23bu_reset_attempt_control(worker)
    call initialize_reference_workspace(workspace,n)
    call reset_reference_workspace(workspace)
    call initialize_reference_state_binding(state,request)

    call headcalc(worker,workspace,history,state,request%evaluation,request%boundary,request%numerical,request%physical, &
         request%step_duration,request%parameters)
  end subroutine run_headcalc

  subroutine build_request(gwl,qtop,origin,request)
    real(real64), intent(in) :: gwl,qtop
    type(soil_water_physical_state_t), intent(in) :: origin
    type(soil_water_solve_request_t), intent(out) :: request

    request=soil_water_solve_request_t()
    request%parameters=>parameters
    request%base_state=origin
    request%step_duration=dt_day
    request%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX
    request%boundary%bottom_mode=1
    request%boundary%top_flux=qtop
    request%boundary%top_head=origin%pressure_head(1)
    request%boundary%bottom_flux=0.0_real64
    request%boundary%bottom_head=gwl
    request%physical%macropore_active=.false.
    request%numerical%max_iterations=24
    request%numerical%max_backtracking=8
    request%numerical%conductivity_implicit_mode=0
    request%numerical%conductivity_mean_method=1
    request%numerical%min_step_duration=1.0e-8_real64
    request%numerical%compartment_balance_tolerance=mass_tol
    request%numerical%total_balance_tolerance=mass_tol
    request%numerical%head_abs_tolerance=1.0e-12_real64
    request%numerical%head_rel_tolerance=1.0e-12_real64
    request%numerical%ponding_tolerance=1.0e-12_real64
    request%evaluation%constitutive=>constitutive
    request%evaluation%source_sink=>source_sink
    request%evaluation%top_boundary=>top_provider
  end subroutine build_request

  subroutine build_origin(gwl,nn,state)
    real(real64), intent(in) :: gwl
    integer, intent(in) :: nn
    type(soil_water_physical_state_t), intent(out) :: state
    real(real64) :: heads(numnod),water(numnod),conductivity(numnod),capacity(numnod),dkdh(numnod)
    integer :: i

    ! Source-consistent zero-gradient profile in the active domain, extended
    ! with the same unit-gradient continuation used by the legacy branch.
    heads(nn)=gwl-parameters%z(nn)
    do i=nn-1,1,-1
      heads(i)=heads(i+1)-parameters%node_distance(i+1)
    end do
    do i=nn+1,numnod
      heads(i)=heads(i-1)+parameters%node_distance(i)
    end do

    call bind_b110_default_mvg_provider(constitutive,hydraulic_parameters,dt_day)
    call constitutive%evaluate(heads,water,conductivity,capacity,dkdh)
    do i=nn+1,numnod
      water(i)=cofgen(2,i)
    end do

    state%active_nodes=numnod
    allocate(state%pressure_head(numnod),state%water_content(numnod))
    state%pressure_head=heads
    state%water_content=water
    state%ponding_depth=0.0_real64
    state%groundwater_level=gwl
  end subroutine build_origin

  integer function derive_nn(gwl) result(nn)
    real(real64), intent(in) :: gwl
    nn=0
    do while(nn<numnod)
      if(parameters%z(nn+1)<=gwl)exit
      nn=nn+1
    end do
    if(nn>0 .and. nn<numnod)then
      if(parameters%z(nn)-gwl<1.0e-4_real64)nn=nn-1
    end if
  end function derive_nn

  subroutine configure_problem()
    integer :: k
    parameters%parameter_set_id=910102_int64
    parameters%active_nodes=numnod
    allocate(parameters%z(numnod),parameters%dz(numnod),parameters%node_distance(numnod))
    parameters%z=z
    parameters%dz=dz
    parameters%node_distance=disnod(1:numnod)
    allocate(cofgen(24,numnod))
    cofgen=0.0_real64
    do k=1,numnod
      cofgen(1,k)=0.032_real64; cofgen(2,k)=0.423_real64; cofgen(3,k)=4.75_real64
      cofgen(4,k)=0.0135_real64; cofgen(5,k)=0.365_real64; cofgen(6,k)=1.455_real64
      cofgen(7,k)=1.0_real64-1.0_real64/cofgen(6,k)
      cofgen(8,k)=cofgen(4,k)
      cofgen(9,k)=0.0_real64; cofgen(10,k)=cofgen(3,k)
      cofgen(11,k)=0.999_real64; cofgen(12,k)=0.99_real64*cofgen(3,k)
      cofgen(22,k)=-1.0e6_real64; cofgen(23,k)=1.0e-12_real64
    end do
    call initialize_b110_default_mvg_parameters(hydraulic_parameters,cofgen)
    call bind_b110_default_mvg_provider(constitutive,hydraulic_parameters,dt_day)

    allocate(drainage(1,numnod),subsurface(numnod),root_sink(numnod))
    drainage=0.0_real64
    subsurface=0.0_real64
    root_sink=0.0_real64
    call bind_b110_source_sink_provider(source_sink,drainage,subsurface,root_sink)
  end subroutine configure_problem

  subroutine compare_state(a,b,label)
    type(reference_richards_state_binding_t), intent(in) :: a,b
    character(len=*), intent(in) :: label
    call require(array_close_fp(a%h,b%h),label//' heads')
    call require(array_close_fp(a%theta,b%theta),label//' theta')
    call require(close_fp(a%pond,b%pond),label//' pond')
    call require(close_fp(a%qtop,b%qtop),label//' qtop')
    call require(close_fp(a%qbot,b%qbot),label//' qbot')
    call require(close_fp(a%gwlinp,b%gwlinp),label//' gwlinp')
    call require(a%fllowgwl .eqv. b%fllowgwl,label//' fllowgwl')
  end subroutine compare_state

  subroutine compare_origin(a,b)
    type(soil_water_physical_state_t), intent(in) :: a,b
    call require(a%active_nodes==b%active_nodes,'origin active nodes')
    call require(array_close_fp(a%pressure_head,b%pressure_head),'origin heads')
    call require(array_close_fp(a%water_content,b%water_content),'origin water')
    call require(close_fp(a%ponding_depth,b%ponding_depth),'origin ponding')
    call require(close_fp(a%groundwater_level,b%groundwater_level),'origin gwl')
  end subroutine compare_origin

  logical function close_fp(a,b)
    real(real64), intent(in) :: a,b
    close_fp=abs(a-b)<=64.0_real64*epsilon(1.0_real64)*max(1.0_real64,abs(a),abs(b))
  end function close_fp

  logical function array_close_fp(a,b)
    real(real64), intent(in) :: a(:),b(:)
    integer :: i
    array_close_fp=.false.
    if(size(a)/=size(b))return
    do i=1,size(a)
      if(.not.close_fp(a(i),b(i)))return
    end do
    array_close_fp=.true.
  end function array_close_fp

  subroutine require(condition,label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if(.not.condition)then
      write(*,'(A,1X,A)') 'GC_LOW01B_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require

end program test_gc_hlink_low01b_inside_profile

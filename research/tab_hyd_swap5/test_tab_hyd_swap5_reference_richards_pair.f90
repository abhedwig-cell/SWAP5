program test_tab_hyd_swap5_reference_richards_pair
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_physical_state_t, &
       soil_water_solve_request_t, soil_water_solve_result_t, SW_SOLVE_CONVERGED
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, &
       reference_richards_legacy_workspace_t
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_fmr04_fixed_top_provider, only: fmr04_fixed_flux_top_provider_t
  use mod_research_direct_table_provider, only: direct_table_storage_t, direct_table_provider_t, &
       build_direct_table_from_provider, bind_direct_table_provider
  implicit none

  real(real64), parameter :: total_dt=0.25_real64, mass_gate=1.0e-10_real64
  type(soil_water_parameter_set_t), target :: parameters
  type(b110_default_mvg_parameters_t), target :: hydraulic_parameters
  type(b110_default_mvg_provider_t), target :: mvg
  type(direct_table_storage_t), target :: table
  type(direct_table_provider_t), target :: tab
  type(b110_source_sink_provider_t), target :: source_sink
  type(fmr04_fixed_flux_top_provider_t), target :: top_provider
  type(reference_richards_legacy_solver_t) :: solver_mvg, solver_tab
  type(reference_richards_legacy_workspace_t) :: workspace_mvg, workspace_tab
  type(soil_water_physical_state_t) :: state_mvg, state_tab
  type(soil_water_solve_request_t) :: request_mvg, request_tab
  type(soil_water_solve_result_t) :: result_mvg, result_tab
  real(real64), allocatable, target :: drainage(:,:), subsurface(:), root_sink(:)
  real(real64), allocatable :: cofgen(:,:)
  real(real64) :: h0, jump, hbot, k0
  real(real64) :: heads(numnod), water_mvg(numnod), k_mvg(numnod), c_mvg(numnod), dk_mvg(numnod)
  real(real64) :: water_tab(numnod), k_tab(numnod), c_tab(numnod), dk_tab(numnod)
  real(real64) :: max_initial_theta_diff, max_head_diff, max_water_diff
  real(real64) :: top_flux_diff, bottom_flux_diff, mass_mvg, mass_tab
  integer :: stat

  call read_inputs(h0,jump)
  hbot=h0+jump
  call configure_problem(h0,parameters,hydraulic_parameters,mvg,source_sink,top_provider, &
       drainage,subsurface,root_sink,cofgen,k0)

  call build_direct_table_from_provider(table,mvg,numnod,512,-1.0e7_real64,1.0e-2_real64)
  call bind_direct_table_provider(tab,table)

  heads=h0
  call mvg%evaluate(heads,water_mvg,k_mvg,c_mvg,dk_mvg)
  call tab%evaluate(heads,water_tab,k_tab,c_tab,dk_tab)
  max_initial_theta_diff=maxval(abs(water_tab-water_mvg))

  call make_state(state_mvg,heads,water_mvg)
  call make_state(state_tab,heads,water_tab)
  call make_request(request_mvg,parameters,state_mvg,mvg,source_sink,top_provider,k0,hbot)
  call make_request(request_tab,parameters,state_tab,tab,source_sink,top_provider,k0,hbot)

  call solver_mvg%solve(request_mvg,workspace_mvg,result_mvg)
  call solver_tab%solve(request_tab,workspace_tab,result_tab)

  call require(result_mvg%status==SW_SOLVE_CONVERGED,1)
  call require(result_tab%status==SW_SOLVE_CONVERGED,2)
  call require(all(ieee_is_finite(result_mvg%candidate_state%pressure_head)),3)
  call require(all(ieee_is_finite(result_tab%candidate_state%pressure_head)),4)

  max_head_diff=maxval(abs(result_tab%candidate_state%pressure_head-result_mvg%candidate_state%pressure_head))
  max_water_diff=maxval(abs(result_tab%candidate_state%water_content-result_mvg%candidate_state%water_content))
  top_flux_diff=abs(result_tab%top_flux-result_mvg%top_flux)
  bottom_flux_diff=abs(result_tab%bottom_flux-result_mvg%bottom_flux)
  mass_mvg=abs(result_mvg%unrounded_mass_balance_residual)
  mass_tab=abs(result_tab%unrounded_mass_balance_residual)

  call require(mass_mvg<=mass_gate,5)
  call require(mass_tab<=mass_gate,6)

  write(*,'(A,ES24.16,A,ES24.16,A,ES24.16,A,ES24.16,A,ES24.16,A,ES24.16,A,ES24.16,A,I0,A,I0)') &
       'TAB_HYD_SWAP5_RICHARDS:H0=',h0,':JUMP=',jump,':INIT_THETA_DIFF=',max_initial_theta_diff, &
       ':HEAD_DIFF=',max_head_diff,':WATER_DIFF=',max_water_diff,':TOP_FLUX_DIFF=',top_flux_diff, &
       ':BOTTOM_FLUX_DIFF=',bottom_flux_diff,':ITER_MVG=',result_mvg%diagnostics%nonlinear_iterations, &
       ':ITER_TABLE=',result_tab%diagnostics%nonlinear_iterations
  write(*,'(A,ES24.16,A,ES24.16)') 'TAB_HYD_SWAP5_RICHARDS_MASS:MVG=',mass_mvg,':TABLE=',mass_tab
  write(*,'(A)') 'TAB_HYD_SWAP5_REFERENCE_RICHARDS_PAIR=PASS'

contains

  subroutine read_inputs(initial_head,jump_head)
    real(real64), intent(out) :: initial_head,jump_head
    character(len=128) :: arg
    if(command_argument_count()/=2) error stop 'TAB-HYD pair requires h0 jump'
    call get_command_argument(1,arg); read(arg,*,iostat=stat) initial_head
    if(stat/=0) error stop 'bad h0'
    call get_command_argument(2,arg); read(arg,*,iostat=stat) jump_head
    if(stat/=0) error stop 'bad jump'
  end subroutine read_inputs

  subroutine configure_problem(initial_head,p,hp,provider,sp,tp,qdra,qssdi,qrot,c,k0_out)
    real(real64), intent(in) :: initial_head
    type(soil_water_parameter_set_t), target, intent(out) :: p
    type(b110_default_mvg_parameters_t), target, intent(out) :: hp
    type(b110_default_mvg_provider_t), target, intent(out) :: provider
    type(b110_source_sink_provider_t), target, intent(out) :: sp
    type(fmr04_fixed_flux_top_provider_t), target, intent(out) :: tp
    real(real64), allocatable, target, intent(out) :: qdra(:,:),qssdi(:),qrot(:)
    real(real64), allocatable, intent(out) :: c(:,:)
    real(real64), intent(out) :: k0_out
    real(real64) :: h(numnod),w(numnod),k(numnod),cap(numnod),dk(numnod)
    integer :: j

    p%parameter_set_id=991024_int64
    p%active_nodes=numnod
    allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod))
    p%z=z; p%dz=dz; p%node_distance=disnod(1:numnod)

    allocate(c(24,numnod)); c=0.0_real64
    do j=1,numnod
      c(1,j)=0.032_real64; c(2,j)=0.423_real64; c(3,j)=4.75_real64
      c(4,j)=0.0135_real64; c(5,j)=0.365_real64; c(6,j)=1.455_real64
      c(7,j)=1.0_real64-1.0_real64/c(6,j); c(8,j)=c(4,j)
      c(9,j)=0.0_real64; c(10,j)=c(3,j); c(11,j)=0.999_real64
      c(12,j)=0.99_real64*c(3,j); c(22,j)=-1.0e6_real64; c(23,j)=1.0e-12_real64
    end do
    call initialize_b110_default_mvg_parameters(hp,c)
    call bind_b110_default_mvg_provider(provider,hp,total_dt)
    h=initial_head
    call provider%evaluate(h,w,k,cap,dk)
    k0_out=k(1)

    allocate(qdra(1,numnod),qssdi(numnod),qrot(numnod))
    qdra=0.0_real64; qssdi=0.0_real64; qrot=0.0_real64
    call bind_b110_source_sink_provider(sp,qdra,qssdi,qrot)
    if(.not.same_type_as(tp,tp)) error stop 'invalid fixed top fixture'
  end subroutine configure_problem

  subroutine make_state(state,h,w)
    type(soil_water_physical_state_t), intent(out) :: state
    real(real64), intent(in) :: h(:),w(:)
    state%active_nodes=numnod
    allocate(state%pressure_head(numnod),state%water_content(numnod))
    state%pressure_head=h
    state%water_content=w
    state%ponding_depth=0.0_real64
    state%groundwater_level=-2.0_real64
  end subroutine make_state

  subroutine make_request(r,p,state,constitutive,sp,tp,top_k,bottom_head)
    type(soil_water_solve_request_t), intent(out) :: r
    type(soil_water_parameter_set_t), target, intent(in) :: p
    type(soil_water_physical_state_t), intent(in) :: state
    class(*), target, intent(in) :: constitutive
    type(b110_source_sink_provider_t), target, intent(in) :: sp
    type(fmr04_fixed_flux_top_provider_t), target, intent(in) :: tp
    real(real64), intent(in) :: top_k,bottom_head

    r=soil_water_solve_request_t()
    r%parameters=>p
    r%base_state=state
    r%step_duration=total_dt
    r%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX
    r%boundary%bottom_mode=5
    r%boundary%top_flux=-top_k
    r%boundary%top_head=h0
    r%boundary%bottom_flux=12345.678_real64
    r%boundary%bottom_head=bottom_head
    r%physical%macropore_active=.false.
    r%numerical%max_iterations=8
    r%numerical%max_backtracking=4
    r%numerical%conductivity_implicit_mode=0
    r%numerical%conductivity_mean_method=1
    r%numerical%min_step_duration=1.0e-6_real64
    r%numerical%compartment_balance_tolerance=mass_gate
    r%numerical%total_balance_tolerance=mass_gate
    r%numerical%head_abs_tolerance=1.0e-12_real64
    r%numerical%head_rel_tolerance=1.0e-12_real64
    r%numerical%ponding_tolerance=1.0e-12_real64
    select type(constitutive)
    type is (b110_default_mvg_provider_t)
      r%evaluation%constitutive=>constitutive
    type is (direct_table_provider_t)
      r%evaluation%constitutive=>constitutive
    class default
      error stop 'unsupported constitutive provider'
    end select
    r%evaluation%source_sink=>sp
    r%evaluation%top_boundary=>tp
  end subroutine make_request

  subroutine require(condition,code)
    logical, intent(in) :: condition
    integer, intent(in) :: code
    if(.not.condition) then
      write(*,'(A,I0)') 'TAB_HYD_SWAP5_RICHARDS_FAIL=',code
      error stop 1
    end if
  end subroutine require

end program test_tab_hyd_swap5_reference_richards_pair

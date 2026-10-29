program groundwater_driver
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_physical_state_t, &
       soil_water_solve_request_t, soil_water_solve_result_t, soil_water_temporal_indicator_request_t, &
       soil_water_temporal_indicator_result_t, SW_SOLVE_CONVERGED, SW_TEMPORAL_INDICATOR_AVAILABLE, &
       SW_TEMPORAL_INDICATOR_UNAVAILABLE
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, &
       reference_richards_legacy_workspace_t
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  implicit none
  real(real64), parameter :: total_dt = 0.01_real64, hard_mass_gate = 1.0e-12_real64
  type(soil_water_parameter_set_t), target :: parameters
  type(b110_default_mvg_parameters_t), target :: hydraulic_parameters
  type(b110_default_mvg_provider_t), target :: constitutive
  type(b110_source_sink_provider_t), target :: source_sink
  type(fixed_flux_top_boundary_provider_t), target :: top_provider
  type(reference_richards_legacy_solver_t) :: solver
  type(reference_richards_legacy_workspace_t) :: workspace
  type(soil_water_physical_state_t) :: initial_state
  type(soil_water_solve_request_t) :: request
  type(soil_water_solve_result_t) :: result, face_result
  type(soil_water_temporal_indicator_request_t) :: indicator_request
  type(soil_water_temporal_indicator_result_t) :: warmup_result, indicator_result
  real(real64), allocatable, target :: drainage(:,:), subsurface(:), root_sink(:)
  real(real64), allocatable :: cofgen(:,:)
  real(real64) :: h0, jump, hbot, conductivity0, mass_residual
  real(real64) :: heads0(numnod), water0(numnod), conductivity0_nodes(numnod), capacity0(numnod), dkdh0(numnod)
  real(real64) :: static_residual(numnod), hdot_n(numnod), storage0, storage1, total_in, total_out
  real(real64) :: state_head_snapshot(numnod), state_water_snapshot(numnod), solver_mass
  real(real64) :: top_flux_snapshot, bottom_flux_snapshot, mass_snapshot
  integer :: status_snapshot
  integer :: nonlinear_before, jacobian_before, linear_before, backtracking_before, retries_before
  integer :: i

  call configure_problem(-1d0,parameters,hydraulic_parameters,constitutive,source_sink,top_provider, &
       initial_state,drainage,subsurface,root_sink,cofgen,conductivity0)
  initial_state%pressure_head=-1.5d0-z
  call constitutive%evaluate(initial_state%pressure_head,initial_state%water_content,conductivity0_nodes,capacity0,dkdh0)
  initial_state%groundwater_level=-1.5d0
  request%parameters=>parameters;request%base_state=initial_state
  request%step_duration=total_dt
  request%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX
  request%boundary%bottom_mode=1
  request%boundary%top_flux=0d0
  request%boundary%bottom_head=-1.5d0
  request%numerical%max_iterations=64;request%numerical%max_backtracking=16
  request%numerical%conductivity_mean_method=1
  request%numerical%min_step_duration=1d-10
  request%numerical%compartment_balance_tolerance=1d-10
  request%numerical%total_balance_tolerance=1d-10
  request%numerical%head_abs_tolerance=1d-8
  request%numerical%head_rel_tolerance=1d-8
  request%numerical%ponding_tolerance=1d-10
  request%evaluation%constitutive=>constitutive
  request%evaluation%source_sink=>source_sink
  request%evaluation%top_boundary=>top_provider
  call solver%solve(request,workspace,result)
  call require(result%status/=SW_SOLVE_CONVERGED,'default off')
  request%physical%prescribed_groundwater_active=.true.
  do i=1,5
   select case(i)
   case(1);request%boundary%bottom_head=-1.5d0
   case(2);request%boundary%bottom_head=-1.2d0
   case(3);request%boundary%bottom_head=-2d0
   case(4);request%boundary%bottom_head=-4d0
   case(5);request%boundary%bottom_head=-.75d0
   end select
   call solver%solve(request,workspace,result)
   write(*,*)'SOLVE',i,result%status,trim(result%diagnostics%route)
   call require(result%status==SW_SOLVE_CONVERGED,'groundwater convergence')
   storage0=sum(initial_state%water_content*dz)+initial_state%ponding_depth
   storage1=sum(result%candidate_state%water_content*dz)+result%candidate_state%ponding_depth
   mass_residual=storage1-storage0-total_dt*(result%bottom_flux-result%top_flux)
   write(*,*)'GROUNDWATER',i,mass_residual,result%bottom_flux
   call require(abs(mass_residual)<1d-10,'groundwater whole profile mass')
   if(i==1) call require(abs(result%bottom_flux)<1d-9,'hydrostatic equilibrium')
   if(i==4)then
    request%boundary%bottom_mode=5
    request%physical%prescribed_groundwater_active=.false.
    request%boundary%bottom_head=-4d0-z(numnod)+.5d0*dz(numnod)
    call solver%solve(request,workspace,face_result)
    call require(face_result%status==SW_SOLVE_CONVERGED,'face comparator')
    call require(all(face_result%candidate_state%pressure_head==result%candidate_state%pressure_head),'below-profile face identity')
    call require(face_result%bottom_flux==result%bottom_flux,'below-profile flux identity')
    request%boundary%bottom_mode=1
    request%physical%prescribed_groundwater_active=.true.
   end if
   call require(all(request%base_state%pressure_head==initial_state%pressure_head),'rollback base heads')
   call require(all(request%base_state%water_content==initial_state%water_content),'rollback base water')
  end do
  write(*,*)'PRESCRIBED_GROUNDWATER_DIRECT_PASS'
contains
  subroutine configure_problem(initial_head,p,hp,cp,sp,tp,state,qdra,qssdi,qrot,c,k0)
    real(real64), intent(in) :: initial_head
    type(soil_water_parameter_set_t), target, intent(out) :: p
    type(b110_default_mvg_parameters_t), target, intent(out) :: hp
    type(b110_default_mvg_provider_t), target, intent(out) :: cp
    type(b110_source_sink_provider_t), target, intent(out) :: sp
    type(fixed_flux_top_boundary_provider_t), target, intent(out) :: tp
    type(soil_water_physical_state_t), intent(out) :: state
    real(real64), allocatable, target, intent(out) :: qdra(:,:),qssdi(:),qrot(:)
    real(real64), allocatable, intent(out) :: c(:,:)
    real(real64), intent(out) :: k0
    real(real64) :: heads(numnod),water(numnod),conductivity(numnod),capacity(numnod),dkdh(numnod)
    integer :: k

    p%parameter_set_id = 250251_int64
    p%active_nodes = numnod
    allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod))
    p%z = z
    p%dz = dz
    p%node_distance(1)=0.5_real64*dz(1)
    p%node_distance(2:numnod)=z(1:numnod-1)-z(2:numnod)

    allocate(c(24,numnod))
    c = 0.0_real64
    do k = 1, numnod
       c(1,k)=0.032_real64; c(2,k)=0.423_real64; c(3,k)=4.75_real64
       c(4,k)=0.0135_real64; c(5,k)=0.365_real64; c(6,k)=1.455_real64
       c(7,k)=1.0_real64-1.0_real64/c(6,k); c(8,k)=c(4,k)
       c(9,k)=0.0_real64; c(10,k)=c(3,k); c(11,k)=0.999_real64
       c(12,k)=0.99_real64*c(3,k); c(22,k)=-1.0e6_real64; c(23,k)=1.0e-12_real64
    end do
    call initialize_b110_default_mvg_parameters(hp,c)
    call bind_b110_default_mvg_provider(cp,hp,total_dt)
    heads = initial_head
    call cp%evaluate(heads,water,conductivity,capacity,dkdh)
    do k = 2, numnod
       call require(transfer(conductivity(k),0_int64) == transfer(conductivity(1),0_int64), &
            'uniform initial K configure')
    end do
    k0 = conductivity(1)

    state%active_nodes = numnod
    allocate(state%pressure_head(numnod),state%water_content(numnod))
    state%pressure_head = heads
    state%water_content = water
    state%ponding_depth = 0.0_real64
    state%groundwater_level = -2.0_real64

    allocate(qdra(1,numnod),qssdi(numnod),qrot(numnod))
    qdra = 0.0_real64
    qssdi = 0.0_real64
    qrot = 0.0_real64
    call bind_b110_source_sink_provider(sp,qdra,qssdi,qrot)
  end subroutine configure_problem

  subroutine require(condition,label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
       write(*,'(A,1X,A)') 'FSI25_REFERENCE_INDICATOR_FAIL',trim(label)
       error stop 1
    end if
  end subroutine require

end program

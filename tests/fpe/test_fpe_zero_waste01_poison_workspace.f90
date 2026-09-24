program test_fpe_zero_waste01_poison_workspace
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_physical_state_t, &
       soil_water_solve_request_t, soil_water_solve_result_t, SW_SOLVE_CONVERGED
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, &
       reference_richards_legacy_workspace_t
  use mod_reference_richards_workspace, only: ensure_reference_workspace_shape, poison_reference_workspace
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  implicit none

  real(real64), parameter :: h0=-75.0_real64, dt=0.25_real64, tol=1.0e-12_real64
  type(soil_water_parameter_set_t), target :: parameters
  type(b110_default_mvg_parameters_t), target :: hydraulic_parameters
  type(b110_default_mvg_provider_t), target :: constitutive
  type(b110_source_sink_provider_t), target :: source_sink
  type(fixed_flux_top_boundary_provider_t), target :: top_provider
  type(reference_richards_legacy_solver_t) :: solver
  type(reference_richards_legacy_workspace_t) :: clean_workspace, poisoned_workspace
  type(soil_water_physical_state_t) :: initial_state
  type(soil_water_solve_request_t) :: request
  type(soil_water_solve_result_t) :: clean_result, poisoned_result
  real(real64), allocatable, target :: drainage(:,:), subsurface(:), root_sink(:)
  real(real64), allocatable :: cofgen(:,:)
  real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
  real(real64) :: qeq
  integer :: i

  call configure()
  heads = h0
  call constitutive%evaluate(heads,water,conductivity,capacity,dkdh)
  qeq = -conductivity(1)

  request = soil_water_solve_request_t()
  request%parameters => parameters
  request%base_state = initial_state
  request%step_duration = dt
  request%boundary%top_mode = FSI_TOP_MODE_EXPLICIT_FLUX
  request%boundary%bottom_mode = 2
  request%boundary%top_flux = qeq
  request%boundary%top_head = h0
  request%boundary%bottom_flux = qeq
  request%boundary%bottom_head = -999999.0_real64
  request%physical%macropore_active = .false.
  request%numerical%max_iterations = 16
  request%numerical%max_backtracking = 8
  request%numerical%conductivity_implicit_mode = 0
  request%numerical%conductivity_mean_method = 1
  request%numerical%min_step_duration = 1.0e-8_real64
  request%numerical%compartment_balance_tolerance = tol
  request%numerical%total_balance_tolerance = tol
  request%numerical%head_abs_tolerance = tol
  request%numerical%head_rel_tolerance = tol
  request%numerical%ponding_tolerance = tol
  request%evaluation%constitutive => constitutive
  request%evaluation%source_sink => source_sink
  request%evaluation%top_boundary => top_provider

  call solver%solve(request,clean_workspace,clean_result)
  call require(clean_result%status == SW_SOLVE_CONVERGED,'clean solve converged')

  call ensure_reference_workspace_shape(poisoned_workspace%richards,numnod)
  call poison_reference_workspace(poisoned_workspace%richards)
  call solver%solve(request,poisoned_workspace,poisoned_result)
  call require(poisoned_result%status == SW_SOLVE_CONVERGED,'poisoned solve converged')

  call require(clean_result%candidate_state%active_nodes == poisoned_result%candidate_state%active_nodes, &
       'active node identity')
  call require(same_vector_bits(clean_result%candidate_state%pressure_head, &
       poisoned_result%candidate_state%pressure_head),'pressure-head bit identity')
  call require(same_vector_bits(clean_result%candidate_state%water_content, &
       poisoned_result%candidate_state%water_content),'water-content bit identity')
  call require(same_bits(clean_result%candidate_state%ponding_depth,poisoned_result%candidate_state%ponding_depth), &
       'ponding bit identity')
  call require(same_bits(clean_result%top_flux,poisoned_result%top_flux),'top-flux bit identity')
  call require(same_bits(clean_result%bottom_flux,poisoned_result%bottom_flux),'bottom-flux bit identity')
  call require(clean_result%diagnostics%nonlinear_iterations == poisoned_result%diagnostics%nonlinear_iterations, &
       'nonlinear-iteration identity')
  call require(clean_result%diagnostics%workspace_full_resets == 0 .and. &
       poisoned_result%diagnostics%workspace_full_resets == 0,'no full reset in either solve')
  call require(clean_result%diagnostics%workspace_zeroed_bytes == 0_int64 .and. &
       poisoned_result%diagnostics%workspace_zeroed_bytes == 0_int64,'no full-reset zeroed bytes')

  write(*,'(A)') 'FPE_ZERO_WASTE01_POISON_WORKSPACE_EQUIVALENCE=PASS'

contains

  subroutine configure()
    do i=1,numnod
      continue
    end do
    parameters%parameter_set_id=770001_int64
    parameters%active_nodes=numnod
    allocate(parameters%z(numnod),parameters%dz(numnod),parameters%node_distance(numnod))
    parameters%z=z
    parameters%dz=dz
    parameters%node_distance=disnod(1:numnod)

    allocate(cofgen(24,numnod))
    cofgen=0.0_real64
    do i=1,numnod
      cofgen(1,i)=0.032_real64
      cofgen(2,i)=0.423_real64
      cofgen(3,i)=4.75_real64
      cofgen(4,i)=0.0135_real64
      cofgen(5,i)=0.365_real64
      cofgen(6,i)=1.455_real64
      cofgen(7,i)=1.0_real64-1.0_real64/cofgen(6,i)
      cofgen(8,i)=cofgen(4,i)
      cofgen(9,i)=0.0_real64
      cofgen(10,i)=cofgen(3,i)
      cofgen(11,i)=0.999_real64
      cofgen(12,i)=0.99_real64*cofgen(3,i)
      cofgen(22,i)=-1.0e6_real64
      cofgen(23,i)=1.0e-12_real64
    end do

    call initialize_b110_default_mvg_parameters(hydraulic_parameters,cofgen)
    call bind_b110_default_mvg_provider(constitutive,hydraulic_parameters,dt)
    heads=h0
    call constitutive%evaluate(heads,water,conductivity,capacity,dkdh)

    initial_state%active_nodes=numnod
    allocate(initial_state%pressure_head(numnod),initial_state%water_content(numnod))
    initial_state%pressure_head=heads
    initial_state%water_content=water
    initial_state%ponding_depth=0.0_real64
    initial_state%groundwater_level=-2.0_real64

    allocate(drainage(1,numnod),subsurface(numnod),root_sink(numnod))
    drainage=0.0_real64
    subsurface=0.0_real64
    root_sink=0.0_real64
    call bind_b110_source_sink_provider(source_sink,drainage,subsurface,root_sink)
  end subroutine configure

  pure logical function same_bits(a,b)
    real(real64), intent(in) :: a,b
    same_bits = transfer(a,0_int64) == transfer(b,0_int64)
  end function same_bits

  pure logical function same_vector_bits(a,b)
    real(real64), intent(in) :: a(:),b(:)
    integer :: k
    same_vector_bits=.false.
    if(size(a)/=size(b)) return
    do k=1,size(a)
      if(.not.same_bits(a(k),b(k))) return
    end do
    same_vector_bits=.true.
  end function same_vector_bits

  subroutine require(condition,label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if(.not.condition) then
      write(*,'(A,1X,A)') 'FPE_ZERO_WASTE01_POISON_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_fpe_zero_waste01_poison_workspace

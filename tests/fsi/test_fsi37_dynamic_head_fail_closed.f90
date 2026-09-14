program test_fsi37_dynamic_head_fail_closed
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_physical_state_t, &
       soil_water_solve_request_t, soil_water_solve_result_t, soil_water_boundary_conditions_t, &
       soil_water_top_boundary_result_t, SW_SOLVE_CONVERGED, SW_TOP_BOUNDARY_AVAILABLE
  use mod_soil_water_accepted_step_direction_contract, only: &
       soil_water_accepted_step_direction_request_t, soil_water_accepted_step_direction_result_t, &
       SW_STEP_DIRECTION_UNAVAILABLE, SW_STEP_CONTROL_BOTTOM_FLUX
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, &
       reference_richards_legacy_workspace_t
  use mod_reference_richards_accepted_step_directional_service, only: solve_with_accepted_step_direction
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_DYNAMIC_PROVIDER
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_b110_dynamic_top_boundary_solver_adapter, only: b110_dynamic_top_boundary_solver_provider_t, &
       bind_b110_dynamic_top_boundary_solver_provider
  use mod_b110_dynamic_top_boundary_provider, only: B110_DYN_TOP_ATMOSPHERIC_HEAD_CM
  implicit none

  real(real64), parameter :: dt = 0.125_real64
  real(real64), parameter :: hard_mass_gate = 1.0e-12_real64
  type(soil_water_parameter_set_t), target :: parameters
  type(b110_default_mvg_parameters_t), target :: hydraulic_parameters
  type(b110_default_mvg_provider_t), target :: constitutive
  type(b110_source_sink_provider_t), target :: source_sink
  type(b110_dynamic_top_boundary_solver_provider_t), target :: top
  type(soil_water_physical_state_t) :: state
  type(soil_water_boundary_conditions_t) :: probe_boundary
  type(soil_water_top_boundary_result_t) :: probe, final_probe
  type(soil_water_solve_request_t) :: request
  type(soil_water_solve_result_t) :: result_on, result_off
  type(soil_water_accepted_step_direction_request_t) :: drequest
  type(soil_water_accepted_step_direction_result_t) :: dresult
  type(reference_richards_legacy_solver_t) :: solver
  type(reference_richards_legacy_workspace_t) :: ws_on, ws_off
  real(real64), allocatable, target :: drainage(:,:), subsurface(:), root_sink(:)
  real(real64), allocatable :: raw(:,:)

  call configure_shared_problem(parameters,hydraulic_parameters,constitutive,source_sink, &
       drainage,subsurface,root_sink,raw)
  call make_atmospheric_state(state)
  call bind_b110_dynamic_top_boundary_solver_provider(top,parameters,hydraulic_parameters, &
       1,0.0_real64,dt,0.0_real64,0.0_real64,0.0_real64,0.0_real64, &
       0.0_real64,0.0_real64,10.0_real64,0.5_real64,1.0_real64)

  probe_boundary=soil_water_boundary_conditions_t()
  call top%evaluate(state%pressure_head(1),state%water_content(1),state%ponding_depth,probe_boundary,probe)
  call require(probe%status==SW_TOP_BOUNDARY_AVAILABLE,'atmospheric provider available')
  call require(trim(probe%route)=='atmospheric-head','atmospheric provider route')

  call make_request(state,top,probe%actual_top_flux,request)
  drequest%requested=.true.
  drequest%control_coordinate=SW_STEP_CONTROL_BOTTOM_FLUX
  allocate(drequest%incoming_pressure_head(numnod),drequest%incoming_water_content(numnod))
  drequest%incoming_pressure_head=0.0_real64
  drequest%incoming_water_content=0.0_real64
  drequest%incoming_ponding_depth=0.0_real64
  drequest%direct_control_derivative=1.0_real64

  call solve_with_accepted_step_direction(solver,request,ws_on,drequest,result_on,dresult)
  call require(result_on%status==SW_SOLVE_CONVERGED,'atmospheric physical solve remains valid')
  call require(abs(result_on%unrounded_mass_balance_residual)<=hard_mass_gate,'atmospheric hard mass closure')
  call require(dresult%status==SW_STEP_DIRECTION_UNAVAILABLE .and. .not.dresult%available, &
       'atmospheric derivative fails closed')
  call require(trim(dresult%route)=='dynamic-route-not-surface-flux','atmospheric fail-closed route')
  call require(dresult%additional_tridiagonal_backsolves==0,'atmospheric no tangent backsolve')
  call require(dresult%additional_jacobian_builds==0,'atmospheric no derivative Jacobian build')
  call require(dresult%additional_full_nonlinear_solves==0,'atmospheric no extra nonlinear solve')

  call top%evaluate(result_on%candidate_state%pressure_head(1),result_on%candidate_state%water_content(1), &
       result_on%candidate_state%ponding_depth,probe_boundary,final_probe)
  call require(final_probe%status==SW_TOP_BOUNDARY_AVAILABLE,'atmospheric final provider available')
  call require(trim(final_probe%route)=='atmospheric-head','atmospheric final route preserved')

  call solver%solve(request,ws_off,result_off)
  call require(result_off%status==SW_SOLVE_CONVERGED,'atmospheric baseline solve converged')
  call require(same_bits_vector(result_on%candidate_state%pressure_head,result_off%candidate_state%pressure_head), &
       'atmospheric sensitivity ON/OFF head identity')
  call require(same_bits_vector(result_on%candidate_state%water_content,result_off%candidate_state%water_content), &
       'atmospheric sensitivity ON/OFF theta identity')
  call require(same_bits_scalar(result_on%candidate_state%ponding_depth,result_off%candidate_state%ponding_depth), &
       'atmospheric sensitivity ON/OFF pond identity')
  call require(same_bits_scalar(result_on%top_flux,result_off%top_flux),'atmospheric sensitivity ON/OFF qtop identity')
  call require(same_bits_scalar(result_on%bottom_flux,result_off%bottom_flux),'atmospheric sensitivity ON/OFF qbot identity')
  call require(same_bits_scalar(result_on%unrounded_mass_balance_residual,result_off%unrounded_mass_balance_residual), &
       'atmospheric sensitivity ON/OFF mass identity')

  write(*,'(A)') 'FSI37_DYNAMIC_HEAD_PHYSICAL_VALID=PASS'
  write(*,'(A)') 'FSI37_DYNAMIC_HEAD_SENSITIVITY_FAIL_CLOSED=PASS'
  write(*,'(A)') 'FSI37_DYNAMIC_HEAD_ON_OFF_IDENTITY=PASS'
  write(*,'(A)') 'FSI37_DYNAMIC_HEAD_FAIL_CLOSED PASS'

contains

  subroutine configure_shared_problem(p,hp,cp,sp,qdra,qssdi,qrot,c)
    type(soil_water_parameter_set_t), target, intent(out) :: p
    type(b110_default_mvg_parameters_t), target, intent(out) :: hp
    type(b110_default_mvg_provider_t), target, intent(out) :: cp
    type(b110_source_sink_provider_t), target, intent(out) :: sp
    real(real64), allocatable, target, intent(out) :: qdra(:,:),qssdi(:),qrot(:)
    real(real64), allocatable, intent(out) :: c(:,:)
    integer :: k

    p%parameter_set_id=370003_int64
    p%active_nodes=numnod
    allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod))
    p%z=z; p%dz=dz; p%node_distance=disnod(1:numnod)
    allocate(c(24,numnod)); c=0.0_real64
    do k=1,numnod
      c(1,k)=0.032_real64; c(2,k)=0.423_real64; c(3,k)=4.75_real64
      c(4,k)=0.0135_real64; c(5,k)=0.365_real64; c(6,k)=1.455_real64
      c(7,k)=1.0_real64-1.0_real64/c(6,k); c(8,k)=c(4,k); c(9,k)=0.0_real64
      c(10,k)=c(3,k); c(11,k)=0.999_real64; c(12,k)=0.99_real64*c(3,k)
      c(13,k)=0.10_real64; c(14,k)=1.50_real64; c(15,k)=0.50_real64
      c(22,k)=-1.0e6_real64; c(23,k)=1.0e-12_real64
    end do
    call initialize_b110_default_mvg_parameters(hp,c)
    call bind_b110_default_mvg_provider(cp,hp,dt)
    allocate(qdra(1,numnod),qssdi(numnod),qrot(numnod))
    qdra=0.0_real64; qssdi=0.0_real64; qrot=0.0_real64
    call bind_b110_source_sink_provider(sp,qdra,qssdi,qrot)
  end subroutine configure_shared_problem

  subroutine make_atmospheric_state(x)
    type(soil_water_physical_state_t), intent(out) :: x
    real(real64) :: heads(numnod),water(numnod),conductivity(numnod),capacity(numnod),dkdh(numnod)
    heads=B110_DYN_TOP_ATMOSPHERIC_HEAD_CM
    call constitutive%evaluate(heads,water,conductivity,capacity,dkdh)
    call require(all(ieee_is_finite(water)) .and. all(ieee_is_finite(conductivity)), &
         'atmospheric constitutive values finite')
    x%active_nodes=numnod
    allocate(x%pressure_head(numnod),x%water_content(numnod))
    x%pressure_head=heads
    x%water_content=water
    x%ponding_depth=0.0_real64
    x%groundwater_level=-2.0_real64
  end subroutine make_atmospheric_state

  subroutine make_request(x,provider,bottom_flux,r)
    type(soil_water_physical_state_t), intent(in) :: x
    type(b110_dynamic_top_boundary_solver_provider_t), target, intent(in) :: provider
    real(real64), intent(in) :: bottom_flux
    type(soil_water_solve_request_t), intent(out) :: r
    r=soil_water_solve_request_t()
    r%parameters=>parameters
    r%base_state=x
    r%step_duration=dt
    r%boundary%top_mode=FSI_TOP_MODE_DYNAMIC_PROVIDER
    r%boundary%bottom_mode=SW_STEP_CONTROL_BOTTOM_FLUX
    r%boundary%top_flux=98765.4321_real64
    r%boundary%top_head=-98765.4321_real64
    r%boundary%bottom_flux=bottom_flux
    r%boundary%bottom_head=87654.321_real64
    r%physical%macropore_active=.false.
    r%numerical%max_iterations=12
    r%numerical%max_backtracking=6
    r%numerical%conductivity_implicit_mode=0
    r%numerical%conductivity_mean_method=1
    r%numerical%min_step_duration=1.0e-6_real64
    r%numerical%compartment_balance_tolerance=hard_mass_gate
    r%numerical%total_balance_tolerance=hard_mass_gate
    r%numerical%head_abs_tolerance=1.0e-12_real64
    r%numerical%head_rel_tolerance=1.0e-12_real64
    r%numerical%ponding_tolerance=hard_mass_gate
    r%evaluation%constitutive=>constitutive
    r%evaluation%source_sink=>source_sink
    r%evaluation%dynamic_top_boundary=>provider
  end subroutine make_request

  logical function same_bits_scalar(a,b)
    real(real64), intent(in) :: a,b
    same_bits_scalar=transfer(a,0_int64)==transfer(b,0_int64)
  end function same_bits_scalar

  logical function same_bits_vector(a,b)
    real(real64), intent(in) :: a(:),b(:)
    integer :: i
    same_bits_vector=size(a)==size(b)
    if(.not.same_bits_vector)return
    do i=1,size(a)
       if(.not.same_bits_scalar(a(i),b(i)))then
          same_bits_vector=.false.; return
       end if
    end do
  end function same_bits_vector

  subroutine require(condition,label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if(.not.condition)then
       write(*,'(A,1X,A)')'FSI37_HEAD_FAIL',trim(label)
       error stop 1
    end if
  end subroutine require

end program test_fsi37_dynamic_head_fail_closed

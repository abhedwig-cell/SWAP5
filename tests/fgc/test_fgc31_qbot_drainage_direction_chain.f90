program test_fgc31_qbot_drainage_direction_chain
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_physical_state_t
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_b110_smooth_freatic_projection, only: b110_smooth_freatic_projection_diagnostics_t, &
       evaluate_b110_smooth_freatic_projection, B110_GWL_PROJECTION_OK
  use mod_fmr_drainage_response_binding, only: fmr_drainage_response_level_parameters_t, &
       fmr_drainage_response_level_control_t, fmr_drainage_response_diagnostics_t, &
       evaluate_fmr_drainage_response_bottom_lumped, FMR_DRAIN_VARIANT_TABULATED, FMR_DRAIN_BIND_OK
  use mod_fmr_drainage_qbot_directional_binding, only: compose_fmr_qbot_drainage_sink_direction, &
       FMR_QBOT_DRAIN_DIRECTION_OK, FMR_QBOT_DRAIN_DIRECTION_TANGENT_UNAVAILABLE
  implicit none

  type(soil_water_parameter_set_t) :: p
  type(soil_water_physical_state_t) :: state
  type(fmr_drainage_response_level_parameters_t), allocatable :: levels(:)
  type(fmr_drainage_response_level_control_t), allocatable :: controls(:)
  type(fmr_drainage_response_diagnostics_t) :: diagnostics, bad
  real(real64), allocatable :: qdra(:,:), sink_direction(:)
  real(real64) :: dh(4), dgwl, expected_dgwl, expected_sink, fd
  character(len=64) :: route
  integer :: status

  call initialize_case()
  call evaluate_nominal(diagnostics, qdra)

  dh = [0.02_real64, -0.03_real64, 0.20_real64, 0.30_real64]
  call compose_fmr_qbot_drainage_sink_direction(p, state, dh, diagnostics, sink_direction, dgwl, status, route)
  call require(status == FMR_QBOT_DRAIN_DIRECTION_OK, 'production composition unavailable')
  call require(trim(route) == 'lagged-start-gwl-to-bottom-lumped-drainage-direction', 'unexpected production route')

  ! Crossing is between nodes 3 and 4:
  ! dgwl = d * (h4*dh3 - h3*dh4)/(h4-h3)^2
  expected_dgwl = 1.0_real64*(0.8_real64*0.20_real64 - (-0.2_real64)*0.30_real64)
  call require(abs(dgwl-expected_dgwl) <= 2.0e-15_real64, 'analytic dgwl mismatch')
  expected_sink = (diagnostics%level(1)%dq_dgroundwater_level + &
                   diagnostics%level(2)%dq_dgroundwater_level) * expected_dgwl
  call require(size(sink_direction) == 4, 'sink direction shape')
  call require(all(sink_direction(1:3) == 0.0_real64), 'non-bottom drainage direction not zero')
  call require(abs(sink_direction(4)-expected_sink) <= 2.0e-15_real64, 'bottom-lumped chain rule mismatch')

  call centered_fd_chain(dh, 1.0e-5_real64, fd)
  call require(abs(fd-sink_direction(4)) <= 2.0e-10_real64, 'whole-chain centered FD mismatch')

  bad = diagnostics
  bad%level(2)%derivative_defined = .false.
  call compose_fmr_qbot_drainage_sink_direction(p, state, dh, bad, sink_direction, dgwl, status, route)
  call require(status == FMR_QBOT_DRAIN_DIRECTION_TANGENT_UNAVAILABLE, 'missing level derivative not fail closed')

  bad = diagnostics
  bad%level(1)%branch_or_nonsmooth_point = .true.
  call compose_fmr_qbot_drainage_sink_direction(p, state, dh, bad, sink_direction, dgwl, status, route)
  call require(status == FMR_QBOT_DRAIN_DIRECTION_TANGENT_UNAVAILABLE, 'drainage kink not fail closed')

  write(*,'(A)') 'FGC31_QBOT_DGWL_CHAIN_ANALYTIC=PASS'
  write(*,'(A)') 'FGC31_QBOT_DRAINAGE_CHAIN_CENTERED_FD=PASS'
  write(*,'(A)') 'FGC31_QBOT_DRAINAGE_BOTTOM_LUMPING=PASS'
  write(*,'(A)') 'FGC31_QBOT_DRAINAGE_TANGENT_FAIL_CLOSED=PASS'

contains

  subroutine initialize_case()
    p%active_nodes = 4
    allocate(p%z(4), p%dz(4), p%node_distance(4))
    p%z = [-0.25_real64,-0.75_real64,-1.50_real64,-2.50_real64]
    p%dz = [0.50_real64,0.50_real64,1.00_real64,1.00_real64]
    p%node_distance = 1.0_real64

    state%active_nodes = 4
    allocate(state%pressure_head(4), state%water_content(4))
    state%pressure_head = [-2.2_real64,-1.2_real64,-0.2_real64,0.8_real64]
    state%water_content = 0.30_real64
    state%ponding_depth = 0.0_real64
    state%groundwater_level = -0.3_real64

    allocate(levels(2), controls(2))
    levels(1)%variant = FMR_DRAIN_VARIANT_TABULATED
    allocate(levels(1)%tabulated%groundwater_depth(2), levels(1)%tabulated%signed_exchange_rate(2))
    levels(1)%tabulated%groundwater_depth = [0.5_real64,2.5_real64]
    levels(1)%tabulated%signed_exchange_rate = [4.0e-3_real64,1.0e-3_real64]

    levels(2)%variant = FMR_DRAIN_VARIANT_TABULATED
    allocate(levels(2)%tabulated%groundwater_depth(2), levels(2)%tabulated%signed_exchange_rate(2))
    levels(2)%tabulated%groundwater_depth = [0.5_real64,2.5_real64]
    levels(2)%tabulated%signed_exchange_rate = [2.0e-3_real64,-1.0e-3_real64]
  end subroutine initialize_case

  subroutine evaluate_nominal(d, q)
    type(fmr_drainage_response_diagnostics_t), intent(out) :: d
    real(real64), allocatable, intent(out) :: q(:,:)
    type(process_hydraulic_view_t) :: view
    type(b110_smooth_freatic_projection_diagnostics_t) :: proj
    real(real64) :: zero(4), gwl, ignored
    zero = 0.0_real64
    call evaluate_b110_smooth_freatic_projection(2,.false.,p%z,p%node_distance,state%pressure_head,zero,gwl,ignored,proj)
    call require(proj%status == B110_GWL_PROJECTION_OK, 'nominal projection failed')
    view%active_nodes = 4
    allocate(view%pressure_head(4),view%water_content(4))
    view%pressure_head = state%pressure_head
    view%water_content = state%water_content
    view%ponding_depth = state%ponding_depth
    view%groundwater_level = gwl
    allocate(q(2,4))
    call evaluate_fmr_drainage_response_bottom_lumped(levels,controls,view,q,d)
    call require(d%status == FMR_DRAIN_BIND_OK .and. d%evaluated, 'nominal drainage response failed')
    call require(all(d%level%derivative_defined), 'nominal level derivatives unavailable')
  end subroutine evaluate_nominal

  subroutine centered_fd_chain(direction, eps, derivative)
    real(real64), intent(in) :: direction(4), eps
    real(real64), intent(out) :: derivative
    real(real64) :: qp, qm
    call perturbed_bottom_drainage(+eps,direction,qp)
    call perturbed_bottom_drainage(-eps,direction,qm)
    derivative = (qp-qm)/(2.0_real64*eps)
  end subroutine centered_fd_chain

  subroutine perturbed_bottom_drainage(alpha, direction, rate)
    real(real64), intent(in) :: alpha, direction(4)
    real(real64), intent(out) :: rate
    type(process_hydraulic_view_t) :: view
    type(b110_smooth_freatic_projection_diagnostics_t) :: proj
    type(fmr_drainage_response_diagnostics_t) :: d
    real(real64), allocatable :: q(:,:)
    real(real64) :: heads(4), zero(4), gwl, ignored
    heads = state%pressure_head + alpha*direction
    zero = 0.0_real64
    call evaluate_b110_smooth_freatic_projection(2,.false.,p%z,p%node_distance,heads,zero,gwl,ignored,proj)
    call require(proj%status == B110_GWL_PROJECTION_OK, 'FD projection left smooth branch')
    view%active_nodes = 4
    allocate(view%pressure_head(4),view%water_content(4))
    view%pressure_head = heads
    view%water_content = state%water_content
    view%ponding_depth = 0.0_real64
    view%groundwater_level = gwl
    allocate(q(2,4))
    call evaluate_fmr_drainage_response_bottom_lumped(levels,controls,view,q,d)
    call require(d%status == FMR_DRAIN_BIND_OK, 'FD drainage evaluation failed')
    rate = sum(q(:,4))
  end subroutine perturbed_bottom_drainage

  subroutine require(condition,label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'FGC31_QBOT_DRAINAGE_CHAIN_FAIL',trim(label)
      error stop 31
    end if
  end subroutine require
end program test_fgc31_qbot_drainage_direction_chain

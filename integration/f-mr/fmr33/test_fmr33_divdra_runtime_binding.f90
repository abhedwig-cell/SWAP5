program test_fmr33_divdra_runtime_binding
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_drainage_spatial_distribution, only: drainage_distribution_parameters_t, drainage_node_transfer_t, &
       drainage_distribution_diagnostics_t, distribute_single_level_positive_divdra, DRAIN_DIST_OK, &
       DRAIN_DIST_TRANSFER_BELOW_ADMITTED_MAGNITUDE
  use mod_fmr_divdra_runtime_binding, only: fmr_divdra_binding_diagnostics_t, &
       fmr_bind_single_level_positive_divdra, FMR_DIVDRA_BIND_OK, &
       FMR_DIVDRA_BIND_TARGET_ALREADY_BOUND, FMR_DIVDRA_BIND_PROCESS_REJECTED
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  implicit none

  integer, parameter :: n = 4
  type(drainage_distribution_parameters_t) :: parameters
  type(process_hydraulic_view_t) :: view_a, view_b
  type(drainage_node_transfer_t) :: direct_a, direct_b
  type(drainage_distribution_diagnostics_t) :: direct_diag_a, direct_diag_b
  type(fmr_divdra_binding_diagnostics_t) :: bind_diag_a, bind_diag_b, bind_diag_zero, bind_diag_fail, bind_diag_guard
  type(b110_source_sink_provider_t) :: provider
  real(real64), allocatable, target :: runtime_a(:,:), runtime_b(:,:), runtime_zero(:,:), runtime_fail(:,:), runtime_guard(:,:)
  real(real64), target :: qssdi(n), root_sink(n)
  real(real64) :: source(n), sink(n)
  real(real64), parameter :: scalar = 0.75_real64
  integer :: failures

  failures = 0
  call initialize_parameters(parameters)
  call initialize_view(view_a, -15.0_real64)
  call initialize_view(view_b, -45.0_real64)

  call distribute_single_level_positive_divdra(parameters, view_a, scalar, direct_a, direct_diag_a)
  call check(direct_diag_a%status == DRAIN_DIST_OK, 'direct process view A admitted', failures)
  call fmr_bind_single_level_positive_divdra(parameters, view_a, scalar, runtime_a, bind_diag_a)
  call check(bind_diag_a%status == FMR_DIVDRA_BIND_OK, 'runtime view A admitted', failures)
  call check(bind_diag_a%published, 'runtime view A published', failures)
  call check(allocated(runtime_a), 'runtime view A allocated', failures)
  if (allocated(runtime_a)) then
    call check(size(runtime_a,1) == 1 .and. size(runtime_a,2) == n, 'runtime shape 1 x n', failures)
    call check(all(runtime_a(1,:) == direct_a%soil_to_drain_rate), 'runtime row equals direct process row', failures)
  end if
  call check(bind_diag_a%authoritative_scalar_transfer == scalar, 'scalar authority propagated', failures)
  call check(bind_diag_a%process%scalar_transfer_is_authoritative, 'process scalar authority preserved', failures)

  qssdi = 0.0_real64
  root_sink = 0.0_real64
  call bind_b110_source_sink_provider(provider, runtime_a, qssdi, root_sink)
  call provider%evaluate(view_a%pressure_head, view_a%water_content, source, sink)
  call check(all(source == 0.0_real64), 'source provider unchanged', failures)
  call check(all(sink == runtime_a(1,:)), 'source sink provider consumes runtime row unchanged', failures)

  call fmr_bind_single_level_positive_divdra(parameters, view_a, 0.0_real64, runtime_zero, bind_diag_zero)
  call check(bind_diag_zero%status == FMR_DIVDRA_BIND_OK, 'zero scalar admitted', failures)
  call check(bind_diag_zero%process%zero_transfer, 'zero scalar process diagnostic preserved', failures)
  call check(allocated(runtime_zero), 'zero scalar row published', failures)
  if (allocated(runtime_zero)) call check(all(runtime_zero == 0.0_real64), 'zero scalar row is zero', failures)

  call fmr_bind_single_level_positive_divdra(parameters, view_a, 1.0e-11_real64, runtime_fail, bind_diag_fail)
  call check(bind_diag_fail%status == FMR_DIVDRA_BIND_PROCESS_REJECTED, 'restricted small transfer rejected', failures)
  call check(bind_diag_fail%process_status == DRAIN_DIST_TRANSFER_BELOW_ADMITTED_MAGNITUDE, &
       'process rejection status propagated', failures)
  call check(.not. allocated(runtime_fail), 'process rejection publishes nothing', failures)

  allocate(runtime_guard(1,n))
  runtime_guard = 123.5_real64
  call fmr_bind_single_level_positive_divdra(parameters, view_a, scalar, runtime_guard, bind_diag_guard)
  call check(bind_diag_guard%status == FMR_DIVDRA_BIND_TARGET_ALREADY_BOUND, 'prebound target rejected', failures)
  call check(all(runtime_guard == 123.5_real64), 'prebound target not overwritten', failures)

  call distribute_single_level_positive_divdra(parameters, view_b, scalar, direct_b, direct_diag_b)
  call check(direct_diag_b%status == DRAIN_DIST_OK, 'direct process view B admitted', failures)
  call fmr_bind_single_level_positive_divdra(parameters, view_b, scalar, runtime_b, bind_diag_b)
  call check(bind_diag_b%status == FMR_DIVDRA_BIND_OK, 'runtime view B admitted', failures)
  call check(all(runtime_b(1,:) == direct_b%soil_to_drain_rate), 'runtime view B equals its explicit process result', failures)
  call check(any(runtime_a(1,:) /= runtime_b(1,:)), 'different explicit hydraulic views remain distinguishable', failures)
  call check(bind_diag_a%process%groundwater_depth /= bind_diag_b%process%groundwater_depth, &
       'hydraulic view provenance reaches process', failures)

  if (failures /= 0) then
    write(*,'(A,I0)') 'F-MR33 FAILURES=', failures
    error stop 1
  end if

  write(*,'(A)') 'F-MR33 PASS'
  write(*,'(A,I0)') 'ACTIVE_NODES=', n
  write(*,'(A,I0)') 'DRAINAGE_LEVELS=', size(runtime_a,1)
  write(*,'(A,ES24.16)') 'SCALAR=', scalar
  write(*,'(A,4(ES24.16,1X))') 'VIEW_A_ROW=', runtime_a(1,:)
  write(*,'(A,4(ES24.16,1X))') 'VIEW_B_ROW=', runtime_b(1,:)
  write(*,'(A,I0)') 'VIEW_A_WT_NODE=', bind_diag_a%process%water_table_node
  write(*,'(A,I0)') 'VIEW_B_WT_NODE=', bind_diag_b%process%water_table_node
  write(*,'(A,ES24.16)') 'VIEW_A_CLOSURE=', bind_diag_a%process%closure_correction
  write(*,'(A,ES24.16)') 'VIEW_B_CLOSURE=', bind_diag_b%process%closure_correction
  write(*,'(A)') 'NO_COMMITTED_STATE_LOOKUP=TRUE'
  write(*,'(A)') 'NO_SCIENTIFIC_RENORMALIZATION=TRUE'

contains

  subroutine initialize_parameters(p)
    type(drainage_distribution_parameters_t), intent(out) :: p

    p%active_nodes = n
    allocate(p%dz(n), p%zbotcp(n), p%saturated_conductivity(n), p%horizontal_anisotropy_factor(n))
    p%dz = [10.0_real64, 20.0_real64, 30.0_real64, 40.0_real64]
    p%zbotcp = [-10.0_real64, -30.0_real64, -60.0_real64, -100.0_real64]
    p%saturated_conductivity = [1.0_real64, 2.0_real64, 3.0_real64, 4.0_real64]
    p%horizontal_anisotropy_factor = [1.0_real64, 2.0_real64, 0.5_real64, 1.5_real64]
    p%drain_spacing = 80.0_real64
  end subroutine initialize_parameters

  subroutine initialize_view(view, groundwater_level)
    type(process_hydraulic_view_t), intent(out) :: view
    real(real64), intent(in) :: groundwater_level

    view%active_nodes = n
    allocate(view%pressure_head(n), view%water_content(n))
    view%pressure_head = [-10.0_real64, -20.0_real64, -30.0_real64, -40.0_real64]
    view%water_content = [0.20_real64, 0.21_real64, 0.22_real64, 0.23_real64]
    view%groundwater_level = groundwater_level
  end subroutine initialize_view

  subroutine check(condition, label, failures)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    integer, intent(inout) :: failures

    if (.not. condition) then
      failures = failures + 1
      write(*,'(A,A)') 'CHECK_FAIL: ', trim(label)
    end if
  end subroutine check

end program test_fmr33_divdra_runtime_binding

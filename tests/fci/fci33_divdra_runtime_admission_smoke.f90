program fci33_divdra_runtime_admission_smoke
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_drainage_spatial_distribution, only: drainage_distribution_parameters_t, drainage_node_transfer_t, &
       drainage_distribution_diagnostics_t, distribute_single_level_positive_divdra, DRAIN_DIST_OK, &
       DRAIN_DIST_TRANSFER_BELOW_ADMITTED_MAGNITUDE
  use mod_fmr_divdra_runtime_binding, only: fmr_divdra_binding_diagnostics_t, &
       fmr_bind_single_level_positive_divdra, FMR_DIVDRA_BIND_OK, FMR_DIVDRA_BIND_TARGET_ALREADY_BOUND, &
       FMR_DIVDRA_BIND_PROCESS_REJECTED
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  implicit none

  integer, parameter :: n = 5
  type(drainage_distribution_parameters_t) :: p
  type(process_hydraulic_view_t) :: h
  type(drainage_node_transfer_t) :: direct
  type(drainage_distribution_diagnostics_t) :: direct_diag
  type(fmr_divdra_binding_diagnostics_t) :: bind_diag
  type(b110_source_sink_provider_t) :: consumer
  real(real64), allocatable, target :: drainage(:,:)
  real(real64), target :: irrigation(n), root_sink(n)
  real(real64) :: source(n), sink(n)
  real(real64), parameter :: scalar = 0.75_real64
  real(real64), parameter :: sentinel = 99.0_real64
  real(real64) :: mass_bound

  p%active_nodes = n
  allocate(p%dz(n), p%zbotcp(n), p%saturated_conductivity(n), p%horizontal_anisotropy_factor(n))
  p%dz = [10.0_real64, 15.0_real64, 20.0_real64, 25.0_real64, 30.0_real64]
  p%zbotcp = [-10.0_real64, -25.0_real64, -45.0_real64, -70.0_real64, -100.0_real64]
  p%saturated_conductivity = [1.0_real64, 2.0_real64, 3.0_real64, 4.0_real64, 5.0_real64]
  p%horizontal_anisotropy_factor = [1.0_real64, 1.25_real64, 0.75_real64, 2.0_real64, 1.5_real64]
  p%drain_spacing = 80.0_real64

  h%active_nodes = n
  allocate(h%pressure_head(n), h%water_content(n))
  h%pressure_head = [-5.0_real64, -10.0_real64, -20.0_real64, -30.0_real64, -40.0_real64]
  h%water_content = [0.30_real64, 0.31_real64, 0.32_real64, 0.33_real64, 0.34_real64]
  h%groundwater_level = -30.0_real64

  call distribute_single_level_positive_divdra(p, h, scalar, direct, direct_diag)
  call require(direct_diag%status == DRAIN_DIST_OK, 'direct provider accepted valid case')

  call fmr_bind_single_level_positive_divdra(p, h, scalar, drainage, bind_diag)
  call require(bind_diag%status == FMR_DIVDRA_BIND_OK, 'binding accepted valid case')
  call require(bind_diag%published, 'binding published valid case')
  call require(allocated(drainage), 'binding allocated publication target')
  call require(size(drainage,1) == 1 .and. size(drainage,2) == n, 'binding publication shape')
  call require(all(drainage(1,:) == direct%soil_to_drain_rate), 'binding exact provider row copy')
  call require(bind_diag%authoritative_scalar_transfer == scalar, 'authoritative scalar preserved')
  mass_bound = 64.0_real64 * epsilon(1.0_real64) * max(1.0_real64, abs(scalar))
  call require(abs(sum(drainage(1,:)) - scalar) <= mass_bound, 'published row conserves scalar to binary64 roundoff')

  irrigation = 0.0_real64
  root_sink = 0.0_real64
  call bind_b110_source_sink_provider(consumer, drainage, irrigation, root_sink)
  call consumer%evaluate(h%pressure_head, h%water_content, source, sink)
  call require(all(source == 0.0_real64), 'consumer source remains zero')
  call require(all(sink == drainage(1,:)), 'consumer sees exact admitted drainage row')

  deallocate(drainage)
  call fmr_bind_single_level_positive_divdra(p, h, 0.0_real64, drainage, bind_diag)
  call require(bind_diag%status == FMR_DIVDRA_BIND_OK .and. bind_diag%published, 'zero transfer publishes explicit zero row')
  call require(allocated(drainage) .and. all(drainage == 0.0_real64), 'zero transfer row is zero')

  deallocate(drainage)
  call fmr_bind_single_level_positive_divdra(p, h, 1.0e-10_real64, drainage, bind_diag)
  call require(bind_diag%status == FMR_DIVDRA_BIND_PROCESS_REJECTED, 'below admitted magnitude fails closed')
  call require(bind_diag%process_status == DRAIN_DIST_TRANSFER_BELOW_ADMITTED_MAGNITUDE, 'provider rejection propagated')
  call require(.not. allocated(drainage), 'rejected transfer publishes no target')

  allocate(drainage(1,n))
  drainage = sentinel
  call fmr_bind_single_level_positive_divdra(p, h, scalar, drainage, bind_diag)
  call require(bind_diag%status == FMR_DIVDRA_BIND_TARGET_ALREADY_BOUND, 'preallocated target fails closed')
  call require(all(drainage == sentinel), 'preallocated target remains unchanged')

  print '(a)', 'FCI33_VALID_PUBLICATION=PASS'
  print '(a)', 'FCI33_SCALAR_MASS_PRESERVATION=PASS'
  print '(a)', 'FCI33_B110_CONSUMER_SEAM=PASS'
  print '(a)', 'FCI33_ZERO_PATH=PASS'
  print '(a)', 'FCI33_PROCESS_REJECTION=PASS'
  print '(a)', 'FCI33_OVERWRITE_GUARD=PASS'
  print '(a)', 'FCI33_DIVDRA_RUNTIME_ADMISSION_SMOKE=PASS'

contains

  subroutine require(ok, label)
    logical, intent(in) :: ok
    character(len=*), intent(in) :: label
    if (.not. ok) then
      write(*,'(a,1x,a)') 'FCI33_SMOKE_FAIL', trim(label)
      error stop 33
    end if
  end subroutine require

end program fci33_divdra_runtime_admission_smoke

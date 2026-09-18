program test_ppa_low02_time_application_admission
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_b110_legacy_swbotb2_application_control, only: b110_legacy_swbotb2_application_control_t, &
       B110_SWBOTB2_OK, B110_SWBOTB2_INVALID_CONTROL, B110_SWBOTB2_SINE, B110_SWBOTB2_TABLE, &
       B110_SWBOTB2_DRY_HEAD_CM
  use mod_fmr_runtime_core, only: FMR_BACKEND_SERIALIZED_REFERENCE, FMR_NUMERICAL_CONTINUATION_NONE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, &
       fmr_b110_physical_forcing_t, fmr_b110_physical_state_t
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t
  use mod_fmr_production_application_bootstrap, only: fmr_production_application_config_t, &
       fmr_production_application_bootstrap_t, FMR_APP_BOOT_OK, FMR_APP_BOOT_RUNTIME_FAILED
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  implicit none

  real(real64), parameter :: T0 = 5100.1875_real64
  real(real64), parameter :: T1 = 5100.6875_real64
  real(real64), parameter :: H_NORMAL = -75.0_real64
  real(real64), parameter :: H_DRY = -1.0000001e7_real64
  real(real64), parameter :: HARD_MASS_GATE = 1.0e-12_real64

  type(b110_legacy_swbotb2_application_control_t) :: sine, table, bad
  type(fmr_production_application_config_t) :: cfg_control, cfg_reference, cfg_dry_control, cfg_dry_reference
  type(fmr_production_application_config_t) :: cfg_bad_owner
  type(fmr_production_application_bootstrap_t) :: app_control, app_reference
  type(fmr_production_application_bootstrap_t) :: app_dry_control, app_dry_reference, app_bad_owner
  type(fmr_serialized_column_result_t), allocatable :: controlled(:), reference(:), dry_controlled(:), dry_reference(:)
  type(fmr_serialized_column_result_t), allocatable :: bad_results(:)
  real(real64) :: years(3), tx(3), qx(3), flux, expected, conductivity_normal, conductivity_dry
  real(real64) :: controlled_q
  integer :: status, mode

  call qualify_pure_source_laws()

  ! End-to-end table control: deliberately make the stored static bottom_flux
  ! different from the legacy time-law value. The controlled application must
  ! remain exactly identical to a separately bootstrapped direct mode-2
  ! application whose static forcing is the expected time-law value.
  call initialize_application_config(cfg_control, H_NORMAL, conductivity_normal)
  controlled_q = -conductivity_normal
  cfg_control%tiles(1)%parameters%bottom_mode = 2
  cfg_control%tiles(1)%base_forcing%bottom_flux = controlled_q + 0.01_real64
  allocate(cfg_control%tiles(1)%base_forcing%legacy_swbotb2_control)
  tx = [1000.0_real64, 1001.0_real64, 1002.0_real64]
  qx = [controlled_q, controlled_q, controlled_q]
  call cfg_control%tiles(1)%base_forcing%legacy_swbotb2_control%initialize_table( &
       T0, 1000.0_real64, tx, qx, status)
  call require(status == B110_SWBOTB2_OK, 'table control construction for production run')

  call initialize_application_config(cfg_reference, H_NORMAL, conductivity_normal)
  cfg_reference%tiles(1)%parameters%bottom_mode = 2
  cfg_reference%tiles(1)%base_forcing%bottom_flux = controlled_q

  call app_control%initialize(cfg_control, status)
  call require(status == FMR_APP_BOOT_OK, 'controlled table bootstrap initialize')
  call app_reference%initialize(cfg_reference, status)
  call require(status == FMR_APP_BOOT_OK, 'direct qbot bootstrap initialize')
  call app_control%run_standalone(T0, T1, controlled, status)
  call require(status == FMR_APP_BOOT_OK, 'controlled table production run')
  call app_reference%run_standalone(T0, T1, reference, status)
  call require(status == FMR_APP_BOOT_OK, 'direct qbot production run')
  call require(results_identical(controlled(1), reference(1)), 'table control equals direct admitted qbot route')
  call require(abs(controlled(1)%mass%residual) <= HARD_MASS_GATE, 'table control hard mass')
  call app_control%close(status)
  call require(status == FMR_APP_BOOT_OK, 'controlled table close')
  call app_reference%close(status)
  call require(status == FMR_APP_BOOT_OK, 'direct qbot close')

  ! End-to-end sine control with zero amplitude gives a constant oracle while
  ! still exercising the SW2=1 substep-start calendar route in production.
  call initialize_application_config(cfg_control, H_NORMAL, conductivity_normal)
  controlled_q = -conductivity_normal
  cfg_control%tiles(1)%parameters%bottom_mode = 2
  cfg_control%tiles(1)%base_forcing%bottom_flux = controlled_q + 0.02_real64
  allocate(cfg_control%tiles(1)%base_forcing%legacy_swbotb2_control)
  years = [2000.0_real64, 2365.0_real64, 2731.0_real64]
  call cfg_control%tiles(1)%base_forcing%legacy_swbotb2_control%initialize_sine( &
       T0, 2090.0_real64, years, controlled_q, 0.0_real64, 90.0_real64, status)
  call require(status == B110_SWBOTB2_OK, 'sine control construction for production run')
  call initialize_application_config(cfg_reference, H_NORMAL, conductivity_normal)
  cfg_reference%tiles(1)%parameters%bottom_mode = 2
  cfg_reference%tiles(1)%base_forcing%bottom_flux = controlled_q
  call app_control%initialize(cfg_control, status)
  call require(status == FMR_APP_BOOT_OK, 'controlled sine bootstrap initialize')
  call app_reference%initialize(cfg_reference, status)
  call require(status == FMR_APP_BOOT_OK, 'sine direct qbot bootstrap initialize')
  call app_control%run_standalone(T0, T1, controlled, status)
  call require(status == FMR_APP_BOOT_OK, 'controlled sine production run')
  call app_reference%run_standalone(T0, T1, reference, status)
  call require(status == FMR_APP_BOOT_OK, 'sine direct qbot production run')
  call require(results_identical(controlled(1), reference(1)), 'sine control equals direct admitted qbot route')
  call require(abs(controlled(1)%mass%residual) <= HARD_MASS_GATE, 'sine control hard mass')
  call app_control%close(status)
  call require(status == FMR_APP_BOOT_OK, 'controlled sine close')
  call app_reference%close(status)
  call require(status == FMR_APP_BOOT_OK, 'sine direct qbot close')

  ! Dynamic dry continuation is compared against the already admitted mode-7
  ! free-drainage equation from the exact same very-dry physical state. F-SI13
  ! already establishes that internal -2 and mode 7 share this equation.
  call initialize_application_config(cfg_dry_control, H_DRY, conductivity_dry)
  cfg_dry_control%tiles(1)%parameters%bottom_mode = 2
  cfg_dry_control%tiles(1)%base_forcing%bottom_flux = 0.5_real64
  allocate(cfg_dry_control%tiles(1)%base_forcing%legacy_swbotb2_control)
  tx = [3000.0_real64, 3001.0_real64, 3002.0_real64]
  qx = [0.5_real64, 0.5_real64, 0.5_real64]
  call cfg_dry_control%tiles(1)%base_forcing%legacy_swbotb2_control%initialize_table( &
       T0, 3000.0_real64, tx, qx, status)
  call require(status == B110_SWBOTB2_OK, 'dry control construction')
  call initialize_application_config(cfg_dry_reference, H_DRY, conductivity_dry)
  cfg_dry_reference%tiles(1)%parameters%bottom_mode = 7

  call app_dry_control%initialize(cfg_dry_control, status)
  call require(status == FMR_APP_BOOT_OK, 'dry controlled bootstrap initialize')
  call app_dry_reference%initialize(cfg_dry_reference, status)
  call require(status == FMR_APP_BOOT_OK, 'free drainage bootstrap initialize')
  call app_dry_control%run_standalone(T0, T1, dry_controlled, status)
  call require(status == FMR_APP_BOOT_OK, 'dry continuation production run')
  call app_dry_reference%run_standalone(T0, T1, dry_reference, status)
  call require(status == FMR_APP_BOOT_OK, 'free drainage reference production run')
  call require(results_identical(dry_controlled(1), dry_reference(1)), 'dynamic -2 equals admitted free drainage equation')
  call require(abs(dry_controlled(1)%mass%residual) <= HARD_MASS_GATE, 'dry continuation hard mass')
  call app_dry_control%close(status)
  call require(status == FMR_APP_BOOT_OK, 'dry controlled close')
  call app_dry_reference%close(status)
  call require(status == FMR_APP_BOOT_OK, 'free drainage close')

  ! Attaching the legacy SWBOTB=2 control to a non-mode2 production profile
  ! must fail before any accepted application commit.
  call initialize_application_config(cfg_bad_owner, H_NORMAL, conductivity_normal)
  cfg_bad_owner%tiles(1)%parameters%bottom_mode = 7
  allocate(cfg_bad_owner%tiles(1)%base_forcing%legacy_swbotb2_control)
  tx = [4000.0_real64, 4001.0_real64, 4002.0_real64]
  qx = [0.0_real64, 0.0_real64, 0.0_real64]
  call cfg_bad_owner%tiles(1)%base_forcing%legacy_swbotb2_control%initialize_table( &
       T0, 4000.0_real64, tx, qx, status)
  call require(status == B110_SWBOTB2_OK, 'bad-owner control itself valid')
  call app_bad_owner%initialize(cfg_bad_owner, status)
  call require(status == FMR_APP_BOOT_OK, 'bad-owner app initializes existing mode7 profile')
  call app_bad_owner%run_standalone(T0, T1, bad_results, status)
  call require(status == FMR_APP_BOOT_RUNTIME_FAILED, 'non-mode2 attachment fails closed at runtime')
  call app_bad_owner%close(status)
  call require(status == FMR_APP_BOOT_OK, 'bad-owner close')

  print '(a)', 'PPA_LOW02_SOURCE_LAW_ORACLES=PASS'
  print '(a)', 'PPA_LOW02_SINE_CALENDAR_RESET=PASS'
  print '(a)', 'PPA_LOW02_TABLE_AFGEN_SEMANTICS=PASS'
  print '(a)', 'PPA_LOW02_STRICT_DRY_THRESHOLD_REENTRY=PASS'
  print '(a)', 'PPA_LOW02_TABLE_PRODUCTION_IDENTITY=PASS'
  print '(a)', 'PPA_LOW02_SINE_PRODUCTION_IDENTITY=PASS'
  print '(a)', 'PPA_LOW02_DRY_FREE_DRAINAGE_IDENTITY=PASS'
  print '(a)', 'PPA_LOW02_HARD_MASS=PASS'
  print '(a)', 'PPA_LOW02_NON_MODE2_ATTACHMENT_FAIL_CLOSED=PASS'
  print '(a)', 'PPA-LOW02-TIME OWNER QUALIFICATION PASS'

contains

  subroutine qualify_pure_source_laws()
    real(real64) :: local_years(3), local_tx(3), local_qx(3)
    integer :: local_status, local_mode
    real(real64) :: local_flux, local_expected, twopi, freq, year2_t0

    local_years = [1000.0_real64, 1365.0_real64, 1731.0_real64]
    call sine%initialize_sine(10.0_real64, 1090.0_real64, local_years, &
         1.25_real64, 0.75_real64, 90.0_real64, local_status)
    call require(local_status == B110_SWBOTB2_OK .and. sine%ready(), 'valid sine control')
    call sine%evaluate(10.0_real64, 10.25_real64, -100.0_real64, local_mode, local_flux, local_status)
    call require(local_status == B110_SWBOTB2_OK .and. local_mode == 2, 'sine normal selector')
    call require(same_bits(local_flux, 2.0_real64), 'sine maximum at SINMAX')

    twopi = 8.0_real64 * atan(1.0_real64)
    freq = twopi / 365.0_real64
    year2_t0 = 10.0_real64 + (1365.0_real64 - 1090.0_real64)
    call sine%evaluate(year2_t0, year2_t0 + 0.25_real64, -100.0_real64, local_mode, local_flux, local_status)
    local_expected = 1.25_real64 + 0.75_real64 * cos(freq * (0.0_real64 - 90.0_real64))
    call require(local_status == B110_SWBOTB2_OK .and. local_mode == 2, 'sine next-year selector')
    call require(same_bits(local_flux, local_expected), 'sine phase resets at next calendar year')

    call sine%evaluate(10.0_real64, 10.25_real64, B110_SWBOTB2_DRY_HEAD_CM, &
         local_mode, local_flux, local_status)
    call require(local_status == B110_SWBOTB2_OK .and. local_mode == 2, 'dry threshold is strict less-than')
    call sine%evaluate(10.0_real64, 10.25_real64, B110_SWBOTB2_DRY_HEAD_CM - 1.0_real64, &
         local_mode, local_flux, local_status)
    call require(local_status == B110_SWBOTB2_OK .and. local_mode == -2, 'dry continuation activates')
    call sine%evaluate(10.0_real64, 10.25_real64, -100.0_real64, local_mode, local_flux, local_status)
    call require(local_status == B110_SWBOTB2_OK .and. local_mode == 2, 'dry continuation re-enters mode2 without history')

    local_tx = [2000.0_real64, 2001.0_real64, 2002.0_real64]
    local_qx = [1.0_real64, 3.0_real64, -1.0_real64]
    call table%initialize_table(20.0_real64, 2000.0_real64, local_tx, local_qx, local_status)
    call require(local_status == B110_SWBOTB2_OK .and. table%ready(), 'valid table control')
    call table%evaluate(20.0_real64, 20.5_real64, -100.0_real64, local_mode, local_flux, local_status)
    call require(local_status == B110_SWBOTB2_OK .and. local_mode == 2, 'table normal selector')
    call require(same_bits(local_flux, 2.0_real64), 'AFGEN linear interpolation uses substep-end t1900')
    call table%evaluate(18.0_real64, 19.0_real64, -100.0_real64, local_mode, local_flux, local_status)
    call require(same_bits(local_flux, 1.0_real64), 'AFGEN lower endpoint clamp')
    call table%evaluate(22.0_real64, 23.0_real64, -100.0_real64, local_mode, local_flux, local_status)
    call require(same_bits(local_flux, -1.0_real64), 'AFGEN upper endpoint clamp')

    call bad%initialize_table(0.0_real64, 0.0_real64, &
         [0.0_real64, 0.0_real64], [0.0_real64, 1.0_real64], local_status)
    call require(local_status == B110_SWBOTB2_INVALID_CONTROL .and. .not. bad%ready(), 'duplicate table time rejected')
    call bad%initialize_sine(0.0_real64, 0.0_real64, [0.0_real64, 365.0_real64], &
         11.0_real64, 0.0_real64, 0.0_real64, local_status)
    call require(local_status == B110_SWBOTB2_INVALID_CONTROL, 'legacy sine parser bound preserved')
  end subroutine qualify_pure_source_laws

  subroutine initialize_application_config(value, initial_head, conductivity0)
    type(fmr_production_application_config_t), intent(out) :: value
    real(real64), intent(in) :: initial_head
    real(real64), intent(out) :: conductivity0

    value%initial_time = T0
    value%numerical%transaction%temporal_tolerance = 0.0_real64
    value%numerical%transaction%mass_tolerance = HARD_MASS_GATE
    value%numerical%transaction%retry_scale = 0.5_real64
    value%numerical%transaction%max_retries = 2
    value%numerical%max_committed_substeps = 8
    value%numerical%progress_tolerance = 0.0_real64

    allocate(value%tiles(1))
    value%tiles(1)%tile_id = 660101_int64
    value%tiles(1)%ledger_id = 760101_int64
    value%tiles(1)%template%template_id = 660201_int64
    value%tiles(1)%template%physics_topology_id = 660210_int64
    value%tiles(1)%template%vertical_layout_id = 660220_int64
    value%tiles(1)%template%state_layout_id = 660230_int64
    value%tiles(1)%template%solver_interface_id = 660240_int64
    value%tiles(1)%template%optional_state_layout_id = 0_int64
    value%tiles(1)%template%numerical_continuation_layout_id = FMR_NUMERICAL_CONTINUATION_NONE
    value%tiles(1)%template%compatible_backend_id = FMR_BACKEND_SERIALIZED_REFERENCE

    call initialize_parameters(value%tiles(1)%parameters, 670001_int64)
    call initialize_state_and_forcing(value%tiles(1)%parameters, value%tiles(1)%initial_state, &
         value%tiles(1)%base_forcing, initial_head, conductivity0)
  end subroutine initialize_application_config

  subroutine initialize_parameters(p, parameter_id)
    type(fmr_b110_physical_parameters_t), intent(out) :: p
    integer(int64), intent(in) :: parameter_id
    integer :: k

    p%parameter_set_id = parameter_id
    p%active_nodes = numnod
    allocate(p%z(numnod), p%dz(numnod), p%node_distance(numnod), p%cofgen(24, numnod))
    p%z = z
    p%dz = dz
    p%node_distance = disnod(1:numnod)
    p%cofgen = 0.0_real64
    do k = 1, numnod
      p%cofgen(1,k) = 0.032_real64
      p%cofgen(2,k) = 0.423_real64
      p%cofgen(3,k) = 4.75_real64
      p%cofgen(4,k) = 0.0135_real64
      p%cofgen(5,k) = 0.365_real64
      p%cofgen(6,k) = 1.455_real64
      p%cofgen(7,k) = 1.0_real64 - 1.0_real64 / p%cofgen(6,k)
      p%cofgen(8,k) = p%cofgen(4,k)
      p%cofgen(10,k) = p%cofgen(3,k)
      p%cofgen(11,k) = 0.999_real64
      p%cofgen(12,k) = 0.99_real64 * p%cofgen(3,k)
      p%cofgen(22,k) = -1.0e6_real64
      p%cofgen(23,k) = 1.0e-12_real64
    end do
    p%bottom_mode = 2
    p%swkimpl = 0
    p%swkmean = 1
    p%swsophy = 0
    p%max_iterations = 8
    p%max_backtracking = 4
    p%root_extraction_active = .false.
    p%macropore_active = .false.
    p%snow_active = .false.
    p%hysteresis_active = .false.
    p%tabulated_hydraulics_active = .false.
    p%elasticity_active = .false.
    p%frost_active = .false.
    p%soil_temperature_active = .false.
    p%drainage_response_active = .false.
  end subroutine initialize_parameters

  subroutine initialize_state_and_forcing(p, state, forcing, initial_head, conductivity0)
    type(fmr_b110_physical_parameters_t), intent(in) :: p
    type(fmr_b110_physical_state_t), intent(out) :: state
    type(fmr_b110_physical_forcing_t), intent(out) :: forcing
    real(real64), intent(in) :: initial_head
    real(real64), intent(out) :: conductivity0

    type(b110_default_mvg_parameters_t), target :: hp
    type(b110_default_mvg_provider_t) :: provider
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)

    heads = initial_head
    call initialize_b110_default_mvg_parameters(hp, p%cofgen)
    call bind_b110_default_mvg_provider(provider, hp, T1 - T0)
    call provider%evaluate(heads, water, conductivity, capacity, dkdh)
    conductivity0 = conductivity(1)

    state%active_nodes = numnod
    allocate(state%pressure_head(numnod), state%water_content(numnod))
    state%pressure_head = heads
    state%water_content = water
    state%ponding_depth = 0.0_real64
    state%groundwater_level = -2.0_real64

    forcing%top_flux = -conductivity0
    forcing%top_head = initial_head
    forcing%bottom_flux = -conductivity0
    forcing%bottom_head = -100.0_real64
    allocate(forcing%drainage_flux_by_level(1,numnod), forcing%subsurface_irrigation_source(numnod), &
         forcing%root_extraction_sink(numnod))
    forcing%drainage_flux_by_level = 0.0_real64
    forcing%subsurface_irrigation_source = 0.0_real64
    forcing%root_extraction_sink = 0.0_real64
  end subroutine initialize_state_and_forcing

  logical function results_identical(a, b) result(same)
    type(fmr_serialized_column_result_t), intent(in) :: a, b

    same = a%admitted .eqv. b%admitted
    same = same .and. (a%completed .eqv. b%completed) .and. (a%committed .eqv. b%committed)
    same = same .and. a%kernel_status == b%kernel_status .and. a%commit_status == b%commit_status
    same = same .and. a%accepted_substeps == b%accepted_substeps
    same = same .and. a%solver_nonlinear_iterations == b%solver_nonlinear_iterations
    same = same .and. a%solver_internal_retries == b%solver_internal_retries
    same = same .and. same_bits(a%mass%storage_start, b%mass%storage_start)
    same = same .and. same_bits(a%mass%storage_end, b%mass%storage_end)
    same = same .and. same_bits(a%mass%storage_change, b%mass%storage_change)
    same = same .and. same_bits(a%mass%total_in, b%mass%total_in)
    same = same .and. same_bits(a%mass%total_out, b%mass%total_out)
    same = same .and. same_bits(a%mass%residual, b%mass%residual)
  end function results_identical

  logical function same_bits(a, b) result(same)
    real(real64), intent(in) :: a, b
    integer(int64) :: ia, ib
    ia = transfer(a, ia)
    ib = transfer(b, ib)
    same = ia == ib
  end function same_bits

  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not. condition) then
      write(*,'(a,1x,a)') 'PPA_LOW02_FAIL', trim(message)
      error stop 1
    end if
  end subroutine require

end program test_ppa_low02_time_application_admission

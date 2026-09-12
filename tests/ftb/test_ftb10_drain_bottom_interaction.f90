program test_ftb10_drain_bottom_interaction
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use MOD_swap_base, only: swmacro
  use MOD_snow, only: legacy_melt => melt
  use MOD_drain, only: legacy_qdra => qdra
  use MOD_irrigation, only: legacy_qssdi => qssdi
  use variables, only: legacy_qrot => qrot
  use mod_transaction_reference, only: transaction_state_t, TX_MASS_MISSING_NONE
  use mod_canonical_contracts, only: canonical_numerical_config_t, canonical_mass_accounting_t
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, fmr_column_diagnostics_t, &
       fmr_aggregate_diagnostics_t, FMR_BACKEND_SERIALIZED_REFERENCE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, fmr_b110_physical_parameters_t, &
       fmr_b110_physical_forcing_t, fmr_new_b110_committed_state
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t, FMR_SERIAL_DISPATCH_OK
  use mod_fmr_divdra_serialized_runtime, only: fmr_divdra_serialized_column_request_t, &
       fmr_divdra_serialized_binding_record_t, fmr_run_serialized_physical_multiswap_with_divdra
  use mod_fmr_divdra_serialized_composition, only: FMR_DIVDRA_COMPOSE_OK
  use mod_drainage_spatial_distribution, only: drainage_distribution_parameters_t
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_fmr04_fixed_top_provider, only: fmr04_fixed_flux_top_provider_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  implicit none

  real(real64), parameter :: t0 = 7312.0625_real64
  real(real64), parameter :: tm = 7312.1875_real64
  real(real64), parameter :: t1 = 7312.3125_real64
  real(real64), parameter :: initial_head = -123.0_real64
  real(real64), parameter :: bottom_head_first = -123.0_real64
  real(real64), parameter :: bottom_head_second = -120.0_real64
  real(real64), parameter :: mass_gate = 1.0e-12_real64
  real(real64), parameter :: drainage_transfer = 2.0e-4_real64
  real(real64), parameter :: gwl_first = -0.35_real64
  real(real64), parameter :: gwl_second = -1.55_real64
  integer(int64), parameter :: column_id = 1003001_int64

  call verify_changing_bottom_boundary_with_active_divdra()
  write(*,'(A)') 'FTB10_TB09_DRAIN_BOTTOM_INTERACTION PASS'

contains

  subroutine verify_changing_bottom_boundary_with_active_divdra()
    type(fmr_logical_column_t) :: columns(1)
    type(fmr_template_t) :: templates(1)
    type(fmr_b110_physical_parameters_t) :: parameters(1)
    type(fmr_b110_physical_forcing_t) :: forcings(1)
    type(kernel_committed_state_t) :: states(1)
    type(canonical_numerical_config_t) :: config
    type(fmr_serialized_column_result_t), allocatable :: results(:)
    type(fmr_column_diagnostics_t), allocatable :: diagnostics(:)
    type(fmr_aggregate_diagnostics_t) :: aggregate
    type(fmr_divdra_serialized_column_request_t) :: request(1)
    type(fmr_divdra_serialized_binding_record_t), allocatable :: records(:)
    type(drainage_distribution_parameters_t) :: distribution(1)
    type(process_hydraulic_view_t) :: view(1)
    type(fmr04_fixed_flux_top_provider_t), target :: top
    type(canonical_mass_accounting_t) :: mass_first, mass_second
    real(real64) :: storage0, storage1, storage2
    real(real64) :: qbot_first, qbot_second, combined_residual, dt1, dt2
    integer :: dispatch_status, composition_status, wt_first, wt_second

    call initialize_runtime(columns, templates, parameters, forcings, states, config)
    call configure_distribution(distribution(1))
    call configure_view(view(1), gwl_first)
    call make_request(request(1), drainage_transfer)

    storage0 = soil_storage(states(1))
    call require(same_bits(forcings(1)%bottom_head, bottom_head_first), 'first prescribed bottom head configured')
    call reset_legacy()
    call fmr_run_serialized_physical_multiswap_with_divdra(columns, templates, parameters, forcings, states, config, &
         top, t0, tm, 1, request, distribution, view, results, diagnostics, aggregate, dispatch_status, &
         composition_status, records)

    call require(dispatch_status == FMR_SERIAL_DISPATCH_OK, 'first interval dispatch')
    call require(composition_status == FMR_DIVDRA_COMPOSE_OK, 'first interval composition')
    call require(size(results) == 1 .and. results(1)%committed .and. results(1)%completed, 'first interval committed')
    call require(size(records) == 1 .and. records(1)%binding%published, 'first interval drainage published')
    call require(same_bits(records(1)%binding%authoritative_scalar_transfer, drainage_transfer), 'first drainage scalar')
    call require(results(1)%mass%complete, 'first mass complete')
    call require(results(1)%mass%missing_contribution_mask == TX_MASS_MISSING_NONE, 'first mass mask complete')
    call require(abs(results(1)%mass%residual) <= mass_gate, 'first hard mass gate')
    call require(.not. allocated(forcings(1)%drainage_flux_by_level), 'first transient drainage forcing cleaned')
    storage1 = soil_storage(states(1))
    mass_first = results(1)%mass
    wt_first = records(1)%binding%process%water_table_node
    dt1 = tm-t0
    qbot_first = ((mass_first%total_in-mass_first%total_out)/dt1) + forcings(1)%top_flux + drainage_transfer

    forcings(1)%bottom_head = bottom_head_second
    call configure_view(view(1), gwl_second)
    call require(.not. same_bits(bottom_head_first, forcings(1)%bottom_head), 'prescribed bottom head changed')

    call reset_legacy()
    call fmr_run_serialized_physical_multiswap_with_divdra(columns, templates, parameters, forcings, states, config, &
         top, tm, t1, 1, request, distribution, view, results, diagnostics, aggregate, dispatch_status, &
         composition_status, records)

    call require(dispatch_status == FMR_SERIAL_DISPATCH_OK, 'second interval dispatch')
    call require(composition_status == FMR_DIVDRA_COMPOSE_OK, 'second interval composition')
    call require(size(results) == 1 .and. results(1)%committed .and. results(1)%completed, 'second interval committed')
    call require(size(records) == 1 .and. records(1)%binding%published, 'second interval drainage published')
    call require(same_bits(records(1)%binding%authoritative_scalar_transfer, drainage_transfer), 'second drainage scalar')
    call require(results(1)%mass%complete, 'second mass complete')
    call require(results(1)%mass%missing_contribution_mask == TX_MASS_MISSING_NONE, 'second mass mask complete')
    call require(abs(results(1)%mass%residual) <= mass_gate, 'second hard mass gate')
    call require(.not. allocated(forcings(1)%drainage_flux_by_level), 'second transient drainage forcing cleaned')
    storage2 = soil_storage(states(1))
    mass_second = results(1)%mass
    wt_second = records(1)%binding%process%water_table_node
    dt2 = t1-tm
    qbot_second = ((mass_second%total_in-mass_second%total_out)/dt2) + forcings(1)%top_flux + drainage_transfer

    call require(wt_first /= wt_second, 'explicit groundwater view crossed drainage distribution node')
    call require(abs(qbot_second-qbot_first) > 1.0e-12_real64, 'prescribed-head change altered signed bottom flux')
    call require(same_bits(mass_first%storage_end, mass_second%storage_start), 'committed interval storage continuity')
    call require(abs(mass_first%storage_start-storage0) <= mass_gate, 'first ledger origin storage')
    call require(abs(mass_first%storage_end-storage1) <= mass_gate, 'first ledger endpoint storage')
    call require(abs(mass_second%storage_end-storage2) <= mass_gate, 'second ledger endpoint storage')

    combined_residual = (storage2-storage0) - &
         ((mass_first%total_in+mass_second%total_in) - (mass_first%total_out+mass_second%total_out))
    call require(abs(combined_residual) <= mass_gate, 'full-window hard mass closure')

    write(*,'(A)') 'FTB10_TB09_003_ACTIVE_DIVDRA=PASS'
    write(*,'(A)') 'FTB10_TB09_003_BOTTOM_HEAD_CHANGE=PASS'
    write(*,'(A)') 'FTB10_TB09_003_BOTTOM_FLUX_RESPONSE=PASS'
    write(*,'(A)') 'FTB10_TB09_003_GROUNDWATER_VIEW_CHANGE=PASS'
    write(*,'(A)') 'FTB10_TB09_003_INTERVAL1_HARD_MASS=PASS'
    write(*,'(A)') 'FTB10_TB09_003_INTERVAL2_HARD_MASS=PASS'
    write(*,'(A)') 'FTB10_TB09_003_FULL_WINDOW_HARD_MASS=PASS'
    write(*,'(A,I0,A,I0)') 'FTB10_TB09_003_WATER_TABLE_NODES=', wt_first, ':', wt_second
    write(*,'(A,ES24.16,A,ES24.16)') 'FTB10_TB09_003_BOTTOM_HEADS=', bottom_head_first, ':', bottom_head_second
    write(*,'(A,ES24.16,A,ES24.16)') 'FTB10_TB09_003_DERIVED_SIGNED_QBOT=', qbot_first, ':', qbot_second
    write(*,'(A,ES24.16)') 'FTB10_TB09_003_COMBINED_RESIDUAL=', combined_residual
  end subroutine verify_changing_bottom_boundary_with_active_divdra

  subroutine initialize_runtime(c,t,p,f,s,cfg)
    type(fmr_logical_column_t), intent(out) :: c(1)
    type(fmr_template_t), intent(out) :: t(1)
    type(fmr_b110_physical_parameters_t), intent(out) :: p(1)
    type(fmr_b110_physical_forcing_t), intent(out) :: f(1)
    type(kernel_committed_state_t), intent(out) :: s(1)
    type(canonical_numerical_config_t), intent(out) :: cfg
    type(fmr_b110_physical_state_t) :: state
    real(real64) :: k0
    logical :: ok

    call configure_parameters(p(1), state, k0)
    call configure_template(t(1))
    call configure_column(c(1), t(1))
    call configure_forcing(f(1), k0)
    call configure_config(cfg)
    call fmr_new_b110_committed_state(s(1), column_id, state, t0, ok)
    call require(ok, 'committed state initialization')
  end subroutine initialize_runtime

  subroutine configure_template(t)
    type(fmr_template_t), intent(out) :: t
    t%template_id = 10030_int64
    t%physics_topology_id = 100301_int64
    t%vertical_layout_id = 100302_int64
    t%state_layout_id = 100303_int64
    t%solver_interface_id = 100304_int64
    t%optional_state_layout_id = 0_int64
    t%compatible_backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine configure_template

  subroutine configure_column(c,t)
    type(fmr_logical_column_t), intent(out) :: c
    type(fmr_template_t), intent(in) :: t
    c%column_id = column_id
    c%template_id = t%template_id
    c%parameter_ref = 1_int64
    c%state_handle = 1_int64
    c%forcing_handle = 1_int64
    c%backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine configure_column

  subroutine configure_parameters(p,state,k0)
    type(fmr_b110_physical_parameters_t), intent(out) :: p
    type(fmr_b110_physical_state_t), intent(out) :: state
    real(real64), intent(out) :: k0
    type(b110_default_mvg_parameters_t), target :: hp
    type(b110_default_mvg_provider_t) :: provider
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
    integer :: k

    p%parameter_set_id = 1003001_int64
    p%active_nodes = numnod
    allocate(p%z(numnod), p%dz(numnod), p%node_distance(numnod), p%cofgen(24,numnod))
    p%z = z
    p%dz = dz
    p%node_distance = disnod(1:numnod)
    p%cofgen = 0.0_real64
    do k = 1, numnod
      p%cofgen(1,k)=0.032_real64; p%cofgen(2,k)=0.423_real64; p%cofgen(3,k)=4.75_real64
      p%cofgen(4,k)=0.0135_real64; p%cofgen(5,k)=0.365_real64; p%cofgen(6,k)=1.455_real64
      p%cofgen(7,k)=1.0_real64-1.0_real64/p%cofgen(6,k); p%cofgen(8,k)=p%cofgen(4,k)
      p%cofgen(9,k)=0.0_real64; p%cofgen(10,k)=p%cofgen(3,k); p%cofgen(11,k)=0.999_real64
      p%cofgen(12,k)=0.99_real64*p%cofgen(3,k); p%cofgen(22,k)=-1.0e6_real64; p%cofgen(23,k)=1.0e-12_real64
    end do
    p%bottom_mode = 5
    p%swkimpl = 0
    p%swkmean = 1
    p%swsophy = 0
    p%root_extraction_active = .false.
    p%macropore_active = .false.
    p%snow_active = .false.
    p%hysteresis_active = .false.
    p%tabulated_hydraulics_active = .false.
    p%elasticity_active = .false.
    p%frost_active = .false.
    p%soil_temperature_active = .false.

    call initialize_b110_default_mvg_parameters(hp, p%cofgen)
    call bind_b110_default_mvg_provider(provider, hp, tm-t0)
    heads = initial_head
    call provider%evaluate(heads, water, conductivity, capacity, dkdh)
    k0 = conductivity(1)

    state%active_nodes = numnod
    allocate(state%pressure_head(numnod), state%water_content(numnod))
    state%pressure_head = heads
    state%water_content = water
    state%ponding_depth = 0.0_real64
    state%groundwater_level = -2.25_real64
  end subroutine configure_parameters

  subroutine configure_forcing(f,k0)
    type(fmr_b110_physical_forcing_t), intent(out) :: f
    real(real64), intent(in) :: k0
    f%top_flux = -k0
    f%top_head = initial_head
    f%bottom_flux = 0.0_real64
    f%bottom_head = bottom_head_first
    allocate(f%drainage_flux_by_level(1,numnod), f%subsurface_irrigation_source(numnod), &
         f%root_extraction_sink(numnod))
    f%drainage_flux_by_level = 0.0_real64
    f%subsurface_irrigation_source = 0.0_real64
    f%root_extraction_sink = 0.0_real64
  end subroutine configure_forcing

  subroutine configure_distribution(dp)
    type(drainage_distribution_parameters_t), intent(out) :: dp
    real(real64) :: depth
    integer :: k
    dp%active_nodes = numnod
    allocate(dp%dz(numnod), dp%zbotcp(numnod), dp%saturated_conductivity(numnod), &
         dp%horizontal_anisotropy_factor(numnod))
    dp%dz = dz
    depth = 0.0_real64
    do k = 1, numnod
      depth = depth + dz(k)
      dp%zbotcp(k) = -depth
    end do
    dp%saturated_conductivity = [1.0_real64,2.5_real64,0.7_real64,4.0_real64]
    dp%horizontal_anisotropy_factor = [1.2_real64,0.8_real64,1.5_real64,0.6_real64]
    dp%drain_spacing = 7.3_real64
  end subroutine configure_distribution

  subroutine configure_view(hv,gwl)
    type(process_hydraulic_view_t), intent(out) :: hv
    real(real64), intent(in) :: gwl
    hv%active_nodes = numnod
    if (allocated(hv%pressure_head)) deallocate(hv%pressure_head)
    if (allocated(hv%water_content)) deallocate(hv%water_content)
    allocate(hv%pressure_head(numnod), hv%water_content(numnod))
    hv%pressure_head = [-45.0_real64,-90.0_real64,-180.0_real64,-360.0_real64]
    hv%water_content = [0.31_real64,0.29_real64,0.27_real64,0.25_real64]
    hv%ponding_depth = 0.0_real64
    hv%groundwater_level = gwl
  end subroutine configure_view

  subroutine make_request(req,q)
    type(fmr_divdra_serialized_column_request_t), intent(out) :: req
    real(real64), intent(in) :: q
    req = fmr_divdra_serialized_column_request_t()
    req%column_id = column_id
    req%active = .true.
    req%distribution_parameter_ref = 1_int64
    req%hydraulic_view_ref = 1_int64
    req%scalar_transfer = q
  end subroutine make_request

  subroutine configure_config(cfg)
    type(canonical_numerical_config_t), intent(out) :: cfg
    cfg%transaction%temporal_tolerance = 0.0_real64
    cfg%transaction%mass_tolerance = mass_gate
    cfg%transaction%retry_scale = 0.5_real64
    cfg%transaction%max_retries = 2
    cfg%max_committed_substeps = 8
    cfg%progress_tolerance = 0.0_real64
  end subroutine configure_config

  subroutine reset_legacy()
    legacy_qdra = 88888.0_real64
    legacy_qssdi = -77777.0_real64
    legacy_qrot = 66666.0_real64
    swmacro = 0
    legacy_melt = 0.0_real64
  end subroutine reset_legacy

  real(real64) function soil_storage(state) result(storage)
    type(kernel_committed_state_t), intent(in) :: state
    class(transaction_state_t), allocatable :: snapshot
    logical :: got
    call state%snapshot(snapshot, got)
    call require(got, 'storage snapshot')
    storage = 0.0_real64
    select type (physical => snapshot)
    class is (fmr_b110_physical_state_t)
      storage = sum(physical%water_content*dz)
      call require(abs(physical%ponding_depth) <= mass_gate, 'surface storage remains inactive')
    class default
      call require(.false., 'unexpected committed physical state family')
    end select
  end function soil_storage

  logical function same_bits(a,b) result(equal)
    real(real64), intent(in) :: a,b
    integer(int64) :: ia,ib
    ia = transfer(a,ia)
    ib = transfer(b,ib)
    equal = ia == ib
  end function same_bits

  subroutine require(condition,label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'FTB10_TEST_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require
end program test_ftb10_drain_bottom_interaction

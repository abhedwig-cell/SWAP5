program test_fmr39_soil_temperature_runtime_composition
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use MOD_grid, only: numnod, z, dz, disnod
  use MOD_swap_base, only: swmacro
  use MOD_snow, only: melt
  use MOD_drain, only: legacy_qdra => qdra
  use MOD_irrigation, only: legacy_qssdi => qssdi
  use variables, only: legacy_qrot => qrot
  use mod_transaction_reference, only: transaction_state_t
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, fmr_column_diagnostics_t, &
       fmr_aggregate_diagnostics_t, FMR_BACKEND_SERIALIZED_REFERENCE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, fmr_b110_physical_parameters_t, &
       fmr_b110_physical_forcing_t, fmr_new_b110_committed_state
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t, &
       fmr_run_serialized_physical_multiswap, FMR_SERIAL_DISPATCH_OK
  use mod_fmr_committed_restart, only: fmr_committed_restart_bundle_t, fmr_export_committed_restart, &
       fmr_restore_committed_restart, FMR_RESTART_OK
  use mod_restricted_soil_temperature, only: SOIL_TEMP_OK, soil_temperature_parameters_t, &
       initialize_soil_temperature_parameters, initialize_soil_temperature_state, copy_soil_temperature_profile
  use mod_fmr04_fixed_flux_top_provider, only: fmr04_fixed_flux_top_provider_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  implicit none

  real(real64), parameter :: t0 = 7300.125_real64
  real(real64), parameter :: tm = 7300.375_real64
  real(real64), parameter :: t1 = 7300.625_real64
  real(real64), parameter :: head0 = -75.0_real64
  real(real64), parameter :: hard_mass_gate = 1.0e-12_real64
  integer(int64), parameter :: parameter_set_identity = 3905001_int64
  integer(int64), parameter :: thermal_layout_id = 390501_int64

  call test_enabled_success_and_atomic_failure()
  call test_split_restart_identity()
  call test_mixed_enabled_disabled_isolation()
  write(*,'(A)') 'FMR39_RESTRICTED_SOIL_TEMPERATURE_RUNTIME_TEST PASS'

contains

  subroutine test_enabled_success_and_atomic_failure()
    type(fmr_logical_column_t), allocatable :: columns(:), ref_columns(:)
    type(fmr_template_t), allocatable :: templates(:), ref_templates(:)
    type(fmr_b110_physical_parameters_t), allocatable :: parameters(:), ref_parameters(:)
    type(fmr_b110_physical_forcing_t), allocatable :: forcings(:), ref_forcings(:)
    type(kernel_committed_state_t), allocatable :: states(:), ref_states(:)
    type(fmr_serialized_column_result_t), allocatable :: results(:), ref_results(:)
    type(fmr_column_diagnostics_t), allocatable :: diagnostics(:), ref_diagnostics(:)
    type(fmr_aggregate_diagnostics_t) :: aggregate, ref_aggregate
    type(fmr04_fixed_flux_top_provider_t), target :: top_provider
    type(canonical_numerical_config_t) :: config
    integer(int64) :: before_fp, after_fp, valid_fp, ref_fp
    integer(int64) :: before_revision
    real(real64) :: before_time
    logical :: before_time_available
    integer :: status

    call configure_transaction(config)
    call build_single_runtime(.true., .true., columns, templates, parameters, forcings, states)
    before_fp = committed_fingerprint(states(1))
    call reset_legacy_globals()
    call fmr_run_serialized_physical_multiswap(columns, templates, parameters, forcings, states, config, top_provider, &
         t0, tm, 1, results, diagnostics, aggregate, status)
    call require(status == FMR_SERIAL_DISPATCH_OK, 'enabled dispatch status')
    call require(results(1)%completed .and. results(1)%committed, 'enabled transaction committed')
    call require(results(1)%solver_executed, 'Richards executed before thermal composition')
    call require(results(1)%mass%complete .and. abs(results(1)%mass%residual) <= hard_mass_gate, 'enabled hard water mass')
    after_fp = committed_fingerprint(states(1))
    call require(after_fp /= before_fp, 'enabled committed state changed')
    call require(committed_has_thermal_state(states(1)), 'enabled committed thermal state present')
    call require(thermal_profile_changed_from(states(1), 10.0_real64), 'enabled thermal profile advanced')
    write(*,'(A)') 'FMR39_ENABLED_WATER_THERMAL_ATOMIC_COMMIT=PASS'
    write(*,'(A)') 'FMR39_WATER_MASS_AUTHORITY_WITH_THERMAL_ACTIVE=PASS'

    ! Rebuild the exact same committed origin and force a thermal failure after
    ! the Richards solve by supplying a non-finite surface temperature.
    call build_single_runtime(.true., .true., columns, templates, parameters, forcings, states)
    forcings(1)%soil_temperature%prescribed_surface_temperature_c = ieee_value(0.0_real64, ieee_quiet_nan)
    before_fp = committed_fingerprint(states(1))
    before_revision = states(1)%current_revision()
    call states(1)%current_time(before_time, before_time_available)
    call reset_legacy_globals()
    call fmr_run_serialized_physical_multiswap(columns, templates, parameters, forcings, states, config, top_provider, &
         t0, tm, 1, results, diagnostics, aggregate, status)
    call require(status == FMR_SERIAL_DISPATCH_OK, 'thermal rejection dispatch status')
    call require(.not. results(1)%committed .and. .not. results(1)%completed, 'thermal failure rejects complete transaction')
    call require(results(1)%solver_executed, 'water solve executed before thermal rejection')
    call require(states(1)%current_revision() == before_revision, 'thermal rejection revision rollback')
    call require(committed_time_same(states(1), before_time, before_time_available), 'thermal rejection time rollback')
    call require(committed_fingerprint(states(1)) == before_fp, 'thermal rejection physical rollback')
    write(*,'(A)') 'FMR39_THERMAL_FAILURE_ROLLS_BACK_WATER_AND_TEMPERATURE=PASS'

    ! Fix only the thermal forcing. The rerun from the rejected state must be
    ! identical to a fresh reference run from the same committed origin.
    forcings(1)%soil_temperature%prescribed_surface_temperature_c = 18.0_real64
    call reset_legacy_globals()
    call fmr_run_serialized_physical_multiswap(columns, templates, parameters, forcings, states, config, top_provider, &
         t0, tm, 1, results, diagnostics, aggregate, status)
    call require(results(1)%committed, 'post-rejection valid rerun committed')
    valid_fp = committed_fingerprint(states(1))

    call build_single_runtime(.true., .true., ref_columns, ref_templates, ref_parameters, ref_forcings, ref_states)
    ref_forcings(1)%soil_temperature%prescribed_surface_temperature_c = 18.0_real64
    call reset_legacy_globals()
    call fmr_run_serialized_physical_multiswap(ref_columns, ref_templates, ref_parameters, ref_forcings, ref_states, &
         config, top_provider, t0, tm, 1, ref_results, ref_diagnostics, ref_aggregate, status)
    call require(ref_results(1)%committed, 'fresh reference committed')
    ref_fp = committed_fingerprint(ref_states(1))
    call require(valid_fp == ref_fp, 'retry/rerun starts from same committed physical origin')
    call require(same_bits(results(1)%mass%residual, ref_results(1)%mass%residual), 'retry/rerun water mass identity')
    write(*,'(A)') 'FMR39_RETRY_FROM_SAME_COMMITTED_STATE=PASS'
  end subroutine test_enabled_success_and_atomic_failure

  subroutine test_split_restart_identity()
    type(fmr_logical_column_t), allocatable :: ccol(:), rcol(:)
    type(fmr_template_t), allocatable :: ctpl(:), rtpl(:)
    type(fmr_b110_physical_parameters_t), allocatable :: cpar(:), rpar(:)
    type(fmr_b110_physical_forcing_t), allocatable :: cfor(:), rfor(:)
    type(kernel_committed_state_t), allocatable :: cstate(:), rstate(:)
    type(fmr_serialized_column_result_t), allocatable :: cres(:), rres(:)
    type(fmr_column_diagnostics_t), allocatable :: cdiag(:), rdiag(:)
    type(fmr_aggregate_diagnostics_t) :: cagg, ragg
    type(fmr_committed_restart_bundle_t) :: bundle
    type(fmr04_fixed_flux_top_provider_t), target :: top_provider
    type(canonical_numerical_config_t) :: config
    logical :: exported, restored
    integer :: status

    call configure_transaction(config)
    call build_single_runtime(.true., .true., ccol, ctpl, cpar, cfor, cstate)
    call reset_legacy_globals()
    call fmr_run_serialized_physical_multiswap(ccol, ctpl, cpar, cfor, cstate, config, top_provider, t0, tm, 1, &
         cres, cdiag, cagg, status)
    call require(cres(1)%committed, 'continuous first interval')
    call reset_legacy_globals()
    call fmr_run_serialized_physical_multiswap(ccol, ctpl, cpar, cfor, cstate, config, top_provider, tm, t1, 1, &
         cres, cdiag, cagg, status)
    call require(cres(1)%committed, 'continuous second interval')

    call build_single_runtime(.true., .true., rcol, rtpl, rpar, rfor, rstate)
    call reset_legacy_globals()
    call fmr_run_serialized_physical_multiswap(rcol, rtpl, rpar, rfor, rstate, config, top_provider, t0, tm, 1, &
         rres, rdiag, ragg, status)
    call require(rres(1)%committed, 'restart first interval')
    call fmr_export_committed_restart(rcol, rtpl, rstate, parameter_set_identity, bundle, exported, status)
    call require(exported .and. status == FMR_RESTART_OK, 'thermal restart export')
    call require(bundle_record_has_thermal(bundle), 'restart bundle carries thermal state')

    deallocate(rcol, rtpl, rpar, rfor, rstate)
    call build_single_runtime(.true., .false., rcol, rtpl, rpar, rfor, rstate)
    call fmr_restore_committed_restart(bundle, parameter_set_identity, rcol, rtpl, rstate, restored, status)
    call require(restored .and. status == FMR_RESTART_OK, 'thermal restart restore')
    call require(committed_has_thermal_state(rstate(1)), 'restored thermal state present')
    call reset_legacy_globals()
    call fmr_run_serialized_physical_multiswap(rcol, rtpl, rpar, rfor, rstate, config, top_provider, tm, t1, 1, &
         rres, rdiag, ragg, status)
    call require(rres(1)%committed, 'restart second interval')
    call require(committed_fingerprint(cstate(1)) == committed_fingerprint(rstate(1)), 'continuous/restart exact endpoint')
    call require(same_bits(cres(1)%mass%residual, rres(1)%mass%residual), 'continuous/restart second-interval mass')
    write(*,'(A)') 'FMR39_SPLIT_RESTART_WATER_THERMAL_IDENTITY=PASS'
    write(*,'(A)') 'FMR39_RESTART_USES_EXISTING_POLYMORPHIC_PHYSICAL_STATE=PASS'
  end subroutine test_split_restart_identity

  subroutine test_mixed_enabled_disabled_isolation()
    type(fmr_logical_column_t), allocatable :: columns(:), acol(:), icol(:)
    type(fmr_template_t), allocatable :: templates(:), atpl(:), itpl(:)
    type(fmr_b110_physical_parameters_t), allocatable :: parameters(:), apar(:), ipar(:)
    type(fmr_b110_physical_forcing_t), allocatable :: forcings(:), afor(:), ifor(:)
    type(kernel_committed_state_t), allocatable :: states(:), astate(:), istate(:)
    type(fmr_serialized_column_result_t), allocatable :: results(:), ares(:), ires(:)
    type(fmr_column_diagnostics_t), allocatable :: diagnostics(:), adiag(:), idiag(:)
    type(fmr_aggregate_diagnostics_t) :: aggregate, aagg, iagg
    type(fmr04_fixed_flux_top_provider_t), target :: top_provider
    type(canonical_numerical_config_t) :: config
    integer :: status

    call configure_transaction(config)
    call build_mixed_runtime(columns, templates, parameters, forcings, states)
    call reset_legacy_globals()
    call fmr_run_serialized_physical_multiswap(columns, templates, parameters, forcings, states, config, top_provider, &
         t0, tm, 2, results, diagnostics, aggregate, status)
    call require(status == FMR_SERIAL_DISPATCH_OK .and. all(results%committed), 'mixed runtime commits')
    call require(committed_has_thermal_state(states(1)), 'mixed active thermal allocation')
    call require(.not. committed_has_thermal_state(states(2)), 'mixed inactive has no thermal allocation')

    call build_single_runtime(.true., .true., acol, atpl, apar, afor, astate)
    call reset_legacy_globals()
    call fmr_run_serialized_physical_multiswap(acol, atpl, apar, afor, astate, config, top_provider, t0, tm, 1, &
         ares, adiag, aagg, status)
    call require(ares(1)%committed, 'active reference commit')

    call build_single_runtime(.false., .true., icol, itpl, ipar, ifor, istate)
    call reset_legacy_globals()
    call fmr_run_serialized_physical_multiswap(icol, itpl, ipar, ifor, istate, config, top_provider, t0, tm, 1, &
         ires, idiag, iagg, status)
    call require(ires(1)%committed, 'inactive reference commit')

    call require(committed_fingerprint(states(1)) == committed_fingerprint(astate(1)), 'mixed active isolation')
    call require(committed_fingerprint(states(2)) == committed_fingerprint(istate(1)), 'mixed inactive isolation')
    call require(.not. committed_has_thermal_state(istate(1)), 'inactive reference remains compact')
    write(*,'(A)') 'FMR39_MIXED_ENABLED_DISABLED_MULTISWAP_ISOLATION=PASS'
    write(*,'(A)') 'FMR39_INACTIVE_COLUMN_NO_THERMAL_PHYSICAL_STATE=PASS'
  end subroutine test_mixed_enabled_disabled_isolation

  subroutine build_single_runtime(thermal_active, initialize_state, columns, templates, parameters, forcings, states)
    logical, intent(in) :: thermal_active, initialize_state
    type(fmr_logical_column_t), allocatable, intent(out) :: columns(:)
    type(fmr_template_t), allocatable, intent(out) :: templates(:)
    type(fmr_b110_physical_parameters_t), allocatable, intent(out) :: parameters(:)
    type(fmr_b110_physical_forcing_t), allocatable, intent(out) :: forcings(:)
    type(kernel_committed_state_t), allocatable, intent(out) :: states(:)
    type(fmr_b110_physical_state_t) :: initial_state
    real(real64) :: conductivity0
    logical :: ok

    allocate(columns(1), templates(1), parameters(1), forcings(1), states(1))
    call configure_template(templates(1), thermal_active, 39051_int64)
    call configure_parameters(parameters(1), initial_state, conductivity0, thermal_active)
    call configure_forcing(forcings(1), conductivity0, thermal_active, 18.0_real64)
    columns(1)%column_id = 390501_int64
    columns(1)%template_id = templates(1)%template_id
    columns(1)%parameter_ref = 1_int64
    columns(1)%state_handle = 1_int64
    columns(1)%forcing_handle = 1_int64
    columns(1)%backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
    if (initialize_state) then
      call fmr_new_b110_committed_state(states(1), columns(1)%column_id, initial_state, t0, ok)
      call require(ok, 'single committed state init')
    end if
  end subroutine build_single_runtime

  subroutine build_mixed_runtime(columns, templates, parameters, forcings, states)
    type(fmr_logical_column_t), allocatable, intent(out) :: columns(:)
    type(fmr_template_t), allocatable, intent(out) :: templates(:)
    type(fmr_b110_physical_parameters_t), allocatable, intent(out) :: parameters(:)
    type(fmr_b110_physical_forcing_t), allocatable, intent(out) :: forcings(:)
    type(kernel_committed_state_t), allocatable, intent(out) :: states(:)
    type(fmr_b110_physical_state_t) :: s1, s2
    real(real64) :: k1, k2
    logical :: ok

    allocate(columns(2), templates(2), parameters(2), forcings(2), states(2))
    call configure_template(templates(1), .true., 39051_int64)
    call configure_template(templates(2), .false., 39052_int64)
    call configure_parameters(parameters(1), s1, k1, .true.)
    call configure_parameters(parameters(2), s2, k2, .false.)
    call configure_forcing(forcings(1), k1, .true., 18.0_real64)
    call configure_forcing(forcings(2), k2, .false., 0.0_real64)
    columns(1)%column_id=390501_int64; columns(1)%template_id=templates(1)%template_id
    columns(1)%parameter_ref=1_int64; columns(1)%state_handle=1_int64; columns(1)%forcing_handle=1_int64
    columns(1)%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    columns(2)%column_id=390502_int64; columns(2)%template_id=templates(2)%template_id
    columns(2)%parameter_ref=2_int64; columns(2)%state_handle=2_int64; columns(2)%forcing_handle=2_int64
    columns(2)%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    call fmr_new_b110_committed_state(states(1), columns(1)%column_id, s1, t0, ok); call require(ok, 'mixed active init')
    call fmr_new_b110_committed_state(states(2), columns(2)%column_id, s2, t0, ok); call require(ok, 'mixed inactive init')
  end subroutine build_mixed_runtime

  subroutine configure_template(template, thermal_active, template_id)
    type(fmr_template_t), intent(out) :: template
    logical, intent(in) :: thermal_active
    integer(int64), intent(in) :: template_id
    template%template_id = template_id
    template%physics_topology_id = 390510_int64 + merge(1_int64,0_int64,thermal_active)
    template%vertical_layout_id = 390520_int64
    template%state_layout_id = 390530_int64
    template%solver_interface_id = 390540_int64
    template%optional_state_layout_id = merge(thermal_layout_id,0_int64,thermal_active)
    template%compatible_backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine configure_template

  subroutine configure_parameters(parameters, state, conductivity0, thermal_active)
    type(fmr_b110_physical_parameters_t), intent(out) :: parameters
    type(fmr_b110_physical_state_t), intent(out) :: state
    real(real64), intent(out) :: conductivity0
    logical, intent(in) :: thermal_active
    type(b110_default_mvg_parameters_t), target :: hyd_parameters
    type(b110_default_mvg_provider_t) :: constitutive
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
    real(real64) :: theta_sat(numnod), fq(numnod), fc(numnod), fo(numnod), distance(numnod)
    integer :: i, s

    parameters%parameter_set_id = 390501_int64 + merge(0_int64,1_int64,thermal_active)
    parameters%active_nodes = numnod
    allocate(parameters%z(numnod), parameters%dz(numnod), parameters%node_distance(numnod), parameters%cofgen(24,numnod))
    parameters%z=z; parameters%dz=dz; parameters%node_distance=disnod(1:numnod); parameters%cofgen=0.0_real64
    do i=1,numnod
      parameters%cofgen(1,i)=0.032_real64; parameters%cofgen(2,i)=0.423_real64
      parameters%cofgen(3,i)=4.75_real64; parameters%cofgen(4,i)=0.0135_real64
      parameters%cofgen(5,i)=0.365_real64; parameters%cofgen(6,i)=1.455_real64
      parameters%cofgen(7,i)=1.0_real64-1.0_real64/parameters%cofgen(6,i)
      parameters%cofgen(8,i)=parameters%cofgen(4,i); parameters%cofgen(9,i)=0.0_real64
      parameters%cofgen(10,i)=parameters%cofgen(3,i); parameters%cofgen(11,i)=0.999_real64
      parameters%cofgen(12,i)=0.99_real64*parameters%cofgen(3,i)
      parameters%cofgen(22,i)=-1.0e6_real64; parameters%cofgen(23,i)=1.0e-12_real64
    end do
    parameters%bottom_mode=7; parameters%swkimpl=0; parameters%swkmean=1; parameters%swsophy=0
    parameters%root_extraction_active=.false.; parameters%macropore_active=.false.; parameters%snow_active=.false.
    parameters%hysteresis_active=.false.; parameters%tabulated_hydraulics_active=.false.
    parameters%elasticity_active=.false.; parameters%frost_active=.false.; parameters%soil_temperature_active=thermal_active

    call initialize_b110_default_mvg_parameters(hyd_parameters, parameters%cofgen)
    call bind_b110_default_mvg_provider(constitutive, hyd_parameters, tm-t0)
    heads=head0
    call constitutive%evaluate(heads, water, conductivity, capacity, dkdh)
    call require(all(conductivity == conductivity(1)), 'uniform conductivity fixture')
    conductivity0=conductivity(1)
    state%active_nodes=numnod; allocate(state%pressure_head(numnod),state%water_content(numnod))
    state%pressure_head=heads; state%water_content=water; state%ponding_depth=0.0_real64; state%groundwater_level=-2.0_real64

    if (thermal_active) then
      allocate(parameters%soil_temperature, state%soil_temperature)
      theta_sat=0.45_real64; fq=0.35_real64; fc=0.15_real64; fo=0.05_real64
      distance=parameters%node_distance
      where (distance <= 0.0_real64) distance=max(0.5_real64*parameters%dz,1.0e-6_real64)
      call initialize_soil_temperature_parameters(parameters%dz, distance, theta_sat, fq, fc, fo, parameters%soil_temperature, s)
      call require(s == SOIL_TEMP_OK .and. parameters%soil_temperature%ready(), 'thermal parameter init')
      call initialize_soil_temperature_state([(10.0_real64,i=1,numnod)], state%soil_temperature, s)
      call require(s == SOIL_TEMP_OK, 'thermal state init')
    end if
  end subroutine configure_parameters

  subroutine configure_forcing(forcing, conductivity0, thermal_active, surface_temperature)
    type(fmr_b110_physical_forcing_t), intent(out) :: forcing
    real(real64), intent(in) :: conductivity0, surface_temperature
    logical, intent(in) :: thermal_active
    integer :: i
    forcing%top_flux=-conductivity0; forcing%top_head=head0
    forcing%bottom_flux=-conductivity0; forcing%bottom_head=-100.0_real64
    allocate(forcing%drainage_flux_by_level(2,numnod),forcing%subsurface_irrigation_source(numnod), &
             forcing%root_extraction_sink(numnod))
    do i=1,numnod
      forcing%drainage_flux_by_level(1,i)=1.0e-5_real64*real(i,real64)
      forcing%drainage_flux_by_level(2,i)=-2.0e-6_real64*real(i+1,real64)
      forcing%subsurface_irrigation_source(i)=forcing%drainage_flux_by_level(1,i)+forcing%drainage_flux_by_level(2,i)
      forcing%root_extraction_sink(i)=0.0_real64
    end do
    if (thermal_active) then
      allocate(forcing%soil_temperature)
      forcing%soil_temperature%prescribed_surface_temperature_c=surface_temperature
    end if
  end subroutine configure_forcing

  subroutine configure_transaction(config)
    type(canonical_numerical_config_t), intent(out) :: config
    config%transaction%temporal_tolerance=0.0_real64
    config%transaction%mass_tolerance=hard_mass_gate
    config%transaction%retry_scale=0.5_real64
    config%transaction%max_retries=2
    config%max_committed_substeps=8
    config%progress_tolerance=0.0_real64
  end subroutine configure_transaction

  subroutine reset_legacy_globals()
    legacy_qdra=12345.0_real64; legacy_qssdi=-54321.0_real64; legacy_qrot=0.0_real64
    swmacro=0; melt=0.0_real64
  end subroutine reset_legacy_globals

  logical function committed_has_thermal_state(state) result(has)
    type(kernel_committed_state_t), intent(in) :: state
    class(transaction_state_t), allocatable :: snapshot
    logical :: got
    call state%snapshot(snapshot,got); call require(got,'thermal snapshot')
    has=.false.
    select type (physical=>snapshot)
    class is (fmr_b110_physical_state_t)
      has=allocated(physical%soil_temperature)
    class default
      call require(.false.,'unexpected physical state family')
    end select
  end function committed_has_thermal_state

  logical function thermal_profile_changed_from(state, initial) result(changed)
    type(kernel_committed_state_t), intent(in) :: state
    real(real64), intent(in) :: initial
    class(transaction_state_t), allocatable :: snapshot
    real(real64), allocatable :: profile(:)
    logical :: got
    integer :: s
    changed=.false.; call state%snapshot(snapshot,got); if(.not.got)return
    select type (physical=>snapshot)
    class is (fmr_b110_physical_state_t)
      if(.not.allocated(physical%soil_temperature))return
      call copy_soil_temperature_profile(physical%soil_temperature,profile,s)
      if(s==SOIL_TEMP_OK) changed=maxval(abs(profile-initial))>1.0e-12_real64
    class default
      return
    end select
  end function thermal_profile_changed_from

  logical function bundle_record_has_thermal(bundle) result(has)
    type(fmr_committed_restart_bundle_t), intent(in) :: bundle
    has=.false.; if(.not.allocated(bundle%records))return; if(size(bundle%records)/=1)return
    if(.not.allocated(bundle%records(1)%physical_state))return
    select type (physical=>bundle%records(1)%physical_state)
    class is (fmr_b110_physical_state_t)
      has=allocated(physical%soil_temperature)
    class default
      return
    end select
  end function bundle_record_has_thermal

  integer(int64) function committed_fingerprint(state) result(fp)
    type(kernel_committed_state_t), intent(in) :: state
    class(transaction_state_t), allocatable :: snapshot
    real(real64), allocatable :: profile(:)
    logical :: got
    integer :: i,s
    call state%snapshot(snapshot,got); call require(got,'fingerprint snapshot')
    fp=1469598103934665603_int64
    select type (physical=>snapshot)
    class is (fmr_b110_physical_state_t)
      fp=ieor(fp,int(physical%active_nodes,int64))
      do i=1,physical%active_nodes
        fp=ieor(fp,transfer(physical%pressure_head(i),fp)); fp=ieor(fp,transfer(physical%water_content(i),fp))
      end do
      fp=ieor(fp,transfer(physical%ponding_depth,fp)); fp=ieor(fp,transfer(physical%groundwater_level,fp))
      if(allocated(physical%soil_temperature))then
        fp=ieor(fp,390501_int64)
        call copy_soil_temperature_profile(physical%soil_temperature,profile,s); call require(s==SOIL_TEMP_OK,'fingerprint thermal')
        do i=1,size(profile); fp=ieor(fp,transfer(profile(i),fp)); end do
      end if
    class default
      error stop 'F-MR39 unexpected physical state type'
    end select
  end function committed_fingerprint

  logical function committed_time_same(state, expected, expected_available) result(same)
    type(kernel_committed_state_t), intent(in) :: state
    real(real64), intent(in) :: expected
    logical, intent(in) :: expected_available
    real(real64) :: actual
    logical :: available
    call state%current_time(actual,available)
    same=(available .eqv. expected_available)
    if(same .and. available) same=same_bits(actual,expected)
  end function committed_time_same

  logical function same_bits(a,b)
    real(real64), intent(in) :: a,b
    integer(int64) :: ia,ib
    ia=transfer(a,ia); ib=transfer(b,ib); same_bits=ia==ib
  end function same_bits

  subroutine require(condition,label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if(.not.condition)then
      write(*,'(A,1X,A)') 'FMR39_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_fmr39_soil_temperature_runtime_composition

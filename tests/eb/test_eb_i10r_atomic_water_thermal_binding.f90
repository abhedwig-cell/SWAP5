program test_eb_i10r_atomic_water_thermal_binding
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
       fmr_aggregate_diagnostics_t, FMR_BACKEND_SERIALIZED_REFERENCE, &
       FMR_OPTIONAL_STATE_LAYOUT_RESTRICTED_SOIL_TEMPERATURE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, fmr_b110_physical_parameters_t, &
       fmr_b110_physical_forcing_t, fmr_new_b110_committed_state
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t, &
       FMR_SERIAL_DISPATCH_OK, FMR_SERIAL_DISPATCH_INVALID_REQUEST
  use mod_fmr_accepted_water_thermal_binding, only: fmr_accepted_water_thermal_record_t, &
       fmr_run_serialized_multiswap_with_water_thermal_binding, EB_I10R_BINDING_OK, &
       EB_I10R_BINDING_INVALID_REQUEST, EB_I10R_BINDING_INVALID_REGISTRY, &
       EB_I10R_BINDING_THERMAL_TOPOLOGY_REQUIRED
  use mod_restricted_soil_temperature, only: SOIL_TEMP_OK, initialize_soil_temperature_parameters, &
       initialize_soil_temperature_state, copy_soil_temperature_profile
  use mod_fmr04_fixed_top_provider, only: fmr04_fixed_flux_top_provider_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  implicit none

  real(real64), parameter :: t0 = 7310.125_real64
  real(real64), parameter :: t1 = 7310.375_real64
  real(real64), parameter :: head0 = -75.0_real64
  real(real64), parameter :: hard_mass_gate = 1.0e-12_real64
  integer(int64), parameter :: thermal_id = 101001_int64
  integer(int64), parameter :: inactive_id = 101002_int64

  call test_successful_atomic_binding()
  call test_thermal_failure_has_no_accepted_binding()
  call test_nonthermal_request_rejected_precommit()
  call test_sparse_mixed_multiswap_binding()
  call test_invalid_ids_rejected_precommit()
  write(*,'(A)') 'EB_I10R_ATOMIC_WATER_THERMAL_BINDING_TEST PASS'

contains

  subroutine test_successful_atomic_binding()
    type(fmr_logical_column_t), allocatable :: columns(:)
    type(fmr_template_t), allocatable :: templates(:)
    type(fmr_b110_physical_parameters_t), allocatable :: parameters(:)
    type(fmr_b110_physical_forcing_t), allocatable :: forcings(:)
    type(kernel_committed_state_t), allocatable :: states(:)
    type(fmr_serialized_column_result_t), allocatable :: results(:)
    type(fmr_column_diagnostics_t), allocatable :: diagnostics(:)
    type(fmr_aggregate_diagnostics_t) :: aggregate
    type(fmr_accepted_water_thermal_record_t), allocatable :: accepted(:)
    type(fmr04_fixed_flux_top_provider_t), target :: top_provider
    type(canonical_numerical_config_t) :: config
    integer(int64) :: ids(1)
    integer :: dispatch, binding
    real(real64) :: rt0, rt1
    logical :: available

    ids = [thermal_id]
    call configure_transaction(config)
    call build_single_runtime(.true., columns, templates, parameters, forcings, states)
    call reset_legacy_globals()
    call fmr_run_serialized_multiswap_with_water_thermal_binding(columns, templates, parameters, forcings, states, &
         config, top_provider, t0, t1, 1, ids, results, diagnostics, aggregate, dispatch, binding, accepted)

    call require(dispatch == FMR_SERIAL_DISPATCH_OK .and. binding == EB_I10R_BINDING_OK, 'success statuses')
    call require(size(accepted) == 1 .and. accepted(1)%column_id == thermal_id, 'success sparse record association')
    call require(accepted(1)%transaction%ready(), 'success accepted transaction ready')
    call require(results(1)%completed .and. results(1)%committed, 'success column committed')
    call require(states(1)%current_revision() == 1_int64, 'success revision exactly one')
    call require(accepted(1)%transaction%current_lineage_id() == thermal_id, 'success lineage')
    call require(accepted(1)%transaction%origin_revision() == 0_int64, 'success origin revision')
    call require(accepted(1)%transaction%committed_revision() == 1_int64, 'success committed revision')
    call accepted(1)%transaction%origin_interval(rt0, rt1, available)
    call require(available .and. same_bits(rt0,t0) .and. same_bits(rt1,t1), 'success interval')
    call require(committed_has_thermal_state(states(1)), 'success committed state retains thermal state')
    call require(results(1)%mass%complete .and. abs(results(1)%mass%residual) <= hard_mass_gate, 'success mass authority')
    write(*,'(A)') 'EB_I10R_ACCEPTED_THERMAL_TRANSACTION_BINDING=PASS'
    write(*,'(A)') 'EB_I10R_EXISTING_WATER_MASS_AUTHORITY_PRESERVED=PASS'
  end subroutine test_successful_atomic_binding

  subroutine test_thermal_failure_has_no_accepted_binding()
    type(fmr_logical_column_t), allocatable :: columns(:)
    type(fmr_template_t), allocatable :: templates(:)
    type(fmr_b110_physical_parameters_t), allocatable :: parameters(:)
    type(fmr_b110_physical_forcing_t), allocatable :: forcings(:)
    type(kernel_committed_state_t), allocatable :: states(:)
    type(fmr_serialized_column_result_t), allocatable :: results(:)
    type(fmr_column_diagnostics_t), allocatable :: diagnostics(:)
    type(fmr_aggregate_diagnostics_t) :: aggregate
    type(fmr_accepted_water_thermal_record_t), allocatable :: accepted(:)
    type(fmr04_fixed_flux_top_provider_t), target :: top_provider
    type(canonical_numerical_config_t) :: config
    integer(int64) :: ids(1), before_fp
    integer :: dispatch, binding

    ids = [thermal_id]
    call configure_transaction(config)
    call build_single_runtime(.true., columns, templates, parameters, forcings, states)
    forcings(1)%soil_temperature%prescribed_surface_temperature_c = ieee_value(0.0_real64, ieee_quiet_nan)
    before_fp = committed_fingerprint(states(1))
    call reset_legacy_globals()
    call fmr_run_serialized_multiswap_with_water_thermal_binding(columns, templates, parameters, forcings, states, &
         config, top_provider, t0, t1, 1, ids, results, diagnostics, aggregate, dispatch, binding, accepted)

    call require(dispatch == FMR_SERIAL_DISPATCH_OK .and. binding == EB_I10R_BINDING_OK, 'thermal failure wrapper status')
    call require(size(accepted) == 1 .and. .not. accepted(1)%transaction%ready(), 'thermal failure no accepted binding')
    call require(.not. results(1)%committed .and. .not. results(1)%completed, 'thermal failure no commit')
    call require(states(1)%current_revision() == 0_int64, 'thermal failure revision unchanged')
    call require(committed_fingerprint(states(1)) == before_fp, 'thermal failure state rollback')
    write(*,'(A)') 'EB_I10R_THERMAL_FAILURE_NO_PROVENANCE_AND_EXACT_ROLLBACK=PASS'
  end subroutine test_thermal_failure_has_no_accepted_binding

  subroutine test_nonthermal_request_rejected_precommit()
    type(fmr_logical_column_t), allocatable :: columns(:)
    type(fmr_template_t), allocatable :: templates(:)
    type(fmr_b110_physical_parameters_t), allocatable :: parameters(:)
    type(fmr_b110_physical_forcing_t), allocatable :: forcings(:)
    type(kernel_committed_state_t), allocatable :: states(:)
    type(fmr_serialized_column_result_t), allocatable :: results(:)
    type(fmr_column_diagnostics_t), allocatable :: diagnostics(:)
    type(fmr_aggregate_diagnostics_t) :: aggregate
    type(fmr_accepted_water_thermal_record_t), allocatable :: accepted(:)
    type(fmr04_fixed_flux_top_provider_t), target :: top_provider
    type(canonical_numerical_config_t) :: config
    integer(int64) :: ids(1), before_fp
    integer :: dispatch, binding

    ids = [thermal_id]
    call configure_transaction(config)
    call build_single_runtime(.false., columns, templates, parameters, forcings, states)
    before_fp = committed_fingerprint(states(1))
    call fmr_run_serialized_multiswap_with_water_thermal_binding(columns, templates, parameters, forcings, states, &
         config, top_provider, t0, t1, 1, ids, results, diagnostics, aggregate, dispatch, binding, accepted)

    call require(binding == EB_I10R_BINDING_THERMAL_TOPOLOGY_REQUIRED, 'nonthermal topology rejected')
    call require(dispatch == FMR_SERIAL_DISPATCH_INVALID_REQUEST, 'nonthermal dispatch precommit rejection')
    call require(size(accepted) == 0, 'nonthermal produces no records')
    call require(states(1)%current_revision() == 0_int64 .and. committed_fingerprint(states(1)) == before_fp, &
         'nonthermal request leaves state untouched')
    write(*,'(A)') 'EB_I10R_NONTHERMAL_REQUEST_FAILS_PRECOMMIT=PASS'
  end subroutine test_nonthermal_request_rejected_precommit

  subroutine test_sparse_mixed_multiswap_binding()
    type(fmr_logical_column_t), allocatable :: columns(:)
    type(fmr_template_t), allocatable :: templates(:)
    type(fmr_b110_physical_parameters_t), allocatable :: parameters(:)
    type(fmr_b110_physical_forcing_t), allocatable :: forcings(:)
    type(kernel_committed_state_t), allocatable :: states(:)
    type(fmr_serialized_column_result_t), allocatable :: results(:)
    type(fmr_column_diagnostics_t), allocatable :: diagnostics(:)
    type(fmr_aggregate_diagnostics_t) :: aggregate
    type(fmr_accepted_water_thermal_record_t), allocatable :: accepted(:)
    type(fmr04_fixed_flux_top_provider_t), target :: top_provider
    type(canonical_numerical_config_t) :: config
    integer(int64) :: ids(1)
    integer :: dispatch, binding

    ids = [thermal_id]
    call configure_transaction(config)
    call build_mixed_runtime(columns, templates, parameters, forcings, states)
    call reset_legacy_globals()
    call fmr_run_serialized_multiswap_with_water_thermal_binding(columns, templates, parameters, forcings, states, &
         config, top_provider, t0, t1, 2, ids, results, diagnostics, aggregate, dispatch, binding, accepted)

    call require(dispatch == FMR_SERIAL_DISPATCH_OK .and. binding == EB_I10R_BINDING_OK, 'mixed statuses')
    call require(all(results%committed), 'mixed both physical transactions committed')
    call require(states(1)%current_revision() == 1_int64 .and. states(2)%current_revision() == 1_int64, 'mixed revisions')
    call require(size(accepted) == 1 .and. accepted(1)%column_id == thermal_id .and. &
         accepted(1)%transaction%ready(), 'mixed sparse thermal-only binding')
    call require(committed_has_thermal_state(states(1)) .and. .not. committed_has_thermal_state(states(2)), &
         'mixed optional thermal state isolation')
    write(*,'(A)') 'EB_I10R_SPARSE_MULTISWAP_THERMAL_BINDING=PASS'
  end subroutine test_sparse_mixed_multiswap_binding

  subroutine test_invalid_ids_rejected_precommit()
    type(fmr_logical_column_t), allocatable :: columns(:)
    type(fmr_template_t), allocatable :: templates(:)
    type(fmr_b110_physical_parameters_t), allocatable :: parameters(:)
    type(fmr_b110_physical_forcing_t), allocatable :: forcings(:)
    type(kernel_committed_state_t), allocatable :: states(:)
    type(fmr_serialized_column_result_t), allocatable :: results(:)
    type(fmr_column_diagnostics_t), allocatable :: diagnostics(:)
    type(fmr_aggregate_diagnostics_t) :: aggregate
    type(fmr_accepted_water_thermal_record_t), allocatable :: accepted(:)
    type(fmr04_fixed_flux_top_provider_t), target :: top_provider
    type(canonical_numerical_config_t) :: config
    integer(int64) :: duplicates(2), unknown(1)
    integer :: dispatch, binding

    call configure_transaction(config)
    duplicates = [thermal_id, thermal_id]
    call build_single_runtime(.true., columns, templates, parameters, forcings, states)
    call fmr_run_serialized_multiswap_with_water_thermal_binding(columns, templates, parameters, forcings, states, &
         config, top_provider, t0, t1, 1, duplicates, results, diagnostics, aggregate, dispatch, binding, accepted)
    call require(binding == EB_I10R_BINDING_INVALID_REQUEST .and. states(1)%current_revision() == 0_int64, &
         'duplicate ids rejected precommit')

    unknown = [999999_int64]
    call build_single_runtime(.true., columns, templates, parameters, forcings, states)
    call fmr_run_serialized_multiswap_with_water_thermal_binding(columns, templates, parameters, forcings, states, &
         config, top_provider, t0, t1, 1, unknown, results, diagnostics, aggregate, dispatch, binding, accepted)
    call require(binding == EB_I10R_BINDING_INVALID_REGISTRY .and. states(1)%current_revision() == 0_int64, &
         'unknown id rejected precommit')
    write(*,'(A)') 'EB_I10R_INVALID_BINDING_REQUESTS_PRECOMMIT=PASS'
  end subroutine test_invalid_ids_rejected_precommit

  subroutine build_single_runtime(thermal_active, columns, templates, parameters, forcings, states)
    logical, intent(in) :: thermal_active
    type(fmr_logical_column_t), allocatable, intent(out) :: columns(:)
    type(fmr_template_t), allocatable, intent(out) :: templates(:)
    type(fmr_b110_physical_parameters_t), allocatable, intent(out) :: parameters(:)
    type(fmr_b110_physical_forcing_t), allocatable, intent(out) :: forcings(:)
    type(kernel_committed_state_t), allocatable, intent(out) :: states(:)
    type(fmr_b110_physical_state_t) :: initial_state
    real(real64) :: conductivity0
    logical :: ok

    allocate(columns(1), templates(1), parameters(1), forcings(1), states(1))
    call configure_template(templates(1), thermal_active, 10101_int64)
    call configure_parameters(parameters(1), initial_state, conductivity0, thermal_active)
    call configure_forcing(forcings(1), conductivity0, thermal_active, 18.0_real64)
    columns(1)%column_id = thermal_id
    columns(1)%template_id = templates(1)%template_id
    columns(1)%parameter_ref = 1_int64
    columns(1)%state_handle = 1_int64
    columns(1)%forcing_handle = 1_int64
    columns(1)%backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
    call fmr_new_b110_committed_state(states(1), columns(1)%column_id, initial_state, t0, ok)
    call require(ok, 'single committed state init')
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
    call configure_template(templates(1), .true., 10101_int64)
    call configure_template(templates(2), .false., 10102_int64)
    call configure_parameters(parameters(1), s1, k1, .true.)
    call configure_parameters(parameters(2), s2, k2, .false.)
    call configure_forcing(forcings(1), k1, .true., 18.0_real64)
    call configure_forcing(forcings(2), k2, .false., 0.0_real64)
    columns(1)%column_id=thermal_id; columns(1)%template_id=templates(1)%template_id
    columns(1)%parameter_ref=1_int64; columns(1)%state_handle=1_int64; columns(1)%forcing_handle=1_int64
    columns(1)%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    columns(2)%column_id=inactive_id; columns(2)%template_id=templates(2)%template_id
    columns(2)%parameter_ref=2_int64; columns(2)%state_handle=2_int64; columns(2)%forcing_handle=2_int64
    columns(2)%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    call fmr_new_b110_committed_state(states(1), columns(1)%column_id, s1, t0, ok); call require(ok,'mixed thermal init')
    call fmr_new_b110_committed_state(states(2), columns(2)%column_id, s2, t0, ok); call require(ok,'mixed inactive init')
  end subroutine build_mixed_runtime

  subroutine configure_template(template, thermal_active, template_id)
    type(fmr_template_t), intent(out) :: template
    logical, intent(in) :: thermal_active
    integer(int64), intent(in) :: template_id
    template%template_id = template_id
    template%physics_topology_id = 10110_int64 + merge(1_int64,0_int64,thermal_active)
    template%vertical_layout_id = 10120_int64
    template%state_layout_id = 10130_int64
    template%solver_interface_id = 10140_int64
    template%optional_state_layout_id = merge(FMR_OPTIONAL_STATE_LAYOUT_RESTRICTED_SOIL_TEMPERATURE,0_int64,thermal_active)
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

    parameters%parameter_set_id = 101001_int64 + merge(0_int64,1_int64,thermal_active)
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
    call bind_b110_default_mvg_provider(constitutive, hyd_parameters, t1-t0)
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
        fp=ieor(fp,101001_int64)
        call copy_soil_temperature_profile(physical%soil_temperature,profile,s); call require(s==SOIL_TEMP_OK,'fingerprint thermal')
        do i=1,size(profile); fp=ieor(fp,transfer(profile(i),fp)); end do
      end if
    class default
      error stop 'EB-I10R unexpected physical state type'
    end select
  end function committed_fingerprint

  logical function same_bits(a,b)
    real(real64), intent(in) :: a,b
    integer(int64) :: ia,ib
    ia=transfer(a,ia); ib=transfer(b,ib); same_bits=ia==ib
  end function same_bits

  subroutine require(condition,label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if(.not.condition)then
      write(*,'(A,1X,A)') 'EB_I10R_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_eb_i10r_atomic_water_thermal_binding

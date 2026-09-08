program test_fvq18_ssdi_mass
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use MOD_swap_base, only: swmacro
  use MOD_snow, only: legacy_melt => melt
  use MOD_drain, only: legacy_qdra => qdra
  use MOD_irrigation, only: legacy_qssdi => qssdi
  use variables, only: legacy_qrot => qrot
  use mod_transaction_reference, only: transaction_state_t, TX_MASS_MISSING_NONE
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, fmr_column_diagnostics_t, &
       fmr_aggregate_diagnostics_t, FMR_BACKEND_SERIALIZED_REFERENCE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, fmr_b110_physical_parameters_t, &
       fmr_b110_physical_forcing_t, fmr_new_b110_committed_state
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t, &
       fmr_serialized_batch_diagnostics_t, fmr_run_serialized_physical_multiswap, FMR_SERIAL_DISPATCH_OK
  use mod_fmr04_fixed_top_provider, only: fmr04_fixed_flux_top_provider_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_irrigation_process, only: irrigation_parameters_t, irrigation_state_t, irrigation_management_request_t, &
       irrigation_flux_result_t, irrigation_diagnostics_t, fixed_irrigation_event_t, &
       evaluate_fixed_irrigation_interval, IRRIGATION_OK, IRRIGATION_APPLICATION_SSDI
  implicit none

  real(real64), parameter :: t0 = 1700.125_real64
  real(real64), parameter :: t1 = 1700.375_real64
  real(real64), parameter :: head0 = -75.0_real64
  real(real64), parameter :: hard_mass_gate = 1.0e-12_real64

  type(fmr_logical_column_t) :: columns(1)
  type(fmr_template_t) :: templates(1)
  type(fmr_b110_physical_parameters_t) :: parameters(1)
  type(fmr_b110_physical_forcing_t) :: control_forcing(1), irrigation_forcing(1)
  type(fmr_b110_physical_state_t) :: initial_state
  type(kernel_committed_state_t) :: control_state(1), irrigation_state_runtime(1)
  type(fmr_serialized_column_result_t), allocatable :: control_result(:), irrigation_result(:)
  type(fmr_column_diagnostics_t), allocatable :: control_diag(:), irrigation_diag_runtime(:)
  type(fmr_aggregate_diagnostics_t) :: control_aggregate, irrigation_aggregate
  type(fmr_serialized_batch_diagnostics_t) :: control_run, irrigation_run
  type(fmr04_fixed_flux_top_provider_t), target :: top_provider
  type(canonical_numerical_config_t) :: config
  type(irrigation_parameters_t) :: ip
  type(irrigation_state_t) :: process_committed, process_candidate
  type(irrigation_management_request_t) :: request
  type(irrigation_flux_result_t) :: flux
  type(irrigation_diagnostics_t) :: process_diag
  real(real64) :: conductivity0, delta_in, delta_out, tol, expected_in
  integer :: status_control, status_irrigation
  logical :: ok

  call configure_physics(parameters(1), initial_state, conductivity0)
  call configure_runtime_identity(columns(1), templates(1))
  call configure_numerics(config)
  call configure_control_forcing(control_forcing(1), conductivity0)

  ip%fixed_irrigation_enabled = .true.
  ip%active_nodes = numnod
  ip%ssdi_first_node = 1
  ip%ssdi_last_node = min(3,numnod)
  call require(ip%ssdi_last_node-ip%ssdi_first_node+1 == 3, 'fixture requires three admitted nodes')
  allocate(ip%fixed_events(1))
  ip%fixed_events(1) = fixed_irrigation_event_t(t0, IRRIGATION_APPLICATION_SSDI, &
       0.03125_real64, 0.125_real64, 123.0_real64)
  request%t0 = t0
  request%t1 = t1
  call evaluate_fixed_irrigation_interval(ip, process_committed, request, process_candidate, flux, process_diag)
  call require(process_diag%status == IRRIGATION_OK .and. flux%applied .and. flux%event_finished, 'process SSDI event')
  call require(allocated(flux%subsurface_source), 'process SSDI allocation')
  call require(all(flux%subsurface_source(1:3) == 0.125_real64), 'process per-node qssdi')
  call require(flux%concentration == 0.0_real64, 'SSDI does not publish surface concentration')
  expected_in = 3.0_real64 * 0.125_real64 * (t1-t0)
  call require(same_bits(expected_in,0.09375_real64), 'exact fixture inflow')
  call require(same_bits(flux%external_inflow_amount,expected_in), 'process reconciliation inflow')

  irrigation_forcing(1) = control_forcing(1)
  irrigation_forcing(1)%subsurface_irrigation_source = flux%subsurface_source
  irrigation_forcing(1)%drainage_flux_by_level = 0.0_real64
  irrigation_forcing(1)%drainage_flux_by_level(1,:) = flux%subsurface_source

  call fmr_new_b110_committed_state(control_state(1), columns(1)%column_id, initial_state, t0, ok)
  call require(ok, 'control initial state')
  call fmr_new_b110_committed_state(irrigation_state_runtime(1), columns(1)%column_id, initial_state, t0, ok)
  call require(ok, 'irrigation initial state')

  call reset_legacy_globals()
  call fmr_run_serialized_physical_multiswap(columns, templates, parameters, control_forcing, control_state, config, &
       top_provider, t0, t1, 1, control_result, control_diag, control_aggregate, status_control, control_run)
  call reset_legacy_globals()
  call fmr_run_serialized_physical_multiswap(columns, templates, parameters, irrigation_forcing, irrigation_state_runtime, &
       config, top_provider, t0, t1, 1, irrigation_result, irrigation_diag_runtime, irrigation_aggregate, &
       status_irrigation, irrigation_run)

  call require(status_control == FMR_SERIAL_DISPATCH_OK .and. status_irrigation == FMR_SERIAL_DISPATCH_OK, 'dispatch')
  call require(control_result(1)%completed .and. control_result(1)%committed, 'control committed')
  call require(irrigation_result(1)%completed .and. irrigation_result(1)%committed, 'irrigation committed')
  call require(control_result(1)%mass%complete .and. irrigation_result(1)%mass%complete, 'mass complete')
  call require(control_result(1)%mass%missing_contribution_mask == TX_MASS_MISSING_NONE .and. &
       irrigation_result(1)%mass%missing_contribution_mask == TX_MASS_MISSING_NONE, 'mass contribution mask')
  call require(abs(control_result(1)%mass%residual) <= hard_mass_gate .and. &
       abs(irrigation_result(1)%mass%residual) <= hard_mass_gate, 'hard mass residual')
  call require(control_run%max_simultaneous_real_physical_solves == 1 .and. &
       irrigation_run%max_simultaneous_real_physical_solves == 1, 'serialized real physics')
  call require(committed_physics_identical(control_state(1),irrigation_state_runtime(1)), 'balanced source/sink state identity')

  delta_in = irrigation_result(1)%mass%total_in - control_result(1)%mass%total_in
  delta_out = irrigation_result(1)%mass%total_out - control_result(1)%mass%total_out
  tol = 128.0_real64 * epsilon(1.0_real64) * max(1.0_real64,abs(expected_in))
  call require(abs(delta_in-expected_in) <= tol, 'authoritative total_in owns SSDI exactly once')
  call require(abs(delta_out-expected_in) <= tol, 'balancing drain isolates physics')
  call require(abs(irrigation_run%authoritative_aggregate_mass%total_in-irrigation_result(1)%mass%total_in) <= tol, &
       'aggregate authoritative total_in')
  call require(abs(irrigation_run%authoritative_aggregate_mass%residual) <= hard_mass_gate, 'aggregate mass residual')
  call require(irrigation_result(1)%mass%accepted_transaction_count == control_result(1)%mass%accepted_transaction_count, &
       'irrigation does not create duplicate accepted transaction accounting')

  write(*,'(A,1X,ES24.16)') 'FVQ18_SSDI_EXPECTED_IN=', expected_in
  write(*,'(A,1X,ES24.16)') 'FVQ18_SSDI_AUTHORITATIVE_IN_DELTA=', delta_in
  write(*,'(A)') 'FVQ18_SSDI_AUTHORITATIVE_EXACTLY_ONCE=PASS'
  write(*,'(A)') 'FVQ18_SSDI_BALANCED_RICHARDS_IDENTITY=PASS'
  write(*,'(A)') 'FVQ18_SSDI_MASS_COMPLETE=PASS'
  write(*,'(A)') 'FVQ18_SSDI_INDEPENDENT_MASS_VERIFIER PASS'

contains

  subroutine configure_runtime_identity(column, template)
    type(fmr_logical_column_t), intent(out) :: column
    type(fmr_template_t), intent(out) :: template
    template%template_id = 718_int64
    template%physics_topology_id = 71801_int64
    template%vertical_layout_id = 71802_int64
    template%state_layout_id = 71803_int64
    template%solver_interface_id = 71804_int64
    template%optional_state_layout_id = 71805_int64
    template%compatible_backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
    column%column_id = 718001_int64
    column%template_id = template%template_id
    column%parameter_ref = 1_int64
    column%state_handle = 1_int64
    column%forcing_handle = 1_int64
    column%backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine configure_runtime_identity

  subroutine configure_physics(p,state,conductivity0)
    type(fmr_b110_physical_parameters_t), intent(out) :: p
    type(fmr_b110_physical_state_t), intent(out) :: state
    real(real64), intent(out) :: conductivity0
    type(b110_default_mvg_parameters_t), target :: hyd_parameters
    type(b110_default_mvg_provider_t) :: constitutive
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
    integer :: k

    p%parameter_set_id = 71801_int64
    p%active_nodes = numnod
    allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod),p%cofgen(24,numnod))
    p%z = z
    p%dz = dz
    p%node_distance = disnod(1:numnod)
    p%cofgen = 0.0_real64
    do k=1,numnod
      p%cofgen(1,k)=0.032_real64; p%cofgen(2,k)=0.423_real64; p%cofgen(3,k)=4.75_real64
      p%cofgen(4,k)=0.0135_real64; p%cofgen(5,k)=0.365_real64; p%cofgen(6,k)=1.455_real64
      p%cofgen(7,k)=1.0_real64-1.0_real64/p%cofgen(6,k); p%cofgen(8,k)=p%cofgen(4,k)
      p%cofgen(9,k)=0.0_real64; p%cofgen(10,k)=p%cofgen(3,k); p%cofgen(11,k)=0.999_real64
      p%cofgen(12,k)=0.99_real64*p%cofgen(3,k); p%cofgen(22,k)=-1.0e6_real64; p%cofgen(23,k)=1.0e-12_real64
    end do
    p%bottom_mode=7; p%swkimpl=0; p%swkmean=1; p%swsophy=0
    p%root_extraction_active=.false.; p%macropore_active=.false.; p%snow_active=.false.
    p%hysteresis_active=.false.; p%tabulated_hydraulics_active=.false.; p%elasticity_active=.false.; p%frost_active=.false.

    call initialize_b110_default_mvg_parameters(hyd_parameters,p%cofgen)
    call bind_b110_default_mvg_provider(constitutive,hyd_parameters,t1-t0)
    heads = head0
    call constitutive%evaluate(heads,water,conductivity,capacity,dkdh)
    conductivity0 = conductivity(1)
    state%active_nodes = numnod
    allocate(state%pressure_head(numnod),state%water_content(numnod))
    state%pressure_head = heads
    state%water_content = water
    state%ponding_depth = 0.0_real64
    state%groundwater_level = -2.0_real64
  end subroutine configure_physics

  subroutine configure_control_forcing(f,conductivity0)
    type(fmr_b110_physical_forcing_t), intent(out) :: f
    real(real64), intent(in) :: conductivity0
    f%top_flux = -conductivity0
    f%top_head = head0
    f%bottom_flux = -conductivity0
    f%bottom_head = -100.0_real64
    allocate(f%drainage_flux_by_level(1,numnod),f%subsurface_irrigation_source(numnod),f%root_extraction_sink(numnod))
    f%drainage_flux_by_level = 0.0_real64
    f%subsurface_irrigation_source = 0.0_real64
    f%root_extraction_sink = 0.0_real64
  end subroutine configure_control_forcing

  subroutine configure_numerics(cfg)
    type(canonical_numerical_config_t), intent(out) :: cfg
    cfg%transaction%temporal_tolerance = 0.0_real64
    cfg%transaction%mass_tolerance = hard_mass_gate
    cfg%transaction%retry_scale = 0.5_real64
    cfg%transaction%max_retries = 2
    cfg%max_committed_substeps = 8
    cfg%progress_tolerance = 0.0_real64
  end subroutine configure_numerics

  subroutine reset_legacy_globals()
    legacy_qdra = 22222.0_real64
    legacy_qssdi = -33333.0_real64
    legacy_qrot = 0.0_real64
    swmacro = 0
    legacy_melt = 0.0_real64
  end subroutine reset_legacy_globals

  logical function committed_physics_identical(a,b)
    type(kernel_committed_state_t), intent(in) :: a,b
    class(transaction_state_t), allocatable :: sa,sb
    logical :: oka,okb
    integer :: i
    committed_physics_identical = .false.
    call a%snapshot(sa,oka)
    call b%snapshot(sb,okb)
    if (.not. oka .or. .not. okb) return
    select type (pa=>sa)
    type is (fmr_b110_physical_state_t)
      select type (pb=>sb)
      type is (fmr_b110_physical_state_t)
        if (pa%active_nodes /= pb%active_nodes) return
        if (.not. allocated(pa%pressure_head) .or. .not. allocated(pb%pressure_head)) return
        if (.not. allocated(pa%water_content) .or. .not. allocated(pb%water_content)) return
        do i=1,pa%active_nodes
          if (.not. same_bits(pa%pressure_head(i),pb%pressure_head(i))) return
          if (.not. same_bits(pa%water_content(i),pb%water_content(i))) return
        end do
        if (.not. same_bits(pa%ponding_depth,pb%ponding_depth)) return
        if (.not. same_bits(pa%groundwater_level,pb%groundwater_level)) return
        committed_physics_identical = .true.
      end select
    end select
  end function committed_physics_identical

  logical function same_bits(a,b)
    real(real64), intent(in) :: a,b
    integer(int64) :: ia,ib
    ia=transfer(a,ia)
    ib=transfer(b,ib)
    same_bits=ia==ib
  end function same_bits

  subroutine require(condition,label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'FVQ18_SSDI_MASS_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require

end program test_fvq18_ssdi_mass

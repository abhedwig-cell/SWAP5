program test_fvq20_scheduled_ssdi_runtime_mass
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
  use mod_fmr_process_hydraulic_view_binding, only: fmr_build_committed_process_hydraulic_view
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_fmr04_fixed_top_provider, only: fmr04_fixed_flux_top_provider_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_irrigation_process, only: scheduled_irrigation_parameters_t, scheduled_irrigation_request_t, &
       irrigation_state_t, irrigation_flux_result_t, irrigation_diagnostics_t, &
       evaluate_scheduled_irrigation_interval, IRRIGATION_OK, IRRIGATION_EVENT_SCHEDULED
  implicit none

  real(real64), parameter :: t0 = 2600.375_real64
  real(real64), parameter :: expected_depth = 0.12_real64
  real(real64), parameter :: expected_rate = 0.48_real64
  real(real64), parameter :: expected_duration = expected_depth / expected_rate
  real(real64), parameter :: t1 = t0 + expected_duration
  real(real64), parameter :: head0 = -75.0_real64
  real(real64), parameter :: hard_mass_gate = 1.0e-12_real64

  type(fmr_logical_column_t) :: columns(1)
  type(fmr_template_t) :: templates(1)
  type(fmr_b110_physical_parameters_t) :: parameters(1)
  type(fmr_b110_physical_forcing_t) :: forcing_control(1), forcing_irrigation(1)
  type(fmr_b110_physical_state_t) :: initial_state
  type(kernel_committed_state_t) :: states_control(1), states_irrigation(1)
  type(fmr_serialized_column_result_t), allocatable :: result_control(:), result_irrigation(:)
  type(fmr_column_diagnostics_t), allocatable :: diag_control(:), diag_irrigation(:)
  type(fmr_aggregate_diagnostics_t) :: aggregate_control, aggregate_irrigation
  type(fmr_serialized_batch_diagnostics_t) :: run_control, run_irrigation
  type(fmr04_fixed_flux_top_provider_t), target :: top_provider
  type(canonical_numerical_config_t) :: config
  type(process_hydraulic_view_t) :: hydraulic_view
  type(scheduled_irrigation_parameters_t) :: irrigation_parameters
  type(scheduled_irrigation_request_t) :: irrigation_request
  type(irrigation_state_t) :: irrigation_committed, irrigation_candidate
  type(irrigation_flux_result_t) :: irrigation_flux
  type(irrigation_diagnostics_t) :: irrigation_diag
  real(real64) :: conductivity0, total_in_delta, total_out_delta, tolerance
  integer :: dispatch_control, dispatch_irrigation
  logical :: ok

  call configure_physical_parameters(parameters(1), initial_state, conductivity0)
  call configure_column(columns(1), templates(1))
  call configure_transaction(config)
  call configure_control_forcing(forcing_control(1), conductivity0)

  call fmr_new_b110_committed_state(states_control(1), columns(1)%column_id, initial_state, t0, ok)
  call require(ok, 'control committed init')
  call fmr_new_b110_committed_state(states_irrigation(1), columns(1)%column_id, initial_state, t0, ok)
  call require(ok, 'irrigation committed init')

  call fmr_build_committed_process_hydraulic_view(states_irrigation(1), hydraulic_view, ok)
  call require(ok, 'committed F-MR07 hydraulic view')
  call require(hydraulic_view%active_nodes == numnod, 'committed view active nodes')
  call require(same_bits(hydraulic_view%pressure_head(2),head0), 'committed view pressure head identity')

  irrigation_parameters%scheduled_irrigation_enabled = .true.
  irrigation_parameters%active_nodes = numnod
  irrigation_parameters%sensor_node = 2
  irrigation_parameters%single_ssdi_node = 3
  ! 0.2 mm/h * 0.1 cm/mm * 24 h/d = 0.48 cm/d.
  irrigation_parameters%irr_rate_cm_per_day = expected_rate
  irrigation_parameters%tcs7_knot_count = 2
  irrigation_parameters%tcs7_dvs(1:2) = [0.0_real64, 2.0_real64]
  irrigation_parameters%tcs7_pressure_head(1:2) = [-70.0_real64, -70.0_real64]
  irrigation_parameters%dcs2_knot_count = 2
  irrigation_parameters%dcs2_dvs(1:2) = [0.0_real64, 2.0_real64]
  ! Legacy FID=1.2 mm is translated before the process to 0.12 cm.
  irrigation_parameters%dcs2_depth_cm(1:2) = [expected_depth, expected_depth]

  irrigation_request%t0 = t0
  irrigation_request%t1 = t1
  irrigation_request%dvs = 1.0_real64
  irrigation_request%selection_opportunity = .true.
  irrigation_request%irrigation_enabled = .true.
  irrigation_request%schedule_enabled = .true.
  irrigation_request%crop_emerged = .true.
  irrigation_request%irrigation_window_open = .true.
  irrigation_request%fixed_event_already_selected = .false.

  call evaluate_scheduled_irrigation_interval(irrigation_parameters, irrigation_committed, irrigation_request, &
       hydraulic_view, irrigation_candidate, irrigation_flux, irrigation_diag)
  call require(irrigation_diag%status == IRRIGATION_OK .and. irrigation_diag%selection_evaluated .and. &
       irrigation_diag%triggered, 'scheduled selection from committed view')
  call require(irrigation_flux%applied .and. irrigation_flux%event_finished, 'scheduled full event')
  call require(irrigation_flux%event_origin == IRRIGATION_EVENT_SCHEDULED, 'scheduled event origin')
  call require(.not. irrigation_candidate%active_event, 'completed event leaves compact state clear')
  call require(allocated(irrigation_flux%subsurface_source), 'scheduled source allocated')
  call require(same_bits(irrigation_flux%subsurface_source(3),expected_rate), 'scheduled qssdi equals rate')
  call require(same_bits(irrigation_flux%external_inflow_amount,expected_depth), 'scheduled process full-event inflow')

  forcing_irrigation(1) = forcing_control(1)
  forcing_irrigation(1)%subsurface_irrigation_source = irrigation_flux%subsurface_source
  forcing_irrigation(1)%drainage_flux_by_level = 0.0_real64
  forcing_irrigation(1)%drainage_flux_by_level(1,:) = irrigation_flux%subsurface_source

  call reset_legacy_globals()
  call fmr_run_serialized_physical_multiswap(columns, templates, parameters, forcing_control, states_control, config, &
       top_provider, t0, t1, 1, result_control, diag_control, aggregate_control, dispatch_control, run_control)
  call reset_legacy_globals()
  call fmr_run_serialized_physical_multiswap(columns, templates, parameters, forcing_irrigation, states_irrigation, config, &
       top_provider, t0, t1, 1, result_irrigation, diag_irrigation, aggregate_irrigation, dispatch_irrigation, run_irrigation)

  call require(dispatch_control == FMR_SERIAL_DISPATCH_OK .and. dispatch_irrigation == FMR_SERIAL_DISPATCH_OK, &
       'runtime dispatch')
  call require(result_control(1)%completed .and. result_control(1)%committed .and. &
       result_irrigation(1)%completed .and. result_irrigation(1)%committed, 'runtime commit')
  call require(result_control(1)%mass%complete .and. result_irrigation(1)%mass%complete, 'runtime mass complete')
  call require(result_control(1)%mass%missing_contribution_mask == TX_MASS_MISSING_NONE .and. &
       result_irrigation(1)%mass%missing_contribution_mask == TX_MASS_MISSING_NONE, 'runtime mass mask')
  call require(abs(result_control(1)%mass%residual) <= hard_mass_gate .and. &
       abs(result_irrigation(1)%mass%residual) <= hard_mass_gate, 'runtime hard mass gate')
  call require(run_control%max_simultaneous_real_physical_solves == 1 .and. &
       run_irrigation%max_simultaneous_real_physical_solves == 1, 'serialized real solver')
  call require(committed_physics_identical(states_control(1),states_irrigation(1)), 'balanced source sink state identity')

  total_in_delta = result_irrigation(1)%mass%total_in - result_control(1)%mass%total_in
  total_out_delta = result_irrigation(1)%mass%total_out - result_control(1)%mass%total_out
  tolerance = 128.0_real64 * epsilon(1.0_real64) * max(1.0_real64,abs(expected_depth))
  call require(abs(total_in_delta-expected_depth) <= tolerance, 'authoritative total_in equals scheduled inflow exactly once')
  call require(abs(total_out_delta-expected_depth) <= tolerance, 'balancing drain isolates identical physics')
  call require(abs(run_irrigation%authoritative_aggregate_mass%total_in - &
       result_irrigation(1)%mass%total_in) <= tolerance, 'aggregate authoritative total_in')
  call require(abs(run_irrigation%authoritative_aggregate_mass%residual) <= hard_mass_gate, 'aggregate hard mass gate')

  write(*,'(A,1X,ES24.16)') 'FVQ20_SCHEDULED_PROCESS_INFLOW=', irrigation_flux%external_inflow_amount
  write(*,'(A,1X,ES24.16)') 'FVQ20_SCHEDULED_AUTHORITATIVE_TOTAL_IN_DELTA=', total_in_delta
  write(*,'(A)') 'FVQ20_COMMITTED_HYDRAULIC_VIEW_BINDING=PASS'
  write(*,'(A)') 'FVQ20_SCHEDULED_AUTHORITATIVE_MASS_EXACTLY_ONCE=PASS'
  write(*,'(A)') 'FVQ20_SCHEDULED_REAL_PHYSICS_STATE_IDENTITY=PASS'
  write(*,'(A)') 'FVQ20_SCHEDULED_SSDI_RUNTIME_MASS PASS'

contains

  subroutine configure_column(column, template)
    type(fmr_logical_column_t), intent(out) :: column
    type(fmr_template_t), intent(out) :: template
    template%template_id = 720_int64
    template%physics_topology_id = 72001_int64
    template%vertical_layout_id = 72002_int64
    template%state_layout_id = 72003_int64
    template%solver_interface_id = 72004_int64
    template%optional_state_layout_id = 72005_int64
    template%compatible_backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
    column%column_id = 720001_int64
    column%template_id = template%template_id
    column%parameter_ref = 1_int64
    column%state_handle = 1_int64
    column%forcing_handle = 1_int64
    column%backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine configure_column

  subroutine configure_physical_parameters(p,state,conductivity0)
    type(fmr_b110_physical_parameters_t), intent(out) :: p
    type(fmr_b110_physical_state_t), intent(out) :: state
    real(real64), intent(out) :: conductivity0
    type(b110_default_mvg_parameters_t), target :: hyd_parameters
    type(b110_default_mvg_provider_t) :: constitutive
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
    integer :: k

    p%parameter_set_id = 72001_int64
    p%active_nodes = numnod
    allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod),p%cofgen(24,numnod))
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
  end subroutine configure_physical_parameters

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

  subroutine configure_transaction(cfg)
    type(canonical_numerical_config_t), intent(out) :: cfg
    cfg%transaction%temporal_tolerance = 0.0_real64
    cfg%transaction%mass_tolerance = hard_mass_gate
    cfg%transaction%retry_scale = 0.5_real64
    cfg%transaction%max_retries = 2
    cfg%max_committed_substeps = 8
    cfg%progress_tolerance = 0.0_real64
  end subroutine configure_transaction

  subroutine reset_legacy_globals()
    legacy_qdra = 12345.0_real64
    legacy_qssdi = -54321.0_real64
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
        if (size(pa%pressure_head) /= size(pb%pressure_head) .or. size(pa%water_content) /= size(pb%water_content)) return
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
      write(*,'(A,1X,A)') 'FVQ20_SCHEDULED_RUNTIME_MASS_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require

end program test_fvq20_scheduled_ssdi_runtime_mass

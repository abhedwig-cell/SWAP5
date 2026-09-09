program test_fsi20_candidate_headnorm_fgc02_policy
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use MOD_swap_base, only: swmacro
  use MOD_snow, only: legacy_melt => melt
  use MOD_drain, only: legacy_qdra => qdra
  use MOD_irrigation, only: legacy_qssdi => qssdi
  use variables, only: legacy_qrot => qrot, legacy_swbotb => swbotb, legacy_hbot => hbot, legacy_qbot => qbot
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t, kernel_result_t, &
       kernel_candidate_state_t, kernel_diagnostics_t
  use mod_fmr_checkpoint_orchestrator, only: fmr_capture_checkpoint
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, FMR_BACKEND_SERIALIZED_REFERENCE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, fmr_b110_physical_parameters_t, &
       fmr_b110_physical_forcing_t, fmr_serialized_reference_backend_t, fmr_serialized_physical_observation_t, &
       fmr_new_b110_committed_state
  use mod_fmr04_fixed_top_provider, only: fmr04_fixed_flux_top_provider_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  implicit none

  real(real64), parameter :: t0 = 4100.125_real64
  real(real64), parameter :: t1 = 4100.375_real64
  real(real64), parameter :: initial_head_cm = -75.0_real64
  real(real64), parameter :: predictor_bottom_head_cm = -74.99_real64
  real(real64), parameter :: hard_mass_gate = 1.0e-12_real64
  integer, parameter :: ncases = 9
  real(real64), parameter :: temporal_tolerances(ncases) = [ &
       1.0e-3_real64, 3.0e-4_real64, 2.6e-4_real64, 2.5525e-4_real64, &
       2.55242948426825933e-4_real64, 2.5524e-4_real64, 2.5e-4_real64, &
       2.0e-4_real64, 1.0e-4_real64 ]

  integer :: icase

  do icase = 1, ncases
    call run_case(icase, temporal_tolerances(icase))
  end do
  write(*,'(A)') 'FSI20_HEADNORM_FGC02_POLICY_DRIVER PASS'

contains

  subroutine run_case(case_id, temporal_tolerance)
    integer, intent(in) :: case_id
    real(real64), intent(in) :: temporal_tolerance
    type(fmr_logical_column_t) :: column
    type(fmr_template_t) :: template
    type(fmr_b110_physical_parameters_t) :: parameters
    type(fmr_b110_physical_forcing_t) :: forcing
    type(fmr_b110_physical_state_t) :: initial_state
    type(kernel_committed_state_t) :: committed
    type(fmr_serialized_reference_backend_t) :: backend
    type(fmr04_fixed_flux_top_provider_t), target :: top_provider
    type(canonical_numerical_config_t) :: config
    type(kernel_checkpoint_t) :: checkpoint
    type(kernel_result_t) :: result
    type(kernel_candidate_state_t) :: candidate
    type(kernel_diagnostics_t) :: diagnostics
    type(fmr_serialized_physical_observation_t) :: observation
    real(real64) :: conductivity0
    integer(int64) :: revision0
    logical :: ok

    call configure_column(column, template)
    call configure_case(parameters, initial_state, forcing, conductivity0)
    call configure_transaction(config, temporal_tolerance)
    call fmr_new_b110_committed_state(committed, column%column_id + int(case_id,int64), initial_state, t0, ok)
    call require(ok, 'committed initialization')
    revision0 = committed%current_revision()
    call backend%initialize(top_provider)
    call fmr_capture_checkpoint(committed, checkpoint, ok)
    call require(ok, 'checkpoint capture')
    call poison_legacy_bottom_context()

    call backend%run_trial(column, template, parameters, committed, forcing, config, &
         t0, t1, checkpoint, result, candidate, diagnostics)
    observation = backend%observation()

    call require(committed%current_revision() == revision0, 'policy sweep trial cannot commit')
    call require(diagnostics%mass_rejections == 0, 'no mass rejection in candidate metric sweep')
    if (result%completed) then
      call require(candidate%ready(), 'completed result materializes candidate')
      call require(result%mass%complete, 'completed result has complete mass accounting')
      call require(abs(result%mass%residual) <= hard_mass_gate, 'completed result passes hard mass')
    else
      call require(.not. candidate%ready(), 'failed result cannot materialize candidate')
    end if

    write(*,'(A,I0,A,ES26.17E3,A,L1,A,I0,A,I0,A,I0,A,I0,A,I0,A,I0,A,L1,A,ES26.17E3)') &
         'FSI20_HEADNORM_POLICY_CASE=', case_id, ':TEMPORAL_TOL=', temporal_tolerance, &
         ':COMPLETED=', result%completed, ':ATTEMPTS=', diagnostics%attempts, ':RETRIES=', diagnostics%retries, &
         ':SOLVER_REJECTIONS=', diagnostics%solver_rejections, &
         ':TEMPORAL_REJECTIONS=', diagnostics%temporal_rejections, &
         ':MASS_REJECTIONS=', diagnostics%mass_rejections, &
         ':ACCEPTED_SUBSTEPS=', diagnostics%accepted_substeps, &
         ':CANDIDATE_READY=', candidate%ready(), ':LAST_QBOT=', observation%bottom_flux
  end subroutine run_case

  subroutine configure_column(c, templ)
    type(fmr_logical_column_t), intent(out) :: c
    type(fmr_template_t), intent(out) :: templ
    templ%template_id = 202020_int64
    templ%physics_topology_id = 2020201_int64
    templ%vertical_layout_id = 2020202_int64
    templ%state_layout_id = 2020203_int64
    templ%solver_interface_id = 2020204_int64
    templ%optional_state_layout_id = 2020205_int64
    templ%compatible_backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
    c%column_id = 20202001_int64
    c%template_id = templ%template_id
    c%parameter_ref = 1_int64
    c%state_handle = 1_int64
    c%forcing_handle = 1_int64
    c%backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine configure_column

  subroutine configure_case(p, state, forcing, conductivity_reference)
    type(fmr_b110_physical_parameters_t), intent(out) :: p
    type(fmr_b110_physical_state_t), intent(out) :: state
    type(fmr_b110_physical_forcing_t), intent(out) :: forcing
    real(real64), intent(out) :: conductivity_reference
    type(b110_default_mvg_parameters_t), target :: hyd_parameters
    type(b110_default_mvg_provider_t) :: constitutive
    real(real64) :: heads(numnod), conductivity(numnod), water(numnod), capacity(numnod), dkdh(numnod)
    integer :: k

    p%parameter_set_id = 2020201_int64
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
    p%max_iterations = 8
    p%max_backtracking = 4
    p%min_step_duration = 1.0e-6_real64
    p%compartment_balance_tolerance = hard_mass_gate
    p%total_balance_tolerance = hard_mass_gate
    p%head_abs_tolerance = hard_mass_gate
    p%head_rel_tolerance = hard_mass_gate
    p%ponding_tolerance = hard_mass_gate

    heads = initial_head_cm
    call initialize_b110_default_mvg_parameters(hyd_parameters, p%cofgen)
    call bind_b110_default_mvg_provider(constitutive, hyd_parameters, t1-t0)
    call constitutive%evaluate(heads, water, conductivity, capacity, dkdh)
    do k = 2, numnod
      call require(transfer(conductivity(k),0_int64) == transfer(conductivity(1),0_int64), &
           'uniform initial conductivity')
    end do
    conductivity_reference = conductivity(1)
    state%active_nodes = numnod
    allocate(state%pressure_head(numnod), state%water_content(numnod))
    state%pressure_head = heads
    state%water_content = water
    state%ponding_depth = 0.0_real64
    state%groundwater_level = -2.0_real64

    forcing%top_flux = -conductivity_reference
    forcing%top_head = initial_head_cm
    forcing%bottom_flux = 12345.678_real64
    forcing%bottom_head = predictor_bottom_head_cm
    allocate(forcing%drainage_flux_by_level(1,numnod), forcing%subsurface_irrigation_source(numnod), &
             forcing%root_extraction_sink(numnod))
    forcing%drainage_flux_by_level = 0.0_real64
    forcing%subsurface_irrigation_source = 0.0_real64
    forcing%root_extraction_sink = 0.0_real64
  end subroutine configure_case

  subroutine configure_transaction(cfg, temporal_tolerance)
    type(canonical_numerical_config_t), intent(out) :: cfg
    real(real64), intent(in) :: temporal_tolerance
    cfg%transaction%temporal_tolerance = temporal_tolerance
    cfg%transaction%mass_tolerance = hard_mass_gate
    cfg%transaction%retry_scale = 0.5_real64
    cfg%transaction%max_retries = 2
    cfg%max_committed_substeps = 8
    cfg%progress_tolerance = 0.0_real64
  end subroutine configure_transaction

  subroutine poison_legacy_bottom_context()
    swmacro = 0
    legacy_melt = 0.0_real64
    legacy_qdra = 24680.0_real64
    legacy_qssdi = -13579.0_real64
    legacy_qrot = 0.0_real64
    legacy_swbotb = 3
    legacy_hbot = 99999.0_real64
    legacy_qbot = -99999.0_real64
  end subroutine poison_legacy_bottom_context

  subroutine require(condition,label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'FSI20_HEADNORM_POLICY_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require
end program test_fsi20_candidate_headnorm_fgc02_policy

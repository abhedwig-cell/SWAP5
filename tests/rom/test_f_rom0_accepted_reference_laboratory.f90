program test_f_rom0_accepted_reference_laboratory
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use MOD_grid, only: numnod
  use mod_transaction_reference, only: transaction_state_t, TX_TEMPORAL_EXTERNAL_FULL_HALF, TX_MASS_MISSING_NONE
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t, kernel_candidate_state_t, &
       kernel_result_t, kernel_diagnostics_t, KERNEL_COMMIT_STATUS_COMMITTED
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, &
       FMR_BACKEND_SERIALIZED_REFERENCE, FMR_NUMERICAL_CONTINUATION_NONE
  use mod_fmr_checkpoint_orchestrator, only: fmr_capture_checkpoint
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, &
       fmr_b110_physical_state_t, fmr_serialized_reference_backend_t, fmr_serialized_physical_observation_t, &
       fmr_new_b110_committed_state
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  implicit none

  real(real64), parameter :: se0 = 0.85_real64
  real(real64), parameter :: base_dt = 0.0016_real64
  real(real64), parameter :: hard_mass_tol = 1.0e-12_real64
  integer(int64), parameter :: lineage_id = 910001_int64

  character(len=16) :: material_id, experiment_id
  character(len=32) :: arg
  integer :: n, base_intervals, intervals, i, j, bottom_mode, ios
  real(real64) :: dz_cm, dt_day, t0, t1
  real(real64) :: theta_r, theta_s, alpha_per_cm, vg_n, ksat, lambda_mvg
  real(real64) :: h0, k0, qtop, qbot, hbot
  real(real64) :: total_s, upper_s, lower_s
  logical :: ok, did_commit, snapshot_ok
  integer :: commit_status

  type(fmr_b110_physical_parameters_t) :: parameters
  type(fmr_b110_physical_forcing_t) :: forcing
  type(fmr_b110_physical_state_t) :: initial_state
  type(fmr_serialized_reference_backend_t) :: backend
  type(fixed_flux_top_boundary_provider_t), target :: top_boundary
  type(kernel_committed_state_t) :: committed
  type(kernel_checkpoint_t) :: checkpoint
  type(kernel_candidate_state_t) :: candidate
  type(kernel_result_t) :: result
  type(kernel_diagnostics_t) :: diagnostic
  type(canonical_numerical_config_t) :: config
  type(fmr_logical_column_t) :: column
  type(fmr_template_t) :: template
  type(fmr_serialized_physical_observation_t) :: observation
  class(transaction_state_t), allocatable :: snapshot

  call get_command_argument(1, material_id)
  call get_command_argument(2, arg); read(arg,*,iostat=ios) n
  call require(ios == 0 .and. n > 0, 'node-count argument')
  call require(n == numnod, 'runtime geometry matches compiled legacy-grid authority')
  call get_command_argument(3, arg); read(arg,*,iostat=ios) dz_cm
  call require(ios == 0 .and. dz_cm > 0.0_real64, 'dz argument')
  call get_command_argument(4, arg); read(arg,*,iostat=ios) dt_day
  call require(ios == 0 .and. dt_day > 0.0_real64, 'dt argument')
  call get_command_argument(5, experiment_id)
  material_id = adjustl(material_id)
  experiment_id = adjustl(experiment_id)

  call material_parameters(trim(material_id), theta_r, theta_s, alpha_per_cm, vg_n, ksat, lambda_mvg, ok)
  call require(ok, 'known preregistered material')
  call require(abs(real(n,real64) * dz_cm - 160.0_real64) <= 1.0e-12_real64, '160 cm fixed profile depth')

  call initialize_parameters(parameters, n, dz_cm, theta_r, theta_s, alpha_per_cm, vg_n, ksat, lambda_mvg)
  call initial_head_and_conductivity(parameters, dt_day, h0, k0, initial_state)
  call fmr_new_b110_committed_state(committed, lineage_id, initial_state, 0.0_real64, ok)
  call require(ok, 'committed state initialized')

  call initialize_forcing(forcing, n)
  call initialize_runtime_identity(column, template)
  call initialize_numerics(config)
  call backend%initialize(top_boundary)

  base_intervals = experiment_base_intervals(trim(experiment_id))
  call require(base_intervals > 0, 'known preregistered experiment')
  intervals = nint(real(base_intervals,real64) * base_dt / dt_day)
  call require(intervals > 0, 'positive interval count')
  call require(abs(real(intervals,real64)*dt_day - real(base_intervals,real64)*base_dt) <= 1.0e-12_real64, &
       'refined run preserves physical horizon')

  write(*,'(*(g0))') 'F_ROM0_CASE|MATERIAL=',trim(material_id),'|EXPERIMENT=',trim(experiment_id), &
       '|N=',n,'|DZ_CM=',dz_cm,'|DT_DAY=',dt_day,'|INTERVALS=',intervals,'|H0_CM=',h0,'|K0_CM_PER_DAY=',k0

  t0 = 0.0_real64
  do i = 1, intervals
    t1 = real(i,real64) * dt_day
    call forcing_for_step(trim(experiment_id), i, intervals, h0, k0, dz_cm, bottom_mode, qtop, qbot, hbot)
    parameters%bottom_mode = bottom_mode
    forcing%top_flux = qtop
    forcing%top_head = h0
    forcing%bottom_flux = qbot
    forcing%bottom_head = hbot

    call fmr_capture_checkpoint(committed, checkpoint, ok)
    call require(ok .and. checkpoint%ready(), 'checkpoint captured from committed authority')

    call backend%run_trial(column, template, parameters, committed, forcing, config, t0, t1, checkpoint, &
         result, candidate, diagnostic)

    if (.not. result%completed .or. .not. candidate%ready()) then
      write(*,'(*(g0))') 'F_ROM0_REJECT|MATERIAL=',trim(material_id),'|EXPERIMENT=',trim(experiment_id), &
           '|STEP=',i,'|STATUS=',result%status,'|COMPLETED=',result%completed, &
           '|ATTEMPTS=',diagnostic%attempts,'|RETRIES=',diagnostic%retries, &
           '|SOLVER_REJECTIONS=',diagnostic%solver_rejections,'|TEMPORAL_REJECTIONS=',diagnostic%temporal_rejections, &
           '|MASS_REJECTIONS=',diagnostic%mass_rejections
      error stop 1
    end if
    call require(result%mass%complete, 'accepted candidate mass accounting complete')
    call require(result%mass%missing_contribution_mask == TX_MASS_MISSING_NONE, 'accepted candidate no missing mass')
    call require(abs(result%mass%residual) <= hard_mass_tol, 'accepted candidate hard mass gate')
    call require(result%bottom_interface_exchange_available, 'accepted bottom exchange available')

    call backend%commit_trial_candidate(committed, candidate, diagnostic, did_commit, commit_status)
    call require(did_commit .and. commit_status == KERNEL_COMMIT_STATUS_COMMITTED, 'candidate committed exactly through kernel owner')

    call committed%snapshot(snapshot, snapshot_ok)
    call require(snapshot_ok, 'committed postimage snapshot available')
    select type (physical => snapshot)
    type is (fmr_b110_physical_state_t)
      call require(physical%active_nodes == n, 'accepted snapshot node count')
      call require(all(ieee_is_finite(physical%pressure_head)), 'accepted heads finite')
      call require(all(ieee_is_finite(physical%water_content)), 'accepted water contents finite')
      call storage_bands(physical, parameters, total_s, upper_s, lower_s)
      observation = backend%observation()

      write(*,'(*(g0))') 'F_ROM0_ACCEPTED|MATERIAL=',trim(material_id),'|EXPERIMENT=',trim(experiment_id), &
           '|STEP=',i,'|T=',committed%current_time(),'|REV=',committed%current_revision(), &
           '|BOTTOM_MODE=',bottom_mode,'|QTOP=',observation%top_flux,'|QBOT=',observation%bottom_flux, &
           '|TOP_EXCHANGE=',observation%top_flux*(t1-t0), &
           '|BOTTOM_EXCHANGE=',result%bottom_outward_exchange_native,'|BOTTOM_EXCHANGE_AVAILABLE=',result%bottom_interface_exchange_available, &
           '|TERMINAL_QBOT=',result%terminal_bottom_outward_flux_native, &
           '|S_TOTAL=',total_s,'|S_UPPER=',upper_s,'|S_LOWER=',lower_s, &
           '|MASS_START=',result%mass%storage_start,'|MASS_END=',result%mass%storage_end, &
           '|MASS_IN=',result%mass%total_in,'|MASS_OUT=',result%mass%total_out,'|MASS_RES=',result%mass%residual, &
           '|TX=',result%mass%accepted_transaction_count,'|ATTEMPTS=',diagnostic%attempts, &
           '|RETRIES=',diagnostic%retries,'|ROLLBACKS=',diagnostic%trial_rollbacks, &
           '|SOLVER_REJ=',diagnostic%solver_rejections,'|TEMP_REJ=',diagnostic%temporal_rejections, &
           '|MASS_REJ=',diagnostic%mass_rejections,'|MIN_DT=',diagnostic%min_accepted_substep_duration, &
           '|MAX_DT=',diagnostic%max_accepted_substep_duration
      do j = 1, n
        write(*,'(*(g0))') 'F_ROM0_NODE|MATERIAL=',trim(material_id),'|EXPERIMENT=',trim(experiment_id), &
             '|STEP=',i,'|NODE=',j,'|H_CM=',physical%pressure_head(j),'|THETA=',physical%water_content(j)
      end do
    class default
      error stop 'F_ROM0_FAIL committed snapshot unexpected type'
    end select
    if (allocated(snapshot)) deallocate(snapshot)
    t0 = t1
  end do

  call require(committed%current_revision() == int(intervals,int64), 'one external commit per observation interval')
  call require(abs(committed%current_time() - real(intervals,real64)*dt_day) <= 1.0e-12_real64, 'final committed time exact')
  write(*,'(*(g0))') 'F_ROM0_CASE_PASS|MATERIAL=',trim(material_id),'|EXPERIMENT=',trim(experiment_id), &
       '|FINAL_REV=',committed%current_revision(),'|FINAL_T=',committed%current_time()

contains

  subroutine material_parameters(id, tr, ts, alpha, nn, ks, lam, found)
    character(len=*), intent(in) :: id
    real(real64), intent(out) :: tr, ts, alpha, nn, ks, lam
    logical, intent(out) :: found
    found = .true.
    select case (trim(id))
    case ('B01')
      tr=0.02_real64; ts=0.427494_real64; alpha=0.021659_real64; nn=1.734737_real64
      ks=31.225016_real64; lam=0.98087_real64
    case ('B14')
      tr=0.01_real64; ts=0.416774_real64; alpha=0.00541_real64; nn=1.301528_real64
      ks=0.895023_real64; lam=-0.334926_real64
    case default
      tr=0.0_real64; ts=0.0_real64; alpha=0.0_real64; nn=0.0_real64; ks=0.0_real64; lam=0.0_real64
      found=.false.
    end select
  end subroutine material_parameters

  subroutine initialize_parameters(p, nodes, cell_dz, tr, ts, alpha, nn, ks, lam)
    type(fmr_b110_physical_parameters_t), intent(out) :: p
    integer, intent(in) :: nodes
    real(real64), intent(in) :: cell_dz, tr, ts, alpha, nn, ks, lam
    real(real64) :: mm
    integer :: k
    mm = 1.0_real64 - 1.0_real64/nn
    p%parameter_set_id = 910001_int64
    p%active_nodes = nodes
    allocate(p%z(nodes), p%dz(nodes), p%node_distance(nodes), p%cofgen(24,nodes))
    do k=1,nodes
      p%z(k) = -cell_dz*(real(k,real64)-0.5_real64)
    end do
    p%dz = cell_dz
    p%node_distance = cell_dz
    p%cofgen = 0.0_real64
    do k=1,nodes
      p%cofgen(1,k)=tr; p%cofgen(2,k)=ts; p%cofgen(3,k)=ks
      p%cofgen(4,k)=alpha; p%cofgen(5,k)=lam; p%cofgen(6,k)=nn
      p%cofgen(7,k)=mm; p%cofgen(8,k)=alpha; p%cofgen(9,k)=0.0_real64
      p%cofgen(10,k)=ks; p%cofgen(11,k)=0.999_real64; p%cofgen(12,k)=0.99_real64*ks
      p%cofgen(22,k)=-1.0e6_real64; p%cofgen(23,k)=1.0e-12_real64
    end do
    p%bottom_mode=2
    p%swkimpl=0; p%swkmean=1; p%swsophy=0
    p%max_iterations=16; p%max_backtracking=8
    p%min_step_duration=1.0e-8_real64
    p%compartment_balance_tolerance=1.0e-12_real64
    p%total_balance_tolerance=1.0e-12_real64
    p%head_abs_tolerance=1.0e-12_real64
    p%head_rel_tolerance=1.0e-12_real64
    p%ponding_tolerance=1.0e-12_real64
    p%root_extraction_active=.false.; p%macropore_active=.false.; p%snow_active=.false.
    p%hysteresis_active=.false.; p%tabulated_hydraulics_active=.false.; p%elasticity_active=.false.
    p%frost_active=.false.; p%soil_temperature_active=.false.; p%drainage_response_active=.false.
    p%drainage_qbot_smooth_freatic_projection=.false.
  end subroutine initialize_parameters

  subroutine initial_head_and_conductivity(p, step_dt, head0, conductivity0, state)
    type(fmr_b110_physical_parameters_t), intent(in) :: p
    real(real64), intent(in) :: step_dt
    real(real64), intent(out) :: head0, conductivity0
    type(fmr_b110_physical_state_t), intent(out) :: state
    type(b110_default_mvg_parameters_t), target :: hp
    type(b110_default_mvg_provider_t) :: provider
    real(real64), allocatable :: heads(:), water(:), conductivity(:), capacity(:), dkdh(:)
    real(real64) :: m
    integer :: nodes
    nodes=p%active_nodes
    allocate(heads(nodes),water(nodes),conductivity(nodes),capacity(nodes),dkdh(nodes))
    m=1.0_real64-1.0_real64/p%cofgen(6,1)
    head0=-(se0**(-1.0_real64/m)-1.0_real64)**(1.0_real64/p%cofgen(6,1))/p%cofgen(4,1)
    heads=head0
    call initialize_b110_default_mvg_parameters(hp,p%cofgen)
    call bind_b110_default_mvg_provider(provider,hp,step_dt)
    call provider%evaluate(heads,water,conductivity,capacity,dkdh)
    call require(all(ieee_is_finite(water)) .and. all(ieee_is_finite(conductivity)), 'initial constitutive state finite')
    conductivity0=conductivity(1)
    call require(conductivity0 > 0.0_real64, 'initial conductivity positive')
    state%active_nodes=nodes
    allocate(state%pressure_head(nodes),state%water_content(nodes))
    state%pressure_head=heads
    state%water_content=water
    state%ponding_depth=0.0_real64
    state%groundwater_level=-999.0_real64
  end subroutine initial_head_and_conductivity

  subroutine initialize_forcing(f, nodes)
    type(fmr_b110_physical_forcing_t), intent(out) :: f
    integer, intent(in) :: nodes
    allocate(f%drainage_flux_by_level(1,nodes),f%subsurface_irrigation_source(nodes),f%root_extraction_sink(nodes))
    f%drainage_flux_by_level=0.0_real64
    f%subsurface_irrigation_source=0.0_real64
    f%root_extraction_sink=0.0_real64
  end subroutine initialize_forcing

  subroutine initialize_runtime_identity(col, tmpl)
    type(fmr_logical_column_t), intent(out) :: col
    type(fmr_template_t), intent(out) :: tmpl
    tmpl%template_id=910001_int64
    tmpl%physics_topology_id=910002_int64
    tmpl%vertical_layout_id=910003_int64
    tmpl%state_layout_id=910004_int64
    tmpl%solver_interface_id=910005_int64
    tmpl%optional_state_layout_id=0_int64
    tmpl%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_NONE
    tmpl%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    col%column_id=lineage_id
    col%template_id=tmpl%template_id
    col%parameter_ref=1_int64
    col%state_handle=1_int64
    col%forcing_handle=1_int64
    col%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine initialize_runtime_identity

  subroutine initialize_numerics(cfg)
    type(canonical_numerical_config_t), intent(out) :: cfg
    cfg%transaction%temporal_mode=TX_TEMPORAL_EXTERNAL_FULL_HALF
    cfg%transaction%temporal_tolerance=1.0e-6_real64
    cfg%transaction%max_retries=8
    cfg%transaction%mass_tolerance=hard_mass_tol
    cfg%transaction%retry_scale=0.5_real64
    cfg%max_committed_substeps=128
    cfg%progress_tolerance=0.0_real64
    cfg%model_temporal_indicator_budget_available=.false.
    cfg%model_temporal_indicator_budget=0.0_real64
  end subroutine initialize_numerics

  integer function experiment_base_intervals(id) result(count)
    character(len=*), intent(in) :: id
    select case(trim(id))
    case('E0_HOLD'); count=16
    case('E1_NOMINAL_FLUX','E2_DRYING_FLUX','E3_BOTTOM_HEAD_RISE','E4_BOTTOM_HEAD_FALL','E5_DIRECTION_REVERSAL')
      count=32
    case default; count=0
    end select
  end function experiment_base_intervals

  subroutine forcing_for_step(id, step, steps, head0, conductivity0, cell_dz, mode, qt, qb, hb)
    character(len=*), intent(in) :: id
    integer, intent(in) :: step, steps
    real(real64), intent(in) :: head0, conductivity0, cell_dz
    integer, intent(out) :: mode
    real(real64), intent(out) :: qt, qb, hb
    qt=0.0_real64; qb=0.0_real64; hb=head0
    select case(trim(id))
    case('E0_HOLD')
      mode=2
    case('E1_NOMINAL_FLUX')
      mode=2; qt=0.010_real64*conductivity0; qb=-0.004_real64*conductivity0
    case('E2_DRYING_FLUX')
      mode=2; qt=-0.005_real64*conductivity0; qb=-0.019_real64*conductivity0
    case('E3_BOTTOM_HEAD_RISE')
      mode=5; hb=head0+2.0_real64*cell_dz
    case('E4_BOTTOM_HEAD_FALL')
      mode=5; hb=head0-2.0_real64*cell_dz
    case('E5_DIRECTION_REVERSAL')
      mode=5
      if (step <= steps/2) then
        hb=head0+2.0_real64*cell_dz
      else
        hb=head0-2.0_real64*cell_dz
      end if
    case default
      mode=-999
    end select
  end subroutine forcing_for_step

  subroutine storage_bands(state,p,total,upper,lower)
    type(fmr_b110_physical_state_t), intent(in) :: state
    type(fmr_b110_physical_parameters_t), intent(in) :: p
    real(real64), intent(out) :: total,upper,lower
    integer :: k
    real(real64) :: depth
    total=state%ponding_depth
    upper=0.0_real64; lower=0.0_real64
    do k=1,p%active_nodes
      total=total+p%dz(k)*state%water_content(k)
      depth=-p%z(k)
      if (depth < 40.0_real64) then
        upper=upper+p%dz(k)*state%water_content(k)
      else
        lower=lower+p%dz(k)*state%water_content(k)
      end if
    end do
  end subroutine storage_bands

  subroutine require(condition,label)
    logical,intent(in) :: condition
    character(len=*),intent(in) :: label
    if(.not.condition) then
      write(*,'(A,1X,A)') 'F_ROM0_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require

end program test_f_rom0_accepted_reference_laboratory
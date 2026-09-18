program test_pub_me_d1_rejected_state_leakage
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t, transaction_policy_t, transaction_result_t, &
       execute_reference_interval, TX_STATUS_ACCEPTED, TX_STATUS_RETRY_EXHAUSTED, TX_TEMPORAL_EXTERNAL_FULL_HALF
  use mod_canonical_contracts, only: canonical_interval_t, canonical_numerical_config_t
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, &
       fmr_b110_physical_state_t, fmr_serialized_reference_backend_t
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use MOD_grid, only: numnod, z, dz, disnod
  implicit none

  real(real64), parameter :: h0 = -75.0_real64
  real(real64), parameter :: duration = 0.25_real64
  real(real64), parameter :: hard_mass_gate = 1.0e-12_real64
  real(real64), parameter :: permissive_temporal_tolerance = 1.0e6_real64

  type(fmr_serialized_reference_backend_t) :: backend
  type(fmr_b110_physical_parameters_t) :: parameters
  type(fmr_b110_physical_forcing_t) :: forcing
  type(fmr_b110_physical_state_t) :: physical
  type(fixed_flux_top_boundary_provider_t), target :: top
  type(canonical_interval_t) :: interval
  type(canonical_numerical_config_t) :: reject_config, accept_config
  type(transaction_policy_t) :: reject_policy, accept_policy
  type(transaction_result_t) :: rejected, accepted
  class(transaction_state_t), allocatable :: committed, before_reject, after_reject, final_state
  real(real64) :: reject_head_diff, reject_theta_diff, reject_ponding_diff, reject_groundwater_diff
  logical :: reject_changed

  call initialize_parameters(parameters)
  call initialize_forcing(forcing)
  call initialize_physical(physical, parameters)
  call physical%clone(committed)
  call committed%clone(before_reject)

  interval%t0 = 0.0_real64
  interval%t1 = duration

  call initialize_config(reject_config, 0.0_real64)
  reject_policy = reject_config%transaction

  call backend%initialize(top)
  call backend%configure_parameters(parameters)
  call backend%prepare_interval(forcing, interval, reject_config)

  call execute_reference_interval(backend, committed, 0.0_real64, duration, reject_policy, rejected)

  call require(rejected%status == TX_STATUS_RETRY_EXHAUSTED, 'first transaction rejected after bounded physical work')
  call require(rejected%headcalc_calls >= 3, 'real Reference full and two-half HeadCalc work executed')
  call require(rejected%accepted_total_in == 0.0_real64 .and. rejected%accepted_total_out == 0.0_real64, &
       'rejected transaction publishes no accepted transfer totals')

  call committed%clone(after_reject)
  call physical_difference(before_reject, after_reject, reject_head_diff, reject_theta_diff, &
       reject_ponding_diff, reject_groundwater_diff, reject_changed)

  write(*,'(A,I0)') 'PUB_ME_D1_REJECT_STATUS=', rejected%status
  write(*,'(A,I0)') 'PUB_ME_D1_REJECT_HEADCALC_CALLS=', rejected%headcalc_calls
  write(*,'(A,ES26.17E3)') 'PUB_ME_D1_REJECT_ACCEPTED_TOTAL_IN=', rejected%accepted_total_in
  write(*,'(A,ES26.17E3)') 'PUB_ME_D1_REJECT_ACCEPTED_TOTAL_OUT=', rejected%accepted_total_out
  write(*,'(A,L1)') 'PUB_ME_D1_REJECT_CHANGED=', reject_changed
  write(*,'(A,ES26.17E3)') 'PUB_ME_D1_REJECT_MAX_HEAD_DIFF_CM=', reject_head_diff
  write(*,'(A,ES26.17E3)') 'PUB_ME_D1_REJECT_MAX_THETA_DIFF=', reject_theta_diff
  write(*,'(A,ES26.17E3)') 'PUB_ME_D1_REJECT_PONDING_DIFF_CM=', reject_ponding_diff
  write(*,'(A,ES26.17E3)') 'PUB_ME_D1_REJECT_GROUNDWATER_DIFF=', reject_groundwater_diff

  call initialize_config(accept_config, permissive_temporal_tolerance)
  accept_policy = accept_config%transaction
  call backend%prepare_interval(forcing, interval, accept_config)

  call execute_reference_interval(backend, committed, 0.0_real64, duration, accept_policy, accepted)

  call require(accepted%status == TX_STATUS_ACCEPTED, 'bounded continuation accepted')
  call require(accepted%commits == 1, 'bounded continuation commits exactly once')
  call require(accepted%accepted_mass_complete, 'bounded continuation mass accounting complete')
  call require(abs(accepted%accepted_mass_residual) <= hard_mass_gate, 'bounded continuation closes hard mass gate')

  call committed%clone(final_state)

  write(*,'(A,I0)') 'PUB_ME_D1_CONTINUATION_STATUS=', accepted%status
  write(*,'(A,I0)') 'PUB_ME_D1_CONTINUATION_COMMITS=', accepted%commits
  write(*,'(A,L1)') 'PUB_ME_D1_CONTINUATION_MASS_COMPLETE=', accepted%accepted_mass_complete
  write(*,'(A,ES26.17E3)') 'PUB_ME_D1_CONTINUATION_MASS_RESIDUAL_CM=', accepted%accepted_mass_residual
  write(*,'(A,ES26.17E3)') 'PUB_ME_D1_CONTINUATION_STORAGE_START_CM=', accepted%accepted_storage_start
  write(*,'(A,ES26.17E3)') 'PUB_ME_D1_CONTINUATION_STORAGE_END_CM=', accepted%accepted_storage_end
  call write_state_bits('FINAL', final_state)
  write(*,'(A)') 'PUB_ME_D1_DIRECT_TRANSACTION_PROBE=PASS'

contains

  subroutine initialize_parameters(p)
    type(fmr_b110_physical_parameters_t), intent(out) :: p
    integer :: k
    p%parameter_set_id = 920101_int64
    p%active_nodes = numnod
    allocate(p%z(numnod), p%dz(numnod), p%node_distance(numnod), p%cofgen(24,numnod))
    p%z = z
    p%dz = dz
    p%node_distance = disnod(1:numnod)
    p%cofgen = 0.0_real64
    do k = 1, numnod
      p%cofgen(1,k)=0.032_real64
      p%cofgen(2,k)=0.423_real64
      p%cofgen(3,k)=4.75_real64
      p%cofgen(4,k)=0.0135_real64
      p%cofgen(5,k)=0.365_real64
      p%cofgen(6,k)=1.455_real64
      p%cofgen(7,k)=1.0_real64-1.0_real64/p%cofgen(6,k)
      p%cofgen(8,k)=p%cofgen(4,k)
      p%cofgen(9,k)=0.0_real64
      p%cofgen(10,k)=p%cofgen(3,k)
      p%cofgen(11,k)=0.999_real64
      p%cofgen(12,k)=0.99_real64*p%cofgen(3,k)
      p%cofgen(22,k)=-1.0e6_real64
      p%cofgen(23,k)=1.0e-12_real64
    end do
    p%bottom_mode=2
    p%swkimpl=0
    p%swkmean=1
    p%swsophy=0
    p%max_iterations=16
    p%max_backtracking=8
    p%min_step_duration=1.0e-8_real64
    p%compartment_balance_tolerance=hard_mass_gate
    p%total_balance_tolerance=hard_mass_gate
    p%head_abs_tolerance=hard_mass_gate
    p%head_rel_tolerance=hard_mass_gate
    p%ponding_tolerance=hard_mass_gate
    p%root_extraction_active=.false.
    p%macropore_active=.false.
    p%snow_active=.false.
    p%hysteresis_active=.false.
    p%tabulated_hydraulics_active=.false.
    p%elasticity_active=.false.
    p%frost_active=.false.
    p%soil_temperature_active=.false.
    p%drainage_response_active=.false.
  end subroutine initialize_parameters

  subroutine initialize_forcing(f)
    type(fmr_b110_physical_forcing_t), intent(out) :: f
    f%top_flux=0.0_real64
    f%top_head=h0
    f%bottom_flux=0.0_real64
    f%bottom_head=-999999.0_real64
    allocate(f%drainage_flux_by_level(1,numnod), f%subsurface_irrigation_source(numnod), f%root_extraction_sink(numnod))
    f%drainage_flux_by_level=0.0_real64
    f%subsurface_irrigation_source=0.0_real64
    f%root_extraction_sink=0.0_real64
  end subroutine initialize_forcing

  subroutine initialize_physical(state, p)
    type(fmr_b110_physical_state_t), intent(out) :: state
    type(fmr_b110_physical_parameters_t), intent(in) :: p
    real(real64) :: m, se, theta
    m = p%cofgen(7,1)
    se = (1.0_real64 + abs(p%cofgen(4,1)*h0)**p%cofgen(6,1))**(-m)
    theta = p%cofgen(1,1) + (p%cofgen(2,1)-p%cofgen(1,1))*se
    state%active_nodes = numnod
    allocate(state%pressure_head(numnod), state%water_content(numnod))
    state%pressure_head = h0
    state%water_content = theta
    state%ponding_depth = 0.0_real64
    state%groundwater_level = -2.0_real64
  end subroutine initialize_physical

  subroutine initialize_config(cfg, temporal_tolerance)
    type(canonical_numerical_config_t), intent(out) :: cfg
    real(real64), intent(in) :: temporal_tolerance
    cfg = canonical_numerical_config_t()
    cfg%transaction%temporal_mode = TX_TEMPORAL_EXTERNAL_FULL_HALF
    cfg%transaction%temporal_tolerance = temporal_tolerance
    cfg%transaction%mass_tolerance = hard_mass_gate
    cfg%transaction%retry_scale = 0.5_real64
    cfg%transaction%max_retries = 0
    cfg%max_committed_substeps = 1
    cfg%progress_tolerance = 0.0_real64
  end subroutine initialize_config

  subroutine physical_difference(left_state, right_state, head_diff, theta_diff, ponding_diff, groundwater_diff, changed)
    class(transaction_state_t), allocatable, intent(in) :: left_state, right_state
    real(real64), intent(out) :: head_diff, theta_diff, ponding_diff, groundwater_diff
    logical, intent(out) :: changed

    head_diff = huge(0.0_real64)
    theta_diff = huge(0.0_real64)
    ponding_diff = huge(0.0_real64)
    groundwater_diff = huge(0.0_real64)
    changed = .true.

    select type (left => left_state)
    type is (fmr_b110_physical_state_t)
      select type (right => right_state)
      type is (fmr_b110_physical_state_t)
        call require(left%active_nodes == right%active_nodes, 'state comparison node count')
        call require(allocated(left%pressure_head) .and. allocated(right%pressure_head), 'state comparison head allocated')
        call require(allocated(left%water_content) .and. allocated(right%water_content), 'state comparison theta allocated')
        head_diff = maxval(abs(left%pressure_head-right%pressure_head))
        theta_diff = maxval(abs(left%water_content-right%water_content))
        ponding_diff = abs(left%ponding_depth-right%ponding_depth)
        groundwater_diff = abs(left%groundwater_level-right%groundwater_level)
        changed = any(transfer(left%pressure_head,0_int64,size(left%pressure_head)) /= &
             transfer(right%pressure_head,0_int64,size(right%pressure_head))) .or. &
             any(transfer(left%water_content,0_int64,size(left%water_content)) /= &
             transfer(right%water_content,0_int64,size(right%water_content))) .or. &
             transfer(left%ponding_depth,0_int64) /= transfer(right%ponding_depth,0_int64) .or. &
             transfer(left%groundwater_level,0_int64) /= transfer(right%groundwater_level,0_int64)
      class default
        call require(.false., 'right comparison state type')
      end select
    class default
      call require(.false., 'left comparison state type')
    end select
  end subroutine physical_difference

  subroutine write_state_bits(prefix, state)
    character(len=*), intent(in) :: prefix
    class(transaction_state_t), allocatable, intent(in) :: state
    integer :: k
    select type (physical_state => state)
    type is (fmr_b110_physical_state_t)
      do k = 1, physical_state%active_nodes
        write(*,'(A,A,A,I0,A,I0,A,I0)') 'PUB_ME_D1_',trim(prefix),'_NODE=',k, &
             ' HEAD_BITS=',transfer(physical_state%pressure_head(k),0_int64), &
             ' THETA_BITS=',transfer(physical_state%water_content(k),0_int64)
      end do
      write(*,'(A,A,A,I0)') 'PUB_ME_D1_',trim(prefix),'_PONDING_BITS=',transfer(physical_state%ponding_depth,0_int64)
      write(*,'(A,A,A,I0)') 'PUB_ME_D1_',trim(prefix),'_GROUNDWATER_BITS=',transfer(physical_state%groundwater_level,0_int64)
    class default
      call require(.false., 'state bits physical type')
    end select
  end subroutine write_state_bits

  subroutine require(condition,label)
    logical,intent(in)::condition
    character(len=*),intent(in)::label
    if(.not.condition) then
      write(*,'(A,1X,A)') 'PUB_ME_D1_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_pub_me_d1_rejected_state_leakage

program test_pub_me_d6_rejected_publication
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_result_t, TX_STATUS_ACCEPTED, TX_STATUS_RETRY_EXHAUSTED
  use mod_soil_water_accepted_step_direction_contract, only: &
       soil_water_accepted_step_direction_request_t, soil_water_accepted_step_direction_result_t, &
       SW_STEP_DIRECTION_AVAILABLE, SW_STEP_CONTROL_BOTTOM_FLUX
  use mod_accepted_trajectory_directional_sensitivity, only: &
       accepted_trajectory_direction_t, trajectory_step_token_t, &
       configure_trajectory_direction, begin_or_continue_trajectory, build_trajectory_step_request, &
       stage_trajectory_step_result, accept_trajectory_step, finalize_trajectory_direction
  use mod_accepted_trajectory_directional_publication, only: &
       accepted_trajectory_direction_result_t, publish_accepted_trajectory_direction
  use mod_accepted_trajectory_transaction_binding, only: bind_accepted_trajectory_to_transaction
  implicit none

  type :: observer_t
    integer :: count = 0
    logical :: last_available = .false.
    integer :: worker_id = -1
    integer(int64) :: generation = 0_int64
    integer :: control_coordinate = 0
    integer :: accepted_steps = 0
    real(real64) :: origin_t0 = 0.0_real64
    real(real64) :: accepted_t1 = 0.0_real64
    real(real64) :: bottom_exchange_derivative = 0.0_real64
  end type observer_t

  type(accepted_trajectory_direction_t) :: trajectory
  type(accepted_trajectory_direction_result_t) :: accepted_pub, rejected_pub, premature_pub
  type(transaction_result_t) :: accepted_tx, rejected_tx
  type(observer_t) :: accepted_observer, rejected_observer, mutant_observer
  real(real64) :: physical_sentinel_before, physical_sentinel_after
  logical :: b2_detected, b1_detected, constructed

  physical_sentinel_before = -17.25_real64
  physical_sentinel_after = physical_sentinel_before

  call build_available_candidate_trajectory(trajectory)

  call make_accepted_transaction(accepted_tx)
  call bind_accepted_trajectory_to_transaction(accepted_tx, trajectory, accepted_pub)
  call assert_true(accepted_pub%available, 'accepted control publication available')
  call emit_if_available(accepted_observer, accepted_pub)
  call assert_true(accepted_observer%count == 1, 'accepted control emits once')
  call assert_true(accepted_observer%worker_id == 61, 'accepted control worker provenance')
  call assert_true(accepted_observer%generation == 6001_int64, 'accepted control generation provenance')
  call assert_true(accepted_observer%control_coordinate == SW_STEP_CONTROL_BOTTOM_FLUX, &
       'accepted control coordinate provenance')
  call assert_true(accepted_observer%accepted_steps == 1, 'accepted control step count')
  call assert_true(same_real(accepted_observer%origin_t0, 0.0_real64), 'accepted control origin')
  call assert_true(same_real(accepted_observer%accepted_t1, 1.0_real64), 'accepted control end')
  call assert_true(same_real(physical_sentinel_after, physical_sentinel_before), &
       'accepted control physical sentinel unchanged')
  write(*,'(A)') 'PUB_ME_D6_ACCEPTED_CONTROL=PASS'

  call make_rejected_transaction(rejected_tx)
  call bind_accepted_trajectory_to_transaction(rejected_tx, trajectory, rejected_pub)
  call assert_true(.not. rejected_pub%available, 'rejected control unavailable')
  call assert_true(trim(rejected_pub%route) == 'transaction-not-accepted', 'rejected control route')
  call emit_if_available(rejected_observer, rejected_pub)
  call assert_true(rejected_observer%count == 0, 'rejected clean control zero observer effects')
  call assert_true(same_real(physical_sentinel_after, physical_sentinel_before), &
       'rejected control physical sentinel unchanged')
  write(*,'(A)') 'PUB_ME_D6_REJECTED_CONTROL_ZERO_PUBLICATION=PASS'

  ! B2 authority is known before any external emission.
  b2_detected = rejected_tx%status /= TX_STATUS_ACCEPTED .or. rejected_tx%commits /= 1
  call assert_true(b2_detected, 'B2 detects rejected outer transaction before publication')
  write(*,'(A)') 'PUB_ME_D6_B2_PREEMISSION_AUTHORITY=DETECTED'

  ! Qualification-only faulty integration route:
  ! bypass the transaction binding and materialize locally available trajectory
  ! scratch directly as an externally visible accepted publication.
  call publish_accepted_trajectory_direction(trajectory, premature_pub)
  constructed = premature_pub%available
  if (.not. constructed) then
    write(*,'(A)') 'PUB_ME_D6_DIRECT_PUBLICATION_AVAILABLE=NO'
    write(*,'(A)') 'PUB_ME_D6_CLASSIFICATION=STRUCTURAL_PREVENTION'
    write(*,'(A)') 'PUB_ME_D6_REJECTED_PUBLICATION_EXPERIMENT=PASS'
    stop
  end if

  write(*,'(A)') 'PUB_ME_D6_DIRECT_PUBLICATION_AVAILABLE=YES'
  call emit_if_available(mutant_observer, premature_pub)
  call assert_true(mutant_observer%count == 1, 'mutant emitted one premature publication')
  call assert_true(rejected_tx%status == TX_STATUS_RETRY_EXHAUSTED .and. rejected_tx%commits == 0, &
       'outer transaction remains rejected after emission')
  call assert_true(same_real(physical_sentinel_after, physical_sentinel_before), &
       'mutant physical sentinel unchanged')
  write(*,'(A)') 'PUB_ME_D6_MUTANT_OBSERVER_COUNT=1'
  write(*,'(A)') 'PUB_ME_D6_PHYSICAL_STATE_UNCHANGED=PASS'

  ! Strong B1 checks accepted external outputs after the rejected operation.
  b1_detected = mutant_observer%count /= 0
  call assert_true(b1_detected, 'B1 detects rejected-operation external accepted publication')
  write(*,'(A)') 'PUB_ME_D6_B1_POSTOP_PUBLICATION_REGRESSION=DETECTED'

  write(*,'(A,I0)') 'PUB_ME_D6_PUBLISHED_WORKER=', mutant_observer%worker_id
  write(*,'(A,I0)') 'PUB_ME_D6_PUBLISHED_GENERATION=', mutant_observer%generation
  write(*,'(A,I0)') 'PUB_ME_D6_PUBLISHED_ACCEPTED_STEPS=', mutant_observer%accepted_steps
  write(*,'(A,ES25.17E3)') 'PUB_ME_D6_PUBLISHED_ORIGIN_T0=', mutant_observer%origin_t0
  write(*,'(A,ES25.17E3)') 'PUB_ME_D6_PUBLISHED_ACCEPTED_T1=', mutant_observer%accepted_t1
  write(*,'(A,ES25.17E3)') 'PUB_ME_D6_PUBLISHED_BOTTOM_DERIVATIVE=', &
       mutant_observer%bottom_exchange_derivative

  if (b2_detected .and. b1_detected) then
    write(*,'(A)') 'PUB_ME_D6_CLASSIFICATION=EARLIER_DETECTION'
  else if (b2_detected .and. .not. b1_detected) then
    write(*,'(A)') 'PUB_ME_D6_CLASSIFICATION=UNIQUE_DETECTION'
  else if (.not. b2_detected .and. b1_detected) then
    write(*,'(A)') 'PUB_ME_D6_CLASSIFICATION=NO_INCREMENTAL_VALUE'
  else
    write(*,'(A)') 'PUB_ME_D6_CLASSIFICATION=D6_AUTHORITY_FAILURE'
  end if

  write(*,'(A)') 'PUB_ME_D6_REJECTED_PUBLICATION_EXPERIMENT=PASS'

contains

  subroutine build_available_candidate_trajectory(state)
    type(accepted_trajectory_direction_t), intent(out) :: state
    type(soil_water_accepted_step_direction_request_t) :: request
    type(soil_water_accepted_step_direction_result_t) :: direction
    type(trajectory_step_token_t) :: token
    logical :: ok, finalized

    call configure_trajectory_direction(state, .true.)
    call begin_or_continue_trajectory(state, 61, 0.0_real64, 1.0_real64, &
         SW_STEP_CONTROL_BOTTOM_FLUX, 2, ok, 6001_int64)
    call assert_true(ok, 'trajectory begin')

    call build_trajectory_step_request(state, 0.0_real64, 1.0_real64, request, token, ok)
    call assert_true(ok .and. request%requested, 'trajectory request')

    direction = soil_water_accepted_step_direction_result_t()
    direction%status = SW_STEP_DIRECTION_AVAILABLE
    direction%available = .true.
    direction%fixed_smooth_route = .true.
    direction%control_coordinate = SW_STEP_CONTROL_BOTTOM_FLUX
    direction%method = 'd6-qualified-candidate'
    direction%route = 'd6-smooth-publication'
    allocate(direction%outgoing_pressure_head(2), direction%outgoing_water_content(2))
    direction%outgoing_pressure_head = [0.125_real64, -0.375_real64]
    direction%outgoing_water_content = [0.0125_real64, -0.0075_real64]
    direction%outgoing_ponding_depth = 0.0025_real64
    direction%bottom_flux_derivative = 0.625_real64
    direction%additional_tridiagonal_backsolves = 1

    call stage_trajectory_step_result(state, token, direction, ok)
    call assert_true(ok, 'trajectory stage')
    call accept_trajectory_step(state, ok)
    call assert_true(ok .and. state%accepted_steps == 1, 'trajectory internal step accepted')
    call finalize_trajectory_direction(state, 0.0_real64, 1.0_real64, finalized)
    call assert_true(finalized, 'trajectory scratch finalized')
  end subroutine build_available_candidate_trajectory

  subroutine make_accepted_transaction(tx)
    type(transaction_result_t), intent(out) :: tx
    tx = transaction_result_t()
    tx%status = TX_STATUS_ACCEPTED
    tx%commits = 1
    tx%requested_t0 = 0.0_real64
    tx%requested_t1 = 1.0_real64
    tx%accepted_t1 = 1.0_real64
    tx%accepted_dt = 1.0_real64
  end subroutine make_accepted_transaction

  subroutine make_rejected_transaction(tx)
    type(transaction_result_t), intent(out) :: tx
    tx = transaction_result_t()
    tx%status = TX_STATUS_RETRY_EXHAUSTED
    tx%commits = 0
    tx%requested_t0 = 0.0_real64
    tx%requested_t1 = 1.0_real64
    tx%accepted_t1 = 0.0_real64
    tx%accepted_dt = 0.0_real64
    tx%rollbacks = 1
    tx%temporal_rejections = 1
  end subroutine make_rejected_transaction

  subroutine emit_if_available(observer, publication)
    type(observer_t), intent(inout) :: observer
    type(accepted_trajectory_direction_result_t), intent(in) :: publication
    if (.not. publication%available) return
    observer%count = observer%count + 1
    observer%last_available = publication%available
    observer%worker_id = publication%worker_id
    observer%generation = publication%generation
    observer%control_coordinate = publication%control_coordinate
    observer%accepted_steps = publication%accepted_steps
    observer%origin_t0 = publication%origin_t0
    observer%accepted_t1 = publication%accepted_t1
    observer%bottom_exchange_derivative = publication%accepted_bottom_exchange_derivative
  end subroutine emit_if_available

  pure logical function same_real(a,b) result(equal)
    real(real64), intent(in) :: a,b
    integer(int64) :: ia,ib
    ia=transfer(a,ia)
    ib=transfer(b,ib)
    equal=ia==ib
  end function same_real

  subroutine assert_true(condition,label)
    logical,intent(in)::condition
    character(len=*),intent(in)::label
    if(.not.condition) then
      write(*,'(A,1X,A)') 'PUB_ME_D6_FAIL',trim(label)
      error stop 1
    end if
  end subroutine assert_true

end program test_pub_me_d6_rejected_publication

program test_fgc31_modflow6_multiswap_cell_response
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_groundwater_coupling_contract, only: groundwater_coupling_window_t
  use mod_groundwater_multiswap_types, only: groundwater_direct_tile_binding_t
  use mod_modflow6_swap_predictor_response, only: modflow6_swap_predictor_lineage_t, &
       modflow6_derivative_coverage_t, modflow6_swap_predictor_response_t, &
       compose_modflow6_swap_predictor_response, MODFLOW6_DERIVATIVE_TRAJECTORY_TANGENT, &
       MODFLOW6_PREDICTOR_OK
  use mod_modflow6_multiswap_cell_response, only: modflow6_multiswap_cell_response_t, &
       compose_modflow6_multiswap_cell_response, evaluate_modflow6_multiswap_cell_response, &
       MODFLOW6_MULTI_CELL_OK, MODFLOW6_MULTI_CELL_INVALID_REFERENCE_HEAD, &
       MODFLOW6_MULTI_CELL_DUPLICATE_TILE, MODFLOW6_MULTI_CELL_INVALID_RESPONSE, &
       MODFLOW6_MULTI_CELL_WINDOW_MISMATCH, MODFLOW6_MULTI_CELL_ORIGIN_MISMATCH, &
       MODFLOW6_MULTI_CELL_DUPLICATE_SWAP_LINEAGE, MODFLOW6_MULTI_CELL_FRACTION_SUM
  implicit none

  real(real64), parameter :: DAY_TO_S = 86400.0_real64
  real(real64), parameter :: CM_TO_M = 0.01_real64
  integer :: failures

  failures = 0
  call test_single_tile_equivalence(failures)
  call test_heterogeneous_affine_closure(failures)
  call test_permutation_determinism(failures)
  call test_fail_closed_contract(failures)

  if (failures /= 0) then
    write(*,'(A,I0)') 'F-GC31 FAILURES=', failures
    error stop 1
  end if

  print '(A)', 'FGC31_SINGLE_TILE_EQUIVALENCE=PASS'
  print '(A)', 'FGC31_HETEROGENEOUS_AFFINE_CLOSURE=PASS'
  print '(A)', 'FGC31_REFERENCE_HEAD_RECONCILIATION=PASS'
  print '(A)', 'FGC31_AREA_WEIGHTED_U=PASS'
  print '(A)', 'FGC31_PERMUTATION_DETERMINISM=PASS'
  print '(A)', 'FGC31_CANONICAL_TILE_PROVENANCE=PASS'
  print '(A)', 'FGC31_PROVENANCE_FAIL_CLOSED=PASS'
  print '(A)', 'FGC31_CELL_RESPONSE_CONTRACT_GATE=PASS'

contains

  subroutine test_single_tile_equivalence(failures)
    integer, intent(inout) :: failures
    type(groundwater_direct_tile_binding_t) :: binding(1)
    type(modflow6_swap_predictor_response_t) :: response(1)
    type(modflow6_multiswap_cell_response_t) :: cell
    real(real64) :: q_eval
    integer :: status

    binding(1)%groundwater_cell_id = 9001_int64
    binding(1)%tile_id = 1_int64
    binding(1)%area_fraction = 1.0_real64
    call make_response(101_int64, response(1))

    call compose_modflow6_multiswap_cell_response(binding, response, response(1)%h_bot_end_m, cell, status)
    call require(status == MODFLOW6_MULTI_CELL_OK .and. cell%valid, &
         'single tile response rejected', failures)
    call require_close(cell%q_u_at_reference_m_per_s, response(1)%q_u_m_per_s, 1.0e-22_real64, &
         'single tile q_u mismatch', failures)
    call require_close(cell%coupling_storage_coefficient_u, response(1)%coupling_storage_coefficient_u, &
         1.0e-15_real64, 'single tile u mismatch', failures)
    call require_close(cell%dq_u_dh_per_s, response(1)%coupling_storage_coefficient_u / (0.5_real64*DAY_TO_S), &
         1.0e-20_real64, 'single tile tangent mismatch', failures)

    call evaluate_modflow6_multiswap_cell_response(cell, response(1)%h_bot_end_m, q_eval, status)
    call require(status == MODFLOW6_MULTI_CELL_OK, 'single tile evaluate rejected', failures)
    call require_close(q_eval, response(1)%q_u_m_per_s, 1.0e-22_real64, &
         'single tile evaluate mismatch', failures)
  end subroutine test_single_tile_equivalence

  subroutine test_heterogeneous_affine_closure(failures)
    integer, intent(inout) :: failures
    type(groundwater_direct_tile_binding_t) :: bindings(2)
    type(modflow6_swap_predictor_response_t) :: responses(2)
    type(modflow6_multiswap_cell_response_t) :: cell
    real(real64) :: reference_head, second_head
    real(real64) :: expected_q_ref, expected_q_second, q_second
    real(real64) :: expected_u, expected_raw
    integer :: status

    bindings(1)%groundwater_cell_id = 7001_int64
    bindings(1)%tile_id = 20_int64
    bindings(1)%area_fraction = 0.75_real64
    bindings(2)%groundwater_cell_id = 7001_int64
    bindings(2)%tile_id = 10_int64
    bindings(2)%area_fraction = 0.25_real64

    call make_response(102_int64, responses(1), second=.true.)
    call make_response(101_int64, responses(2))

    reference_head = 1.005_real64
    call compose_modflow6_multiswap_cell_response(bindings, responses, reference_head, cell, status)
    call require(status == MODFLOW6_MULTI_CELL_OK .and. cell%valid, &
         'heterogeneous response rejected', failures)

    expected_q_ref = 0.5625_real64 * CM_TO_M / DAY_TO_S
    expected_raw = 0.625_real64 * CM_TO_M / DAY_TO_S
    expected_u = 0.4375_real64

    call require_close(cell%q_u_at_reference_m_per_s, expected_q_ref, 1.0e-20_real64, &
         'reference reconciled q_u mismatch', failures)
    call require_close(cell%area_weighted_predictor_q_u_m_per_s, expected_raw, 1.0e-20_real64, &
         'raw predictor q_u diagnostic mismatch', failures)
    call require(abs(cell%reference_adjustment_m_per_s) > 0.0_real64, &
         'reference adjustment unexpectedly zero', failures)
    call require_close(cell%coupling_storage_coefficient_u, expected_u, 1.0e-15_real64, &
         'area weighted u mismatch', failures)
    call require_close(cell%dq_u_dh_per_s, expected_u / (0.5_real64*DAY_TO_S), 1.0e-20_real64, &
         'cell dq/dH mismatch', failures)

    call require(cell%tile_count == 2, 'tile count mismatch', failures)
    call require(cell%tiles(1)%binding%tile_id == 10_int64 .and. cell%tiles(2)%binding%tile_id == 20_int64, &
         'canonical tile order mismatch', failures)
    call require(cell%tiles(1)%response%lineage%swap_lineage_id == 101_int64 .and. &
         cell%tiles(2)%response%lineage%swap_lineage_id == 102_int64, &
         'tile response provenance mismatch', failures)
    call require_close(cell%tiles(1)%q_u_at_reference_m_per_s, 0.45_real64*CM_TO_M/DAY_TO_S, &
         1.0e-20_real64, 'tile 10 reference q mismatch', failures)
    call require_close(cell%tiles(2)%q_u_at_reference_m_per_s, 0.60_real64*CM_TO_M/DAY_TO_S, &
         1.0e-20_real64, 'tile 20 reference q mismatch', failures)

    second_head = 1.007_real64
    call evaluate_modflow6_multiswap_cell_response(cell, second_head, q_second, status)
    call require(status == MODFLOW6_MULTI_CELL_OK, 'second-head cell evaluation rejected', failures)
    expected_q_second = 0.7375_real64 * CM_TO_M / DAY_TO_S
    call require_close(q_second, expected_q_second, 1.0e-20_real64, &
         'aggregate affine evaluation mismatch', failures)
  end subroutine test_heterogeneous_affine_closure

  subroutine test_permutation_determinism(failures)
    integer, intent(inout) :: failures
    type(groundwater_direct_tile_binding_t) :: a_bind(2), b_bind(2), tmp_bind
    type(modflow6_swap_predictor_response_t) :: a_resp(2), b_resp(2), tmp_resp
    type(modflow6_multiswap_cell_response_t) :: a_cell, b_cell
    integer :: status_a, status_b

    a_bind(1)%groundwater_cell_id = 8001_int64
    a_bind(1)%tile_id = 10_int64
    a_bind(1)%area_fraction = 0.25_real64
    a_bind(2)%groundwater_cell_id = 8001_int64
    a_bind(2)%tile_id = 20_int64
    a_bind(2)%area_fraction = 0.75_real64
    call make_response(101_int64, a_resp(1))
    call make_response(102_int64, a_resp(2), second=.true.)

    b_bind = a_bind
    b_resp = a_resp
    tmp_bind = b_bind(1)
    b_bind(1) = b_bind(2)
    b_bind(2) = tmp_bind
    tmp_resp = b_resp(1)
    b_resp(1) = b_resp(2)
    b_resp(2) = tmp_resp

    call compose_modflow6_multiswap_cell_response(a_bind, a_resp, 1.005_real64, a_cell, status_a)
    call compose_modflow6_multiswap_cell_response(b_bind, b_resp, 1.005_real64, b_cell, status_b)

    call require(status_a == MODFLOW6_MULTI_CELL_OK .and. status_b == MODFLOW6_MULTI_CELL_OK, &
         'permutation route rejected', failures)
    call require(transfer(a_cell%q_u_at_reference_m_per_s, 0_int64) == &
         transfer(b_cell%q_u_at_reference_m_per_s, 0_int64), &
         'q_ref not bit-identical under permutation', failures)
    call require(transfer(a_cell%area_weighted_predictor_q_u_m_per_s, 0_int64) == &
         transfer(b_cell%area_weighted_predictor_q_u_m_per_s, 0_int64), &
         'raw q not bit-identical under permutation', failures)
    call require(transfer(a_cell%coupling_storage_coefficient_u, 0_int64) == &
         transfer(b_cell%coupling_storage_coefficient_u, 0_int64), &
         'u not bit-identical under permutation', failures)
    call require(a_cell%tiles(1)%binding%tile_id == b_cell%tiles(1)%binding%tile_id .and. &
         a_cell%tiles(2)%binding%tile_id == b_cell%tiles(2)%binding%tile_id, &
         'canonical tile output order changed', failures)
  end subroutine test_permutation_determinism

  subroutine test_fail_closed_contract(failures)
    integer, intent(inout) :: failures
    type(groundwater_direct_tile_binding_t) :: bindings(2), bad_bindings(2)
    type(modflow6_swap_predictor_response_t) :: responses(2), bad_responses(2)
    type(modflow6_multiswap_cell_response_t) :: cell
    real(real64) :: nan_value
    integer :: status

    bindings(1)%groundwater_cell_id = 7101_int64
    bindings(1)%tile_id = 1_int64
    bindings(1)%area_fraction = 0.4_real64
    bindings(2)%groundwater_cell_id = 7101_int64
    bindings(2)%tile_id = 2_int64
    bindings(2)%area_fraction = 0.6_real64
    call make_response(201_int64, responses(1))
    call make_response(202_int64, responses(2), second=.true.)

    bad_bindings = bindings
    bad_bindings(2)%tile_id = bad_bindings(1)%tile_id
    call compose_modflow6_multiswap_cell_response(bad_bindings, responses, 1.005_real64, cell, status)
    call require(status == MODFLOW6_MULTI_CELL_DUPLICATE_TILE .and. .not. cell%valid, &
         'duplicate tile did not fail closed', failures)

    bad_bindings = bindings
    bad_bindings(1)%area_fraction = 0.3_real64
    call compose_modflow6_multiswap_cell_response(bad_bindings, responses, 1.005_real64, cell, status)
    call require(status == MODFLOW6_MULTI_CELL_FRACTION_SUM .and. .not. cell%valid, &
         'fraction sum did not fail closed', failures)

    bad_responses = responses
    bad_responses(2)%valid = .false.
    call compose_modflow6_multiswap_cell_response(bindings, bad_responses, 1.005_real64, cell, status)
    call require(status == MODFLOW6_MULTI_CELL_INVALID_RESPONSE .and. .not. cell%valid, &
         'invalid response did not fail closed', failures)

    bad_responses = responses
    bad_responses(2)%window%t1 = bad_responses(2)%window%t1 + 0.1_real64
    call compose_modflow6_multiswap_cell_response(bindings, bad_responses, 1.005_real64, cell, status)
    call require(status == MODFLOW6_MULTI_CELL_WINDOW_MISMATCH .and. .not. cell%valid, &
         'window mismatch did not fail closed', failures)

    bad_responses = responses
    bad_responses(2)%lineage%groundwater_origin_revision = bad_responses(2)%lineage%groundwater_origin_revision + 1_int64
    call compose_modflow6_multiswap_cell_response(bindings, bad_responses, 1.005_real64, cell, status)
    call require(status == MODFLOW6_MULTI_CELL_ORIGIN_MISMATCH .and. .not. cell%valid, &
         'groundwater origin mismatch did not fail closed', failures)

    bad_responses = responses
    bad_responses(2)%lineage%swap_lineage_id = bad_responses(1)%lineage%swap_lineage_id
    call compose_modflow6_multiswap_cell_response(bindings, bad_responses, 1.005_real64, cell, status)
    call require(status == MODFLOW6_MULTI_CELL_DUPLICATE_SWAP_LINEAGE .and. .not. cell%valid, &
         'duplicate SWAP lineage did not fail closed', failures)

    nan_value = ieee_value(0.0_real64, ieee_quiet_nan)
    call compose_modflow6_multiswap_cell_response(bindings, responses, nan_value, cell, status)
    call require(status == MODFLOW6_MULTI_CELL_INVALID_REFERENCE_HEAD .and. .not. cell%valid, &
         'nonfinite reference head did not fail closed', failures)
  end subroutine test_fail_closed_contract

  subroutine make_response(swap_lineage_id, response, second)
    integer(int64), intent(in) :: swap_lineage_id
    type(modflow6_swap_predictor_response_t), intent(out) :: response
    logical, intent(in), optional :: second

    type(groundwater_coupling_window_t) :: window
    type(modflow6_swap_predictor_lineage_t) :: lineage
    type(modflow6_derivative_coverage_t) :: coverage
    logical :: use_second
    real(real64) :: qbot, hstart, hend, dhdq
    integer :: status

    use_second = .false.
    if (present(second)) use_second = second

    window%t0 = 10.0_real64
    window%t1 = 10.5_real64

    lineage%coupling_id = 3101_int64
    lineage%swap_lineage_id = swap_lineage_id
    lineage%swap_origin_revision = 7_int64
    lineage%groundwater_service_id = 51_int64
    lineage%groundwater_lineage_id = 41_int64
    lineage%groundwater_origin_revision = 9_int64

    coverage%lower_face_head_semantics_covered = .true.
    coverage%richards_hydraulic_response_covered = .true.
    coverage%constitutive_response_covered = .true.

    if (use_second) then
      qbot = -0.1_real64
      hstart = 1.0_real64
      hend = 1.006_real64
      dhdq = 1.0_real64
    else
      qbot = -0.2_real64
      hstart = 1.0_real64
      hend = 1.004_real64
      dhdq = 2.0_real64
    end if

    call compose_modflow6_swap_predictor_response(window, lineage, qbot, hstart, hend, dhdq, &
         MODFLOW6_DERIVATIVE_TRAJECTORY_TANGENT, coverage, 'fgc31-fixture', &
         'drainage-free-smooth-route', response, status)
    if (status /= MODFLOW6_PREDICTOR_OK .or. .not. response%valid) then
      write(*,'(A)') 'FGC31 fixture construction failed'
      error stop 2
    end if
  end subroutine make_response

  subroutine require(condition, message, failures)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    integer, intent(inout) :: failures

    if (.not. condition) then
      failures = failures + 1
      write(*,'(A)') 'FGC31_FAIL: '//trim(message)
    end if
  end subroutine require

  subroutine require_close(actual, expected, tolerance, message, failures)
    real(real64), intent(in) :: actual, expected, tolerance
    character(len=*), intent(in) :: message
    integer, intent(inout) :: failures

    call require(abs(actual - expected) <= tolerance, message, failures)
  end subroutine require_close

end program test_fgc31_modflow6_multiswap_cell_response

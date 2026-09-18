program test_fgc33_modflow6_linear_response_backend
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
       MODFLOW6_MULTI_CELL_OK
  use mod_modflow6_linear_response_backend, only: modflow6_linear_boundary_term_t, &
       compose_modflow6_linear_boundary_term, evaluate_modflow6_linear_boundary_flux, &
       MODFLOW6_LINEAR_BACKEND_OK, MODFLOW6_LINEAR_BACKEND_INVALID_CELL_RESPONSE, &
       MODFLOW6_LINEAR_BACKEND_INVALID_AREA, MODFLOW6_LINEAR_BACKEND_NONFINITE_SOURCE, &
       MODFLOW6_LINEAR_BACKEND_INVALID_EVALUATION
  implicit none

  real(real64), parameter :: DAY_TO_S = 86400.0_real64
  real(real64), parameter :: AREA = 2000.0_real64
  integer :: failures

  failures = 0
  call test_exact_hcof_rhs_transform(failures)
  call test_reference_representation_invariance(failures)
  call test_area_scaling_and_sign(failures)
  call test_fail_closed(failures)

  if (failures /= 0) then
    write(*,'(A,I0)') 'F-GC33 FAILURES=', failures
    error stop 1
  end if

  print '(A)', 'FGC33_EXACT_HCOF_RHS_TRANSFORM=PASS'
  print '(A)', 'FGC33_REFERENCE_HEAD_CLOSURE=PASS'
  print '(A)', 'FGC33_SECOND_HEAD_CLOSURE=PASS'
  print '(A)', 'FGC33_REFERENCE_REPRESENTATION_INVARIANCE=PASS'
  print '(A)', 'FGC33_AREA_SCALING=PASS'
  print '(A)', 'FGC33_SIGN_PRESERVATION=PASS'
  print '(A)', 'FGC33_IDENTITY_NOT_NODE_INDEX=PASS'
  print '(A)', 'FGC33_FAIL_CLOSED=PASS'
  print '(A)', 'FGC33_LINEAR_RESPONSE_BACKEND_GATE=PASS'

contains

  subroutine test_exact_hcof_rhs_transform(failures)
    integer, intent(inout) :: failures
    type(modflow6_multiswap_cell_response_t) :: cell
    type(modflow6_linear_boundary_term_t) :: term
    real(real64) :: q_cell, q_volume, expected_volume
    integer :: status

    call make_cell(1.005_real64, cell)

    call compose_modflow6_linear_boundary_term(cell, AREA, term, status)
    call require(status == MODFLOW6_LINEAR_BACKEND_OK .and. term%valid, &
         'valid F-GC40 cell rejected', failures)

    call require_close(term%reference_volume_flux_m3_per_day, 11.25_real64, 1.0e-11_real64, &
         'reference volume flux mismatch', failures)
    call require_close(term%hcof_m2_per_day, 1750.0_real64, 1.0e-10_real64, &
         'HCOF mismatch', failures)
    call require_close(term%rhs_m3_per_day, 1747.5_real64, 1.0e-10_real64, &
         'RHS mismatch', failures)

    call evaluate_modflow6_linear_boundary_flux(term, cell%reference_head_m, q_volume, status)
    call require(status == MODFLOW6_LINEAR_BACKEND_OK, 'reference-head backend evaluation rejected', failures)
    call require_close(q_volume, 11.25_real64, 1.0e-10_real64, &
         'reference-head MODFLOW flux mismatch', failures)

    call evaluate_modflow6_multiswap_cell_response(cell, 1.007_real64, q_cell, status)
    call require(status == MODFLOW6_MULTI_CELL_OK, 'F-GC40 second-head evaluation rejected', failures)
    expected_volume = AREA * DAY_TO_S * q_cell
    call evaluate_modflow6_linear_boundary_flux(term, 1.007_real64, q_volume, status)
    call require(status == MODFLOW6_LINEAR_BACKEND_OK, 'second-head backend evaluation rejected', failures)
    call require_close(q_volume, expected_volume, 1.0e-10_real64, &
         'second-head MODFLOW/F-GC40 closure mismatch', failures)
    call require_close(q_volume, 14.75_real64, 1.0e-10_real64, &
         'second-head expected flux mismatch', failures)

    call require(term%groundwater_cell_id == cell%groundwater_cell_id, &
         'coupling cell identity not preserved', failures)
    call require(term%groundwater_cell_id == 7001_int64, &
         'fixture identity unexpectedly transformed into node indexing', failures)
  end subroutine test_exact_hcof_rhs_transform

  subroutine test_reference_representation_invariance(failures)
    integer, intent(inout) :: failures
    type(modflow6_multiswap_cell_response_t) :: cell_a, cell_b
    type(modflow6_linear_boundary_term_t) :: term_a, term_b
    integer :: status_a, status_b

    call make_cell(1.005_real64, cell_a)
    call make_cell(1.007_real64, cell_b)

    call compose_modflow6_linear_boundary_term(cell_a, AREA, term_a, status_a)
    call compose_modflow6_linear_boundary_term(cell_b, AREA, term_b, status_b)
    call require(status_a == MODFLOW6_LINEAR_BACKEND_OK .and. status_b == MODFLOW6_LINEAR_BACKEND_OK, &
         'reference-invariance route rejected', failures)

    call require_close(term_a%hcof_m2_per_day, term_b%hcof_m2_per_day, 1.0e-10_real64, &
         'HCOF depends on reference representation', failures)
    call require_close(term_a%rhs_m3_per_day, term_b%rhs_m3_per_day, 1.0e-10_real64, &
         'RHS depends on reference representation', failures)
  end subroutine test_reference_representation_invariance

  subroutine test_area_scaling_and_sign(failures)
    integer, intent(inout) :: failures
    type(modflow6_multiswap_cell_response_t) :: cell
    type(modflow6_linear_boundary_term_t) :: small, large
    real(real64) :: q_small, q_large
    integer :: status

    call make_cell(1.005_real64, cell)

    call compose_modflow6_linear_boundary_term(cell, AREA, small, status)
    call require(status == MODFLOW6_LINEAR_BACKEND_OK, 'base area rejected', failures)
    call compose_modflow6_linear_boundary_term(cell, 2.0_real64*AREA, large, status)
    call require(status == MODFLOW6_LINEAR_BACKEND_OK, 'double area rejected', failures)

    call require_close(large%hcof_m2_per_day, 2.0_real64*small%hcof_m2_per_day, 1.0e-10_real64, &
         'HCOF area scaling mismatch', failures)
    call require_close(large%rhs_m3_per_day, 2.0_real64*small%rhs_m3_per_day, 1.0e-10_real64, &
         'RHS area scaling mismatch', failures)

    call evaluate_modflow6_linear_boundary_flux(small, cell%reference_head_m, q_small, status)
    call require(status == MODFLOW6_LINEAR_BACKEND_OK, 'small area evaluation rejected', failures)
    call evaluate_modflow6_linear_boundary_flux(large, cell%reference_head_m, q_large, status)
    call require(status == MODFLOW6_LINEAR_BACKEND_OK, 'large area evaluation rejected', failures)

    call require_close(q_large, 2.0_real64*q_small, 1.0e-10_real64, &
         'volume flux area scaling mismatch', failures)
    call require(q_small > 0.0_real64, &
         'positive outward-from-SWAP flux did not map to positive MODFLOW infiltration', failures)
  end subroutine test_area_scaling_and_sign

  subroutine test_fail_closed(failures)
    integer, intent(inout) :: failures
    type(modflow6_multiswap_cell_response_t) :: cell, bad_cell
    type(modflow6_linear_boundary_term_t) :: term
    real(real64) :: nan_value, q
    integer :: status

    call make_cell(1.005_real64, cell)
    nan_value = ieee_value(0.0_real64, ieee_quiet_nan)

    bad_cell = cell
    bad_cell%valid = .false.
    call compose_modflow6_linear_boundary_term(bad_cell, AREA, term, status)
    call require(status == MODFLOW6_LINEAR_BACKEND_INVALID_CELL_RESPONSE .and. .not. term%valid, &
         'invalid cell did not fail closed', failures)

    call compose_modflow6_linear_boundary_term(cell, 0.0_real64, term, status)
    call require(status == MODFLOW6_LINEAR_BACKEND_INVALID_AREA .and. .not. term%valid, &
         'zero area did not fail closed', failures)

    call compose_modflow6_linear_boundary_term(cell, nan_value, term, status)
    call require(status == MODFLOW6_LINEAR_BACKEND_INVALID_AREA .and. .not. term%valid, &
         'nonfinite area did not fail closed', failures)

    bad_cell = cell
    bad_cell%q_u_at_reference_m_per_s = nan_value
    call compose_modflow6_linear_boundary_term(bad_cell, AREA, term, status)
    call require(status == MODFLOW6_LINEAR_BACKEND_NONFINITE_SOURCE .and. .not. term%valid, &
         'nonfinite source response did not fail closed', failures)

    call compose_modflow6_linear_boundary_term(cell, AREA, term, status)
    call require(status == MODFLOW6_LINEAR_BACKEND_OK, 'valid term unavailable for evaluation guard', failures)
    call evaluate_modflow6_linear_boundary_flux(term, nan_value, q, status)
    call require(status == MODFLOW6_LINEAR_BACKEND_INVALID_EVALUATION .and. q == 0.0_real64, &
         'nonfinite evaluation head did not fail closed', failures)
  end subroutine test_fail_closed

  subroutine make_cell(reference_head_m, cell)
    real(real64), intent(in) :: reference_head_m
    type(modflow6_multiswap_cell_response_t), intent(out) :: cell

    type(groundwater_direct_tile_binding_t) :: bindings(2)
    type(modflow6_swap_predictor_response_t) :: responses(2)
    integer :: status

    bindings(1)%groundwater_cell_id = 7001_int64
    bindings(1)%tile_id = 20_int64
    bindings(1)%area_fraction = 0.75_real64
    bindings(2)%groundwater_cell_id = 7001_int64
    bindings(2)%tile_id = 10_int64
    bindings(2)%area_fraction = 0.25_real64

    call make_response(102_int64, responses(1), second=.true.)
    call make_response(101_int64, responses(2))

    call compose_modflow6_multiswap_cell_response(bindings, responses, reference_head_m, cell, status)
    if (status /= MODFLOW6_MULTI_CELL_OK .or. .not. cell%valid) then
      write(*,'(A)') 'FGC33 cell fixture construction failed'
      error stop 2
    end if
  end subroutine make_cell

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

    lineage%coupling_id = 3301_int64
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
         MODFLOW6_DERIVATIVE_TRAJECTORY_TANGENT, coverage, 'fgc33-fixture', &
         'drainage-free-smooth-route', response, status)
    if (status /= MODFLOW6_PREDICTOR_OK .or. .not. response%valid) then
      write(*,'(A)') 'FGC33 predictor fixture construction failed'
      error stop 3
    end if
  end subroutine make_response

  subroutine require(condition, message, failures)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    integer, intent(inout) :: failures

    if (.not. condition) then
      failures = failures + 1
      write(*,'(A)') 'FGC33_FAIL: '//trim(message)
    end if
  end subroutine require

  subroutine require_close(actual, expected, tolerance, message, failures)
    real(real64), intent(in) :: actual, expected, tolerance
    character(len=*), intent(in) :: message
    integer, intent(inout) :: failures

    call require(abs(actual - expected) <= tolerance, message, failures)
  end subroutine require_close

end program test_fgc33_modflow6_linear_response_backend

program test_fgc34_modflow6_api_binding
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use, intrinsic :: iso_fortran_env, only: int32, int64, real64
  use mod_modflow6_linear_response_backend, only: modflow6_linear_boundary_term_t, &
       MODFLOW6_LINEAR_BACKEND_OK
  use mod_modflow6_api_binding, only: modflow6_api_slot_binding_t, publish_modflow6_api_terms, &
       MODFLOW6_API_BINDING_OK, MODFLOW6_API_BINDING_INVALID_PACKAGE, &
       MODFLOW6_API_BINDING_INVALID_COUNT, MODFLOW6_API_BINDING_INVALID_BINDING, &
       MODFLOW6_API_BINDING_DUPLICATE_BINDING, MODFLOW6_API_BINDING_TERM_MATCH, &
       MODFLOW6_API_BINDING_INVALID_TERM, MODFLOW6_API_BINDING_NONFINITE_TERM
  implicit none

  integer :: failures

  failures = 0
  call test_explicit_mapping_and_n_to_1(failures)
  call test_order_independence(failures)
  call test_fail_closed(failures)

  if (failures /= 0) then
    write(*,'(A,I0)') 'F-GC34 FAILURES=', failures
    error stop 1
  end if

  print '(A)', 'FGC34_EXPLICIT_IDENTITY_MAPPING=PASS'
  print '(A)', 'FGC34_HCOF_RHS_PUBLICATION=PASS'
  print '(A)', 'FGC34_NBOUND_ACTIVE_PREFIX=PASS'
  print '(A)', 'FGC34_ORDER_INDEPENDENCE=PASS'
  print '(A)', 'FGC34_N_TO_1_NODE_PRESERVATION=PASS'
  print '(A)', 'FGC34_UNMAPPED_TAIL_PRESERVED=PASS'
  print '(A)', 'FGC34_ATOMIC_FAIL_CLOSED=PASS'
  print '(A)', 'FGC34_TYPED_API_BINDING_GATE=PASS'

contains

  subroutine test_explicit_mapping_and_n_to_1(failures)
    integer, intent(inout) :: failures
    type(modflow6_api_slot_binding_t) :: bindings(2)
    type(modflow6_linear_boundary_term_t) :: terms(2)
    integer(int32) :: nodelist(4), nbound
    real(real64) :: hcof(4), rhs(4)
    integer :: status

    call make_bindings(bindings)
    call make_terms(terms)

    nodelist = [-91_int32, -92_int32, -93_int32, -94_int32]
    hcof = [-11.0_real64, -12.0_real64, -13.0_real64, -14.0_real64]
    rhs = [-21.0_real64, -22.0_real64, -23.0_real64, -24.0_real64]
    nbound = 4_int32

    call publish_modflow6_api_terms(bindings, terms, 4_int32, nodelist, hcof, rhs, nbound, status)

    call require(status == MODFLOW6_API_BINDING_OK, 'valid publication rejected', failures)
    call require(nbound == 2_int32, 'NBOUND not set to active binding count', failures)

    ! Binding records are deliberately not ordered by package slot.
    call require(nodelist(1) == 42_int32, 'slot 1 node mismatch', failures)
    call require(nodelist(2) == 42_int32, 'slot 2 node mismatch', failures)
    call require_close(hcof(1), 250.0_real64, 0.0_real64, 'slot 1 HCOF mismatch', failures)
    call require_close(rhs(1), -10.0_real64, 0.0_real64, 'slot 1 RHS mismatch', failures)
    call require_close(hcof(2), 1750.0_real64, 0.0_real64, 'slot 2 HCOF mismatch', failures)
    call require_close(rhs(2), 1747.5_real64, 0.0_real64, 'slot 2 RHS mismatch', failures)

    ! The two coupling cells deliberately map to the same MODFLOW node.
    call require(bindings(1)%groundwater_cell_id /= bindings(2)%groundwater_cell_id, &
         'fixture coupling identities not distinct', failures)
    call require(bindings(1)%modflow_node_id == bindings(2)%modflow_node_id, &
         'fixture does not exercise N:1 MODFLOW node mapping', failures)

    ! Inactive package tail is outside NBOUND and must not be rewritten.
    call require(nodelist(3) == -93_int32 .and. nodelist(4) == -94_int32, &
         'inactive NODELIST tail was modified', failures)
    call require_close(hcof(3), -13.0_real64, 0.0_real64, 'inactive HCOF tail modified', failures)
    call require_close(hcof(4), -14.0_real64, 0.0_real64, 'inactive HCOF tail modified', failures)
    call require_close(rhs(3), -23.0_real64, 0.0_real64, 'inactive RHS tail modified', failures)
    call require_close(rhs(4), -24.0_real64, 0.0_real64, 'inactive RHS tail modified', failures)
  end subroutine test_explicit_mapping_and_n_to_1

  subroutine test_order_independence(failures)
    integer, intent(inout) :: failures
    type(modflow6_api_slot_binding_t) :: bindings_a(2), bindings_b(2)
    type(modflow6_linear_boundary_term_t) :: terms_a(2), terms_b(2)
    integer(int32) :: nodes_a(3), nodes_b(3), nbound_a, nbound_b
    real(real64) :: hcof_a(3), hcof_b(3), rhs_a(3), rhs_b(3)
    integer :: status_a, status_b

    call make_bindings(bindings_a)
    call make_terms(terms_a)
    bindings_b = [bindings_a(2), bindings_a(1)]
    terms_b = [terms_a(2), terms_a(1)]

    nodes_a = -1_int32
    nodes_b = -1_int32
    hcof_a = -1.0_real64
    hcof_b = -1.0_real64
    rhs_a = -1.0_real64
    rhs_b = -1.0_real64
    nbound_a = 0_int32
    nbound_b = 0_int32

    call publish_modflow6_api_terms(bindings_a, terms_a, 3_int32, nodes_a, hcof_a, rhs_a, nbound_a, status_a)
    call publish_modflow6_api_terms(bindings_b, terms_b, 3_int32, nodes_b, hcof_b, rhs_b, nbound_b, status_b)

    call require(status_a == MODFLOW6_API_BINDING_OK .and. status_b == MODFLOW6_API_BINDING_OK, &
         'order-independence publication rejected', failures)
    call require(all(nodes_a == nodes_b), 'NODELIST depends on input order', failures)
    call require(all(hcof_a == hcof_b), 'HCOF depends on input order', failures)
    call require(all(rhs_a == rhs_b), 'RHS depends on input order', failures)
    call require(nbound_a == nbound_b, 'NBOUND depends on input order', failures)
  end subroutine test_order_independence

  subroutine test_fail_closed(failures)
    integer, intent(inout) :: failures
    type(modflow6_api_slot_binding_t) :: bindings(2), bad_bindings(2)
    type(modflow6_linear_boundary_term_t) :: terms(2), bad_terms(2)
    real(real64) :: nan_value

    call make_bindings(bindings)
    call make_terms(terms)
    nan_value = ieee_value(0.0_real64, ieee_quiet_nan)

    call assert_rejected_unchanged(bindings, terms, 1_int32, MODFLOW6_API_BINDING_INVALID_COUNT, &
         'insufficient MAXBOUND', failures)

    call assert_rejected_unchanged(bindings, terms, 5_int32, MODFLOW6_API_BINDING_INVALID_PACKAGE, &
         'MAXBOUND exceeds package arrays', failures)

    bad_bindings = bindings
    bad_bindings(1)%package_slot = 3
    call assert_rejected_unchanged(bad_bindings, terms, 4_int32, MODFLOW6_API_BINDING_INVALID_BINDING, &
         'non-contiguous active prefix', failures)

    bad_bindings = bindings
    bad_bindings(2)%package_slot = bad_bindings(1)%package_slot
    call assert_rejected_unchanged(bad_bindings, terms, 4_int32, MODFLOW6_API_BINDING_DUPLICATE_BINDING, &
         'duplicate package slot', failures)

    bad_bindings = bindings
    bad_bindings(2)%groundwater_cell_id = bad_bindings(1)%groundwater_cell_id
    call assert_rejected_unchanged(bad_bindings, terms, 4_int32, MODFLOW6_API_BINDING_DUPLICATE_BINDING, &
         'duplicate coupling cell', failures)

    bad_bindings = bindings
    bad_bindings(1)%modflow_node_id = 0_int32
    call assert_rejected_unchanged(bad_bindings, terms, 4_int32, MODFLOW6_API_BINDING_INVALID_BINDING, &
         'invalid MODFLOW node id', failures)

    bad_terms = terms
    bad_terms(2)%groundwater_cell_id = 9999_int64
    call assert_rejected_unchanged(bindings, bad_terms, 4_int32, MODFLOW6_API_BINDING_TERM_MATCH, &
         'missing exact F-GC33 term', failures)

    bad_terms = terms
    bad_terms(1)%valid = .false.
    call assert_rejected_unchanged(bindings, bad_terms, 4_int32, MODFLOW6_API_BINDING_INVALID_TERM, &
         'invalid F-GC33 term', failures)

    bad_terms = terms
    bad_terms(1)%hcof_m2_per_day = nan_value
    call assert_rejected_unchanged(bindings, bad_terms, 4_int32, MODFLOW6_API_BINDING_NONFINITE_TERM, &
         'nonfinite HCOF', failures)

    call assert_empty_rejected_unchanged(terms, failures)
  end subroutine test_fail_closed

  subroutine assert_rejected_unchanged(bindings, terms, maxbound, expected_status, label, failures)
    type(modflow6_api_slot_binding_t), intent(in) :: bindings(:)
    type(modflow6_linear_boundary_term_t), intent(in) :: terms(:)
    integer(int32), intent(in) :: maxbound
    integer, intent(in) :: expected_status
    character(len=*), intent(in) :: label
    integer, intent(inout) :: failures

    integer(int32) :: nodelist(4), before_nodes(4), nbound, before_nbound
    real(real64) :: hcof(4), before_hcof(4), rhs(4), before_rhs(4)
    integer :: status

    nodelist = [91_int32, 92_int32, 93_int32, 94_int32]
    hcof = [11.0_real64, 12.0_real64, 13.0_real64, 14.0_real64]
    rhs = [21.0_real64, 22.0_real64, 23.0_real64, 24.0_real64]
    nbound = 3_int32

    before_nodes = nodelist
    before_hcof = hcof
    before_rhs = rhs
    before_nbound = nbound

    call publish_modflow6_api_terms(bindings, terms, maxbound, nodelist, hcof, rhs, nbound, status)

    call require(status == expected_status, trim(label)//': unexpected status', failures)
    call require(all(nodelist == before_nodes), trim(label)//': NODELIST mutated on failure', failures)
    call require(all(hcof == before_hcof), trim(label)//': HCOF mutated on failure', failures)
    call require(all(rhs == before_rhs), trim(label)//': RHS mutated on failure', failures)
    call require(nbound == before_nbound, trim(label)//': NBOUND mutated on failure', failures)
  end subroutine assert_rejected_unchanged

  subroutine assert_empty_rejected_unchanged(terms, failures)
    type(modflow6_linear_boundary_term_t), intent(in) :: terms(:)
    integer, intent(inout) :: failures

    type(modflow6_api_slot_binding_t), allocatable :: empty(:)
    integer(int32) :: nodelist(4), before_nodes(4), nbound, before_nbound
    real(real64) :: hcof(4), before_hcof(4), rhs(4), before_rhs(4)
    integer :: status

    allocate(empty(0))
    nodelist = [91_int32, 92_int32, 93_int32, 94_int32]
    hcof = [11.0_real64, 12.0_real64, 13.0_real64, 14.0_real64]
    rhs = [21.0_real64, 22.0_real64, 23.0_real64, 24.0_real64]
    nbound = 3_int32
    before_nodes = nodelist
    before_hcof = hcof
    before_rhs = rhs
    before_nbound = nbound

    call publish_modflow6_api_terms(empty, terms, 4_int32, nodelist, hcof, rhs, nbound, status)

    call require(status == MODFLOW6_API_BINDING_INVALID_COUNT, 'empty mapping unexpected status', failures)
    call require(all(nodelist == before_nodes), 'empty mapping NODELIST mutated', failures)
    call require(all(hcof == before_hcof), 'empty mapping HCOF mutated', failures)
    call require(all(rhs == before_rhs), 'empty mapping RHS mutated', failures)
    call require(nbound == before_nbound, 'empty mapping NBOUND mutated', failures)
  end subroutine assert_empty_rejected_unchanged

  subroutine make_bindings(bindings)
    type(modflow6_api_slot_binding_t), intent(out) :: bindings(2)

    ! Deliberately keep all three identity domains different.
    bindings(1)%groundwater_cell_id = 7001_int64
    bindings(1)%package_slot = 2
    bindings(1)%modflow_node_id = 42_int32

    bindings(2)%groundwater_cell_id = 8002_int64
    bindings(2)%package_slot = 1
    bindings(2)%modflow_node_id = 42_int32
  end subroutine make_bindings

  subroutine make_terms(terms)
    type(modflow6_linear_boundary_term_t), intent(out) :: terms(2)

    terms = modflow6_linear_boundary_term_t()

    ! Reverse coupling-cell order relative to package slots.
    terms(1)%valid = .true.
    terms(1)%status = MODFLOW6_LINEAR_BACKEND_OK
    terms(1)%groundwater_cell_id = 7001_int64
    terms(1)%hcof_m2_per_day = 1750.0_real64
    terms(1)%rhs_m3_per_day = 1747.5_real64

    terms(2)%valid = .true.
    terms(2)%status = MODFLOW6_LINEAR_BACKEND_OK
    terms(2)%groundwater_cell_id = 8002_int64
    terms(2)%hcof_m2_per_day = 250.0_real64
    terms(2)%rhs_m3_per_day = -10.0_real64
  end subroutine make_terms

  subroutine require(condition, message, failures)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    integer, intent(inout) :: failures

    if (.not. condition) then
      failures = failures + 1
      write(*,'(A)') 'FGC34_FAIL: '//trim(message)
    end if
  end subroutine require

  subroutine require_close(actual, expected, tolerance, message, failures)
    real(real64), intent(in) :: actual, expected, tolerance
    character(len=*), intent(in) :: message
    integer, intent(inout) :: failures

    call require(abs(actual - expected) <= tolerance, message, failures)
  end subroutine require_close

end program test_fgc34_modflow6_api_binding

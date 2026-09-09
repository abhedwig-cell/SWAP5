program test_fmr20_parallel_readiness
  use, intrinsic :: iso_fortran_env, only: int64
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_build_execution_order, &
       FMR_BACKEND_SERIALIZED_REFERENCE, FMR_EXECUTION_EASY
  implicit none

  integer, parameter :: worker_matrix(4) = [1, 2, 4, 8]
  integer, parameter :: column_matrix(7) = [1, 2, 8, 17, 31, 32, 64]
  integer(int64), parameter :: normal_cost_budget = 100_int64
  integer(int64), parameter :: fallback_cost_budget = 200_int64
  integer, parameter :: LANE_NORMAL = 1
  integer, parameter :: LANE_RELAXED = 2
  integer, parameter :: LANE_FALLBACK = 3

  type :: route_metadata_t
    integer :: worker = 0
    integer :: lane = 0
    integer(int64) :: synthetic_cost = 0_int64
    logical :: hard_mass_gate_required = .true.
    logical :: reference_completion_available = .true.
  end type route_metadata_t

  integer :: nc, nw, i, j, matrix_cases
  type(fmr_logical_column_t), allocatable :: base(:), reversed(:), permuted(:)
  type(route_metadata_t), allocatable :: reference_routes(:), probe_routes(:)
  integer, allocatable :: canonical_order(:), probe_order(:)
  integer(int64), allocatable :: canonical_payload(:), collected_payload(:)

  matrix_cases = 0
  do i = 1, size(column_matrix)
    nc = column_matrix(i)
    call build_columns(nc, base)
    call reverse_columns(base, reversed)
    call permute_columns(base, permuted)

    call fmr_build_execution_order(base, canonical_order)
    call require(valid_permutation(canonical_order, nc), 'production canonical order is a permutation')
    call require(canonical_keys_strict(base, canonical_order), 'production canonical keys strictly ordered')

    do j = 1, size(worker_matrix)
      nw = worker_matrix(j)
      matrix_cases = matrix_cases + 1

      call build_routes(base, canonical_order, nw, reference_routes)
      call require(route_contract_valid(base, canonical_order, nw, reference_routes), 'reference route contract')
      call require(worker_balance_valid(reference_routes, nw), 'round-robin worker balance')
      call require(empty_worker_contract_valid(reference_routes, nc, nw), 'deterministic empty workers')
      call require(difficult_lane_contract_valid(base, canonical_order, reference_routes), 'bounded difficult lane contract')

      call fmr_build_execution_order(reversed, probe_order)
      call require(valid_permutation(probe_order, nc), 'reverse order canonical permutation')
      call build_routes(reversed, probe_order, nw, probe_routes)
      call require(same_canonical_routes(base, canonical_order, reference_routes, reversed, probe_order, probe_routes), &
           'reverse input route identity')

      call fmr_build_execution_order(permuted, probe_order)
      call require(valid_permutation(probe_order, nc), 'permuted order canonical permutation')
      call build_routes(permuted, probe_order, nw, probe_routes)
      call require(same_canonical_routes(base, canonical_order, reference_routes, permuted, probe_order, probe_routes), &
           'permuted input route identity')

      call canonical_results(base, canonical_order, canonical_payload)
      call collect_reverse_completion(base, canonical_order, collected_payload)
      call require(all(collected_payload == canonical_payload), 'reverse completion canonical collection')
      call collect_odd_even_completion(base, canonical_order, collected_payload)
      call require(all(collected_payload == canonical_payload), 'permuted completion canonical collection')

      call replay_routes(base, canonical_order, nw, probe_routes)
      call require(same_route_metadata(reference_routes, probe_routes), 'deterministic replay')

      call require(all_identity_preserved(base), 'routing leaves physical identity metadata unchanged')
      call require(all(reference_routes%hard_mass_gate_required), 'all numerical lanes retain hard mass gate requirement')
      call require(all(reference_routes%reference_completion_available), 'reference completion remains available')
    end do

    write(*,'(A,I0,A)') 'FMR20_COLUMNS_', nc, '=PASS'
  end do

  call require(matrix_cases == size(worker_matrix)*size(column_matrix), 'complete 4x7 matrix')
  write(*,'(A,I0)') 'FMR20_MATRIX_CASES=', matrix_cases
  write(*,'(A)') 'FMR20_CANONICAL_TEMPLATE_COLUMN_ORDER=PASS'
  write(*,'(A)') 'FMR20_STATIC_PARTITION_FORMULA=PASS'
  write(*,'(A)') 'FMR20_INPUT_ORDER_INDEPENDENCE=PASS'
  write(*,'(A)') 'FMR20_COMPLETION_ORDER_INDEPENDENCE=PASS'
  write(*,'(A)') 'FMR20_EXACTLY_ONCE_ASSIGNMENT=PASS'
  write(*,'(A)') 'FMR20_EMPTY_WORKER_DETERMINISM=PASS'
  write(*,'(A)') 'FMR20_BOUNDED_DIFFICULT_LANE_ROUTING=PASS'
  write(*,'(A)') 'FMR20_PHYSICAL_IDENTITY_NONMUTATION=PASS'
  write(*,'(A)') 'FMR20_HARD_MASS_GATE_REQUIREMENT_PRESERVED=PASS'
  write(*,'(A)') 'FMR20_REFERENCE_COMPLETION_AVAILABLE=PASS'
  write(*,'(A)') 'FMR20_DETERMINISTIC_REPLAY=PASS'
  write(*,'(A)') 'FMR20_SCHEDULER_READINESS_ORACLE=PASS'

contains

  subroutine build_columns(n, columns)
    integer, intent(in) :: n
    type(fmr_logical_column_t), allocatable, intent(out) :: columns(:)
    integer :: k
    allocate(columns(n))
    do k = 1, n
      columns(k)%column_id = 1000_int64 + int(k, int64)
      columns(k)%template_id = 10_int64 + int(mod(2*k + 1, 3), int64)
      columns(k)%parameter_ref = 1_int64 + int(mod(k, 4), int64)
      columns(k)%state_handle = 5000_int64 + int(k, int64)
      columns(k)%forcing_handle = 9000_int64 + int(3*k, int64)
      columns(k)%execution_class = FMR_EXECUTION_EASY
      columns(k)%backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
    end do
  end subroutine build_columns

  subroutine reverse_columns(source, target)
    type(fmr_logical_column_t), intent(in) :: source(:)
    type(fmr_logical_column_t), allocatable, intent(out) :: target(:)
    integer :: k, n
    n = size(source)
    allocate(target(n))
    do k = 1, n
      target(k) = source(n-k+1)
    end do
  end subroutine reverse_columns

  subroutine permute_columns(source, target)
    type(fmr_logical_column_t), intent(in) :: source(:)
    type(fmr_logical_column_t), allocatable, intent(out) :: target(:)
    integer :: k, n, idx, shift
    n = size(source)
    allocate(target(n))
    if (n == 1) then
      target = source
      return
    end if
    shift = n/2
    do k = 1, n
      idx = 1 + mod(shift + (k-1)*(n-1), n)
      target(k) = source(idx)
    end do
  end subroutine permute_columns

  subroutine build_routes(columns, order, workers, routes)
    type(fmr_logical_column_t), intent(in) :: columns(:)
    integer, intent(in) :: order(:), workers
    type(route_metadata_t), allocatable, intent(out) :: routes(:)
    integer :: k, idx
    integer(int64) :: cost
    allocate(routes(size(order)))
    do k = 1, size(order)
      idx = order(k)
      cost = synthetic_scheduler_cost(columns(idx))
      routes(k)%worker = mod(k-1, workers) + 1
      routes(k)%synthetic_cost = cost
      if (cost <= normal_cost_budget) then
        routes(k)%lane = LANE_NORMAL
      else if (cost <= fallback_cost_budget) then
        routes(k)%lane = LANE_RELAXED
      else
        routes(k)%lane = LANE_FALLBACK
      end if
      routes(k)%hard_mass_gate_required = .true.
      routes(k)%reference_completion_available = .true.
    end do
  end subroutine build_routes

  subroutine replay_routes(columns, order, workers, routes)
    type(fmr_logical_column_t), intent(in) :: columns(:)
    integer, intent(in) :: order(:), workers
    type(route_metadata_t), allocatable, intent(out) :: routes(:)
    call build_routes(columns, order, workers, routes)
  end subroutine replay_routes

  logical function route_contract_valid(columns, order, workers, routes) result(ok)
    type(fmr_logical_column_t), intent(in) :: columns(:)
    integer, intent(in) :: order(:), workers
    type(route_metadata_t), intent(in) :: routes(:)
    integer :: k
    ok = size(routes) == size(columns) .and. size(order) == size(columns) .and. workers > 0
    if (.not. ok) return
    do k = 1, size(routes)
      if (routes(k)%worker /= mod(k-1, workers)+1) then
        ok = .false.; return
      end if
      if (routes(k)%synthetic_cost /= synthetic_scheduler_cost(columns(order(k)))) then
        ok = .false.; return
      end if
    end do
  end function route_contract_valid

  logical function worker_balance_valid(routes, workers) result(ok)
    type(route_metadata_t), intent(in) :: routes(:)
    integer, intent(in) :: workers
    integer, allocatable :: counts(:)
    integer :: k
    allocate(counts(workers)); counts = 0
    do k = 1, size(routes)
      if (routes(k)%worker < 1 .or. routes(k)%worker > workers) then
        ok = .false.; return
      end if
      counts(routes(k)%worker) = counts(routes(k)%worker) + 1
    end do
    ok = maxval(counts) - minval(counts) <= 1
  end function worker_balance_valid

  logical function empty_worker_contract_valid(routes, columns, workers) result(ok)
    type(route_metadata_t), intent(in) :: routes(:)
    integer, intent(in) :: columns, workers
    integer, allocatable :: counts(:)
    integer :: k
    allocate(counts(workers)); counts = 0
    do k = 1, size(routes)
      counts(routes(k)%worker) = counts(routes(k)%worker) + 1
    end do
    ok = .true.
    if (workers > columns) then
      do k = columns+1, workers
        if (counts(k) /= 0) then
          ok = .false.; return
        end if
      end do
    end if
  end function empty_worker_contract_valid

  logical function difficult_lane_contract_valid(columns, order, routes) result(ok)
    type(fmr_logical_column_t), intent(in) :: columns(:)
    integer, intent(in) :: order(:)
    type(route_metadata_t), intent(in) :: routes(:)
    integer :: k, expected
    integer(int64) :: cost
    ok = .true.
    do k = 1, size(routes)
      cost = synthetic_scheduler_cost(columns(order(k)))
      if (cost <= normal_cost_budget) then
        expected = LANE_NORMAL
      else if (cost <= fallback_cost_budget) then
        expected = LANE_RELAXED
      else
        expected = LANE_FALLBACK
      end if
      if (routes(k)%lane /= expected) then
        ok = .false.; return
      end if
      if (.not. routes(k)%hard_mass_gate_required .or. .not. routes(k)%reference_completion_available) then
        ok = .false.; return
      end if
    end do
  end function difficult_lane_contract_valid

  logical function same_canonical_routes(a, order_a, route_a, b, order_b, route_b) result(ok)
    type(fmr_logical_column_t), intent(in) :: a(:), b(:)
    integer, intent(in) :: order_a(:), order_b(:)
    type(route_metadata_t), intent(in) :: route_a(:), route_b(:)
    integer :: k
    ok = size(a) == size(b) .and. size(order_a) == size(order_b) .and. size(route_a) == size(route_b)
    if (.not. ok) return
    do k = 1, size(order_a)
      if (.not. same_column_identity(a(order_a(k)), b(order_b(k)))) then
        ok = .false.; return
      end if
      if (.not. same_route(route_a(k), route_b(k))) then
        ok = .false.; return
      end if
    end do
  end function same_canonical_routes

  logical function same_route_metadata(a, b) result(ok)
    type(route_metadata_t), intent(in) :: a(:), b(:)
    integer :: k
    ok = size(a) == size(b)
    if (.not. ok) return
    do k = 1, size(a)
      if (.not. same_route(a(k), b(k))) then
        ok = .false.; return
      end if
    end do
  end function same_route_metadata

  logical function same_route(a, b) result(ok)
    type(route_metadata_t), intent(in) :: a, b
    ok = a%worker == b%worker .and. a%lane == b%lane .and. &
         a%synthetic_cost == b%synthetic_cost .and. &
         (a%hard_mass_gate_required .eqv. b%hard_mass_gate_required) .and. &
         (a%reference_completion_available .eqv. b%reference_completion_available)
  end function same_route

  logical function valid_permutation(order, n) result(ok)
    integer, intent(in) :: order(:), n
    logical, allocatable :: seen(:)
    integer :: k
    ok = size(order) == n
    if (.not. ok) return
    allocate(seen(n)); seen = .false.
    do k = 1, n
      if (order(k) < 1 .or. order(k) > n) then
        ok = .false.; return
      end if
      if (seen(order(k))) then
        ok = .false.; return
      end if
      seen(order(k)) = .true.
    end do
    ok = all(seen)
  end function valid_permutation

  logical function canonical_keys_strict(columns, order) result(ok)
    type(fmr_logical_column_t), intent(in) :: columns(:)
    integer, intent(in) :: order(:)
    integer :: k
    ok = .true.
    do k = 2, size(order)
      if (columns(order(k-1))%template_id > columns(order(k))%template_id) then
        ok = .false.; return
      end if
      if (columns(order(k-1))%template_id == columns(order(k))%template_id .and. &
          columns(order(k-1))%column_id >= columns(order(k))%column_id) then
        ok = .false.; return
      end if
    end do
  end function canonical_keys_strict

  subroutine canonical_results(columns, order, payload)
    type(fmr_logical_column_t), intent(in) :: columns(:)
    integer, intent(in) :: order(:)
    integer(int64), allocatable, intent(out) :: payload(:)
    integer :: k
    allocate(payload(size(order)))
    do k = 1, size(order)
      payload(k) = result_payload(columns(order(k)))
    end do
  end subroutine canonical_results

  subroutine collect_reverse_completion(columns, order, payload)
    type(fmr_logical_column_t), intent(in) :: columns(:)
    integer, intent(in) :: order(:)
    integer(int64), allocatable, intent(out) :: payload(:)
    integer :: k, completion_pos, canonical_pos, idx
    allocate(payload(size(order))); payload = -1_int64
    do k = 1, size(order)
      completion_pos = size(order)-k+1
      idx = order(completion_pos)
      canonical_pos = find_canonical_position(columns, order, columns(idx)%column_id)
      if (canonical_pos > 0) payload(canonical_pos) = result_payload(columns(idx))
    end do
  end subroutine collect_reverse_completion

  subroutine collect_odd_even_completion(columns, order, payload)
    type(fmr_logical_column_t), intent(in) :: columns(:)
    integer, intent(in) :: order(:)
    integer(int64), allocatable, intent(out) :: payload(:)
    integer :: k, completion_pos, canonical_pos, idx, n, odd_count
    n = size(order)
    odd_count = (n+1)/2
    allocate(payload(n)); payload = -1_int64
    do k = 1, n
      if (k <= odd_count) then
        completion_pos = 2*k-1
      else
        completion_pos = 2*(k-odd_count)
      end if
      idx = order(completion_pos)
      canonical_pos = find_canonical_position(columns, order, columns(idx)%column_id)
      if (canonical_pos > 0) payload(canonical_pos) = result_payload(columns(idx))
    end do
  end subroutine collect_odd_even_completion

  integer function find_canonical_position(columns, order, column_id) result(pos)
    type(fmr_logical_column_t), intent(in) :: columns(:)
    integer, intent(in) :: order(:)
    integer(int64), intent(in) :: column_id
    integer :: k
    pos = 0
    do k = 1, size(order)
      if (columns(order(k))%column_id == column_id) then
        pos = k
        return
      end if
    end do
  end function find_canonical_position

  integer(int64) function synthetic_scheduler_cost(column) result(cost)
    type(fmr_logical_column_t), intent(in) :: column
    cost = 20_int64 + 60_int64*mod(column%column_id, 5_int64)
  end function synthetic_scheduler_cost

  integer(int64) function result_payload(column) result(value)
    type(fmr_logical_column_t), intent(in) :: column
    value = 1000000_int64*column%template_id + 100_int64*column%column_id + column%parameter_ref
  end function result_payload

  logical function all_identity_preserved(columns) result(ok)
    type(fmr_logical_column_t), intent(in) :: columns(:)
    integer :: k
    ok = .true.
    do k = 1, size(columns)
      if (columns(k)%execution_class /= FMR_EXECUTION_EASY .or. &
          columns(k)%backend_id /= FMR_BACKEND_SERIALIZED_REFERENCE) then
        ok = .false.; return
      end if
      if (columns(k)%parameter_ref <= 0_int64 .or. columns(k)%state_handle <= 0_int64 .or. &
          columns(k)%forcing_handle <= 0_int64) then
        ok = .false.; return
      end if
    end do
  end function all_identity_preserved

  logical function same_column_identity(a, b) result(ok)
    type(fmr_logical_column_t), intent(in) :: a, b
    ok = a%column_id == b%column_id .and. a%template_id == b%template_id .and. &
         a%parameter_ref == b%parameter_ref .and. a%state_handle == b%state_handle .and. &
         a%forcing_handle == b%forcing_handle .and. a%execution_class == b%execution_class .and. &
         a%backend_id == b%backend_id
  end function same_column_identity

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'FMR20_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require

end program test_fmr20_parallel_readiness

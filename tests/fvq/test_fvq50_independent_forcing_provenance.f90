program test_fvq50_independent_forcing_provenance
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t, TX_TEMPORAL_EXTERNAL_FULL_HALF
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_fmr04_fixed_top_provider, only: fmr04_fixed_flux_top_provider_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, fmr_column_diagnostics_t, &
       fmr_aggregate_diagnostics_t, FMR_BACKEND_SERIALIZED_REFERENCE
  use mod_fmr_serialized_reference_backend, only: fvq50_physical_state_t, fmr_b110_physical_parameters_t, &
       fmr_b110_physical_forcing_t
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t, &
       fmr_serialized_batch_diagnostics_t, fmr_run_serialized_physical_multiswap, FMR_SERIAL_DISPATCH_OK
  implicit none

  integer, parameter :: ncol = 8, nforcing = 5
  integer, parameter :: SEM_A=1, SEM_B=2, SEM_ZERO=3, SEM_D=4, SEM_E=5
  real(real64), parameter :: t0 = 1234.0625_real64
  real(real64), parameter :: t1 = 1234.40625_real64
  real(real64), parameter :: dt = t1 - t0

  type(fmr_serialized_column_result_t), allocatable :: a(:), b(:), a2(:)
  type(fmr_column_diagnostics_t), allocatable :: da(:), db(:), da2(:)
  type(fmr_aggregate_diagnostics_t) :: aa, ab, aa2
  type(fmr_serialized_batch_diagnostics_t) :: ra, rb, ra2
  type(kernel_committed_state_t), allocatable :: sa(:), sb(:), sa2(:)
  integer :: status

  call run_case(1, 1, .false., a, da, aa, ra, sa, status)
  call require(status == FMR_SERIAL_DISPATCH_OK, 'case A dispatch')
  call validate_case(a, ra)

  call run_case(2, 5, .true., b, db, ab, rb, sb, status)
  call require(status == FMR_SERIAL_DISPATCH_OK, 'case B dispatch')
  call validate_case(b, rb)
  call require(result_sets_equal_by_id(a,b), 'registry permutation plus input reversal identity')
  call require(same_bits(ra%authoritative_aggregate_mass%total_out, rb%authoritative_aggregate_mass%total_out), &
       'aggregate mass registry permutation identity')
  print '(a)', 'FVQ50_PERMUTED_REGISTRY_PROVENANCE=PASS'
  print '(a)', 'FVQ50_BATCH_ORDER_IDENTITY=PASS'

  call run_case(1, 2, .false., a2, da2, aa2, ra2, sa2, status)
  call require(status == FMR_SERIAL_DISPATCH_OK, 'case A2 dispatch')
  call require(result_sets_equal_by_id(a,a2), 'A-B-A result identity')
  call require(same_bits(ra%authoritative_aggregate_mass%total_out, ra2%authoritative_aggregate_mass%total_out), &
       'A-B-A aggregate identity')
  print '(a)', 'FVQ50_A_B_A_IDENTITY=PASS'

  call validate_shared_and_distinct(a)
  call postcommit_mutation_attack()
  print '(a)', 'FVQ50_INDEPENDENT_RUNTIME_ORACLE PASS'

contains

  subroutine run_case(registry_variant, batch_size, reverse_input, results, diagnostics, aggregate, runtime, states, dispatch)
    integer, intent(in) :: registry_variant, batch_size
    logical, intent(in) :: reverse_input
    type(fmr_serialized_column_result_t), allocatable, intent(out) :: results(:)
    type(fmr_column_diagnostics_t), allocatable, intent(out) :: diagnostics(:)
    type(fmr_aggregate_diagnostics_t), intent(out) :: aggregate
    type(fmr_serialized_batch_diagnostics_t), intent(out) :: runtime
    type(kernel_committed_state_t), allocatable, intent(out) :: states(:)
    integer, intent(out) :: dispatch
    type(fmr_logical_column_t) :: columns(ncol), tmp
    type(fmr_template_t) :: templates(1)
    type(fmr_b110_physical_parameters_t) :: parameters(3)
    type(fmr_b110_physical_forcing_t) :: forcings(nforcing)
    type(canonical_numerical_config_t) :: config
    type(fmr04_fixed_flux_top_provider_t), target :: top
    integer :: left, right

    call configure_case(registry_variant, columns, templates, parameters, forcings, states, config)
    if (reverse_input) then
      do left = 1, ncol/2
        right = ncol + 1 - left
        tmp = columns(left)
        columns(left) = columns(right)
        columns(right) = tmp
      end do
    end if

    call fmr_run_serialized_physical_multiswap(columns, templates, parameters, forcings, states, config, top, &
         t0, t1, batch_size, results, diagnostics, aggregate, dispatch, runtime_diagnostics=runtime)
  end subroutine run_case

  subroutine configure_case(registry_variant, columns, templates, parameters, forcings, states, config)
    integer, intent(in) :: registry_variant
    type(fmr_logical_column_t), intent(out) :: columns(ncol)
    type(fmr_template_t), intent(out) :: templates(1)
    type(fmr_b110_physical_parameters_t), intent(out) :: parameters(3)
    type(fmr_b110_physical_forcing_t), intent(out) :: forcings(nforcing)
    type(kernel_committed_state_t), allocatable, intent(out) :: states(:)
    type(canonical_numerical_config_t), intent(out) :: config
    integer :: i, semantic
    integer, parameter :: semantics(ncol) = [SEM_A, SEM_B, SEM_E, SEM_A, SEM_ZERO, SEM_D, SEM_B, SEM_E]

    templates(1)%template_id = 5001_int64
    templates(1)%physics_topology_id = 5002_int64
    templates(1)%vertical_layout_id = 5003_int64
    templates(1)%state_layout_id = 5004_int64
    templates(1)%solver_interface_id = 5005_int64
    templates(1)%optional_state_layout_id = 0_int64
    templates(1)%compatible_backend_id = FMR_BACKEND_SERIALIZED_REFERENCE

    parameters(1)%admitted = .true.
    parameters(1)%active_nodes = 4
    parameters(1)%root_extraction_active = .true.
    parameters(1)%independent_background_out_rate = 0.03125_real64
    parameters(2) = parameters(1)
    parameters(2)%root_extraction_active = .false.
    parameters(2)%independent_background_out_rate = 0.0625_real64
    parameters(3) = parameters(1)
    parameters(3)%admitted = .false.

    do semantic = 1, nforcing
      call set_semantic_forcing(forcings(semantic_handle(semantic, registry_variant)), semantic)
    end do

    allocate(states(ncol))
    do i = 1, ncol
      columns(i)%column_id = 50000_int64 + int(i,int64)
      columns(i)%template_id = templates(1)%template_id
      columns(i)%parameter_ref = 1_int64
      columns(i)%state_handle = int(i,int64)
      columns(i)%forcing_handle = int(semantic_handle(semantics(i), registry_variant), int64)
      columns(i)%backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
      call initialize_state(states(i), columns(i)%column_id)
    end do
    columns(6)%parameter_ref = 2_int64
    columns(7)%parameter_ref = 3_int64

    config%transaction%temporal_tolerance = 0.0_real64
    config%transaction%mass_tolerance = 1.0e-12_real64
    config%transaction%retry_scale = 0.5_real64
    config%transaction%max_retries = 2
    config%transaction%temporal_mode = TX_TEMPORAL_EXTERNAL_FULL_HALF
    config%max_committed_substeps = 8
    config%progress_tolerance = 0.0_real64
  end subroutine configure_case

  integer function semantic_handle(semantic, variant) result(handle)
    integer, intent(in) :: semantic, variant
    integer, parameter :: map1(5) = [3,1,2,5,4]
    integer, parameter :: map2(5) = [5,2,4,1,3]
    select case (variant)
    case (1)
      handle = map1(semantic)
    case (2)
      handle = map2(semantic)
    case default
      error stop 'F-VQ50 invalid registry variant'
    end select
  end function semantic_handle

  subroutine set_semantic_forcing(forcing, semantic)
    type(fmr_b110_physical_forcing_t), intent(out) :: forcing
    integer, intent(in) :: semantic
    allocate(forcing%root_extraction_sink(4))
    select case (semantic)
    case (SEM_A)
      forcing%root_extraction_sink = [0.02_real64, 0.07_real64, 0.11_real64, 0.13_real64]
    case (SEM_B)
      forcing%root_extraction_sink = [0.70_real64, 0.00_real64, 0.10_real64, 0.05_real64]
    case (SEM_ZERO)
      forcing%root_extraction_sink = 0.0_real64
    case (SEM_D)
      forcing%root_extraction_sink = [0.004_real64, 0.006_real64, 0.008_real64, 0.012_real64]
    case (SEM_E)
      forcing%root_extraction_sink = [0.31_real64, 0.29_real64, 0.17_real64, 0.23_real64]
    case default
      error stop 'F-VQ50 invalid semantic forcing'
    end select
  end subroutine set_semantic_forcing

  real(real64) function semantic_root_amount(semantic) result(amount)
    integer, intent(in) :: semantic
    select case (semantic)
    case (SEM_A)
      amount = (0.02_real64 + 0.07_real64 + 0.11_real64 + 0.13_real64) * dt
    case (SEM_B)
      amount = (0.70_real64 + 0.00_real64 + 0.10_real64 + 0.05_real64) * dt
    case (SEM_ZERO)
      amount = 0.0_real64
    case (SEM_D)
      amount = (0.004_real64 + 0.006_real64 + 0.008_real64 + 0.012_real64) * dt
    case (SEM_E)
      amount = (0.31_real64 + 0.29_real64 + 0.17_real64 + 0.23_real64) * dt
    case default
      error stop 'F-VQ50 invalid expected semantic'
    end select
  end function semantic_root_amount

  integer function semantic_for_column(column_id) result(semantic)
    integer(int64), intent(in) :: column_id
    select case (column_id)
    case (50001_int64,50004_int64)
      semantic = SEM_A
    case (50002_int64,50007_int64)
      semantic = SEM_B
    case (50003_int64,50008_int64)
      semantic = SEM_E
    case (50005_int64)
      semantic = SEM_ZERO
    case (50006_int64)
      semantic = SEM_D
    case default
      error stop 'F-VQ50 unknown column id'
    end select
  end function semantic_for_column

  subroutine initialize_state(state, lineage)
    type(kernel_committed_state_t), intent(out) :: state
    integer(int64), intent(in) :: lineage
    class(transaction_state_t), allocatable :: physical
    logical :: ok

    allocate(fvq50_physical_state_t :: physical)
    select type (physical)
    type is (fvq50_physical_state_t)
      physical%storage = 50.0_real64
    end select
    call state%initialize(lineage, physical, ok, t0)
    call require(ok, 'state initialization')
  end subroutine initialize_state

  subroutine validate_case(results, runtime)
    type(fmr_serialized_column_result_t), intent(in) :: results(:)
    type(fmr_serialized_batch_diagnostics_t), intent(in) :: runtime
    type(fmr_serialized_column_result_t) :: r
    real(real64) :: expected_root, expected_background, expected_total, sum_total
    integer :: i, sem

    sum_total = 0.0_real64
    do i = 1, size(results)
      r = results(i)
      sem = semantic_for_column(r%column_id)
      if (r%column_id == 50007_int64) then
        call require(.not. r%committed, 'not-admitted column remains noncommitted')
        call require(.not. r%actual_transpiration_available, 'not-admitted attribution unavailable')
        call assert_close(r%actual_transpiration_amount, 0.0_real64, 'not-admitted attribution zero default')
      else if (r%column_id == 50006_int64) then
        expected_background = 0.0625_real64 * dt
        call require(r%committed, 'root-inactive column committed')
        call require(.not. r%actual_transpiration_available, 'root-inactive attribution unavailable')
        call assert_close(r%actual_transpiration_amount, 0.0_real64, 'root-inactive attribution zero default')
        call assert_close(r%mass%total_out, expected_background, 'root-inactive independent background mass')
        call assert_close(r%mass%residual, 0.0_real64, 'root-inactive mass residual')
        sum_total = sum_total + r%mass%total_out
      else
        expected_root = semantic_root_amount(sem)
        expected_background = 0.03125_real64 * dt
        expected_total = expected_root + expected_background
        call require(r%committed, 'active column committed')
        call require(r%actual_transpiration_available, 'active attribution available')
        call assert_close(r%actual_transpiration_amount, expected_root, 'independent semantic root amount')
        call assert_close(r%mass%total_out, expected_total, 'root plus independent background mass')
        call assert_close(r%mass%total_out-r%actual_transpiration_amount, expected_background, &
             'attribution separated from background mass')
        call assert_close(r%mass%residual, 0.0_real64, 'active mass residual')
        sum_total = sum_total + r%mass%total_out
      end if
    end do

    r = result_for_id(results,50005_int64)
    call require(r%actual_transpiration_available, 'active-zero availability')
    call assert_close(r%actual_transpiration_amount, 0.0_real64, 'active-zero amount')
    call require(r%mass%total_out > 0.0_real64, 'active-zero independent background mass remains')

    call require(runtime%authoritative_aggregate_mass%complete, 'aggregate mass complete')
    call assert_close(runtime%authoritative_aggregate_mass%total_out, sum_total, 'aggregate physical total out')
    call assert_close(runtime%authoritative_aggregate_mass%residual, 0.0_real64, 'aggregate mass residual')
    print '(a)', 'FVQ50_ACTIVE_ZERO_AVAILABLE=PASS'
    print '(a)', 'FVQ50_ROOT_INACTIVE_UNAVAILABLE=PASS'
    print '(a)', 'FVQ50_NONCOMMITTED_UNAVAILABLE=PASS'
    print '(a)', 'FVQ50_ROOT_ATTRIBUTION_SEPARATE_FROM_BACKGROUND_MASS=PASS'
    print '(a)', 'FVQ50_HARD_MASS_BALANCE=PASS'
  end subroutine validate_case

  subroutine validate_shared_and_distinct(results)
    type(fmr_serialized_column_result_t), intent(in) :: results(:)
    type(fmr_serialized_column_result_t) :: a1, a2, b, e
    a1 = result_for_id(results,50001_int64)
    a2 = result_for_id(results,50004_int64)
    b = result_for_id(results,50002_int64)
    e = result_for_id(results,50003_int64)
    call require(same_bits(a1%actual_transpiration_amount,a2%actual_transpiration_amount), 'shared A forcing amount identity')
    call require(.not. same_bits(a1%actual_transpiration_amount,b%actual_transpiration_amount), 'A/B amount distinction')
    call require(.not. same_bits(b%actual_transpiration_amount,e%actual_transpiration_amount), 'B/E amount distinction')
    print '(a)', 'FVQ50_SHARED_FORCING_HANDLE_IDENTITY=PASS'
    print '(a)', 'FVQ50_DISTINCT_FORCING_HANDLE_DISTINCTION=PASS'
  end subroutine validate_shared_and_distinct

  subroutine postcommit_mutation_attack()
    type(fmr_logical_column_t) :: columns(ncol)
    type(fmr_template_t) :: templates(1)
    type(fmr_b110_physical_parameters_t) :: parameters(3)
    type(fmr_b110_physical_forcing_t) :: forcings(nforcing)
    type(kernel_committed_state_t), allocatable :: states(:)
    type(canonical_numerical_config_t) :: config
    type(fmr04_fixed_flux_top_provider_t), target :: top
    type(fmr_serialized_column_result_t), allocatable :: results(:)
    type(fmr_column_diagnostics_t), allocatable :: diagnostics(:)
    type(fmr_aggregate_diagnostics_t) :: aggregate
    type(fmr_serialized_batch_diagnostics_t) :: runtime
    type(fmr_serialized_column_result_t) :: before
    real(real64) :: amount_before
    integer :: dispatch, i

    call configure_case(1, columns, templates, parameters, forcings, states, config)
    call fmr_run_serialized_physical_multiswap(columns, templates, parameters, forcings, states, config, top, &
         t0, t1, 2, results, diagnostics, aggregate, dispatch, runtime_diagnostics=runtime)
    call require(dispatch == FMR_SERIAL_DISPATCH_OK, 'mutation attack dispatch')
    before = result_for_id(results,50001_int64)
    amount_before = before%actual_transpiration_amount
    do i = 1, size(forcings)
      forcings(i)%root_extraction_sink = [9.0_real64+real(i,real64), 8.0_real64, 7.0_real64, 6.0_real64]
    end do
    call require(same_bits(amount_before, result_for_id(results,50001_int64)%actual_transpiration_amount), &
         'committed result detached from later forcing mutation')
    call assert_close(result_for_id(results,50001_int64)%actual_transpiration_amount, semantic_root_amount(SEM_A), &
         'postcommit result retains original A attribution')
    print '(a)', 'FVQ50_POSTCOMMIT_FORCING_MUTATION_CANNOT_REPAIR_RESULT=PASS'
  end subroutine postcommit_mutation_attack

  logical function result_sets_equal_by_id(left,right) result(equal)
    type(fmr_serialized_column_result_t), intent(in) :: left(:), right(:)
    type(fmr_serialized_column_result_t) :: r
    integer :: i
    equal = size(left) == size(right)
    if (.not. equal) return
    do i = 1, size(left)
      r = result_for_id(right,left(i)%column_id)
      if (left(i)%committed .neqv. r%committed) then
        equal=.false.; return
      end if
      if (left(i)%actual_transpiration_available .neqv. r%actual_transpiration_available) then
        equal=.false.; return
      end if
      if (.not. same_bits(left(i)%actual_transpiration_amount,r%actual_transpiration_amount)) then
        equal=.false.; return
      end if
      if (.not. same_bits(left(i)%mass%total_out,r%mass%total_out)) then
        equal=.false.; return
      end if
      if (.not. same_bits(left(i)%mass%residual,r%mass%residual)) then
        equal=.false.; return
      end if
    end do
  end function result_sets_equal_by_id

  function result_for_id(results,id) result(value)
    type(fmr_serialized_column_result_t), intent(in) :: results(:)
    integer(int64), intent(in) :: id
    type(fmr_serialized_column_result_t) :: value
    integer :: i
    value = fmr_serialized_column_result_t()
    do i = 1, size(results)
      if (results(i)%column_id == id) then
        value = results(i)
        return
      end if
    end do
    error stop 'F-VQ50 result id not found'
  end function result_for_id

  pure logical function same_bits(x,y) result(equal)
    real(real64), intent(in) :: x,y
    integer(int64) :: xi,yi
    xi = transfer(x,xi)
    yi = transfer(y,yi)
    equal = xi == yi
  end function same_bits

  subroutine assert_close(actual,expected,label)
    real(real64), intent(in) :: actual,expected
    character(len=*), intent(in) :: label
    real(real64) :: tolerance
    tolerance = 1024.0_real64*epsilon(1.0_real64)*max(1.0_real64,abs(actual),abs(expected))
    call require(abs(actual-expected) <= tolerance,label)
  end subroutine assert_close

  subroutine require(condition,label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(a,1x,a)') 'FVQ50_ASSERT_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require

end program test_fvq50_independent_forcing_provenance

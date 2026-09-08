program test_fwof13_crop_root_snapshot_assembly
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_crop_root_uptake_input_contract, only: crop_root_uptake_input_t, validate_crop_root_uptake_input, &
       CROP_ROOT_INPUT_OK, CROP_ROOT_INPUT_NOT_CANONICAL
  use mod_crop_root_uptake_input_assembly, only: crop_root_state_view_t, root_uptake_et_result_t, &
       crop_root_uptake_assembly_diagnostics_t, validate_crop_root_state_view, assemble_crop_root_uptake_input, &
       CROP_ROOT_ASSEMBLY_OK, CROP_ROOT_ASSEMBLY_INVALID_ACTIVE_NODES, CROP_ROOT_ASSEMBLY_INVALID_SNAPSHOT, &
       CROP_ROOT_ASSEMBLY_INVALID_ET_RESULT
  implicit none

  type(crop_root_state_view_t) :: inactive, stale_inactive, zero_root, rooted_a, rooted_a_before, rooted_b, invalid_root
  type(root_uptake_et_result_t) :: et, et_before
  type(crop_root_uptake_input_t) :: got, a1, b, a2
  type(crop_root_uptake_assembly_diagnostics_t) :: diag
  real(real64) :: nan_value
  integer :: status, contract_status

  nan_value = ieee_value(0.0_real64, ieee_quiet_nan)

  call validate_crop_root_state_view(inactive, 0, status, contract_status)
  call require(status == CROP_ROOT_ASSEMBLY_INVALID_ACTIVE_NODES, 'active_nodes <= 0 fails closed')

  et%potential_transpiration = nan_value
  call assemble_crop_root_uptake_input(inactive, et, 4, got, diag)
  call require(diag%status == CROP_ROOT_ASSEMBLY_OK, 'inactive assembly status')
  call require(diag%snapshot_validated .and. diag%assembled, 'inactive assembly completed')
  call require(.not. diag%et_result_consumed, 'inactive route does not consume ET')
  call require(.not. got%crop_emerged .and. got%rooted_nodes == 0, 'inactive canonical scalar fields')
  call require(abs(got%potential_transpiration) <= tiny(1.0_real64), 'inactive canonical ptra zero')
  call require(.not. allocated(got%cumulative_root_fraction), 'inactive canonical distribution absent')
  call validate_crop_root_uptake_input(got, 4, contract_status)
  call require(contract_status == CROP_ROOT_INPUT_OK, 'inactive assembled DTO validates')
  write(*,'(A)') 'FWOF13_INACTIVE_VIEW_IGNORES_INVALID_ET_AND_EMITS_CANONICAL_DTO=PASS'

  stale_inactive%crop_emerged = .false.
  stale_inactive%rooted_nodes = 1
  allocate(stale_inactive%cumulative_root_fraction(2))
  stale_inactive%cumulative_root_fraction = [0.0_real64, 1.0_real64]
  et%potential_transpiration = 0.15_real64
  call assemble_crop_root_uptake_input(stale_inactive, et, 4, got, diag)
  call require(diag%status == CROP_ROOT_ASSEMBLY_INVALID_SNAPSHOT, 'stale inactive snapshot rejected')
  call require(diag%crop_contract_status == CROP_ROOT_INPUT_NOT_CANONICAL, 'stale inactive detail preserved')
  call require(.not. diag%et_result_consumed .and. .not. diag%assembled, 'stale inactive rejected before ET')
  write(*,'(A)') 'FWOF13_NONCANONICAL_INACTIVE_SNAPSHOT_FAILS_CLOSED=PASS'

  zero_root%crop_emerged = .true.
  zero_root%rooted_nodes = 0
  et%potential_transpiration = 0.12_real64
  call assemble_crop_root_uptake_input(zero_root, et, 4, got, diag)
  call require(diag%status == CROP_ROOT_ASSEMBLY_OK, 'active zero-root status')
  call require(diag%et_result_consumed .and. diag%assembled, 'active zero-root consumes ET and assembles')
  call require(got%crop_emerged .and. got%rooted_nodes == 0, 'active zero-root identity')
  call require(same_bits(got%potential_transpiration, 0.12_real64), 'active zero-root ptra exact')
  call require(.not. allocated(got%cumulative_root_fraction), 'active zero-root distribution absent')
  call validate_crop_root_uptake_input(got, 4, contract_status)
  call require(contract_status == CROP_ROOT_INPUT_OK, 'active zero-root DTO validates')
  write(*,'(A)') 'FWOF13_ACTIVE_ZERO_ROOT_EXACT_ASSEMBLY=PASS'

  call configure_rooted(rooted_a, [0.0_real64, 0.15_real64, 0.50_real64, 1.0_real64])
  rooted_a_before = rooted_a
  et%potential_transpiration = 0.30_real64
  et_before = et
  call assemble_crop_root_uptake_input(rooted_a, et, 4, got, diag)
  call require(diag%status == CROP_ROOT_ASSEMBLY_OK, 'active rooted A status')
  call require(diag%snapshot_validated .and. diag%et_result_consumed .and. diag%assembled, 'active rooted A diagnostics')
  call require(got%crop_emerged .and. got%rooted_nodes == 3, 'active rooted A scalar mapping')
  call require(same_bits(got%potential_transpiration, et%potential_transpiration), 'active rooted A ptra exact')
  call require(all_bits_identical(got%cumulative_root_fraction, rooted_a%cumulative_root_fraction), 'active rooted A distribution exact')
  call validate_crop_root_uptake_input(got, 4, contract_status)
  call require(contract_status == CROP_ROOT_INPUT_OK, 'active rooted A DTO validates')
  call require(root_views_identical(rooted_a, rooted_a_before), 'snapshot read only')
  call require(same_bits(et%potential_transpiration, et_before%potential_transpiration), 'ET result read only')
  write(*,'(A)') 'FWOF13_ACTIVE_ROOTED_EXACT_ASSEMBLY=PASS'
  write(*,'(A)') 'FWOF13_SNAPSHOT_AND_ET_RESULT_READ_ONLY=PASS'

  et%potential_transpiration = nan_value
  call assemble_crop_root_uptake_input(rooted_a, et, 4, got, diag)
  call require(diag%status == CROP_ROOT_ASSEMBLY_INVALID_ET_RESULT, 'active NaN ptra rejected')
  call require(diag%snapshot_validated .and. diag%et_result_consumed .and. .not. diag%assembled, 'NaN rejection diagnostics')
  call require(.not. got%crop_emerged .and. .not. allocated(got%cumulative_root_fraction), 'NaN rejection clears output')

  et%potential_transpiration = -0.01_real64
  call assemble_crop_root_uptake_input(rooted_a, et, 4, got, diag)
  call require(diag%status == CROP_ROOT_ASSEMBLY_INVALID_ET_RESULT, 'active negative ptra rejected')
  write(*,'(A)') 'FWOF13_ACTIVE_INVALID_ET_FAILS_CLOSED=PASS'

  call configure_rooted(invalid_root, [0.0_real64, 0.70_real64, 0.60_real64, 1.0_real64])
  et%potential_transpiration = 0.30_real64
  call assemble_crop_root_uptake_input(invalid_root, et, 4, got, diag)
  call require(diag%status == CROP_ROOT_ASSEMBLY_INVALID_SNAPSHOT, 'invalid root distribution rejected')
  call require(.not. diag%et_result_consumed, 'invalid snapshot rejected before ET consumption')
  write(*,'(A)') 'FWOF13_INVALID_ROOT_SNAPSHOT_FAILS_BEFORE_ET=PASS'

  et%potential_transpiration = 0.30_real64
  call assemble_crop_root_uptake_input(rooted_a, et, 4, a1, diag)
  call require(diag%status == CROP_ROOT_ASSEMBLY_OK, 'A1 assembly')
  call configure_rooted(rooted_b, [0.0_real64, 0.25_real64, 0.70_real64, 1.0_real64])
  et%potential_transpiration = 0.42_real64
  call assemble_crop_root_uptake_input(rooted_b, et, 4, b, diag)
  call require(diag%status == CROP_ROOT_ASSEMBLY_OK, 'B assembly')
  call require(.not. inputs_identical(a1, b), 'B distinct from A')
  et%potential_transpiration = 0.30_real64
  call assemble_crop_root_uptake_input(rooted_a, et, 4, a2, diag)
  call require(diag%status == CROP_ROOT_ASSEMBLY_OK, 'A2 assembly')
  call require(inputs_identical(a1, a2), 'A/B/A assembly identity')
  write(*,'(A)') 'FWOF13_A_B_A_ASSEMBLY_IDENTITY=PASS'

  write(*,'(A)') 'FWOF13_CROP_ROOT_SNAPSHOT_ASSEMBLY_TEST PASS'

contains

  subroutine configure_rooted(view, distribution)
    type(crop_root_state_view_t), intent(out) :: view
    real(real64), intent(in) :: distribution(4)
    view%crop_emerged = .true.
    view%rooted_nodes = 3
    allocate(view%cumulative_root_fraction(4))
    view%cumulative_root_fraction = distribution
  end subroutine configure_rooted

  logical function root_views_identical(a, b) result(equal)
    type(crop_root_state_view_t), intent(in) :: a, b
    equal = .false.
    if (a%crop_emerged .neqv. b%crop_emerged) return
    if (a%rooted_nodes /= b%rooted_nodes) return
    if (allocated(a%cumulative_root_fraction) .neqv. allocated(b%cumulative_root_fraction)) return
    if (allocated(a%cumulative_root_fraction)) then
      if (.not. all_bits_identical(a%cumulative_root_fraction, b%cumulative_root_fraction)) return
    end if
    equal = .true.
  end function root_views_identical

  logical function inputs_identical(a, b) result(equal)
    type(crop_root_uptake_input_t), intent(in) :: a, b
    equal = .false.
    if (a%crop_emerged .neqv. b%crop_emerged) return
    if (.not. same_bits(a%potential_transpiration, b%potential_transpiration)) return
    if (a%rooted_nodes /= b%rooted_nodes) return
    if (allocated(a%cumulative_root_fraction) .neqv. allocated(b%cumulative_root_fraction)) return
    if (allocated(a%cumulative_root_fraction)) then
      if (.not. all_bits_identical(a%cumulative_root_fraction, b%cumulative_root_fraction)) return
    end if
    equal = .true.
  end function inputs_identical

  logical function same_bits(a, b) result(equal)
    real(real64), intent(in) :: a, b
    integer(int64) :: ia, ib
    ia = transfer(a, ia)
    ib = transfer(b, ib)
    equal = ia == ib
  end function same_bits

  logical function all_bits_identical(a, b) result(equal)
    real(real64), intent(in) :: a(:), b(:)
    integer :: i
    equal = size(a) == size(b)
    if (.not. equal) return
    do i = 1, size(a)
      if (.not. same_bits(a(i), b(i))) then
        equal = .false.
        return
      end if
    end do
  end function all_bits_identical

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'FWOF13_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require

end program test_fwof13_crop_root_snapshot_assembly

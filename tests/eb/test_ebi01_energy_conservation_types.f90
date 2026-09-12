program test_energy_conservation_types
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_energy_conservation_types
  implicit none
  integer(int64), parameter :: SOIL = 1_int64, CANOPY = 2_int64
  integer(int64) :: all_ids(2), soil_only(1), canopy_only(1), dup_ids(2)
  real(real64) :: initial_energy(2), final_energy(2)
  type(energy_storage_snapshot_t) :: initial_snapshot, final_snapshot, invalid_snapshot
  type(energy_transfer_t) :: transfers(3), invalid_transfer
  type(energy_balance_t) :: balance
  integer :: status

  all_ids = [SOIL, CANOPY]
  soil_only = [SOIL]
  canopy_only = [CANOPY]
  initial_energy = [100.0_real64, 20.0_real64]
  final_energy = [120.0_real64, 25.0_real64]

  initial_snapshot = make_energy_storage_snapshot(all_ids, initial_energy, status)
  call require(status == ENERGY_CONSERVATION_OK .and. initial_snapshot%ready(), 'initial snapshot')
  final_snapshot = make_energy_storage_snapshot(all_ids, final_energy, status)
  call require(status == ENERGY_CONSERVATION_OK .and. final_snapshot%ready(), 'final snapshot')

  transfers(1) = make_energy_transfer(ENERGY_EXTERNAL_COMPONENT, SOIL, 30.0_real64, status)
  call require(status == ENERGY_CONSERVATION_OK, 'external to soil transfer')
  transfers(2) = make_energy_transfer(SOIL, CANOPY, 10.0_real64, status)
  call require(status == ENERGY_CONSERVATION_OK, 'soil to canopy transfer')
  transfers(3) = make_energy_transfer(CANOPY, ENERGY_EXTERNAL_COMPONENT, 5.0_real64, status)
  call require(status == ENERGY_CONSERVATION_OK, 'canopy to external transfer')

  call project_energy_balance(initial_snapshot, final_snapshot, transfers, all_ids, balance, status)
  call require(status == ENERGY_CONSERVATION_OK .and. balance%available, 'outer control volume balance')
  call require(exact(balance%delta_storage_j_m2, 25.0_real64), 'outer delta storage')
  call require(exact(balance%boundary_input_j_m2, 30.0_real64), 'outer boundary input')
  call require(exact(balance%boundary_output_j_m2, 5.0_real64), 'outer boundary output')
  call require(exact(balance%internal_transfer_j_m2, 10.0_real64), 'outer internal transfer diagnostic')
  call require(exact(balance%residual_j_m2, 0.0_real64), 'outer residual')
  print '(a)', 'EBI01_INTERNAL_TRANSFER_CANCELS_IN_OUTER_CV=PASS'

  call project_energy_balance(initial_snapshot, final_snapshot, transfers, soil_only, balance, status)
  call require(status == ENERGY_CONSERVATION_OK .and. exact(balance%delta_storage_j_m2, 20.0_real64), &
       'soil delta storage')
  call require(exact(balance%boundary_input_j_m2, 30.0_real64), 'soil input')
  call require(exact(balance%boundary_output_j_m2, 10.0_real64), 'soil output')
  call require(exact(balance%internal_transfer_j_m2, 0.0_real64), 'soil no internal transfer')
  call require(exact(balance%residual_j_m2, 0.0_real64), 'soil residual')

  call project_energy_balance(initial_snapshot, final_snapshot, transfers, canopy_only, balance, status)
  call require(status == ENERGY_CONSERVATION_OK .and. exact(balance%delta_storage_j_m2, 5.0_real64), &
       'canopy delta storage')
  call require(exact(balance%boundary_input_j_m2, 10.0_real64), 'canopy input')
  call require(exact(balance%boundary_output_j_m2, 5.0_real64), 'canopy output')
  call require(exact(balance%residual_j_m2, 0.0_real64), 'canopy residual')
  print '(a)', 'EBI01_NESTED_CONTROL_VOLUMES_CLOSE=PASS'

  invalid_transfer = make_energy_transfer(SOIL, CANOPY, -1.0_real64, status)
  call require(status == ENERGY_CONSERVATION_INVALID_TRANSFER .and. .not. invalid_transfer%ready(), &
       'negative directed transfer rejected')
  dup_ids = [SOIL, SOIL]
  invalid_snapshot = make_energy_storage_snapshot(dup_ids, initial_energy, status)
  call require(status == ENERGY_CONSERVATION_DUPLICATE_COMPONENT .and. .not. invalid_snapshot%ready(), &
       'duplicate component rejected')
  print '(a)', 'EBI01_INVALID_ACCOUNTING_INPUT_REJECTED=PASS'
  print '(a)', 'EBI01_ENERGY_CONSERVATION_TYPES_TEST PASS'
contains
  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(a,a)') 'FAIL ', trim(label)
      error stop 1
    end if
  end subroutine require

  logical function exact(a, b) result(equal)
    real(real64), intent(in) :: a, b
    integer(int64) :: ai, bi
    ai = transfer(a, ai)
    bi = transfer(b, bi)
    equal = ai == bi
  end function exact
end program test_energy_conservation_types

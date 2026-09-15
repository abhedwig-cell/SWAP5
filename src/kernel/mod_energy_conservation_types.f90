module mod_energy_conservation_types
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: ENERGY_CONSERVATION_OK = 0
  integer, parameter, public :: ENERGY_CONSERVATION_INVALID_ARGUMENT = 1
  integer, parameter, public :: ENERGY_CONSERVATION_INVALID_COMPONENT = 2
  integer, parameter, public :: ENERGY_CONSERVATION_DUPLICATE_COMPONENT = 3
  integer, parameter, public :: ENERGY_CONSERVATION_INVALID_TRANSFER = 4
  integer, parameter, public :: ENERGY_CONSERVATION_MISSING_COMPONENT = 5
  integer, parameter, public :: ENERGY_CONSERVATION_ARITHMETIC_FAILURE = 6
  integer(int64), parameter, public :: ENERGY_EXTERNAL_COMPONENT = 0_int64

  type, public :: energy_transfer_t
    private
    logical :: initialized = .false.
    integer(int64) :: source_component_id = ENERGY_EXTERNAL_COMPONENT
    integer(int64) :: target_component_id = ENERGY_EXTERNAL_COMPONENT
    real(real64) :: transfer_j_m2 = 0.0_real64
  contains
    procedure, public :: ready => energy_transfer_ready
    procedure, public :: source_component => energy_transfer_source_component
    procedure, public :: target_component => energy_transfer_target_component
    procedure, public :: amount_j_m2 => energy_transfer_amount
  end type energy_transfer_t

  type, public :: energy_storage_snapshot_t
    private
    logical :: initialized = .false.
    integer(int64), allocatable :: component_ids(:)
    real(real64), allocatable :: energy_j_m2(:)
  contains
    procedure, public :: ready => energy_snapshot_ready
    procedure, public :: component_count => energy_snapshot_component_count
    procedure, public :: contains_component => energy_snapshot_contains_component
    procedure, public :: component_energy => energy_snapshot_component_energy
  end type energy_storage_snapshot_t

  type, public :: energy_balance_t
    logical :: available = .false.
    real(real64) :: initial_storage_j_m2 = 0.0_real64
    real(real64) :: final_storage_j_m2 = 0.0_real64
    real(real64) :: delta_storage_j_m2 = 0.0_real64
    real(real64) :: boundary_input_j_m2 = 0.0_real64
    real(real64) :: boundary_output_j_m2 = 0.0_real64
    real(real64) :: internal_transfer_j_m2 = 0.0_real64
    real(real64) :: residual_j_m2 = 0.0_real64
  end type energy_balance_t

  public :: make_energy_transfer
  public :: make_energy_storage_snapshot
  public :: project_energy_balance

contains

  function make_energy_transfer(source_component_id, target_component_id, amount_j_m2, status) result(transfer_record)
    integer(int64), intent(in) :: source_component_id, target_component_id
    real(real64), intent(in) :: amount_j_m2
    integer, intent(out) :: status
    type(energy_transfer_t) :: transfer_record

    transfer_record = energy_transfer_t()
    status = ENERGY_CONSERVATION_INVALID_TRANSFER
    if (source_component_id < ENERGY_EXTERNAL_COMPONENT) return
    if (target_component_id < ENERGY_EXTERNAL_COMPONENT) return
    if (source_component_id == ENERGY_EXTERNAL_COMPONENT .and. &
        target_component_id == ENERGY_EXTERNAL_COMPONENT) return
    if (source_component_id == target_component_id) return
    if (.not. ieee_is_finite(amount_j_m2) .or. amount_j_m2 < 0.0_real64) return

    transfer_record%source_component_id = source_component_id
    transfer_record%target_component_id = target_component_id
    transfer_record%transfer_j_m2 = amount_j_m2
    transfer_record%initialized = .true.
    status = ENERGY_CONSERVATION_OK
  end function make_energy_transfer

  pure logical function energy_transfer_ready(self) result(ready)
    class(energy_transfer_t), intent(in) :: self
    ready = self%initialized .and. self%source_component_id >= ENERGY_EXTERNAL_COMPONENT .and. &
         self%target_component_id >= ENERGY_EXTERNAL_COMPONENT .and. &
         .not. (self%source_component_id == ENERGY_EXTERNAL_COMPONENT .and. &
                self%target_component_id == ENERGY_EXTERNAL_COMPONENT) .and. &
         self%source_component_id /= self%target_component_id .and. &
         ieee_is_finite(self%transfer_j_m2) .and. self%transfer_j_m2 >= 0.0_real64
  end function energy_transfer_ready

  pure integer(int64) function energy_transfer_source_component(self) result(component_id)
    class(energy_transfer_t), intent(in) :: self
    component_id = self%source_component_id
  end function energy_transfer_source_component

  pure integer(int64) function energy_transfer_target_component(self) result(component_id)
    class(energy_transfer_t), intent(in) :: self
    component_id = self%target_component_id
  end function energy_transfer_target_component

  pure real(real64) function energy_transfer_amount(self) result(amount)
    class(energy_transfer_t), intent(in) :: self
    amount = self%transfer_j_m2
  end function energy_transfer_amount

  function make_energy_storage_snapshot(component_ids, energy_j_m2, status) result(snapshot)
    integer(int64), intent(in) :: component_ids(:)
    real(real64), intent(in) :: energy_j_m2(:)
    integer, intent(out) :: status
    type(energy_storage_snapshot_t) :: snapshot
    integer :: i, j

    snapshot = energy_storage_snapshot_t()
    status = ENERGY_CONSERVATION_INVALID_ARGUMENT
    if (size(component_ids) <= 0 .or. size(component_ids) /= size(energy_j_m2)) return

    do i = 1, size(component_ids)
      status = ENERGY_CONSERVATION_INVALID_COMPONENT
      if (component_ids(i) <= ENERGY_EXTERNAL_COMPONENT) return
      if (.not. ieee_is_finite(energy_j_m2(i))) return
      do j = 1, i - 1
        status = ENERGY_CONSERVATION_DUPLICATE_COMPONENT
        if (component_ids(i) == component_ids(j)) return
      end do
    end do

    allocate(snapshot%component_ids(size(component_ids)), snapshot%energy_j_m2(size(energy_j_m2)))
    snapshot%component_ids = component_ids
    snapshot%energy_j_m2 = energy_j_m2
    snapshot%initialized = .true.
    status = ENERGY_CONSERVATION_OK
  end function make_energy_storage_snapshot

  pure logical function energy_snapshot_ready(self) result(ready)
    class(energy_storage_snapshot_t), intent(in) :: self
    integer :: i, j

    ready = .false.
    if (.not. self%initialized) return
    if (.not. allocated(self%component_ids) .or. .not. allocated(self%energy_j_m2)) return
    if (size(self%component_ids) <= 0 .or. size(self%component_ids) /= size(self%energy_j_m2)) return
    do i = 1, size(self%component_ids)
      if (self%component_ids(i) <= ENERGY_EXTERNAL_COMPONENT) return
      if (.not. ieee_is_finite(self%energy_j_m2(i))) return
      do j = 1, i - 1
        if (self%component_ids(i) == self%component_ids(j)) return
      end do
    end do
    ready = .true.
  end function energy_snapshot_ready

  pure integer function energy_snapshot_component_count(self) result(count)
    class(energy_storage_snapshot_t), intent(in) :: self
    count = 0
    if (.not. self%ready()) return
    count = size(self%component_ids)
  end function energy_snapshot_component_count

  pure logical function energy_snapshot_contains_component(self, component_id) result(found)
    class(energy_storage_snapshot_t), intent(in) :: self
    integer(int64), intent(in) :: component_id
    integer :: i

    found = .false.
    if (.not. self%ready()) return
    do i = 1, size(self%component_ids)
      if (self%component_ids(i) == component_id) then
        found = .true.
        return
      end if
    end do
  end function energy_snapshot_contains_component

  pure subroutine energy_snapshot_component_energy(self, component_id, value_j_m2, available)
    class(energy_storage_snapshot_t), intent(in) :: self
    integer(int64), intent(in) :: component_id
    real(real64), intent(out) :: value_j_m2
    logical, intent(out) :: available
    integer :: i

    value_j_m2 = 0.0_real64
    available = .false.
    if (.not. self%ready()) return
    do i = 1, size(self%component_ids)
      if (self%component_ids(i) == component_id) then
        value_j_m2 = self%energy_j_m2(i)
        available = .true.
        return
      end if
    end do
  end subroutine energy_snapshot_component_energy

  subroutine project_energy_balance(initial_snapshot, final_snapshot, transfers, control_volume_ids, balance, status)
    type(energy_storage_snapshot_t), intent(in) :: initial_snapshot, final_snapshot
    type(energy_transfer_t), intent(in) :: transfers(:)
    integer(int64), intent(in) :: control_volume_ids(:)
    type(energy_balance_t), intent(out) :: balance
    integer, intent(out) :: status
    integer :: i, j
    real(real64) :: initial_value, final_value, amount
    integer(int64) :: source_id, target_id
    logical :: initial_available, final_available, source_inside, target_inside

    balance = energy_balance_t()
    status = ENERGY_CONSERVATION_INVALID_ARGUMENT
    if (.not. initial_snapshot%ready() .or. .not. final_snapshot%ready()) return
    if (size(control_volume_ids) <= 0) return

    do i = 1, size(control_volume_ids)
      status = ENERGY_CONSERVATION_INVALID_COMPONENT
      if (control_volume_ids(i) <= ENERGY_EXTERNAL_COMPONENT) return
      do j = 1, i - 1
        status = ENERGY_CONSERVATION_DUPLICATE_COMPONENT
        if (control_volume_ids(i) == control_volume_ids(j)) return
      end do
      call initial_snapshot%component_energy(control_volume_ids(i), initial_value, initial_available)
      call final_snapshot%component_energy(control_volume_ids(i), final_value, final_available)
      status = ENERGY_CONSERVATION_MISSING_COMPONENT
      if (.not. initial_available .or. .not. final_available) return
      status = ENERGY_CONSERVATION_ARITHMETIC_FAILURE
      if (.not. safe_accumulate(balance%initial_storage_j_m2, initial_value)) return
      if (.not. safe_accumulate(balance%final_storage_j_m2, final_value)) return
    end do

    do i = 1, size(transfers)
      status = ENERGY_CONSERVATION_INVALID_TRANSFER
      if (.not. transfers(i)%ready()) return
      source_id = transfers(i)%source_component()
      target_id = transfers(i)%target_component()
      amount = transfers(i)%amount_j_m2()
      status = ENERGY_CONSERVATION_MISSING_COMPONENT
      if (source_id /= ENERGY_EXTERNAL_COMPONENT) then
        if (.not. initial_snapshot%contains_component(source_id) .or. &
            .not. final_snapshot%contains_component(source_id)) return
      end if
      if (target_id /= ENERGY_EXTERNAL_COMPONENT) then
        if (.not. initial_snapshot%contains_component(target_id) .or. &
            .not. final_snapshot%contains_component(target_id)) return
      end if
      status = ENERGY_CONSERVATION_ARITHMETIC_FAILURE
      source_inside = component_in_set(source_id, control_volume_ids)
      target_inside = component_in_set(target_id, control_volume_ids)
      if (.not. source_inside .and. target_inside) then
        if (.not. safe_accumulate(balance%boundary_input_j_m2, amount)) return
      else if (source_inside .and. .not. target_inside) then
        if (.not. safe_accumulate(balance%boundary_output_j_m2, amount)) return
      else if (source_inside .and. target_inside) then
        if (.not. safe_accumulate(balance%internal_transfer_j_m2, amount)) return
      end if
    end do

    status = ENERGY_CONSERVATION_ARITHMETIC_FAILURE
    if (.not. safe_difference(balance%final_storage_j_m2, balance%initial_storage_j_m2, &
         balance%delta_storage_j_m2)) return
    if (.not. safe_balance_residual(balance%delta_storage_j_m2, balance%boundary_input_j_m2, &
         balance%boundary_output_j_m2, balance%residual_j_m2)) return

    balance%available = .true.
    status = ENERGY_CONSERVATION_OK
  end subroutine project_energy_balance

  pure logical function component_in_set(component_id, ids) result(found)
    integer(int64), intent(in) :: component_id
    integer(int64), intent(in) :: ids(:)
    integer :: i

    found = .false.
    if (component_id == ENERGY_EXTERNAL_COMPONENT) return
    do i = 1, size(ids)
      if (ids(i) == component_id) then
        found = .true.
        return
      end if
    end do
  end function component_in_set

  logical function safe_accumulate(accumulator, addend) result(ok)
    real(real64), intent(inout) :: accumulator
    real(real64), intent(in) :: addend
    real(real64) :: limit

    ok = .false.
    if (.not. ieee_is_finite(accumulator) .or. .not. ieee_is_finite(addend)) return
    limit = huge(0.0_real64)
    if (addend > 0.0_real64) then
      if (accumulator > limit - addend) return
    else if (addend < 0.0_real64) then
      if (accumulator < -limit - addend) return
    end if
    accumulator = accumulator + addend
    ok = ieee_is_finite(accumulator)
  end function safe_accumulate

  logical function safe_difference(a, b, value) result(ok)
    real(real64), intent(in) :: a, b
    real(real64), intent(out) :: value
    real(real64) :: work

    value = 0.0_real64
    work = a
    ok = safe_accumulate(work, -b)
    if (ok) value = work
  end function safe_difference

  logical function safe_balance_residual(delta_storage, boundary_input, boundary_output, residual) result(ok)
    real(real64), intent(in) :: delta_storage, boundary_input, boundary_output
    real(real64), intent(out) :: residual
    real(real64) :: work

    residual = 0.0_real64
    work = delta_storage
    ok = safe_accumulate(work, -boundary_input)
    if (.not. ok) return
    ok = safe_accumulate(work, boundary_output)
    if (ok) residual = work
  end function safe_balance_residual

end module mod_energy_conservation_types

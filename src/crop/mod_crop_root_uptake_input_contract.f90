module mod_crop_root_uptake_input_contract
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: CROP_ROOT_INPUT_OK = 0
  integer, parameter, public :: CROP_ROOT_INPUT_INVALID_ACTIVE_NODES = 1
  integer, parameter, public :: CROP_ROOT_INPUT_NONFINITE_PTRA = 2
  integer, parameter, public :: CROP_ROOT_INPUT_NEGATIVE_PTRA = 3
  integer, parameter, public :: CROP_ROOT_INPUT_ROOTED_NODES_RANGE = 4
  integer, parameter, public :: CROP_ROOT_INPUT_DISTRIBUTION_MISSING = 5
  integer, parameter, public :: CROP_ROOT_INPUT_DISTRIBUTION_SIZE = 6
  integer, parameter, public :: CROP_ROOT_INPUT_DISTRIBUTION_INVALID = 7
  integer, parameter, public :: CROP_ROOT_INPUT_PROVIDER_REJECTED = 8
  integer, parameter, public :: CROP_ROOT_INPUT_NOT_CANONICAL = 9

  real(real64), parameter :: ROOT_FRACTION_TOL = 256.0_real64 * epsilon(1.0_real64)

  type, public :: crop_root_uptake_input_t
    logical :: crop_emerged = .false.
    real(real64) :: potential_transpiration = 0.0_real64
    integer :: rooted_nodes = 0
    real(real64), allocatable :: cumulative_root_fraction(:)
  end type crop_root_uptake_input_t

  type, abstract, public :: crop_root_uptake_input_provider_t
  contains
    procedure(crop_root_uptake_provider_evaluate_iface), deferred :: evaluate
  end type crop_root_uptake_input_provider_t

  abstract interface
    subroutine crop_root_uptake_provider_evaluate_iface(self, raw_input, provider_status)
      import :: crop_root_uptake_input_provider_t, crop_root_uptake_input_t
      class(crop_root_uptake_input_provider_t), intent(in) :: self
      type(crop_root_uptake_input_t), intent(out) :: raw_input
      integer, intent(out) :: provider_status
    end subroutine crop_root_uptake_provider_evaluate_iface
  end interface

  public :: canonicalize_crop_root_uptake_input
  public :: validate_crop_root_uptake_input
  public :: evaluate_crop_root_uptake_input

contains

  subroutine canonicalize_crop_root_uptake_input(raw_input, active_nodes, input, status)
    type(crop_root_uptake_input_t), intent(in) :: raw_input
    integer, intent(in) :: active_nodes
    type(crop_root_uptake_input_t), intent(out) :: input
    integer, intent(out) :: status

    integer :: i

    input = crop_root_uptake_input_t()
    status = CROP_ROOT_INPUT_OK

    if (active_nodes <= 0) then
      status = CROP_ROOT_INPUT_INVALID_ACTIVE_NODES
      return
    end if

    ! Legacy crop state may retain stale values outside the emerged-crop route.
    ! Inactive crop therefore canonicalizes without consulting those values.
    if (.not. raw_input%crop_emerged) return

    if (.not. ieee_is_finite(raw_input%potential_transpiration)) then
      status = CROP_ROOT_INPUT_NONFINITE_PTRA
      return
    end if
    if (raw_input%potential_transpiration < 0.0_real64) then
      status = CROP_ROOT_INPUT_NEGATIVE_PTRA
      return
    end if
    if (raw_input%rooted_nodes < 0 .or. raw_input%rooted_nodes > active_nodes) then
      status = CROP_ROOT_INPUT_ROOTED_NODES_RANGE
      return
    end if

    input%crop_emerged = .true.
    input%potential_transpiration = raw_input%potential_transpiration
    input%rooted_nodes = raw_input%rooted_nodes

    ! An emerged crop without active roots needs no root-distribution storage.
    if (raw_input%rooted_nodes == 0) return

    if (.not. allocated(raw_input%cumulative_root_fraction)) then
      status = CROP_ROOT_INPUT_DISTRIBUTION_MISSING
      input = crop_root_uptake_input_t()
      return
    end if
    if (size(raw_input%cumulative_root_fraction) /= raw_input%rooted_nodes + 1) then
      status = CROP_ROOT_INPUT_DISTRIBUTION_SIZE
      input = crop_root_uptake_input_t()
      return
    end if
    if (.not. all(ieee_is_finite(raw_input%cumulative_root_fraction))) then
      status = CROP_ROOT_INPUT_DISTRIBUTION_INVALID
      input = crop_root_uptake_input_t()
      return
    end if
    if (abs(raw_input%cumulative_root_fraction(1)) > ROOT_FRACTION_TOL .or. &
        abs(raw_input%cumulative_root_fraction(raw_input%rooted_nodes + 1) - 1.0_real64) > ROOT_FRACTION_TOL) then
      status = CROP_ROOT_INPUT_DISTRIBUTION_INVALID
      input = crop_root_uptake_input_t()
      return
    end if

    do i = 2, raw_input%rooted_nodes + 1
      if (raw_input%cumulative_root_fraction(i) < raw_input%cumulative_root_fraction(i - 1)) then
        status = CROP_ROOT_INPUT_DISTRIBUTION_INVALID
        input = crop_root_uptake_input_t()
        return
      end if
    end do

    allocate(input%cumulative_root_fraction(raw_input%rooted_nodes + 1))
    input%cumulative_root_fraction = raw_input%cumulative_root_fraction
    input%cumulative_root_fraction(1) = 0.0_real64
    input%cumulative_root_fraction(raw_input%rooted_nodes + 1) = 1.0_real64
  end subroutine canonicalize_crop_root_uptake_input

  subroutine validate_crop_root_uptake_input(input, active_nodes, status)
    type(crop_root_uptake_input_t), intent(in) :: input
    integer, intent(in) :: active_nodes
    integer, intent(out) :: status

    type(crop_root_uptake_input_t) :: canonical

    call canonicalize_crop_root_uptake_input(input, active_nodes, canonical, status)
    if (status /= CROP_ROOT_INPUT_OK) return

    if (.not. input%crop_emerged) then
      if (abs(input%potential_transpiration) > 0.0_real64 .or. input%rooted_nodes /= 0 .or. &
          allocated(input%cumulative_root_fraction)) status = CROP_ROOT_INPUT_NOT_CANONICAL
      return
    end if

    if (input%rooted_nodes == 0) then
      if (allocated(input%cumulative_root_fraction)) status = CROP_ROOT_INPUT_NOT_CANONICAL
      return
    end if

    if (maxval(abs(input%cumulative_root_fraction - canonical%cumulative_root_fraction)) > ROOT_FRACTION_TOL) then
      status = CROP_ROOT_INPUT_NOT_CANONICAL
    end if
  end subroutine validate_crop_root_uptake_input

  subroutine evaluate_crop_root_uptake_input(provider, active_nodes, input, status, provider_status)
    class(crop_root_uptake_input_provider_t), intent(in) :: provider
    integer, intent(in) :: active_nodes
    type(crop_root_uptake_input_t), intent(out) :: input
    integer, intent(out) :: status
    integer, intent(out), optional :: provider_status

    type(crop_root_uptake_input_t) :: raw_input
    integer :: raw_provider_status

    input = crop_root_uptake_input_t()
    status = CROP_ROOT_INPUT_OK
    raw_provider_status = CROP_ROOT_INPUT_OK

    call provider%evaluate(raw_input, raw_provider_status)
    if (present(provider_status)) provider_status = raw_provider_status

    if (raw_provider_status /= CROP_ROOT_INPUT_OK) then
      status = CROP_ROOT_INPUT_PROVIDER_REJECTED
      return
    end if

    call canonicalize_crop_root_uptake_input(raw_input, active_nodes, input, status)
  end subroutine evaluate_crop_root_uptake_input

end module mod_crop_root_uptake_input_contract

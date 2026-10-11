module mod_modflow6_api_binding
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: int32, int64, real64
  use mod_modflow6_linear_response_backend, only: modflow6_linear_boundary_term_t, &
       MODFLOW6_LINEAR_BACKEND_OK
  implicit none
  private

  integer, parameter, public :: MODFLOW6_API_BINDING_OK = 0
  integer, parameter, public :: MODFLOW6_API_BINDING_INVALID_PACKAGE = 1
  integer, parameter, public :: MODFLOW6_API_BINDING_INVALID_COUNT = 2
  integer, parameter, public :: MODFLOW6_API_BINDING_INVALID_BINDING = 3
  integer, parameter, public :: MODFLOW6_API_BINDING_DUPLICATE_BINDING = 4
  integer, parameter, public :: MODFLOW6_API_BINDING_TERM_MATCH = 5
  integer, parameter, public :: MODFLOW6_API_BINDING_INVALID_TERM = 6
  integer, parameter, public :: MODFLOW6_API_BINDING_NONFINITE_TERM = 7

  type, public :: modflow6_api_slot_binding_t
    integer(int64) :: groundwater_cell_id = 0_int64
    integer :: package_slot = 0
    integer(int32) :: modflow_node_id = 0_int32
  end type modflow6_api_slot_binding_t

  public :: publish_modflow6_api_terms

contains

  subroutine publish_modflow6_api_terms(bindings, terms, maxbound, nodelist, hcof, rhs, nbound, status)
    type(modflow6_api_slot_binding_t), intent(in) :: bindings(:)
    type(modflow6_linear_boundary_term_t), intent(in) :: terms(:)
    integer(int32), intent(in) :: maxbound
    integer(int32), intent(inout) :: nodelist(:)
    real(real64), intent(inout) :: hcof(:)
    real(real64), intent(inout) :: rhs(:)
    integer(int32), intent(inout) :: nbound
    integer, intent(out) :: status

    integer, allocatable :: term_index(:)
    integer :: i, j, n, match_count, match_index

    status = MODFLOW6_API_BINDING_INVALID_PACKAGE

    if (maxbound <= 0_int32) return
    if (size(nodelist) < int(maxbound)) return
    if (size(hcof) < int(maxbound)) return
    if (size(rhs) < int(maxbound)) return

    n = size(bindings)

    status = MODFLOW6_API_BINDING_INVALID_COUNT
    if (n <= 0) return
    if (size(terms) /= n) return
    if (n > int(maxbound)) return

    allocate(term_index(n))
    term_index = 0

    do i = 1, n
      status = MODFLOW6_API_BINDING_INVALID_BINDING
      if (bindings(i)%groundwater_cell_id <= 0_int64) return
      if (bindings(i)%package_slot < 1 .or. bindings(i)%package_slot > n) return
      if (bindings(i)%modflow_node_id <= 0_int32) return

      do j = 1, i - 1
        status = MODFLOW6_API_BINDING_DUPLICATE_BINDING
        if (bindings(j)%groundwater_cell_id == bindings(i)%groundwater_cell_id) return
        if (bindings(j)%package_slot == bindings(i)%package_slot) return
      end do

      match_count = 0
      match_index = 0
      do j = 1, n
        if (terms(j)%groundwater_cell_id == bindings(i)%groundwater_cell_id) then
          match_count = match_count + 1
          match_index = j
        end if
      end do

      status = MODFLOW6_API_BINDING_TERM_MATCH
      if (match_count /= 1) return

      status = MODFLOW6_API_BINDING_INVALID_TERM
      if (.not. terms(match_index)%valid) return
      if (terms(match_index)%status /= MODFLOW6_LINEAR_BACKEND_OK) return
      if (terms(match_index)%groundwater_cell_id <= 0_int64) return

      status = MODFLOW6_API_BINDING_NONFINITE_TERM
      if (.not. ieee_is_finite(terms(match_index)%hcof_m2_per_day)) return
      if (.not. ieee_is_finite(terms(match_index)%rhs_m3_per_day)) return

      term_index(i) = match_index
    end do

    ! Validation above is intentionally complete before the first package write.
    do i = 1, n
      j = bindings(i)%package_slot
      nodelist(j) = bindings(i)%modflow_node_id
      hcof(j) = terms(term_index(i))%hcof_m2_per_day
      rhs(j) = terms(term_index(i))%rhs_m3_per_day
    end do
    nbound = int(n, int32)

    status = MODFLOW6_API_BINDING_OK
  end subroutine publish_modflow6_api_terms

end module mod_modflow6_api_binding

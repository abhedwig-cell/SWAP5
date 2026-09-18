module mod_modflow6_fgc34_c_bridge
  use, intrinsic :: iso_c_binding, only: c_double, c_int, c_int64_t
  use, intrinsic :: iso_fortran_env, only: int32, int64, real64
  use mod_modflow6_api_binding, only: modflow6_api_slot_binding_t, publish_modflow6_api_terms
  use mod_modflow6_linear_response_backend, only: modflow6_linear_boundary_term_t, &
       MODFLOW6_LINEAR_BACKEND_OK
  implicit none
  private

  public :: fgc34_publish_c

contains

  integer(c_int) function fgc34_publish_c( &
       n, binding_cell_ids, package_slots, modflow_node_ids, &
       term_cell_ids, term_hcof, term_rhs, maxbound, &
       nodelist, package_hcof, package_rhs, nbound) &
       bind(C, name="fgc34_publish_c") result(c_status)
    integer(c_int), value, intent(in) :: n
    integer(c_int64_t), intent(in) :: binding_cell_ids(*)
    integer(c_int), intent(in) :: package_slots(*)
    integer(c_int), intent(in) :: modflow_node_ids(*)
    integer(c_int64_t), intent(in) :: term_cell_ids(*)
    real(c_double), intent(in) :: term_hcof(*)
    real(c_double), intent(in) :: term_rhs(*)
    integer(c_int), value, intent(in) :: maxbound
    integer(c_int), intent(inout) :: nodelist(*)
    real(c_double), intent(inout) :: package_hcof(*)
    real(c_double), intent(inout) :: package_rhs(*)
    integer(c_int), intent(inout) :: nbound

    type(modflow6_api_slot_binding_t), allocatable :: bindings(:)
    type(modflow6_linear_boundary_term_t), allocatable :: terms(:)
    integer :: i
    integer :: status
    integer :: n_local
    integer(int32) :: maxbound_local

    n_local = int(n)
    maxbound_local = int(maxbound, int32)

    allocate(bindings(max(0, n_local)))
    allocate(terms(max(0, n_local)))

    do i = 1, n_local
      bindings(i)%groundwater_cell_id = int(binding_cell_ids(i), int64)
      bindings(i)%package_slot = int(package_slots(i))
      bindings(i)%modflow_node_id = int(modflow_node_ids(i), int32)

      terms(i) = modflow6_linear_boundary_term_t()
      terms(i)%valid = .true.
      terms(i)%status = MODFLOW6_LINEAR_BACKEND_OK
      terms(i)%groundwater_cell_id = int(term_cell_ids(i), int64)
      terms(i)%hcof_m2_per_day = real(term_hcof(i), real64)
      terms(i)%rhs_m3_per_day = real(term_rhs(i), real64)
    end do

    call publish_modflow6_api_terms( &
         bindings, terms, maxbound_local, &
         nodelist(1:int(maxbound_local)), &
         package_hcof(1:int(maxbound_local)), &
         package_rhs(1:int(maxbound_local)), &
         nbound, status)

    c_status = int(status, c_int)
  end function fgc34_publish_c

end module mod_modflow6_fgc34_c_bridge

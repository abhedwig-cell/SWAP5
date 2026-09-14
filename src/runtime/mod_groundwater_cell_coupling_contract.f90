module mod_groundwater_cell_coupling_contract
  use, intrinsic :: iso_fortran_env, only: int64
  implicit none
  private

  type, public :: groundwater_cell_interface_lineage_t
    integer(int64) :: coupling_id = 0_int64
    integer(int64) :: groundwater_lineage_id = 0_int64
    integer(int64) :: groundwater_origin_revision = -1_int64
    integer(int64) :: candidate_revision = -1_int64
    integer(int64), allocatable :: swap_lineage_ids(:)
    integer(int64), allocatable :: swap_origin_revisions(:)
  contains
    procedure, public :: valid => groundwater_cell_lineage_valid
  end type groundwater_cell_interface_lineage_t

contains

  pure logical function groundwater_cell_lineage_valid(self) result(valid)
    class(groundwater_cell_interface_lineage_t), intent(in) :: self
    integer :: i, j

    valid = .false.
    if (self%coupling_id <= 0_int64) return
    if (self%groundwater_lineage_id <= 0_int64) return
    if (self%groundwater_origin_revision < 0_int64) return
    if (self%candidate_revision < 0_int64) return
    if (.not. allocated(self%swap_lineage_ids)) return
    if (.not. allocated(self%swap_origin_revisions)) return
    if (size(self%swap_lineage_ids) <= 0) return
    if (size(self%swap_lineage_ids) /= size(self%swap_origin_revisions)) return

    do i = 1, size(self%swap_lineage_ids)
      if (self%swap_lineage_ids(i) <= 0_int64) return
      if (self%swap_origin_revisions(i) < 0_int64) return
      do j = i + 1, size(self%swap_lineage_ids)
        if (self%swap_lineage_ids(j) == self%swap_lineage_ids(i)) return
      end do
    end do
    valid = .true.
  end function groundwater_cell_lineage_valid

end module mod_groundwater_cell_coupling_contract

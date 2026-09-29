module mod_fmr_elastic_storage_maparea_profile_association
  implicit none
  private

  integer, parameter, public :: FMR_ELAS_MAPAREA_ID_LEN = 64
  integer, parameter, public :: FMR_ELAS_MAPAREA_PROFILE_OK = 0
  integer, parameter, public :: FMR_ELAS_MAPAREA_PROFILE_INVALID_REQUEST = 1
  integer, parameter, public :: FMR_ELAS_MAPAREA_PROFILE_NOT_FOUND = 2
  integer, parameter, public :: FMR_ELAS_MAPAREA_PROFILE_AMBIGUOUS = 3
  integer, parameter, public :: FMR_ELAS_MAPAREA_PROFILE_INVALID_SOURCE = 4

  type, public :: fmr_elastic_storage_maparea_profile_row_t
    character(len=FMR_ELAS_MAPAREA_ID_LEN) :: maparea_id = ''
    integer :: normalsoilprofile_id = 0
  end type fmr_elastic_storage_maparea_profile_row_t

  type, public :: fmr_elastic_storage_maparea_profile_diagnostics_t
    integer :: status = FMR_ELAS_MAPAREA_PROFILE_INVALID_REQUEST
    integer :: matches = 0
    integer :: matched_row = 0
    integer :: selected_profile_id = 0
  end type fmr_elastic_storage_maparea_profile_diagnostics_t

  public :: fmr_resolve_maparea_profile

contains

  subroutine fmr_resolve_maparea_profile(rows, requested_maparea_id, profile_id, diagnostics)
    type(fmr_elastic_storage_maparea_profile_row_t), intent(in) :: rows(:)
    character(len=*), intent(in) :: requested_maparea_id
    integer, intent(out) :: profile_id
    type(fmr_elastic_storage_maparea_profile_diagnostics_t), intent(out) :: diagnostics

    integer :: i, match_row, matches
    character(len=FMR_ELAS_MAPAREA_ID_LEN) :: requested

    profile_id = 0
    diagnostics = fmr_elastic_storage_maparea_profile_diagnostics_t()

    if (len_trim(requested_maparea_id) <= 0) return
    if (requested_maparea_id(1:1) == ' ') return
    if (len_trim(requested_maparea_id) > FMR_ELAS_MAPAREA_ID_LEN) return

    requested = ''
    requested = trim(requested_maparea_id)

    matches = 0
    match_row = 0
    do i = 1, size(rows)
      if (trim(rows(i)%maparea_id) == trim(requested)) then
        matches = matches + 1
        match_row = i
      end if
    end do

    diagnostics%matches = matches
    if (matches == 0) then
      diagnostics%status = FMR_ELAS_MAPAREA_PROFILE_NOT_FOUND
      return
    end if
    if (matches > 1) then
      diagnostics%status = FMR_ELAS_MAPAREA_PROFILE_AMBIGUOUS
      return
    end if

    if (.not. valid_source_row(rows(match_row))) then
      diagnostics%status = FMR_ELAS_MAPAREA_PROFILE_INVALID_SOURCE
      return
    end if

    profile_id = rows(match_row)%normalsoilprofile_id
    diagnostics%matched_row = match_row
    diagnostics%selected_profile_id = profile_id
    diagnostics%status = FMR_ELAS_MAPAREA_PROFILE_OK
  end subroutine fmr_resolve_maparea_profile

  pure logical function valid_source_row(row) result(valid)
    type(fmr_elastic_storage_maparea_profile_row_t), intent(in) :: row
    valid = .false.
    if (len_trim(row%maparea_id) <= 0) return
    if (row%maparea_id(1:1) == ' ') return
    if (row%normalsoilprofile_id <= 0) return
    valid = .true.
  end function valid_source_row

end module mod_fmr_elastic_storage_maparea_profile_association

module mod_fmr_elastic_storage_staringblock_association
  use mod_fmr_elastic_storage_staringreeks_catalog, only: &
       fmr_staringreeks_code_at, FMR_STARINGREEKS_CATALOG_OK
  implicit none
  private

  integer, parameter, public :: FMR_STARINGBLOCK_OK = 0
  integer, parameter, public :: FMR_STARINGBLOCK_NOT_FOUND = 1
  integer, parameter, public :: FMR_STARINGBLOCK_FAMILY_TOPSOIL = 1
  integer, parameter, public :: FMR_STARINGBLOCK_FAMILY_SUBSOIL = 2

  public :: fmr_staringseriesblock_to_code

contains

  subroutine fmr_staringseriesblock_to_code(staringseriesblock, code, family, family_index, catalog_index, status)
    integer, intent(in) :: staringseriesblock
    character(len=3), intent(out) :: code
    integer, intent(out) :: family, family_index, catalog_index, status

    integer :: catalog_status

    code = '   '
    family = 0
    family_index = 0
    catalog_index = 0
    status = FMR_STARINGBLOCK_NOT_FOUND

    if (staringseriesblock >= 101 .and. staringseriesblock <= 118) then
      family = FMR_STARINGBLOCK_FAMILY_TOPSOIL
      family_index = staringseriesblock - 100
      catalog_index = family_index
    else if (staringseriesblock >= 201 .and. staringseriesblock <= 218) then
      family = FMR_STARINGBLOCK_FAMILY_SUBSOIL
      family_index = staringseriesblock - 200
      catalog_index = 18 + family_index
    else
      return
    end if

    call fmr_staringreeks_code_at(catalog_index, code, catalog_status)
    if (catalog_status /= FMR_STARINGREEKS_CATALOG_OK) then
      code = '   '
      family = 0
      family_index = 0
      catalog_index = 0
      return
    end if

    status = FMR_STARINGBLOCK_OK
  end subroutine fmr_staringseriesblock_to_code

end module mod_fmr_elastic_storage_staringblock_association

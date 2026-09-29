module mod_fmr_elastic_storage_staringseriesblock_map
  use mod_fmr_elastic_storage_staringreeks_catalog, only: &
       fmr_staringreeks_code_at, FMR_STARINGREEKS_CATALOG_OK
  implicit none
  private

  integer, parameter, public :: FMR_STARINGSERIESBLOCK_OK = 0
  integer, parameter, public :: FMR_STARINGSERIESBLOCK_NOT_FOUND = 1

  public :: fmr_map_staringseriesblock_to_catalog

contains

  subroutine fmr_map_staringseriesblock_to_catalog(staringseriesblock, code, catalog_index, status)
    integer, intent(in) :: staringseriesblock
    character(len=3), intent(out) :: code
    integer, intent(out) :: catalog_index
    integer, intent(out) :: status

    integer :: catalog_status

    code = '   '
    catalog_index = 0
    status = FMR_STARINGSERIESBLOCK_NOT_FOUND

    if (staringseriesblock >= 101 .and. staringseriesblock <= 118) then
      catalog_index = staringseriesblock - 100
    else if (staringseriesblock >= 201 .and. staringseriesblock <= 218) then
      catalog_index = 18 + staringseriesblock - 200
    else
      return
    end if

    call fmr_staringreeks_code_at(catalog_index, code, catalog_status)
    if (catalog_status /= FMR_STARINGREEKS_CATALOG_OK) then
      code = '   '
      catalog_index = 0
      return
    end if

    status = FMR_STARINGSERIESBLOCK_OK
  end subroutine fmr_map_staringseriesblock_to_catalog

end module mod_fmr_elastic_storage_staringseriesblock_map

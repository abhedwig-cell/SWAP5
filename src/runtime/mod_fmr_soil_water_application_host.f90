module mod_fmr_soil_water_application_host
  implicit none
  private

  character(len=*), parameter, public :: FMR_SOIL_WATER_MODEL_REFERENCE = 'REFERENCE_RICHARDS'

  integer, parameter, public :: FMR_APPLICATION_HOST_OK = 0
  integer, parameter, public :: FMR_APPLICATION_HOST_INVALID_REGISTRY = 1
  integer, parameter, public :: FMR_APPLICATION_HOST_UNSUPPORTED_MODEL = 2

  integer, parameter, public :: FMR_APPLICATION_ROUTE_REFERENCE = 1
  integer, parameter, public :: FMR_APPLICATION_ROUTE_REGISTERED_ALTERNATIVE = 2

  type, public :: fmr_soil_water_application_selection_t
    integer :: route = FMR_APPLICATION_ROUTE_REFERENCE
    integer :: registered_index = 0
    logical :: explicit_selection = .false.
    character(len=32) :: model_key = FMR_SOIL_WATER_MODEL_REFERENCE
  end type fmr_soil_water_application_selection_t

  public :: fmr_resolve_soil_water_application_model

contains

  subroutine fmr_resolve_soil_water_application_model(requested_model_key, registered_model_keys, &
                                                       selection, status)
    character(len=*), intent(in) :: requested_model_key
    character(len=*), intent(in) :: registered_model_keys(:)
    type(fmr_soil_water_application_selection_t), intent(out) :: selection
    integer, intent(out) :: status

    character(len=32) :: requested
    integer :: i, j, match_index

    selection = fmr_soil_water_application_selection_t()
    status = FMR_APPLICATION_HOST_INVALID_REGISTRY

    ! F-APP01 owns only application-level model selection. The registry is
    ! supplied by admitted bindings; the host does not know RossFast or any
    ! other alternative model by name.
    do i = 1, size(registered_model_keys)
      if (len_trim(registered_model_keys(i)) == 0) return
      if (len_trim(registered_model_keys(i)) > len(selection%model_key)) return
      if (trim(registered_model_keys(i)) == FMR_SOIL_WATER_MODEL_REFERENCE) return
      do j = i + 1, size(registered_model_keys)
        if (trim(registered_model_keys(j)) == trim(registered_model_keys(i))) return
      end do
    end do

    requested = adjustl(requested_model_key)
    if (len_trim(requested_model_key) == 0) then
      selection%route = FMR_APPLICATION_ROUTE_REFERENCE
      selection%registered_index = 0
      selection%explicit_selection = .false.
      selection%model_key = FMR_SOIL_WATER_MODEL_REFERENCE
      status = FMR_APPLICATION_HOST_OK
      return
    end if

    if (len_trim(requested_model_key) > len(selection%model_key)) then
      status = FMR_APPLICATION_HOST_UNSUPPORTED_MODEL
      return
    end if

    requested = trim(requested)
    if (trim(requested) == FMR_SOIL_WATER_MODEL_REFERENCE) then
      selection%route = FMR_APPLICATION_ROUTE_REFERENCE
      selection%registered_index = 0
      selection%explicit_selection = .true.
      selection%model_key = FMR_SOIL_WATER_MODEL_REFERENCE
      status = FMR_APPLICATION_HOST_OK
      return
    end if

    match_index = 0
    do i = 1, size(registered_model_keys)
      if (trim(requested) == trim(registered_model_keys(i))) then
        match_index = i
        exit
      end if
    end do

    if (match_index == 0) then
      status = FMR_APPLICATION_HOST_UNSUPPORTED_MODEL
      return
    end if

    selection%route = FMR_APPLICATION_ROUTE_REGISTERED_ALTERNATIVE
    selection%registered_index = match_index
    selection%explicit_selection = .true.
    selection%model_key = trim(requested)
    status = FMR_APPLICATION_HOST_OK
  end subroutine fmr_resolve_soil_water_application_model

end module mod_fmr_soil_water_application_host

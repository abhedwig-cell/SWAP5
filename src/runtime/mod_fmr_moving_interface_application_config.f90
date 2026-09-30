module mod_fmr_moving_interface_application_config
  implicit none
  private

  character(len=*), parameter, public :: FMR_MI_CONFIG_KEY = 'MOVING_INTERFACE_MANAGER'
  character(len=*), parameter, public :: FMR_MI_CONFIG_VALUE_ENABLED = 'ENABLED'
  character(len=*), parameter, public :: FMR_MI_CONFIG_VALUE_DISABLED = 'DISABLED'

  integer, parameter, public :: FMR_MI_CONFIG_OK = 0
  integer, parameter, public :: FMR_MI_CONFIG_MISSING = 1
  integer, parameter, public :: FMR_MI_CONFIG_UNSUPPORTED_KEY = 2
  integer, parameter, public :: FMR_MI_CONFIG_UNSUPPORTED_VALUE = 3

  type, public :: fmr_moving_interface_application_config_t
     logical :: supplied = .false.
     character(len=32) :: key = ''
     character(len=32) :: value = ''
  end type fmr_moving_interface_application_config_t

  type, public :: fmr_moving_interface_application_request_t
     logical :: manager_enabled = .false.
  end type fmr_moving_interface_application_request_t

  public :: fmr_bind_moving_interface_application_config

contains

  subroutine fmr_bind_moving_interface_application_config(config, request, status)
    type(fmr_moving_interface_application_config_t), intent(in) :: config
    type(fmr_moving_interface_application_request_t), intent(out) :: request
    integer, intent(out) :: status

    ! Default-off is deliberate. Absence of this research configuration seam
    ! must not alter the established production/legacy numerical route.
    request = fmr_moving_interface_application_request_t()
    status = FMR_MI_CONFIG_MISSING

    if (.not. config%supplied) return

    if (trim(config%key) /= FMR_MI_CONFIG_KEY) then
       status = FMR_MI_CONFIG_UNSUPPORTED_KEY
       return
    end if

    select case (trim(config%value))
    case (FMR_MI_CONFIG_VALUE_ENABLED)
       request%manager_enabled = .true.
       status = FMR_MI_CONFIG_OK
    case (FMR_MI_CONFIG_VALUE_DISABLED)
       request%manager_enabled = .false.
       status = FMR_MI_CONFIG_OK
    case default
       status = FMR_MI_CONFIG_UNSUPPORTED_VALUE
    end select
  end subroutine fmr_bind_moving_interface_application_config

end module mod_fmr_moving_interface_application_config

module mod_fmr_elastic_storage_application_config
  implicit none
  private

  character(len=*), parameter, public :: FMR_ELAS_CONFIG_KEY_SOURCE = 'ELASTIC_STORAGE_SOURCE'
  character(len=*), parameter, public :: FMR_ELAS_CONFIG_VALUE_GENERATED_BOFEK_BRO = 'GENERATED_BOFEK_BRO_PRIOR'

  integer, parameter, public :: FMR_ELAS_CONFIG_OK = 0
  integer, parameter, public :: FMR_ELAS_CONFIG_MISSING = 1
  integer, parameter, public :: FMR_ELAS_CONFIG_UNSUPPORTED_KEY = 2
  integer, parameter, public :: FMR_ELAS_CONFIG_UNSUPPORTED_VALUE = 3

  type, public :: fmr_elastic_storage_application_config_t
    logical :: supplied = .false.
    character(len=32) :: key = ''
    character(len=64) :: value = ''
  end type fmr_elastic_storage_application_config_t

  type, public :: fmr_elastic_storage_application_request_t
    logical :: generated_prior_requested = .false.
  end type fmr_elastic_storage_application_request_t

  public :: fmr_bind_elastic_storage_application_config

contains

  subroutine fmr_bind_elastic_storage_application_config(config, request, status)
    type(fmr_elastic_storage_application_config_t), intent(in) :: config
    type(fmr_elastic_storage_application_request_t), intent(out) :: request
    integer, intent(out) :: status

    request = fmr_elastic_storage_application_request_t()
    status = FMR_ELAS_CONFIG_MISSING

    if (.not. config%supplied) return

    if (trim(config%key) /= FMR_ELAS_CONFIG_KEY_SOURCE) then
      status = FMR_ELAS_CONFIG_UNSUPPORTED_KEY
      return
    end if

    if (trim(config%value) /= FMR_ELAS_CONFIG_VALUE_GENERATED_BOFEK_BRO) then
      status = FMR_ELAS_CONFIG_UNSUPPORTED_VALUE
      return
    end if

    request%generated_prior_requested = .true.
    status = FMR_ELAS_CONFIG_OK
  end subroutine fmr_bind_elastic_storage_application_config

end module mod_fmr_elastic_storage_application_config

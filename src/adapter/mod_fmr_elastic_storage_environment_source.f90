module mod_fmr_elastic_storage_environment_source
  use mod_fmr_elastic_storage_request_source_arbitration, only: &
       fmr_elastic_storage_request_path_candidate_t
  implicit none
  private

  character(len=*), parameter, public :: FMR_ELAS_CONFIG_ENVIRONMENT_VARIABLE = 'SWAP5_ELASTIC_STORAGE_CONFIG'

  integer, parameter, public :: FMR_ELAS_ENV_SOURCE_OK = 0
  integer, parameter, public :: FMR_ELAS_ENV_SOURCE_INACTIVE = 1
  integer, parameter, public :: FMR_ELAS_ENV_SOURCE_TOO_LONG = 2
  integer, parameter, public :: FMR_ELAS_ENV_SOURCE_READ_FAILED = 3

  public :: fmr_read_elastic_storage_environment_source

contains

  subroutine fmr_read_elastic_storage_environment_source(candidate, status)
    type(fmr_elastic_storage_request_path_candidate_t), intent(out) :: candidate
    integer, intent(out) :: status

    character(len=len(candidate%path)) :: value
    integer :: value_length, env_status

    candidate = fmr_elastic_storage_request_path_candidate_t()
    status = FMR_ELAS_ENV_SOURCE_INACTIVE

    call get_environment_variable(FMR_ELAS_CONFIG_ENVIRONMENT_VARIABLE, length=value_length, status=env_status)
    if (env_status /= 0 .and. value_length <= 0) return
    if (value_length <= 0) return
    if (value_length > len(candidate%path)) then
      status = FMR_ELAS_ENV_SOURCE_TOO_LONG
      return
    end if

    value = ''
    call get_environment_variable(FMR_ELAS_CONFIG_ENVIRONMENT_VARIABLE, value=value, &
                                  length=value_length, status=env_status)
    if (env_status /= 0) then
      status = FMR_ELAS_ENV_SOURCE_READ_FAILED
      return
    end if

    if (value_length <= 0) return

    candidate%supplied = .true.
    candidate%path = value
    status = FMR_ELAS_ENV_SOURCE_OK
  end subroutine fmr_read_elastic_storage_environment_source

end module mod_fmr_elastic_storage_environment_source

program test_fpe_nlglob14z43_config
  use mod_fmr_moving_interface_application_config, only: &
       fmr_moving_interface_application_config_t, fmr_moving_interface_application_request_t, &
       fmr_bind_moving_interface_application_config, FMR_MI_CONFIG_KEY, &
       FMR_MI_CONFIG_VALUE_ENABLED, FMR_MI_CONFIG_VALUE_DISABLED, &
       FMR_MI_CONFIG_OK, FMR_MI_CONFIG_MISSING, FMR_MI_CONFIG_UNSUPPORTED_VALUE
  implicit none
  type(fmr_moving_interface_application_config_t) :: cfg
  type(fmr_moving_interface_application_request_t) :: req
  integer :: status

  call fmr_bind_moving_interface_application_config(cfg, req, status)
  call require(status == FMR_MI_CONFIG_MISSING, 'missing status')
  call require(.not. req%manager_enabled, 'missing config must default disabled')

  cfg%supplied = .true.
  cfg%key = FMR_MI_CONFIG_KEY
  cfg%value = FMR_MI_CONFIG_VALUE_DISABLED
  call fmr_bind_moving_interface_application_config(cfg, req, status)
  call require(status == FMR_MI_CONFIG_OK, 'explicit disabled status')
  call require(.not. req%manager_enabled, 'explicit disabled must stay disabled')

  cfg%value = FMR_MI_CONFIG_VALUE_ENABLED
  call fmr_bind_moving_interface_application_config(cfg, req, status)
  call require(status == FMR_MI_CONFIG_OK, 'enabled status')
  call require(req%manager_enabled, 'enabled must opt in')

  cfg%value = 'INVALID'
  call fmr_bind_moving_interface_application_config(cfg, req, status)
  call require(status == FMR_MI_CONFIG_UNSUPPORTED_VALUE, 'invalid value status')
  call require(.not. req%manager_enabled, 'invalid config must fail closed')

  write(*,'(a)') 'F_PE_NLGLOB14Z43_CONFIG={"default_enabled":false,"explicit_disabled":true,"explicit_enabled":true,"invalid_fail_closed":true}'
  write(*,'(a)') 'F_PE_NLGLOB14Z43_CONFIG=PASS'

contains
  subroutine require(cond,msg)
    logical,intent(in)::cond
    character(len=*),intent(in)::msg
    if(.not.cond) then
       write(*,'(a,1x,a)') 'F_PE_NLGLOB14Z43_CONFIG_FAIL',trim(msg)
       error stop 1
    end if
  end subroutine require
end program test_fpe_nlglob14z43_config

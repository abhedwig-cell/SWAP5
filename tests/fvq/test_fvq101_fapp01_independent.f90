program test_fvq101_fapp01_independent
  use mod_fmr_soil_water_application_host, only: fmr_soil_water_application_selection_t, &
       fmr_resolve_soil_water_application_model, FMR_SOIL_WATER_MODEL_REFERENCE, &
       FMR_APPLICATION_HOST_OK, FMR_APPLICATION_HOST_INVALID_REGISTRY, &
       FMR_APPLICATION_HOST_UNSUPPORTED_MODEL, FMR_APPLICATION_ROUTE_REFERENCE, &
       FMR_APPLICATION_ROUTE_REGISTERED_ALTERNATIVE
  implicit none

  type(fmr_soil_water_application_selection_t) :: selection
  character(len=32) :: registry(2), empty_registry(0), duplicate_registry(2), reserved_registry(1), blank_registry(1)
  character(len=40) :: overlong_registry(1), overlong_request
  integer :: status

  registry = [character(len=32) :: 'MODEL_A', 'MODEL_B']

  call fmr_resolve_soil_water_application_model('', empty_registry, selection, status)
  call require(status == FMR_APPLICATION_HOST_OK, 'empty registry permits default reference')
  call require(selection%route == FMR_APPLICATION_ROUTE_REFERENCE, 'empty registry default route is reference')
  call require(.not. selection%explicit_selection, 'empty request remains implicit')
  call require(trim(selection%model_key) == FMR_SOIL_WATER_MODEL_REFERENCE, 'default reference key preserved')

  call fmr_resolve_soil_water_application_model(FMR_SOIL_WATER_MODEL_REFERENCE, registry, selection, status)
  call require(status == FMR_APPLICATION_HOST_OK, 'explicit reference accepted')
  call require(selection%route == FMR_APPLICATION_ROUTE_REFERENCE, 'explicit reference route')
  call require(selection%explicit_selection, 'explicit reference marked explicit')

  call fmr_resolve_soil_water_application_model('MODEL_B', registry, selection, status)
  call require(status == FMR_APPLICATION_HOST_OK, 'registered alternative accepted')
  call require(selection%route == FMR_APPLICATION_ROUTE_REGISTERED_ALTERNATIVE, 'alternative route selected')
  call require(selection%registered_index == 2, 'alternative registry index preserved')
  call require(selection%explicit_selection, 'alternative selection is explicit')
  call require(trim(selection%model_key) == 'MODEL_B', 'alternative model key preserved')

  call fmr_resolve_soil_water_application_model('UNKNOWN_MODEL', registry, selection, status)
  call require(status == FMR_APPLICATION_HOST_UNSUPPORTED_MODEL, 'unknown model fails closed')

  call fmr_resolve_soil_water_application_model('MODEL_A', empty_registry, selection, status)
  call require(status == FMR_APPLICATION_HOST_UNSUPPORTED_MODEL, 'unregistered alternative fails closed')

  duplicate_registry = [character(len=32) :: 'MODEL_A', 'MODEL_A']
  call fmr_resolve_soil_water_application_model('', duplicate_registry, selection, status)
  call require(status == FMR_APPLICATION_HOST_INVALID_REGISTRY, 'duplicate registry rejected')

  reserved_registry = [character(len=32) :: FMR_SOIL_WATER_MODEL_REFERENCE]
  call fmr_resolve_soil_water_application_model('', reserved_registry, selection, status)
  call require(status == FMR_APPLICATION_HOST_INVALID_REGISTRY, 'reference cannot be registered as alternative')

  blank_registry = [character(len=32) :: '']
  call fmr_resolve_soil_water_application_model('', blank_registry, selection, status)
  call require(status == FMR_APPLICATION_HOST_INVALID_REGISTRY, 'blank registry key rejected')

  overlong_registry(1) = 'MODEL_KEY_THAT_IS_DELIBERATELY_OVER_32_CHARS'
  call fmr_resolve_soil_water_application_model('', overlong_registry, selection, status)
  call require(status == FMR_APPLICATION_HOST_INVALID_REGISTRY, 'overlong registry key rejected')

  overlong_request = 'MODEL_KEY_THAT_IS_DELIBERATELY_OVER_32_CHARS'
  call fmr_resolve_soil_water_application_model(overlong_request, registry, selection, status)
  call require(status == FMR_APPLICATION_HOST_UNSUPPORTED_MODEL, 'overlong requested key fails closed')

  write(*,'(a)') 'FVQ101_DEFAULT_REFERENCE_EMPTY_REGISTRY=PASS'
  write(*,'(a)') 'FVQ101_EXPLICIT_REFERENCE=PASS'
  write(*,'(a)') 'FVQ101_REGISTERED_ALTERNATIVE=PASS'
  write(*,'(a)') 'FVQ101_UNKNOWN_ALTERNATIVE_FAIL_CLOSED=PASS'
  write(*,'(a)') 'FVQ101_INVALID_REGISTRY_FAIL_CLOSED=PASS'
  write(*,'(a)') 'FVQ101_LENGTH_GUARDS=PASS'
  write(*,'(a)') 'FVQ101_INDEPENDENT_HOST_CONTRACT=PASS'

contains

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(a,a)') 'FVQ101_FAIL=', trim(label)
      error stop 1
    end if
  end subroutine require

end program test_fvq101_fapp01_independent

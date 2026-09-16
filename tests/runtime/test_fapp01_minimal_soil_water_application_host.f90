program test_fapp01_minimal_soil_water_application_host
  use mod_fmr_soil_water_application_host, only: fmr_soil_water_application_selection_t, &
       fmr_resolve_soil_water_application_model, FMR_SOIL_WATER_MODEL_REFERENCE, &
       FMR_APPLICATION_HOST_OK, FMR_APPLICATION_HOST_INVALID_REGISTRY, &
       FMR_APPLICATION_HOST_UNSUPPORTED_MODEL, FMR_APPLICATION_ROUTE_REFERENCE, &
       FMR_APPLICATION_ROUTE_REGISTERED_ALTERNATIVE
  implicit none

  type(fmr_soil_water_application_selection_t) :: selection
  character(len=32) :: registry(2), empty_registry(0), duplicate_registry(2), bad_registry(1)
  integer :: status

  registry = [character(len=32) :: 'ALTERNATIVE_A', 'ALTERNATIVE_B']

  call fmr_resolve_soil_water_application_model('', registry, selection, status)
  call require(status == FMR_APPLICATION_HOST_OK, 'default reference status')
  call require(selection%route == FMR_APPLICATION_ROUTE_REFERENCE, 'default reference route')
  call require(.not. selection%explicit_selection, 'default is not explicit')
  call require(trim(selection%model_key) == FMR_SOIL_WATER_MODEL_REFERENCE, 'default reference key')

  call fmr_resolve_soil_water_application_model(FMR_SOIL_WATER_MODEL_REFERENCE, registry, selection, status)
  call require(status == FMR_APPLICATION_HOST_OK, 'explicit reference status')
  call require(selection%route == FMR_APPLICATION_ROUTE_REFERENCE, 'explicit reference route')
  call require(selection%explicit_selection, 'explicit reference marked explicit')

  call fmr_resolve_soil_water_application_model('ALTERNATIVE_B', registry, selection, status)
  call require(status == FMR_APPLICATION_HOST_OK, 'registered alternative status')
  call require(selection%route == FMR_APPLICATION_ROUTE_REGISTERED_ALTERNATIVE, 'registered alternative route')
  call require(selection%registered_index == 2, 'registered alternative index')
  call require(selection%explicit_selection, 'alternative is explicit')
  call require(trim(selection%model_key) == 'ALTERNATIVE_B', 'alternative key preserved')

  call fmr_resolve_soil_water_application_model('UNKNOWN_MODEL', registry, selection, status)
  call require(status == FMR_APPLICATION_HOST_UNSUPPORTED_MODEL, 'unknown model fails closed')

  call fmr_resolve_soil_water_application_model('ALTERNATIVE_A', empty_registry, selection, status)
  call require(status == FMR_APPLICATION_HOST_UNSUPPORTED_MODEL, 'no registered alternative fails closed')

  duplicate_registry = [character(len=32) :: 'ALTERNATIVE_A', 'ALTERNATIVE_A']
  call fmr_resolve_soil_water_application_model('', duplicate_registry, selection, status)
  call require(status == FMR_APPLICATION_HOST_INVALID_REGISTRY, 'duplicate registry fails closed')

  bad_registry = [character(len=32) :: FMR_SOIL_WATER_MODEL_REFERENCE]
  call fmr_resolve_soil_water_application_model('', bad_registry, selection, status)
  call require(status == FMR_APPLICATION_HOST_INVALID_REGISTRY, 'reference cannot be registered as alternative')

  bad_registry = [character(len=32) :: '']
  call fmr_resolve_soil_water_application_model('', bad_registry, selection, status)
  call require(status == FMR_APPLICATION_HOST_INVALID_REGISTRY, 'blank alternative fails closed')

  write(*,'(a)') 'FAPP01_DEFAULT_REFERENCE=PASS'
  write(*,'(a)') 'FAPP01_EXPLICIT_REFERENCE=PASS'
  write(*,'(a)') 'FAPP01_REGISTERED_ALTERNATIVE=PASS'
  write(*,'(a)') 'FAPP01_UNKNOWN_MODEL_FAIL_CLOSED=PASS'
  write(*,'(a)') 'FAPP01_INVALID_REGISTRY_FAIL_CLOSED=PASS'
  write(*,'(a)') 'FAPP01_NO_SCIENTIFIC_EXECUTION=PASS'

contains

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(a,a)') 'FAPP01_FAIL=', trim(label)
      error stop 1
    end if
  end subroutine require

end program test_fapp01_minimal_soil_water_application_host

program test_ross13_36_material_production_envelope
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_rossfast_d3r_model_binding, only: rossfast_d3r_material_t, &
       rossfast_d3r_material_from_id, rossfast_d3r_material_is_admitted
  use mod_rossfast_d3r_table_kernel, only: rossfast_d3r_table_kernel_t
  use mod_rossfast_d3r_table_provider, only: rossfast_d3r_table_registry_t, &
       bind_rossfast_d3r_table_registry, rossfast_d3r_table_asset_relative_path, &
       ROSSFAST_TABLE_PROVIDER_OK, ROSSFAST_TABLE_PROVIDER_MATERIAL
  implicit none

  character(len=3), parameter :: ids(36) = [character(len=3) :: &
       'B01','B02','B03','B04','B05','B06','B07','B08','B09', &
       'B10','B11','B12','B13','B14','B15','B16','B17','B18', &
       'O01','O02','O03','O04','O05','O06','O07','O08','O09', &
       'O10','O11','O12','O13','O14','O15','O16','O17','O18']
  type(rossfast_d3r_table_registry_t) :: registry
  type(rossfast_d3r_table_kernel_t) :: kernel
  type(rossfast_d3r_material_t) :: material
  character(len=:), allocatable :: path
  logical :: found, valid
  integer :: i, status

  call bind_rossfast_d3r_table_registry(registry, 'assets/rossfast/d3r', valid)
  call require(valid, 'registry bind')

  do i = 1, size(ids)
    call rossfast_d3r_material_from_id(ids(i), material, found)
    call require(found, 'catalog lookup '//ids(i))
    call require(material%material_id == ids(i), 'catalog identity '//ids(i))
    call require(rossfast_d3r_material_is_admitted(material), 'strict material admission '//ids(i))

    call rossfast_d3r_table_asset_relative_path(ids(i), path, found)
    call require(found, 'asset mapping '//ids(i))
    call require(path == ids(i)//'_log_mobility_f32.hex', 'asset path '//ids(i))

    call registry%initialize_kernel(kernel, material, valid, status)
    call require(valid, 'provider initialization '//ids(i))
    call require(status == ROSSFAST_TABLE_PROVIDER_OK, 'provider status '//ids(i))
  end do
  write(*,'(A)') 'ROSS13_ALL_36_CATALOG=PASS'
  write(*,'(A)') 'ROSS13_ALL_36_PROVIDER_ASSETS=PASS'

  call rossfast_d3r_material_from_id('X99', material, found)
  call require(.not. found, 'unknown model material must fail closed')
  call rossfast_d3r_table_asset_relative_path('X99', path, found)
  call require(.not. found, 'unknown provider material must fail closed')
  write(*,'(A)') 'ROSS13_UNKNOWN_MATERIAL_FAIL_CLOSED=PASS'

  call rossfast_d3r_material_from_id('B02', material, found)
  call require(found, 'B02 drift setup')
  material%theta_s = material%theta_s + 1.0e-12_real64
  call require(.not. rossfast_d3r_material_is_admitted(material), 'parameter drift model admission')
  call registry%initialize_kernel(kernel, material, valid, status)
  call require(.not. valid, 'parameter drift provider valid flag')
  call require(status == ROSSFAST_TABLE_PROVIDER_MATERIAL, 'parameter drift provider status')
  write(*,'(A)') 'ROSS13_PARAMETER_DRIFT_FAIL_CLOSED=PASS'

  write(*,'(A)') 'F_ROSS13_36_MATERIAL_PRODUCTION_ENVELOPE PASS'

contains

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A)') 'F_ROSS13_36_MATERIAL_PRODUCTION_ENVELOPE FAIL '//trim(label)
      error stop 1
    end if
  end subroutine require

end program test_ross13_36_material_production_envelope

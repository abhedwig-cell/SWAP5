module mod_rossfast_d3r_table_provider
  use, intrinsic :: iso_fortran_env, only: int32, real32, iostat_end
  use mod_rossfast_d3r_model_binding, only: rossfast_d3r_material_t, &
       rossfast_d3r_material_is_admitted
  use mod_rossfast_d3r_table_kernel, only: rossfast_d3r_table_kernel_t, &
       initialize_rossfast_d3r_table_kernel, ROSSFAST_D3R_TABLE_N
  implicit none
  private

  character(len=*), parameter :: TABLE_MAGIC = 'ROSSFAST_D3R_TABLE_V1'
  integer, parameter :: TABLE_WORDS = ROSSFAST_D3R_TABLE_N * ROSSFAST_D3R_TABLE_N

  integer, parameter, public :: ROSSFAST_TABLE_PROVIDER_OK = 0
  integer, parameter, public :: ROSSFAST_TABLE_PROVIDER_UNBOUND = 1
  integer, parameter, public :: ROSSFAST_TABLE_PROVIDER_MATERIAL = 2
  integer, parameter, public :: ROSSFAST_TABLE_PROVIDER_OPEN = 3
  integer, parameter, public :: ROSSFAST_TABLE_PROVIDER_HEADER = 4
  integer, parameter, public :: ROSSFAST_TABLE_PROVIDER_WORD = 5
  integer, parameter, public :: ROSSFAST_TABLE_PROVIDER_TRAILING = 6
  integer, parameter, public :: ROSSFAST_TABLE_PROVIDER_KERNEL = 7

  type, public :: rossfast_d3r_table_registry_t
    private
    character(len=:), allocatable :: asset_root
    logical :: bound = .false.
  contains
    procedure :: initialize_kernel => registry_initialize_kernel
  end type rossfast_d3r_table_registry_t

  public :: bind_rossfast_d3r_table_registry
  public :: rossfast_d3r_table_asset_relative_path

contains

  subroutine bind_rossfast_d3r_table_registry(registry, asset_root, valid)
    type(rossfast_d3r_table_registry_t), intent(out) :: registry
    character(len=*), intent(in) :: asset_root
    logical, intent(out) :: valid

    valid = .false.
    registry%bound = .false.
    if (len_trim(asset_root) == 0) return
    registry%asset_root = trim(asset_root)
    registry%bound = .true.
    valid = .true.
  end subroutine bind_rossfast_d3r_table_registry

  subroutine registry_initialize_kernel(self, kernel, material, valid, status)
    class(rossfast_d3r_table_registry_t), intent(in) :: self
    type(rossfast_d3r_table_kernel_t), intent(out) :: kernel
    type(rossfast_d3r_material_t), intent(in) :: material
    logical, intent(out) :: valid
    integer, intent(out) :: status
    real(real32), allocatable :: table(:,:)
    character(len=:), allocatable :: relative_path, full_path
    logical :: found, kernel_valid

    valid = .false.
    status = ROSSFAST_TABLE_PROVIDER_UNBOUND
    if (.not. self%bound .or. .not. allocated(self%asset_root)) return

    status = ROSSFAST_TABLE_PROVIDER_MATERIAL
    if (.not. rossfast_d3r_material_is_admitted(material)) return
    call rossfast_d3r_table_asset_relative_path(material%material_id, relative_path, found)
    if (.not. found) return

    full_path = trim(self%asset_root) // '/' // relative_path
    call load_exact_table_asset(full_path, trim(material%material_id), table, status)
    if (status /= ROSSFAST_TABLE_PROVIDER_OK) return

    call initialize_rossfast_d3r_table_kernel(kernel, material, table, kernel_valid)
    if (.not. kernel_valid) then
      status = ROSSFAST_TABLE_PROVIDER_KERNEL
      return
    end if
    valid = .true.
    status = ROSSFAST_TABLE_PROVIDER_OK
  end subroutine registry_initialize_kernel

  subroutine rossfast_d3r_table_asset_relative_path(material_id, path, found)
    character(len=*), intent(in) :: material_id
    character(len=:), allocatable, intent(out) :: path
    logical, intent(out) :: found

    found = .true.
    select case(trim(material_id))
    case('B01','B02','B03','B04','B05','B06','B07','B08','B09', &
         'B10','B11','B12','B13','B14','B15','B16','B17','B18', &
         'O01','O02','O03','O04','O05','O06','O07','O08','O09', &
         'O10','O11','O12','O13','O14','O15','O16','O17','O18')
      path = trim(material_id) // '_log_mobility_f32.hex'
    case default
      path = ''
      found = .false.
    end select
  end subroutine rossfast_d3r_table_asset_relative_path

  subroutine load_exact_table_asset(path, expected_material, table, status)
    character(len=*), intent(in) :: path, expected_material
    real(real32), allocatable, intent(out) :: table(:,:)
    integer, intent(out) :: status
    character(len=256) :: line, magic, material
    integer(int32) :: bits
    integer :: unit, ios, n, words, i, j

    status = ROSSFAST_TABLE_PROVIDER_OPEN
    open(newunit=unit, file=trim(path), status='old', action='read', form='formatted', iostat=ios)
    if (ios /= 0) return

    status = ROSSFAST_TABLE_PROVIDER_HEADER
    read(unit, '(A)', iostat=ios) line
    if (ios /= 0) then
      close(unit)
      return
    end if
    magic = ''
    material = ''
    n = 0
    words = 0
    read(line, *, iostat=ios) magic, material, n, words
    if (ios /= 0 .or. trim(magic) /= TABLE_MAGIC .or. &
        trim(material) /= trim(expected_material) .or. &
        n /= ROSSFAST_D3R_TABLE_N .or. words /= TABLE_WORDS) then
      close(unit)
      return
    end if

    allocate(table(ROSSFAST_D3R_TABLE_N, ROSSFAST_D3R_TABLE_N))
    status = ROSSFAST_TABLE_PROVIDER_WORD
    do j = 1, ROSSFAST_D3R_TABLE_N
      do i = 1, ROSSFAST_D3R_TABLE_N
        read(unit, '(Z8)', iostat=ios) bits
        if (ios /= 0) then
          deallocate(table)
          close(unit)
          return
        end if
        table(i,j) = transfer(bits, 0.0_real32)
      end do
    end do

    status = ROSSFAST_TABLE_PROVIDER_TRAILING
    read(unit, '(A)', iostat=ios) line
    close(unit)
    if (ios /= iostat_end) then
      deallocate(table)
      return
    end if
    status = ROSSFAST_TABLE_PROVIDER_OK
  end subroutine load_exact_table_asset

end module mod_rossfast_d3r_table_provider

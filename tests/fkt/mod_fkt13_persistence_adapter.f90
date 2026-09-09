module mod_fkt13_persistence_adapter
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t
  use mod_kernel_committed_persistence, only: kernel_persistence_snapshot_t, &
       KERNEL_PERSISTENCE_SCHEMA_VERSION, KERNEL_PERSISTENCE_OK, &
       reconstruct_kernel_persistence_snapshot_trusted
  use mod_fkt05_test_model, only: fkt05_state_t
  implicit none
  private

  integer(int64), parameter, public :: FKT13_CODEC_FKT05 = 1300501_int64

  integer, parameter, public :: FKT13_ADAPTER_OK = 0
  integer, parameter, public :: FKT13_ADAPTER_IO_ERROR = 1
  integer, parameter, public :: FKT13_ADAPTER_FORMAT_ERROR = 2
  integer, parameter, public :: FKT13_ADAPTER_SCHEMA_MISMATCH = 3
  integer, parameter, public :: FKT13_ADAPTER_LAYOUT_MISMATCH = 4
  integer, parameter, public :: FKT13_ADAPTER_UNKNOWN_CODEC = 5
  integer, parameter, public :: FKT13_ADAPTER_INVALID_PROVENANCE = 6
  integer, parameter, public :: FKT13_ADAPTER_INVALID_PAYLOAD = 7
  integer, parameter, public :: FKT13_ADAPTER_KERNEL_REJECTED = 8
  integer, parameter, public :: FKT13_ADAPTER_INVALID_SNAPSHOT = 9

  public :: fkt13_write_artifact
  public :: fkt13_read_artifact

contains

  subroutine fkt13_write_artifact(path, snapshot, written, status)
    character(len=*), intent(in) :: path
    type(kernel_persistence_snapshot_t), intent(in) :: snapshot
    logical, intent(out) :: written
    integer, intent(out) :: status
    class(transaction_state_t), allocatable :: physical
    integer :: unit, ios, close_ios
    integer(int64) :: time_bits, water_bits
    real(real64) :: time_value, water
    logical :: time_available, time_bound, physical_available, io_ok
    character(len=256) :: line

    written = .false.
    status = FKT13_ADAPTER_INVALID_SNAPSHOT
    if (.not. snapshot%ready()) return

    time_bound = snapshot%time_is_bound()
    call snapshot%current_time(time_value, time_available)
    if (time_available .neqv. time_bound) return
    if (.not. time_bound) time_value = 0.0_real64

    call snapshot%snapshot_physical(physical, physical_available)
    if (.not. physical_available) return
    select type (physical)
    type is (fkt05_state_t)
      water = physical%water
    class default
      status = FKT13_ADAPTER_UNKNOWN_CODEC
      return
    end select
    if (.not. ieee_is_finite(water)) then
      status = FKT13_ADAPTER_INVALID_PAYLOAD
      return
    end if

    time_bits = transfer(time_value, 0_int64)
    water_bits = transfer(water, 0_int64)

    open(newunit=unit, file=path, status='replace', action='write', form='formatted', iostat=ios)
    if (ios /= 0) then
      status = FKT13_ADAPTER_IO_ERROR
      return
    end if

    io_ok = .true.
    call write_line(unit, 'SWAP5_FKT13_ARTIFACT_V1', io_ok)
    write(line,'(A,I0)') 'schema_version=', snapshot%schema_version()
    call write_line(unit, trim(line), io_ok)
    write(line,'(A,I0)') 'layout_id=', snapshot%layout_id()
    call write_line(unit, trim(line), io_ok)
    write(line,'(A,I0)') 'codec_id=', FKT13_CODEC_FKT05
    call write_line(unit, trim(line), io_ok)
    write(line,'(A,I0)') 'lineage_id=', snapshot%current_lineage_id()
    call write_line(unit, trim(line), io_ok)
    write(line,'(A,I0)') 'revision=', snapshot%current_revision()
    call write_line(unit, trim(line), io_ok)
    write(line,'(A,I0)') 'time_bound=', merge(1, 0, time_bound)
    call write_line(unit, trim(line), io_ok)
    write(line,'(A,I0)') 'committed_time_bits=', time_bits
    call write_line(unit, trim(line), io_ok)
    write(line,'(A,I0)') 'water_bits=', water_bits
    call write_line(unit, trim(line), io_ok)
    call write_line(unit, 'SWAP5_FKT13_END', io_ok)

    close(unit, iostat=close_ios)
    if (.not. io_ok .or. close_ios /= 0) then
      status = FKT13_ADAPTER_IO_ERROR
      return
    end if

    written = .true.
    status = FKT13_ADAPTER_OK
  end subroutine fkt13_write_artifact

  subroutine fkt13_read_artifact(path, expected_layout_id, snapshot, imported, status)
    character(len=*), intent(in) :: path
    integer(int64), intent(in) :: expected_layout_id
    type(kernel_persistence_snapshot_t), intent(out) :: snapshot
    logical, intent(out) :: imported
    integer, intent(out) :: status
    class(transaction_state_t), allocatable :: decoded_state
    integer :: unit, ios, close_ios, schema_version, time_bound_int, kernel_status
    integer(int64) :: layout_id, codec_id, lineage_id, revision, time_bits, water_bits
    real(real64) :: committed_time, water
    logical :: format_ok, kernel_ok, time_bound
    character(len=256) :: value, trailing

    snapshot = kernel_persistence_snapshot_t()
    imported = .false.
    status = FKT13_ADAPTER_IO_ERROR

    open(newunit=unit, file=path, status='old', action='read', form='formatted', iostat=ios)
    if (ios /= 0) return

    format_ok = .true.
    call read_exact_line(unit, 'SWAP5_FKT13_ARTIFACT_V1', format_ok)
    call read_value_line(unit, 'schema_version', value, format_ok)
    if (format_ok) format_ok = parse_int_text(value, schema_version)
    call read_value_line(unit, 'layout_id', value, format_ok)
    if (format_ok) format_ok = parse_int64_text(value, layout_id)
    call read_value_line(unit, 'codec_id', value, format_ok)
    if (format_ok) format_ok = parse_int64_text(value, codec_id)
    call read_value_line(unit, 'lineage_id', value, format_ok)
    if (format_ok) format_ok = parse_int64_text(value, lineage_id)
    call read_value_line(unit, 'revision', value, format_ok)
    if (format_ok) format_ok = parse_int64_text(value, revision)
    call read_value_line(unit, 'time_bound', value, format_ok)
    if (format_ok) format_ok = parse_int_text(value, time_bound_int)
    call read_value_line(unit, 'committed_time_bits', value, format_ok)
    if (format_ok) format_ok = parse_int64_text(value, time_bits)
    call read_value_line(unit, 'water_bits', value, format_ok)
    if (format_ok) format_ok = parse_int64_text(value, water_bits)
    call read_exact_line(unit, 'SWAP5_FKT13_END', format_ok)
    if (format_ok) then
      read(unit,'(A)',iostat=ios) trailing
      if (ios >= 0) format_ok = .false.
    end if

    close(unit, iostat=close_ios)
    if (close_ios /= 0) then
      status = FKT13_ADAPTER_IO_ERROR
      return
    end if
    if (.not. format_ok) then
      status = FKT13_ADAPTER_FORMAT_ERROR
      return
    end if

    if (schema_version /= KERNEL_PERSISTENCE_SCHEMA_VERSION) then
      status = FKT13_ADAPTER_SCHEMA_MISMATCH
      return
    end if
    if (expected_layout_id <= 0_int64 .or. layout_id /= expected_layout_id) then
      status = FKT13_ADAPTER_LAYOUT_MISMATCH
      return
    end if
    if (codec_id /= FKT13_CODEC_FKT05) then
      status = FKT13_ADAPTER_UNKNOWN_CODEC
      return
    end if
    if (lineage_id <= 0_int64 .or. revision < 0_int64) then
      status = FKT13_ADAPTER_INVALID_PROVENANCE
      return
    end if
    if (time_bound_int /= 0 .and. time_bound_int /= 1) then
      status = FKT13_ADAPTER_INVALID_PROVENANCE
      return
    end if

    time_bound = time_bound_int == 1
    committed_time = transfer(time_bits, 0.0_real64)
    if (time_bound) then
      if (.not. ieee_is_finite(committed_time)) then
        status = FKT13_ADAPTER_INVALID_PROVENANCE
        return
      end if
    else
      if (time_bits /= transfer(0.0_real64, 0_int64)) then
        status = FKT13_ADAPTER_INVALID_PROVENANCE
        return
      end if
    end if

    water = transfer(water_bits, 0.0_real64)
    if (.not. ieee_is_finite(water) .or. water < 0.0_real64) then
      status = FKT13_ADAPTER_INVALID_PAYLOAD
      return
    end if

    allocate(fkt05_state_t :: decoded_state)
    select type (decoded_state)
    type is (fkt05_state_t)
      decoded_state%water = water
    class default
      status = FKT13_ADAPTER_INVALID_PAYLOAD
      return
    end select

    call reconstruct_kernel_persistence_snapshot_trusted(schema_version, layout_id, lineage_id, revision, &
         committed_time, time_bound, decoded_state, snapshot, kernel_ok, kernel_status)
    if (.not. kernel_ok .or. kernel_status /= KERNEL_PERSISTENCE_OK) then
      snapshot = kernel_persistence_snapshot_t()
      status = FKT13_ADAPTER_KERNEL_REJECTED
      return
    end if

    imported = .true.
    status = FKT13_ADAPTER_OK
  end subroutine fkt13_read_artifact

  subroutine write_line(unit, line, ok)
    integer, intent(in) :: unit
    character(len=*), intent(in) :: line
    logical, intent(inout) :: ok
    integer :: ios

    if (.not. ok) return
    write(unit,'(A)',iostat=ios) trim(line)
    if (ios /= 0) ok = .false.
  end subroutine write_line

  subroutine read_exact_line(unit, expected, ok)
    integer, intent(in) :: unit
    character(len=*), intent(in) :: expected
    logical, intent(inout) :: ok
    integer :: ios
    character(len=256) :: line

    if (.not. ok) return
    read(unit,'(A)',iostat=ios) line
    if (ios /= 0) then
      ok = .false.
      return
    end if
    if (trim(line) /= expected) ok = .false.
  end subroutine read_exact_line

  subroutine read_value_line(unit, expected_key, value, ok)
    integer, intent(in) :: unit
    character(len=*), intent(in) :: expected_key
    character(len=*), intent(out) :: value
    logical, intent(inout) :: ok
    integer :: ios, separator
    character(len=256) :: line

    value = ''
    if (.not. ok) return
    read(unit,'(A)',iostat=ios) line
    if (ios /= 0) then
      ok = .false.
      return
    end if
    separator = index(line, '=')
    if (separator <= 1) then
      ok = .false.
      return
    end if
    if (trim(line(:separator-1)) /= expected_key) then
      ok = .false.
      return
    end if
    if (index(line(separator+1:), '=') /= 0) then
      ok = .false.
      return
    end if
    value = adjustl(line(separator+1:))
    if (len_trim(value) == 0) ok = .false.
  end subroutine read_value_line

  logical function parse_int_text(text, value) result(ok)
    character(len=*), intent(in) :: text
    integer, intent(out) :: value
    integer :: ios
    character(len=64) :: canonical

    ok = .false.
    value = 0
    read(text,*,iostat=ios) value
    if (ios /= 0) return
    write(canonical,'(I0)') value
    if (trim(adjustl(text)) /= trim(canonical)) return
    ok = .true.
  end function parse_int_text

  logical function parse_int64_text(text, value) result(ok)
    character(len=*), intent(in) :: text
    integer(int64), intent(out) :: value
    integer :: ios
    character(len=64) :: canonical

    ok = .false.
    value = 0_int64
    read(text,*,iostat=ios) value
    if (ios /= 0) return
    write(canonical,'(I0)') value
    if (trim(adjustl(text)) /= trim(canonical)) return
    ok = .true.
  end function parse_int64_text

end module mod_fkt13_persistence_adapter

module mod_fwof40_external_crop_restart_adapter
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_kernel_committed_persistence, only: kernel_persistence_snapshot_t, &
       KERNEL_PERSISTENCE_SCHEMA_VERSION, KERNEL_PERSISTENCE_OK, export_kernel_committed_state, &
       reconstruct_kernel_persistence_snapshot_trusted, restore_kernel_committed_state
  use mod_wofost_crop_owner_state, only: wofost_crop_owner_state_t, wofost_common_evolution_continuation_t, &
       wofost_b110_reference_compatibility_t, WOFOST_CROP_OWNER_OK
  use mod_fmr_wofost_crop_transaction, only: fmr_wofost_crop_transaction_state_t, &
       fmr_wofost_crop_transaction_persistence_t, FMR_WOFOST_CROP_PERSISTENCE_OK, &
       export_fmr_wofost_crop_transaction_persistence, reconstruct_fmr_wofost_crop_transaction_from_persistence
  implicit none
  private

  integer(int64), parameter, public :: FWO40_CROP_LAYOUT_ID = 904001_int64
  integer, parameter, public :: FWO40_CROP_CODEC_VERSION = 1
  integer, parameter, public :: FWO40_EXTERNAL_OK = 0
  integer, parameter, public :: FWO40_EXTERNAL_INVALID_SOURCE = 1
  integer, parameter, public :: FWO40_EXTERNAL_IO_ERROR = 2
  integer, parameter, public :: FWO40_EXTERNAL_FORMAT_ERROR = 3
  integer, parameter, public :: FWO40_EXTERNAL_SCHEMA_MISMATCH = 4
  integer, parameter, public :: FWO40_EXTERNAL_LAYOUT_MISMATCH = 5
  integer, parameter, public :: FWO40_EXTERNAL_CODEC_MISMATCH = 6
  integer, parameter, public :: FWO40_EXTERNAL_INVALID_PHYSICAL = 7
  integer, parameter, public :: FWO40_EXTERNAL_RECONSTRUCTION_FAILED = 8

  character(len=*), parameter :: MAGIC = 'SWAP5_FWO40_CROP_RESTART_V1'

  public :: write_fwof40_crop_restart_artifact
  public :: read_fwof40_crop_restart_artifact

contains

  subroutine write_fwof40_crop_restart_artifact(path, committed, written, status)
    character(len=*), intent(in) :: path
    type(kernel_committed_state_t), intent(in) :: committed
    logical, intent(out) :: written
    integer, intent(out) :: status
    type(kernel_persistence_snapshot_t) :: snapshot
    type(fmr_wofost_crop_transaction_persistence_t) :: view
    class(transaction_state_t), allocatable :: physical
    logical :: ok, view_ok, time_available
    integer :: persistence_status, crop_status, u, ios, i, nleaf
    real(real64) :: committed_time
    character(len=64) :: label

    written = .false.
    status = FWO40_EXTERNAL_INVALID_SOURCE
    if (.not. committed%ready() .or. .not. committed%time_is_bound()) return

    call export_kernel_committed_state(committed, FWO40_CROP_LAYOUT_ID, snapshot, ok, persistence_status)
    if (.not. ok .or. persistence_status /= KERNEL_PERSISTENCE_OK .or. .not. snapshot%ready()) return
    call snapshot%snapshot_physical(physical, ok)
    if (.not. ok) return
    select type (tx => physical)
    type is (fmr_wofost_crop_transaction_state_t)
      call export_fmr_wofost_crop_transaction_persistence(tx, view, view_ok, crop_status)
    class default
      return
    end select
    if (.not. view_ok .or. crop_status /= FMR_WOFOST_CROP_PERSISTENCE_OK .or. .not. view%ready()) return
    if (view%owner%validate() /= WOFOST_CROP_OWNER_OK) return

    call snapshot%current_time(committed_time, time_available)
    if (.not. time_available) return

    open(newunit=u, file=trim(path), status='replace', action='write', form='formatted', iostat=ios)
    if (ios /= 0) then
      status = FWO40_EXTERNAL_IO_ERROR
      return
    end if

    write(u,'(A)',iostat=ios) MAGIC
    if (ios == 0) call write_int(u, 'schema', snapshot%schema_version(), ios)
    if (ios == 0) call write_i64(u, 'layout', snapshot%layout_id(), ios)
    if (ios == 0) call write_int(u, 'codec', FWO40_CROP_CODEC_VERSION, ios)
    if (ios == 0) call write_i64(u, 'kernel_lineage', snapshot%current_lineage_id(), ios)
    if (ios == 0) call write_i64(u, 'kernel_revision', snapshot%current_revision(), ios)
    if (ios == 0) call write_flag(u, 'kernel_time_bound', snapshot%time_is_bound(), ios)
    if (ios == 0) call write_bits(u, 'kernel_time_bits', committed_time, ios)

    if (ios == 0) call write_flag(u, 'owner_crop_emerged', view%owner%crop_emerged, ios)
    if (ios == 0) call write_bits(u, 'owner_development_stage_bits', view%owner%development_stage, ios)
    if (ios == 0) call write_flag(u, 'biomass_present', allocated(view%owner%biomass), ios)
    nleaf = 0
    if (allocated(view%owner%biomass)) then
      if (ios == 0) call write_bits(u, 'root_biomass_bits', view%owner%biomass%root_biomass, ios)
      if (ios == 0) call write_bits(u, 'stem_biomass_bits', view%owner%biomass%stem_biomass, ios)
      if (ios == 0) call write_bits(u, 'storage_biomass_bits', view%owner%biomass%storage_biomass, ios)
      if (ios == 0) call write_bits(u, 'exponential_lai_bits', view%owner%biomass%exponential_leaf_area_index, ios)
      if (allocated(view%owner%biomass%leaf_biomass)) nleaf = size(view%owner%biomass%leaf_biomass)
    end if
    if (ios == 0) call write_int(u, 'leaf_count', nleaf, ios)
    if (nleaf > 0) then
      if (.not. allocated(view%owner%biomass%specific_leaf_area) .or. &
          .not. allocated(view%owner%biomass%leaf_age)) ios = 1
      if (ios == 0 .and. size(view%owner%biomass%specific_leaf_area) /= nleaf) ios = 1
      if (ios == 0 .and. size(view%owner%biomass%leaf_age) /= nleaf) ios = 1
      do i = 1, nleaf
        write(label,'("leaf_biomass_bits_",I0)') i
        if (ios == 0) call write_bits(u, trim(label), view%owner%biomass%leaf_biomass(i), ios)
        write(label,'("specific_leaf_area_bits_",I0)') i
        if (ios == 0) call write_bits(u, trim(label), view%owner%biomass%specific_leaf_area(i), ios)
        write(label,'("leaf_age_bits_",I0)') i
        if (ios == 0) call write_bits(u, trim(label), view%owner%biomass%leaf_age(i), ios)
      end do
    end if

    if (ios == 0) call write_flag(u, 'evolution_present', allocated(view%owner%evolution_continuation), ios)
    if (allocated(view%owner%evolution_continuation)) then
      if (ios == 0) call write_bits(u, 'temperature_sum_bits', view%owner%evolution_continuation%temperature_sum, ios)
      if (ios == 0) call write_flag(u, 'anthesis_reached', view%owner%evolution_continuation%anthesis_reached, ios)
      if (ios == 0) call write_int(u, 'minimum_temperature_history_count', &
           view%owner%evolution_continuation%minimum_temperature_history_count, ios)
      do i = 1, 7
        write(label,'("minimum_temperature_history_bits_",I0)') i
        if (ios == 0) call write_bits(u, trim(label), view%owner%evolution_continuation%minimum_temperature_history(i), ios)
      end do
    end if

    if (ios == 0) call write_flag(u, 'b110_compatibility_present', allocated(view%owner%b110_reference_compatibility), ios)
    if (allocated(view%owner%b110_reference_compatibility)) then
      if (ios == 0) call write_bits(u, 'lai_exponential_rate_carryover_bits', &
           view%owner%b110_reference_compatibility%lai_exponential_rate_carryover, ios)
    end if

    if (ios == 0) call write_flag(u, 'receipt_present', view%receipt_present, ios)
    if (view%receipt_present) then
      if (ios == 0) call write_i64(u, 'receipt_lineage', view%receipt%lineage_id, ios)
      if (ios == 0) call write_i64(u, 'receipt_final_revision', view%receipt%final_revision, ios)
      if (ios == 0) call write_bits(u, 'receipt_t0_bits', view%receipt%t0, ios)
      if (ios == 0) call write_bits(u, 'receipt_t1_bits', view%receipt%t1, ios)
      if (ios == 0) call write_bits(u, 'receipt_actual_root_uptake_integral_bits', &
           view%receipt%actual_root_uptake_integral, ios)
      if (ios == 0) call write_bits(u, 'receipt_potential_transpiration_integral_bits', &
           view%receipt%potential_transpiration_integral, ios)
    end if
    if (ios == 0) write(u,'(A)',iostat=ios) 'END'
    close(u)

    if (ios /= 0) then
      status = FWO40_EXTERNAL_IO_ERROR
      return
    end if
    written = .true.
    status = FWO40_EXTERNAL_OK
  end subroutine write_fwof40_crop_restart_artifact

  subroutine read_fwof40_crop_restart_artifact(path, committed, restored, status)
    character(len=*), intent(in) :: path
    type(kernel_committed_state_t), intent(out) :: committed
    logical, intent(out) :: restored
    integer, intent(out) :: status
    type(fmr_wofost_crop_transaction_persistence_t) :: view
    type(fmr_wofost_crop_transaction_state_t) :: tx_state
    type(kernel_persistence_snapshot_t) :: snapshot
    class(transaction_state_t), allocatable :: decoded
    type(wofost_crop_owner_state_t) :: owner
    integer :: u, ios, schema, codec, leaf_count, i, crop_status, persistence_status
    integer(int64) :: layout, lineage, revision
    real(real64) :: committed_time
    logical :: time_bound, flag, ok, tx_ok, snapshot_ok, restore_ok
    character(len=512) :: line
    character(len=64) :: label

    committed = kernel_committed_state_t()
    restored = .false.
    status = FWO40_EXTERNAL_IO_ERROR
    open(newunit=u, file=trim(path), status='old', action='read', form='formatted', iostat=ios)
    if (ios /= 0) return

    call read_exact_line(u, MAGIC, ok)
    if (.not. ok) then; status = FWO40_EXTERNAL_FORMAT_ERROR; close(u); return; end if
    call read_int(u, 'schema', schema, ok)
    if (.not. ok) then; status = FWO40_EXTERNAL_FORMAT_ERROR; close(u); return; end if
    if (schema /= KERNEL_PERSISTENCE_SCHEMA_VERSION) then; status = FWO40_EXTERNAL_SCHEMA_MISMATCH; close(u); return; end if
    call read_i64(u, 'layout', layout, ok)
    if (.not. ok) then; status = FWO40_EXTERNAL_FORMAT_ERROR; close(u); return; end if
    if (layout /= FWO40_CROP_LAYOUT_ID) then; status = FWO40_EXTERNAL_LAYOUT_MISMATCH; close(u); return; end if
    call read_int(u, 'codec', codec, ok)
    if (.not. ok) then; status = FWO40_EXTERNAL_FORMAT_ERROR; close(u); return; end if
    if (codec /= FWO40_CROP_CODEC_VERSION) then; status = FWO40_EXTERNAL_CODEC_MISMATCH; close(u); return; end if
    call read_i64(u, 'kernel_lineage', lineage, ok)
    if (.not. ok) then; status = FWO40_EXTERNAL_FORMAT_ERROR; close(u); return; end if
    call read_i64(u, 'kernel_revision', revision, ok)
    if (.not. ok) then; status = FWO40_EXTERNAL_FORMAT_ERROR; close(u); return; end if
    call read_flag(u, 'kernel_time_bound', time_bound, ok)
    if (.not. ok) then; status = FWO40_EXTERNAL_FORMAT_ERROR; close(u); return; end if
    call read_bits(u, 'kernel_time_bits', committed_time, ok)
    if (.not. ok) then; status = FWO40_EXTERNAL_FORMAT_ERROR; close(u); return; end if

    call read_flag(u, 'owner_crop_emerged', owner%crop_emerged, ok)
    if (.not. ok) then; status = FWO40_EXTERNAL_FORMAT_ERROR; close(u); return; end if
    call read_bits(u, 'owner_development_stage_bits', owner%development_stage, ok)
    if (.not. ok) then; status = FWO40_EXTERNAL_FORMAT_ERROR; close(u); return; end if
    call read_flag(u, 'biomass_present', flag, ok)
    if (.not. ok) then; status = FWO40_EXTERNAL_FORMAT_ERROR; close(u); return; end if
    if (flag) then
      allocate(owner%biomass)
      call read_bits(u, 'root_biomass_bits', owner%biomass%root_biomass, ok)
      if (.not. ok) then; status = FWO40_EXTERNAL_FORMAT_ERROR; close(u); return; end if
      call read_bits(u, 'stem_biomass_bits', owner%biomass%stem_biomass, ok)
      if (.not. ok) then; status = FWO40_EXTERNAL_FORMAT_ERROR; close(u); return; end if
      call read_bits(u, 'storage_biomass_bits', owner%biomass%storage_biomass, ok)
      if (.not. ok) then; status = FWO40_EXTERNAL_FORMAT_ERROR; close(u); return; end if
      call read_bits(u, 'exponential_lai_bits', owner%biomass%exponential_leaf_area_index, ok)
      if (.not. ok) then; status = FWO40_EXTERNAL_FORMAT_ERROR; close(u); return; end if
    end if
    call read_int(u, 'leaf_count', leaf_count, ok)
    if (.not. ok .or. leaf_count < 0) then; status = FWO40_EXTERNAL_FORMAT_ERROR; close(u); return; end if
    if (.not. flag .and. leaf_count /= 0) then; status = FWO40_EXTERNAL_FORMAT_ERROR; close(u); return; end if
    if (leaf_count > 0) then
      allocate(owner%biomass%leaf_biomass(leaf_count), owner%biomass%specific_leaf_area(leaf_count), &
           owner%biomass%leaf_age(leaf_count))
      do i = 1, leaf_count
        write(label,'("leaf_biomass_bits_",I0)') i
        call read_bits(u, trim(label), owner%biomass%leaf_biomass(i), ok)
        if (.not. ok) then; status = FWO40_EXTERNAL_FORMAT_ERROR; close(u); return; end if
        write(label,'("specific_leaf_area_bits_",I0)') i
        call read_bits(u, trim(label), owner%biomass%specific_leaf_area(i), ok)
        if (.not. ok) then; status = FWO40_EXTERNAL_FORMAT_ERROR; close(u); return; end if
        write(label,'("leaf_age_bits_",I0)') i
        call read_bits(u, trim(label), owner%biomass%leaf_age(i), ok)
        if (.not. ok) then; status = FWO40_EXTERNAL_FORMAT_ERROR; close(u); return; end if
      end do
    end if

    call read_flag(u, 'evolution_present', flag, ok)
    if (.not. ok) then; status = FWO40_EXTERNAL_FORMAT_ERROR; close(u); return; end if
    if (flag) then
      allocate(wofost_common_evolution_continuation_t :: owner%evolution_continuation)
      call read_bits(u, 'temperature_sum_bits', owner%evolution_continuation%temperature_sum, ok)
      if (.not. ok) then; status = FWO40_EXTERNAL_FORMAT_ERROR; close(u); return; end if
      call read_flag(u, 'anthesis_reached', owner%evolution_continuation%anthesis_reached, ok)
      if (.not. ok) then; status = FWO40_EXTERNAL_FORMAT_ERROR; close(u); return; end if
      call read_int(u, 'minimum_temperature_history_count', &
           owner%evolution_continuation%minimum_temperature_history_count, ok)
      if (.not. ok) then; status = FWO40_EXTERNAL_FORMAT_ERROR; close(u); return; end if
      do i = 1, 7
        write(label,'("minimum_temperature_history_bits_",I0)') i
        call read_bits(u, trim(label), owner%evolution_continuation%minimum_temperature_history(i), ok)
        if (.not. ok) then; status = FWO40_EXTERNAL_FORMAT_ERROR; close(u); return; end if
      end do
    end if

    call read_flag(u, 'b110_compatibility_present', flag, ok)
    if (.not. ok) then; status = FWO40_EXTERNAL_FORMAT_ERROR; close(u); return; end if
    if (flag) then
      allocate(wofost_b110_reference_compatibility_t :: owner%b110_reference_compatibility)
      call read_bits(u, 'lai_exponential_rate_carryover_bits', &
           owner%b110_reference_compatibility%lai_exponential_rate_carryover, ok)
      if (.not. ok) then; status = FWO40_EXTERNAL_FORMAT_ERROR; close(u); return; end if
    end if

    call read_flag(u, 'receipt_present', view%receipt_present, ok)
    if (.not. ok) then; status = FWO40_EXTERNAL_FORMAT_ERROR; close(u); return; end if
    if (view%receipt_present) then
      call read_i64(u, 'receipt_lineage', view%receipt%lineage_id, ok)
      if (.not. ok) then; status = FWO40_EXTERNAL_FORMAT_ERROR; close(u); return; end if
      call read_i64(u, 'receipt_final_revision', view%receipt%final_revision, ok)
      if (.not. ok) then; status = FWO40_EXTERNAL_FORMAT_ERROR; close(u); return; end if
      call read_bits(u, 'receipt_t0_bits', view%receipt%t0, ok)
      if (.not. ok) then; status = FWO40_EXTERNAL_FORMAT_ERROR; close(u); return; end if
      call read_bits(u, 'receipt_t1_bits', view%receipt%t1, ok)
      if (.not. ok) then; status = FWO40_EXTERNAL_FORMAT_ERROR; close(u); return; end if
      call read_bits(u, 'receipt_actual_root_uptake_integral_bits', view%receipt%actual_root_uptake_integral, ok)
      if (.not. ok) then; status = FWO40_EXTERNAL_FORMAT_ERROR; close(u); return; end if
      call read_bits(u, 'receipt_potential_transpiration_integral_bits', view%receipt%potential_transpiration_integral, ok)
      if (.not. ok) then; status = FWO40_EXTERNAL_FORMAT_ERROR; close(u); return; end if
      view%receipt%valid = .true.
    end if

    call read_exact_line(u, 'END', ok)
    if (.not. ok) then; status = FWO40_EXTERNAL_FORMAT_ERROR; close(u); return; end if
    read(u,'(A)',iostat=ios) line
    close(u)
    if (ios >= 0) then
      status = FWO40_EXTERNAL_FORMAT_ERROR
      return
    end if

    if (owner%validate() /= WOFOST_CROP_OWNER_OK) then
      status = FWO40_EXTERNAL_INVALID_PHYSICAL
      return
    end if
    view%owner = owner
    view%valid = .true.
    if (.not. view%ready()) then
      status = FWO40_EXTERNAL_INVALID_PHYSICAL
      return
    end if

    call reconstruct_fmr_wofost_crop_transaction_from_persistence(view, tx_state, tx_ok, crop_status)
    if (.not. tx_ok .or. crop_status /= FMR_WOFOST_CROP_PERSISTENCE_OK .or. .not. tx_state%ready()) then
      status = FWO40_EXTERNAL_INVALID_PHYSICAL
      return
    end if
    allocate(fmr_wofost_crop_transaction_state_t :: decoded)
    select type (typed => decoded)
    type is (fmr_wofost_crop_transaction_state_t)
      typed = tx_state
    class default
      status = FWO40_EXTERNAL_RECONSTRUCTION_FAILED
      return
    end select

    call reconstruct_kernel_persistence_snapshot_trusted(schema, layout, lineage, revision, committed_time, &
         time_bound, decoded, snapshot, snapshot_ok, persistence_status)
    if (.not. snapshot_ok .or. persistence_status /= KERNEL_PERSISTENCE_OK .or. .not. snapshot%ready()) then
      status = FWO40_EXTERNAL_RECONSTRUCTION_FAILED
      return
    end if
    call restore_kernel_committed_state(snapshot, FWO40_CROP_LAYOUT_ID, committed, restore_ok, persistence_status)
    if (.not. restore_ok .or. persistence_status /= KERNEL_PERSISTENCE_OK .or. .not. committed%ready()) then
      committed = kernel_committed_state_t()
      status = FWO40_EXTERNAL_RECONSTRUCTION_FAILED
      return
    end if

    restored = .true.
    status = FWO40_EXTERNAL_OK
  end subroutine read_fwof40_crop_restart_artifact

  subroutine write_int(u, label, value, ios)
    integer, intent(in) :: u, value
    character(len=*), intent(in) :: label
    integer, intent(inout) :: ios
    if (ios /= 0) return
    write(u,'(A,1X,I0)',iostat=ios) trim(label), value
  end subroutine write_int

  subroutine write_i64(u, label, value, ios)
    integer, intent(in) :: u
    character(len=*), intent(in) :: label
    integer(int64), intent(in) :: value
    integer, intent(inout) :: ios
    if (ios /= 0) return
    write(u,'(A,1X,I0)',iostat=ios) trim(label), value
  end subroutine write_i64

  subroutine write_flag(u, label, value, ios)
    integer, intent(in) :: u
    character(len=*), intent(in) :: label
    logical, intent(in) :: value
    integer, intent(inout) :: ios
    if (value) then
      call write_int(u, label, 1, ios)
    else
      call write_int(u, label, 0, ios)
    end if
  end subroutine write_flag

  subroutine write_bits(u, label, value, ios)
    integer, intent(in) :: u
    character(len=*), intent(in) :: label
    real(real64), intent(in) :: value
    integer, intent(inout) :: ios
    call write_i64(u, label, transfer(value, 0_int64), ios)
  end subroutine write_bits

  subroutine read_exact_line(u, expected, ok)
    integer, intent(in) :: u
    character(len=*), intent(in) :: expected
    logical, intent(out) :: ok
    character(len=512) :: line
    integer :: ios
    read(u,'(A)',iostat=ios) line
    ok = ios == 0 .and. trim(line) == trim(expected)
  end subroutine read_exact_line

  subroutine read_payload(u, label, payload, ok)
    integer, intent(in) :: u
    character(len=*), intent(in) :: label
    character(len=*), intent(out) :: payload
    logical, intent(out) :: ok
    character(len=512) :: line, prefix
    integer :: ios, n
    payload = ''
    ok = .false.
    read(u,'(A)',iostat=ios) line
    if (ios /= 0) return
    prefix = trim(label)//' '
    n = len_trim(prefix)
    if (len_trim(line) <= n) return
    if (line(1:n) /= prefix(1:n)) return
    payload = adjustl(line(n+1:len_trim(line)))
    if (len_trim(payload) == 0) return
    if (index(trim(payload), ' ') /= 0) return
    ok = .true.
  end subroutine read_payload

  subroutine read_int(u, label, value, ok)
    integer, intent(in) :: u
    character(len=*), intent(in) :: label
    integer, intent(out) :: value
    logical, intent(out) :: ok
    character(len=512) :: payload
    character(len=64) :: canonical
    integer :: ios
    value = 0
    call read_payload(u, label, payload, ok)
    if (.not. ok) return
    read(payload,*,iostat=ios) value
    if (ios /= 0) then; ok = .false.; return; end if
    write(canonical,'(I0)') value
    ok = trim(payload) == trim(canonical)
  end subroutine read_int

  subroutine read_i64(u, label, value, ok)
    integer, intent(in) :: u
    character(len=*), intent(in) :: label
    integer(int64), intent(out) :: value
    logical, intent(out) :: ok
    character(len=512) :: payload
    character(len=64) :: canonical
    integer :: ios
    value = 0_int64
    call read_payload(u, label, payload, ok)
    if (.not. ok) return
    read(payload,*,iostat=ios) value
    if (ios /= 0) then; ok = .false.; return; end if
    write(canonical,'(I0)') value
    ok = trim(payload) == trim(canonical)
  end subroutine read_i64

  subroutine read_flag(u, label, value, ok)
    integer, intent(in) :: u
    character(len=*), intent(in) :: label
    logical, intent(out) :: value
    logical, intent(out) :: ok
    integer :: raw
    value = .false.
    call read_int(u, label, raw, ok)
    if (.not. ok) return
    if (raw == 0) then
      value = .false.
    else if (raw == 1) then
      value = .true.
    else
      ok = .false.
    end if
  end subroutine read_flag

  subroutine read_bits(u, label, value, ok)
    integer, intent(in) :: u
    character(len=*), intent(in) :: label
    real(real64), intent(out) :: value
    logical, intent(out) :: ok
    integer(int64) :: bits
    value = 0.0_real64
    call read_i64(u, label, bits, ok)
    if (ok) value = transfer(bits, value)
  end subroutine read_bits

end module mod_fwof40_external_crop_restart_adapter

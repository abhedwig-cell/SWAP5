module mod_ppa_wu05a2_macropore_state
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: PPA_WU05A2_SCHEMA_VERSION = 1

  type, public :: ppa_wu05a2_macropore_payload_t
    integer :: n_domains = 0
    integer :: n_compartments = 0
    integer, allocatable :: bottom_domain(:)                 ! ICpBtDm
    integer, allocatable :: bottom_domain_previous(:)        ! ICpBtDmM1
    real(real64), allocatable :: domain_water_storage(:)      ! WaSrMpDm
    real(real64), allocatable :: pore_volume(:,:)             ! VlMpDmCp
    real(real64), allocatable :: pore_volume_previous(:,:)    ! VlMpDmCpM1
    real(real64), allocatable :: pore_water(:,:)              ! WaUnMpDmCp
    real(real64), allocatable :: pore_water_previous(:,:)     ! WaUnMpDmCpM1
    real(real64), allocatable :: sorptivity_reference(:,:)    ! ThtSrpRefDmCp
    real(real64), allocatable :: sorptivity(:,:)              ! SorpDmCp
    real(real64), allocatable :: absorption_time(:,:)         ! TimAbsCumDmCp
    logical, allocatable :: sorptivity_event_ended(:,:)       ! FlEndSrpEvt
  contains
    procedure :: ready => ppa_wu05a2_payload_ready
  end type ppa_wu05a2_macropore_payload_t

  type, public :: ppa_wu05a2_macropore_committed_t
    integer(int64) :: lineage_id = 0_int64
    integer(int64) :: revision = -1_int64
    type(ppa_wu05a2_macropore_payload_t) :: payload
  end type ppa_wu05a2_macropore_committed_t

  type, public :: ppa_wu05a2_macropore_checkpoint_t
    integer(int64) :: lineage_id = 0_int64
    integer(int64) :: revision = -1_int64
    type(ppa_wu05a2_macropore_payload_t) :: payload
  end type ppa_wu05a2_macropore_checkpoint_t

  type, public :: ppa_wu05a2_macropore_candidate_t
    logical :: valid = .false.
    integer(int64) :: origin_lineage_id = 0_int64
    integer(int64) :: origin_revision = -1_int64
    type(ppa_wu05a2_macropore_payload_t) :: payload
  end type ppa_wu05a2_macropore_candidate_t

  type, public :: ppa_wu05a2_macropore_restart_t
    integer :: schema_version = 0
    type(ppa_wu05a2_macropore_committed_t) :: committed
  end type ppa_wu05a2_macropore_restart_t

  public :: ppa_wu05a2_initialize_payload
  public :: ppa_wu05a2_capture_checkpoint, ppa_wu05a2_restore_checkpoint
  public :: ppa_wu05a2_begin_candidate, ppa_wu05a2_discard_candidate, ppa_wu05a2_commit_candidate
  public :: ppa_wu05a2_export_restart, ppa_wu05a2_restore_restart
  public :: ppa_wu05a2_optional_restart_complete

contains

  subroutine ppa_wu05a2_initialize_payload(n_domains, n_compartments, payload, accepted)
    integer, intent(in) :: n_domains, n_compartments
    type(ppa_wu05a2_macropore_payload_t), intent(out) :: payload
    logical, intent(out) :: accepted

    accepted = .false.
    if (n_domains <= 0 .or. n_compartments <= 0) return
    payload%n_domains = n_domains
    payload%n_compartments = n_compartments
    allocate(payload%bottom_domain(n_domains), payload%bottom_domain_previous(n_domains))
    allocate(payload%domain_water_storage(n_domains))
    allocate(payload%pore_volume(n_domains,n_compartments), payload%pore_volume_previous(n_domains,n_compartments))
    allocate(payload%pore_water(n_domains,n_compartments), payload%pore_water_previous(n_domains,n_compartments))
    allocate(payload%sorptivity_reference(n_domains,n_compartments), payload%sorptivity(n_domains,n_compartments))
    allocate(payload%absorption_time(n_domains,n_compartments), payload%sorptivity_event_ended(n_domains,n_compartments))
    payload%bottom_domain = 0
    payload%bottom_domain_previous = 0
    payload%domain_water_storage = 0.0_real64
    payload%pore_volume = 0.0_real64
    payload%pore_volume_previous = 0.0_real64
    payload%pore_water = 0.0_real64
    payload%pore_water_previous = 0.0_real64
    payload%sorptivity_reference = 0.0_real64
    payload%sorptivity = 0.0_real64
    payload%absorption_time = 0.0_real64
    payload%sorptivity_event_ended = .true.
    accepted = payload%ready()
  end subroutine ppa_wu05a2_initialize_payload

  pure logical function ppa_wu05a2_payload_ready(self) result(ready)
    class(ppa_wu05a2_macropore_payload_t), intent(in) :: self
    integer :: nd, nc

    ready = .false.
    nd = self%n_domains
    nc = self%n_compartments
    if (nd <= 0 .or. nc <= 0) return
    if (.not. allocated(self%bottom_domain) .or. .not. allocated(self%bottom_domain_previous) .or. &
        .not. allocated(self%domain_water_storage) .or. .not. allocated(self%pore_volume) .or. &
        .not. allocated(self%pore_volume_previous) .or. .not. allocated(self%pore_water) .or. &
        .not. allocated(self%pore_water_previous) .or. .not. allocated(self%sorptivity_reference) .or. &
        .not. allocated(self%sorptivity) .or. .not. allocated(self%absorption_time) .or. &
        .not. allocated(self%sorptivity_event_ended)) return
    if (size(self%bottom_domain) /= nd .or. size(self%bottom_domain_previous) /= nd .or. &
        size(self%domain_water_storage) /= nd) return
    if (size(self%pore_volume,1) /= nd .or. size(self%pore_volume,2) /= nc .or. &
        size(self%pore_volume_previous,1) /= nd .or. size(self%pore_volume_previous,2) /= nc .or. &
        size(self%pore_water,1) /= nd .or. size(self%pore_water,2) /= nc .or. &
        size(self%pore_water_previous,1) /= nd .or. size(self%pore_water_previous,2) /= nc .or. &
        size(self%sorptivity_reference,1) /= nd .or. size(self%sorptivity_reference,2) /= nc .or. &
        size(self%sorptivity,1) /= nd .or. size(self%sorptivity,2) /= nc .or. &
        size(self%absorption_time,1) /= nd .or. size(self%absorption_time,2) /= nc .or. &
        size(self%sorptivity_event_ended,1) /= nd .or. size(self%sorptivity_event_ended,2) /= nc) return
    if (any(self%bottom_domain < 0) .or. any(self%bottom_domain > nc) .or. &
        any(self%bottom_domain_previous < 0) .or. any(self%bottom_domain_previous > nc)) return
    if (.not. all(ieee_is_finite(self%domain_water_storage)) .or. &
        .not. all(ieee_is_finite(self%pore_volume)) .or. .not. all(ieee_is_finite(self%pore_volume_previous)) .or. &
        .not. all(ieee_is_finite(self%pore_water)) .or. .not. all(ieee_is_finite(self%pore_water_previous)) .or. &
        .not. all(ieee_is_finite(self%sorptivity_reference)) .or. .not. all(ieee_is_finite(self%sorptivity)) .or. &
        .not. all(ieee_is_finite(self%absorption_time))) return
    if (any(self%domain_water_storage < 0.0_real64) .or. any(self%pore_volume < 0.0_real64) .or. &
        any(self%pore_volume_previous < 0.0_real64) .or. any(self%pore_water < 0.0_real64) .or. &
        any(self%pore_water_previous < 0.0_real64) .or. any(self%sorptivity < 0.0_real64) .or. &
        any(self%absorption_time < 0.0_real64)) return
    ready = .true.
  end function ppa_wu05a2_payload_ready

  subroutine ppa_wu05a2_capture_checkpoint(committed, checkpoint, accepted)
    type(ppa_wu05a2_macropore_committed_t), intent(in) :: committed
    type(ppa_wu05a2_macropore_checkpoint_t), intent(out) :: checkpoint
    logical, intent(out) :: accepted

    accepted = committed%lineage_id > 0_int64 .and. committed%revision >= 0_int64 .and. committed%payload%ready()
    if (.not. accepted) return
    checkpoint%lineage_id = committed%lineage_id
    checkpoint%revision = committed%revision
    checkpoint%payload = committed%payload
  end subroutine ppa_wu05a2_capture_checkpoint

  subroutine ppa_wu05a2_restore_checkpoint(checkpoint, committed, accepted)
    type(ppa_wu05a2_macropore_checkpoint_t), intent(in) :: checkpoint
    type(ppa_wu05a2_macropore_committed_t), intent(inout) :: committed
    logical, intent(out) :: accepted

    accepted = checkpoint%lineage_id > 0_int64 .and. checkpoint%revision >= 0_int64 .and. checkpoint%payload%ready()
    if (.not. accepted) return
    if (committed%lineage_id > 0_int64 .and. committed%lineage_id /= checkpoint%lineage_id) then
      accepted = .false.
      return
    end if
    committed%lineage_id = checkpoint%lineage_id
    committed%revision = checkpoint%revision
    committed%payload = checkpoint%payload
  end subroutine ppa_wu05a2_restore_checkpoint

  subroutine ppa_wu05a2_begin_candidate(checkpoint, candidate, accepted)
    type(ppa_wu05a2_macropore_checkpoint_t), intent(in) :: checkpoint
    type(ppa_wu05a2_macropore_candidate_t), intent(out) :: candidate
    logical, intent(out) :: accepted

    accepted = checkpoint%lineage_id > 0_int64 .and. checkpoint%revision >= 0_int64 .and. checkpoint%payload%ready()
    if (.not. accepted) return
    candidate%payload = checkpoint%payload
    candidate%origin_lineage_id = checkpoint%lineage_id
    candidate%origin_revision = checkpoint%revision
    candidate%valid = .true.
  end subroutine ppa_wu05a2_begin_candidate

  subroutine ppa_wu05a2_discard_candidate(candidate)
    type(ppa_wu05a2_macropore_candidate_t), intent(inout) :: candidate
    candidate = ppa_wu05a2_macropore_candidate_t()
  end subroutine ppa_wu05a2_discard_candidate

  subroutine ppa_wu05a2_commit_candidate(candidate, committed, accepted)
    type(ppa_wu05a2_macropore_candidate_t), intent(inout) :: candidate
    type(ppa_wu05a2_macropore_committed_t), intent(inout) :: committed
    logical, intent(out) :: accepted

    accepted = .false.
    if (.not. candidate%valid .or. .not. candidate%payload%ready()) return
    if (candidate%origin_lineage_id /= committed%lineage_id .or. candidate%origin_revision /= committed%revision) return
    if (committed%revision == huge(committed%revision)) return
    committed%payload = candidate%payload
    committed%revision = committed%revision + 1_int64
    call ppa_wu05a2_discard_candidate(candidate)
    accepted = .true.
  end subroutine ppa_wu05a2_commit_candidate

  subroutine ppa_wu05a2_export_restart(committed, restart, exported)
    type(ppa_wu05a2_macropore_committed_t), intent(in) :: committed
    type(ppa_wu05a2_macropore_restart_t), intent(out) :: restart
    logical, intent(out) :: exported

    exported = committed%lineage_id > 0_int64 .and. committed%revision >= 0_int64 .and. committed%payload%ready()
    if (.not. exported) return
    restart%schema_version = PPA_WU05A2_SCHEMA_VERSION
    restart%committed = committed
  end subroutine ppa_wu05a2_export_restart

  subroutine ppa_wu05a2_restore_restart(restart, committed, restored)
    type(ppa_wu05a2_macropore_restart_t), intent(in) :: restart
    type(ppa_wu05a2_macropore_committed_t), intent(out) :: committed
    logical, intent(out) :: restored

    restored = .false.
    if (restart%schema_version /= PPA_WU05A2_SCHEMA_VERSION) return
    if (restart%committed%lineage_id <= 0_int64 .or. restart%committed%revision < 0_int64) return
    if (.not. restart%committed%payload%ready()) return
    committed = restart%committed
    restored = .true.
  end subroutine ppa_wu05a2_restore_restart

  logical function ppa_wu05a2_optional_restart_complete(restart, macropore_active, n_domains, n_compartments) result(complete)
    type(ppa_wu05a2_macropore_restart_t), allocatable, intent(in) :: restart
    logical, intent(in) :: macropore_active
    integer, intent(in) :: n_domains, n_compartments

    complete = .false.
    if (.not. macropore_active) then
      complete = .not. allocated(restart)
      return
    end if
    if (.not. allocated(restart)) return
    if (restart%schema_version /= PPA_WU05A2_SCHEMA_VERSION) return
    if (.not. restart%committed%payload%ready()) return
    complete = restart%committed%payload%n_domains == n_domains .and. &
               restart%committed%payload%n_compartments == n_compartments .and. &
               restart%committed%lineage_id > 0_int64 .and. restart%committed%revision >= 0_int64
  end function ppa_wu05a2_optional_restart_complete

end module mod_ppa_wu05a2_macropore_state

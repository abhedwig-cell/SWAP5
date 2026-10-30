module mod_fmr_wofost_accepted_window_lineage
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_kernel_transactions, only: kernel_checkpoint_t, kernel_committed_state_t
  use mod_wofost_one_day_structural_evolution, only: wofost_accepted_window_aggregates_t
  implicit none
  private

  integer, parameter, public :: FMR_WOFOST_LINEAGE_OK = 0
  integer, parameter, public :: FMR_WOFOST_LINEAGE_INVALID_CHECKPOINT = 1
  integer, parameter, public :: FMR_WOFOST_LINEAGE_INVALID_COMMITTED = 2
  integer, parameter, public :: FMR_WOFOST_LINEAGE_COMMIT_NOT_PROVEN = 3
  integer, parameter, public :: FMR_WOFOST_LINEAGE_INVALID_TRIAL = 4
  integer, parameter, public :: FMR_WOFOST_LINEAGE_INVALID_WINDOW = 5
  integer, parameter, public :: FMR_WOFOST_LINEAGE_INVALID_PROCESS_RATE = 6
  integer, parameter, public :: FMR_WOFOST_LINEAGE_NONCONTIGUOUS = 7
  integer, parameter, public :: FMR_WOFOST_LINEAGE_CERTIFICATE_MISMATCH = 8
  integer, parameter, public :: FMR_WOFOST_LINEAGE_WINDOW_INCOMPLETE = 9
  integer, parameter, public :: FMR_WOFOST_LINEAGE_EVENT_ALREADY_DELIVERED = 10
  integer, parameter, public :: FMR_WOFOST_LINEAGE_EVENT_TOKEN_MISMATCH = 11
  integer, parameter, public :: FMR_WOFOST_LINEAGE_TRIAL_WINDOW_MISMATCH = 12
  integer, parameter, public :: FMR_WOFOST_LINEAGE_INVALID_PERSISTENCE = 13

  type, public :: fmr_wofost_accepted_interval_certificate_t
    private
    logical :: initialized = .false.
    integer(int64) :: lineage_id = 0_int64
    integer(int64) :: origin_revision = -1_int64
    integer(int64) :: committed_revision = -1_int64
    real(real64) :: t0 = 0.0_real64
    real(real64) :: t1 = 0.0_real64
  contains
    procedure, public :: ready => certificate_ready
  end type fmr_wofost_accepted_interval_certificate_t

  type, public :: fmr_wofost_trial_contribution_t
    private
    logical :: initialized = .false.
    integer(int64) :: lineage_id = 0_int64
    integer(int64) :: origin_revision = -1_int64
    real(real64) :: t0 = 0.0_real64
    real(real64) :: t1 = 0.0_real64
    real(real64) :: next_t = 0.0_real64
    real(real64) :: actual_root_uptake_integral = 0.0_real64
    real(real64) :: potential_transpiration_integral = 0.0_real64
    logical :: deepest_root_oxygen_factor_available = .false.
    real(real64) :: deepest_root_oxygen_factor_integral = 0.0_real64
    logical :: rootzone_drought_uptake_factor_available = .false.
    real(real64) :: rootzone_drought_uptake_factor_integral = 0.0_real64
    real(real64), allocatable :: potential_root_sink_integral(:), root_sink_reduction_integral(:)
    logical :: root_layer_reduction_clipped=.false.
  contains
    procedure, public :: ready => trial_ready
    procedure, public :: complete => trial_complete
  end type fmr_wofost_trial_contribution_t

  type, public :: fmr_wofost_accepted_window_t
    private
    logical :: initialized = .false.
    integer(int64) :: lineage_id = 0_int64
    integer(int64) :: start_revision = -1_int64
    integer(int64) :: next_revision = -1_int64
    integer :: accepted_intervals = 0
    real(real64) :: t0 = 0.0_real64
    real(real64) :: t1 = 0.0_real64
    real(real64) :: covered_t = 0.0_real64
    real(real64) :: actual_root_uptake_integral = 0.0_real64
    real(real64) :: potential_transpiration_integral = 0.0_real64
    logical :: deepest_root_oxygen_factor_available = .false.
    real(real64) :: deepest_root_oxygen_factor_integral = 0.0_real64
    logical :: rootzone_drought_uptake_factor_available = .false.
    real(real64) :: rootzone_drought_uptake_factor_integral = 0.0_real64
    real(real64), allocatable :: potential_root_sink_integral(:), root_sink_reduction_integral(:)
    logical :: root_layer_reduction_clipped=.false.
    logical :: event_delivered = .false.
  contains
    procedure, public :: ready => accepted_window_ready
    procedure, public :: complete => accepted_window_complete
    procedure, public :: event_due => accepted_window_event_due
    procedure, public :: delivery_committed => accepted_window_delivery_committed
    procedure, public :: interval_count => accepted_window_interval_count
  end type fmr_wofost_accepted_window_t

  type, public :: fmr_wofost_crop_event_token_t
    private
    logical :: initialized = .false.
    integer(int64) :: lineage_id = 0_int64
    integer(int64) :: final_revision = -1_int64
    real(real64) :: t0 = 0.0_real64
    real(real64) :: t1 = 0.0_real64
    real(real64) :: actual_root_uptake_integral = 0.0_real64
    real(real64) :: potential_transpiration_integral = 0.0_real64
    logical :: deepest_root_oxygen_factor_available = .false.
    real(real64) :: deepest_root_oxygen_factor_integral = 0.0_real64
    logical :: rootzone_drought_uptake_factor_available = .false.
    real(real64) :: rootzone_drought_uptake_factor_integral = 0.0_real64
    real(real64), allocatable :: potential_root_sink_integral(:), root_sink_reduction_integral(:)
    logical :: root_layer_reduction_clipped=.false.
  contains
    procedure, public :: ready => crop_event_token_ready
  end type fmr_wofost_crop_event_token_t

  ! Compact opaque identity of one frozen accepted physical crop event.
  ! This is provenance metadata, not crop physics and not a second commit owner.
  type, public :: fmr_wofost_crop_event_identity_t
    private
    logical :: initialized = .false.
    integer(int64) :: lineage_id = 0_int64
    integer(int64) :: final_revision = -1_int64
    real(real64) :: t0 = 0.0_real64
    real(real64) :: t1 = 0.0_real64
    real(real64) :: actual_root_uptake_integral = 0.0_real64
    real(real64) :: potential_transpiration_integral = 0.0_real64
    logical :: deepest_root_oxygen_factor_available = .false.
    real(real64) :: deepest_root_oxygen_factor_integral = 0.0_real64
    logical :: rootzone_drought_uptake_factor_available = .false.
    real(real64) :: rootzone_drought_uptake_factor_integral = 0.0_real64
    real(real64), allocatable :: potential_root_sink_integral(:), root_sink_reduction_integral(:)
    logical :: root_layer_reduction_clipped=.false.
  contains
    procedure, public :: ready => crop_event_identity_ready
  end type fmr_wofost_crop_event_identity_t

  ! Serialization-neutral owner view of the committed crop-event receipt.
  ! This is data, not commit authority. External adapters may encode these
  ! fields, but reconstruction is validated by this owner module.
  type, public :: fmr_wofost_crop_event_identity_persistence_t
    logical :: valid = .false.
    integer(int64) :: lineage_id = 0_int64
    integer(int64) :: final_revision = -1_int64
    real(real64) :: t0 = 0.0_real64
    real(real64) :: t1 = 0.0_real64
    real(real64) :: actual_root_uptake_integral = 0.0_real64
    real(real64) :: potential_transpiration_integral = 0.0_real64
    logical :: deepest_root_oxygen_factor_available = .false.
    real(real64) :: deepest_root_oxygen_factor_integral = 0.0_real64
    logical :: rootzone_drought_uptake_factor_available = .false.
    real(real64) :: rootzone_drought_uptake_factor_integral = 0.0_real64
    real(real64), allocatable :: potential_root_sink_integral(:), root_sink_reduction_integral(:)
    logical :: root_layer_reduction_clipped=.false.
  contains
    procedure, public :: ready => crop_event_identity_persistence_ready
  end type fmr_wofost_crop_event_identity_persistence_t

  ! Data view only; reconstruction remains validated by this accepted-window owner.
  type, public :: fmr_wofost_window_persistence_t
    logical :: initialized = .false.
    integer(int64) :: lineage_id = 0_int64
    integer(int64) :: start_revision = -1_int64
    integer(int64) :: next_revision = -1_int64
    integer :: accepted_intervals = 0
    real(real64) :: t0 = 0.0_real64
    real(real64) :: t1 = 0.0_real64
    real(real64) :: covered_t = 0.0_real64
    real(real64) :: actual_root_uptake_integral = 0.0_real64
    real(real64) :: potential_transpiration_integral = 0.0_real64
    logical :: deepest_root_oxygen_factor_available = .false.
    real(real64) :: deepest_root_oxygen_factor_integral = 0.0_real64
    logical :: rootzone_drought_uptake_factor_available = .false.
    real(real64) :: rootzone_drought_uptake_factor_integral = 0.0_real64
    real(real64), allocatable :: potential_root_sink_integral(:), root_sink_reduction_integral(:)
    logical :: root_layer_reduction_clipped=.false.
    logical :: event_delivered = .false.
  end type
  public :: export_wofost_window_persistence,reconstruct_wofost_window_persistence
  public :: certify_fkt_accepted_interval
  public :: begin_wofost_trial_contribution
  public :: accumulate_wofost_trial_process_rate
  public :: discard_wofost_trial_contribution
  public :: open_wofost_accepted_window
  public :: prevalidate_wofost_trial_admission
  public :: admit_wofost_accepted_trial
  public :: prepare_wofost_crop_event_delivery
  public :: commit_wofost_crop_event_delivery
  public :: identify_wofost_crop_event
  public :: same_wofost_crop_event_identity
  public :: crop_event_identity_matches_interval
  public :: export_wofost_crop_event_identity_persistence
  public :: reconstruct_wofost_crop_event_identity_from_persistence

contains
  subroutine export_wofost_window_persistence(window,view,status)
    type(fmr_wofost_accepted_window_t),intent(in)::window
    type(fmr_wofost_window_persistence_t),intent(out)::view
    integer,intent(out)::status
    view=fmr_wofost_window_persistence_t();status=FMR_WOFOST_LINEAGE_INVALID_PERSISTENCE
    if(window%initialized.and..not.window%ready())return
    view%initialized=window%initialized
    view%lineage_id=window%lineage_id
    view%start_revision=window%start_revision
    view%next_revision=window%next_revision
    view%accepted_intervals=window%accepted_intervals
    view%t0=window%t0
    view%t1=window%t1
    view%covered_t=window%covered_t
    view%actual_root_uptake_integral=window%actual_root_uptake_integral
    view%potential_transpiration_integral=window%potential_transpiration_integral
    view%deepest_root_oxygen_factor_available=window%deepest_root_oxygen_factor_available
    view%deepest_root_oxygen_factor_integral=window%deepest_root_oxygen_factor_integral
    view%rootzone_drought_uptake_factor_available=window%rootzone_drought_uptake_factor_available
    view%rootzone_drought_uptake_factor_integral=window%rootzone_drought_uptake_factor_integral
    view%root_layer_reduction_clipped=window%root_layer_reduction_clipped
    if(allocated(window%potential_root_sink_integral))view%potential_root_sink_integral=window%potential_root_sink_integral
    if(allocated(window%root_sink_reduction_integral))view%root_sink_reduction_integral=window%root_sink_reduction_integral
    view%event_delivered=window%event_delivered
    status=FMR_WOFOST_LINEAGE_OK
  end subroutine
  subroutine reconstruct_wofost_window_persistence(view,window,status)
    type(fmr_wofost_window_persistence_t),intent(in)::view
    type(fmr_wofost_accepted_window_t),intent(out)::window
    type(fmr_wofost_accepted_window_t)::pending
    integer,intent(out)::status
    window=fmr_wofost_accepted_window_t();status=FMR_WOFOST_LINEAGE_INVALID_PERSISTENCE
    if(.not.view%initialized)then
      ! Only the canonical empty previous-window representation is accepted.
      if(view%lineage_id/=0_int64.or.view%start_revision/=-1_int64.or.view%next_revision/=-1_int64.or. &
        view%accepted_intervals/=0.or.view%event_delivered)return
      if(any([view%t0,view%t1,view%covered_t,view%actual_root_uptake_integral, &
        view%potential_transpiration_integral,view%deepest_root_oxygen_factor_integral, &
        view%rootzone_drought_uptake_factor_integral]/=0._real64))return
      if(view%root_layer_reduction_clipped)return
      if(view%deepest_root_oxygen_factor_available.or.view%rootzone_drought_uptake_factor_available)return
      if(allocated(view%potential_root_sink_integral).or.allocated(view%root_sink_reduction_integral))return
      status=FMR_WOFOST_LINEAGE_OK;return
    end if
    pending%initialized=view%initialized
    pending%lineage_id=view%lineage_id
    pending%start_revision=view%start_revision
    pending%next_revision=view%next_revision
    pending%accepted_intervals=view%accepted_intervals
    pending%t0=view%t0
    pending%t1=view%t1
    pending%covered_t=view%covered_t
    pending%actual_root_uptake_integral=view%actual_root_uptake_integral
    pending%potential_transpiration_integral=view%potential_transpiration_integral
    pending%deepest_root_oxygen_factor_available=view%deepest_root_oxygen_factor_available
    pending%deepest_root_oxygen_factor_integral=view%deepest_root_oxygen_factor_integral
    pending%rootzone_drought_uptake_factor_available=view%rootzone_drought_uptake_factor_available
    pending%rootzone_drought_uptake_factor_integral=view%rootzone_drought_uptake_factor_integral
    pending%root_layer_reduction_clipped=view%root_layer_reduction_clipped
    if(allocated(view%potential_root_sink_integral))pending%potential_root_sink_integral=view%potential_root_sink_integral
    if(allocated(view%root_sink_reduction_integral))pending%root_sink_reduction_integral=view%root_sink_reduction_integral
    pending%event_delivered=view%event_delivered
    if(.not.pending%ready())return
    if(pending%event_delivered.and..not.pending%complete())return
    window=pending;status=FMR_WOFOST_LINEAGE_OK
  end subroutine

  logical function crop_event_identity_persistence_ready(self) result(ready)
    class(fmr_wofost_crop_event_identity_persistence_t), intent(in) :: self
    ready = .false.
    if (.not. self%valid) return
    if (self%lineage_id <= 0_int64 .or. self%final_revision < 0_int64) return
    if (.not. ieee_is_finite(self%t0) .or. .not. ieee_is_finite(self%t1)) return
    if (self%t1 <= self%t0) return
    if (.not. ieee_is_finite(self%actual_root_uptake_integral)) return
    if (.not. ieee_is_finite(self%potential_transpiration_integral)) return
    if (self%actual_root_uptake_integral < 0.0_real64) return
    if (self%potential_transpiration_integral < 0.0_real64) return
    if (self%deepest_root_oxygen_factor_available) then
      if (.not. ieee_is_finite(self%deepest_root_oxygen_factor_integral)) return
      if (self%deepest_root_oxygen_factor_integral < 0.0_real64) return
      if (self%deepest_root_oxygen_factor_integral > (self%t1-self%t0) + &
           64.0_real64*epsilon(1.0_real64)*max(1.0_real64,abs(self%t1),abs(self%t0))) return
    else
      if (abs(self%deepest_root_oxygen_factor_integral) > tiny(1.0_real64)) return
    end if
    if (.not. valid_optional_factor_integral(self%rootzone_drought_uptake_factor_available, &
         self%rootzone_drought_uptake_factor_integral, self%t1-self%t0)) return
    if(.not.valid_root_layers(self%potential_root_sink_integral,self%root_sink_reduction_integral, &
      self%potential_transpiration_integral,self%actual_root_uptake_integral,self%root_layer_reduction_clipped))return
    ready = .true.
  end function crop_event_identity_persistence_ready

  subroutine export_wofost_crop_event_identity_persistence(identity, view, exported)
    type(fmr_wofost_crop_event_identity_t), intent(in) :: identity
    type(fmr_wofost_crop_event_identity_persistence_t), intent(out) :: view
    logical, intent(out) :: exported

    view = fmr_wofost_crop_event_identity_persistence_t()
    exported = .false.
    if (.not. identity%ready()) return
    view%lineage_id = identity%lineage_id
    view%final_revision = identity%final_revision
    view%t0 = identity%t0
    view%t1 = identity%t1
    view%actual_root_uptake_integral = identity%actual_root_uptake_integral
    view%potential_transpiration_integral = identity%potential_transpiration_integral
    view%deepest_root_oxygen_factor_available = identity%deepest_root_oxygen_factor_available
    view%deepest_root_oxygen_factor_integral = identity%deepest_root_oxygen_factor_integral
    view%rootzone_drought_uptake_factor_available = identity%rootzone_drought_uptake_factor_available
    view%rootzone_drought_uptake_factor_integral = identity%rootzone_drought_uptake_factor_integral
    view%root_layer_reduction_clipped=identity%root_layer_reduction_clipped
    if(allocated(identity%potential_root_sink_integral))then
      view%potential_root_sink_integral=identity%potential_root_sink_integral
      view%root_sink_reduction_integral=identity%root_sink_reduction_integral
    end if
    view%valid = .true.
    exported = view%ready()
    if (.not. exported) view = fmr_wofost_crop_event_identity_persistence_t()
  end subroutine export_wofost_crop_event_identity_persistence

  subroutine reconstruct_wofost_crop_event_identity_from_persistence(view, identity, status)
    type(fmr_wofost_crop_event_identity_persistence_t), intent(in) :: view
    type(fmr_wofost_crop_event_identity_t), intent(out) :: identity
    integer, intent(out) :: status

    identity = fmr_wofost_crop_event_identity_t()
    status = FMR_WOFOST_LINEAGE_INVALID_PERSISTENCE
    if (.not. view%ready()) return
    identity%lineage_id = view%lineage_id
    identity%final_revision = view%final_revision
    identity%t0 = view%t0
    identity%t1 = view%t1
    identity%actual_root_uptake_integral = view%actual_root_uptake_integral
    identity%potential_transpiration_integral = view%potential_transpiration_integral
    identity%deepest_root_oxygen_factor_available = view%deepest_root_oxygen_factor_available
    identity%deepest_root_oxygen_factor_integral = view%deepest_root_oxygen_factor_integral
    identity%rootzone_drought_uptake_factor_available = view%rootzone_drought_uptake_factor_available
    identity%rootzone_drought_uptake_factor_integral = view%rootzone_drought_uptake_factor_integral
    identity%root_layer_reduction_clipped=view%root_layer_reduction_clipped
    if(allocated(view%potential_root_sink_integral))then
      identity%potential_root_sink_integral=view%potential_root_sink_integral
      identity%root_sink_reduction_integral=view%root_sink_reduction_integral
    end if
    identity%initialized = .true.
    if (.not. identity%ready()) then
      identity = fmr_wofost_crop_event_identity_t()
      return
    end if
    status = FMR_WOFOST_LINEAGE_OK
  end subroutine reconstruct_wofost_crop_event_identity_from_persistence

  subroutine certify_fkt_accepted_interval(checkpoint, committed_after, certificate, status)
    type(kernel_checkpoint_t), intent(in) :: checkpoint
    type(kernel_committed_state_t), intent(in) :: committed_after
    type(fmr_wofost_accepted_interval_certificate_t), intent(out) :: certificate
    integer, intent(out) :: status
    integer(int64) :: origin_revision, committed_revision, lineage_id
    real(real64) :: t0, t1
    logical :: t0_available, t1_available

    certificate = fmr_wofost_accepted_interval_certificate_t()
    status = FMR_WOFOST_LINEAGE_INVALID_CHECKPOINT
    if (.not. checkpoint%ready()) return
    if (.not. checkpoint%time_is_bound()) return

    status = FMR_WOFOST_LINEAGE_INVALID_COMMITTED
    if (.not. committed_after%ready()) return
    if (.not. committed_after%time_is_bound()) return

    lineage_id = checkpoint%current_lineage_id()
    if (lineage_id <= 0_int64) then
      status = FMR_WOFOST_LINEAGE_COMMIT_NOT_PROVEN
      return
    end if
    if (committed_after%current_lineage_id() /= lineage_id) then
      status = FMR_WOFOST_LINEAGE_COMMIT_NOT_PROVEN
      return
    end if

    origin_revision = checkpoint%origin_revision()
    committed_revision = committed_after%current_revision()
    if (origin_revision < 0_int64 .or. origin_revision >= huge(origin_revision)) then
      status = FMR_WOFOST_LINEAGE_COMMIT_NOT_PROVEN
      return
    end if
    if (committed_revision /= origin_revision + 1_int64) then
      status = FMR_WOFOST_LINEAGE_COMMIT_NOT_PROVEN
      return
    end if

    call checkpoint%current_time(t0, t0_available)
    call committed_after%current_time(t1, t1_available)
    if (.not. t0_available) then
      status = FMR_WOFOST_LINEAGE_COMMIT_NOT_PROVEN
      return
    end if
    if (.not. t1_available) then
      status = FMR_WOFOST_LINEAGE_COMMIT_NOT_PROVEN
      return
    end if
    if (.not. ieee_is_finite(t0) .or. .not. ieee_is_finite(t1) .or. t1 <= t0) then
      status = FMR_WOFOST_LINEAGE_COMMIT_NOT_PROVEN
      return
    end if

    certificate%lineage_id = lineage_id
    certificate%origin_revision = origin_revision
    certificate%committed_revision = committed_revision
    certificate%t0 = t0
    certificate%t1 = t1
    certificate%initialized = .true.
    status = FMR_WOFOST_LINEAGE_OK
  end subroutine certify_fkt_accepted_interval

  subroutine begin_wofost_trial_contribution(checkpoint, trial_t1, trial, status)
    type(kernel_checkpoint_t), intent(in) :: checkpoint
    real(real64), intent(in) :: trial_t1
    type(fmr_wofost_trial_contribution_t), intent(out) :: trial
    integer, intent(out) :: status
    real(real64) :: trial_t0
    logical :: time_available

    trial = fmr_wofost_trial_contribution_t()
    status = FMR_WOFOST_LINEAGE_INVALID_CHECKPOINT
    if (.not. checkpoint%ready()) return
    if (.not. checkpoint%time_is_bound()) return
    call checkpoint%current_time(trial_t0, time_available)
    if (.not. time_available) return

    status = FMR_WOFOST_LINEAGE_INVALID_TRIAL
    if (.not. ieee_is_finite(trial_t0) .or. .not. ieee_is_finite(trial_t1) .or. trial_t1 <= trial_t0) return
    trial%lineage_id = checkpoint%current_lineage_id()
    trial%origin_revision = checkpoint%origin_revision()
    if (trial%lineage_id <= 0_int64 .or. trial%origin_revision < 0_int64) then
      trial = fmr_wofost_trial_contribution_t()
      return
    end if

    trial%t0 = trial_t0
    trial%t1 = trial_t1
    trial%next_t = trial_t0
    trial%initialized = .true.
    status = FMR_WOFOST_LINEAGE_OK
  end subroutine begin_wofost_trial_contribution

  subroutine accumulate_wofost_trial_process_rate(trial, sub_t0, sub_t1, &
       actual_root_uptake_rate, potential_transpiration_rate, status, deepest_root_oxygen_factor, &
       rootzone_drought_uptake_factor, potential_root_sink, root_sink_reduction, &
       source_clipped_root_reduction,actual_root_sink)
    type(fmr_wofost_trial_contribution_t), intent(inout) :: trial
    real(real64), intent(in) :: sub_t0, sub_t1
    real(real64), intent(in) :: actual_root_uptake_rate, potential_transpiration_rate
    integer, intent(out) :: status
    real(real64), intent(in), optional :: deepest_root_oxygen_factor
    real(real64), intent(in), optional :: rootzone_drought_uptake_factor
    real(real64), intent(in), optional :: potential_root_sink(:),root_sink_reduction(:),actual_root_sink(:)
    logical,intent(in),optional::source_clipped_root_reduction
    logical::clipped
    real(real64)::layer_tolerance
    real(real64), allocatable :: layer_potential(:),layer_reduction(:)
    real(real64) :: dt, actual_add, potential_add, actual_new, potential_new
    real(real64) :: oxygen_add, oxygen_new, drought_add, drought_new

    status = FMR_WOFOST_LINEAGE_INVALID_TRIAL
    if (.not. trial%ready()) return
    if (trial%complete()) return
    if (.not. ieee_is_finite(sub_t0) .or. .not. ieee_is_finite(sub_t1) .or. sub_t1 <= sub_t0) return
    if (.not. same_time(sub_t0, trial%next_t)) then
      status = FMR_WOFOST_LINEAGE_NONCONTIGUOUS
      return
    end if
    if (sub_t1 > trial%t1 .and. .not. same_time(sub_t1, trial%t1)) then
      status = FMR_WOFOST_LINEAGE_NONCONTIGUOUS
      return
    end if
    if (.not. valid_nonnegative(actual_root_uptake_rate)) then
      status = FMR_WOFOST_LINEAGE_INVALID_PROCESS_RATE
      return
    end if
    if (.not. valid_nonnegative(potential_transpiration_rate)) then
      status = FMR_WOFOST_LINEAGE_INVALID_PROCESS_RATE
      return
    end if

    clipped=.false.
    if(present(source_clipped_root_reduction))clipped=source_clipped_root_reduction
    if(clipped.and..not.present(potential_root_sink))return
    if(.not.same_time(trial%next_t,trial%t0))then
      if(clipped.neqv.trial%root_layer_reduction_clipped)return
    end if
    dt = sub_t1 - sub_t0
    if(present(potential_root_sink).neqv.present(root_sink_reduction))return
    if(present(potential_root_sink))then
      status=FMR_WOFOST_LINEAGE_INVALID_PROCESS_RATE
      layer_potential=potential_root_sink;layer_reduction=root_sink_reduction
      if(.not.valid_root_layers(layer_potential,layer_reduction,potential_transpiration_rate,actual_root_uptake_rate,clipped))return
      if(clipped)then
        if(.not.present(actual_root_sink))return
        if(size(actual_root_sink)/=size(layer_potential))return
        if(any(.not.ieee_is_finite(actual_root_sink)))return
        if(any(actual_root_sink<0.0_real64))return
        layer_tolerance=256.0_real64*epsilon(1.0_real64)*max(1.0_real64,potential_transpiration_rate,actual_root_uptake_rate)
        if(abs(sum(actual_root_sink)-actual_root_uptake_rate)>layer_tolerance)return
        if(any(abs(layer_reduction-max(0.0_real64,layer_potential-actual_root_sink))>layer_tolerance))return
      else if(present(actual_root_sink))then
        return
      end if
      if(allocated(trial%potential_root_sink_integral))then
        if(size(layer_potential)/=size(trial%potential_root_sink_integral))return
        layer_potential=trial%potential_root_sink_integral+dt*potential_root_sink
        layer_reduction=trial%root_sink_reduction_integral+dt*root_sink_reduction
      else
        if(.not.same_time(trial%next_t,trial%t0))return
        layer_potential=dt*potential_root_sink;layer_reduction=dt*root_sink_reduction
      end if
    else if(allocated(trial%potential_root_sink_integral))then
      return
    end if
    actual_add = actual_root_uptake_rate * dt
    potential_add = potential_transpiration_rate * dt
    actual_new = trial%actual_root_uptake_integral + actual_add
    potential_new = trial%potential_transpiration_integral + potential_add
    oxygen_add = 0.0_real64
    oxygen_new = trial%deepest_root_oxygen_factor_integral
    drought_add = 0.0_real64
    drought_new = trial%rootzone_drought_uptake_factor_integral
    if (present(deepest_root_oxygen_factor)) then
      if (.not. trial%deepest_root_oxygen_factor_available .and. .not. same_time(trial%next_t,trial%t0)) then
        status = FMR_WOFOST_LINEAGE_INVALID_PROCESS_RATE
        return
      end if
      if (.not. ieee_is_finite(deepest_root_oxygen_factor) .or. deepest_root_oxygen_factor < 0.0_real64 .or. &
           deepest_root_oxygen_factor > 1.0_real64) then
        status = FMR_WOFOST_LINEAGE_INVALID_PROCESS_RATE
        return
      end if
      oxygen_add = deepest_root_oxygen_factor*dt
      oxygen_new = oxygen_new + oxygen_add
    else if (trial%deepest_root_oxygen_factor_available) then
      ! Once a trial has started carrying the oxygen integral, every contiguous
      ! subinterval must provide it; otherwise the accepted-day integral is incomplete.
      status = FMR_WOFOST_LINEAGE_INVALID_PROCESS_RATE
      return
    end if

    if (present(rootzone_drought_uptake_factor)) then
      if (.not. trial%rootzone_drought_uptake_factor_available .and. .not. same_time(trial%next_t,trial%t0)) then
        status = FMR_WOFOST_LINEAGE_INVALID_PROCESS_RATE
        return
      end if
      if (.not. ieee_is_finite(rootzone_drought_uptake_factor) .or. &
           rootzone_drought_uptake_factor < 0.0_real64 .or. rootzone_drought_uptake_factor > 1.0_real64) then
        status = FMR_WOFOST_LINEAGE_INVALID_PROCESS_RATE
        return
      end if
      drought_add = rootzone_drought_uptake_factor*dt
      drought_new = drought_new + drought_add
    else if (trial%rootzone_drought_uptake_factor_available) then
      status = FMR_WOFOST_LINEAGE_INVALID_PROCESS_RATE
      return
    end if

    if (.not. ieee_is_finite(actual_add) .or. .not. ieee_is_finite(potential_add) .or. &
         .not. ieee_is_finite(oxygen_add) .or. .not. ieee_is_finite(drought_add)) then
      status = FMR_WOFOST_LINEAGE_INVALID_PROCESS_RATE
      return
    end if
    if (.not. ieee_is_finite(actual_new) .or. .not. ieee_is_finite(potential_new)) then
      status = FMR_WOFOST_LINEAGE_INVALID_PROCESS_RATE
      return
    end if

    if(.not.valid_root_layers(layer_potential,layer_reduction,potential_new,actual_new,clipped))return
    trial%root_layer_reduction_clipped=clipped
    if(allocated(layer_potential))then
      trial%potential_root_sink_integral=layer_potential
      trial%root_sink_reduction_integral=layer_reduction
    end if
    trial%actual_root_uptake_integral = actual_new
    trial%potential_transpiration_integral = potential_new
    if (present(deepest_root_oxygen_factor)) then
      trial%deepest_root_oxygen_factor_available = .true.
      trial%deepest_root_oxygen_factor_integral = oxygen_new
    end if
    if (present(rootzone_drought_uptake_factor)) then
      trial%rootzone_drought_uptake_factor_available = .true.
      trial%rootzone_drought_uptake_factor_integral = drought_new
    end if
    trial%next_t = sub_t1
    status = FMR_WOFOST_LINEAGE_OK
  end subroutine accumulate_wofost_trial_process_rate

  subroutine discard_wofost_trial_contribution(trial)
    type(fmr_wofost_trial_contribution_t), intent(inout) :: trial
    trial = fmr_wofost_trial_contribution_t()
  end subroutine discard_wofost_trial_contribution

  subroutine open_wofost_accepted_window(checkpoint, window_t1, window, status)
    type(kernel_checkpoint_t), intent(in) :: checkpoint
    real(real64), intent(in) :: window_t1
    type(fmr_wofost_accepted_window_t), intent(out) :: window
    integer, intent(out) :: status
    real(real64) :: window_t0
    logical :: time_available

    window = fmr_wofost_accepted_window_t()
    status = FMR_WOFOST_LINEAGE_INVALID_CHECKPOINT
    if (.not. checkpoint%ready()) return
    if (.not. checkpoint%time_is_bound()) return
    call checkpoint%current_time(window_t0, time_available)
    if (.not. time_available) return

    status = FMR_WOFOST_LINEAGE_INVALID_WINDOW
    if (.not. ieee_is_finite(window_t0) .or. .not. ieee_is_finite(window_t1) .or. window_t1 <= window_t0) return
    window%lineage_id = checkpoint%current_lineage_id()
    window%start_revision = checkpoint%origin_revision()
    if (window%lineage_id <= 0_int64 .or. window%start_revision < 0_int64) then
      window = fmr_wofost_accepted_window_t()
      return
    end if

    window%next_revision = window%start_revision
    window%t0 = window_t0
    window%t1 = window_t1
    window%covered_t = window_t0
    window%initialized = .true.
    status = FMR_WOFOST_LINEAGE_OK
  end subroutine open_wofost_accepted_window

  subroutine prevalidate_wofost_trial_admission(window, trial, status)
    type(fmr_wofost_accepted_window_t), intent(in) :: window
    type(fmr_wofost_trial_contribution_t), intent(in) :: trial
    integer, intent(out) :: status

    status = FMR_WOFOST_LINEAGE_INVALID_WINDOW
    if (.not. window%ready()) return
    if (window%event_delivered) return

    status = FMR_WOFOST_LINEAGE_INVALID_TRIAL
    if (.not. trial%ready()) return
    if (.not. trial%complete()) return

    status = FMR_WOFOST_LINEAGE_TRIAL_WINDOW_MISMATCH
    if (trial%lineage_id /= window%lineage_id) return
    if (trial%origin_revision /= window%next_revision) return

    if (.not. same_time(trial%t0, window%covered_t)) then
      status = FMR_WOFOST_LINEAGE_NONCONTIGUOUS
      return
    end if
    if (trial%t1 > window%t1 .and. .not. same_time(trial%t1, window%t1)) then
      status = FMR_WOFOST_LINEAGE_NONCONTIGUOUS
      return
    end if

    if(window%accepted_intervals>0)then
      if(window%root_layer_reduction_clipped.neqv.trial%root_layer_reduction_clipped)return
    end if
    if(allocated(window%potential_root_sink_integral).neqv.allocated(trial%potential_root_sink_integral))then
      if(window%accepted_intervals>0)return
    end if
    if(allocated(window%potential_root_sink_integral).and.allocated(trial%potential_root_sink_integral))then
      if(size(window%potential_root_sink_integral)/=size(trial%potential_root_sink_integral))return
    end if
    status = FMR_WOFOST_LINEAGE_OK
  end subroutine prevalidate_wofost_trial_admission

  subroutine admit_wofost_accepted_trial(window, certificate, trial, status)
    type(fmr_wofost_accepted_window_t), intent(inout) :: window
    type(fmr_wofost_accepted_interval_certificate_t), intent(in) :: certificate
    type(fmr_wofost_trial_contribution_t), intent(in) :: trial
    integer, intent(out) :: status
    real(real64) :: actual_new, potential_new, oxygen_new, drought_new
    real(real64),allocatable :: layer_potential(:),layer_reduction(:)

    status = FMR_WOFOST_LINEAGE_INVALID_WINDOW
    if (.not. window%ready()) return
    if (window%event_delivered) return

    status = FMR_WOFOST_LINEAGE_CERTIFICATE_MISMATCH
    if (.not. certificate%ready()) return
    if (.not. trial%ready()) return
    if (.not. trial%complete()) return
    if (certificate%lineage_id /= window%lineage_id) return
    if (trial%lineage_id /= window%lineage_id) return
    if (certificate%origin_revision /= window%next_revision) return
    if (trial%origin_revision /= window%next_revision) return
    if (certificate%committed_revision /= certificate%origin_revision + 1_int64) return
    if (.not. same_time(certificate%t0, trial%t0)) return
    if (.not. same_time(certificate%t1, trial%t1)) return
    if (.not. same_time(certificate%t0, window%covered_t)) then
      status = FMR_WOFOST_LINEAGE_NONCONTIGUOUS
      return
    end if
    if (certificate%t1 > window%t1 .and. .not. same_time(certificate%t1, window%t1)) then
      status = FMR_WOFOST_LINEAGE_NONCONTIGUOUS
      return
    end if

    if(window%accepted_intervals>0)then
      if(window%root_layer_reduction_clipped.neqv.trial%root_layer_reduction_clipped)return
    end if
    if(allocated(trial%potential_root_sink_integral))then
      if(allocated(window%potential_root_sink_integral))then
        if(size(window%potential_root_sink_integral)/=size(trial%potential_root_sink_integral))return
        layer_potential=window%potential_root_sink_integral+trial%potential_root_sink_integral
        layer_reduction=window%root_sink_reduction_integral+trial%root_sink_reduction_integral
      else
        if(window%accepted_intervals>0)return
        layer_potential=trial%potential_root_sink_integral
        layer_reduction=trial%root_sink_reduction_integral
      end if
    else if(allocated(window%potential_root_sink_integral))then
      return
    end if
    actual_new = window%actual_root_uptake_integral + trial%actual_root_uptake_integral
    potential_new = window%potential_transpiration_integral + trial%potential_transpiration_integral
    oxygen_new = window%deepest_root_oxygen_factor_integral
    drought_new = window%rootzone_drought_uptake_factor_integral
    if (trial%deepest_root_oxygen_factor_available) then
      if (window%accepted_intervals > 0 .and. .not. window%deepest_root_oxygen_factor_available) then
        status = FMR_WOFOST_LINEAGE_INVALID_PROCESS_RATE
        return
      end if
      oxygen_new = oxygen_new + trial%deepest_root_oxygen_factor_integral
    else if (window%deepest_root_oxygen_factor_available) then
      status = FMR_WOFOST_LINEAGE_INVALID_PROCESS_RATE
      return
    end if
    if (trial%rootzone_drought_uptake_factor_available) then
      if (window%accepted_intervals > 0 .and. .not. window%rootzone_drought_uptake_factor_available) then
        status = FMR_WOFOST_LINEAGE_INVALID_PROCESS_RATE
        return
      end if
      drought_new = drought_new + trial%rootzone_drought_uptake_factor_integral
    else if (window%rootzone_drought_uptake_factor_available) then
      status = FMR_WOFOST_LINEAGE_INVALID_PROCESS_RATE
      return
    end if
    if (.not. ieee_is_finite(actual_new) .or. .not. ieee_is_finite(potential_new) .or. &
         .not. ieee_is_finite(oxygen_new) .or. .not. ieee_is_finite(drought_new)) then
      status = FMR_WOFOST_LINEAGE_INVALID_PROCESS_RATE
      return
    end if

    if(.not.valid_root_layers(layer_potential,layer_reduction,potential_new,actual_new,trial%root_layer_reduction_clipped))return
    window%root_layer_reduction_clipped=trial%root_layer_reduction_clipped
    if(allocated(layer_potential))then
      window%potential_root_sink_integral=layer_potential
      window%root_sink_reduction_integral=layer_reduction
    end if
    window%actual_root_uptake_integral = actual_new
    window%potential_transpiration_integral = potential_new
    if (trial%deepest_root_oxygen_factor_available) then
      window%deepest_root_oxygen_factor_available = .true.
      window%deepest_root_oxygen_factor_integral = oxygen_new
    end if
    if (trial%rootzone_drought_uptake_factor_available) then
      window%rootzone_drought_uptake_factor_available = .true.
      window%rootzone_drought_uptake_factor_integral = drought_new
    end if
    window%covered_t = certificate%t1
    window%next_revision = certificate%committed_revision
    window%accepted_intervals = window%accepted_intervals + 1
    status = FMR_WOFOST_LINEAGE_OK
  end subroutine admit_wofost_accepted_trial

  subroutine prepare_wofost_crop_event_delivery(window, aggregates, token, available, status)
    type(fmr_wofost_accepted_window_t), intent(in) :: window
    type(wofost_accepted_window_aggregates_t), intent(out) :: aggregates
    type(fmr_wofost_crop_event_token_t), intent(out) :: token
    logical, intent(out) :: available
    integer, intent(out) :: status

    aggregates = wofost_accepted_window_aggregates_t()
    token = fmr_wofost_crop_event_token_t()
    available = .false.
    status = FMR_WOFOST_LINEAGE_INVALID_WINDOW
    if (.not. window%ready()) return
    if (window%event_delivered) then
      status = FMR_WOFOST_LINEAGE_EVENT_ALREADY_DELIVERED
      return
    end if
    if (.not. window%complete()) then
      status = FMR_WOFOST_LINEAGE_WINDOW_INCOMPLETE
      return
    end if

    aggregates%actual_root_uptake = window%actual_root_uptake_integral
    aggregates%potential_transpiration = window%potential_transpiration_integral
    aggregates%deepest_root_oxygen_factor_available = window%deepest_root_oxygen_factor_available
    aggregates%deepest_root_oxygen_factor_integral = window%deepest_root_oxygen_factor_integral
    aggregates%rootzone_drought_uptake_factor_available = window%rootzone_drought_uptake_factor_available
    aggregates%rootzone_drought_uptake_factor_integral = window%rootzone_drought_uptake_factor_integral
    token%lineage_id = window%lineage_id
    token%final_revision = window%next_revision
    token%t0 = window%t0
    token%t1 = window%t1
    token%actual_root_uptake_integral = window%actual_root_uptake_integral
    token%potential_transpiration_integral = window%potential_transpiration_integral
    token%deepest_root_oxygen_factor_available = window%deepest_root_oxygen_factor_available
    token%deepest_root_oxygen_factor_integral = window%deepest_root_oxygen_factor_integral
    token%rootzone_drought_uptake_factor_available = window%rootzone_drought_uptake_factor_available
    token%rootzone_drought_uptake_factor_integral = window%rootzone_drought_uptake_factor_integral
    token%root_layer_reduction_clipped=window%root_layer_reduction_clipped
    if(allocated(window%potential_root_sink_integral))then
      token%potential_root_sink_integral=window%potential_root_sink_integral
      token%root_sink_reduction_integral=window%root_sink_reduction_integral
    end if
    token%initialized = .true.
    available = .true.
    status = FMR_WOFOST_LINEAGE_OK
  end subroutine prepare_wofost_crop_event_delivery

  subroutine commit_wofost_crop_event_delivery(window, token, status)
    type(fmr_wofost_accepted_window_t), intent(inout) :: window
    type(fmr_wofost_crop_event_token_t), intent(in) :: token
    integer, intent(out) :: status

    status = FMR_WOFOST_LINEAGE_INVALID_WINDOW
    if (.not. window%ready()) return
    if (.not. window%complete()) return
    if (window%event_delivered) then
      status = FMR_WOFOST_LINEAGE_EVENT_ALREADY_DELIVERED
      return
    end if

    status = FMR_WOFOST_LINEAGE_EVENT_TOKEN_MISMATCH
    if (.not. token%ready()) return
    if (token%lineage_id /= window%lineage_id) return
    if (token%final_revision /= window%next_revision) return
    if (.not. same_time(token%t0, window%t0)) return
    if (.not. same_time(token%t1, window%t1)) return
    if (.not. same_real_bits(token%actual_root_uptake_integral, window%actual_root_uptake_integral)) return
    if (.not. same_real_bits(token%potential_transpiration_integral, &
         window%potential_transpiration_integral)) return
    if (token%deepest_root_oxygen_factor_available .neqv. &
         window%deepest_root_oxygen_factor_available) return
    if (.not. same_real_bits(token%deepest_root_oxygen_factor_integral, &
         window%deepest_root_oxygen_factor_integral)) return
    if(token%root_layer_reduction_clipped.neqv.window%root_layer_reduction_clipped)return
    if(.not.same_root_layers(token%potential_root_sink_integral,token%root_sink_reduction_integral, &
      window%potential_root_sink_integral,window%root_sink_reduction_integral))return
    if (token%rootzone_drought_uptake_factor_available .neqv. &
         window%rootzone_drought_uptake_factor_available) return
    if (.not. same_real_bits(token%rootzone_drought_uptake_factor_integral, &
         window%rootzone_drought_uptake_factor_integral)) return

    window%event_delivered = .true.
    status = FMR_WOFOST_LINEAGE_OK
  end subroutine commit_wofost_crop_event_delivery

  pure logical function certificate_ready(self) result(ready)
    class(fmr_wofost_accepted_interval_certificate_t), intent(in) :: self
    ready = self%initialized .and. self%lineage_id > 0_int64 .and. &
         self%origin_revision >= 0_int64 .and. self%committed_revision == self%origin_revision + 1_int64 .and. &
         ieee_is_finite(self%t0) .and. ieee_is_finite(self%t1) .and. self%t1 > self%t0
  end function certificate_ready

  pure logical function trial_ready(self) result(ready)
    class(fmr_wofost_trial_contribution_t), intent(in) :: self
    ready = self%initialized .and. self%lineage_id > 0_int64 .and. self%origin_revision >= 0_int64 .and. &
         ieee_is_finite(self%t0) .and. ieee_is_finite(self%t1) .and. ieee_is_finite(self%next_t) .and. &
         ieee_is_finite(self%actual_root_uptake_integral) .and. &
         ieee_is_finite(self%potential_transpiration_integral) .and. self%t1 > self%t0 .and. &
         self%next_t >= self%t0 .and. self%next_t <= self%t1
    if (.not. ready) return
    ready = valid_optional_factor_integral(self%deepest_root_oxygen_factor_available, &
         self%deepest_root_oxygen_factor_integral, self%next_t-self%t0)
    if (.not. ready) return
    ready = valid_optional_factor_integral(self%rootzone_drought_uptake_factor_available, &
         self%rootzone_drought_uptake_factor_integral, self%next_t-self%t0)
    if(.not.ready)return
    ready=valid_root_layers(self%potential_root_sink_integral,self%root_sink_reduction_integral, &
      self%potential_transpiration_integral,self%actual_root_uptake_integral,self%root_layer_reduction_clipped)
  end function trial_ready

  pure logical function trial_complete(self) result(complete)
    class(fmr_wofost_trial_contribution_t), intent(in) :: self
    complete = .false.
    if (.not. self%ready()) return
    complete = same_time(self%next_t, self%t1)
  end function trial_complete

  pure logical function accepted_window_ready(self) result(ready)
    class(fmr_wofost_accepted_window_t), intent(in) :: self
    ready = self%initialized .and. self%lineage_id > 0_int64 .and. self%start_revision >= 0_int64 .and. &
         self%next_revision >= self%start_revision .and. self%accepted_intervals >= 0 .and. &
         ieee_is_finite(self%t0) .and. ieee_is_finite(self%t1) .and. ieee_is_finite(self%covered_t) .and. &
         ieee_is_finite(self%actual_root_uptake_integral) .and. &
         ieee_is_finite(self%potential_transpiration_integral) .and. self%t1 > self%t0 .and. &
         self%covered_t >= self%t0 .and. self%covered_t <= self%t1
    if (.not. ready) return
    ready = valid_optional_factor_integral(self%deepest_root_oxygen_factor_available, &
         self%deepest_root_oxygen_factor_integral, self%covered_t-self%t0)
    if (.not. ready) return
    ready = valid_optional_factor_integral(self%rootzone_drought_uptake_factor_available, &
         self%rootzone_drought_uptake_factor_integral, self%covered_t-self%t0)
    if(.not.ready)return
    ready=valid_root_layers(self%potential_root_sink_integral,self%root_sink_reduction_integral, &
      self%potential_transpiration_integral,self%actual_root_uptake_integral,self%root_layer_reduction_clipped)
  end function accepted_window_ready

  pure logical function accepted_window_complete(self) result(complete)
    class(fmr_wofost_accepted_window_t), intent(in) :: self
    complete = .false.
    if (.not. self%ready()) return
    complete = same_time(self%covered_t, self%t1)
  end function accepted_window_complete

  pure logical function accepted_window_event_due(self) result(due)
    class(fmr_wofost_accepted_window_t), intent(in) :: self
    due = .false.
    if (.not. self%complete()) return
    due = .not. self%event_delivered
  end function accepted_window_event_due

  pure logical function accepted_window_delivery_committed(self) result(committed)
    class(fmr_wofost_accepted_window_t), intent(in) :: self
    committed = .false.
    if (.not. self%ready()) return
    committed = self%event_delivered
  end function accepted_window_delivery_committed

  pure integer function accepted_window_interval_count(self) result(count)
    class(fmr_wofost_accepted_window_t), intent(in) :: self
    count = 0
    if (.not. self%ready()) return
    count = self%accepted_intervals
  end function accepted_window_interval_count

  subroutine identify_wofost_crop_event(token, identity, status)
    type(fmr_wofost_crop_event_token_t), intent(in) :: token
    type(fmr_wofost_crop_event_identity_t), intent(out) :: identity
    integer, intent(out) :: status

    identity = fmr_wofost_crop_event_identity_t()
    status = FMR_WOFOST_LINEAGE_EVENT_TOKEN_MISMATCH
    if (.not. token%ready()) return

    identity%lineage_id = token%lineage_id
    identity%final_revision = token%final_revision
    identity%t0 = token%t0
    identity%t1 = token%t1
    identity%actual_root_uptake_integral = token%actual_root_uptake_integral
    identity%potential_transpiration_integral = token%potential_transpiration_integral
    identity%deepest_root_oxygen_factor_available = token%deepest_root_oxygen_factor_available
    identity%deepest_root_oxygen_factor_integral = token%deepest_root_oxygen_factor_integral
    identity%rootzone_drought_uptake_factor_available = token%rootzone_drought_uptake_factor_available
    identity%rootzone_drought_uptake_factor_integral = token%rootzone_drought_uptake_factor_integral
    identity%root_layer_reduction_clipped=token%root_layer_reduction_clipped
    if(allocated(token%potential_root_sink_integral))then
      identity%potential_root_sink_integral=token%potential_root_sink_integral
      identity%root_sink_reduction_integral=token%root_sink_reduction_integral
    end if
    identity%initialized = .true.
    status = FMR_WOFOST_LINEAGE_OK
  end subroutine identify_wofost_crop_event

  pure logical function crop_event_identity_ready(self) result(ready)
    class(fmr_wofost_crop_event_identity_t), intent(in) :: self
    ready = self%initialized .and. self%lineage_id > 0_int64 .and. self%final_revision >= 0_int64 .and. &
         ieee_is_finite(self%t0) .and. ieee_is_finite(self%t1) .and. self%t1 > self%t0 .and. &
         ieee_is_finite(self%actual_root_uptake_integral) .and. &
         ieee_is_finite(self%potential_transpiration_integral) .and. &
         self%actual_root_uptake_integral >= 0.0_real64 .and. &
         self%potential_transpiration_integral >= 0.0_real64
    if (.not. ready) return
    ready = valid_optional_factor_integral(self%deepest_root_oxygen_factor_available, &
         self%deepest_root_oxygen_factor_integral, self%t1-self%t0)
    if (.not. ready) return
    ready = valid_optional_factor_integral(self%rootzone_drought_uptake_factor_available, &
         self%rootzone_drought_uptake_factor_integral, self%t1-self%t0)
    if(.not.ready)return
    ready=valid_root_layers(self%potential_root_sink_integral,self%root_sink_reduction_integral, &
      self%potential_transpiration_integral,self%actual_root_uptake_integral,self%root_layer_reduction_clipped)
  end function crop_event_identity_ready

  pure logical function same_wofost_crop_event_identity(left, right) result(matches)
    type(fmr_wofost_crop_event_identity_t), intent(in) :: left, right
    matches = .false.
    if (.not. left%ready() .or. .not. right%ready()) return
    matches = left%lineage_id == right%lineage_id .and. &
         left%final_revision == right%final_revision .and. &
         same_time(left%t0, right%t0) .and. same_time(left%t1, right%t1) .and. &
         same_real_bits(left%actual_root_uptake_integral, right%actual_root_uptake_integral) .and. &
         same_real_bits(left%potential_transpiration_integral, right%potential_transpiration_integral) .and. &
         (left%deepest_root_oxygen_factor_available .eqv. right%deepest_root_oxygen_factor_available) .and. &
         same_real_bits(left%deepest_root_oxygen_factor_integral, right%deepest_root_oxygen_factor_integral) .and. &
         (left%rootzone_drought_uptake_factor_available .eqv. right%rootzone_drought_uptake_factor_available) .and. &
         same_real_bits(left%rootzone_drought_uptake_factor_integral, right%rootzone_drought_uptake_factor_integral)
    if(matches)matches=left%root_layer_reduction_clipped.eqv.right%root_layer_reduction_clipped
    if(matches)matches=same_root_layers(left%potential_root_sink_integral,left%root_sink_reduction_integral, &
      right%potential_root_sink_integral,right%root_sink_reduction_integral)
  end function same_wofost_crop_event_identity

  pure logical function crop_event_identity_matches_interval(identity, t0, t1) result(matches)
    type(fmr_wofost_crop_event_identity_t), intent(in) :: identity
    real(real64), intent(in) :: t0, t1
    matches = .false.
    if (.not. identity%ready()) return
    matches = same_time(identity%t0, t0) .and. same_time(identity%t1, t1)
  end function crop_event_identity_matches_interval

  pure logical function crop_event_token_ready(self) result(ready)
    class(fmr_wofost_crop_event_token_t), intent(in) :: self
    ready = self%initialized .and. self%lineage_id > 0_int64 .and. self%final_revision >= 0_int64 .and. &
         ieee_is_finite(self%t0) .and. ieee_is_finite(self%t1) .and. self%t1 > self%t0 .and. &
         ieee_is_finite(self%actual_root_uptake_integral) .and. &
         ieee_is_finite(self%potential_transpiration_integral) .and. &
         self%actual_root_uptake_integral >= 0.0_real64 .and. &
         self%potential_transpiration_integral >= 0.0_real64
    if (.not. ready) return
    ready = valid_optional_factor_integral(self%deepest_root_oxygen_factor_available, &
         self%deepest_root_oxygen_factor_integral, self%t1-self%t0)
    if (.not. ready) return
    ready = valid_optional_factor_integral(self%rootzone_drought_uptake_factor_available, &
         self%rootzone_drought_uptake_factor_integral, self%t1-self%t0)
    if(.not.ready)return
    ready=valid_root_layers(self%potential_root_sink_integral,self%root_sink_reduction_integral, &
      self%potential_transpiration_integral,self%actual_root_uptake_integral,self%root_layer_reduction_clipped)
  end function crop_event_token_ready

  pure logical function valid_optional_factor_integral(available, integral, duration) result(valid)
    logical, intent(in) :: available
    real(real64), intent(in) :: integral, duration
    real(real64) :: tolerance
    valid = .false.
    if (.not. ieee_is_finite(integral) .or. .not. ieee_is_finite(duration) .or. duration < 0.0_real64) return
    tolerance = 64.0_real64*epsilon(1.0_real64)*max(1.0_real64,abs(duration))
    if (available) then
      valid = integral >= 0.0_real64 .and. integral <= duration+tolerance
    else
      valid = abs(integral) <= tiny(1.0_real64)
    end if
  end function valid_optional_factor_integral

  pure logical function valid_nonnegative(value) result(valid)
    real(real64), intent(in) :: value
    valid = .false.
    if (.not. ieee_is_finite(value)) return
    valid = value >= 0.0_real64
  end function valid_nonnegative

  pure logical function same_time(a, b) result(matches)
    real(real64), intent(in) :: a, b
    real(real64) :: scale
    matches = .false.
    if (.not. ieee_is_finite(a) .or. .not. ieee_is_finite(b)) return
    scale = max(1.0_real64, abs(a), abs(b))
    matches = abs(a-b) <= 64.0_real64 * epsilon(1.0_real64) * scale
  end function same_time

  pure logical function same_real_bits(a, b) result(matches)
    real(real64), intent(in) :: a, b
    integer(int64) :: ia, ib
    ia = transfer(a, ia)
    ib = transfer(b, ib)
    matches = ia == ib
  end function same_real_bits

  pure logical function valid_root_layers(p,r,total_p,total_a,clipped)result(valid)
    real(real64),allocatable,intent(in)::p(:),r(:)
    real(real64),intent(in)::total_p,total_a
    logical,intent(in),optional::clipped
    real(real64)::tol
    valid=.false.
    if(allocated(p).neqv.allocated(r))return
    if(.not.allocated(p))then
      if(present(clipped))then
        if(clipped)return
      end if
      valid=.true.;return
    end if
    if(size(p)<=0.or.size(p)/=size(r))return
    if(any(.not.ieee_is_finite(p)).or.any(.not.ieee_is_finite(r)))return
    if(any(p<0.0_real64).or.any(r<0.0_real64))return
    tol=256.0_real64*epsilon(1.0_real64)*max(1.0_real64,abs(total_p),abs(total_a))
    if(any(r>p+tol))return
    if(.not.ieee_is_finite(sum(p)).or..not.ieee_is_finite(sum(p-r)))return
    if(abs(sum(p)-total_p)>tol)return
    if(present(clipped))then
      if(clipped)then
        if(total_a>total_p+tol.or.sum(p-r)>total_a+tol)return
        valid=.true.;return
      end if
    end if
    if(abs(sum(p-r)-total_a)>tol)return
    valid=.true.
  end function

  pure logical function same_root_layers(p,r,q,s)result(same)
    real(real64),allocatable,intent(in)::p(:),r(:),q(:),s(:)
    integer::i
    same=.false.
    if(allocated(p).neqv.allocated(q))return
    if(allocated(r).neqv.allocated(s))return
    if(allocated(p).neqv.allocated(r))return
    if(.not.allocated(p))then
      same=.true.;return
    end if
    if(size(p)/=size(q).or.size(r)/=size(s).or.size(p)/=size(r))return
    do i=1,size(p)
      if(.not.same_real_bits(p(i),q(i)).or..not.same_real_bits(r(i),s(i)))return
    end do
    same=.true.
  end function

end module mod_fmr_wofost_accepted_window_lineage

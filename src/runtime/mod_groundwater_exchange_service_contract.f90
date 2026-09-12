module mod_groundwater_exchange_service_contract
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_groundwater_coupling_contract, only: groundwater_coupling_window_t
  implicit none
  private

  integer, parameter, public :: GW_EXCHANGE_OK = 0
  integer, parameter, public :: GW_EXCHANGE_INVALID_CHECKPOINT = 1
  integer, parameter, public :: GW_EXCHANGE_INVALID_WINDOW = 2
  integer, parameter, public :: GW_EXCHANGE_INVALID_FLUX = 3
  integer, parameter, public :: GW_EXCHANGE_INVALID_CANDIDATE = 4
  integer, parameter, public :: GW_EXCHANGE_ORIGIN_MISMATCH = 5
  integer, parameter, public :: GW_EXCHANGE_STALE_CANDIDATE = 6
  integer, parameter, public :: GW_EXCHANGE_BACKEND_REJECTED = 7

  type, public :: groundwater_exchange_checkpoint_t
    private
    logical :: initialized = .false.
    integer(int64) :: service_id_value = 0_int64
    integer(int64) :: lineage_id_value = 0_int64
    integer(int64) :: origin_revision_value = -1_int64
    real(real64) :: origin_time_value = 0.0_real64
    integer(int64) :: backend_token = 0_int64
  contains
    procedure, public :: ready => checkpoint_ready
    procedure, public :: service_id => checkpoint_service_id
    procedure, public :: lineage_id => checkpoint_lineage_id
    procedure, public :: origin_revision => checkpoint_origin_revision
    procedure, public :: origin_time => checkpoint_origin_time
  end type groundwater_exchange_checkpoint_t

  type, public :: groundwater_exchange_candidate_t
    private
    logical :: initialized = .false.
    integer(int64) :: service_id_value = 0_int64
    integer(int64) :: lineage_id_value = 0_int64
    integer(int64) :: origin_revision_value = -1_int64
    integer(int64) :: candidate_revision_value = -1_int64
    real(real64) :: t0_value = 0.0_real64
    real(real64) :: t1_value = 0.0_real64
    integer(int64) :: checkpoint_token = 0_int64
    integer(int64) :: backend_token = 0_int64
  contains
    procedure, public :: ready => candidate_ready
    procedure, public :: service_id => candidate_service_id
    procedure, public :: lineage_id => candidate_lineage_id
    procedure, public :: origin_revision => candidate_origin_revision
    procedure, public :: candidate_revision => candidate_revision
    procedure, public :: origin_window => candidate_origin_window
  end type groundwater_exchange_candidate_t

  type, public :: groundwater_exchange_trial_result_t
    integer :: status = GW_EXCHANGE_INVALID_CANDIDATE
    real(real64) :: h_groundwater_m = 0.0_real64
    real(real64) :: q_groundwater_m_per_s = 0.0_real64
    type(groundwater_coupling_window_t) :: window
    integer(int64) :: groundwater_lineage_id = 0_int64
    integer(int64) :: origin_revision = -1_int64
    integer(int64) :: candidate_revision = -1_int64
  end type groundwater_exchange_trial_result_t

  type, abstract, public :: groundwater_exchange_service_t
  contains
    procedure(gw_capture_backend_ifc), deferred :: capture_backend
    procedure(gw_trial_backend_ifc), deferred :: trial_backend
    procedure(gw_commit_backend_ifc), deferred :: commit_backend
    procedure(gw_discard_backend_ifc), deferred :: discard_backend
  end type groundwater_exchange_service_t

  public :: groundwater_capture_checkpoint
  public :: groundwater_trial_from_checkpoint
  public :: groundwater_commit_candidate
  public :: groundwater_discard_candidate

  abstract interface
    subroutine gw_capture_backend_ifc(self, service_id, lineage_id, origin_revision, origin_time, token, status)
      import :: groundwater_exchange_service_t, int64, real64
      class(groundwater_exchange_service_t), intent(inout) :: self
      integer(int64), intent(out) :: service_id, lineage_id, origin_revision, token
      real(real64), intent(out) :: origin_time
      integer, intent(out) :: status
    end subroutine gw_capture_backend_ifc

    subroutine gw_trial_backend_ifc(self, checkpoint_token, window, q_groundwater_m_per_s, &
                                    candidate_token, h_groundwater_m, status)
      import :: groundwater_exchange_service_t, groundwater_coupling_window_t, int64, real64
      class(groundwater_exchange_service_t), intent(inout) :: self
      integer(int64), intent(in) :: checkpoint_token
      type(groundwater_coupling_window_t), intent(in) :: window
      real(real64), intent(in) :: q_groundwater_m_per_s
      integer(int64), intent(out) :: candidate_token
      real(real64), intent(out) :: h_groundwater_m
      integer, intent(out) :: status
    end subroutine gw_trial_backend_ifc

    subroutine gw_commit_backend_ifc(self, checkpoint_token, candidate_token, status)
      import :: groundwater_exchange_service_t, int64
      class(groundwater_exchange_service_t), intent(inout) :: self
      integer(int64), intent(in) :: checkpoint_token, candidate_token
      integer, intent(out) :: status
    end subroutine gw_commit_backend_ifc

    subroutine gw_discard_backend_ifc(self, candidate_token, status)
      import :: groundwater_exchange_service_t, int64
      class(groundwater_exchange_service_t), intent(inout) :: self
      integer(int64), intent(in) :: candidate_token
      integer, intent(out) :: status
    end subroutine gw_discard_backend_ifc
  end interface

contains

  subroutine groundwater_capture_checkpoint(service, checkpoint, status)
    class(groundwater_exchange_service_t), intent(inout) :: service
    type(groundwater_exchange_checkpoint_t), intent(out) :: checkpoint
    integer, intent(out) :: status

    integer(int64) :: service_id, lineage_id, origin_revision, token
    real(real64) :: origin_time

    checkpoint = groundwater_exchange_checkpoint_t()
    status = GW_EXCHANGE_INVALID_CHECKPOINT
    call service%capture_backend(service_id, lineage_id, origin_revision, origin_time, token, status)
    if (status /= GW_EXCHANGE_OK) return
    if (service_id <= 0_int64 .or. lineage_id <= 0_int64) then
      status = GW_EXCHANGE_INVALID_CHECKPOINT
      return
    end if
    if (origin_revision < 0_int64 .or. token <= 0_int64) then
      status = GW_EXCHANGE_INVALID_CHECKPOINT
      return
    end if
    if (.not. ieee_is_finite(origin_time)) then
      status = GW_EXCHANGE_INVALID_CHECKPOINT
      return
    end if

    checkpoint%service_id_value = service_id
    checkpoint%lineage_id_value = lineage_id
    checkpoint%origin_revision_value = origin_revision
    checkpoint%origin_time_value = origin_time
    checkpoint%backend_token = token
    checkpoint%initialized = .true.
    status = GW_EXCHANGE_OK
  end subroutine groundwater_capture_checkpoint

  subroutine groundwater_trial_from_checkpoint(service, checkpoint, window, q_groundwater_m_per_s, &
                                                candidate, result, status)
    class(groundwater_exchange_service_t), intent(inout) :: service
    type(groundwater_exchange_checkpoint_t), intent(in) :: checkpoint
    type(groundwater_coupling_window_t), intent(in) :: window
    real(real64), intent(in) :: q_groundwater_m_per_s
    type(groundwater_exchange_candidate_t), intent(out) :: candidate
    type(groundwater_exchange_trial_result_t), intent(out) :: result
    integer, intent(out) :: status

    integer(int64) :: candidate_token
    real(real64) :: h_groundwater_m

    candidate = groundwater_exchange_candidate_t()
    result = groundwater_exchange_trial_result_t()
    status = GW_EXCHANGE_INVALID_CHECKPOINT
    if (.not. checkpoint%ready()) return

    status = GW_EXCHANGE_INVALID_WINDOW
    if (.not. window%valid()) return
    if (.not. same_exchange_time(window%t0, checkpoint%origin_time_value)) then
      status = GW_EXCHANGE_ORIGIN_MISMATCH
      return
    end if

    status = GW_EXCHANGE_INVALID_FLUX
    if (.not. ieee_is_finite(q_groundwater_m_per_s)) return

    candidate_token = 0_int64
    h_groundwater_m = 0.0_real64
    call service%trial_backend(checkpoint%backend_token, window, q_groundwater_m_per_s, &
         candidate_token, h_groundwater_m, status)
    if (status /= GW_EXCHANGE_OK) return
    if (candidate_token <= 0_int64 .or. .not. ieee_is_finite(h_groundwater_m)) then
      status = GW_EXCHANGE_BACKEND_REJECTED
      return
    end if

    candidate%service_id_value = checkpoint%service_id_value
    candidate%lineage_id_value = checkpoint%lineage_id_value
    candidate%origin_revision_value = checkpoint%origin_revision_value
    candidate%candidate_revision_value = checkpoint%origin_revision_value + 1_int64
    candidate%t0_value = window%t0
    candidate%t1_value = window%t1
    candidate%checkpoint_token = checkpoint%backend_token
    candidate%backend_token = candidate_token
    candidate%initialized = .true.

    result%status = GW_EXCHANGE_OK
    result%h_groundwater_m = h_groundwater_m
    result%q_groundwater_m_per_s = q_groundwater_m_per_s
    result%window = window
    result%groundwater_lineage_id = checkpoint%lineage_id_value
    result%origin_revision = checkpoint%origin_revision_value
    result%candidate_revision = checkpoint%origin_revision_value + 1_int64
    status = GW_EXCHANGE_OK
  end subroutine groundwater_trial_from_checkpoint

  subroutine groundwater_commit_candidate(service, checkpoint, candidate, status)
    class(groundwater_exchange_service_t), intent(inout) :: service
    type(groundwater_exchange_checkpoint_t), intent(inout) :: checkpoint
    type(groundwater_exchange_candidate_t), intent(inout) :: candidate
    integer, intent(out) :: status

    status = GW_EXCHANGE_INVALID_CHECKPOINT
    if (.not. checkpoint%ready()) return
    status = GW_EXCHANGE_INVALID_CANDIDATE
    if (.not. candidate%ready()) return

    status = GW_EXCHANGE_ORIGIN_MISMATCH
    if (candidate%service_id_value /= checkpoint%service_id_value) return
    if (candidate%lineage_id_value /= checkpoint%lineage_id_value) return
    if (candidate%origin_revision_value /= checkpoint%origin_revision_value) return
    if (candidate%candidate_revision_value /= checkpoint%origin_revision_value + 1_int64) return
    if (candidate%checkpoint_token /= checkpoint%backend_token) return
    if (.not. same_exchange_time(candidate%t0_value, checkpoint%origin_time_value)) return

    call service%commit_backend(checkpoint%backend_token, candidate%backend_token, status)
    if (status /= GW_EXCHANGE_OK) return

    candidate%initialized = .false.
    checkpoint%initialized = .false.
    status = GW_EXCHANGE_OK
  end subroutine groundwater_commit_candidate

  subroutine groundwater_discard_candidate(service, candidate, status)
    class(groundwater_exchange_service_t), intent(inout) :: service
    type(groundwater_exchange_candidate_t), intent(inout) :: candidate
    integer, intent(out) :: status

    status = GW_EXCHANGE_INVALID_CANDIDATE
    if (.not. candidate%ready()) return
    call service%discard_backend(candidate%backend_token, status)
    if (status /= GW_EXCHANGE_OK) return
    candidate%initialized = .false.
    status = GW_EXCHANGE_OK
  end subroutine groundwater_discard_candidate

  pure logical function checkpoint_ready(self) result(ready)
    class(groundwater_exchange_checkpoint_t), intent(in) :: self
    ready = self%initialized .and. self%service_id_value > 0_int64 .and. &
         self%lineage_id_value > 0_int64 .and. self%origin_revision_value >= 0_int64 .and. &
         self%backend_token > 0_int64 .and. ieee_is_finite(self%origin_time_value)
  end function checkpoint_ready

  pure integer(int64) function checkpoint_service_id(self) result(value)
    class(groundwater_exchange_checkpoint_t), intent(in) :: self
    value = self%service_id_value
  end function checkpoint_service_id

  pure integer(int64) function checkpoint_lineage_id(self) result(value)
    class(groundwater_exchange_checkpoint_t), intent(in) :: self
    value = self%lineage_id_value
  end function checkpoint_lineage_id

  pure integer(int64) function checkpoint_origin_revision(self) result(value)
    class(groundwater_exchange_checkpoint_t), intent(in) :: self
    value = self%origin_revision_value
  end function checkpoint_origin_revision

  pure subroutine checkpoint_origin_time(self, value, available)
    class(groundwater_exchange_checkpoint_t), intent(in) :: self
    real(real64), intent(out) :: value
    logical, intent(out) :: available
    available = self%ready()
    if (available) then
      value = self%origin_time_value
    else
      value = 0.0_real64
    end if
  end subroutine checkpoint_origin_time

  pure logical function candidate_ready(self) result(ready)
    class(groundwater_exchange_candidate_t), intent(in) :: self
    ready = self%initialized .and. self%service_id_value > 0_int64 .and. &
         self%lineage_id_value > 0_int64 .and. self%origin_revision_value >= 0_int64 .and. &
         self%candidate_revision_value == self%origin_revision_value + 1_int64 .and. &
         self%checkpoint_token > 0_int64 .and. self%backend_token > 0_int64 .and. &
         ieee_is_finite(self%t0_value) .and. ieee_is_finite(self%t1_value) .and. &
         self%t1_value > self%t0_value
  end function candidate_ready

  pure integer(int64) function candidate_service_id(self) result(value)
    class(groundwater_exchange_candidate_t), intent(in) :: self
    value = self%service_id_value
  end function candidate_service_id

  pure integer(int64) function candidate_lineage_id(self) result(value)
    class(groundwater_exchange_candidate_t), intent(in) :: self
    value = self%lineage_id_value
  end function candidate_lineage_id

  pure integer(int64) function candidate_origin_revision(self) result(value)
    class(groundwater_exchange_candidate_t), intent(in) :: self
    value = self%origin_revision_value
  end function candidate_origin_revision

  pure integer(int64) function candidate_revision(self) result(value)
    class(groundwater_exchange_candidate_t), intent(in) :: self
    value = self%candidate_revision_value
  end function candidate_revision

  pure subroutine candidate_origin_window(self, window, available)
    class(groundwater_exchange_candidate_t), intent(in) :: self
    type(groundwater_coupling_window_t), intent(out) :: window
    logical, intent(out) :: available
    window = groundwater_coupling_window_t()
    available = self%ready()
    if (available) then
      window%t0 = self%t0_value
      window%t1 = self%t1_value
    end if
  end subroutine candidate_origin_window

  pure logical function same_exchange_time(a, b) result(matches)
    real(real64), intent(in) :: a, b
    real(real64) :: scale

    matches = .false.
    if (.not. ieee_is_finite(a) .or. .not. ieee_is_finite(b)) return
    scale = max(1.0_real64, abs(a), abs(b))
    matches = abs(a-b) <= 64.0_real64 * epsilon(1.0_real64) * scale
  end function same_exchange_time

end module mod_groundwater_exchange_service_contract

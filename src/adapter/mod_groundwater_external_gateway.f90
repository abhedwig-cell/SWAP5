module mod_groundwater_external_gateway
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_groundwater_coupling_contract, only: groundwater_coupling_window_t
  use mod_groundwater_exchange_service_contract, only: groundwater_preparable_exchange_service_t, &
       GW_EXCHANGE_OK, GW_EXCHANGE_BACKEND_REJECTED
  implicit none
  private

  integer, parameter, public :: GW_EXTERNAL_GATEWAY_OK = 0
  integer, parameter, public :: GW_EXTERNAL_GATEWAY_INVALID_CONFIG = 1
  integer, parameter, public :: GW_EXTERNAL_GATEWAY_NOT_QUIESCENT = 2
  integer, parameter, public :: GW_EXTERNAL_GATEWAY_BATCH_CONFLICT = 3
  integer, parameter, public :: GW_EXTERNAL_BACKEND_OK = 0
  integer, parameter, public :: GW_EXTERNAL_BACKEND_NOT_CALLED = -1

  type, public :: groundwater_external_gateway_config_t
    integer(int64) :: service_id = 0_int64
    integer(int64) :: cell_id = 0_int64
    real(real64) :: head_native_to_m_scale = 0.0_real64
    real(real64) :: head_native_zero_m = 0.0_real64
    real(real64) :: flux_native_to_m_per_s_scale = 0.0_real64
    integer :: native_flux_sign_relative_to_groundwater = 1
  contains
    procedure, public :: valid => external_gateway_config_valid
  end type groundwater_external_gateway_config_t

  ! This backend contract contains only primitive external-adapter quantities.
  ! SWAP runtime types stop at groundwater_external_gateway_t.
  !
  ! The prepared publication callbacks intentionally have no status return. That
  ! matches the admitted F-GC18 two-phase publication contract: every operation
  ! that can still fail must fail during capture/trial/prepare. After prepare has
  ! succeeded, commit_prepared is a non-failing publication callback.
  type, abstract, public :: external_groundwater_backend_t
  contains
    procedure(external_capture_ifc), deferred, public :: capture
    procedure(external_trial_ifc), deferred, public :: trial
    procedure(external_commit_candidate_ifc), deferred, public :: commit_candidate
    procedure(external_discard_candidate_ifc), deferred, public :: discard_candidate
    procedure(external_prepare_ifc), deferred, public :: prepare
    procedure(external_commit_prepared_ifc), deferred, public :: commit_prepared
    procedure(external_abort_prepared_ifc), deferred, public :: abort_prepared
  end type external_groundwater_backend_t

  type, extends(groundwater_preparable_exchange_service_t), public :: groundwater_external_gateway_t
    private
    class(external_groundwater_backend_t), pointer :: backend => null()
    type(groundwater_external_gateway_config_t) :: config
    integer :: last_backend_status_value = GW_EXTERNAL_BACKEND_NOT_CALLED
  contains
    procedure, public :: bind => external_gateway_bind
    procedure, public :: ready => external_gateway_ready
    procedure, public :: last_backend_status => external_gateway_last_backend_status
    procedure, public :: configured_cell_id => external_gateway_cell_id
    procedure, public :: capture_backend => external_gateway_capture_backend
    procedure, public :: trial_backend => external_gateway_trial_backend
    procedure, public :: commit_backend => external_gateway_commit_backend
    procedure, public :: discard_backend => external_gateway_discard_backend
    procedure, public :: prepare_backend => external_gateway_prepare_backend
    procedure, public :: commit_prepared_backend => external_gateway_commit_prepared_backend
    procedure, public :: abort_prepared_backend => external_gateway_abort_prepared_backend
  end type groundwater_external_gateway_t

  public :: bind_groundwater_external_gateway_batch

  abstract interface
    subroutine external_capture_ifc(self, cell_id, lineage_id, origin_revision, origin_time, checkpoint_token, status)
      import :: external_groundwater_backend_t, int64, real64
      class(external_groundwater_backend_t), intent(inout) :: self
      integer(int64), intent(in) :: cell_id
      integer(int64), intent(out) :: lineage_id, origin_revision, checkpoint_token
      real(real64), intent(out) :: origin_time
      integer, intent(out) :: status
    end subroutine external_capture_ifc

    subroutine external_trial_ifc(self, cell_id, checkpoint_token, t0, t1, flux_native, &
                                  candidate_token, head_native, status)
      import :: external_groundwater_backend_t, int64, real64
      class(external_groundwater_backend_t), intent(inout) :: self
      integer(int64), intent(in) :: cell_id, checkpoint_token
      real(real64), intent(in) :: t0, t1, flux_native
      integer(int64), intent(out) :: candidate_token
      real(real64), intent(out) :: head_native
      integer, intent(out) :: status
    end subroutine external_trial_ifc

    subroutine external_commit_candidate_ifc(self, cell_id, checkpoint_token, candidate_token, status)
      import :: external_groundwater_backend_t, int64
      class(external_groundwater_backend_t), intent(inout) :: self
      integer(int64), intent(in) :: cell_id, checkpoint_token, candidate_token
      integer, intent(out) :: status
    end subroutine external_commit_candidate_ifc

    subroutine external_discard_candidate_ifc(self, cell_id, candidate_token, status)
      import :: external_groundwater_backend_t, int64
      class(external_groundwater_backend_t), intent(inout) :: self
      integer(int64), intent(in) :: cell_id, candidate_token
      integer, intent(out) :: status
    end subroutine external_discard_candidate_ifc

    subroutine external_prepare_ifc(self, cell_id, checkpoint_token, candidate_token, prepare_token, status)
      import :: external_groundwater_backend_t, int64
      class(external_groundwater_backend_t), intent(inout) :: self
      integer(int64), intent(in) :: cell_id, checkpoint_token, candidate_token
      integer(int64), intent(out) :: prepare_token
      integer, intent(out) :: status
    end subroutine external_prepare_ifc

    subroutine external_commit_prepared_ifc(self, cell_id, prepare_token)
      import :: external_groundwater_backend_t, int64
      class(external_groundwater_backend_t), intent(inout) :: self
      integer(int64), intent(in) :: cell_id, prepare_token
    end subroutine external_commit_prepared_ifc

    subroutine external_abort_prepared_ifc(self, cell_id, prepare_token)
      import :: external_groundwater_backend_t, int64
      class(external_groundwater_backend_t), intent(inout) :: self
      integer(int64), intent(in) :: cell_id, prepare_token
    end subroutine external_abort_prepared_ifc
  end interface

contains

  pure logical function external_gateway_config_valid(self) result(valid)
    class(groundwater_external_gateway_config_t), intent(in) :: self

    valid = .false.
    if (self%service_id <= 0_int64 .or. self%cell_id <= 0_int64) return
    if (.not. ieee_is_finite(self%head_native_to_m_scale)) return
    if (.not. ieee_is_finite(self%head_native_zero_m)) return
    if (.not. ieee_is_finite(self%flux_native_to_m_per_s_scale)) return
    if (self%head_native_to_m_scale <= 0.0_real64) return
    if (self%flux_native_to_m_per_s_scale <= 0.0_real64) return
    if (abs(self%native_flux_sign_relative_to_groundwater) /= 1) return
    valid = .true.
  end function external_gateway_config_valid

  subroutine external_gateway_bind(self, backend, config, status)
    class(groundwater_external_gateway_t), intent(inout) :: self
    class(external_groundwater_backend_t), target, intent(inout) :: backend
    type(groundwater_external_gateway_config_t), intent(in) :: config
    integer, intent(out) :: status

    status = GW_EXTERNAL_GATEWAY_INVALID_CONFIG
    if (.not. config%valid()) return
    if (.not. self%restart_quiescent()) then
      status = GW_EXTERNAL_GATEWAY_NOT_QUIESCENT
      return
    end if

    self%backend => backend
    self%config = config
    self%last_backend_status_value = GW_EXTERNAL_BACKEND_NOT_CALLED
    status = GW_EXTERNAL_GATEWAY_OK
  end subroutine external_gateway_bind

  subroutine bind_groundwater_external_gateway_batch(gateways, backend, configs, status)
    type(groundwater_external_gateway_t), intent(inout) :: gateways(:)
    class(external_groundwater_backend_t), target, intent(inout) :: backend
    type(groundwater_external_gateway_config_t), intent(in) :: configs(:)
    integer, intent(out) :: status

    integer :: i, j, local_status

    status = GW_EXTERNAL_GATEWAY_INVALID_CONFIG
    if (size(gateways) /= size(configs) .or. size(gateways) <= 0) return
    do i = 1, size(configs)
      if (.not. configs(i)%valid()) return
      do j = 1, i - 1
        if (configs(i)%service_id == configs(j)%service_id) then
          status = GW_EXTERNAL_GATEWAY_BATCH_CONFLICT
          return
        end if
        if (configs(i)%cell_id == configs(j)%cell_id) then
          status = GW_EXTERNAL_GATEWAY_BATCH_CONFLICT
          return
        end if
      end do
    end do
    ! Batch binding is a recoverable configuration operation. Preflight every
    ! member before mutating any gateway so a later non-quiescent member cannot
    ! leave earlier members rebound after the batch itself reports failure.
    do i = 1, size(gateways)
      if (.not. gateways(i)%restart_quiescent()) then
        status = GW_EXTERNAL_GATEWAY_NOT_QUIESCENT
        return
      end if
    end do
    do i = 1, size(gateways)
      call gateways(i)%bind(backend, configs(i), local_status)
      if (local_status /= GW_EXTERNAL_GATEWAY_OK) then
        status = local_status
        return
      end if
    end do
    status = GW_EXTERNAL_GATEWAY_OK
  end subroutine bind_groundwater_external_gateway_batch

  logical function external_gateway_ready(self) result(ready)
    class(groundwater_external_gateway_t), intent(in) :: self

    ready = associated(self%backend) .and. self%config%valid()
  end function external_gateway_ready

  integer function external_gateway_last_backend_status(self) result(value)
    class(groundwater_external_gateway_t), intent(in) :: self
    value = self%last_backend_status_value
  end function external_gateway_last_backend_status

  integer(int64) function external_gateway_cell_id(self) result(value)
    class(groundwater_external_gateway_t), intent(in) :: self
    value = self%config%cell_id
  end function external_gateway_cell_id

  subroutine external_gateway_capture_backend(self, service_id, lineage_id, origin_revision, origin_time, token, status)
    class(groundwater_external_gateway_t), intent(inout) :: self
    integer(int64), intent(out) :: service_id, lineage_id, origin_revision, token
    real(real64), intent(out) :: origin_time
    integer, intent(out) :: status

    integer :: backend_status

    service_id = 0_int64
    lineage_id = 0_int64
    origin_revision = -1_int64
    origin_time = 0.0_real64
    token = 0_int64
    status = GW_EXCHANGE_BACKEND_REJECTED
    self%last_backend_status_value = GW_EXTERNAL_BACKEND_NOT_CALLED
    if (.not. self%ready()) return

    call self%backend%capture(self%config%cell_id, lineage_id, origin_revision, origin_time, token, backend_status)
    self%last_backend_status_value = backend_status
    if (backend_status /= GW_EXTERNAL_BACKEND_OK) return

    service_id = self%config%service_id
    status = GW_EXCHANGE_OK
  end subroutine external_gateway_capture_backend

  subroutine external_gateway_trial_backend(self, checkpoint_token, window, q_groundwater_m_per_s, &
                                            candidate_token, h_groundwater_m, status)
    class(groundwater_external_gateway_t), intent(inout) :: self
    integer(int64), intent(in) :: checkpoint_token
    type(groundwater_coupling_window_t), intent(in) :: window
    real(real64), intent(in) :: q_groundwater_m_per_s
    integer(int64), intent(out) :: candidate_token
    real(real64), intent(out) :: h_groundwater_m
    integer, intent(out) :: status

    integer :: backend_status
    real(real64) :: flux_native, head_native

    candidate_token = 0_int64
    h_groundwater_m = 0.0_real64
    status = GW_EXCHANGE_BACKEND_REJECTED
    self%last_backend_status_value = GW_EXTERNAL_BACKEND_NOT_CALLED
    if (.not. self%ready()) return
    if (.not. ieee_is_finite(q_groundwater_m_per_s)) return

    flux_native = q_groundwater_m_per_s * real(self%config%native_flux_sign_relative_to_groundwater, real64) / &
                  self%config%flux_native_to_m_per_s_scale
    if (.not. ieee_is_finite(flux_native)) return

    head_native = 0.0_real64
    call self%backend%trial(self%config%cell_id, checkpoint_token, window%t0, window%t1, flux_native, &
         candidate_token, head_native, backend_status)
    self%last_backend_status_value = backend_status
    if (backend_status /= GW_EXTERNAL_BACKEND_OK) then
      candidate_token = 0_int64
      return
    end if
    if (candidate_token <= 0_int64 .or. .not. ieee_is_finite(head_native)) then
      candidate_token = 0_int64
      return
    end if

    h_groundwater_m = self%config%head_native_zero_m + head_native * self%config%head_native_to_m_scale
    if (.not. ieee_is_finite(h_groundwater_m)) then
      candidate_token = 0_int64
      h_groundwater_m = 0.0_real64
      return
    end if
    status = GW_EXCHANGE_OK
  end subroutine external_gateway_trial_backend

  subroutine external_gateway_commit_backend(self, checkpoint_token, candidate_token, status)
    class(groundwater_external_gateway_t), intent(inout) :: self
    integer(int64), intent(in) :: checkpoint_token, candidate_token
    integer, intent(out) :: status

    integer :: backend_status

    status = GW_EXCHANGE_BACKEND_REJECTED
    self%last_backend_status_value = GW_EXTERNAL_BACKEND_NOT_CALLED
    if (.not. self%ready()) return
    call self%backend%commit_candidate(self%config%cell_id, checkpoint_token, candidate_token, backend_status)
    self%last_backend_status_value = backend_status
    if (backend_status /= GW_EXTERNAL_BACKEND_OK) return
    status = GW_EXCHANGE_OK
  end subroutine external_gateway_commit_backend

  subroutine external_gateway_discard_backend(self, candidate_token, status)
    class(groundwater_external_gateway_t), intent(inout) :: self
    integer(int64), intent(in) :: candidate_token
    integer, intent(out) :: status

    integer :: backend_status

    status = GW_EXCHANGE_BACKEND_REJECTED
    self%last_backend_status_value = GW_EXTERNAL_BACKEND_NOT_CALLED
    if (.not. self%ready()) return
    call self%backend%discard_candidate(self%config%cell_id, candidate_token, backend_status)
    self%last_backend_status_value = backend_status
    if (backend_status /= GW_EXTERNAL_BACKEND_OK) return
    status = GW_EXCHANGE_OK
  end subroutine external_gateway_discard_backend

  subroutine external_gateway_prepare_backend(self, checkpoint_token, candidate_token, prepare_token, status)
    class(groundwater_external_gateway_t), intent(inout) :: self
    integer(int64), intent(in) :: checkpoint_token, candidate_token
    integer(int64), intent(out) :: prepare_token
    integer, intent(out) :: status

    integer :: backend_status

    prepare_token = 0_int64
    status = GW_EXCHANGE_BACKEND_REJECTED
    self%last_backend_status_value = GW_EXTERNAL_BACKEND_NOT_CALLED
    if (.not. self%ready()) return
    call self%backend%prepare(self%config%cell_id, checkpoint_token, candidate_token, prepare_token, backend_status)
    self%last_backend_status_value = backend_status
    if (backend_status /= GW_EXTERNAL_BACKEND_OK) then
      prepare_token = 0_int64
      return
    end if
    if (prepare_token <= 0_int64) return
    status = GW_EXCHANGE_OK
  end subroutine external_gateway_prepare_backend

  subroutine external_gateway_commit_prepared_backend(self, prepare_token)
    class(groundwater_external_gateway_t), intent(inout) :: self
    integer(int64), intent(in) :: prepare_token

    if (.not. self%ready()) error stop 2601
    call self%backend%commit_prepared(self%config%cell_id, prepare_token)
    self%last_backend_status_value = GW_EXTERNAL_BACKEND_OK
  end subroutine external_gateway_commit_prepared_backend

  subroutine external_gateway_abort_prepared_backend(self, prepare_token)
    class(groundwater_external_gateway_t), intent(inout) :: self
    integer(int64), intent(in) :: prepare_token

    if (.not. self%ready()) error stop 2602
    call self%backend%abort_prepared(self%config%cell_id, prepare_token)
    self%last_backend_status_value = GW_EXTERNAL_BACKEND_OK
  end subroutine external_gateway_abort_prepared_backend

end module mod_groundwater_external_gateway

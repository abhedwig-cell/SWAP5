module mod_fmr_ribasim_management_scheduler
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: int64, real64
  implicit none
  private

  integer, parameter, public :: FMR_RMS_OK = 0
  integer, parameter, public :: FMR_RMS_INVALID_CONFIG = 1
  integer, parameter, public :: FMR_RMS_INVALID_STATE = 2
  integer, parameter, public :: FMR_RMS_BOUNDARY_PENDING = 3
  integer, parameter, public :: FMR_RMS_NO_BOUNDARY_PENDING = 4
  integer, parameter, public :: FMR_RMS_INVALID_REQUEST = 5
  integer, parameter, public :: FMR_RMS_PLAN_MISMATCH = 6
  integer, parameter, public :: FMR_RMS_PLAN_OUTSTANDING = 7
  integer, parameter, public :: FMR_RMS_INVALID_PERSISTENCE = 8

  type, public :: fmr_ribasim_management_clock_persistence_t
    logical :: valid = .false.
    real(real64) :: epoch_s = 0.0_real64
    real(real64) :: allocation_dt_s = 0.0_real64
    real(real64) :: current_time_s = 0.0_real64
    integer(int64) :: next_boundary_index = 0_int64
    logical :: boundary_pending = .false.
  contains
    procedure, public :: ready => fmr_rms_persistence_ready
  end type fmr_ribasim_management_clock_persistence_t

  type, public :: fmr_ribasim_management_clock_t
    private
    logical :: initialized = .false.
    real(real64) :: epoch_s_value = 0.0_real64
    real(real64) :: allocation_dt_s_value = 0.0_real64
    real(real64) :: current_time_s_value = 0.0_real64
    integer(int64) :: next_boundary_index_value = 0_int64
    logical :: boundary_pending_value = .false.
    logical :: plan_valid = .false.
    real(real64) :: planned_target_s_value = 0.0_real64
    logical :: planned_reaches_boundary_value = .false.
  contains
    procedure, public :: ready => fmr_rms_clock_ready
    procedure, public :: current_time => fmr_rms_current_time
    procedure, public :: boundary_is_pending => fmr_rms_boundary_pending
    procedure, public :: next_boundary_time => fmr_rms_next_boundary_time
    procedure, public :: plan_advance => fmr_rms_plan_advance
    procedure, public :: accept_planned_advance => fmr_rms_accept_planned_advance
    procedure, public :: mark_boundary_solved => fmr_rms_mark_boundary_solved
    procedure, public :: has_outstanding_plan => fmr_rms_has_outstanding_plan
  end type fmr_ribasim_management_clock_t

  public :: initialize_fmr_ribasim_management_clock
  public :: export_fmr_ribasim_management_clock
  public :: reconstruct_fmr_ribasim_management_clock

contains

  pure real(real64) function time_tolerance(a,b) result(tol)
    real(real64), intent(in) :: a,b
    tol = 64.0_real64 * epsilon(1.0_real64) * max(1.0_real64,abs(a),abs(b))
  end function time_tolerance

  pure logical function same_time(a,b) result(same)
    real(real64), intent(in) :: a,b
    same = ieee_is_finite(a) .and. ieee_is_finite(b)
    if (same) same = abs(a-b) <= time_tolerance(a,b)
  end function same_time

  pure logical function strictly_after(a,b) result(after)
    real(real64), intent(in) :: a,b
    after = ieee_is_finite(a) .and. ieee_is_finite(b) .and. a > b .and. .not. same_time(a,b)
  end function strictly_after

  pure subroutine boundary_time(epoch,dt,index,value,ok)
    real(real64), intent(in) :: epoch,dt
    integer(int64), intent(in) :: index
    real(real64), intent(out) :: value
    logical, intent(out) :: ok
    real(real64) :: offset

    value = 0.0_real64
    ok = .false.
    if (.not. ieee_is_finite(epoch) .or. .not. ieee_is_finite(dt) .or. dt <= 0.0_real64 .or. index < 0_int64) return
    offset = real(index,real64) * dt
    if (.not. ieee_is_finite(offset)) return
    value = epoch + offset
    ok = ieee_is_finite(value)
  end subroutine boundary_time

  logical function fmr_rms_persistence_ready(self) result(ready)
    class(fmr_ribasim_management_clock_persistence_t), intent(in) :: self
    real(real64) :: boundary
    logical :: ok

    ready = self%valid .and. ieee_is_finite(self%epoch_s) .and. ieee_is_finite(self%allocation_dt_s) .and. &
         self%allocation_dt_s > 0.0_real64 .and. ieee_is_finite(self%current_time_s) .and. &
         self%next_boundary_index >= 0_int64
    if (.not. ready) return
    call boundary_time(self%epoch_s,self%allocation_dt_s,self%next_boundary_index,boundary,ok)
    if (.not. ok) then
      ready = .false.
      return
    end if
    if (self%boundary_pending) then
      ready = same_time(self%current_time_s,boundary)
    else
      ready = self%current_time_s < boundary .and. .not. same_time(self%current_time_s,boundary)
    end if
  end function fmr_rms_persistence_ready

  logical function fmr_rms_clock_ready(self) result(ready)
    class(fmr_ribasim_management_clock_t), intent(in) :: self
    real(real64) :: boundary
    logical :: ok

    ready = self%initialized .and. ieee_is_finite(self%epoch_s_value) .and. &
         ieee_is_finite(self%allocation_dt_s_value) .and. self%allocation_dt_s_value > 0.0_real64 .and. &
         ieee_is_finite(self%current_time_s_value) .and. self%next_boundary_index_value >= 0_int64
    if (.not. ready) return
    call boundary_time(self%epoch_s_value,self%allocation_dt_s_value,self%next_boundary_index_value,boundary,ok)
    if (.not. ok) then
      ready = .false.
      return
    end if
    if (self%boundary_pending_value) then
      ready = same_time(self%current_time_s_value,boundary)
    else
      ready = self%current_time_s_value < boundary .and. .not. same_time(self%current_time_s_value,boundary)
    end if
    if (.not. ready) return
    if (self%plan_valid) then
      ready = ieee_is_finite(self%planned_target_s_value) .and. strictly_after(self%planned_target_s_value,self%current_time_s_value) .and. &
           (self%planned_target_s_value < boundary .or. same_time(self%planned_target_s_value,boundary))
      if (ready) ready = self%planned_reaches_boundary_value .eqv. same_time(self%planned_target_s_value,boundary)
    end if
  end function fmr_rms_clock_ready

  subroutine initialize_fmr_ribasim_management_clock(epoch_s,allocation_dt_s,clock,status)
    real(real64), intent(in) :: epoch_s,allocation_dt_s
    type(fmr_ribasim_management_clock_t), intent(out) :: clock
    integer, intent(out) :: status

    clock = fmr_ribasim_management_clock_t()
    status = FMR_RMS_INVALID_CONFIG
    if (.not. ieee_is_finite(epoch_s) .or. .not. ieee_is_finite(allocation_dt_s)) return
    if (allocation_dt_s <= 0.0_real64) return

    clock%epoch_s_value = epoch_s
    clock%allocation_dt_s_value = allocation_dt_s
    clock%current_time_s_value = epoch_s
    clock%next_boundary_index_value = 0_int64
    clock%boundary_pending_value = .true.
    clock%initialized = .true.
    if (.not. clock%ready()) then
      clock = fmr_ribasim_management_clock_t()
      status = FMR_RMS_INVALID_STATE
      return
    end if
    status = FMR_RMS_OK
  end subroutine initialize_fmr_ribasim_management_clock

  real(real64) function fmr_rms_current_time(self) result(value)
    class(fmr_ribasim_management_clock_t), intent(in) :: self
    value = 0.0_real64
    if (self%ready()) value = self%current_time_s_value
  end function fmr_rms_current_time

  logical function fmr_rms_boundary_pending(self) result(pending)
    class(fmr_ribasim_management_clock_t), intent(in) :: self
    pending = self%ready() .and. self%boundary_pending_value
  end function fmr_rms_boundary_pending

  logical function fmr_rms_has_outstanding_plan(self) result(has_plan)
    class(fmr_ribasim_management_clock_t), intent(in) :: self
    has_plan = self%ready() .and. self%plan_valid
  end function fmr_rms_has_outstanding_plan

  subroutine fmr_rms_next_boundary_time(self,value,available)
    class(fmr_ribasim_management_clock_t), intent(in) :: self
    real(real64), intent(out) :: value
    logical, intent(out) :: available

    value = 0.0_real64
    available = .false.
    if (.not. self%ready()) return
    call boundary_time(self%epoch_s_value,self%allocation_dt_s_value,self%next_boundary_index_value,value,available)
  end subroutine fmr_rms_next_boundary_time

  subroutine fmr_rms_plan_advance(self,requested_target_s,planned_target_s,reaches_boundary,status)
    class(fmr_ribasim_management_clock_t), intent(inout) :: self
    real(real64), intent(in) :: requested_target_s
    real(real64), intent(out) :: planned_target_s
    logical, intent(out) :: reaches_boundary
    integer, intent(out) :: status
    real(real64) :: boundary
    logical :: available

    planned_target_s = 0.0_real64
    reaches_boundary = .false.
    status = FMR_RMS_INVALID_STATE
    if (.not. self%ready()) return
    if (self%boundary_pending_value) then
      status = FMR_RMS_BOUNDARY_PENDING
      return
    end if
    if (self%plan_valid) then
      status = FMR_RMS_PLAN_OUTSTANDING
      return
    end if
    status = FMR_RMS_INVALID_REQUEST
    if (.not. ieee_is_finite(requested_target_s)) return
    if (.not. strictly_after(requested_target_s,self%current_time_s_value)) return

    call self%next_boundary_time(boundary,available)
    if (.not. available) then
      status = FMR_RMS_INVALID_STATE
      return
    end if
    if (requested_target_s < boundary .and. .not. same_time(requested_target_s,boundary)) then
      planned_target_s = requested_target_s
      reaches_boundary = .false.
    else
      planned_target_s = boundary
      reaches_boundary = .true.
    end if

    self%planned_target_s_value = planned_target_s
    self%planned_reaches_boundary_value = reaches_boundary
    self%plan_valid = .true.
    if (.not. self%ready()) then
      self%plan_valid = .false.
      self%planned_target_s_value = 0.0_real64
      self%planned_reaches_boundary_value = .false.
      status = FMR_RMS_INVALID_STATE
      return
    end if
    status = FMR_RMS_OK
  end subroutine fmr_rms_plan_advance

  subroutine fmr_rms_accept_planned_advance(self,accepted_target_s,status)
    class(fmr_ribasim_management_clock_t), intent(inout) :: self
    real(real64), intent(in) :: accepted_target_s
    integer, intent(out) :: status
    real(real64) :: planned
    logical :: reaches

    status = FMR_RMS_INVALID_STATE
    if (.not. self%ready()) return
    status = FMR_RMS_PLAN_MISMATCH
    if (.not. self%plan_valid .or. .not. ieee_is_finite(accepted_target_s)) return
    planned = self%planned_target_s_value
    reaches = self%planned_reaches_boundary_value
    if (.not. same_time(accepted_target_s,planned)) return

    self%current_time_s_value = planned
    self%boundary_pending_value = reaches
    self%plan_valid = .false.
    self%planned_target_s_value = 0.0_real64
    self%planned_reaches_boundary_value = .false.
    if (.not. self%ready()) then
      status = FMR_RMS_INVALID_STATE
      return
    end if
    status = FMR_RMS_OK
  end subroutine fmr_rms_accept_planned_advance

  subroutine fmr_rms_mark_boundary_solved(self,status)
    class(fmr_ribasim_management_clock_t), intent(inout) :: self
    integer, intent(out) :: status
    real(real64) :: boundary
    logical :: available

    status = FMR_RMS_INVALID_STATE
    if (.not. self%ready()) return
    if (self%plan_valid) then
      status = FMR_RMS_PLAN_OUTSTANDING
      return
    end if
    if (.not. self%boundary_pending_value) then
      status = FMR_RMS_NO_BOUNDARY_PENDING
      return
    end if
    call self%next_boundary_time(boundary,available)
    if (.not. available .or. .not. same_time(boundary,self%current_time_s_value)) return
    if (self%next_boundary_index_value == huge(self%next_boundary_index_value)) then
      status = FMR_RMS_INVALID_STATE
      return
    end if

    self%next_boundary_index_value = self%next_boundary_index_value + 1_int64
    self%boundary_pending_value = .false.
    if (.not. self%ready()) then
      status = FMR_RMS_INVALID_STATE
      return
    end if
    status = FMR_RMS_OK
  end subroutine fmr_rms_mark_boundary_solved

  subroutine export_fmr_ribasim_management_clock(clock,persistence,exported,status)
    type(fmr_ribasim_management_clock_t), intent(in) :: clock
    type(fmr_ribasim_management_clock_persistence_t), intent(out) :: persistence
    logical, intent(out) :: exported
    integer, intent(out) :: status

    persistence = fmr_ribasim_management_clock_persistence_t()
    exported = .false.
    status = FMR_RMS_INVALID_STATE
    if (.not. clock%ready()) return
    if (clock%plan_valid) then
      status = FMR_RMS_PLAN_OUTSTANDING
      return
    end if

    persistence%epoch_s = clock%epoch_s_value
    persistence%allocation_dt_s = clock%allocation_dt_s_value
    persistence%current_time_s = clock%current_time_s_value
    persistence%next_boundary_index = clock%next_boundary_index_value
    persistence%boundary_pending = clock%boundary_pending_value
    persistence%valid = .true.
    if (.not. persistence%ready()) then
      persistence = fmr_ribasim_management_clock_persistence_t()
      status = FMR_RMS_INVALID_PERSISTENCE
      return
    end if
    exported = .true.
    status = FMR_RMS_OK
  end subroutine export_fmr_ribasim_management_clock

  subroutine reconstruct_fmr_ribasim_management_clock(persistence,clock,reconstructed,status)
    type(fmr_ribasim_management_clock_persistence_t), intent(in) :: persistence
    type(fmr_ribasim_management_clock_t), intent(out) :: clock
    logical, intent(out) :: reconstructed
    integer, intent(out) :: status

    clock = fmr_ribasim_management_clock_t()
    reconstructed = .false.
    status = FMR_RMS_INVALID_PERSISTENCE
    if (.not. persistence%ready()) return

    clock%epoch_s_value = persistence%epoch_s
    clock%allocation_dt_s_value = persistence%allocation_dt_s
    clock%current_time_s_value = persistence%current_time_s
    clock%next_boundary_index_value = persistence%next_boundary_index
    clock%boundary_pending_value = persistence%boundary_pending
    clock%plan_valid = .false.
    clock%initialized = .true.
    if (.not. clock%ready()) then
      clock = fmr_ribasim_management_clock_t()
      status = FMR_RMS_INVALID_STATE
      return
    end if
    reconstructed = .true.
    status = FMR_RMS_OK
  end subroutine reconstruct_fmr_ribasim_management_clock

end module mod_fmr_ribasim_management_scheduler

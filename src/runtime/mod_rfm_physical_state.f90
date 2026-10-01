module mod_rfm_physical_state
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_rfm_preferential_router, only: rfm_preferential_routing_result_t, RFM_PREF_ROUTER_AVAILABLE
  use mod_rfm_surface_event_age, only: rfm_surface_event_age_result_t, RFM_SURFACE_EVENT_AGE_AVAILABLE
  implicit none
  private

  type, public :: rfm_physical_state_t
    integer :: endpoint_count = 0
    real(real64) :: mb_water_cm = 0.0_real64
    real(real64), allocatable :: endpoint_water_cm(:)
    real(real64) :: tau_surface_day = 0.0_real64
  contains
    procedure, public :: initialize => rfm_state_initialize
    procedure, public :: clear => rfm_state_clear
    procedure, public :: ready => rfm_state_ready
    procedure, public :: storage_cm => rfm_state_storage_cm
    procedure, public :: same_values => rfm_state_same_values
    procedure, public :: payload_bytes => rfm_state_payload_bytes
  end type rfm_physical_state_t

  type, public :: rfm_candidate_receipt_t
    logical :: valid = .false.
    real(real64) :: preferential_input_cm = 0.0_real64
    real(real64) :: mb_input_cm = 0.0_real64
    real(real64) :: ic_input_cm = 0.0_real64
    real(real64) :: storage_start_cm = 0.0_real64
    real(real64) :: storage_end_cm = 0.0_real64
    real(real64) :: storage_change_cm = 0.0_real64
    real(real64) :: mass_residual_cm = 0.0_real64
  end type rfm_candidate_receipt_t

  public :: copy_rfm_physical_state
  public :: build_rfm_candidate_from_routing

contains

  subroutine rfm_state_initialize(self, endpoint_count, ok)
    class(rfm_physical_state_t), intent(inout) :: self
    integer, intent(in) :: endpoint_count
    logical, intent(out) :: ok

    ok = .false.
    call self%clear()
    if (endpoint_count <= 0) return

    self%endpoint_count = endpoint_count
    allocate(self%endpoint_water_cm(endpoint_count))
    self%endpoint_water_cm = 0.0_real64
    self%mb_water_cm = 0.0_real64
    self%tau_surface_day = 0.0_real64
    ok = .true.
  end subroutine rfm_state_initialize

  subroutine rfm_state_clear(self)
    class(rfm_physical_state_t), intent(inout) :: self
    if (allocated(self%endpoint_water_cm)) deallocate(self%endpoint_water_cm)
    self%endpoint_count = 0
    self%mb_water_cm = 0.0_real64
    self%tau_surface_day = 0.0_real64
  end subroutine rfm_state_clear

  pure logical function rfm_state_ready(self) result(ok)
    class(rfm_physical_state_t), intent(in) :: self

    ok = self%endpoint_count > 0 .and. allocated(self%endpoint_water_cm)
    if (.not. ok) return
    ok = size(self%endpoint_water_cm) == self%endpoint_count
    if (.not. ok) return
    ok = ieee_is_finite(self%mb_water_cm) .and. self%mb_water_cm >= 0.0_real64 .and. &
         ieee_is_finite(self%tau_surface_day) .and. self%tau_surface_day >= 0.0_real64 .and. &
         all(ieee_is_finite(self%endpoint_water_cm)) .and. all(self%endpoint_water_cm >= 0.0_real64)
  end function rfm_state_ready

  pure real(real64) function rfm_state_storage_cm(self) result(value)
    class(rfm_physical_state_t), intent(in) :: self
    value = 0.0_real64
    if (.not. self%ready()) return
    value = self%mb_water_cm + sum(self%endpoint_water_cm)
  end function rfm_state_storage_cm

  pure logical function rfm_state_same_values(self, other) result(same)
    class(rfm_physical_state_t), intent(in) :: self
    type(rfm_physical_state_t), intent(in) :: other

    same = self%ready() .and. other%ready()
    if (.not. same) return
    same = self%endpoint_count == other%endpoint_count
    if (.not. same) return
    same = transfer(self%mb_water_cm,0_int64) == transfer(other%mb_water_cm,0_int64) .and. &
         transfer(self%tau_surface_day,0_int64) == transfer(other%tau_surface_day,0_int64)
    if (.not. same) return
    same = all(transfer(self%endpoint_water_cm,[0_int64],size(self%endpoint_water_cm)) == &
         transfer(other%endpoint_water_cm,[0_int64],size(other%endpoint_water_cm)))
  end function rfm_state_same_values

  pure integer(int64) function rfm_state_payload_bytes(self) result(value)
    class(rfm_physical_state_t), intent(in) :: self
    value = 0_int64
    if (.not. self%ready()) return
    value = int(storage_size(self%mb_water_cm)/8,int64) + &
         int(storage_size(self%tau_surface_day)/8,int64) + &
         int(size(self%endpoint_water_cm),int64)*int(storage_size(self%endpoint_water_cm(1))/8,int64)
  end function rfm_state_payload_bytes

  subroutine copy_rfm_physical_state(source, target, ok)
    type(rfm_physical_state_t), intent(in) :: source
    type(rfm_physical_state_t), intent(out) :: target
    logical, intent(out) :: ok

    ok = .false.
    call target%clear()
    if (.not. source%ready()) return
    call target%initialize(source%endpoint_count,ok)
    if (.not. ok) return
    target%mb_water_cm = source%mb_water_cm
    target%endpoint_water_cm = source%endpoint_water_cm
    target%tau_surface_day = source%tau_surface_day
    ok = target%ready()
  end subroutine copy_rfm_physical_state

  subroutine build_rfm_candidate_from_routing(accepted, routing, event_age, step_duration_day, tolerance, &
       candidate, receipt, ok)
    type(rfm_physical_state_t), intent(in) :: accepted
    type(rfm_preferential_routing_result_t), intent(in) :: routing
    type(rfm_surface_event_age_result_t), intent(in) :: event_age
    real(real64), intent(in) :: step_duration_day, tolerance
    type(rfm_physical_state_t), intent(out) :: candidate
    type(rfm_candidate_receipt_t), intent(out) :: receipt
    logical, intent(out) :: ok

    real(real64) :: start_storage, end_storage, mb_input, ic_input

    receipt = rfm_candidate_receipt_t()
    ok = .false.
    call candidate%clear()

    if (.not. accepted%ready()) return
    if (routing%status /= RFM_PREF_ROUTER_AVAILABLE) return
    if (event_age%status /= RFM_SURFACE_EVENT_AGE_AVAILABLE) return
    if (.not. ieee_is_finite(step_duration_day) .or. step_duration_day <= 0.0_real64) return
    if (.not. ieee_is_finite(tolerance) .or. tolerance < 0.0_real64) return
    if (.not. allocated(routing%endpoint_amount)) return
    if (size(routing%endpoint_amount) /= accepted%endpoint_count) return
    if (.not. ieee_is_finite(routing%mb_amount) .or. routing%mb_amount < 0.0_real64) return
    if (any(.not. ieee_is_finite(routing%endpoint_amount)) .or. any(routing%endpoint_amount < 0.0_real64)) return
    if (.not. ieee_is_finite(event_age%candidate_age_day) .or. event_age%candidate_age_day < 0.0_real64) return

    call copy_rfm_physical_state(accepted,candidate,ok)
    if (.not. ok) return

    start_storage = accepted%storage_cm()
    mb_input = routing%mb_amount*step_duration_day
    ic_input = sum(routing%endpoint_amount)*step_duration_day

    candidate%mb_water_cm = candidate%mb_water_cm + mb_input
    candidate%endpoint_water_cm = candidate%endpoint_water_cm + routing%endpoint_amount*step_duration_day
    candidate%tau_surface_day = event_age%candidate_age_day

    if (.not. candidate%ready()) then
      call candidate%clear()
      ok = .false.
      return
    end if

    end_storage = candidate%storage_cm()
    receipt%mb_input_cm = mb_input
    receipt%ic_input_cm = ic_input
    receipt%preferential_input_cm = mb_input + ic_input
    receipt%storage_start_cm = start_storage
    receipt%storage_end_cm = end_storage
    receipt%storage_change_cm = end_storage-start_storage
    receipt%mass_residual_cm = receipt%storage_change_cm-receipt%preferential_input_cm
    receipt%valid = abs(receipt%mass_residual_cm) <= tolerance
    ok = receipt%valid
  end subroutine build_rfm_candidate_from_routing

end module mod_rfm_physical_state

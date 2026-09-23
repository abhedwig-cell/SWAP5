module mod_b110_generated_mvg_provider
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: constitutive_hydraulics_provider_t
  use mod_b110_generated_mvg_table_state, only: b110_generated_mvg_table_state_t, &
       evaluate_b110_generated_mvg_table_state, F_TAB02_STATE_OK
  implicit none
  private

  integer, parameter, public :: F_TAB02_PROVIDER_OK = 0
  integer, parameter, public :: F_TAB02_PROVIDER_STATE_NOT_READY = 1
  integer, parameter, public :: F_TAB02_PROVIDER_INVALID_STEP = 2

  type, extends(constitutive_hydraulics_provider_t), public :: b110_generated_mvg_provider_t
    private
    type(b110_generated_mvg_table_state_t), pointer :: state => null()
    real(real64) :: step_duration = 0.0_real64
  contains
    procedure :: evaluate => b110_generated_mvg_evaluate
    procedure :: context_compatible => generated_provider_context_compatible
    procedure :: ready => generated_provider_ready
  end type b110_generated_mvg_provider_t

  public :: bind_b110_generated_mvg_provider

contains

  subroutine bind_b110_generated_mvg_provider(provider, state, step_duration, status)
    type(b110_generated_mvg_provider_t), intent(out) :: provider
    type(b110_generated_mvg_table_state_t), target, intent(in) :: state
    real(real64), intent(in) :: step_duration
    integer, intent(out) :: status

    nullify(provider%state)
    provider%step_duration = 0.0_real64

    status = F_TAB02_PROVIDER_STATE_NOT_READY
    if (.not. state%ready()) return

    status = F_TAB02_PROVIDER_INVALID_STEP
    if (step_duration <= 0.0_real64) return

    provider%state => state
    provider%step_duration = step_duration
    status = F_TAB02_PROVIDER_OK
  end subroutine bind_b110_generated_mvg_provider

  logical function generated_provider_context_compatible(self, step_duration) result(compatible)
    class(b110_generated_mvg_provider_t), intent(in) :: self
    real(real64), intent(in) :: step_duration
    real(real64) :: scale

    compatible = .false.
    if (.not. self%ready()) return
    if (.not. ieee_is_finite(step_duration) .or. step_duration <= 0.0_real64) return
    if (.not. ieee_is_finite(self%step_duration) .or. self%step_duration <= 0.0_real64) return
    scale = max(1.0_real64, abs(self%step_duration), abs(step_duration))
    compatible = abs(self%step_duration-step_duration) <= 16.0_real64*epsilon(1.0_real64)*scale
  end function generated_provider_context_compatible

  subroutine b110_generated_mvg_evaluate(self, pressure_head, water_content, conductivity, capacity, dconductivity_dhead)
    class(b110_generated_mvg_provider_t), intent(in) :: self
    real(real64), intent(in) :: pressure_head(:)
    real(real64), intent(out) :: water_content(:), conductivity(:), capacity(:), dconductivity_dhead(:)
    real(real64) :: capacity_floor
    integer :: i, status

    if (.not. self%ready()) error stop 'F-TAB02 generated MvG provider: provider not bound'

    call evaluate_b110_generated_mvg_table_state(self%state, pressure_head, water_content, conductivity, capacity, status)
    if (status /= F_TAB02_STATE_OK) error stop 'F-TAB02 generated MvG provider: table-state evaluation failed'

    capacity_floor = self%step_duration * 1.0e-7_real64
    do i = 1, size(pressure_head)
      if (pressure_head(i) >= 0.0_real64) then
        capacity(i) = capacity_floor
      else if (pressure_head(i) > -1.0_real64 .and. capacity(i) < capacity_floor) then
        capacity(i) = capacity_floor
      end if
    end do

    ! F-TAB02 is K0-only. The common ABI reserves this slot for a separately
    ! admitted implicit-conductivity route.
    dconductivity_dhead = 0.0_real64
  end subroutine b110_generated_mvg_evaluate

  logical function generated_provider_ready(self) result(ready)
    class(b110_generated_mvg_provider_t), intent(in) :: self
    ready = associated(self%state) .and. self%step_duration > 0.0_real64
    if (ready) ready = self%state%ready()
  end function generated_provider_ready

end module mod_b110_generated_mvg_provider

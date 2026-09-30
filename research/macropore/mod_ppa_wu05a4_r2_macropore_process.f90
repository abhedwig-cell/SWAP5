module mod_ppa_wu05a4_r2_macropore_process
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: soil_water_physical_state_t
  use mod_macropore_continuation_state, only: macropore_continuation_state_t, &
       copy_macropore_continuation_state
  implicit none
  private

  type, public :: ppa_wu05a4_r2_process_t
    integer :: domain_index = 1
    integer :: node_index = 1
    real(real64) :: sorptivity_max = 0.5_real64
    real(real64) :: sorptivity_alpha = 0.5_real64
    real(real64) :: matrix_fraction = 0.92_real64
    real(real64) :: wall_fraction = 0.08_real64
    real(real64) :: wall_correction = 0.95_real64
    real(real64) :: compartment_thickness_cm = 10.0_real64
    real(real64) :: characteristic_diameter_cm = 4.0_real64
    real(real64) :: theta_s = 0.427494_real64
    real(real64) :: theta_r = 0.02_real64
  contains
    procedure, public :: ready => process_ready
    procedure, public :: evaluate_exchange => process_evaluate_exchange
    procedure, public :: build_candidate => process_build_candidate
  end type ppa_wu05a4_r2_process_t

contains

  pure logical function process_ready(self, matrix, macro) result(ok)
    class(ppa_wu05a4_r2_process_t), intent(in) :: self
    type(soil_water_physical_state_t), intent(in) :: matrix
    type(macropore_continuation_state_t), intent(in) :: macro

    ok = macro%ready()
    if (.not. ok) return
    ok = matrix%active_nodes == macro%num_nodes .and. allocated(matrix%water_content)
    if (.not. ok) return
    ok = size(matrix%water_content) == matrix%active_nodes
    if (.not. ok) return
    ok = self%domain_index >= 1 .and. self%domain_index <= macro%num_domains .and. &
         self%node_index >= 1 .and. self%node_index <= macro%num_nodes
    if (.not. ok) return
    ok = self%sorptivity_max >= 0.0_real64 .and. self%sorptivity_alpha > 0.0_real64 .and. &
         self%wall_fraction > 0.0_real64 .and. self%compartment_thickness_cm > 0.0_real64 .and. &
         self%characteristic_diameter_cm > 0.0_real64 .and. self%theta_s > self%theta_r
  end function process_ready

  subroutine process_evaluate_exchange(self, matrix, accepted_macro, step_duration, exchange_rate, ok)
    class(ppa_wu05a4_r2_process_t), intent(in) :: self
    type(soil_water_physical_state_t), intent(in) :: matrix
    type(macropore_continuation_state_t), intent(in) :: accepted_macro
    real(real64), intent(in) :: step_duration
    real(real64), intent(out) :: exchange_rate(:)
    logical, intent(out) :: ok

    integer :: id, ic
    real(real64) :: theta, tabs, theta_ref, sorp, active, deficit, amount, available

    exchange_rate = 0.0_real64
    ok = .false.
    if (step_duration <= 0.0_real64) return
    if (.not. self%ready(matrix, accepted_macro)) return
    if (size(exchange_rate) /= matrix%active_nodes) return

    id = self%domain_index
    ic = self%node_index
    theta = matrix%water_content(ic)
    deficit = max(0.0_real64, self%theta_s - theta)
    if (deficit < 1.0e-8_real64) then
      ok = .true.
      return
    end if

    tabs = accepted_macro%absorption_time(id,ic)
    theta_ref = accepted_macro%theta_sorption_ref(id,ic)
    sorp = accepted_macro%sorptivity(id,ic)

    if (tabs < 1.0e-8_real64) then
      sorp = self%sorptivity_max * (deficit / (self%theta_s - self%theta_r))**self%sorptivity_alpha
      active = sorp
    else if (theta_ref - theta > 1.0e-8_real64) then
      active = self%sorptivity_max * &
           ((theta_ref - theta) / (self%theta_s - self%theta_r))**self%sorptivity_alpha
    else
      active = 0.0_real64
    end if

    amount = active * self%wall_fraction * &
         (4.0_real64*self%wall_correction*self%compartment_thickness_cm/self%characteristic_diameter_cm) * &
         (sqrt(tabs + step_duration) - sqrt(tabs))

    available = max(0.0_real64, accepted_macro%water_domain_cp(id,ic))
    amount = min(max(0.0_real64, amount), available)
    exchange_rate(ic) = amount / step_duration
    ok = .true.
  end subroutine process_evaluate_exchange

  subroutine process_build_candidate(self, matrix, accepted_macro, step_duration, exchange_rate, candidate_macro, ok)
    class(ppa_wu05a4_r2_process_t), intent(in) :: self
    type(soil_water_physical_state_t), intent(in) :: matrix
    type(macropore_continuation_state_t), intent(in) :: accepted_macro
    real(real64), intent(in) :: step_duration
    real(real64), intent(in) :: exchange_rate(:)
    type(macropore_continuation_state_t), intent(inout) :: candidate_macro
    logical, intent(out) :: ok

    integer :: id, ic
    real(real64) :: amount, theta, deficit, sorp, theta_ref, tabs, delta_root

    ok = .false.
    if (.not. self%ready(matrix, accepted_macro)) return
    if (step_duration <= 0.0_real64) return
    if (size(exchange_rate) /= matrix%active_nodes) return

    call copy_macropore_continuation_state(accepted_macro, candidate_macro, ok)
    if (.not. ok) return

    id = self%domain_index
    ic = self%node_index
    amount = max(0.0_real64, exchange_rate(ic))*step_duration
    if (amount > candidate_macro%water_domain_cp(id,ic) + 1.0e-12_real64) then
      call candidate_macro%clear()
      ok = .false.
      return
    end if

    candidate_macro%water_domain_cp(id,ic) = &
         max(0.0_real64, candidate_macro%water_domain_cp(id,ic) - amount)

    theta = matrix%water_content(ic)
    deficit = max(0.0_real64, self%theta_s - theta)
    tabs = accepted_macro%absorption_time(id,ic)

    if (amount/step_duration <= 1.0e-7_real64 .or. deficit < 1.0e-8_real64) then
      candidate_macro%sorptivity(id,ic) = 0.0_real64
      candidate_macro%theta_sorption_ref(id,ic) = 0.0_real64
      candidate_macro%absorption_time(id,ic) = 0.0_real64
      ok = .true.
      return
    end if

    if (tabs < 1.0e-8_real64) then
      theta_ref = self%theta_s
      sorp = self%sorptivity_max * (deficit / (self%theta_s - self%theta_r))**self%sorptivity_alpha
    else
      theta_ref = accepted_macro%theta_sorption_ref(id,ic)
      sorp = accepted_macro%sorptivity(id,ic)
    end if

    delta_root = sqrt(tabs + step_duration) - sqrt(tabs)
    theta_ref = theta_ref + self%wall_correction*self%wall_fraction * &
         (4.0_real64/self%characteristic_diameter_cm)*sorp*delta_root

    candidate_macro%sorptivity(id,ic) = sorp
    candidate_macro%theta_sorption_ref(id,ic) = theta_ref
    candidate_macro%absorption_time(id,ic) = tabs + step_duration
    ok = .true.
  end subroutine process_build_candidate

end module mod_ppa_wu05a4_r2_macropore_process

module mod_ppa_wu05a3_absorption_arbitration
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: PPA_WU05A3_ABSORPTION_ARBITRATION_OK = 0
  integer, parameter, public :: PPA_WU05A3_ABSORPTION_ARBITRATION_INVALID_INPUT = 1

  public :: ppa_wu05a3_absorption_arbitrate

contains

  pure subroutine ppa_wu05a3_absorption_arbitrate(sorptivity_potential, darcy_potential, sorptivity_factor, &
       flow_reduction, time_step, matrix_outflow, sorptivity_remaining, darcy_remaining, &
       sorptivity_selected, sorptivity_event_continues, status)
    real(real64), intent(in) :: sorptivity_potential, darcy_potential, sorptivity_factor
    real(real64), intent(in) :: flow_reduction, time_step
    real(real64), intent(out) :: matrix_outflow, sorptivity_remaining, darcy_remaining
    logical, intent(out) :: sorptivity_selected, sorptivity_event_continues
    integer, intent(out) :: status

    matrix_outflow = 0.0_real64
    sorptivity_remaining = 0.0_real64
    darcy_remaining = 0.0_real64
    sorptivity_selected = .false.
    sorptivity_event_continues = .false.
    status = PPA_WU05A3_ABSORPTION_ARBITRATION_INVALID_INPUT
    if (.not. ieee_is_finite(sorptivity_potential) .or. .not. ieee_is_finite(darcy_potential) .or. &
        .not. ieee_is_finite(sorptivity_factor) .or. .not. ieee_is_finite(flow_reduction) .or. &
        .not. ieee_is_finite(time_step)) return
    if (sorptivity_potential < 0.0_real64 .or. darcy_potential < 0.0_real64 .or. &
        sorptivity_factor < 0.0_real64 .or. flow_reduction < 0.0_real64 .or. flow_reduction > 1.0_real64 .or. &
        time_step <= 0.0_real64) return

    ! Source: B1.11 SWAP/macrorate.f90 ABSORPTION, lines 1790-1805.
    if (sorptivity_potential > sorptivity_factor*darcy_potential) then
      matrix_outflow = flow_reduction*sorptivity_potential
      sorptivity_selected = .true.
      sorptivity_remaining = sorptivity_potential
      darcy_remaining = 0.0_real64
    else
      matrix_outflow = flow_reduction*sorptivity_factor*darcy_potential
      sorptivity_remaining = 0.0_real64
      darcy_remaining = darcy_potential
    end if
    sorptivity_event_continues = sorptivity_remaining/time_step > 1.0e-7_real64
    status = PPA_WU05A3_ABSORPTION_ARBITRATION_OK
  end subroutine ppa_wu05a3_absorption_arbitrate

end module mod_ppa_wu05a3_absorption_arbitration

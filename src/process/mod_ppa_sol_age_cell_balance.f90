module mod_ppa_sol_age_cell_balance
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: PPA_SOL_AGE_CELL_OK = 0
  integer, parameter, public :: PPA_SOL_AGE_CELL_INVALID_INPUT = 1
  public :: ppa_sol_age_cell_candidate

contains

  pure subroutine ppa_sol_age_cell_candidate(previous_age_storage, bottom_age_amount, top_age_amount, &
       cell_thickness, water_content, previous_water_content, root_age_rate, lateral_age_rate, &
       interval_days, candidate_age_storage, candidate_age_concentration, status)
    real(real64), intent(in) :: previous_age_storage, bottom_age_amount, top_age_amount
    real(real64), intent(in) :: cell_thickness, water_content, previous_water_content
    real(real64), intent(in) :: root_age_rate, lateral_age_rate, interval_days
    real(real64), intent(out) :: candidate_age_storage, candidate_age_concentration
    integer, intent(out) :: status
    real(real64) :: age_production

    candidate_age_storage = 0.0_real64
    candidate_age_concentration = 0.0_real64
    status = PPA_SOL_AGE_CELL_INVALID_INPUT
    if (.not. all(ieee_is_finite([previous_age_storage, bottom_age_amount, top_age_amount, &
        cell_thickness, water_content, previous_water_content, root_age_rate, lateral_age_rate, interval_days]))) return
    if (cell_thickness <= 0.0_real64 .or. water_content <= 0.0_real64 .or. interval_days <= 0.0_real64) return

    ! Source: exact B1.11 SWAP/solute.f90 AgeTracer task-2 compartment update.
    age_production = 1.0_real64 * 0.5_real64 * (water_content + previous_water_content)
    candidate_age_storage = previous_age_storage + (bottom_age_amount - top_age_amount) / cell_thickness + &
         (-root_age_rate - lateral_age_rate + age_production) * interval_days
    candidate_age_concentration = candidate_age_storage / water_content
    if (.not. all(ieee_is_finite([candidate_age_storage, candidate_age_concentration]))) then
      candidate_age_storage = 0.0_real64
      candidate_age_concentration = 0.0_real64
      return
    end if
    status = PPA_SOL_AGE_CELL_OK
  end subroutine ppa_sol_age_cell_candidate

end module mod_ppa_sol_age_cell_balance

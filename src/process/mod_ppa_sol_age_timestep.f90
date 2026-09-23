module mod_ppa_sol_age_timestep
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: PPA_SOL_AGE_DT_OK = 0
  integer, parameter, public :: PPA_SOL_AGE_DT_INVALID_INPUT = 1
  public :: ppa_sol_age_stable_candidate, ppa_sol_age_next_substep

contains

  pure subroutine ppa_sol_age_stable_candidate(interval_days, theta, theta_lower, face_upper_weight, face_lower_weight, &
       lateral_diffusion, layer_lateral_dispersion, water_flux, layer_porosity, cell_thickness, &
       layer_index_by_cell, stable_interval_days, status)
    real(real64), intent(in) :: interval_days, theta(:), theta_lower(:), face_upper_weight(:), face_lower_weight(:)
    real(real64), intent(in) :: lateral_diffusion, layer_lateral_dispersion(:), water_flux(:)
    real(real64), intent(in) :: layer_porosity(:), cell_thickness(:)
    real(real64), intent(out) :: stable_interval_days
    integer, intent(in) :: layer_index_by_cell(:)
    integer, intent(out) :: status
    real(real64) :: theta_face, diffusivity, dispersivity, candidate
    integer :: n, i, layer_index

    stable_interval_days = 0.0_real64
    status = PPA_SOL_AGE_DT_INVALID_INPUT
    n = size(theta)
    if (n <= 0 .or. size(face_upper_weight) /= n + 1 .or. size(face_lower_weight) /= n + 1 .or. &
        size(theta_lower) /= n .or. size(water_flux) /= n + 1 .or. size(cell_thickness) /= n .or. &
        size(layer_index_by_cell) /= n .or. &
        size(layer_porosity) <= 0 .or. &
        size(layer_lateral_dispersion) /= size(layer_porosity)) return
    if (.not. ieee_is_finite(interval_days) .or. .not. ieee_is_finite(lateral_diffusion) .or. &
        .not. all(ieee_is_finite(theta)) .or. .not. all(ieee_is_finite(theta_lower)) .or. &
        .not. all(ieee_is_finite(face_upper_weight)) .or. &
        .not. all(ieee_is_finite(face_lower_weight)) .or. .not. all(ieee_is_finite(water_flux)) .or. &
        .not. all(ieee_is_finite(layer_porosity)) .or. .not. all(ieee_is_finite(cell_thickness)) .or. &
        .not. all(ieee_is_finite(layer_lateral_dispersion))) return
    if (interval_days <= 0.0_real64 .or. lateral_diffusion < 0.0_real64 .or. any(theta <= 0.0_real64) .or. &
        any(theta_lower <= 0.0_real64) .or. &
        any(layer_porosity <= 0.0_real64) .or. any(cell_thickness <= 0.0_real64) .or. &
        any(layer_lateral_dispersion < 0.0_real64)) return

    stable_interval_days = interval_days
    do i = 1, n
      layer_index = layer_index_by_cell(i)
      if (layer_index < 1 .or. layer_index > size(layer_porosity)) then
        stable_interval_days = 0.0_real64
        return
      end if
      theta_face = face_upper_weight(i + 1) * theta(i) + face_lower_weight(i) * theta_lower(i)
      if (theta_face <= 0.0_real64) then
        stable_interval_days = 0.0_real64
        return
      end if
      diffusivity = lateral_diffusion * (theta_face ** 2.33_real64) / (layer_porosity(layer_index) ** 2)
      dispersivity = diffusivity + layer_lateral_dispersion(layer_index) * abs(water_flux(i)) / theta(i)
      if (dispersivity < 1.0e-8_real64) dispersivity = 1.0e-8_real64
      candidate = cell_thickness(i) * cell_thickness(i) * theta(i) / 2.0_real64 / dispersivity
      stable_interval_days = min(stable_interval_days, candidate)
    end do
    if (.not. ieee_is_finite(stable_interval_days) .or. stable_interval_days <= 0.0_real64) then
      stable_interval_days = 0.0_real64
      return
    end if
    status = PPA_SOL_AGE_DT_OK
  end subroutine ppa_sol_age_stable_candidate

  pure subroutine ppa_sol_age_next_substep(interval_days, elapsed_days, stable_interval_days, minimum_step_days, &
       next_step_days, next_elapsed_days, continue_loop, status)
    real(real64), intent(in) :: interval_days, elapsed_days, stable_interval_days, minimum_step_days
    real(real64), intent(out) :: next_step_days, next_elapsed_days
    logical, intent(out) :: continue_loop
    integer, intent(out) :: status

    next_step_days = 0.0_real64
    next_elapsed_days = elapsed_days
    continue_loop = .false.
    status = PPA_SOL_AGE_DT_INVALID_INPUT
    if (.not. ieee_is_finite(interval_days) .or. .not. ieee_is_finite(elapsed_days) .or. &
        .not. ieee_is_finite(stable_interval_days) .or. .not. ieee_is_finite(minimum_step_days)) return
    if (interval_days <= 0.0_real64 .or. elapsed_days < 0.0_real64 .or. stable_interval_days <= 0.0_real64 .or. &
        minimum_step_days <= 0.0_real64) return
    continue_loop = (interval_days - elapsed_days) > 1.0e-8_real64
    if (continue_loop) then
      next_step_days = min(stable_interval_days, interval_days - elapsed_days)
      next_step_days = max(next_step_days, minimum_step_days)
      next_elapsed_days = elapsed_days + next_step_days
    end if
    status = PPA_SOL_AGE_DT_OK
  end subroutine ppa_sol_age_next_substep

end module mod_ppa_sol_age_timestep

module mod_ppa_sol_age_substep
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: PPA_SOL_AGE_SUBSTEP_OK = 0
  integer, parameter, public :: PPA_SOL_AGE_SUBSTEP_INVALID_INPUT = 1
  integer, parameter, public :: PPA_SOL_AGE_SUBSTEP_ALLOCATION_FAILED = 2
  public :: ppa_sol_age_substep_candidate

contains

  pure subroutine ppa_sol_age_substep_candidate(previous_age_storage, age_concentration, water_flux_faces, &
       face_upper_weight, face_lower_weight, water_content_faces, age_dispersion_faces, face_distance, &
       water_content, previous_water_content, cell_thickness, root_water_rate, lateral_water_rates, &
       age_drain_concentration, top_age_amount, interval_days, candidate_age_storage, &
       candidate_age_concentration, status)
    real(real64), intent(in) :: previous_age_storage(:), age_concentration(:), water_flux_faces(:)
    real(real64), intent(in) :: face_upper_weight(:), face_lower_weight(:), water_content_faces(:)
    real(real64), intent(in) :: age_dispersion_faces(:), face_distance(:)
    real(real64), intent(in) :: water_content(:), previous_water_content(:), cell_thickness(:), root_water_rate(:)
    real(real64), intent(in) :: lateral_water_rates(:,:), age_drain_concentration, top_age_amount, interval_days
    real(real64), allocatable, intent(out) :: candidate_age_storage(:), candidate_age_concentration(:)
    integer, intent(out) :: status
    real(real64), allocatable :: local_storage(:), local_concentration(:)
    real(real64) :: face_age, face_top_age, root_age_rate, lateral_age_rate, age_production
    integer :: n, i, level, allocation_status

    status = PPA_SOL_AGE_SUBSTEP_INVALID_INPUT
    n = size(previous_age_storage)
    if (n <= 0 .or. size(age_concentration) /= n .or. size(water_flux_faces) /= n + 1 .or. &
        size(face_upper_weight) /= n + 1 .or. size(face_lower_weight) /= n + 1 .or. &
        size(water_content_faces) /= n + 1 .or. size(age_dispersion_faces) /= n + 1 .or. &
        size(face_distance) /= n + 1 .or. size(water_content) /= n .or. size(previous_water_content) /= n .or. &
        size(cell_thickness) /= n .or. size(root_water_rate) /= n .or. size(lateral_water_rates, 2) /= n) return
    if (.not. all(ieee_is_finite(previous_age_storage)) .or. .not. all(ieee_is_finite(age_concentration)) .or. &
        .not. all(ieee_is_finite(water_flux_faces)) .or. .not. all(ieee_is_finite(face_upper_weight)) .or. &
        .not. all(ieee_is_finite(face_lower_weight)) .or. .not. all(ieee_is_finite(water_content_faces)) .or. &
        .not. all(ieee_is_finite(age_dispersion_faces)) .or. .not. all(ieee_is_finite(face_distance)) .or. &
        .not. all(ieee_is_finite(water_content)) .or. .not. all(ieee_is_finite(previous_water_content)) .or. &
        .not. all(ieee_is_finite(cell_thickness)) .or. .not. all(ieee_is_finite(root_water_rate)) .or. &
        .not. all(ieee_is_finite(lateral_water_rates)) .or. .not. ieee_is_finite(age_drain_concentration) .or. &
        .not. ieee_is_finite(top_age_amount) .or. .not. ieee_is_finite(interval_days)) return
    if (interval_days <= 0.0_real64 .or. any(water_content <= 0.0_real64) .or. &
        any(cell_thickness <= 0.0_real64) .or. any(age_dispersion_faces < 0.0_real64) .or. &
        any(water_content_faces(2:n + 1) <= 0.0_real64) .or. any(face_distance(2:n) <= 0.0_real64)) return

    allocate(local_storage(n), local_concentration(n), stat=allocation_status)
    if (allocation_status /= 0) then
      status = PPA_SOL_AGE_SUBSTEP_ALLOCATION_FAILED
      return
    end if
    local_storage = previous_age_storage
    local_concentration = age_concentration
    face_top_age = top_age_amount

    ! B1.11 AgeTracer task 2 traverses from the soil surface downward. Each
    ! just-updated upper concentration feeds the next internal face below.
    do i = 1, n
      if (i < n) then
        face_age = (water_flux_faces(i + 1) * &
             (face_upper_weight(i + 1) * local_concentration(i) + face_lower_weight(i) * local_concentration(i + 1)) + &
             water_content_faces(i + 1) * age_dispersion_faces(i + 1) * &
             (local_concentration(i + 1) - local_concentration(i)) / face_distance(i + 1)) * interval_days
      else if (water_flux_faces(n + 1) > 0.0_real64) then
        face_age = water_flux_faces(n + 1) * age_drain_concentration * interval_days
      else
        face_age = water_flux_faces(n + 1) * local_concentration(n) * interval_days
      end if

      root_age_rate = root_water_rate(i) * local_concentration(i) / cell_thickness(i)
      lateral_age_rate = 0.0_real64
      do level = 1, size(lateral_water_rates, 1)
        if (lateral_water_rates(level, i) > 0.0_real64) then
          lateral_age_rate = lateral_age_rate + lateral_water_rates(level, i) * local_concentration(i) / cell_thickness(i)
        else
          lateral_age_rate = lateral_age_rate + lateral_water_rates(level, i) * age_drain_concentration / cell_thickness(i)
        end if
      end do
      age_production = 1.0_real64 * 0.5_real64 * (water_content(i) + previous_water_content(i))
      local_storage(i) = local_storage(i) + (face_age - face_top_age) / cell_thickness(i) + &
           (-root_age_rate - lateral_age_rate + age_production) * interval_days
      local_concentration(i) = local_storage(i) / water_content(i)
      if (.not. ieee_is_finite(local_storage(i)) .or. .not. ieee_is_finite(local_concentration(i))) return
      face_top_age = face_age
    end do

    call move_alloc(local_storage, candidate_age_storage)
    call move_alloc(local_concentration, candidate_age_concentration)
    status = PPA_SOL_AGE_SUBSTEP_OK
  end subroutine ppa_sol_age_substep_candidate

end module mod_ppa_sol_age_substep

module mod_modflow6_linear_response_backend
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_groundwater_coupling_contract, only: groundwater_coupling_window_t
  use mod_modflow6_multiswap_cell_response, only: modflow6_multiswap_cell_response_t, MODFLOW6_MULTI_CELL_OK
  implicit none
  private

  real(real64), parameter :: DAY_TO_S = 86400.0_real64

  integer, parameter, public :: MODFLOW6_LINEAR_BACKEND_OK = 0
  integer, parameter, public :: MODFLOW6_LINEAR_BACKEND_INVALID_CELL_RESPONSE = 1
  integer, parameter, public :: MODFLOW6_LINEAR_BACKEND_INVALID_AREA = 2
  integer, parameter, public :: MODFLOW6_LINEAR_BACKEND_NONFINITE_SOURCE = 3
  integer, parameter, public :: MODFLOW6_LINEAR_BACKEND_NONFINITE_COEFFICIENT = 4
  integer, parameter, public :: MODFLOW6_LINEAR_BACKEND_INVALID_EVALUATION = 5

  type, public :: modflow6_linear_boundary_term_t
    integer :: status = MODFLOW6_LINEAR_BACKEND_INVALID_CELL_RESPONSE
    logical :: valid = .false.
    integer(int64) :: groundwater_cell_id = 0_int64
    type(groundwater_coupling_window_t) :: window
    integer(int64) :: coupling_id = 0_int64
    integer(int64) :: groundwater_service_id = 0_int64
    integer(int64) :: groundwater_lineage_id = 0_int64
    integer(int64) :: groundwater_origin_revision = -1_int64
    real(real64) :: cell_area_m2 = 0.0_real64
    real(real64) :: reference_head_m = 0.0_real64
    real(real64) :: q_u_at_reference_m_per_s = 0.0_real64
    real(real64) :: dq_u_dh_per_s = 0.0_real64
    real(real64) :: reference_volume_flux_m3_per_day = 0.0_real64
    real(real64) :: hcof_m2_per_day = 0.0_real64
    real(real64) :: rhs_m3_per_day = 0.0_real64
  end type modflow6_linear_boundary_term_t

  public :: compose_modflow6_linear_boundary_term
  public :: evaluate_modflow6_linear_boundary_flux
  public :: evaluate_modflow6_linear_boundary_flux_density
  public :: reanchor_modflow6_linear_boundary_term
  public :: relinearize_modflow6_linear_boundary_term

contains

  subroutine compose_modflow6_linear_boundary_term(cell, cell_area_m2, term, status)
    type(modflow6_multiswap_cell_response_t), intent(in) :: cell
    real(real64), intent(in) :: cell_area_m2
    type(modflow6_linear_boundary_term_t), intent(out) :: term
    integer, intent(out) :: status

    real(real64) :: area_day_factor
    real(real64) :: reference_volume_flux
    real(real64) :: hcof
    real(real64) :: rhs

    term = modflow6_linear_boundary_term_t()

    status = MODFLOW6_LINEAR_BACKEND_INVALID_CELL_RESPONSE
    if (.not. valid_cell_response(cell)) then
      term%status = status
      return
    end if

    status = MODFLOW6_LINEAR_BACKEND_INVALID_AREA
    if (.not. ieee_is_finite(cell_area_m2)) then
      term%status = status
      return
    end if
    if (cell_area_m2 <= 0.0_real64) then
      term%status = status
      return
    end if

    status = MODFLOW6_LINEAR_BACKEND_NONFINITE_SOURCE
    if (.not. ieee_is_finite(cell%reference_head_m) .or. &
        .not. ieee_is_finite(cell%q_u_at_reference_m_per_s) .or. &
        .not. ieee_is_finite(cell%dq_u_dh_per_s)) then
      term%status = status
      return
    end if

    area_day_factor = cell_area_m2 * DAY_TO_S
    reference_volume_flux = area_day_factor * cell%q_u_at_reference_m_per_s
    hcof = area_day_factor * cell%dq_u_dh_per_s
    rhs = hcof * cell%reference_head_m - reference_volume_flux

    status = MODFLOW6_LINEAR_BACKEND_NONFINITE_COEFFICIENT
    if (.not. ieee_is_finite(area_day_factor) .or. &
        .not. ieee_is_finite(reference_volume_flux) .or. &
        .not. ieee_is_finite(hcof) .or. .not. ieee_is_finite(rhs)) then
      term%status = status
      return
    end if

    term%groundwater_cell_id = cell%groundwater_cell_id
    term%window = cell%window
    term%coupling_id = cell%coupling_id
    term%groundwater_service_id = cell%groundwater_service_id
    term%groundwater_lineage_id = cell%groundwater_lineage_id
    term%groundwater_origin_revision = cell%groundwater_origin_revision
    term%cell_area_m2 = cell_area_m2
    term%reference_head_m = cell%reference_head_m
    term%q_u_at_reference_m_per_s = cell%q_u_at_reference_m_per_s
    term%dq_u_dh_per_s = cell%dq_u_dh_per_s
    term%reference_volume_flux_m3_per_day = reference_volume_flux
    term%hcof_m2_per_day = hcof
    term%rhs_m3_per_day = rhs
    term%status = MODFLOW6_LINEAR_BACKEND_OK
    term%valid = .true.
    status = MODFLOW6_LINEAR_BACKEND_OK
  end subroutine compose_modflow6_linear_boundary_term

  subroutine evaluate_modflow6_linear_boundary_flux(term, hydraulic_head_m, volume_flux_m3_per_day, status)
    type(modflow6_linear_boundary_term_t), intent(in) :: term
    real(real64), intent(in) :: hydraulic_head_m
    real(real64), intent(out) :: volume_flux_m3_per_day
    integer, intent(out) :: status

    volume_flux_m3_per_day = 0.0_real64
    status = MODFLOW6_LINEAR_BACKEND_INVALID_EVALUATION

    if (.not. term%valid .or. term%status /= MODFLOW6_LINEAR_BACKEND_OK) return
    if (.not. ieee_is_finite(hydraulic_head_m)) return
    if (.not. ieee_is_finite(term%hcof_m2_per_day) .or. .not. ieee_is_finite(term%rhs_m3_per_day)) return

    volume_flux_m3_per_day = term%hcof_m2_per_day * hydraulic_head_m - term%rhs_m3_per_day
    if (.not. ieee_is_finite(volume_flux_m3_per_day)) then
      volume_flux_m3_per_day = 0.0_real64
      return
    end if

    status = MODFLOW6_LINEAR_BACKEND_OK
  end subroutine evaluate_modflow6_linear_boundary_flux

  subroutine evaluate_modflow6_linear_boundary_flux_density(term, hydraulic_head_m, flux_m_per_s, status)
    type(modflow6_linear_boundary_term_t), intent(in) :: term
    real(real64), intent(in) :: hydraulic_head_m
    real(real64), intent(out) :: flux_m_per_s
    integer, intent(out) :: status

    real(real64) :: volume_flux_m3_per_day
    real(real64) :: area_day_factor

    flux_m_per_s = 0.0_real64
    call evaluate_modflow6_linear_boundary_flux(term, hydraulic_head_m, volume_flux_m3_per_day, status)
    if (status /= MODFLOW6_LINEAR_BACKEND_OK) return

    status = MODFLOW6_LINEAR_BACKEND_INVALID_EVALUATION
    if (.not. ieee_is_finite(term%cell_area_m2) .or. term%cell_area_m2 <= 0.0_real64) return
    area_day_factor = term%cell_area_m2 * DAY_TO_S
    if (.not. ieee_is_finite(area_day_factor) .or. area_day_factor <= 0.0_real64) return

    flux_m_per_s = volume_flux_m3_per_day / area_day_factor
    if (.not. ieee_is_finite(flux_m_per_s)) then
      flux_m_per_s = 0.0_real64
      return
    end if
    status = MODFLOW6_LINEAR_BACKEND_OK
  end subroutine evaluate_modflow6_linear_boundary_flux_density

  subroutine reanchor_modflow6_linear_boundary_term(term, hydraulic_head_m, q_u_m_per_s, reanchored, status)
    type(modflow6_linear_boundary_term_t), intent(in) :: term
    real(real64), intent(in) :: hydraulic_head_m
    real(real64), intent(in) :: q_u_m_per_s
    type(modflow6_linear_boundary_term_t), intent(out) :: reanchored
    integer, intent(out) :: status

    real(real64) :: area_day_factor
    real(real64) :: reference_volume_flux
    real(real64) :: rhs

    reanchored = modflow6_linear_boundary_term_t()
    status = MODFLOW6_LINEAR_BACKEND_INVALID_EVALUATION
    if (.not. term%valid .or. term%status /= MODFLOW6_LINEAR_BACKEND_OK) return
    if (.not. ieee_is_finite(term%cell_area_m2) .or. term%cell_area_m2 <= 0.0_real64) return
    if (.not. ieee_is_finite(term%hcof_m2_per_day)) return
    if (.not. ieee_is_finite(hydraulic_head_m) .or. .not. ieee_is_finite(q_u_m_per_s)) return

    area_day_factor = term%cell_area_m2 * DAY_TO_S
    reference_volume_flux = area_day_factor * q_u_m_per_s
    rhs = term%hcof_m2_per_day * hydraulic_head_m - reference_volume_flux
    if (.not. ieee_is_finite(area_day_factor) .or. .not. ieee_is_finite(reference_volume_flux) .or. &
        .not. ieee_is_finite(rhs)) return

    reanchored = term
    reanchored%reference_head_m = hydraulic_head_m
    reanchored%q_u_at_reference_m_per_s = q_u_m_per_s
    reanchored%reference_volume_flux_m3_per_day = reference_volume_flux
    reanchored%rhs_m3_per_day = rhs
    reanchored%status = MODFLOW6_LINEAR_BACKEND_OK
    reanchored%valid = .true.
    status = MODFLOW6_LINEAR_BACKEND_OK
  end subroutine reanchor_modflow6_linear_boundary_term

  subroutine relinearize_modflow6_linear_boundary_term(term, hydraulic_head_m, q_u_m_per_s, &
       dq_u_dh_per_s, relinearized, status)
    type(modflow6_linear_boundary_term_t), intent(in) :: term
    real(real64), intent(in) :: hydraulic_head_m
    real(real64), intent(in) :: q_u_m_per_s
    real(real64), intent(in) :: dq_u_dh_per_s
    type(modflow6_linear_boundary_term_t), intent(out) :: relinearized
    integer, intent(out) :: status

    real(real64) :: area_day_factor
    real(real64) :: reference_volume_flux
    real(real64) :: hcof
    real(real64) :: rhs

    relinearized = modflow6_linear_boundary_term_t()
    status = MODFLOW6_LINEAR_BACKEND_INVALID_EVALUATION
    if (.not. term%valid .or. term%status /= MODFLOW6_LINEAR_BACKEND_OK) return
    if (.not. ieee_is_finite(term%cell_area_m2) .or. term%cell_area_m2 <= 0.0_real64) return
    if (.not. ieee_is_finite(hydraulic_head_m) .or. .not. ieee_is_finite(q_u_m_per_s) .or. &
        .not. ieee_is_finite(dq_u_dh_per_s)) return

    area_day_factor = term%cell_area_m2 * DAY_TO_S
    reference_volume_flux = area_day_factor * q_u_m_per_s
    hcof = area_day_factor * dq_u_dh_per_s
    rhs = hcof * hydraulic_head_m - reference_volume_flux
    if (.not. ieee_is_finite(area_day_factor) .or. .not. ieee_is_finite(reference_volume_flux) .or. &
        .not. ieee_is_finite(hcof) .or. .not. ieee_is_finite(rhs)) return

    relinearized = term
    relinearized%reference_head_m = hydraulic_head_m
    relinearized%q_u_at_reference_m_per_s = q_u_m_per_s
    relinearized%dq_u_dh_per_s = dq_u_dh_per_s
    relinearized%reference_volume_flux_m3_per_day = reference_volume_flux
    relinearized%hcof_m2_per_day = hcof
    relinearized%rhs_m3_per_day = rhs
    relinearized%status = MODFLOW6_LINEAR_BACKEND_OK
    relinearized%valid = .true.
    status = MODFLOW6_LINEAR_BACKEND_OK
  end subroutine relinearize_modflow6_linear_boundary_term

  pure logical function valid_cell_response(cell) result(valid)
    type(modflow6_multiswap_cell_response_t), intent(in) :: cell

    valid = .false.
    if (.not. cell%valid .or. cell%status /= MODFLOW6_MULTI_CELL_OK) return
    if (.not. cell%window%valid()) return
    if (cell%groundwater_cell_id <= 0_int64) return
    if (cell%coupling_id <= 0_int64) return
    if (cell%groundwater_service_id <= 0_int64) return
    if (cell%groundwater_lineage_id <= 0_int64 .or. cell%groundwater_origin_revision < 0_int64) return
    if (cell%tile_count <= 0) return
    if (.not. ieee_is_finite(cell%fraction_sum)) return
    if (abs(cell%fraction_sum - 1.0_real64) > &
        64.0_real64 * epsilon(1.0_real64) * max(1.0_real64, abs(cell%fraction_sum))) return
    valid = .true.
  end function valid_cell_response

end module mod_modflow6_linear_response_backend

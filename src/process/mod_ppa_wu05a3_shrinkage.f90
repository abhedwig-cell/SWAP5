module mod_ppa_wu05a3_shrinkage
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: PPA_WU05A3_SHRINKAGE_OK = 0
  integer, parameter, public :: PPA_WU05A3_SHRINKAGE_INVALID_INPUT = 1
  public :: ppa_wu05a3_relative_shrinkage

contains

  pure subroutine ppa_wu05a3_relative_shrinkage(soil_kind, input_kind, theta_s, theta, parameters, &
       shrinkage, status)
    integer, intent(in) :: soil_kind, input_kind
    real(real64), intent(in) :: theta_s, theta, parameters(5)
    real(real64), intent(out) :: shrinkage
    integer, intent(out) :: status
    real(real64) :: solid_relative, moisture_ratio, moisture_at_reference, moisture_at_saturation
    real(real64) :: moisture_point, moisture_relative, void_ratio, void_at_zero, void_at_saturation
    real(real64) :: void_relative, shape_factor, alpha, beta, gamma, mr1, mr2, vr1, vr2

    shrinkage = 0.0_real64
    status = PPA_WU05A3_SHRINKAGE_INVALID_INPUT
    if (.not. all(ieee_is_finite(parameters)) .or. .not. ieee_is_finite(theta_s) .or. &
        .not. ieee_is_finite(theta)) return

    ! B1.11 macropore.f90 SHRINK (1484-1577) defines clay and peat only.
    ! SwSoilShr=0 leaves VoidR undefined in that routine and is deliberately rejected.
    if (soil_kind < 1 .or. soil_kind > 2 .or. input_kind < 1 .or. input_kind > 3) return
    if (theta_s <= 0.0_real64 .or. theta_s >= 1.0_real64 .or. theta < 0.0_real64 .or. theta > theta_s) return
    solid_relative = 1.0_real64 - theta_s
    moisture_ratio = theta / solid_relative

    if (soil_kind == 1) then
      alpha = parameters(1)
      beta = parameters(2)
      gamma = parameters(3)
      moisture_at_reference = parameters(4)
      if (alpha < 0.0_real64 .or. beta < 0.0_real64 .or. moisture_at_reference <= 0.0_real64) return
      if (moisture_ratio > moisture_at_reference) then
        void_ratio = moisture_ratio
      else
        void_ratio = max(alpha * exp(-beta * moisture_ratio) + gamma * moisture_ratio, alpha)
      end if
    else
      void_at_zero = parameters(1)
      moisture_at_reference = parameters(2)
      moisture_at_saturation = theta_s / solid_relative
      void_at_saturation = moisture_at_saturation
      if (moisture_at_reference <= 0.0_real64 .or. moisture_at_reference >= moisture_at_saturation) return

      if (input_kind /= 3) then
        alpha = parameters(3)
        beta = parameters(4)
        if (alpha <= 0.0_real64 .or. beta <= 0.0_real64) return
        if (abs(alpha - beta) <= 1.0e-12_real64 * max(1.0_real64, alpha, beta)) return
        moisture_point = alpha / beta
        moisture_relative = moisture_ratio / moisture_at_reference
        void_relative = void_at_zero + (void_at_saturation - void_at_zero) * &
             moisture_ratio / moisture_at_saturation
        shape_factor = 1.0_real64 + parameters(5) * &
             ((moisture_relative**alpha) * (exp(-beta * moisture_relative) - exp(-beta))) / &
             ((moisture_point**alpha) * (exp(-alpha) - exp(-beta)))
        if (moisture_ratio < moisture_at_reference) then
          void_ratio = void_relative * shape_factor
        else
          void_ratio = void_relative
        end if
      else
        moisture_point = parameters(3)
        if (moisture_point <= 0.0_real64 .or. moisture_point >= moisture_at_reference) return
        if (moisture_ratio > moisture_at_reference) then
          mr1 = moisture_at_saturation
          mr2 = moisture_at_reference
          vr1 = void_at_saturation
          vr2 = void_at_zero + (void_at_saturation - void_at_zero) * &
               moisture_at_reference / moisture_at_saturation
        else if (moisture_ratio > moisture_point) then
          mr1 = moisture_at_reference
          mr2 = moisture_point
          vr1 = void_at_zero + (void_at_saturation - void_at_zero) * &
               moisture_at_reference / moisture_at_saturation
          vr2 = parameters(4)
        else
          mr1 = moisture_point
          mr2 = 0.0_real64
          vr1 = parameters(4)
          vr2 = void_at_zero
        end if
        void_ratio = vr2 + (vr1 - vr2) * (moisture_ratio - mr2) / (mr1 - mr2)
      end if
    end if

    shrinkage = theta_s - void_ratio * solid_relative
    if (.not. ieee_is_finite(shrinkage)) then
      shrinkage = 0.0_real64
      return
    end if
    status = PPA_WU05A3_SHRINKAGE_OK
  end subroutine ppa_wu05a3_relative_shrinkage

end module mod_ppa_wu05a3_shrinkage

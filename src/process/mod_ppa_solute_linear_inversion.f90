module mod_ppa_solute_linear_inversion
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private
  integer, parameter, public :: PPA_SOLUTE_LINEAR_INVERSION_OK = 0
  integer, parameter, public :: PPA_SOLUTE_LINEAR_INVERSION_INVALID_INPUT = 1
  integer, parameter, public :: PPA_SOLUTE_LINEAR_INVERSION_UNSUPPORTED = 2
  public :: ppa_solute_linear_storage_to_concentration
contains
  pure subroutine ppa_solute_linear_storage_to_concentration(storage, water_content, linear_adsorption, &
       layer_thickness, freundlich_exponent, concentration, updated_storage, roundoff_mass, status)
    real(real64), intent(in) :: storage, water_content, linear_adsorption, layer_thickness, freundlich_exponent
    real(real64), intent(out) :: concentration, updated_storage, roundoff_mass
    integer, intent(out) :: status

    concentration = 0.0_real64
    updated_storage = 0.0_real64
    roundoff_mass = 0.0_real64
    status = PPA_SOLUTE_LINEAR_INVERSION_INVALID_INPUT
    if (.not. all(ieee_is_finite([storage,water_content,linear_adsorption,layer_thickness,freundlich_exponent]))) return
    if (water_content < 0.0_real64 .or. linear_adsorption < 0.0_real64 .or. layer_thickness <= 0.0_real64) return
    ! Source: B1.11 solute.f90 task 2 cml inversion's linear Freundlich branch and vsmall roundoff branch.
    if (storage < 1.0e-15_real64) then
      if (abs(storage) > 1.0_real64 .and. layer_thickness > 1.0_real64) then
        if (layer_thickness > huge(1.0_real64)/abs(storage)) return
      end if
      roundoff_mass = storage*layer_thickness
      updated_storage = 0.0_real64
    else
      if (abs(freundlich_exponent-1.0_real64) >= 0.001_real64) then
        status = PPA_SOLUTE_LINEAR_INVERSION_UNSUPPORTED
        return
      end if
      if (water_content > huge(1.0_real64)-linear_adsorption) return
      if (water_content+linear_adsorption <= 0.0_real64) return
      if (water_content+linear_adsorption < 1.0_real64) then
        if (storage > huge(1.0_real64)*(water_content+linear_adsorption)) return
      end if
      concentration = storage/(water_content+linear_adsorption)
      updated_storage = storage
    end if
    if (.not. all(ieee_is_finite([concentration,updated_storage,roundoff_mass]))) then
      concentration = 0.0_real64
      updated_storage = 0.0_real64
      roundoff_mass = 0.0_real64
      return
    end if
    status = PPA_SOLUTE_LINEAR_INVERSION_OK
  end subroutine ppa_solute_linear_storage_to_concentration
end module mod_ppa_solute_linear_inversion

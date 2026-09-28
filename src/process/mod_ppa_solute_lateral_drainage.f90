module mod_ppa_solute_lateral_drainage
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private
  integer, parameter, public :: PPA_SOLUTE_LATERAL_DRAINAGE_OK=0
  integer, parameter, public :: PPA_SOLUTE_LATERAL_DRAINAGE_INVALID_INPUT=1
  public :: ppa_solute_lateral_drainage
contains
  pure subroutine ppa_solute_lateral_drainage(level_flux,matrix_concentration,aquifer_concentration, &
       cell_thickness,substep_days,rate_per_depth,removed_amount,status)
    real(real64),intent(in)::level_flux(:),matrix_concentration,aquifer_concentration
    real(real64),intent(in)::cell_thickness,substep_days
    real(real64),intent(out)::rate_per_depth,removed_amount
    integer,intent(out)::status
    real(real64)::concentration
    integer::level

    rate_per_depth=0.0_real64
    removed_amount=0.0_real64
    status=PPA_SOLUTE_LATERAL_DRAINAGE_INVALID_INPUT
    if(.not.all(ieee_is_finite(level_flux)).or. &
         .not.all(ieee_is_finite([matrix_concentration,aquifer_concentration,cell_thickness,substep_days])))return
    if(any(abs(level_flux)>1.0e6_real64).or.matrix_concentration<0.0_real64.or. &
         matrix_concentration>1.0e12_real64.or.aquifer_concentration<0.0_real64.or. &
         aquifer_concentration>1.0e12_real64.or.cell_thickness<1.0e-12_real64.or. &
         cell_thickness>1.0e3_real64.or.substep_days<=0.0_real64.or.substep_days>1.0e4_real64)return

    ! Source: B1.11 solute.f90 task 2 lateral drainage loop, preserving level order.
    do level=1,size(level_flux)
      if(level_flux(level)>0.0_real64)then
        concentration=matrix_concentration
      else
        concentration=aquifer_concentration
      end if
      rate_per_depth=rate_per_depth+level_flux(level)*concentration/cell_thickness
    end do
    removed_amount=rate_per_depth*cell_thickness*substep_days
    if(.not.all(ieee_is_finite([rate_per_depth,removed_amount])))then
      rate_per_depth=0.0_real64
      removed_amount=0.0_real64
      return
    end if
    status=PPA_SOLUTE_LATERAL_DRAINAGE_OK
  end subroutine ppa_solute_lateral_drainage
end module mod_ppa_solute_lateral_drainage

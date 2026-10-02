module mod_bartholomeus_profile_response
  use iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_bartholomeus_response, only: BartholomeusResponseInput, bartholomeus_respiration_factor, bartholomeus_rwu_factor
  use mod_bartholomeus_macro, only: bartholomeus_macro_concentration
  implicit none
  private
  public :: bartholomeus_profile_factors

contains

  subroutine bartholomeus_profile_factors(input, atmospheric_ctop, factors, ok)
    type(BartholomeusResponseInput), intent(in) :: input(:)
    real(real64), intent(in) :: atmospheric_ctop
    real(real64), allocatable, intent(out) :: factors(:)
    logical, intent(out) :: ok
    type(BartholomeusResponseInput) :: p
    real(real64) :: ctop, rf, cmacro
    logical :: node_ok
    integer :: i

    ok=.false.
    if (.not.ieee_is_finite(atmospheric_ctop)) return
    if (atmospheric_ctop < 0.0_real64) return
    allocate(factors(size(input)))
    factors=1.0_real64
    ctop=atmospheric_ctop

    do i=1,size(input)
      p=input(i)
      p%macro%ctop=ctop
      ! Source-bound early exit: saturated node consumes the vertical oxygen boundary.
      if(p%micro%gas_filled_porosity<1.e-4_real64) then
        factors(i)=0.0_real64
        ctop=0.0_real64
        cycle
      end if
      call bartholomeus_respiration_factor(p,rf,node_ok)
      if (.not.node_ok) return
      factors(i)=bartholomeus_rwu_factor(rf,p%max_resp_factor)
      ! The next-node upper boundary must be the MACRO value at the returned factor.
      cmacro = bartholomeus_macro_concentration(p%macro,rf,node_ok)
      if (.not.node_ok) return
      ctop=cmacro
    end do
    ok=.true.
  end subroutine
end module

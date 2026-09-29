! Proposed diagnostic reconstruction, not an admitted reference correction.
module mod_ppa_wu05a3_conservative_flux
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private
  integer,parameter,public :: FLUX_OK=0, FLUX_INVALID=1, FLUX_BOUNDARY_MISMATCH=2
  public :: reconstruct_conservative_flux
contains
  subroutine reconstruct_conservative_flux(dt,water_old,water_new,exchange,drainage, &
      top_flux,bottom_flux,tolerance,faces,bottom_residual,status)
    real(real64),intent(in) :: dt,water_old(:,:),water_new(:,:),exchange(:,:),drainage(:,:)
    real(real64),intent(in) :: top_flux(:),bottom_flux(:),tolerance
    real(real64),intent(out) :: faces(:,:),bottom_residual(:)
    integer,intent(out) :: status
    integer :: nd,n,ic
    status=FLUX_INVALID; faces=0.0_real64; bottom_residual=0.0_real64
    nd=size(water_old,1); n=size(water_old,2)
    if(nd<1 .or. n<1) return
    if(any(shape(water_new)/=[nd,n]) .or. any(shape(exchange)/=[nd,n]) .or. &
        any(shape(drainage)/=[nd,n]) .or. any(shape(faces)/=[nd,n+1]) .or. &
        size(top_flux)/=nd .or. size(bottom_flux)/=nd .or. size(bottom_residual)/=nd) return
    if(.not.ieee_is_finite(dt) .or. .not.ieee_is_finite(tolerance)) return
    if(dt<=0.0_real64 .or. tolerance<0.0_real64) return
    if(.not.all(ieee_is_finite(water_old)) .or. .not.all(ieee_is_finite(water_new)) .or. &
        .not.all(ieee_is_finite(exchange)) .or. .not.all(ieee_is_finite(drainage)) .or. &
        .not.all(ieee_is_finite(top_flux)) .or. .not.all(ieee_is_finite(bottom_flux))) return
    if(any(water_old<0.0_real64) .or. any(water_new<0.0_real64) .or. any(drainage<0.0_real64)) return
    faces(:,1)=top_flux
    do ic=1,n
      faces(:,ic+1)=faces(:,ic)-exchange(:,ic)-drainage(:,ic)-(water_new(:,ic)-water_old(:,ic))/dt
    end do
    bottom_residual=faces(:,n+1)-bottom_flux
    if(.not.all(ieee_is_finite(faces)) .or. .not.all(ieee_is_finite(bottom_residual))) then
      faces=0.0_real64; bottom_residual=0.0_real64
      return
    end if
    status=FLUX_BOUNDARY_MISMATCH
    if(all(abs(bottom_residual)<=tolerance)) status=FLUX_OK
  end subroutine
end module

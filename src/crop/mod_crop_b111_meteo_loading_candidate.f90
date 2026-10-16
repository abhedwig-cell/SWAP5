module mod_crop_b111_meteo_loading_candidate
  use iso_fortran_env, only: real64
  use ieee_arithmetic, only: ieee_is_finite
  implicit none
  private
  integer, parameter, public :: CROP_METEO_LOAD_OK=0, CROP_METEO_LOAD_INVALID=1
  public :: crop_b111_meteo_loading_candidate
contains
  ! B1.11 SWAP-006 corrected MOD_meteo.f90 lines 260-270.
  ! Pure decision candidate. Does not access or certify a meteorological owner.
  subroutine crop_b111_meteo_loading_candidate(tstart,tend,cropstart,cropend,croptype,ifnd,load,status)
    real(real64),intent(in):: tstart,tend,cropstart(:),cropend(:)
    integer,intent(in):: croptype(:),ifnd
    logical,intent(out):: load
    integer,intent(out):: status
    integer:: i
    load=.false.;status=CROP_METEO_LOAD_INVALID
    if(.not.ieee_is_finite(tstart).or..not.ieee_is_finite(tend)) return
    if(tend<tstart.or.ifnd<0) return
    if(ifnd>size(cropstart).or.ifnd>size(cropend).or.ifnd>size(croptype)) return
    if(.not.all(ieee_is_finite(cropstart(:ifnd)))) return
    if(.not.all(ieee_is_finite(cropend(:ifnd)))) return
    ! Validate the active calendar, not unused allocation slots.
    if(any(cropend(:ifnd)<cropstart(:ifnd))) return
    do i=2,ifnd
      if(cropstart(i)<cropstart(i-1)) return
    end do
    do i=1,ifnd
      if(tend-cropstart(i)<=0.0_real64) exit
      if(cropstart(i)<1.0_real64) exit
      if(tend+0.1_real64>cropstart(i).and.tstart-0.1_real64<cropend(i)) then
        if(croptype(i)==2) load=.true.
      end if
    end do
    status=CROP_METEO_LOAD_OK
  end subroutine
end module

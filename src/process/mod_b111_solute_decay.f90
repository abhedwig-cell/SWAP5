module mod_b111_solute_decay
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private
  integer,parameter,public::B111_DECAY_OK=0,B111_DECAY_INVALID=1
  type,public::b111_decay_result_t
    integer::status=B111_DECAY_OK
    real(real64)::temperature_factor=0d0
    real(real64)::moisture_factor=0d0
    real(real64)::decay_rate=0d0
    real(real64)::transformation_density_rate=0d0
  end type
  public::evaluate_b111_solute_decay
contains
  pure subroutine evaluate_b111_solute_decay(temperature_active,tsoil,gampar,theta,rtheta,bexp, &
       decpot,fdepth,total_density,result)
    logical,intent(in)::temperature_active
    real(real64),intent(in)::tsoil,gampar,theta,rtheta,bexp,decpot,fdepth,total_density
    type(b111_decay_result_t),intent(out)::result
    result=b111_decay_result_t()
    if(.not.all(ieee_is_finite([tsoil,gampar,theta,rtheta,bexp,decpot,fdepth,total_density])))then
      result%status=B111_DECAY_INVALID;return
    end if
    if(theta<0d0.or.rtheta<=0d0.or.bexp<0d0.or.decpot<0d0.or.fdepth<0d0.or.total_density<0d0)then
      result%status=B111_DECAY_INVALID;return
    end if
    if(temperature_active)then
      if(tsoil<35d0)then
        result%temperature_factor=exp(gampar*(tsoil-20d0))
      else
        result%temperature_factor=exp(gampar*15d0)
      end if
    else
      result%temperature_factor=0d0
    end if
    result%moisture_factor=min(1d0,(theta/rtheta)**bexp)
    result%decay_rate=decpot*fdepth*result%temperature_factor*result%moisture_factor
    result%transformation_density_rate=result%decay_rate*total_density
    if(.not.all(ieee_is_finite([result%temperature_factor,result%moisture_factor, &
         result%decay_rate,result%transformation_density_rate])))then
      result=b111_decay_result_t();result%status=B111_DECAY_INVALID;return
    end if
  end subroutine
end module

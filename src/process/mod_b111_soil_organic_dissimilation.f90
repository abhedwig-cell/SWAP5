module mod_b111_soil_organic_dissimilation
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_b111_soil_organic_turnover, only: b111_organic_turnover_parameters_t, b111_organic_turnover_result_t, &
       B111_ORG_TURNOVER_OK,b111_decay_fractions,b111_single_zero_response, &
       b111_resonant_response,b111_requires_resonant_response
  implicit none
  private

  integer,parameter,public::B111_ORG_DISS_OK=0
  integer,parameter,public::B111_ORG_DISS_INVALID=1
  integer,parameter,public::B111_ORG_DISS_SINGULAR=2

  type,public::b111_organic_dissimilation_result_t
    integer::status=B111_ORG_DISS_INVALID
    real(real64)::biomass_average_kg_m3=0.0_real64
    real(real64)::humus_average_kg_m3=0.0_real64
    real(real64)::carbon_dissimilation_kg_m2=0.0_real64
  end type

  public::evaluate_b111_organic_dissimilation

contains

  subroutine evaluate_b111_organic_dissimilation(fom0,biomass0,humus0,depth_m,dt,p,turnover, &
       cfrac_fom,cfrac_biomass,cfrac_humus,result)
    real(real64),intent(in)::fom0(:),biomass0,humus0,depth_m,dt
    type(b111_organic_turnover_parameters_t),intent(in)::p
    type(b111_organic_turnover_result_t),intent(in)::turnover
    real(real64),intent(in)::cfrac_fom(:),cfrac_biomass,cfrac_humus
    type(b111_organic_dissimilation_result_t),intent(out)::result
    real(real64)::p1,p2,p3,p4,denom
    real(real64)::fom2bio,fom2hum,rhs_bio,rhs_hum,help,loss,average
    integer::code
    integer::fn,n
    real(real64),allocatable::endpoint(:),mean_pool(:)

    result=b111_organic_dissimilation_result_t()
    n=size(fom0)
    if(n<1.or.turnover%status/=B111_ORG_TURNOVER_OK)return
    if(.not.allocated(turnover%fom_kg_m3))return
    if(size(turnover%fom_kg_m3)/=n)return
    if(.not.allocated(p%ratecon_fom).or..not.allocated(p%asfa_fom_bio).or..not.allocated(p%asfa_fom_hum))return
    if(size(p%ratecon_fom)/=n.or.size(p%asfa_fom_bio)/=n.or.size(p%asfa_fom_hum)/=n.or.size(cfrac_fom)/=n)return
    if(.not.all(ieee_is_finite(fom0)).or..not.all(ieee_is_finite(cfrac_fom)).or. &
       .not.all(ieee_is_finite([biomass0,humus0,depth_m,dt,cfrac_biomass,cfrac_humus])))return
    if(depth_m<=0.0_real64.or.dt<=0.0_real64.or.any(fom0<0.0_real64).or.biomass0<0.0_real64.or.humus0<0.0_real64)return
    if(any(cfrac_fom<0.0_real64).or.cfrac_biomass<0.0_real64.or.cfrac_humus<0.0_real64)return

    if(p%ratecon_bio==0.0_real64.and.p%ratecon_hum==0.0_real64)then
      result%biomass_average_kg_m3=biomass0;result%humus_average_kg_m3=humus0
      do fn=1,n
        call b111_decay_fractions(p%ratecon_fom(fn)*dt,loss,average,code)
        if(code/=B111_ORG_TURNOVER_OK)then
          result=b111_organic_dissimilation_result_t();return
        end if
        result%biomass_average_kg_m3=result%biomass_average_kg_m3+p%asfa_fom_bio(fn)*fom0(fn)*average
        result%humus_average_kg_m3=result%humus_average_kg_m3+p%asfa_fom_hum(fn)*fom0(fn)*average
        result%carbon_dissimilation_kg_m2=result%carbon_dissimilation_kg_m2+cfrac_fom(fn)*fom0(fn)*loss* &
          depth_m*(1.0_real64-p%asfa_fom_bio(fn)-p%asfa_fom_hum(fn))
      end do
      if(.not.all(ieee_is_finite([result%biomass_average_kg_m3,result%humus_average_kg_m3, &
          result%carbon_dissimilation_kg_m2])))then
        result=b111_organic_dissimilation_result_t();return
      end if
      if(min(result%biomass_average_kg_m3,result%humus_average_kg_m3,result%carbon_dissimilation_kg_m2)<0d0)then
        result=b111_organic_dissimilation_result_t();return
      end if
      result%status=B111_ORG_DISS_OK;return
    end if

    if(p%ratecon_bio==0.0_real64.or.p%ratecon_hum==0.0_real64.or.b111_requires_resonant_response(p))then
      if(p%ratecon_bio==0.0_real64.or.p%ratecon_hum==0.0_real64)then
        call b111_single_zero_response(fom0,biomass0,humus0,dt,p,endpoint,mean_pool,code)
      else
        call b111_resonant_response(fom0,biomass0,humus0,dt,p,endpoint,mean_pool,code)
      end if
      if(code/=B111_ORG_TURNOVER_OK)return
      result%biomass_average_kg_m3=mean_pool(n+1);result%humus_average_kg_m3=mean_pool(n+2)
      do fn=1,n
        call b111_decay_fractions(p%ratecon_fom(fn)*dt,loss,average,code)
        if(code/=B111_ORG_TURNOVER_OK)return
        result%carbon_dissimilation_kg_m2=result%carbon_dissimilation_kg_m2+cfrac_fom(fn)*fom0(fn)*loss* &
          depth_m*(1d0-p%asfa_fom_bio(fn)-p%asfa_fom_hum(fn))
      end do
      result%carbon_dissimilation_kg_m2=result%carbon_dissimilation_kg_m2+dt*depth_m* &
        (1d0-p%asfa_bio-p%asfa_hum)*(cfrac_biomass*p%ratecon_bio*mean_pool(n+1)+ &
        cfrac_humus*p%ratecon_hum*mean_pool(n+2))
      if(.not.ieee_is_finite(result%carbon_dissimilation_kg_m2).or.result%carbon_dissimilation_kg_m2<0d0)then
        result=b111_organic_dissimilation_result_t();return
      end if
      result%status=B111_ORG_DISS_OK;return
    end if

    p1=(1.0_real64-p%asfa_bio)*p%ratecon_bio
    p2=p%asfa_bio*p%ratecon_hum
    p3=p%asfa_hum*p%ratecon_bio
    p4=(1.0_real64-p%asfa_hum)*p%ratecon_hum
    denom=p2*p3-p1*p4
    if(.not.ieee_is_finite(denom).or.abs(denom)<=1024.0_real64*epsilon(1.0_real64))then
      result%status=B111_ORG_DISS_SINGULAR
      return
    end if

    fom2bio=0.0_real64
    fom2hum=0.0_real64
    do fn=1,n
      help=(fom0(fn)-turnover%fom_kg_m3(fn))*depth_m
      fom2bio=fom2bio+p%asfa_fom_bio(fn)*help
      fom2hum=fom2hum+p%asfa_fom_hum(fn)*help
    end do

    rhs_bio=(turnover%biomass_kg_m3-biomass0)/dt-fom2bio/dt/depth_m
    rhs_hum=(turnover%humus_kg_m3-humus0)/dt-fom2hum/dt/depth_m
    result%biomass_average_kg_m3=(p4*rhs_bio+p2*rhs_hum)/denom
    result%humus_average_kg_m3=(p3*rhs_bio+p1*rhs_hum)/denom
    if(.not.all(ieee_is_finite([result%biomass_average_kg_m3,result%humus_average_kg_m3])))then
      result=b111_organic_dissimilation_result_t()
      return
    end if

    result%carbon_dissimilation_kg_m2=0.0_real64
    do fn=1,n
      result%carbon_dissimilation_kg_m2=result%carbon_dissimilation_kg_m2 + cfrac_fom(fn)* &
           (fom0(fn)-turnover%fom_kg_m3(fn))*depth_m* &
           (1.0_real64-p%asfa_fom_bio(fn)-p%asfa_fom_hum(fn))
    end do
    result%carbon_dissimilation_kg_m2=result%carbon_dissimilation_kg_m2 + cfrac_biomass*dt*depth_m* &
         (1.0_real64-p%asfa_bio-p%asfa_hum)*p%ratecon_bio*result%biomass_average_kg_m3 + &
         cfrac_humus*dt*depth_m*(1.0_real64-p%asfa_bio-p%asfa_hum)*p%ratecon_hum*result%humus_average_kg_m3

    if(.not.ieee_is_finite(result%carbon_dissimilation_kg_m2).or.result%carbon_dissimilation_kg_m2<0.0_real64)then
      result=b111_organic_dissimilation_result_t()
      return
    end if
    result%status=B111_ORG_DISS_OK
  end subroutine
end module

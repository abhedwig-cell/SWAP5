module mod_b111_soil_organic_turnover
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer,parameter,public::B111_ORG_TURNOVER_OK=0
  integer,parameter,public::B111_ORG_TURNOVER_INVALID=1
  integer,parameter,public::B111_ORG_TURNOVER_SINGULAR=2

  type,public::b111_organic_turnover_parameters_t
    real(real64),allocatable::ratecon_fom(:)
    real(real64),allocatable::asfa_fom_bio(:)
    real(real64),allocatable::asfa_fom_hum(:)
    real(real64)::ratecon_bio=0.0_real64
    real(real64)::ratecon_hum=0.0_real64
    real(real64)::asfa_bio=0.0_real64
    real(real64)::asfa_hum=0.0_real64
  end type

  type,public::b111_organic_turnover_result_t
    integer::status=B111_ORG_TURNOVER_INVALID
    real(real64),allocatable::fom_kg_m3(:)
    real(real64)::biomass_kg_m3=0.0_real64
    real(real64)::humus_kg_m3=0.0_real64
  end type

  public::evaluate_b111_organic_turnover

contains

  subroutine evaluate_b111_organic_turnover(fom0,biomass0,humus0,dt,p,result)
    real(real64),intent(in)::fom0(:),biomass0,humus0,dt
    type(b111_organic_turnover_parameters_t),intent(in)::p
    type(b111_organic_turnover_result_t),intent(out)::result
    real(real64)::p1,p2,p3,p4,p5,eval1,eval2
    real(real64)::p111,p112,p121,p122,p211,p212,p221,p222
    real(real64)::d1,d2,e1,e2,ef
    integer::fn,n

    result=b111_organic_turnover_result_t()
    n=size(fom0)
    if(n<1.or..not.allocated(p%ratecon_fom).or..not.allocated(p%asfa_fom_bio).or. &
       .not.allocated(p%asfa_fom_hum))return
    if(size(p%ratecon_fom)/=n.or.size(p%asfa_fom_bio)/=n.or.size(p%asfa_fom_hum)/=n)return
    if(.not.all(ieee_is_finite(fom0)).or..not.all(ieee_is_finite(p%ratecon_fom)).or. &
       .not.all(ieee_is_finite(p%asfa_fom_bio)).or..not.all(ieee_is_finite(p%asfa_fom_hum)).or. &
       .not.all(ieee_is_finite([biomass0,humus0,dt,p%ratecon_bio,p%ratecon_hum,p%asfa_bio,p%asfa_hum])))return
    if(any(fom0<0.0_real64).or.biomass0<0.0_real64.or.humus0<0.0_real64.or.dt<=0.0_real64)return
    if(any(p%ratecon_fom<0.0_real64).or.p%ratecon_bio<0.0_real64.or.p%ratecon_hum<0.0_real64)return
    if(any(p%asfa_fom_bio<0.0_real64).or.any(p%asfa_fom_hum<0.0_real64).or. &
       any(p%asfa_fom_bio+p%asfa_fom_hum>1.0_real64))return
    if(p%asfa_bio<0.0_real64.or.p%asfa_hum<0.0_real64.or.p%asfa_bio+p%asfa_hum>1.0_real64)return

    p1=(1.0_real64-p%asfa_bio)*p%ratecon_bio
    p2=p%asfa_bio*p%ratecon_hum
    p3=p%asfa_hum*p%ratecon_bio
    p4=(1.0_real64-p%asfa_hum)*p%ratecon_hum
    p5=sqrt((p1-p4)**2+4.0_real64*p2*p3)
    if(.not.ieee_is_finite(p5).or.p5<=1024.0_real64*epsilon(1.0_real64))then
      result%status=B111_ORG_TURNOVER_SINGULAR
      return
    end if

    eval1=-(p1+p4+p5)/2.0_real64
    eval2=-(p1+p4-p5)/2.0_real64
    p111=-(p4+eval1)/p5
    p112= (p4+eval2)/p5
    p121=-p2/p5
    p122= p2/p5
    p211=-p3/p5
    p212= p3/p5
    p221=-(p1+eval1)/p5
    p222= (p1+eval2)/p5

    allocate(result%fom_kg_m3(n))
    result%fom_kg_m3=fom0*exp(-p%ratecon_fom*dt)
    e1=exp(eval1*dt)
    e2=exp(eval2*dt)
    result%biomass_kg_m3=(p111*e1+p112*e2)*biomass0+(p121*e1+p122*e2)*humus0
    result%humus_kg_m3=(p211*e1+p212*e2)*biomass0+(p221*e1+p222*e2)*humus0

    do fn=1,n
      d1=eval1+p%ratecon_fom(fn)
      d2=eval2+p%ratecon_fom(fn)
      if(abs(d1)<=1024.0_real64*epsilon(1.0_real64).or. &
         abs(d2)<=1024.0_real64*epsilon(1.0_real64))then
        result=b111_organic_turnover_result_t()
        result%status=B111_ORG_TURNOVER_SINGULAR
        return
      end if
      ef=exp(-p%ratecon_fom(fn)*dt)
      result%biomass_kg_m3=result%biomass_kg_m3 + p%asfa_fom_bio(fn)*fom0(fn)*p%ratecon_fom(fn)* &
           (p111/d1*(e1-ef)+p112/d2*(e2-ef))
      result%biomass_kg_m3=result%biomass_kg_m3 + p%asfa_fom_hum(fn)*fom0(fn)*p%ratecon_fom(fn)* &
           (p121/d1*(e1-ef)+p122/d2*(e2-ef))
      result%humus_kg_m3=result%humus_kg_m3 + p%asfa_fom_bio(fn)*fom0(fn)*p%ratecon_fom(fn)* &
           (p211/d1*(e1-ef)+p212/d2*(e2-ef))
      result%humus_kg_m3=result%humus_kg_m3 + p%asfa_fom_hum(fn)*fom0(fn)*p%ratecon_fom(fn)* &
           (p221/d1*(e1-ef)+p222/d2*(e2-ef))
    end do

    if(.not.all(ieee_is_finite(result%fom_kg_m3)).or. &
       .not.all(ieee_is_finite([result%biomass_kg_m3,result%humus_kg_m3])))then
      result=b111_organic_turnover_result_t()
      return
    end if
    if(any(result%fom_kg_m3<0.0_real64).or.result%biomass_kg_m3<0.0_real64.or.result%humus_kg_m3<0.0_real64)then
      result=b111_organic_turnover_result_t()
      return
    end if
    result%status=B111_ORG_TURNOVER_OK
  end subroutine

end module

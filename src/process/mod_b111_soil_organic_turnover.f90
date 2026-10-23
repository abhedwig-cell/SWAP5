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

  public::evaluate_b111_organic_turnover,b111_decay_fractions,b111_single_zero_response

contains

  subroutine evaluate_b111_organic_turnover(fom0,biomass0,humus0,dt,p,result)
    real(real64),intent(in)::fom0(:),biomass0,humus0,dt
    type(b111_organic_turnover_parameters_t),intent(in)::p
    type(b111_organic_turnover_result_t),intent(out)::result
    real(real64)::p1,p2,p3,p4,p5,eval1,eval2
    real(real64)::p111,p112,p121,p122,p211,p212,p221,p222
    real(real64)::d1,d2,e1,e2,ef,loss,average
    integer::code
    integer::fn,n
    real(real64),allocatable::endpoint(:),mean_pool(:)

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

    ! Exact continuous ODE limit when neither receiving pool turns over.
    if(p%ratecon_bio==0.0_real64.and.p%ratecon_hum==0.0_real64)then
      allocate(result%fom_kg_m3(n))
      result%fom_kg_m3=fom0*exp(-p%ratecon_fom*dt)
      result%biomass_kg_m3=biomass0;result%humus_kg_m3=humus0
      do fn=1,n
        call b111_decay_fractions(p%ratecon_fom(fn)*dt,loss,average,code)
        if(code/=B111_ORG_TURNOVER_OK)then
          result=b111_organic_turnover_result_t();return
        end if
        result%biomass_kg_m3=result%biomass_kg_m3+p%asfa_fom_bio(fn)*fom0(fn)*loss
        result%humus_kg_m3=result%humus_kg_m3+p%asfa_fom_hum(fn)*fom0(fn)*loss
      end do
      if(.not.all(ieee_is_finite([result%biomass_kg_m3,result%humus_kg_m3])))then
        result=b111_organic_turnover_result_t();return
      end if
      result%status=B111_ORG_TURNOVER_OK;return
    end if

    if(p%ratecon_bio==0.0_real64.or.p%ratecon_hum==0.0_real64)then
      call b111_single_zero_response(fom0,biomass0,humus0,dt,p,endpoint,mean_pool,code)
      if(code/=B111_ORG_TURNOVER_OK)return
      result%fom_kg_m3=endpoint(:n)
      result%biomass_kg_m3=endpoint(n+1);result%humus_kg_m3=endpoint(n+2)
      result%status=B111_ORG_TURNOVER_OK;return
    end if

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

  ! Exponential and interval mean of the original linear pool equations.
  ! Restricted to exactly one stationary receiving pool. Scaling/squaring
  ! avoids division by zero rates or coincident decay eigenvalues.
  subroutine b111_single_zero_response(fom0,biomass0,humus0,dt,p,endpoint,mean_pool,status)
    real(real64),intent(in)::fom0(:),biomass0,humus0,dt
    type(b111_organic_turnover_parameters_t),intent(in)::p
    real(real64),allocatable,intent(out)::endpoint(:),mean_pool(:)
    integer,intent(out)::status
    real(real64),allocatable::a(:,:),transition(:,:),mean_transition(:,:),term(:,:),initial(:)
    real(real64)::rate,scaled_dt
    integer::n,m,i,j,s,halvings
    status=B111_ORG_TURNOVER_INVALID;n=size(fom0);m=n+2
    if(n<1.or..not.allocated(p%ratecon_fom).or..not.allocated(p%asfa_fom_bio).or. &
        .not.allocated(p%asfa_fom_hum))return
    if(size(p%ratecon_fom)/=n.or.size(p%asfa_fom_bio)/=n.or.size(p%asfa_fom_hum)/=n)return
    if(.not.all(ieee_is_finite(fom0)).or..not.all(ieee_is_finite(p%ratecon_fom)).or. &
        .not.all(ieee_is_finite(p%asfa_fom_bio)).or..not.all(ieee_is_finite(p%asfa_fom_hum)).or. &
        .not.all(ieee_is_finite([biomass0,humus0,dt,p%ratecon_bio,p%ratecon_hum,p%asfa_bio,p%asfa_hum])))return
    if(any(fom0<0d0).or.min(biomass0,humus0)<0d0.or.dt<=0d0)return
    if(any(p%ratecon_fom<0d0).or.min(p%ratecon_bio,p%ratecon_hum)<0d0)return
    if((p%ratecon_bio==0d0).eqv.(p%ratecon_hum==0d0))return
    if(any(p%asfa_fom_bio<0d0).or.any(p%asfa_fom_hum<0d0).or. &
        any(p%asfa_fom_bio+p%asfa_fom_hum>1d0))return
    if(min(p%asfa_bio,p%asfa_hum)<0d0.or.p%asfa_bio+p%asfa_hum>1d0)return
    allocate(a(m,m),transition(m,m),mean_transition(m,m),term(m,m),initial(m))
    rate=max(maxval(p%ratecon_fom),p%ratecon_bio,p%ratecon_hum)
    ! Each column has absolute sum <=2*rate. Form scaled products only.
    scaled_dt=dt;halvings=0
    if(rate>0.0625_real64/huge(rate))then
      do while(scaled_dt>0.0625_real64/rate)
        scaled_dt=scaled_dt*0.5_real64;halvings=halvings+1
      end do
    end if
    a=0d0
    do i=1,n
      a(i,i)=-p%ratecon_fom(i)*scaled_dt
      a(n+1,i)=p%asfa_fom_bio(i)*p%ratecon_fom(i)*scaled_dt
      a(n+2,i)=p%asfa_fom_hum(i)*p%ratecon_fom(i)*scaled_dt
    end do
    a(n+1,n+1)=-(1d0-p%asfa_bio)*p%ratecon_bio*scaled_dt
    a(n+1,n+2)=p%asfa_bio*p%ratecon_hum*scaled_dt
    a(n+2,n+1)=p%asfa_hum*p%ratecon_bio*scaled_dt
    a(n+2,n+2)=-(1d0-p%asfa_hum)*p%ratecon_hum*scaled_dt
    transition=0d0
    do i=1,m
      transition(i,i)=1d0
    end do
    mean_transition=transition;term=transition
    do j=1,32
      term=pool_matrix_product(a,term)/real(j,real64)
      transition=transition+term;mean_transition=mean_transition+term/real(j+1,real64)
    end do
    do s=1,halvings
      mean_transition=0.5_real64*(mean_transition+pool_matrix_product(transition,mean_transition))
      transition=pool_matrix_product(transition,transition)
    end do
    initial=[fom0,biomass0,humus0]
    allocate(endpoint(m),mean_pool(m));endpoint=0d0;mean_pool=0d0
    do j=1,m
      do i=1,m
        endpoint(i)=endpoint(i)+transition(i,j)*initial(j)
        mean_pool(i)=mean_pool(i)+mean_transition(i,j)*initial(j)
      end do
    end do
    if(.not.all(ieee_is_finite(endpoint)).or..not.all(ieee_is_finite(mean_pool)))return
    if(any(endpoint<0d0).or.any(mean_pool<0d0))return
    status=B111_ORG_TURNOVER_OK
  end subroutine

  ! Explicit accumulation order keeps the O0/O2 restart representation exact.
  function pool_matrix_product(a,b)result(c)
    real(real64),intent(in)::a(:,:),b(:,:)
    real(real64)::c(size(a,1),size(b,2))
    integer::i,j,k
    c=0d0
    do j=1,size(b,2)
      do k=1,size(a,2)
        do i=1,size(a,1)
          c(i,j)=c(i,j)+a(i,k)*b(k,j)
        end do
      end do
    end do
  end function

  ! Dimensionless FOM loss and mean accumulated fraction over the interval.
  ! loss=1-exp(-x); average=1-(1-exp(-x))/x, including their exact x=0 limits.
  subroutine b111_decay_fractions(x,loss,average,status)
    real(real64),intent(in)::x
    real(real64),intent(out)::loss,average
    integer,intent(out)::status
    real(real64)::term
    integer::j
    loss=0.0_real64;average=0.0_real64;status=B111_ORG_TURNOVER_INVALID
    if(.not.ieee_is_finite(x))return
    if(x<0.0_real64)return
    if(x<=0.125_real64)then
      term=x
      do j=1,64
        loss=loss+term;average=average+term/real(j+1,real64)
        term=-term*x/real(j+1,real64)
      end do
    else
      loss=1.0_real64-exp(-x);average=1.0_real64-loss/x
    end if
    if(.not.all(ieee_is_finite([loss,average])))return
    if(min(loss,average)<0.0_real64.or.max(loss,average)>1.0_real64)return
    status=B111_ORG_TURNOVER_OK
  end subroutine
end module

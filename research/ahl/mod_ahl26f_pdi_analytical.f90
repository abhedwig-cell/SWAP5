module mod_ahl26f_pdi_analytical
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: constitutive_hydraulics_provider_t
  implicit none
  private
  type,public::pdi_params_t
    integer::model=8
    real(real64)::tr,ts,a1,n1,m1,a2,n2,m2,w1,w2,h0,ha,apar,omegaK,ksat,lpar
  end type
  type,extends(constitutive_hydraulics_provider_t),public::pdi_analytical_provider_t
    type(pdi_params_t)::p
  contains
    procedure::evaluate=>eval_provider
  end type
  public::bind_pdi_analytical_provider
contains
  subroutine bind_pdi_analytical_provider(provider,p)
    type(pdi_analytical_provider_t),intent(out)::provider
    type(pdi_params_t),intent(in)::p
    provider%p=p
  end subroutine
  pure real(real64) function gammaf(ah,a,n,m)
    real(real64),intent(in)::ah,a,n,m
    gammaf=(1.0_real64+(a*ah)**n)**(-m)
  end function
  pure real(real64) function bfun(p)
    type(pdi_params_t),intent(in)::p
    real(real64)::nn
    nn=p%n1
    if(p%model==10.and.p%a2>p%a1)nn=p%n2
    bfun=0.1_real64+0.2_real64/nn**2*(1.0_real64-exp(-((p%tr/(p%ts-p%tr))**2)))
  end function
  pure real(real64) function sadf(ah,p)
    real(real64),intent(in)::ah
    type(pdi_params_t),intent(in)::p
    real(real64)::xa,x0,x,bb
    xa=log10(p%ha);x0=log10(p%h0);x=log10(ah);bb=bfun(p)
    sadf=1.0_real64+(x-xa+bb*log(1.0_real64+exp((xa-x)/bb)))/(xa-x0)
  end function
  pure real(real64) function dsad(ah,p)
    real(real64),intent(in)::ah
    type(pdi_params_t),intent(in)::p
    real(real64)::xa,x0,x,bb
    xa=log10(p%ha);x0=log10(p%h0);x=log10(ah);bb=bfun(p)
    dsad=-1.0_real64/(ah*log(10.0_real64)*(xa-x0)*(1.0_real64+exp((xa-x)/bb)))
  end function
  pure real(real64) function cmode(ah,a,n,m)
    real(real64),intent(in)::ah,a,n,m
    cmode=a*n*m*(a*ah)**(n-1.0_real64)*(1.0_real64+(a*ah)**n)**(-m-1.0_real64)
  end function
  pure subroutine exact_one(p,h,theta,k,c)
    type(pdi_params_t),intent(in)::p
    real(real64),intent(in)::h
    real(real64),intent(out)::theta,k,c
    real(real64)::ah,g1,g2,scap,kcap,kfilm,t1,t2,t3
    if(h>=0.0_real64)then;theta=p%ts;k=p%ksat;c=0.0_real64;return;end if
    ah=abs(h);g1=gammaf(ah,p%a1,p%n1,p%m1)
    if(p%model==8)then
      scap=g1
      theta=sadf(ah,p)*p%tr+scap*(p%ts-p%tr)
      c=(p%ts-p%tr)*cmode(ah,p%a1,p%n1,p%m1)+p%tr*dsad(ah,p)
      kcap=scap**p%lpar*(1.0_real64-(1.0_real64-scap**(1.0_real64/p%m1))**p%m1)**2
    else
      g2=gammaf(ah,p%a2,p%n2,p%m2);scap=p%w1*g1+p%w2*g2
      theta=sadf(ah,p)*p%tr+scap*(p%ts-p%tr)
      c=(p%ts-p%tr)*(p%w1*cmode(ah,p%a1,p%n1,p%m1)+p%w2*cmode(ah,p%a2,p%n2,p%m2))+p%tr*dsad(ah,p)
      t1=scap**p%lpar
      t2=p%w1*p%a1*(1.0_real64-g1**(1.0_real64/p%m1))**p%m1 + p%w2*p%a2*(1.0_real64-g2**(1.0_real64/p%m2))**p%m2
      t3=p%w1*p%a1+p%w2*p%a2
      kcap=t1*(1.0_real64-t2/t3)**2
    end if
    kfilm=(p%h0/p%ha)**(p%apar*(1.0_real64-sadf(ah,p)))
    k=p%ksat*((1.0_real64-p%omegaK)*kcap+p%omegaK*kfilm)
  end subroutine
  subroutine eval_provider(self,pressure_head,water_content,conductivity,capacity,dconductivity_dhead)
    class(pdi_analytical_provider_t),intent(in)::self
    real(real64),intent(in)::pressure_head(:)
    real(real64),intent(out)::water_content(:),conductivity(:),capacity(:),dconductivity_dhead(:)
    integer::i
    do i=1,size(pressure_head)
      call exact_one(self%p,pressure_head(i),water_content(i),conductivity(i),capacity(i))
    end do
    dconductivity_dhead=0.0_real64
  end subroutine
end module

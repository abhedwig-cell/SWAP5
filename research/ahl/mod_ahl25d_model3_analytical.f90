module mod_ahl25d_model3_analytical
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: constitutive_hydraulics_provider_t
  implicit none
  private
  type, public :: model3_parameters_t
    real(real64) :: tr,ts,a1,n1,m1,a2,n2,m2,w,ksat,lambda
  end type
  type, extends(constitutive_hydraulics_provider_t), public :: model3_analytical_provider_t
    type(model3_parameters_t) :: p
  contains
    procedure :: evaluate => eval_analytical
  end type
  public :: bind_model3_analytical_provider
contains
  subroutine bind_model3_analytical_provider(provider,p)
    type(model3_analytical_provider_t),intent(out)::provider
    type(model3_parameters_t),intent(in)::p
    provider%p=p
  end subroutine
  subroutine eval_analytical(self,h,theta,k,c,dkdh)
    class(model3_analytical_provider_t),intent(in)::self
    real(real64),intent(in)::h(:)
    real(real64),intent(out)::theta(:),k(:),c(:),dkdh(:)
    integer::i
    do i=1,size(h)
      call eval_one(self%p,h(i),theta(i),k(i),c(i))
    end do
    dkdh=0.0_real64
  end subroutine
  pure subroutine eval_one(p,h,theta,k,c)
    type(model3_parameters_t),intent(in)::p
    real(real64),intent(in)::h
    real(real64),intent(out)::theta,k,c
    real(real64)::u1,u2,s1,s2,se,t1,t2,den,span
    span=p%ts-p%tr
    if(h>=0.0_real64)then
      theta=p%ts;c=0.0_real64;k=p%ksat;return
    end if
    u1=abs(p%a1*h);u2=abs(p%a2*h)
    s1=(1.0_real64+u1**p%n1)**(-p%m1)
    s2=(1.0_real64+u2**p%n2)**(-p%m2)
    se=p%w*s1+(1.0_real64-p%w)*s2
    theta=p%tr+span*se
    c=span*(p%w*(p%a1*p%n1*p%m1)*u1**(p%n1-1.0_real64)*(1.0_real64+u1**p%n1)**(-p%m1-1.0_real64) + &
         (1.0_real64-p%w)*(p%a2*p%n2*p%m2)*u2**(p%n2-1.0_real64)*(1.0_real64+u2**p%n2)**(-p%m2-1.0_real64))
    if(se>=1.0_real64)then
      k=p%ksat
    else
      t1=p%w*p%a1*(1.0_real64-s1**(1.0_real64/p%m1))**p%m1
      t2=(1.0_real64-p%w)*p%a2*(1.0_real64-s2**(1.0_real64/p%m2))**p%m2
      den=p%w*p%a1+(1.0_real64-p%w)*p%a2
      k=p%ksat*se**p%lambda*(1.0_real64-(t1+t2)/den)**2
    end if
  end subroutine
end module

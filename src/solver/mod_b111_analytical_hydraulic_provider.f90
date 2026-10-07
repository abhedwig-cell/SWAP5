module mod_b111_analytical_hydraulic_provider
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: constitutive_hydraulics_provider_t
  implicit none
  private
  integer, parameter, public :: B111_HYD_EXPONENTIAL = 2
  integer, parameter, public :: B111_HYD_BIMODAL_MVG = 3
  integer, parameter, public :: B111_HYD_BIMODAL_MVG_WCK = 6

  type, public :: b111_analytical_hydraulic_parameters_t
    integer :: active_nodes = 0
    integer, allocatable :: model_kind(:)
    real(real64), allocatable :: theta_r(:), theta_s(:), ksat(:), alpha_1(:), lambda(:), n_1(:), m_1(:)
    real(real64), allocatable :: alpha_2(:), n_2(:), m_2(:), omega_1(:)
  end type

  type, extends(constitutive_hydraulics_provider_t), public :: b111_analytical_hydraulic_provider_t
    type(b111_analytical_hydraulic_parameters_t), pointer :: parameters => null()
  contains
    procedure :: evaluate => b111_analytical_evaluate
    procedure :: supports_point_conductivity => b111_analytical_supports_point_conductivity
    procedure :: evaluate_point_conductivity => b111_analytical_evaluate_point_conductivity
  end type

  public :: initialize_b111_analytical_hydraulic_parameters
  public :: bind_b111_analytical_hydraulic_provider
contains
  subroutine initialize_b111_analytical_hydraulic_parameters(parameters, model_kind, cofgen)
    type(b111_analytical_hydraulic_parameters_t), intent(out) :: parameters
    integer, intent(in) :: model_kind(:)
    real(real64), intent(in) :: cofgen(:,:)
    integer :: n, i
    n=size(model_kind)
    if(n<=0 .or. size(cofgen,1)<16 .or. size(cofgen,2)/=n) error stop 'B1.11 analytical hydraulics: shape mismatch'
    if(any(model_kind/=B111_HYD_EXPONENTIAL .and. model_kind/=B111_HYD_BIMODAL_MVG .and. &
           model_kind/=B111_HYD_BIMODAL_MVG_WCK)) &
      error stop 'B1.11 analytical hydraulics: unsupported model kind'
    if(any(.not.ieee_is_finite(cofgen(1:16,:)))) error stop 'B1.11 analytical hydraulics: non-finite parameter'
    if(any(cofgen(2,:)<=cofgen(1,:)) .or. any(cofgen(3,:)<=0.0_real64) .or. any(cofgen(4,:)<=0.0_real64)) &
      error stop 'B1.11 analytical hydraulics: invalid primary parameters'
    parameters%active_nodes=n
    allocate(parameters%model_kind(n),parameters%theta_r(n),parameters%theta_s(n),parameters%ksat(n), &
      parameters%alpha_1(n),parameters%lambda(n),parameters%n_1(n),parameters%m_1(n), &
      parameters%alpha_2(n),parameters%n_2(n),parameters%m_2(n),parameters%omega_1(n))
    parameters%model_kind=model_kind
    parameters%theta_r=cofgen(1,:); parameters%theta_s=cofgen(2,:); parameters%ksat=cofgen(3,:)
    parameters%alpha_1=cofgen(4,:); parameters%lambda=cofgen(5,:); parameters%n_1=cofgen(6,:); parameters%m_1=cofgen(7,:)
    parameters%alpha_2=cofgen(13,:); parameters%n_2=cofgen(14,:); parameters%m_2=cofgen(15,:); parameters%omega_1=cofgen(16,:)
    do i=1,n
      if(model_kind(i)==B111_HYD_BIMODAL_MVG .or. model_kind(i)==B111_HYD_BIMODAL_MVG_WCK) then
        if(parameters%n_1(i)<=1.0_real64 .or. parameters%m_1(i)<=0.0_real64 .or. &
          parameters%alpha_2(i)<=0.0_real64 .or. parameters%n_2(i)<=1.0_real64 .or. &
          parameters%m_2(i)<=0.0_real64 .or. parameters%omega_1(i)<0.0_real64 .or. parameters%omega_1(i)>1.0_real64) &
          error stop 'B1.11 analytical hydraulics: invalid bimodal parameters'
      end if
    end do
  end subroutine

  subroutine bind_b111_analytical_hydraulic_provider(provider,parameters)
    type(b111_analytical_hydraulic_provider_t),intent(out)::provider
    type(b111_analytical_hydraulic_parameters_t),target,intent(in)::parameters
    if(parameters%active_nodes<=0) error stop 'B1.11 analytical hydraulics: invalid parameter set'
    provider%parameters=>parameters
  end subroutine

  subroutine b111_analytical_evaluate(self,pressure_head,water_content,conductivity,capacity,dconductivity_dhead)
    class(b111_analytical_hydraulic_provider_t),intent(in)::self
    real(real64),intent(in)::pressure_head(:)
    real(real64),intent(out)::water_content(:),conductivity(:),capacity(:),dconductivity_dhead(:)
    integer::i,n
    if(.not.associated(self%parameters)) error stop 'B1.11 analytical hydraulics: parameters not bound'
    n=self%parameters%active_nodes
    if(size(pressure_head)/=n.or.size(water_content)/=n.or.size(conductivity)/=n.or.size(capacity)/=n.or.size(dconductivity_dhead)/=n) &
      error stop 'B1.11 analytical hydraulics: shape mismatch'
    do i=1,n
      call evaluate_node(self%parameters,i,pressure_head(i),water_content(i),conductivity(i),capacity(i),dconductivity_dhead(i))
    end do
  end subroutine

  pure subroutine evaluate_node(p,i,h,theta,k,cap,dkdh)
    type(b111_analytical_hydraulic_parameters_t),intent(in)::p
    integer,intent(in)::i
    real(real64),intent(in)::h
    real(real64),intent(out)::theta,k,cap,dkdh
    real(real64)::delta,s1,s2,relsat,a1,a2,term1,term2,scomb,denom,q
    real(real64)::ds1,ds2,dscomb,df1,df2,dtcond,dq
    delta=p%theta_s(i)-p%theta_r(i)
    select case(p%model_kind(i))
    case(B111_HYD_EXPONENTIAL)
      theta=max(1.0000001_real64*p%theta_r(i),p%theta_r(i)+delta*exp(p%alpha_1(i)*h))
      cap=p%alpha_1(i)*delta*exp(p%alpha_1(i)*h)
      relsat=(theta-p%theta_r(i))/delta
      k=p%ksat(i)*relsat
      dkdh=p%alpha_1(i)*p%ksat(i)*exp(p%alpha_1(i)*h)
    case(B111_HYD_BIMODAL_MVG,B111_HYD_BIMODAL_MVG_WCK)
      if(h>=0.0_real64) then
        theta=p%theta_s(i)
        cap=0.0_real64
        k=p%ksat(i)
        dkdh=1.0e-12_real64
      else
        s1=(1.0_real64+abs(p%alpha_1(i)*h)**p%n_1(i))**(-p%m_1(i))
        s2=(1.0_real64+abs(p%alpha_2(i)*h)**p%n_2(i))**(-p%m_2(i))
        scomb=p%omega_1(i)*s1+(1.0_real64-p%omega_1(i))*s2
        theta=p%theta_r(i)+delta*scomb
        cap=delta*(p%omega_1(i)*p%alpha_1(i)*p%n_1(i)*p%m_1(i)* &
          abs(p%alpha_1(i)*h)**(p%n_1(i)-1.0_real64)*(1.0_real64+abs(p%alpha_1(i)*h)**p%n_1(i))**(-p%m_1(i)-1.0_real64) + &
          (1.0_real64-p%omega_1(i))*p%alpha_2(i)*p%n_2(i)*p%m_2(i)* &
          abs(p%alpha_2(i)*h)**(p%n_2(i)-1.0_real64)*(1.0_real64+abs(p%alpha_2(i)*h)**p%n_2(i))**(-p%m_2(i)-1.0_real64))
        a1=1.0_real64-s1**(1.0_real64/p%m_1(i))
        a2=1.0_real64-s2**(1.0_real64/p%m_2(i))
        term1=p%omega_1(i)*p%alpha_1(i)*a1**p%m_1(i)
        term2=(1.0_real64-p%omega_1(i))*p%alpha_2(i)*a2**p%m_2(i)
        denom=p%omega_1(i)*p%alpha_1(i)+(1.0_real64-p%omega_1(i))*p%alpha_2(i)
        q=1.0_real64-(term1+term2)/denom
        k=p%ksat(i)*scomb**p%lambda(i)*q*q
        ds1=p%alpha_1(i)*p%n_1(i)*p%m_1(i)*abs(p%alpha_1(i)*h)**(p%n_1(i)-1.0_real64)* &
          (1.0_real64+abs(p%alpha_1(i)*h)**p%n_1(i))**(-p%m_1(i)-1.0_real64)
        ds2=p%alpha_2(i)*p%n_2(i)*p%m_2(i)*abs(p%alpha_2(i)*h)**(p%n_2(i)-1.0_real64)* &
          (1.0_real64+abs(p%alpha_2(i)*h)**p%n_2(i))**(-p%m_2(i)-1.0_real64)
        dscomb=p%omega_1(i)*ds1+(1.0_real64-p%omega_1(i))*ds2
        df1=-a1**(p%m_1(i)-1.0_real64)*s1**(1.0_real64/p%m_1(i)-1.0_real64)*ds1
        df2=-a2**(p%m_2(i)-1.0_real64)*s2**(1.0_real64/p%m_2(i)-1.0_real64)*ds2
        dtcond=p%omega_1(i)*p%alpha_1(i)*df1+(1.0_real64-p%omega_1(i))*p%alpha_2(i)*df2
        dq=-dtcond/denom
        dkdh=p%ksat(i)*(p%lambda(i)*scomb**(p%lambda(i)-1.0_real64)*dscomb*q*q + &
          2.0_real64*scomb**p%lambda(i)*q*dq)
      end if
    end select
  end subroutine

  logical function b111_analytical_supports_point_conductivity(self) result(supported)
    class(b111_analytical_hydraulic_provider_t),intent(in)::self
    supported=associated(self%parameters)
  end function

  subroutine b111_analytical_evaluate_point_conductivity(self,node_index,pressure_head,water_content,conductivity,available)
    class(b111_analytical_hydraulic_provider_t),intent(in)::self
    integer,intent(in)::node_index
    real(real64),intent(in)::pressure_head,water_content
    real(real64),intent(out)::conductivity
    logical,intent(out)::available
    real(real64)::theta,cap,dk
    available=.false.
    conductivity=0.0_real64
    if(.not.associated(self%parameters))return
    if(node_index<1.or.node_index>self%parameters%active_nodes)return
    call evaluate_node(self%parameters,node_index,pressure_head,theta,conductivity,cap,dk)
    available=ieee_is_finite(conductivity).and.conductivity>=0.0_real64
  end subroutine
end module

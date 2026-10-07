module mod_b111_extended_hydraulic_provider
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_soil_water_solver_contract, only: constitutive_hydraulics_provider_t
  implicit none
  private

  integer, parameter, public :: B111_EXT_OK = 0
  integer, parameter, public :: B111_EXT_INVALID_SHAPE = 1
  integer, parameter, public :: B111_EXT_INVALID_MODEL = 2
  integer, parameter, public :: B111_EXT_INVALID_PARAMETERS = 3
  integer, parameter :: B111_EXT_COFGEN_REQUIRED = 21

  type, public :: b111_extended_hydraulic_parameters_t
    integer :: active_nodes = 0
    integer, allocatable :: model(:)
    real(real64), allocatable :: cofgen(:,:)
  end type

  type, extends(constitutive_hydraulics_provider_t), public :: b111_extended_hydraulic_provider_t
    type(b111_extended_hydraulic_parameters_t), pointer, private :: parameters => null()
    class(constitutive_hydraulics_provider_t), pointer, private :: base => null()
  contains
    procedure :: evaluate => b111_extended_evaluate
    procedure :: supports_point_conductivity => b111_extended_supports_point
    procedure :: evaluate_point_conductivity => b111_extended_point_conductivity
  end type

  public :: initialize_b111_extended_hydraulic_parameters
  public :: bind_b111_extended_hydraulic_provider
  public :: evaluate_b111_extended_one

contains

  subroutine initialize_b111_extended_hydraulic_parameters(parameters, model, cofgen_input, status)
    type(b111_extended_hydraulic_parameters_t), intent(out) :: parameters
    integer, intent(in) :: model(:)
    real(real64), intent(in) :: cofgen_input(:,:)
    integer, intent(out) :: status
    integer :: i, n

    status = B111_EXT_INVALID_SHAPE
    n = size(model)
    if (n <= 0 .or. size(cofgen_input,1) < B111_EXT_COFGEN_REQUIRED .or. size(cofgen_input,2) /= n) return
    status = B111_EXT_INVALID_MODEL
    if (any(model < 1) .or. any(model > 11) .or. any(model == 4)) return
    status = B111_EXT_INVALID_PARAMETERS
    if (any(.not. ieee_is_finite(cofgen_input(1:B111_EXT_COFGEN_REQUIRED,:)))) return

    do i = 1, n
      if (model(i) >= 5) then
        if (.not. valid_node_parameters(model(i), cofgen_input(:,i))) return
      end if
    end do

    parameters%active_nodes = n
    allocate(parameters%model(n), parameters%cofgen(B111_EXT_COFGEN_REQUIRED,n))
    parameters%model = model
    parameters%cofgen = cofgen_input(1:B111_EXT_COFGEN_REQUIRED,:)
    status = B111_EXT_OK
  end subroutine

  subroutine bind_b111_extended_hydraulic_provider(provider, parameters, base, status)
    type(b111_extended_hydraulic_provider_t), intent(out) :: provider
    type(b111_extended_hydraulic_parameters_t), target, intent(in) :: parameters
    class(constitutive_hydraulics_provider_t), target, intent(in) :: base
    integer, intent(out) :: status
    integer :: i

    nullify(provider%parameters)
    nullify(provider%base)
    status = B111_EXT_INVALID_SHAPE
    if (parameters%active_nodes <= 0 .or. .not. allocated(parameters%model) .or. .not. allocated(parameters%cofgen)) return
    if (size(parameters%model) /= parameters%active_nodes .or. size(parameters%cofgen,1) < B111_EXT_COFGEN_REQUIRED .or. &
        size(parameters%cofgen,2) /= parameters%active_nodes) return
    status = B111_EXT_INVALID_PARAMETERS
    do i = 1, parameters%active_nodes
      if (parameters%model(i) >= 5) then
        if (.not. valid_node_parameters(parameters%model(i), parameters%cofgen(:,i))) return
      end if
    end do
    provider%parameters => parameters
    provider%base => base
    status = B111_EXT_OK
  end subroutine

  subroutine b111_extended_evaluate(self, pressure_head, water_content, conductivity, capacity, dconductivity_dhead)
    class(b111_extended_hydraulic_provider_t), intent(in) :: self
    real(real64), intent(in) :: pressure_head(:)
    real(real64), intent(out) :: water_content(:), conductivity(:), capacity(:), dconductivity_dhead(:)
    integer :: i, n

    if (.not. associated(self%parameters) .or. .not. associated(self%base)) &
      error stop 'B1.11 extended hydraulics: provider not bound'
    n = self%parameters%active_nodes
    if (size(pressure_head) /= n .or. size(water_content) /= n .or. size(conductivity) /= n .or. &
        size(capacity) /= n .or. size(dconductivity_dhead) /= n) error stop 'B1.11 extended hydraulics: shape mismatch'
    call self%base%evaluate(pressure_head, water_content, conductivity, capacity, dconductivity_dhead)
    do i = 1, n
      if (self%parameters%model(i) >= 5) then
        call evaluate_b111_extended_one(self%parameters%model(i), self%parameters%cofgen(:,i), pressure_head(i), &
                                        water_content(i), conductivity(i), capacity(i))
        dconductivity_dhead(i) = 0.0_real64
      end if
    end do
  end subroutine

  logical function b111_extended_supports_point(self) result(supported)
    class(b111_extended_hydraulic_provider_t), intent(in) :: self
    supported = associated(self%parameters) .and. associated(self%base)
    if (supported) supported = self%base%supports_point_conductivity()
  end function

  subroutine b111_extended_point_conductivity(self, node_index, pressure_head, water_content, conductivity, available)
    class(b111_extended_hydraulic_provider_t), intent(in) :: self
    integer, intent(in) :: node_index
    real(real64), intent(in) :: pressure_head, water_content
    real(real64), intent(out) :: conductivity
    logical, intent(out) :: available
    real(real64) :: theta, capacity

    conductivity = 0.0_real64
    available = .false.
    if (.not. associated(self%parameters) .or. .not. associated(self%base)) return
    if (node_index < 1 .or. node_index > self%parameters%active_nodes) return
    if (.not. ieee_is_finite(pressure_head) .or. .not. ieee_is_finite(water_content)) return
    if (self%parameters%model(node_index) >= 5) then
      call evaluate_b111_extended_one(self%parameters%model(node_index), self%parameters%cofgen(:,node_index), &
                                      pressure_head, theta, conductivity, capacity)
      available = ieee_is_finite(conductivity) .and. conductivity >= 0.0_real64
    else
      call self%base%evaluate_point_conductivity(node_index, pressure_head, water_content, conductivity, available)
    end if
    if (.not. available) conductivity = 0.0_real64
  end subroutine

  subroutine evaluate_b111_extended_one(model, c, head, theta, conductivity, capacity)
    integer, intent(in) :: model
    real(real64), intent(in) :: c(:), head
    real(real64), intent(out) :: theta, conductivity, capacity
    real(real64) :: tr, ts, ksat, a1, lpar, n1, m1, a2, n2, m2, w1, w2
    real(real64) :: h0, ha, apar, omega_k, ah, g1, g2, g01, g02, s, s1, s2
    real(real64) :: cap1, cap2, f1, f2, t1, t2, t3, sad, dsad, bb, nn, x, xa, x0
    real(real64) :: kcap, kfilm

    if (model < 5 .or. model > 11 .or. size(c) < B111_EXT_COFGEN_REQUIRED) &
      error stop 'B1.11 extended hydraulics: unsupported model'
    if (.not. ieee_is_finite(head)) error stop 'B1.11 extended hydraulics: non-finite head'

    tr=c(1); ts=c(2); ksat=c(3); a1=c(4); lpar=c(5); n1=c(6); m1=c(7)
    a2=0.0_real64; n2=0.0_real64; m2=0.0_real64; w1=1.0_real64; w2=0.0_real64
    h0=0.0_real64; ha=0.0_real64; apar=0.0_real64; omega_k=0.0_real64
    if (model==6 .or. model==7 .or. model==10 .or. model==11) then
      a2=c(13); n2=c(14); m2=c(15); w1=c(16); w2=c(17)
    end if
    if (model==5 .or. model==7 .or. model>=8) h0=c(18)
    if (model>=8) then
      ha=c(19); apar=c(20); omega_k=c(21)
    end if

    if (head >= 0.0_real64) then
      theta=ts; conductivity=ksat; capacity=0.0_real64
      return
    end if

    ah=abs(head)
    g1=(1.0_real64+(a1*ah)**n1)**(-m1)
    cap1=a1*n1*m1*(a1*ah)**(n1-1.0_real64)*(1.0_real64+(a1*ah)**n1)**(-m1-1.0_real64)
    if (model==6 .or. model==7 .or. model==10 .or. model==11) then
      g2=(1.0_real64+(a2*ah)**n2)**(-m2)
      cap2=a2*n2*m2*(a2*ah)**(n2-1.0_real64)*(1.0_real64+(a2*ah)**n2)**(-m2-1.0_real64)
    else
      g2=0.0_real64; cap2=0.0_real64
    end if

    select case(model)
    case(5)
      g01=(1.0_real64+(a1*h0)**n1)**(-m1)
      s=(g1-g01)/(1.0_real64-g01)
      theta=tr+s*(ts-tr)
      f1=1.0_real64-g1**(1.0_real64/m1)
      t1=1.0_real64-g01**(1.0_real64/m1)
      kcap=s**lpar*(1.0_real64-(f1/t1)**m1)**2
      capacity=(ts-tr)/(1.0_real64-g01)*cap1
      conductivity=ksat*kcap
    case(6)
      s=w1*g1+w2*g2
      theta=tr+s*(ts-tr)
      f1=(1.0_real64-g1**(1.0_real64/m1))**m1
      f2=(1.0_real64-g2**(1.0_real64/m2))**m2
      t2=w1*a1*f1+w2*a2*f2; t3=w1*a1+w2*a2
      kcap=s**lpar*(1.0_real64-t2/t3)**2
      capacity=(ts-tr)*(w1*cap1+w2*cap2)
      conductivity=ksat*kcap
    case(7)
      g01=(1.0_real64+(a1*h0)**n1)**(-m1)
      g02=(1.0_real64+(a2*h0)**n2)**(-m2)
      s=(w1*g1+w2*g2-w1*g01-w2*g02)/(1.0_real64-w1*g01-w2*g02)
      theta=tr+s*(ts-tr)
      s1=(g1-g01)/(1.0_real64-g01); s2=(g2-g02)/(1.0_real64-g02)
      t1=(w1*s1+w2*s2)**lpar
      t2=w1*a1*(1.0_real64-g1**(1.0_real64/m1))**m1 + w2*a2*(1.0_real64-g2**(1.0_real64/m2))**m2
      t3=w1*a1*(1.0_real64-g01**(1.0_real64/m1))**m1 + w2*a2*(1.0_real64-g02**(1.0_real64/m2))**m2
      kcap=t1*(1.0_real64-t2/t3)**2
      capacity=(ts-tr)*(w1*cap1+w2*cap2)/(1.0_real64-w1*g01-w2*g02)
      conductivity=ksat*kcap
    case(8:11)
      nn=n1
      if ((model==10 .or. model==11) .and. a2>a1) nn=n2
      bb=0.1_real64+0.2_real64/nn**2*(1.0_real64-exp(-((tr/(ts-tr))**2)))
      xa=log10(ha); x0=log10(h0); x=log10(ah)
      sad=1.0_real64+(x-xa+bb*log(1.0_real64+exp((xa-x)/bb)))/(xa-x0)
      dsad=-1.0_real64/(ah*log(10.0_real64)*(xa-x0)*(1.0_real64+exp((xa-x)/bb)))
      select case(model)
      case(8)
        s=g1
        kcap=s**lpar*(1.0_real64-(1.0_real64-s**(1.0_real64/m1))**m1)**2
        capacity=(ts-tr)*cap1+tr*dsad
      case(9)
        g01=(1.0_real64+(a1*h0)**n1)**(-m1)
        s=(g1-g01)/(1.0_real64-g01)
        f1=1.0_real64-g1**(1.0_real64/m1); t1=1.0_real64-g01**(1.0_real64/m1)
        kcap=s**lpar*(1.0_real64-(f1/t1)**m1)**2
        capacity=(ts-tr)/(1.0_real64-g01)*cap1+tr*dsad
      case(10)
        s=w1*g1+w2*g2
        t1=s**lpar
        t2=w1*a1*(1.0_real64-g1**(1.0_real64/m1))**m1+w2*a2*(1.0_real64-g2**(1.0_real64/m2))**m2
        t3=w1*a1+w2*a2
        kcap=t1*(1.0_real64-t2/t3)**2
        capacity=(ts-tr)*(w1*cap1+w2*cap2)+tr*dsad
      case(11)
        g01=(1.0_real64+(a1*h0)**n1)**(-m1); g02=(1.0_real64+(a2*h0)**n2)**(-m2)
        s=(w1*g1+w2*g2-w1*g01-w2*g02)/(1.0_real64-w1*g01-w2*g02)
        theta=tr*sad+s*(ts-tr)
        s1=(g1-g01)/(1.0_real64-g01); s2=(g2-g02)/(1.0_real64-g02)
        t1=(w1*s1+w2*s2)**lpar
        t2=w1*a1*(1.0_real64-g1**(1.0_real64/m1))**m1+w2*a2*(1.0_real64-g2**(1.0_real64/m2))**m2
        t3=w1*a1*(1.0_real64-g01**(1.0_real64/m1))**m1+w2*a2*(1.0_real64-g02**(1.0_real64/m2))**m2
        kcap=t1*(1.0_real64-t2/t3)**2
        capacity=(ts-tr)*(w1*cap1+w2*cap2)/(1.0_real64-w1*g01-w2*g02)+tr*dsad
      end select
      if (model /= 11) theta=tr*sad+s*(ts-tr)
      kfilm=(h0/ha)**(apar*(1.0_real64-sad))
      conductivity=ksat*((1.0_real64-omega_k)*kcap+omega_k*kfilm)
    end select

    if (.not. ieee_is_finite(theta) .or. .not. ieee_is_finite(conductivity) .or. .not. ieee_is_finite(capacity)) &
      error stop 'B1.11 extended hydraulics: non-finite result'
  end subroutine

  logical function valid_node_parameters(model, c) result(ok)
    integer, intent(in) :: model
    real(real64), intent(in) :: c(:)
    real(real64) :: w2
    ok=.false.
    if (model < 5 .or. model > 11 .or. size(c) < B111_EXT_COFGEN_REQUIRED) return
    if (any(.not. ieee_is_finite(c(1:B111_EXT_COFGEN_REQUIRED)))) return
    if (c(2) <= c(1) .or. c(3) < 0.0_real64 .or. c(4) <= 0.0_real64 .or. &
        c(6) <= 1.0_real64 .or. c(7) <= 0.0_real64) return
    if (model==6 .or. model==7 .or. model==10 .or. model==11) then
      w2=c(17)
      if (c(13)<=0.0_real64 .or. c(14)<=1.0_real64 .or. c(15)<=0.0_real64) return
      if (c(16)<0.0_real64 .or. w2<0.0_real64 .or. abs(c(16)+w2-1.0_real64)>1.0e-10_real64) return
    end if
    if (model==5 .or. model==7 .or. model>=8) then
      if (c(18)<=0.0_real64) return
    end if
    if (model>=8) then
      if (c(19)<=0.0_real64 .or. c(18)==c(19) .or. c(21)<0.0_real64 .or. c(21)>1.0_real64) return
    end if
    ok=.true.
  end function
end module

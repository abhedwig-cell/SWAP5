module mod_macropore_dynamic_shrinkage
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  type, public :: clay_kim_shrinkage_t
    real(real64) :: alpha_k = 0.0_real64
    real(real64) :: beta_k = 0.0_real64
    real(real64) :: gamma_k = 0.0_real64
    real(real64) :: transition_moisture_ratio = 0.0_real64
  contains
    procedure :: valid => clay_kim_valid
  end type clay_kim_shrinkage_t

  integer, parameter, public :: SHRINK_RIGID=0, SHRINK_KIM=1, SHRINK_PEAT_DIRECT=2, SHRINK_PEAT_SEGMENTS=3

  type, public :: peat_shrinkage_t
    real(real64) :: void_ratio_zero=0.0_real64
    real(real64) :: transition_moisture_ratio=0.0_real64
    real(real64) :: alpha=0.0_real64, beta=0.0_real64, p=0.0_real64
    real(real64) :: intermediate_moisture_ratio=0.0_real64, intermediate_void_ratio=0.0_real64
  end type peat_shrinkage_t

  type, public :: dynamic_crack_request_t
    real(real64) :: theta = 0.0_real64
    real(real64) :: theta_previous = 0.0_real64
    real(real64) :: theta_s = 0.0_real64
    real(real64) :: theta_crack = 0.0_real64
    real(real64) :: dz_cm = 0.0_real64
    real(real64) :: geometry_factor = 0.0_real64
    real(real64) :: matrix_area_fraction = 1.0_real64
    real(real64) :: prior_dynamic_volume_cm = 0.0_real64
    real(real64) :: neighbour_dynamic_volume_cm = 0.0_real64
    real(real64) :: minimum_subsidence_cm = 0.0_real64
  end type dynamic_crack_request_t

  type, public :: dynamic_shrinkage_config_t
    logical :: enabled = .false.
    integer :: surface_crack_area_node = 1
    logical :: surface_crack_area_node_supplied = .false.
    real(real64) :: surface_crack_area_depth_cm = 0.0_real64
    logical :: surface_crack_area_depth_supplied = .false.
    real(real64), allocatable :: theta_s(:), theta_crack(:), geometry_factor(:), minimum_subsidence_cm(:)
    type(clay_kim_shrinkage_t), allocatable :: kim(:)
    ! Absent selector preserves the admitted Kim-only configuration.
    integer, allocatable :: law(:)
    type(peat_shrinkage_t), allocatable :: peat(:)
  contains
    procedure :: valid_for_nodes => dynamic_shrinkage_config_valid
  end type dynamic_shrinkage_config_t

  public :: evaluate_peat_shrinkage_fraction, evaluate_node_shrinkage_fraction
  public :: prepare_clay_kim_option1, prepare_clay_kim_option2, prepare_peat_characteristic_points
  public :: evaluate_clay_kim_shrinkage_fraction
  public :: evaluate_dynamic_crack_volume
  public :: evaluate_dynamic_crack_profile
  public :: find_dynamic_groundwater_cutoff
  public :: map_surface_crack_depth_to_node
  public :: prepare_rapid_drain_reference_kd
  public :: derive_dynamic_minimum_subsidence

contains

  subroutine prepare_rapid_drain_reference_kd(config,z,dz,theta_hydrostatic,static_volume, &
       main_fraction,diameter,static_bottom,drain_level,drain_type,exponent,kd,ok)
    type(dynamic_shrinkage_config_t),intent(in)::config
    real(real64),intent(in)::z(:),dz(:),theta_hydrostatic(:),static_volume(:),main_fraction(:),diameter(:)
    real(real64),intent(in)::static_bottom,drain_level,exponent
    integer,intent(in)::drain_type
    real(real64),intent(out)::kd
    logical,intent(out)::ok
    integer::n,ib,is,it,i
    real(real64)::level,theta,shrink,dynamic_fraction,ratio,width,total,bottom
    logical::rigid,local_ok
    kd=0.0_real64;ok=.false.;n=size(z)
    if(n<=0)return
    if(size(dz)/=n.or.size(theta_hydrostatic)/=n.or.size(static_volume)/=n.or. &
         size(main_fraction)/=n.or.size(diameter)/=n)return
    if(.not.config%enabled.or..not.config%valid_for_nodes(n))return
    if(any(.not.ieee_is_finite(z)).or.any(.not.ieee_is_finite(dz)).or. &
         any(.not.ieee_is_finite(theta_hydrostatic)).or.any(.not.ieee_is_finite(static_volume)).or. &
         any(.not.ieee_is_finite(main_fraction)).or.any(.not.ieee_is_finite(diameter)))return
    if(.not.ieee_is_finite(static_bottom).or..not.ieee_is_finite(drain_level).or. &
         .not.ieee_is_finite(exponent))return
    if(any(dz<=0.0_real64).or.any(diameter<=0.0_real64).or.exponent<=0.0_real64)return
    if(any(static_volume<0.0_real64).or.any(static_volume>=dz).or.any(main_fraction<0.0_real64).or. &
         any(main_fraction>1.0_real64).or.any(theta_hydrostatic<0.0_real64).or. &
         any(theta_hydrostatic>config%theta_s))return
    if(drain_type/=1.and.drain_type/=2)return
    ! Surface-based, contiguous centimetre grid. No covering-layer composition.
    bottom=0.0_real64
    do i=1,n
      if(abs(z(i)-(bottom-0.5_real64*dz(i)))>1.0e-8_real64)return
      bottom=bottom-dz(i)
    end do
    if(static_bottom>0.0_real64.or.drain_level>0.0_real64.or. &
         static_bottom<bottom.or.drain_level<bottom)return
    is=reference_node(static_bottom);ib=is;rigid=.false.
    if(static_bottom>drain_level)then
      ib=reference_node(drain_level)
      if(ib>is.and.allocated(config%law))then
        rigid=any(config%law(is:ib)==SHRINK_RIGID)
        if(rigid)ib=is
      end if
    end if
    if(drain_type==1.and.rigid)then
      ok=.true.;return
    end if
    level=drain_level
    if(rigid)level=static_bottom
    level=min(0.75_real64*level,level+10.0_real64)
    it=reference_node(level);total=0.0_real64
    do i=it,ib
      theta=theta_hydrostatic(i)
      if(static_bottom>drain_level)theta=min(0.99_real64*config%theta_s(i),theta)
      call evaluate_node_shrinkage_fraction(config,i,theta,shrink,local_ok)
      if(.not.local_ok)return
      dynamic_fraction=shrink-(1.0_real64-(1.0_real64-shrink)**(1.0_real64/config%geometry_factor(i)))
      ratio=main_fraction(i)*(dynamic_fraction+static_volume(i)/dz(i))
      if(.not.ieee_is_finite(ratio).or.ratio<0.0_real64.or.ratio>=1.0_real64)return
      width=diameter(i)*(1.0_real64-sqrt(1.0_real64-ratio))
      total=total+(width**exponent)/diameter(i)*dz(i)
    end do
    if(.not.ieee_is_finite(total))return
    kd=total;ok=.true.
  contains
    integer function reference_node(depth) result(node)
      real(real64),intent(in)::depth
      real(real64)::b
      node=1;b=-dz(1)-1.0e-2_real64
      do while(depth<b.and.node<n)
        node=node+1;b=b-dz(node)
      end do
    end function reference_node
  end subroutine prepare_rapid_drain_reference_kd

  subroutine derive_dynamic_minimum_subsidence(config,dz,ok)
    type(dynamic_shrinkage_config_t),intent(inout)::config
    real(real64),intent(in)::dz(:)
    logical,intent(out)::ok
    real(real64)::shrink
    integer::n,ic
    logical::local_ok
    ok=.false.;n=size(dz)
    if(.not.config%enabled)then
      ok=.true.;return
    end if
    if(n<=0 .or. any(.not.ieee_is_finite(dz)) .or. any(dz<=0.0_real64))return
    if(.not.allocated(config%theta_s) .or. .not.allocated(config%theta_crack))return
    if(size(config%theta_s)/=n .or. size(config%theta_crack)/=n)return
    if(allocated(config%minimum_subsidence_cm))deallocate(config%minimum_subsidence_cm)
    allocate(config%minimum_subsidence_cm(n))
    config%minimum_subsidence_cm=0.0_real64
    do ic=1,n
      ! B1.11 MACROPORE initialization: SubsidCpMin = SHRINK(ThetCrMp)*Dz.
      call evaluate_node_shrinkage_fraction(config,ic,config%theta_crack(ic),shrink,local_ok)
      if(.not.local_ok)return
      config%minimum_subsidence_cm(ic)=shrink*dz(ic)
    end do
    ok=.true.
  end subroutine derive_dynamic_minimum_subsidence

  pure subroutine map_surface_crack_depth_to_node(depth_cm,z,dz,top_node,node,ok)
    real(real64),intent(in)::depth_cm,z(:),dz(:)
    integer,intent(in)::top_node
    integer,intent(out)::node
    logical,intent(out)::ok
    integer::n,ic
    n=size(z);node=0;ok=.false.
    if(n<=0 .or. size(dz)/=n .or. top_node<1 .or. top_node>n)return
    if(.not.ieee_is_finite(depth_cm) .or. any(.not.ieee_is_finite(z)) .or. &
       any(.not.ieee_is_finite(dz)) .or. any(dz<=0.0_real64))return
    if(top_node>1)then
      node=top_node;ok=.true.;return
    end if
    ic=1
    do while((z(ic)-0.5_real64*dz(ic)+1.0e-2_real64)>depth_cm)
      ic=ic+1
      if(ic>n)return
    end do
    node=ic;ok=.true.
  end subroutine map_surface_crack_depth_to_node

  pure logical function dynamic_shrinkage_config_valid(self,n) result(ok)
    class(dynamic_shrinkage_config_t),intent(in)::self
    integer,intent(in)::n
    integer::i
    ok=.false.
    if(.not.self%enabled)then
      ok=.true.
      return
    end if
    if(.not.self%surface_crack_area_node_supplied)return
    if(.not.allocated(self%theta_s) .or. .not.allocated(self%theta_crack) .or. &
       .not.allocated(self%geometry_factor) .or. .not.allocated(self%minimum_subsidence_cm))return
    if(size(self%theta_s)/=n .or. size(self%theta_crack)/=n .or. size(self%geometry_factor)/=n .or. &
       size(self%minimum_subsidence_cm)/=n)return
    if(n<=0)return
    if(self%surface_crack_area_node<1 .or. self%surface_crack_area_node>n)return
    if(.not.all(ieee_is_finite(self%theta_s)) .or. .not.all(ieee_is_finite(self%theta_crack)) .or. &
       .not.all(ieee_is_finite(self%geometry_factor)) .or. &
       .not.all(ieee_is_finite(self%minimum_subsidence_cm)))return
    if(any(self%theta_s<=0.0_real64) .or. any(self%theta_s>=1.0_real64) .or. &
       any(self%theta_crack<0.0_real64) .or. any(self%theta_crack>self%theta_s) .or. &
       any(self%geometry_factor<=0.0_real64) .or. any(self%minimum_subsidence_cm<0.0_real64))return
    if(allocated(self%law))then
      if(size(self%law)/=n)return
    end if
    do i=1,n
      if(.not.node_law_valid(self,i))return
    end do
    ok=.true.
  end function dynamic_shrinkage_config_valid

  pure logical function node_law_valid(config,i) result(ok)
    class(dynamic_shrinkage_config_t),intent(in)::config
    integer,intent(in)::i
    integer::law,n
    ok=.false.
    if(.not.allocated(config%theta_s))return
    n=size(config%theta_s)
    if(i<1 .or. i>n)return
    law=SHRINK_KIM
    if(allocated(config%law))then
      if(size(config%law)/=n)return
      law=config%law(i)
    end if
    select case(law)
    case(SHRINK_RIGID)
      ok=.true.
    case(SHRINK_KIM)
      if(.not.allocated(config%kim))return
      if(size(config%kim)/=n)return
      ok=config%kim(i)%valid()
    case(SHRINK_PEAT_DIRECT,SHRINK_PEAT_SEGMENTS)
      if(.not.allocated(config%peat))return
      if(size(config%peat)/=n)return
      ok=peat_valid(config%theta_s(i),config%peat(i),law)
    end select
  end function node_law_valid

  pure logical function peat_valid(theta_s,parameters,law) result(ok)
    real(real64),intent(in)::theta_s
    type(peat_shrinkage_t),intent(in)::parameters
    integer,intent(in)::law
    real(real64)::sat,a,v_at_a
    ok=.false.
    if(.not.ieee_is_finite(theta_s))return
    if(theta_s<=0.0_real64 .or. theta_s>=1.0_real64)return
    sat=theta_s/(1.0_real64-theta_s)
    a=parameters%transition_moisture_ratio
    if(.not.ieee_is_finite(a) .or. .not.ieee_is_finite(parameters%void_ratio_zero))return
    if(a<=0.0_real64 .or. a>=sat .or. parameters%void_ratio_zero<0.0_real64 .or. &
       parameters%void_ratio_zero>=sat)return
    select case(law)
    case(SHRINK_PEAT_DIRECT)
      if(.not.ieee_is_finite(parameters%alpha) .or. .not.ieee_is_finite(parameters%beta) .or. &
         .not.ieee_is_finite(parameters%p))return
      ! Bounded regular Hendriks branch: peak lies strictly within normalized interval.
      if(parameters%alpha<=0.0_real64 .or. parameters%alpha>100.0_real64 .or. &
         parameters%beta<=parameters%alpha+1.0e-8_real64 .or. parameters%beta>100.0_real64)return
      if(abs(parameters%p)>10.0_real64)return
    case(SHRINK_PEAT_SEGMENTS)
      if(.not.ieee_is_finite(parameters%intermediate_moisture_ratio) .or. &
         .not.ieee_is_finite(parameters%intermediate_void_ratio))return
      if(parameters%intermediate_moisture_ratio<=0.0_real64 .or. &
         parameters%intermediate_moisture_ratio>=a)return
      v_at_a=parameters%void_ratio_zero+(sat-parameters%void_ratio_zero)*a/sat
      if(parameters%intermediate_void_ratio<parameters%void_ratio_zero .or. &
         parameters%intermediate_void_ratio<parameters%intermediate_moisture_ratio .or. &
         parameters%intermediate_void_ratio>v_at_a)return
    case default
      return
    end select
    ok=.true.
  end function peat_valid

  subroutine evaluate_node_shrinkage_fraction(config,i,theta,shrink,ok)
    type(dynamic_shrinkage_config_t),intent(in)::config
    integer,intent(in)::i
    real(real64),intent(in)::theta
    real(real64),intent(out)::shrink
    logical,intent(out)::ok
    integer::law
    shrink=0.0_real64;ok=.false.
    if(.not.node_law_valid(config,i))return
    law=SHRINK_KIM
    if(allocated(config%law))law=config%law(i)
    select case(law)
    case(SHRINK_RIGID)
      ok=ieee_is_finite(theta)
      if(ok)ok=theta>=0.0_real64 .and. theta<=config%theta_s(i)
    case(SHRINK_KIM)
      call evaluate_clay_kim_shrinkage_fraction(theta,config%theta_s(i),config%kim(i),shrink,ok)
    case(SHRINK_PEAT_DIRECT,SHRINK_PEAT_SEGMENTS)
      call evaluate_peat_shrinkage_fraction(theta,config%theta_s(i),config%peat(i),law,shrink,ok)
    end select
  end subroutine evaluate_node_shrinkage_fraction

  subroutine evaluate_peat_shrinkage_fraction(theta,theta_s,parameters,law,shrink,ok)
    real(real64),intent(in)::theta,theta_s
    type(peat_shrinkage_t),intent(in)::parameters
    integer,intent(in)::law
    real(real64),intent(out)::shrink
    logical,intent(out)::ok
    real(real64)::moisture,sat,a,void,v_at_a,r,peak,denominator,mr1,mr2,vr1,vr2
    shrink=0.0_real64;ok=.false.
    if(.not.peat_valid(theta_s,parameters,law))return
    if(.not.ieee_is_finite(theta))return
    if(theta<0.0_real64 .or. theta>theta_s)return
    sat=theta_s/(1.0_real64-theta_s);moisture=theta/(1.0_real64-theta_s)
    a=parameters%transition_moisture_ratio
    v_at_a=parameters%void_ratio_zero+(sat-parameters%void_ratio_zero)*a/sat
    if(law==SHRINK_PEAT_DIRECT)then
      void=parameters%void_ratio_zero+(sat-parameters%void_ratio_zero)*moisture/sat
      if(moisture<a)then
        r=moisture/a;peak=parameters%alpha/parameters%beta
        denominator=peak**parameters%alpha*(exp(-parameters%alpha)-exp(-parameters%beta))
        if(denominator<=tiny(1.0_real64))return
        void=void*(1.0_real64+parameters%p*r**parameters%alpha* &
             (exp(-parameters%beta*r)-exp(-parameters%beta))/denominator)
      end if
    else
      if(moisture>a)then
        mr1=sat;mr2=a;vr1=sat;vr2=v_at_a
      else if(moisture>parameters%intermediate_moisture_ratio)then
        mr1=a;mr2=parameters%intermediate_moisture_ratio
        vr1=v_at_a;vr2=parameters%intermediate_void_ratio
      else
        mr1=parameters%intermediate_moisture_ratio;mr2=0.0_real64
        vr1=parameters%intermediate_void_ratio;vr2=parameters%void_ratio_zero
      end if
      void=vr2+(vr1-vr2)*(moisture-mr2)/(mr1-mr2)
    end if
    if(.not.ieee_is_finite(void))return
    ! Void volume cannot contain less volume than liquid or exceed saturation.
    if(void<moisture-1.0e-14_real64 .or. void>sat+1.0e-14_real64)return
    shrink=max(0.0_real64,theta_s-void*(1.0_real64-theta_s))
    ok=ieee_is_finite(shrink) .and. shrink<1.0_real64
  end subroutine evaluate_peat_shrinkage_fraction

  pure logical function clay_kim_valid(self)
    class(clay_kim_shrinkage_t), intent(in) :: self
    clay_kim_valid = ieee_is_finite(self%alpha_k) .and. ieee_is_finite(self%beta_k) .and. &
         ieee_is_finite(self%gamma_k) .and. ieee_is_finite(self%transition_moisture_ratio) .and. &
         self%alpha_k > 0.0_real64 .and. abs(self%beta_k) > tiny(1.0_real64) .and. &
         self%transition_moisture_ratio >= 0.0_real64
  end function clay_kim_valid

  subroutine prepare_clay_kim_option1(theta_s, shr_par_a, shr_par_b, shr_par_c, parameters, ok)
    real(real64), intent(in) :: theta_s, shr_par_a, shr_par_b, shr_par_c
    type(clay_kim_shrinkage_t), intent(out) :: parameters
    logical, intent(out) :: ok
    real(real64) :: argument

    parameters = clay_kim_shrinkage_t()
    ok = .false.
    if (.not. ieee_is_finite(theta_s) .or. theta_s <= 0.0_real64 .or. theta_s >= 1.0_real64) return
    if (.not. ieee_is_finite(shr_par_a) .or. .not. ieee_is_finite(shr_par_b) .or. &
        .not. ieee_is_finite(shr_par_c)) return
    if (shr_par_a <= 0.0_real64 .or. abs(shr_par_b) <= tiny(1.0_real64)) return
    argument = (shr_par_c-1.0_real64)/(shr_par_a*shr_par_b)
    if (argument <= 0.0_real64) return
    parameters%alpha_k = shr_par_a
    parameters%beta_k = shr_par_b
    parameters%gamma_k = shr_par_c
    parameters%transition_moisture_ratio = -log(argument)/shr_par_b
    if (parameters%transition_moisture_ratio > theta_s/(1.0_real64-theta_s)-0.01_real64) return
    ok = parameters%valid()
  end subroutine prepare_clay_kim_option1

  subroutine prepare_clay_kim_option2(theta_s,zero_void,transition,parameters,ok)
    real(real64),intent(in)::theta_s,zero_void,transition
    type(clay_kim_shrinkage_t),intent(out)::parameters
    logical,intent(out)::ok
    parameters=clay_kim_shrinkage_t();ok=.false.
    if(.not.ieee_is_finite(theta_s) .or. .not.ieee_is_finite(zero_void) .or. &
       .not.ieee_is_finite(transition))return
    if(theta_s<=0.0_real64 .or. theta_s>=1.0_real64)return
    if(zero_void<=0.0_real64 .or. transition<sqrt(tiny(1.0_real64)) .or. zero_void>transition)return
    if(transition>theta_s/(1.0_real64-theta_s)-0.01_real64)return
    ! Exact finite root of A*(1+transition*beta)*exp(-transition*beta)=0.
    parameters%alpha_k=zero_void
    parameters%beta_k=-1.0_real64/transition
    parameters%gamma_k=1.0_real64-(zero_void/transition)*exp(1.0_real64)
    parameters%transition_moisture_ratio=transition
    ok=parameters%valid()
  end subroutine prepare_clay_kim_option2

  pure real(real64) function one_minus_exp_negative(x) result(value)
    real(real64),intent(in)::x
    if(x<1.0e-4_real64)then
      value=x*(1.0_real64-x/2.0_real64+x*x/6.0_real64-x*x*x/24.0_real64+x**4/120.0_real64)
    else
      value=1.0_real64-exp(-x)
    end if
  end function one_minus_exp_negative

  pure real(real64) function peat_point_shape(alpha,c1,c2) result(value)
    real(real64),intent(in)::alpha,c1,c2
    ! Algebraically exact scaling of the B1.11 residual; all exponent arguments <=0.
    value=exp(alpha*(log(c2)+1.0_real64-c2))* &
         one_minus_exp_negative(alpha*(c1-c2))/one_minus_exp_negative(alpha*(c1-1.0_real64))
  end function peat_point_shape

  subroutine prepare_peat_characteristic_points(theta_s,zero_void,transition,typical,peak,p,parameters,ok)
    real(real64),intent(in)::theta_s,zero_void,transition,typical,peak,p
    type(peat_shrinkage_t),intent(out)::parameters
    logical,intent(out)::ok
    type(peat_shrinkage_t)::trial
    real(real64)::sat,baseline,target,c1,c2,c3,lo,hi,mid,fmid,ratio,shrink,theta_typical
    integer::iteration
    logical::law_ok
    parameters=peat_shrinkage_t();ok=.false.
    if(.not.ieee_is_finite(theta_s) .or. .not.ieee_is_finite(zero_void) .or. &
       .not.ieee_is_finite(transition) .or. .not.ieee_is_finite(typical) .or. &
       .not.ieee_is_finite(peak) .or. .not.ieee_is_finite(p))return
    if(theta_s<=0.0_real64 .or. theta_s>=1.0_real64)return
    sat=theta_s/(1.0_real64-theta_s)
    if(zero_void<0.0_real64 .or. zero_void>=sat .or. transition>=sat)return
    if(typical<1.0e-8_real64 .or. peak<=typical .or. transition<=peak)return
    if(abs(p)<1.0e-8_real64 .or. abs(p)>10.0_real64)return
    ratio=peak/transition
    if(ratio<1.0e-5_real64)return
    c1=1.0_real64/ratio;c2=typical/peak
    baseline=zero_void+(sat-zero_void)*typical/sat
    if(p>0.0_real64)then
      target=zero_void+typical
    else
      target=0.5_real64*zero_void+typical
    end if
    c3=(target/baseline-1.0_real64)/p
    if(.not.ieee_is_finite(c3))return
    lo=0.001_real64;hi=10.0_real64
    if(peat_point_shape(lo,c1,c2)-peat_point_shape(hi,c1,c2)<=1.0e-10_real64)return
    if(c3>peat_point_shape(lo,c1,c2) .or. c3<peat_point_shape(hi,c1,c2))return
    do iteration=1,80
      mid=lo+0.5_real64*(hi-lo)
      fmid=peat_point_shape(mid,c1,c2)-c3
      if(abs(fmid)<=1.0e-13_real64*max(1.0_real64,abs(c3)) .and. &
         hi-lo<=1.0e-12_real64*max(1.0_real64,abs(mid)))exit
      if(fmid>0.0_real64)then
        lo=mid
      else
        hi=mid
      end if
    end do
    if(iteration>80)return
    trial%void_ratio_zero=zero_void
    trial%transition_moisture_ratio=transition
    trial%alpha=mid;trial%beta=mid/ratio;trial%p=p
    if(.not.peat_valid(theta_s,trial,SHRINK_PEAT_DIRECT))return
    theta_typical=typical*(1.0_real64-theta_s)
    call evaluate_peat_shrinkage_fraction(theta_typical,theta_s,trial,SHRINK_PEAT_DIRECT,shrink,law_ok)
    if(.not.law_ok)return
    if(abs((theta_s-shrink)/(1.0_real64-theta_s)-target)> &
       1.0e-12_real64*max(1.0_real64,abs(target)))return
    parameters=trial;ok=.true.
  end subroutine prepare_peat_characteristic_points

  subroutine evaluate_clay_kim_shrinkage_fraction(theta, theta_s, parameters, shrink_fraction, ok)
    real(real64), intent(in) :: theta, theta_s
    type(clay_kim_shrinkage_t), intent(in) :: parameters
    real(real64), intent(out) :: shrink_fraction
    logical, intent(out) :: ok
    real(real64) :: moisture_ratio, void_ratio, solid_volume_fraction

    ok = .false.
    shrink_fraction = 0.0_real64
    if (.not. parameters%valid()) return
    if (.not. ieee_is_finite(theta) .or. .not. ieee_is_finite(theta_s)) return
    if (theta < 0.0_real64 .or. theta_s <= 0.0_real64 .or. theta_s >= 1.0_real64 .or. theta > theta_s) return

    ! B1.11 SHRINK, clay mode: void ratio from the pinned source relation.
    solid_volume_fraction = 1.0_real64-theta_s
    moisture_ratio = theta/solid_volume_fraction
    if (moisture_ratio > parameters%transition_moisture_ratio) then
      void_ratio = moisture_ratio
    else
      void_ratio = parameters%alpha_k*exp(-parameters%beta_k*moisture_ratio) + &
           parameters%gamma_k*moisture_ratio
      void_ratio = max(void_ratio,parameters%alpha_k)
    end if
    ! B1.11 SHRINK returns relative shrinkage from void ratio and solid fraction.
    shrink_fraction = theta_s-void_ratio*solid_volume_fraction
    ok = ieee_is_finite(shrink_fraction) .and. shrink_fraction >= 0.0_real64 .and. shrink_fraction < 1.0_real64
  end subroutine evaluate_clay_kim_shrinkage_fraction

  subroutine evaluate_dynamic_crack_profile(config,theta,theta_previous,dz,matrix_area_fraction,accepted_dynamic_volume, &
                                              candidate_dynamic_volume,ok,candidate_subsidence_cm,active_node)
    type(dynamic_shrinkage_config_t),intent(in)::config
    real(real64),intent(in)::theta(:),theta_previous(:),dz(:),matrix_area_fraction(:),accepted_dynamic_volume(:)
    real(real64),allocatable,intent(out)::candidate_dynamic_volume(:)
    logical,intent(out)::ok
    real(real64),allocatable,intent(out),optional::candidate_subsidence_cm(:)
    integer,intent(in),optional::active_node
    type(dynamic_crack_request_t)::request
    real(real64)::shrink
    logical::local_ok
    integer::n,ic

    ok=.false.
    n=size(theta)
    allocate(candidate_dynamic_volume(n))
    if(present(candidate_subsidence_cm))allocate(candidate_subsidence_cm(n))
    candidate_dynamic_volume=0.0_real64
    if(present(candidate_subsidence_cm))candidate_subsidence_cm=0.0_real64
    if(size(accepted_dynamic_volume)/=n)return
    candidate_dynamic_volume=accepted_dynamic_volume
    if(.not.config%valid_for_nodes(n))return
    if(.not.config%enabled)then
      ok=.true.
      return
    end if
    if(size(theta_previous)/=n .or. size(dz)/=n .or. size(matrix_area_fraction)/=n .or. &
       size(accepted_dynamic_volume)/=n)return
    if(any(.not.ieee_is_finite(theta_previous)) .or. any(.not.ieee_is_finite(dz)) .or. &
       any(.not.ieee_is_finite(matrix_area_fraction)) .or. any(.not.ieee_is_finite(accepted_dynamic_volume)))return
    if(any(dz<=0.0_real64) .or. any(matrix_area_fraction<=0.0_real64) .or. &
       any(matrix_area_fraction>1.0_real64) .or. any(accepted_dynamic_volume<0.0_real64))return
    do ic=1,n
      call evaluate_node_shrinkage_fraction(config,ic,theta(ic),shrink,local_ok)
      if(.not.local_ok)return
      if(allocated(config%law))then
        if(config%law(ic)==SHRINK_RIGID)then
          candidate_dynamic_volume(ic)=0.0_real64
          cycle
        end if
      end if
      request=dynamic_crack_request_t()
      request%theta=theta(ic)
      request%theta_previous=theta_previous(ic)
      request%theta_s=config%theta_s(ic)
      request%theta_crack=config%theta_crack(ic)
      request%dz_cm=dz(ic)
      request%geometry_factor=config%geometry_factor(ic)
      request%matrix_area_fraction=matrix_area_fraction(ic)
      request%prior_dynamic_volume_cm=accepted_dynamic_volume(ic)
      request%neighbour_dynamic_volume_cm = accepted_dynamic_volume(max(1,ic-1)) + &
           accepted_dynamic_volume(min(n,ic+1))
      request%minimum_subsidence_cm=config%minimum_subsidence_cm(ic)
      if(present(candidate_subsidence_cm))then
        call evaluate_dynamic_crack_volume(request,shrink,candidate_dynamic_volume(ic),local_ok,candidate_subsidence_cm(ic))
      else
        call evaluate_dynamic_crack_volume(request,shrink,candidate_dynamic_volume(ic),local_ok)
      end if
      if(.not.local_ok)return
    end do
    if(present(active_node))then
      if(active_node<0 .or. active_node>n)return
      candidate_dynamic_volume(active_node+1:n)=0.0_real64
      if(present(candidate_subsidence_cm))candidate_subsidence_cm(active_node+1:n)=0.0_real64
    end if
    ok=.true.
  end subroutine evaluate_dynamic_crack_profile

  pure integer function find_dynamic_groundwater_cutoff(head,z,dz,bottom_mode) result(cutoff)
    real(real64),intent(in)::head(:),z(:),dz(:)
    integer,intent(in)::bottom_mode
    real(real64)::water_level,spacing
    integer::n,node,i
    n=size(head);cutoff=n+1
    if(n<1 .or. size(z)/=n .or. size(dz)/=n)return
    if(any(.not.ieee_is_finite(head)) .or. any(.not.ieee_is_finite(z)) .or. &
       any(.not.ieee_is_finite(dz)))return
    if(any(dz<=0.0_real64))return
    if(bottom_mode==1)then
      if(all(head>=0.0_real64))cutoff=1
      return
    end if
    if(head(n)<0.0_real64)return
    do node=n-1,1,-1
      if(head(node)<0.0_real64)then
        if(head(node+1)>=0.0_real64)then
          spacing=abs(z(node+1)-z(node))
          if(spacing<=0.0_real64)return
          water_level=z(node+1)+head(node+1)/(head(node+1)-head(node))*spacing
        else
          water_level=z(node)-0.5_real64*dz(node)-head(node)
          water_level=min(z(node),max(z(node)-0.5_real64*dz(node),water_level))
        end if
        i=max(node-2,1)
        do while(i<n .and. z(i)-0.5_real64*dz(i)>water_level)
          i=i+1
        end do
        cutoff=i
        return
      end if
    end do
    cutoff=1
  end function find_dynamic_groundwater_cutoff

  subroutine evaluate_dynamic_crack_volume(request, shrink_fraction, dynamic_volume_cm, ok, subsidence_result_cm)
    type(dynamic_crack_request_t), intent(in) :: request
    real(real64), intent(in) :: shrink_fraction
    real(real64), intent(out) :: dynamic_volume_cm
    logical, intent(out) :: ok
    real(real64),intent(out),optional::subsidence_result_cm
    real(real64) :: shrink_volume_cm, critical_theta, subsidence_cm

    ok = .false.
    dynamic_volume_cm = 0.0_real64
    if(present(subsidence_result_cm))subsidence_result_cm=0.0_real64
    if (.not. ieee_is_finite(shrink_fraction) .or. shrink_fraction < 0.0_real64 .or. shrink_fraction >= 1.0_real64) return
    if (.not. ieee_is_finite(request%theta) .or. .not. ieee_is_finite(request%theta_previous) .or. &
        .not. ieee_is_finite(request%theta_s) .or. .not. ieee_is_finite(request%theta_crack) .or. &
        .not. ieee_is_finite(request%dz_cm) .or. .not. ieee_is_finite(request%geometry_factor) .or. &
        .not. ieee_is_finite(request%matrix_area_fraction) .or. &
        .not. ieee_is_finite(request%prior_dynamic_volume_cm) .or. &
        .not. ieee_is_finite(request%neighbour_dynamic_volume_cm) .or. &
        .not. ieee_is_finite(request%minimum_subsidence_cm)) return
    if (request%theta_s <= 0.0_real64 .or. request%theta_s > 1.0_real64) return
    if (request%theta_crack < 0.0_real64 .or. request%theta_crack > request%theta_s) return
    if (request%dz_cm <= 0.0_real64 .or. request%geometry_factor <= 0.0_real64) return
    if (request%matrix_area_fraction <= 0.0_real64 .or. request%matrix_area_fraction > 1.0_real64) return
    if (request%prior_dynamic_volume_cm < 0.0_real64 .or. request%neighbour_dynamic_volume_cm < 0.0_real64 .or. &
        request%minimum_subsidence_cm < 0.0_real64) return

    if (request%theta >= request%theta_s-1.0e-4_real64) then
      ok = .true.
      return
    end if

    shrink_volume_cm = shrink_fraction*request%dz_cm
    if (request%theta > request%theta_previous-1.0e-8_real64 .and. &
        (request%prior_dynamic_volume_cm > 0.0_real64 .or. request%neighbour_dynamic_volume_cm > 0.0_real64)) then
      critical_theta = request%theta_s
    else
      critical_theta = request%theta_crack
    end if

    if (request%theta < critical_theta) then
      subsidence_cm = (1.0_real64-(1.0_real64-shrink_fraction)**(1.0_real64/request%geometry_factor))*request%dz_cm
      subsidence_cm = max(subsidence_cm, request%minimum_subsidence_cm)
      if (subsidence_cm >= request%dz_cm) return
      dynamic_volume_cm = request%matrix_area_fraction*(shrink_volume_cm-subsidence_cm)*request%dz_cm / &
           (request%dz_cm-subsidence_cm)
      if(dynamic_volume_cm<0.0_real64)then
        subsidence_cm=subsidence_cm+dynamic_volume_cm
        dynamic_volume_cm=0.0_real64
      end if
    else
      subsidence_cm=shrink_volume_cm
    end if
    if(present(subsidence_result_cm))subsidence_result_cm=subsidence_cm
    ok = .true.
  end subroutine evaluate_dynamic_crack_volume

end module mod_macropore_dynamic_shrinkage

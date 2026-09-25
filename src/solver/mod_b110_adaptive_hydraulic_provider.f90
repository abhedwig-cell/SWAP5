module mod_b110_adaptive_hydraulic_provider
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_soil_water_solver_contract, only: constitutive_hydraulics_provider_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_adaptive_hydraulic_builder, only: b110_adaptive_hydraulic_table_t
  use mod_b110_adaptive_hydraulic_cache, only: b110_adaptive_hydraulic_cache_t, b110_adaptive_hydraulic_cache_key_t, &
       make_b110_adaptive_hydraulic_key, b110_adaptive_hydraulic_keys_equal
  implicit none
  private

  real(real64), parameter :: LOOKUP_H_MAX=-1.0_real64
  real(real64), parameter :: LOOKUP_H_MIN=-1.0e6_real64
  real(real64), parameter :: LN10=log(10.0_real64)
  integer, parameter :: POLICY_VERSION=4, BRANCH_POLICY_VERSION=1
  character(len=*), parameter :: MODEL_ID='B110_DEFAULT_MVG'

  type(b110_adaptive_hydraulic_cache_t), save :: shared_cache

  type, extends(constitutive_hydraulics_provider_t), public :: b110_adaptive_hydraulic_provider_t
    private
    type(b110_default_mvg_provider_t) :: analytical
    real(real64), pointer :: cofgen(:,:) => null()
    type(b110_adaptive_hydraulic_table_t) :: table
    integer :: registry_slot=0
    logical :: registry_handle_active=.false.
    real(real64) :: registry_xmin=0.0_real64, registry_xmax=0.0_real64
    type(b110_adaptive_hydraulic_cache_key_t) :: representation_key
    logical :: representation_key_valid=.false.
    logical :: ready=.false.
    logical :: acquired_from_cache=.false.
  contains
    procedure :: evaluate => b110_adaptive_hydraulic_evaluate
  end type b110_adaptive_hydraulic_provider_t

  public :: bind_b110_adaptive_hydraulic_provider
  public :: b110_adaptive_hydraulic_profile_supported
  public :: b110_adaptive_hydraulic_cache_stats

contains

  pure logical function b110_adaptive_hydraulic_profile_supported(parameters) result(supported)
    type(b110_default_mvg_parameters_t),intent(in)::parameters
    integer(int64) :: reference_bits(42), node_bits(42)
    integer :: i

    supported=.false.
    if(.not.allocated(parameters%cofgen))return
    if(parameters%active_nodes<1 .or. size(parameters%cofgen,1)<42) return
    if(size(parameters%cofgen,2)<parameters%active_nodes) return

    ! The admitted provider owns one immutable representation. Until layered
    ! AHL is separately qualified, use it only when every active node has the
    ! exact same initialized hydraulic authority. Heterogeneous profiles must
    ! stay on the authoritative analytical provider.
    reference_bits=transfer(parameters%cofgen(1:42,1),reference_bits)
    do i=2,parameters%active_nodes
      node_bits=transfer(parameters%cofgen(1:42,i),node_bits)
      if(any(node_bits/=reference_bits))return
    end do
    supported=.true.
  end function b110_adaptive_hydraulic_profile_supported

  subroutine bind_b110_adaptive_hydraulic_provider(provider,parameters,step_duration,ok,was_hit,prefer_registry_handle)
    type(b110_adaptive_hydraulic_provider_t),intent(inout)::provider
    type(b110_default_mvg_parameters_t),target,intent(in)::parameters
    real(real64),intent(in)::step_duration
    logical,intent(out)::ok,was_hit
    logical,intent(in),optional::prefer_registry_handle

    type(b110_default_mvg_parameters_t),target :: sampler_parameters
    type(b110_default_mvg_provider_t) :: sampler
    type(b110_adaptive_hydraulic_cache_key_t) :: key
    real(real64) :: one_node_input(42,1)
    logical :: same_representation,slot_ok,use_handle
    integer :: slot

    ok=.false.;was_hit=.false.
    use_handle=.true.
    if(present(prefer_registry_handle))use_handle=prefer_registry_handle
    if(parameters%active_nodes<=0 .or. .not.allocated(parameters%cofgen))then
      provider%ready=.false.
      return
    end if
    if(size(parameters%cofgen,1)<42)then
      provider%ready=.false.
      return
    end if
    if(.not.b110_adaptive_hydraulic_profile_supported(parameters))then
      provider%ready=.false.
      return
    end if

    ! Step-dependent analytical semantics are always rebound. Only the immutable
    ! adaptive representation may survive a same-key rebind.
    call bind_b110_default_mvg_provider(provider%analytical,parameters,step_duration)
    provider%cofgen=>parameters%cofgen

    ! Same-provider reuse does not need to rebuild/hash the shared-cache key.
    ! Compare the exact initialized hydraulic authority directly. The full
    ! collision-safe cache key is constructed only when this fast path misses.
    same_representation = provider%ready .and. provider%representation_key_valid .and. &
         (provider%registry_handle_active .or. allocated(provider%table%x)) .and. &
         same_local_authority(provider%representation_key,parameters)
    if(same_representation)then
      provider%acquired_from_cache=.true.
      was_hit=.true.
      ok=.true.
      return
    end if

    provider%ready=.false.
    provider%representation_key_valid=.false.
    provider%registry_handle_active=.false.
    provider%registry_slot=0
    provider%registry_xmin=0.0_real64
    provider%registry_xmax=0.0_real64
    key=make_b110_adaptive_hydraulic_key(parameters,MODEL_ID,POLICY_VERSION,BRANCH_POLICY_VERSION)

    ! F-AHL35: changed authority first queries the exact-key registry. The
    ! one-node authoritative sampler is only required after a genuine registry
    ! miss to construct a new immutable representation.
    if(use_handle)then
      call shared_cache%find_slot(key,slot,was_hit)
      if(was_hit)then
        call shared_cache%slot_bounds(slot,provider%registry_xmin,provider%registry_xmax,slot_ok)
        if(.not.slot_ok)return
        provider%registry_slot=slot
        provider%registry_handle_active=.true.
        ok=.true.
      else
        one_node_input(:,1)=parameters%cofgen(1:42,1)
        call initialize_b110_default_mvg_parameters(sampler_parameters,one_node_input, &
             parameters%ksatexm_extension_enabled)
        call bind_b110_default_mvg_provider(sampler,sampler_parameters,step_duration)
        call shared_cache%get_or_build(key,sampler_parameters,sampler,provider%table,was_hit,ok)
        if(.not.ok)return
        call shared_cache%find_slot(key,slot,slot_ok,.false.)
        if(slot_ok)then
          call shared_cache%slot_bounds(slot,provider%registry_xmin,provider%registry_xmax,slot_ok)
          if(.not.slot_ok)return
          provider%registry_slot=slot
          provider%registry_handle_active=.true.
        end if
      end if
    else
      call shared_cache%lookup(key,provider%table,was_hit)
      if(was_hit)then
        ok=.true.
      else
        one_node_input(:,1)=parameters%cofgen(1:42,1)
        call initialize_b110_default_mvg_parameters(sampler_parameters,one_node_input, &
             parameters%ksatexm_extension_enabled)
        call bind_b110_default_mvg_provider(sampler,sampler_parameters,step_duration)
        call shared_cache%get_or_build(key,sampler_parameters,sampler,provider%table,was_hit,ok)
        if(.not.ok)return
      end if
    end if
    provider%representation_key=key
    provider%representation_key_valid=.true.
    provider%acquired_from_cache=was_hit
    provider%ready=.true.
  end subroutine bind_b110_adaptive_hydraulic_provider

  pure logical function same_local_authority(key,parameters) result(equal)
    type(b110_adaptive_hydraulic_cache_key_t),intent(in)::key
    type(b110_default_mvg_parameters_t),intent(in)::parameters
    integer(int64) :: key_bits(42), parameter_bits(42)

    equal=.false.
    if(.not.allocated(parameters%cofgen))return
    if(parameters%active_nodes<1 .or. size(parameters%cofgen,1)<42)return
    if(key%ksatexm_extension_enabled .neqv. parameters%ksatexm_extension_enabled)return
    key_bits=transfer(key%coeff,key_bits)
    parameter_bits=transfer(parameters%cofgen(1:42,1),parameter_bits)
    equal=all(key_bits==parameter_bits)
  end function same_local_authority

  subroutine b110_adaptive_hydraulic_evaluate(self,pressure_head,water_content,conductivity,capacity,dconductivity_dhead)
    class(b110_adaptive_hydraulic_provider_t),intent(in)::self
    real(real64),intent(in)::pressure_head(:)
    real(real64),intent(out)::water_content(:),conductivity(:),capacity(:),dconductivity_dhead(:)

    real(real64) :: wa(size(pressure_head)),ka(size(pressure_head)),ca(size(pressure_head)),da(size(pressure_head))
    real(real64) :: xv,f,dx,t,h00,h10,h01,h11,dh00,h10d,dh01,dh11,zz,dz_x,se,span
    real(real64) :: x0,x1,z0,z1,m0,m1,k0,k1
    integer :: i,idx
    logical :: inside,need_fallback

    if(.not.self%ready .or. .not.associated(self%cofgen))error stop 'B110 adaptive hydraulic provider not ready'

    need_fallback=any(pressure_head>LOOKUP_H_MAX)
    if(self%registry_handle_active)then
      do i=1,size(pressure_head)
        if(pressure_head(i)<=LOOKUP_H_MAX)then
          xv=log10(-pressure_head(i))
          if(xv<self%registry_xmin .or. xv>self%registry_xmax)need_fallback=.true.
        end if
      end do
    else
      if(.not.allocated(self%table%x))error stop 'B110 adaptive hydraulic provider table missing'
      if(any(log10(max(-pressure_head,tiny(1.0_real64)))<self%table%x(1)) .or. &
           any(log10(max(-pressure_head,tiny(1.0_real64)))>self%table%x(self%table%n)))need_fallback=.true.
    end if
    if(need_fallback)call self%analytical%evaluate(pressure_head,wa,ka,ca,da)

    do i=1,size(pressure_head)
      if(pressure_head(i)<=LOOKUP_H_MAX)then
        xv=log10(-pressure_head(i))
      else
        xv=0.0_real64
      end if

      if(self%registry_handle_active)then
        if(pressure_head(i)<=LOOKUP_H_MAX .and. xv>=self%registry_xmin .and. xv<=self%registry_xmax)then
          call shared_cache%sample_slot(self%registry_slot,xv,inside,x0,x1,z0,z1,m0,m1,k0,k1)
          if(.not.inside)error stop 'B110 adaptive hydraulic registry handle invalid'
          dx=x1-x0;f=(xv-x0)/dx;t=f
          h00=2*t**3-3*t**2+1;h10=t**3-2*t**2+t;h01=-2*t**3+3*t**2;h11=t**3-t**2
          zz=h00*z0+h10*dx*m0+h01*z1+h11*dx*m1
          dh00=6*t*t-6*t;h10d=3*t*t-4*t+1;dh01=-6*t*t+6*t;dh11=3*t*t-2*t
          dz_x=(dh00*z0+h10d*dx*m0+dh01*z1+dh11*dx*m1)/dx
          if(zz>=0.0_real64)then
            se=1.0_real64/(1.0_real64+exp(-zz))
          else
            se=exp(zz)/(1.0_real64+exp(zz))
          end if
          span=self%cofgen(2,i)-self%cofgen(1,i)
          water_content(i)=self%cofgen(1,i)+span*se
          capacity(i)=(span*se*(1.0_real64-se)*dz_x)/(pressure_head(i)*LN10)
          conductivity(i)=exp(k0+f*(k1-k0))
          dconductivity_dhead(i)=0.0_real64
        else
          water_content(i)=wa(i);conductivity(i)=ka(i);capacity(i)=ca(i);dconductivity_dhead(i)=da(i)
        end if
      else
        if(pressure_head(i)<=LOOKUP_H_MAX .and. xv>=self%table%x(1) .and. xv<=self%table%x(self%table%n))then
          call locate(self%table%x,xv,idx,f)
          dx=self%table%x(idx+1)-self%table%x(idx);t=f
          h00=2*t**3-3*t**2+1;h10=t**3-2*t**2+t;h01=-2*t**3+3*t**2;h11=t**3-t**2
          zz=h00*self%table%z(idx)+h10*dx*self%table%dzdx(idx)+ &
             h01*self%table%z(idx+1)+h11*dx*self%table%dzdx(idx+1)
          dh00=6*t*t-6*t;h10d=3*t*t-4*t+1;dh01=-6*t*t+6*t;dh11=3*t*t-2*t
          dz_x=(dh00*self%table%z(idx)+h10d*dx*self%table%dzdx(idx)+ &
               dh01*self%table%z(idx+1)+dh11*dx*self%table%dzdx(idx+1))/dx
          if(zz>=0.0_real64)then
            se=1.0_real64/(1.0_real64+exp(-zz))
          else
            se=exp(zz)/(1.0_real64+exp(zz))
          end if
          span=self%cofgen(2,i)-self%cofgen(1,i)
          water_content(i)=self%cofgen(1,i)+span*se
          capacity(i)=(span*se*(1.0_real64-se)*dz_x)/(pressure_head(i)*LN10)
          conductivity(i)=exp(self%table%logk(idx)+f*(self%table%logk(idx+1)-self%table%logk(idx)))
          dconductivity_dhead(i)=0.0_real64
        else
          water_content(i)=wa(i);conductivity(i)=ka(i);capacity(i)=ca(i);dconductivity_dhead(i)=da(i)
        end if
      end if
    end do
  end subroutine b110_adaptive_hydraulic_evaluate

  subroutine b110_adaptive_hydraulic_cache_stats(builds,hits,misses,entries)
    integer,intent(out)::builds,hits,misses,entries
    call shared_cache%stats(builds,hits,misses,entries)
  end subroutine b110_adaptive_hydraulic_cache_stats

  pure subroutine locate(x,value,idx,fraction)
    real(real64),intent(in)::x(:),value
    integer,intent(out)::idx
    real(real64),intent(out)::fraction
    integer::lo,hi,mid,n
    n=size(x)
    if(value<=x(1))then;idx=1;fraction=0.0_real64;return;end if
    if(value>=x(n))then;idx=n-1;fraction=1.0_real64;return;end if
    lo=1;hi=n
    do while(hi-lo>1)
      mid=(lo+hi)/2
      if(x(mid)<=value)then;lo=mid;else;hi=mid;end if
    end do
    idx=lo;fraction=(value-x(lo))/(x(lo+1)-x(lo))
  end subroutine locate

end module mod_b110_adaptive_hydraulic_provider

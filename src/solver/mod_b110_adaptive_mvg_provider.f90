module mod_b110_adaptive_mvg_provider
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: constitutive_hydraulics_provider_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_adaptive_hydraulic_builder, only: b110_adaptive_hydraulic_table_t
  use mod_b110_adaptive_hydraulic_cache, only: b110_adaptive_hydraulic_cache_t, &
       b110_adaptive_hydraulic_cache_key_t, make_b110_adaptive_hydraulic_key, b110_adaptive_same_key
  implicit none
  private

  real(real64), parameter :: LOOKUP_H_MAX=-1.0_real64
  real(real64), parameter :: LOOKUP_H_MIN=-1.0e6_real64
  real(real64), parameter :: LN10=log(10.0_real64)
  integer, parameter :: POLICY_VERSION=1, BRANCH_POLICY_VERSION=1
  character(len=*), parameter :: MODEL_ID='B110_DEFAULT_MVG'

  type, extends(constitutive_hydraulics_provider_t), public :: b110_adaptive_mvg_provider_t
    private
    type(b110_default_mvg_provider_t) :: analytical
    type(b110_adaptive_hydraulic_cache_t) :: cache
    real(real64), pointer :: cofgen(:,:) => null()
    type(b110_adaptive_hydraulic_table_t), allocatable :: material_table(:)
    type(b110_adaptive_hydraulic_cache_key_t), allocatable :: material_key(:)
    integer, allocatable :: node_material(:)
    integer :: material_count=0
    logical :: ready=.false.
    logical :: acquired_from_cache=.false.
  contains
    procedure :: evaluate => b110_adaptive_mvg_evaluate
    procedure :: cache_stats => b110_adaptive_mvg_provider_cache_stats
    procedure :: unique_material_count => b110_adaptive_mvg_unique_material_count
  end type b110_adaptive_mvg_provider_t

  public :: bind_b110_adaptive_mvg_provider
  public :: b110_adaptive_mvg_cache_stats

contains

  subroutine bind_b110_adaptive_mvg_provider(provider,parameters,step_duration,ok,was_hit)
    type(b110_adaptive_mvg_provider_t),intent(inout)::provider
    type(b110_default_mvg_parameters_t),target,intent(in)::parameters
    real(real64),intent(in)::step_duration
    logical,intent(out)::ok,was_hit

    type(b110_default_mvg_parameters_t),target :: sampler_parameters
    type(b110_default_mvg_provider_t) :: sampler
    type(b110_adaptive_hydraulic_cache_key_t) :: key
    real(real64) :: one_node_input(42,1)
    logical :: cache_hit, cache_ok, found, all_hit
    integer :: i,j,n,material_index

    ok=.false.;was_hit=.false.;provider%ready=.false.;provider%acquired_from_cache=.false.
    if(parameters%active_nodes<=0 .or. .not.allocated(parameters%cofgen))return
    if(size(parameters%cofgen,1)<42 .or. size(parameters%cofgen,2)<parameters%active_nodes)return

    call bind_b110_default_mvg_provider(provider%analytical,parameters,step_duration)
    provider%cofgen=>parameters%cofgen
    n=parameters%active_nodes

    if(allocated(provider%material_table)) deallocate(provider%material_table)
    if(allocated(provider%material_key)) deallocate(provider%material_key)
    if(allocated(provider%node_material)) deallocate(provider%node_material)
    allocate(provider%material_table(n),provider%material_key(n),provider%node_material(n))
    provider%node_material=0
    provider%material_count=0
    all_hit=.true.

    do i=1,n
      one_node_input(:,1)=parameters%cofgen(1:42,i)
      call initialize_b110_default_mvg_parameters(sampler_parameters,one_node_input, &
           parameters%ksatexm_extension_enabled)
      call bind_b110_default_mvg_provider(sampler,sampler_parameters,step_duration)
      key=make_b110_adaptive_hydraulic_key(sampler_parameters,MODEL_ID,POLICY_VERSION,BRANCH_POLICY_VERSION)

      found=.false.
      material_index=0
      do j=1,provider%material_count
        if(b110_adaptive_same_key(provider%material_key(j),key))then
          found=.true.
          material_index=j
          exit
        end if
      end do

      if(.not.found)then
        material_index=provider%material_count+1
        call provider%cache%get_or_build(key,sampler_parameters,sampler,provider%material_table(material_index), &
             cache_hit,cache_ok)
        if(.not.cache_ok)return
        provider%material_count=material_index
        provider%material_key(material_index)=key
        if(.not.cache_hit)all_hit=.false.
      end if
      provider%node_material(i)=material_index
    end do

    if(provider%material_count<=0 .or. any(provider%node_material<=0))return
    provider%acquired_from_cache=all_hit
    provider%ready=.true.
    was_hit=all_hit
    ok=.true.
  end subroutine bind_b110_adaptive_mvg_provider

  subroutine b110_adaptive_mvg_evaluate(self,pressure_head,water_content,conductivity,capacity,dconductivity_dhead)
    class(b110_adaptive_mvg_provider_t),intent(in)::self
    real(real64),intent(in)::pressure_head(:)
    real(real64),intent(out)::water_content(:),conductivity(:),capacity(:),dconductivity_dhead(:)

    real(real64) :: wa(size(pressure_head)),ka(size(pressure_head)),ca(size(pressure_head)),da(size(pressure_head))
    real(real64) :: xv,f,dx,t,h00,h10,h01,h11,dh00,dh10,dh01,dh11,zz,dz_x,se,span
    integer :: i,idx,m

    if(.not.self%ready .or. .not.associated(self%cofgen))error stop 'B110 adaptive provider not ready'
    if(size(pressure_head)/=size(self%node_material))error stop 'B110 adaptive provider node shape mismatch'

    if(any(pressure_head>LOOKUP_H_MAX) .or. any(pressure_head<LOOKUP_H_MIN))then
      call self%analytical%evaluate(pressure_head,wa,ka,ca,da)
    end if

    do i=1,size(pressure_head)
      if(pressure_head(i)<=LOOKUP_H_MAX .and. pressure_head(i)>=LOOKUP_H_MIN)then
        m=self%node_material(i)
        if(m<1 .or. m>self%material_count)error stop 'B110 adaptive provider material mapping invalid'
        xv=log10(-pressure_head(i))
        call locate(self%material_table(m)%x,xv,idx,f)
        dx=self%material_table(m)%x(idx+1)-self%material_table(m)%x(idx);t=f
        h00=2*t**3-3*t**2+1;h10=t**3-2*t**2+t;h01=-2*t**3+3*t**2;h11=t**3-t**2
        zz=h00*self%material_table(m)%z(idx)+h10*dx*self%material_table(m)%dzdx(idx)+ &
           h01*self%material_table(m)%z(idx+1)+h11*dx*self%material_table(m)%dzdx(idx+1)
        dh00=6*t*t-6*t;dh10=3*t*t-4*t+1;dh01=-6*t*t+6*t;dh11=3*t*t-2*t
        dz_x=(dh00*self%material_table(m)%z(idx)+dh10*dx*self%material_table(m)%dzdx(idx)+ &
             dh01*self%material_table(m)%z(idx+1)+dh11*dx*self%material_table(m)%dzdx(idx+1))/dx
        if(zz>=0.0_real64)then
          se=1.0_real64/(1.0_real64+exp(-zz))
        else
          se=exp(zz)/(1.0_real64+exp(zz))
        end if
        span=self%cofgen(2,i)-self%cofgen(1,i)
        water_content(i)=self%cofgen(1,i)+span*se
        capacity(i)=(span*se*(1.0_real64-se)*dz_x)/(pressure_head(i)*LN10)
        conductivity(i)=exp(self%material_table(m)%logk(idx)+ &
             f*(self%material_table(m)%logk(idx+1)-self%material_table(m)%logk(idx)))
        dconductivity_dhead(i)=0.0_real64
      else
        water_content(i)=wa(i);conductivity(i)=ka(i);capacity(i)=ca(i);dconductivity_dhead(i)=da(i)
      end if
    end do
  end subroutine b110_adaptive_mvg_evaluate

  subroutine b110_adaptive_mvg_provider_cache_stats(self,builds,hits,misses,entries)
    class(b110_adaptive_mvg_provider_t),intent(in)::self
    integer,intent(out)::builds,hits,misses,entries
    call self%cache%stats(builds,hits,misses,entries)
  end subroutine b110_adaptive_mvg_provider_cache_stats

  integer function b110_adaptive_mvg_unique_material_count(self) result(count)
    class(b110_adaptive_mvg_provider_t),intent(in)::self
    count=self%material_count
  end function b110_adaptive_mvg_unique_material_count

  subroutine b110_adaptive_mvg_cache_stats(provider,builds,hits,misses,entries)
    type(b110_adaptive_mvg_provider_t),intent(in)::provider
    integer,intent(out)::builds,hits,misses,entries
    call provider%cache_stats(builds,hits,misses,entries)
  end subroutine b110_adaptive_mvg_cache_stats

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

end module mod_b110_adaptive_mvg_provider

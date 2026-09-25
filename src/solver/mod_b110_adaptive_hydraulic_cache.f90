module mod_b110_adaptive_hydraulic_cache
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t
  use mod_b110_adaptive_hydraulic_builder, only: b110_adaptive_hydraulic_table_t, build_b110_adaptive_hydraulic_table
  implicit none
  private

  integer, parameter, public :: B110_AHL_MAX_CACHE=16384
  integer, parameter :: NCOEF=42

  type, public :: b110_adaptive_hydraulic_cache_key_t
    character(len=32) :: model_id=''
    integer :: policy_version=0
    integer :: branch_policy_version=0
    real(real64) :: coeff(NCOEF)=0.0_real64
    logical :: ksatexm_extension_enabled=.false.
    integer(int64) :: fingerprint=0_int64
  end type b110_adaptive_hydraulic_cache_key_t

  type :: b110_adaptive_hydraulic_cache_entry_t
    logical :: occupied=.false.
    type(b110_adaptive_hydraulic_cache_key_t) :: key
    type(b110_adaptive_hydraulic_table_t) :: table
  end type b110_adaptive_hydraulic_cache_entry_t

  type, public :: b110_adaptive_hydraulic_cache_t
    private
    type(b110_adaptive_hydraulic_cache_entry_t), allocatable :: entry(:)
    integer :: builds=0, hits=0, misses=0
    integer(int64) :: total_probes=0_int64
    integer :: max_probes=0
  contains
    procedure :: lookup => b110_ahl_lookup
    procedure :: find_slot => b110_ahl_find_slot
    procedure :: sample_slot => b110_ahl_sample_slot
    procedure :: slot_bounds => b110_ahl_slot_bounds
    procedure :: get_or_build => b110_ahl_get_or_build
    procedure :: stats => b110_ahl_stats
    procedure :: probe_stats => b110_ahl_probe_stats
  end type b110_adaptive_hydraulic_cache_t

  public :: make_b110_adaptive_hydraulic_key, b110_adaptive_hydraulic_keys_equal

contains

  function make_b110_adaptive_hydraulic_key(parameters,model_id,policy_version,branch_policy_version,node_index) result(key)
    type(b110_default_mvg_parameters_t),intent(in)::parameters
    character(len=*),intent(in)::model_id
    integer,intent(in)::policy_version,branch_policy_version
    integer,intent(in),optional::node_index
    type(b110_adaptive_hydraulic_cache_key_t)::key
    integer::i,node
    integer(int64)::bits,h

    if(.not.allocated(parameters%cofgen)) error stop 'B110 AHL key: cofgen not allocated'
    if(parameters%active_nodes<1) error stop 'B110 AHL key: no active nodes'
    node=1
    if(present(node_index))node=node_index
    if(node<1 .or. node>parameters%active_nodes) error stop 'B110 AHL key: invalid node index'

    key%model_id=''
    key%model_id(1:min(len_trim(model_id),len(key%model_id)))=model_id(1:min(len_trim(model_id),len(key%model_id)))
    key%policy_version=policy_version
    key%branch_policy_version=branch_policy_version
    if(size(parameters%cofgen,1)<NCOEF) error stop 'B110 AHL key: incomplete initialized cofgen'
    if(size(parameters%cofgen,2)/=parameters%active_nodes) error stop 'B110 AHL key: invalid node shape'
    key%coeff=parameters%cofgen(1:NCOEF,node)
    key%ksatexm_extension_enabled=parameters%ksatexm_extension_enabled

    h=transfer(key%coeff(1),h)
    do i=2,NCOEF
      bits=transfer(key%coeff(i),bits)
      h=ieor(ishftc(h,7),bits)
    end do
    if(key%ksatexm_extension_enabled) h=ieor(ishftc(h,13),int(z'5A17E1',int64))
    h=ieor(h,int(policy_version,int64))
    h=ieor(ishftc(h,11),int(branch_policy_version,int64))
    do i=1,len_trim(key%model_id)
      h=ieor(ishftc(h,5),int(iachar(key%model_id(i:i)),int64))
    end do
    key%fingerprint=h
  end function make_b110_adaptive_hydraulic_key

  logical function b110_adaptive_hydraulic_keys_equal(a,b) result(equal)
    type(b110_adaptive_hydraulic_cache_key_t),intent(in)::a,b
    integer(int64) :: abit(NCOEF), bbit(NCOEF)
    abit=transfer(a%coeff,abit)
    bbit=transfer(b%coeff,bbit)
    equal = a%fingerprint==b%fingerprint .and. &
         a%policy_version==b%policy_version .and. &
         a%branch_policy_version==b%branch_policy_version .and. &
         (a%ksatexm_extension_enabled .eqv. b%ksatexm_extension_enabled) .and. &
         trim(a%model_id)==trim(b%model_id) .and. &
         all(abit==bbit)
  end function b110_adaptive_hydraulic_keys_equal

  subroutine b110_ahl_find_slot(self,key,slot,was_hit,count_hit)
    class(b110_adaptive_hydraulic_cache_t),intent(inout)::self
    type(b110_adaptive_hydraulic_cache_key_t),intent(in)::key
    integer,intent(out)::slot
    logical,intent(out)::was_hit
    logical,intent(in),optional::count_hit
    integer::i,current
    logical::do_count

    slot=0;was_hit=.false.
    do_count=.true.
    if(present(count_hit))do_count=count_hit
    if(.not.allocated(self%entry)) return

    current=b110_ahl_initial_slot(key%fingerprint)
    do i=1,B110_AHL_MAX_CACHE
      self%total_probes=self%total_probes+1_int64
      self%max_probes=max(self%max_probes,i)
      if(.not.self%entry(current)%occupied) return
      if(self%entry(current)%key%fingerprint==key%fingerprint)then
        if(b110_adaptive_hydraulic_keys_equal(self%entry(current)%key,key))then
          if(do_count)self%hits=self%hits+1
          slot=current
          was_hit=.true.
          return
        end if
      end if
      current=current+1
      if(current>B110_AHL_MAX_CACHE) current=1
    end do
  end subroutine b110_ahl_find_slot

  subroutine b110_ahl_slot_bounds(self,slot,xmin,xmax,ok)
    class(b110_adaptive_hydraulic_cache_t),intent(in)::self
    integer,intent(in)::slot
    real(real64),intent(out)::xmin,xmax
    logical,intent(out)::ok
    integer::n

    xmin=0.0_real64;xmax=0.0_real64;ok=.false.
    if(.not.allocated(self%entry))return
    if(slot<1 .or. slot>size(self%entry))return
    if(.not.self%entry(slot)%occupied)return
    n=self%entry(slot)%table%n
    if(n<2 .or. .not.allocated(self%entry(slot)%table%x))return
    xmin=self%entry(slot)%table%x(1)
    xmax=self%entry(slot)%table%x(n)
    ok=.true.
  end subroutine b110_ahl_slot_bounds

  subroutine b110_ahl_sample_slot(self,slot,xv,inside,x0,x1,z0,z1,m0,m1,k0,k1)
    class(b110_adaptive_hydraulic_cache_t),intent(in)::self
    integer,intent(in)::slot
    real(real64),intent(in)::xv
    logical,intent(out)::inside
    real(real64),intent(out)::x0,x1,z0,z1,m0,m1,k0,k1
    integer::lo,hi,mid,n

    inside=.false.
    x0=0.0_real64;x1=0.0_real64;z0=0.0_real64;z1=0.0_real64
    m0=0.0_real64;m1=0.0_real64;k0=0.0_real64;k1=0.0_real64
    if(.not.allocated(self%entry))return
    if(slot<1 .or. slot>size(self%entry))return
    if(.not.self%entry(slot)%occupied)return
    n=self%entry(slot)%table%n
    if(n<2 .or. .not.allocated(self%entry(slot)%table%x))return
    if(xv<self%entry(slot)%table%x(1) .or. xv>self%entry(slot)%table%x(n))return

    if(xv<=self%entry(slot)%table%x(1))then
      lo=1
    else if(xv>=self%entry(slot)%table%x(n))then
      lo=n-1
    else
      lo=1;hi=n
      do while(hi-lo>1)
        mid=(lo+hi)/2
        if(self%entry(slot)%table%x(mid)<=xv)then
          lo=mid
        else
          hi=mid
        end if
      end do
    end if

    x0=self%entry(slot)%table%x(lo)
    x1=self%entry(slot)%table%x(lo+1)
    z0=self%entry(slot)%table%z(lo)
    z1=self%entry(slot)%table%z(lo+1)
    m0=self%entry(slot)%table%dzdx(lo)
    m1=self%entry(slot)%table%dzdx(lo+1)
    k0=self%entry(slot)%table%logk(lo)
    k1=self%entry(slot)%table%logk(lo+1)
    inside=.true.
  end subroutine b110_ahl_sample_slot

  subroutine b110_ahl_lookup(self,key,table,was_hit)
    class(b110_adaptive_hydraulic_cache_t),intent(inout)::self
    type(b110_adaptive_hydraulic_cache_key_t),intent(in)::key
    type(b110_adaptive_hydraulic_table_t),intent(out)::table
    logical,intent(out)::was_hit
    integer::i,slot

    was_hit=.false.
    if(.not.allocated(self%entry)) return

    slot=b110_ahl_initial_slot(key%fingerprint)
    do i=1,B110_AHL_MAX_CACHE
      self%total_probes=self%total_probes+1_int64
      self%max_probes=max(self%max_probes,i)
      if(.not.self%entry(slot)%occupied) return
      if(self%entry(slot)%key%fingerprint==key%fingerprint)then
        if(b110_adaptive_hydraulic_keys_equal(self%entry(slot)%key,key))then
          table=self%entry(slot)%table
          self%hits=self%hits+1
          was_hit=.true.
          return
        end if
      end if
      slot=slot+1
      if(slot>B110_AHL_MAX_CACHE) slot=1
    end do
  end subroutine b110_ahl_lookup

  subroutine b110_ahl_get_or_build(self,key,parameters,provider,table,was_hit,ok)
    class(b110_adaptive_hydraulic_cache_t),intent(inout)::self
    type(b110_adaptive_hydraulic_cache_key_t),intent(in)::key
    type(b110_default_mvg_parameters_t),intent(in)::parameters
    type(b110_default_mvg_provider_t),intent(in)::provider
    type(b110_adaptive_hydraulic_table_t),intent(out)::table
    logical,intent(out)::was_hit,ok
    integer::i,slot
    logical::build_ok

    was_hit=.false.;ok=.false.;slot=0
    if(.not.allocated(self%entry)) allocate(self%entry(B110_AHL_MAX_CACHE))

    slot=b110_ahl_initial_slot(key%fingerprint)
    do i=1,B110_AHL_MAX_CACHE
      self%total_probes=self%total_probes+1_int64
      self%max_probes=max(self%max_probes,i)
      if(.not.self%entry(slot)%occupied) exit
      if(self%entry(slot)%key%fingerprint==key%fingerprint)then
        if(b110_adaptive_hydraulic_keys_equal(self%entry(slot)%key,key))then
          table=self%entry(slot)%table
          self%hits=self%hits+1
          was_hit=.true.;ok=.true.;return
        end if
      end if
      slot=slot+1
      if(slot>B110_AHL_MAX_CACHE) slot=1
      if(i==B110_AHL_MAX_CACHE) slot=0
    end do

    self%misses=self%misses+1
    if(slot==0)then
      ! F-AHL29: cache capacity is an optimization bound, never a correctness
      ! bound. Build a valid uncached representation when all slots are occupied.
      call build_b110_adaptive_hydraulic_table(provider,parameters%cofgen(1,1),parameters%cofgen(2,1),table,build_ok)
      if(.not.build_ok)return
      self%builds=self%builds+1
      ok=.true.
      return
    end if
    call build_b110_adaptive_hydraulic_table(provider,parameters%cofgen(1,1),parameters%cofgen(2,1),table,build_ok)
    if(.not.build_ok)return
    self%entry(slot)%occupied=.true.
    self%entry(slot)%key=key
    self%entry(slot)%table=table
    self%builds=self%builds+1
    ok=.true.
  end subroutine b110_ahl_get_or_build

  pure integer function b110_ahl_initial_slot(fingerprint) result(slot)
    integer(int64),intent(in)::fingerprint
    integer(int64)::h
    ! F-AHL32A: preserve the stored fingerprint and exact-key authority.
    ! Fold high-order fingerprint information into the low bits used by the
    ! fixed power-of-two registry capacity before open-addressed probing.
    h=fingerprint
    h=ieor(h,ishft(h,-32))
    h=ieor(h,ishft(h,-16))
    h=ieor(h,ishft(h,-8))
    slot=1+int(iand(h,int(B110_AHL_MAX_CACHE-1,int64)))
  end function b110_ahl_initial_slot

  subroutine b110_ahl_stats(self,builds,hits,misses,entries)
    class(b110_adaptive_hydraulic_cache_t),intent(in)::self
    integer,intent(out)::builds,hits,misses,entries
    integer::i
    builds=self%builds;hits=self%hits;misses=self%misses;entries=0
    if(.not.allocated(self%entry)) return
    do i=1,B110_AHL_MAX_CACHE
      if(self%entry(i)%occupied)entries=entries+1
    end do
  end subroutine b110_ahl_stats

  subroutine b110_ahl_probe_stats(self,total_probes,max_probes)
    class(b110_adaptive_hydraulic_cache_t),intent(in)::self
    integer(int64),intent(out)::total_probes
    integer,intent(out)::max_probes
    total_probes=self%total_probes
    max_probes=self%max_probes
  end subroutine b110_ahl_probe_stats

end module mod_b110_adaptive_hydraulic_cache

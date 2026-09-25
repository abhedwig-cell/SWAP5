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
  contains
    procedure :: get_or_build => b110_ahl_get_or_build
    procedure :: stats => b110_ahl_stats
  end type b110_adaptive_hydraulic_cache_t

  public :: make_b110_adaptive_hydraulic_key, b110_adaptive_hydraulic_keys_equal

contains

  function make_b110_adaptive_hydraulic_key(parameters,model_id,policy_version,branch_policy_version) result(key)
    type(b110_default_mvg_parameters_t),intent(in)::parameters
    character(len=*),intent(in)::model_id
    integer,intent(in)::policy_version,branch_policy_version
    type(b110_adaptive_hydraulic_cache_key_t)::key
    integer::i
    integer(int64)::bits,h

    if(.not.allocated(parameters%cofgen)) error stop 'B110 AHL key: cofgen not allocated'
    if(parameters%active_nodes<1) error stop 'B110 AHL key: no active nodes'

    key%model_id=''
    key%model_id(1:min(len_trim(model_id),len(key%model_id)))=model_id(1:min(len_trim(model_id),len(key%model_id)))
    key%policy_version=policy_version
    key%branch_policy_version=branch_policy_version
    if(size(parameters%cofgen,1)<NCOEF) error stop 'B110 AHL key: incomplete initialized cofgen'
    key%coeff=parameters%cofgen(1:NCOEF,1)
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
         a%ksatexm_extension_enabled .eqv. b%ksatexm_extension_enabled .and. &
         trim(a%model_id)==trim(b%model_id) .and. &
         all(abit==bbit)
  end function b110_adaptive_hydraulic_keys_equal

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
    do i=1,B110_AHL_MAX_CACHE
      if(self%entry(i)%occupied)then
        if(self%entry(i)%key%fingerprint==key%fingerprint)then
          if(b110_adaptive_hydraulic_keys_equal(self%entry(i)%key,key))then
            table=self%entry(i)%table
            self%hits=self%hits+1
            was_hit=.true.;ok=.true.;return
          end if
        end if
      else if(slot==0)then
        slot=i
      end if
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

end module mod_b110_adaptive_hydraulic_cache

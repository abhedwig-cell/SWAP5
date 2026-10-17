module mod_wofost81_crop_owner_state
  use iso_fortran_env, only: real64,int64
  use ieee_arithmetic, only: ieee_is_finite
  use mod_transaction_reference, only: transaction_state_t
  use mod_wofost_crop_owner_state, only: wofost_crop_owner_state_t, WOFOST_CROP_OWNER_OK
  use mod_wofost81_n_owner_state, only: wofost81_n_owner_state_t, WOFOST81_N_OWNER_OK
  implicit none
  private

  integer, parameter, public :: WOFOST81_CROP_OWNER_OK = 0
  integer, parameter, public :: WOFOST81_CROP_OWNER_INVALID_CROP_STATE = 1
  integer, parameter, public :: WOFOST81_CROP_OWNER_INVALID_N_STATE = 2

  integer, parameter, public :: WOFOST81_HARVEST_INVALID=3, WOFOST81_HARVEST_NOT_DUE=4
  type, public :: wofost81_harvest_policy_t
    real(real64) :: return_fraction(3)=0d0 ! leaf, stem, storage; all living roots return
    real(real64) :: application_age(4)=0d0 ! root, leaf, stem, storage
  end type
  type, public :: wofost81_harvest_record_t
    real(real64)::continuation_totals(2)=[-1d0,-1d0] ! complete coupled N and organic matter, kg/m2
    logical :: pending_incorporated=.false.
    integer(int64) :: crop_identity=0_int64
    real(real64) :: clock=0d0
    type(wofost_crop_owner_state_t) :: end_crop
    type(wofost81_n_owner_state_t) :: end_nitrogen
    type(wofost81_harvest_policy_t) :: policy
    real(real64) :: pending_dm(4)=0d0,pending_n(4)=0d0
    real(real64) :: exported_dm(4)=0d0,exported_n(4)=0d0
  end type
  public :: prepare_wofost81_harvest,restore_wofost81_harvest_trusted,stage_wofost81_harvest_consumed
  type, public :: wofost81_harvest_retired_t
    real(real64) :: clock=0d0,continuation_totals(2)=[-1d0,-1d0]
    integer(int64) :: crop_identity=0_int64
  end type
  public :: stage_wofost81_harvest_retired,restore_wofost81_retired_trusted,stage_wofost81_fallow_continuation
  public :: stage_wofost81_harvest_continuation_totals
  public :: stage_wofost81_retired_material_totals

  type, extends(transaction_state_t), public :: wofost81_crop_owner_state_t
    type(wofost_crop_owner_state_t) :: crop
    type(wofost81_n_owner_state_t) :: nitrogen
    type(wofost81_harvest_record_t), allocatable, private :: harvest
    type(wofost81_harvest_retired_t), allocatable, private :: retired
  contains
    procedure :: clone => clone_wofost81_crop_owner_state
    procedure, public :: validate => validate_wofost81_crop_owner_state
    procedure, public :: harvest_snapshot => snapshot_harvest
    procedure, public :: harvested => crop_harvested
    procedure, public :: retired_snapshot => snapshot_retired
    procedure, public :: harvest_retired => crop_retired
  end type wofost81_crop_owner_state_t

contains

  subroutine clone_wofost81_crop_owner_state(self, copy)
    class(wofost81_crop_owner_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy
    allocate(wofost81_crop_owner_state_t :: copy)
    select type (typed_copy => copy)
    type is (wofost81_crop_owner_state_t)
      typed_copy%crop = self%crop
      typed_copy%nitrogen = self%nitrogen
      if(allocated(self%harvest)) allocate(typed_copy%harvest,source=self%harvest)
      if(allocated(self%retired)) allocate(typed_copy%retired,source=self%retired)
    class default
      error stop 'WOFOST81 crop owner state: clone allocation failure'
    end select
  end subroutine clone_wofost81_crop_owner_state

  integer function validate_wofost81_crop_owner_state(self) result(status)
    class(wofost81_crop_owner_state_t), intent(in) :: self
    status = WOFOST81_CROP_OWNER_INVALID_CROP_STATE
    if (self%crop%validate() /= WOFOST_CROP_OWNER_OK) return
    status = WOFOST81_CROP_OWNER_INVALID_N_STATE
    if (self%nitrogen%validate() /= WOFOST81_N_OWNER_OK) return
    if(allocated(self%crop%biomass))then
      if(self%nitrogen%b112_residue_profile)then
        if(any(self%nitrogen%retained_dead_n>self%crop%biomass%retained_dead_biomass))return
      else
        if(any(self%crop%biomass%retained_dead_biomass/=0d0))return
      endif
    else
      if(any(self%nitrogen%retained_dead_n/=0d0))return
    endif
    if(allocated(self%retired)) then
      status=WOFOST81_HARVEST_INVALID
      if(allocated(self%harvest))return
      if(.not.retired_valid(self%retired))return
      if(self%crop%crop_emerged.or.abs(self%crop%development_stage)>0d0)return
      if(allocated(self%crop%biomass).or.allocated(self%crop%evolution_continuation).or. &
         allocated(self%crop%b110_reference_compatibility))return
      associate(n=>self%nitrogen%value)
        if(any(abs([n%namountlv,n%namountst,n%namountrt,n%namountso])>0d0))return
        if(any([n%nuptake_total,n%nfix_total,n%nlosses_total,n%initial_total]>1d9))return
      end associate
    end if
    if(allocated(self%harvest)) then
      status=WOFOST81_HARVEST_INVALID
      if(.not.harvest_record_valid(self%harvest)) return
      if(self%crop%crop_emerged.or.abs(self%crop%development_stage)>0d0) return
      associate(n=>self%nitrogen%value,h=>self%harvest%end_nitrogen%value)
        if(any(abs([n%namountlv,n%namountst,n%namountrt,n%namountso])>0d0)) return
        if(any(abs([n%initial_total-h%initial_total,n%nuptake_total-h%nuptake_total, &
            n%nfix_total-h%nfix_total])>0d0)) return
        if(self%nitrogen%b112_residue_profile)then
          if(abs(n%nlosses_total-(h%nlosses_total+sum(self%harvest%exported_n)- &
             sum((1d0-self%harvest%policy%return_fraction(1:2))*self%harvest%end_nitrogen%retained_dead_n)))>1d-12)return
        else
        if(abs(n%nlosses_total-(h%nlosses_total+sum(self%harvest%exported_n)))>0d0) return
        endif
      end associate
    end if
    status = WOFOST81_CROP_OWNER_OK
  end function validate_wofost81_crop_owner_state

  logical function crop_harvested(self) result(present_harvest)
    class(wofost81_crop_owner_state_t), intent(in) :: self
    present_harvest=allocated(self%harvest).or.allocated(self%retired)
  end function

  subroutine snapshot_harvest(self,record,available)
    class(wofost81_crop_owner_state_t), intent(in) :: self
    type(wofost81_harvest_record_t), intent(out) :: record
    logical, intent(out) :: available
    record=wofost81_harvest_record_t();available=allocated(self%harvest)
    if(available) record=self%harvest
  end subroutine

  logical function crop_retired(self) result(retired)
    class(wofost81_crop_owner_state_t),intent(in)::self
    retired=allocated(self%retired)
  end function
  subroutine snapshot_retired(self,record,available)
    class(wofost81_crop_owner_state_t),intent(in)::self
    type(wofost81_harvest_retired_t),intent(out)::record
    logical,intent(out)::available
    record=wofost81_harvest_retired_t();available=allocated(self%retired)
    if(available)record=self%retired
  end subroutine
  logical function retired_valid(h) result(ok)
    type(wofost81_harvest_retired_t),intent(in)::h
    ok=.false.
    if(.not.all(ieee_is_finite([h%clock,h%continuation_totals])))return
    if(abs(h%clock)>1d9.or.h%crop_identity<1.or.h%crop_identity>1000000)return
    if(any(h%continuation_totals<0d0).or.any(h%continuation_totals>1d9))return
    ok=.true.
  end function
  subroutine restore_wofost81_retired_trusted(h,nitrogen,candidate,status)
    type(wofost81_harvest_retired_t),intent(in)::h
    type(wofost81_n_owner_state_t),intent(in)::nitrogen
    type(wofost81_crop_owner_state_t),intent(out)::candidate
    integer,intent(out)::status
    type(wofost81_crop_owner_state_t)::trial
    candidate=wofost81_crop_owner_state_t();status=WOFOST81_HARVEST_INVALID
    if(.not.retired_valid(h))return
    allocate(trial%retired,source=h);trial%nitrogen=nitrogen
    if(trial%validate()/=0)return
    candidate=trial;status=0
  end subroutine
  subroutine stage_wofost81_harvest_retired(committed,candidate,status)
    type(wofost81_crop_owner_state_t),intent(in)::committed
    type(wofost81_crop_owner_state_t),intent(out)::candidate
    integer,intent(out)::status
    type(wofost81_harvest_retired_t)::h
    candidate=wofost81_crop_owner_state_t();status=WOFOST81_HARVEST_INVALID
    if(.not.allocated(committed%harvest))return
    if(committed%validate()/=0)return
    if(.not.committed%harvest%pending_incorporated)return
    h%clock=committed%harvest%clock;h%crop_identity=committed%harvest%crop_identity
    h%continuation_totals=committed%harvest%continuation_totals
    call restore_wofost81_retired_trusted(h,committed%nitrogen,candidate,status)
  end subroutine
  subroutine stage_wofost81_fallow_continuation(committed,t0,t1,totals,candidate,status)
    type(wofost81_crop_owner_state_t),intent(in)::committed
    real(real64),intent(in)::t0,t1,totals(2)
    type(wofost81_crop_owner_state_t),intent(out)::candidate
    integer,intent(out)::status
    type(wofost81_harvest_retired_t)::h
    candidate=wofost81_crop_owner_state_t();status=WOFOST81_HARVEST_INVALID
    if(.not.committed%harvest_retired())return
    if(committed%validate()/=0)return
    if(.not.all(ieee_is_finite([t0,t1])))return
    if(abs(t0-committed%retired%clock)>0d0.or.abs(t1-t0-1d0)>0d0)return
    h=committed%retired;h%clock=t1;h%continuation_totals=totals
    call restore_wofost81_retired_trusted(h,committed%nitrogen,candidate,status)
  end subroutine

  subroutine stage_wofost81_retired_material_totals(committed,clock,totals,candidate,status)
    ! Source amendment staging changes inventory, not the retired crop clock.
    ! Construct a trial with revised continuation totals under the existing owner.
    type(wofost81_crop_owner_state_t),intent(in)::committed
    real(real64),intent(in)::clock,totals(2)
    type(wofost81_crop_owner_state_t),intent(out)::candidate
    integer,intent(out)::status
    type(wofost81_harvest_retired_t)::h
    candidate=wofost81_crop_owner_state_t();status=WOFOST81_HARVEST_INVALID
    if(.not.committed%harvest_retired())return
    if(committed%validate()/=0)return
    if(.not.all(ieee_is_finite([clock,totals])))return
    if(clock/=committed%retired%clock.or.any(totals<0d0))return
    h=committed%retired;h%continuation_totals=totals
    call restore_wofost81_retired_trusted(h,committed%nitrogen,candidate,status)
  end subroutine

  logical function harvest_record_valid(h) result(ok)
    type(wofost81_harvest_record_t), intent(in) :: h
    real(real64) :: dm(4),fractions(4),n_after(4),n_before(4)
    ok=.false.
    if(.not.all(ieee_is_finite(h%continuation_totals)))return
    if(any(h%continuation_totals<0d0))then
      if(any(abs(h%continuation_totals+1d0)>0d0))return
    else
      if(any(h%continuation_totals>1d9))return
    end if
    if(h%crop_identity<=0_int64) return
    if(.not.all(ieee_is_finite([h%clock,h%policy%return_fraction,h%policy%application_age, &
        h%pending_dm,h%pending_n,h%exported_dm,h%exported_n]))) return
    if(abs(h%clock)>1d9) return
    if(any(h%policy%return_fraction<0d0).or.any(h%policy%return_fraction>1d0)) return
    if(any(h%policy%application_age<.67d0).or.any(h%policy%application_age>100d0)) return
    if(any(h%pending_dm<0d0).or.any(h%pending_dm>5d5)) return
    if(any(h%pending_n<0d0).or.any(h%pending_n>h%pending_dm)) return
    if(any(h%exported_dm<0d0).or.any(h%exported_dm>5d5)) return
    if(any(h%exported_n<0d0).or.any(h%exported_n>h%exported_dm)) return
    ! The literal management threshold would drop these amounts: reject them.
    if(any(h%pending_dm>0d0.and.h%pending_dm<=1d-8)) return
    if(h%end_crop%validate()/=WOFOST_CROP_OWNER_OK) return
    if(.not.h%end_crop%crop_emerged) return
    if(h%end_nitrogen%validate()/=WOFOST81_N_OWNER_OK) return
    if(.not.h%end_nitrogen%b112_residue_profile)then
      if(any(h%end_crop%biomass%retained_dead_biomass/=0d0))return
    endif
    associate(b=>h%end_crop%biomass,n=>h%end_nitrogen%value)
      dm=[b%root_biomass,b%living_leaf_biomass(),b%stem_biomass,b%storage_biomass]
      if(h%end_nitrogen%b112_residue_profile)dm(2:3)=dm(2:3)+b%retained_dead_biomass
      n_after=[n%namountrt,n%namountlv,n%namountst,n%namountso]
    end associate
    fractions=[1d0,h%policy%return_fraction]
    n_before=h%pending_n+h%exported_n
    if(any(n_before>dm)) return
    if(any(abs(h%pending_dm-fractions*dm)>0d0).or.any(abs(h%exported_dm-(dm-h%pending_dm))>0d0)) return
    ! N amounts have been debited at the historical residue boundary only.
    if(h%end_nitrogen%b112_residue_profile)then
      if(any(h%end_nitrogen%retained_dead_n>h%end_crop%biomass%retained_dead_biomass))return
      if(any(abs(n_after-(h%exported_n-[0d0,(1d0-h%policy%return_fraction(1:2))*h%end_nitrogen%retained_dead_n,0d0]))>1d-12))return
    else
      if(any(abs(n_after-h%exported_n)>0d0)) return
    endif
    if(any(abs(h%pending_n-fractions*n_before)>1d-12*max(1d0,maxval(n_before)))) return
    ok=.true.
  end function

  subroutine prepare_wofost81_harvest(committed,clock,crop_identity,crop_end,sw_harv, &
      sw_wofost,dvs_end,policy,candidate,status)
    type(wofost81_crop_owner_state_t), intent(in) :: committed
    real(real64), intent(in) :: clock,crop_end,dvs_end
    integer(int64), intent(in) :: crop_identity
    integer, intent(in) :: sw_harv,sw_wofost
    type(wofost81_harvest_policy_t), intent(in) :: policy
    type(wofost81_crop_owner_state_t), intent(out) :: candidate
    integer, intent(out) :: status
    type(wofost81_crop_owner_state_t) :: trial
    type(wofost81_harvest_record_t) :: h
    real(real64) :: dm(4),n(4),fractions(4),nv(8),mass
    logical :: due
    ! A failed staging operation never supplies a usable harvested candidate.
    candidate=wofost81_crop_owner_state_t();status=WOFOST81_HARVEST_INVALID
    if(committed%harvested().or.crop_identity<=0_int64) return
    if(.not.all(ieee_is_finite([clock,crop_end,dvs_end,policy%return_fraction,policy%application_age]))) return
    if(max(abs(clock),abs(crop_end))>1d9.or.abs(dvs_end)>100d0) return
    if(sw_harv<0.or.sw_harv>1.or.sw_wofost<1.or.sw_wofost>2) return
    if(any(policy%return_fraction<0d0).or.any(policy%return_fraction>1d0)) return
    if(any(policy%application_age<.67d0).or.any(policy%application_age>100d0)) return
    if(.not.committed%crop%crop_emerged.or..not.allocated(committed%crop%biomass)) return
    associate(b=>committed%crop%biomass)
      if(.not.allocated(b%leaf_biomass)) return
      if(size(b%leaf_biomass)<1.or.size(b%leaf_biomass)>512) return
      if(.not.all(ieee_is_finite([b%root_biomass,b%stem_biomass,b%storage_biomass,b%leaf_biomass]))) return
      if(any([b%root_biomass,b%stem_biomass,b%storage_biomass,b%leaf_biomass]<0d0)) return
      if(any([b%root_biomass,b%stem_biomass,b%storage_biomass,b%leaf_biomass]>5d5)) return
      dm=[b%root_biomass,b%living_leaf_biomass(),b%stem_biomass,b%storage_biomass]
      if(committed%nitrogen%b112_residue_profile)dm(2:3)=dm(2:3)+b%retained_dead_biomass
    end associate
    if(any(dm>5d5)) return
    associate(s=>committed%nitrogen%value)
      n=[s%namountrt,s%namountlv,s%namountst,s%namountso]
      if(committed%nitrogen%b112_residue_profile)n(2:3)=n(2:3)+committed%nitrogen%retained_dead_n
      nv=[n,s%nuptake_total,s%nfix_total,s%nlosses_total,s%initial_total]
    end associate
    if(.not.all(ieee_is_finite(nv))) return
    if(any(nv<0d0).or.any(nv>1d9).or.any(n>dm)) return
    if(committed%validate()/=WOFOST81_CROP_OWNER_OK) return
    ! Literal B1.11 wofost(task4); the supported bounded annual profile.
    due=abs(clock-crop_end-1d0)<.1d0
    if(sw_harv>0) due=due.or.committed%crop%development_stage>=dvs_end
    if(.not.due) then
      status=WOFOST81_HARVEST_NOT_DUE;return
    end if
    fractions=[1d0,policy%return_fraction]
    h%clock=clock;h%crop_identity=crop_identity;h%policy=policy
    h%pending_dm=fractions*dm;h%pending_n=fractions*n
    h%exported_dm=dm-h%pending_dm;h%exported_n=n-h%pending_n
    h%end_crop=committed%crop;h%end_nitrogen=committed%nitrogen
    associate(s=>h%end_nitrogen%value)
      s%namountrt=h%exported_n(1);s%namountlv=h%exported_n(2)
      s%namountst=h%exported_n(3);s%namountso=h%exported_n(4)
      s%nlosses_total=s%nlosses_total+sum(h%pending_n)
      if(committed%nitrogen%b112_residue_profile)then
        s%namountlv=(1d0-policy%return_fraction(1))*committed%nitrogen%value%namountlv
        s%namountst=(1d0-policy%return_fraction(2))*committed%nitrogen%value%namountst
        s%nlosses_total=s%nlosses_total-sum(policy%return_fraction(1:2)*committed%nitrogen%retained_dead_n)
      endif
    end associate
    if(.not.harvest_record_valid(h)) return
    trial%crop=wofost_crop_owner_state_t();trial%nitrogen=h%end_nitrogen
    associate(s=>trial%nitrogen%value)
      s%namountrt=0d0;s%namountlv=0d0;s%namountst=0d0;s%namountso=0d0
      s%nlosses_total=s%nlosses_total+sum(h%exported_n)
      if(trial%nitrogen%b112_residue_profile)then
        s%nlosses_total=s%nlosses_total-sum((1d0-h%policy%return_fraction(1:2))*h%end_nitrogen%retained_dead_n)
        trial%nitrogen%retained_dead_n=0d0
      endif
    end associate
    allocate(trial%harvest,source=h)
    if(trial%validate()/=WOFOST81_CROP_OWNER_OK) return
    mass=sum(n)-sum(h%pending_n)-sum(h%exported_n)
    if(abs(mass)>1d-12*max(1d0,sum(n))) return
    candidate=trial;status=WOFOST81_CROP_OWNER_OK
  end subroutine

  subroutine stage_wofost81_harvest_continuation_totals(committed,totals,candidate,status)
    type(wofost81_crop_owner_state_t),intent(in)::committed
    real(real64),intent(in)::totals(2)
    type(wofost81_crop_owner_state_t),intent(out)::candidate
    integer,intent(out)::status
    candidate=wofost81_crop_owner_state_t();status=WOFOST81_HARVEST_INVALID
    if(.not.allocated(committed%harvest))return
    if(committed%validate()/=0)return
    if(any(abs(committed%harvest%continuation_totals+1d0)>0d0))return
    if(.not.all(ieee_is_finite(totals)))return
    if(any(totals<0d0).or.any(totals>1d9))return
    candidate=committed;candidate%harvest%continuation_totals=totals;status=0
  end subroutine
  ! Trusted decoder/staging constructor, never cross-owner publication authority.
  subroutine restore_wofost81_harvest_trusted(h,candidate,status)
    type(wofost81_harvest_record_t),intent(in)::h
    type(wofost81_crop_owner_state_t),intent(out)::candidate
    integer,intent(out)::status
    type(wofost81_crop_owner_state_t)::trial
    candidate=wofost81_crop_owner_state_t();status=WOFOST81_HARVEST_INVALID
    if(.not.harvest_record_valid(h))return
    trial%nitrogen=h%end_nitrogen
    associate(n=>trial%nitrogen%value)
     n%namountlv=0d0;n%namountst=0d0;n%namountrt=0d0;n%namountso=0d0
     n%nlosses_total=n%nlosses_total+sum(h%exported_n)
     if(trial%nitrogen%b112_residue_profile)then
       n%nlosses_total=n%nlosses_total-sum((1d0-h%policy%return_fraction(1:2))*h%end_nitrogen%retained_dead_n)
       trial%nitrogen%retained_dead_n=0d0
     endif
    end associate
    allocate(trial%harvest,source=h)
    if(trial%validate()/=0)return
    candidate=trial;status=0
  end subroutine
  subroutine stage_wofost81_harvest_consumed(committed,candidate,status)
    type(wofost81_crop_owner_state_t),intent(in)::committed
    type(wofost81_crop_owner_state_t),intent(out)::candidate
    integer,intent(out)::status
    candidate=wofost81_crop_owner_state_t();status=WOFOST81_HARVEST_INVALID
    if(.not.allocated(committed%harvest))return
    if(committed%validate()/=0)return
    if(committed%harvest%pending_incorporated)return
    candidate=committed;candidate%harvest%pending_incorporated=.true.;status=0
  end subroutine
end module mod_wofost81_crop_owner_state

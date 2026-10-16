program test_b112_retained_split
 use iso_fortran_env,only:real64
 use ieee_arithmetic,only:ieee_value,ieee_quiet_nan
 use mod_transaction_reference,only:transaction_state_t
 use mod_crop_senescence_residue
 use mod_wofost_actual_biomass_state
 use mod_wofost81_n_owner_state
 implicit none
 type(crop_senescence_policy_t)::policy
 type(crop_residue_pending_t)::pending
 type(wofost_actual_biomass_state_t)::biomass
 type(wofost81_n_owner_state_t)::nitrogen
 class(transaction_state_t),allocatable::copied
 real(real64)::dm(3),n(3),rdm(2),rn(2),f,values(5),bad(3)
 integer::i,j,code,cases
 policy%application_age=[1d0,2d0,3d0];values=[0d0,.25d0,.37d0,.999d0,1d0];cases=0
 do i=1,5
 do j=0,3
  f=values(i);dm=real(j,real64)*[2d0,10d0,3d0];n=dm*[.002d0,.004d0,.002d0]
  call split_b112_retained_residue(2d0,dm,n,f,policy,pending,rdm,rn,code)
  call require(code==0.and.pending%valid(),'valid physical partition')
  call require(pending%dry_matter_kg_ha(1)==dm(1).and.pending%dry_matter_kg_ha(3)==0d0,'root return and retained stem')
  call require(all(abs([pending%dry_matter_kg_ha(2:3)+rdm]-dm(2:3))<1d-12),'whole DM partition')
  call require(all(abs([pending%nitrogen_kg_ha(2:3)+rn]-n(2:3))<1d-12),'whole N partition')
  call require(all(rn<=rdm),'N cannot exceed physical DM')
  cases=cases+1
 enddo
 enddo
 dm=[2d0,10d0,3d0];n=dm*.002d0
 do i=1,4
  bad=n;f=.25d0
  select case(i)
  case(1);bad(3)=4d0
  case(2);bad(1)=-1d0
  case(3);f=ieee_value(0d0,ieee_quiet_nan)
  case(4);f=1.1d0
  end select
  call split_b112_retained_residue(2d0,dm,bad,f,policy,pending,rdm,rn,code)
  call require(code/=0,'invalid material rejected')
 enddo
 dm=[0d0,1d-9,0d0];n=0d0
 call split_b112_retained_residue(2d0,dm,n,1d0,policy,pending,rdm,rn,code)
 call require(code/=0,'source threshold cannot silently drop returned DM')
 call split_b112_retained_residue(2d0,dm,n,0d0,policy,pending,rdm,rn,code)
 call require(code==0.and.rdm(1)==1d-9,'tiny retained material remains physical')
 biomass%retained_dead_biomass=[3d0,4d0]
 biomass%cumulative_dead_leaf_biomass=8d0
 call biomass%clone(copied)
 select type(copied)
 type is(wofost_actual_biomass_state_t)
  call require(all(copied%retained_dead_biomass==[3d0,4d0]).and.copied%cumulative_dead_leaf_biomass==8d0,'clone retains physical and distinct gross DM')
 class default
  error stop 'wrong clone'
 end select
 deallocate(copied)
 nitrogen%value%initial_total=.2d0;nitrogen%value%nlosses_total=.2d0
 nitrogen%b112_residue_profile=.true.;nitrogen%retained_dead_n=[.03d0,.04d0]
 call require(nitrogen%validate()==0,'retained N is subset of existing gross diagnostic')
 call nitrogen%clone(copied)
 select type(copied)
 type is(wofost81_n_owner_state_t)
  call require(copied%b112_residue_profile.and.all(copied%retained_dead_n==[.03d0,.04d0]),'clone retains N profile and physical stock')
 end select
 nitrogen%b112_residue_profile=.false.;call require(nitrogen%validate()/=0,'nonprofile retained N rejects')
 nitrogen%b112_residue_profile=.true.;nitrogen%retained_dead_n=[.3d0,0d0]
 call require(nitrogen%validate()/=0,'retained N exceeds gross deaths rejects')
 print '(A,I0)','B112_PHYSICAL_PARTITION_CASES=',cases
 print '(A)','B112_RETAINED_STATE_SPLIT_CLONE_REJECTIONS=PASS'
contains
 subroutine require(ok,label)
 logical,intent(in)::ok
 character(*),intent(in)::label
 if(.not.ok)then;print *,label;error stop 1;endif
 end subroutine
end program

program test_harvest_owner
 use iso_fortran_env,only:real64,int64
 use ieee_arithmetic,only:ieee_value,ieee_quiet_nan,ieee_positive_inf
 use mod_transaction_reference,only:transaction_state_t
 use mod_wofost81_crop_owner_state
 use mod_wofost81_harvest_materials
 use mod_b111_soil_n_addition
 use mod_soil_n_pool_state,only:soil_n_transfer_t
 use mod_harvest_oracle
 use mod_crop_soil_n_day,only:pack_crop_n_owner
 use mod_wofost81_one_day_candidate
 use mod_wofost81_daily_parameter_contract
 use mod_wofost_rate_parameters
 use mod_wofost_one_day_structural_evolution
 implicit none
 type(wofost81_crop_owner_state_t)::owner,candidate,copy,invalid
 type(b111_soil_n_material_t)::materials(4)
 type(b111_soil_n_split_parameters_t)::split
 type(soil_n_transfer_t)::transfer
 type(wofost81_harvest_policy_t)::policy,bad
 type(wofost81_harvest_record_t)::h,other
 type(wofost81_one_day_prepared_candidate_t)::prepared
 type(wofost_rate_parameter_bundle_t)::common
 type(wofost81_daily_parameter_contract_t)::p81
 type(wofost_one_day_forcing_t)::weather
 type(wofost_one_day_update_parameters_t)::update
 type(wofost_accepted_window_aggregates_t)::aggregates
 class(transaction_state_t),allocatable::cloned
 real(real64)::dm(4),n(4),pending_dm(4),pending_n(4),remaining_n(4),f(3),clocks(6),total
 real(real64),allocatable::packed(:)
 integer::code,i,j,k,checks,sw,organ
 logical::available
 checks=0
 split=b111_soil_n_split_parameters_t(.002d0,.06d0,.58d0/14d0,.04d0,.28d0)
 policy%application_age=[1.57d0,.99d0,1.57d0,.99d0]
 call make_owner(owner)
 call require(owner%validate()==0.and..not.owner%harvested(),'actual balanced emerged owner')
 dm=[100d0,200d0,300d0,400d0];n=[2d0,6d0,3d0,4d0]
 ! Distinct fractions test every organ with independent original Fortran.
 do i=0,4
  do j=0,4
   do k=0,4
    f=[real(i,real64)/4d0,real(j,real64)/4d0,real(k,real64)/4d0]
    policy%return_fraction=f
    call prepare_wofost81_harvest(owner,11d0,7_int64,10d0,0,1,2d0,policy,candidate,code)
    call require(code==0.and.candidate%harvested().and.candidate%validate()==0,'valid harvest candidate')
    call candidate%harvest_snapshot(h,available);call require(available,'owned immutable end-status')
    call literal_harvest(dm,n,f,pending_dm,pending_n,remaining_n)
    call require(all(h%pending_dm==pending_dm).and.all(h%pending_n==pending_n),'original four organ returns')
    call require(all(h%exported_n==remaining_n),'original residual N for export')
    call build_wofost81_harvest_materials(candidate,materials,code)
    call require(code==0,'actual four organ material producer')
    total=0d0
    do organ=1,4
     call require(materials(organ)%application_kg_m2==pending_dm(organ)*1d-4.and. &
      materials(organ)%application_age==policy%application_age(organ),'literal management units and ages')
     call build_b111_residue_transfer(.3d0,materials(organ),split,transfer,code)
     call require(code==0,'actual existing B1.11 residue chemistry')
     call require(abs(transfer%external_n_input_kg_m2-pending_n(organ)*1d-4)<=1d-12.and. &
      transfer%external_n_output_kg_m2==0d0,'actual residue N transfer per organ')
     total=total+transfer%external_n_input_kg_m2
    end do
    call require(abs(total+sum(h%exported_n)*1d-4-sum(n)*1d-4)<=1d-12, &
     'harvest N closes across original soil-transfer and export boundaries')
    call require(all(h%pending_dm+h%exported_dm==dm),'organ dry matter closure')
    call require(all(h%pending_n+h%exported_n==n),'organ nitrogen closure')
    call require(h%pending_dm(1)==dm(1).and.h%exported_n(1)==0d0,'all living roots return')
    call require(all(h%policy%application_age==policy%application_age),'four distinct material ages preserved')
    call require(.not.candidate%crop%crop_emerged.and..not.allocated(candidate%crop%biomass).and. &
     .not.allocated(candidate%crop%evolution_continuation),'active crop reset without optional state')
    call require(h%end_crop%biomass%storage_biomass==400d0.and. &
     h%end_crop%biomass%living_leaf_biomass()==200d0,'end-status biomass before reset')
    call require(h%end_nitrogen%validate()==0.and.h%end_nitrogen%value%namountrt==0d0.and. &
     h%end_nitrogen%value%namountso==remaining_n(4),'post-residue end-status N before export')
    call require(candidate%nitrogen%value%nfix_total==owner%nitrogen%value%nfix_total.and. &
     candidate%nitrogen%value%nuptake_total==owner%nitrogen%value%nuptake_total.and. &
     candidate%nitrogen%value%initial_total==owner%nitrogen%value%initial_total,'WOFOST81 source totals unchanged')
    call require(candidate%nitrogen%value%nlosses_total==owner%nitrogen%value%nlosses_total+sum(n), &
     'single complete live N debit')
    call input_unchanged()
   end do
  end do
 end do
 copy=candidate
 ! Both ordinary assignment and production polymorphic clone retain optional record.
 call copy%clone(cloned)
 select type(cloned)
 type is(wofost81_crop_owner_state_t)
  call require(cloned%harvested().and.cloned%validate()==0,'polymorphic clone retains harvest')
  call cloned%harvest_snapshot(other,available)
  call require(available.and.all(other%pending_n==h%pending_n),'clone retains complete pending N')
 class default
  error stop 'wrong cloned type'
 end select
 h%pending_n=999d0
 call copy%harvest_snapshot(other,available)
 call require(available.and.all(other%pending_n<=other%pending_dm),'snapshot is detached from private owner')
 call prepare_wofost81_harvest(copy,11d0,7_int64,10d0,0,1,2d0,policy,candidate,code)
 call require(code/=0.and..not.candidate%harvested(),'harvest replay rejected')
 packed=pack_crop_n_owner(copy)
 call require(size(packed)==0,'old active-only serialization refuses harvested owner')
 call prepare_wofost81_one_day_candidate(copy,weather,11d0,12d0,common,p81,update,aggregates, &
  0d0,0d0,.false.,prepared,code)
 call require(code==WOFOST81_DAY_INVALID_OWNER.and..not.prepared%ready,'unqualified daily continuation refuses harvest')
 policy%return_fraction=[.25d0,.5d0,.75d0]
 clocks=[10.875d0,10.9375d0,11d0,11.0625d0,11.125d0,12d0]
 do sw=0,1
  do i=1,size(clocks)
   call prepare_wofost81_harvest(owner,clocks(i),7_int64,10d0,sw,1,2d0,policy,candidate,code)
   call require((code==0).eqv.(abs(clocks(i)-10d0-1d0)<.1d0),'literal strict calendar boundary before maturity')
  end do
 end do
 owner%crop%development_stage=2d0
 call prepare_wofost81_harvest(owner,9d0,7_int64,10d0,1,2,2d0,policy,candidate,code)
 call require(code==0,'maturity trigger annual type2')
 call prepare_wofost81_harvest(owner,9d0,7_int64,10d0,0,1,2d0,policy,candidate,code)
 call require(code==WOFOST81_HARVEST_NOT_DUE,'calendar-only ignores maturity')
 call make_owner(owner)
 do i=1,16
  invalid=owner;bad=policy
  select case(i)
  case(1);bad%return_fraction(1)=-1d0
  case(2);bad%return_fraction(2)=1.1d0
  case(3);bad%return_fraction(3)=ieee_value(0d0,ieee_quiet_nan)
  case(4);bad%application_age(4)=.66d0
  case(5);bad%application_age(1)=ieee_value(0d0,ieee_positive_inf)
  case(6);invalid%nitrogen%value%namountso=-1d0
  case(7);invalid%nitrogen%value%namountso=ieee_value(0d0,ieee_quiet_nan)
  case(8);invalid%crop%biomass%root_biomass=huge(0d0)
  case(9);invalid%nitrogen%value%initial_total=999d0
  case(10);bad%return_fraction(3)=1d-12 ! historical material threshold would lose nonzero matter
  case(11);invalid%crop%biomass%storage_biomass=0d0 ! orphan nitrogen
  case(12);deallocate(invalid%crop%biomass%specific_leaf_area)
  case(13);invalid%crop%development_stage=ieee_value(0d0,ieee_quiet_nan)
  case(14);invalid%crop%biomass%leaf_biomass(1)=ieee_value(0d0,ieee_positive_inf)
  case(15);invalid%nitrogen%value%nuptake_total=huge(0d0)
  case(16);invalid%crop%crop_emerged=.false.
  end select
  call prepare_wofost81_harvest(invalid,11d0,7_int64,10d0,0,1,2d0,bad,candidate,code)
  call require(code/=0.and..not.candidate%harvested(),'invalid candidate fails closed')
  call input_unchanged()
 end do
 call prepare_wofost81_harvest(owner,ieee_value(0d0,ieee_quiet_nan),7_int64,10d0,0,1,2d0,policy,candidate,code)
 call require(code/=0,'nonfinite event clock')
 call prepare_wofost81_harvest(owner,11d0,0_int64,10d0,0,1,2d0,policy,candidate,code)
 call require(code/=0,'missing crop identity')
 call prepare_wofost81_harvest(owner,11d0,7_int64,10d0,0,3,2d0,policy,candidate,code)
 call require(code/=0,'unqualified grass profile refused')
 call build_wofost81_harvest_materials(owner,materials,code)
 call require(code/=0,'active owner cannot produce harvest material')
 invalid=copy;invalid%crop=owner%crop
 call require(invalid%validate()/=0,'cannot reactivate reset crop while private harvest remains')
 call build_wofost81_harvest_materials(invalid,materials,code)
 call require(code/=0,'invalid owner cannot emit material')
 print '(A,I0)','WOFOST81_HARVEST_ASSERTIONS=',checks
 print '(A)','WOFOST81_HARVEST_OWNER_LITERAL_ORACLE=PASS'
contains
 subroutine require(ok,label)
  logical,intent(in)::ok
  character(*),intent(in)::label
  if(.not.ok)then;print *,'FAIL ',label;error stop 1;end if
  checks=checks+1
 end subroutine
 subroutine make_owner(o)
  type(wofost81_crop_owner_state_t),intent(out)::o
  o=wofost81_crop_owner_state_t()
  o%crop%crop_emerged=.true.;o%crop%development_stage=1.5d0
  allocate(o%crop%biomass,o%crop%evolution_continuation)
  o%crop%biomass%root_biomass=100d0;o%crop%biomass%stem_biomass=300d0
  o%crop%biomass%storage_biomass=400d0
  o%crop%biomass%leaf_biomass=[80d0,120d0]
  o%crop%biomass%specific_leaf_area=[.02d0,.03d0];o%crop%biomass%leaf_age=[2d0,3d0]
  o%nitrogen%value%namountrt=2d0;o%nitrogen%value%namountlv=6d0
  o%nitrogen%value%namountst=3d0;o%nitrogen%value%namountso=4d0
  o%nitrogen%value%initial_total=10d0;o%nitrogen%value%nuptake_total=4d0
  o%nitrogen%value%nfix_total=3d0;o%nitrogen%value%nlosses_total=2d0
 end subroutine
 subroutine input_unchanged()
  call require(owner%validate()==0.and..not.owner%harvested().and.owner%crop%crop_emerged,'input owner unchanged')
  call require(owner%crop%biomass%living_leaf_biomass()==200d0.and. &
   owner%nitrogen%value%namountso==4d0.and.owner%nitrogen%value%nlosses_total==2d0,'no input material/N debit')
 end subroutine
end program

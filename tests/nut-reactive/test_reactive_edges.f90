program test_reactive_edges
 use iso_fortran_env,only:real64,int64
 use mod_b111_soil_n_reactive_owner
 use mod_b111_soil_n_mineral_owner,only:MINERAL_OK,mineral_state_t,mineral_receipt_t,initialize_mineral,apply_mineral_day_transfer
 use mod_soil_n_pool_state
 implicit none
 type(reactive_parameters_t)::p,q
 type(reactive_state_t)::state
 type(soil_n_pool_state_t)::before,after
 type(reactive_receipt_t)::r
 type(mineral_state_t)::base
 type(mineral_receipt_t)::budget
 type(soil_n_transfer_t)::x
 real(real64)::time,water
 integer(int64)::revision
 integer::code
 call parameters(p)
 ! A successful immobilisation consumes NH4 rather than silently clipping organic N.
 p%mineral%inventory%nfrac_fom=.001d0;p%mineral%inventory%nfrac_biomass=.08d0
 p%mineral%inventory%nfrac_humus=.06d0
 call initialize_soil_n_pool_state(p%mineral%inventory,[100d0,200d0],.1d0,.1d0,.2d0,.03d0,before,code)
 call require(code==0,'immobilisation pools')
 call initialize_reactive(p,9_int64,0d0,.34d0,before,state,code);call require(code==0,'immobilisation state')
 call advance_reactive_day(state,0d0,1d0,.34d0,0d0,0d0,0d0,0d0,r)
 call require(r%status==MINERAL_OK,'successful immobilisation')
 call require(r%process%organic%nitrogen%mineralized_n_kg_m2<0d0,'negative mineralisation transfer')
 call state%snapshot(time,water,after,revision)
 call require(after%ammonium_n_kg_m2<before%ammonium_n_kg_m2,'NH4 debit')
 call require(abs(before%nitrogen_total(p%mineral%inventory)-after%nitrogen_total(p%mineral%inventory)- &
      r%process%exchange%no3_denitrified_kg_m2)<1d-12,'immobilisation whole N')
 ! Nitrification is internal, and denitrification explicitly disabled means no gas loss.
 call parameters(p);p%environment%denitrification_ref_per_day=0d0
 call initialize_soil_n_pool_state(p%mineral%inventory,[10d0,20d0],5d0,40d0,.02d0,.03d0,before,code)
 call initialize_reactive(p,9_int64,0d0,.34d0,before,state,code)
 call advance_reactive_day(state,0d0,1d0,.34d0,0d0,0d0,0d0,0d0,r)
 call require(r%status==0.and.r%process%exchange%nh4_nitrified_kg_m2>0d0,'internal nitrification')
 call require(r%external_out==0d0.and.r%process%exchange%no3_denitrified_kg_m2==0d0,'no false external nitrification sink')
 call state%snapshot(time,water,after,revision)
 call require(abs(before%nitrogen_total(p%mineral%inventory)-after%nitrogen_total(p%mineral%inventory))<1d-12,'internal whole N')
 ! Clock and storage mismatches remain atomic even if the pure reaction could run.
 call advance_reactive_day(state,1d0,2d0,.35d0,0d0,0d0,0d0,0d0,r)
 call require(r%status/=0,'unbooked water rejected')
 call state%snapshot(time,water,after,revision)
 call require(time==1d0.and.revision==1.and.water==.34d0,'water mismatch did not consume state')
 ! Current same-platform disk revision domain is enforced at the new commit seam.
 call reconstruct_reactive_trusted(p,9_int64,100000000_int64,0d0,.34d0,before,state,code)
 call require(code==0,'bounded counter setup')
 call advance_reactive_day(state,0d0,1d0,.34d0,0d0,0d0,0d0,0d0,r)
 call require(r%status/=0,'counter overflow domain rejected')
 call state%snapshot(time,water,after,revision)
 call require(time==0d0.and.revision==100000000_int64,'counter failure atomic')
 call initialize_mineral(p%mineral,9_int64,0d0,.34d0,before,base,code)
 x%fom_delta_kg_m3=[0d0,0d0]
 x%ammonium_n_delta_kg_m2=huge(0d0);x%nitrate_n_delta_kg_m2=huge(0d0)
 call apply_mineral_day_transfer(base,0d0,1d0,.34d0,0d0,0d0,0d0,0d0,x,budget)
 call require(budget%status/=0,'huge transfer rejected before arithmetic overflow')
 call base%snapshot(time,water,after,revision)
 call require(time==0d0.and.revision==0,'huge transfer atomic')
 print '(A)','REACTIVE_SUCCESSFUL_IMMOBILISATION_INTERNAL_NITRIFICATION_WATER_COUNTER=PASS'
contains
 subroutine require(ok,label)
 logical,intent(in)::ok
 character(*),intent(in)::label
 if(.not.ok)then;print *,label;error stop 1;end if
 end subroutine
 include 'reactive_parameters.inc'
end program

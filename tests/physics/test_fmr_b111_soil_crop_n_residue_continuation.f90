program test_fmr_b111_soil_crop_n_residue_continuation
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference, only: transaction_state_t,transaction_policy_t,transaction_result_t, &
       execute_reference_interval,TX_STATUS_ACCEPTED,TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_soil_n_pool_state, only: soil_n_inventory_parameters_t,soil_n_pool_state_t,initialize_soil_n_pool_state,SOIL_N_OK
  use mod_b111_soil_organic_turnover, only: b111_organic_turnover_parameters_t
  use mod_b111_soil_n_addition, only: b111_soil_n_split_parameters_t
  use mod_b111_soil_n_daily_exchange, only: b111_soil_n_exchange_forcing_t
  use mod_b111_soil_n_daily_candidate, only: b111_soil_n_rate_environment_t
  use mod_b111_crop_n_owner, only: b111_crop_n_state_t,b111_crop_n_forcing_t,initialize_b111_crop_n_state,B111_CROPN_OK
  use mod_fmr_b111_soil_n_transaction, only: fmr_b111_soil_n_state_t,initialize_fmr_b111_soil_n_state,FMR_SOIL_N_OK
  use mod_fmr_b111_soil_crop_n_transaction
  implicit none

  type(soil_n_inventory_parameters_t)::p,ps
  type(soil_n_pool_state_t)::spool,ssnap
  type(fmr_b111_soil_n_state_t)::soil,soil_snap
  type(b111_crop_n_state_t)::crop,crop_snap
  type(b111_organic_turnover_parameters_t)::tp
  type(b111_soil_n_split_parameters_t)::split
  type(b111_soil_n_exchange_forcing_t)::sf
  type(b111_soil_n_rate_environment_t)::env
  type(b111_crop_n_forcing_t)::cf
  type(fmr_b111_soil_crop_n_state_t)::joint,restarted
  type(fmr_b111_soil_crop_n_model_t)::model
  type(fmr_b111_soil_crop_n_receipt_t)::receipt
  class(transaction_state_t),allocatable::committed
  type(transaction_policy_t)::policy
  type(transaction_result_t)::tx
  integer::status
  logical::available,consumed
  real(real64)::t0,t1,prd,pnr,pld,pnl,whole0,whole1,whole2

  p%depth_m=0.5_real64
  p%nfrac_fom=[0.03_real64,0.01_real64,0.03_real64,0.01_real64, &
               0.03_real64,0.01_real64,0.03_real64,0.01_real64]
  p%nfrac_biomass=0.04_real64;p%nfrac_humus=0.05_real64
  call initialize_soil_n_pool_state(p,[1d0,1d0,1d0,1d0,1d0,1d0,1d0,1d0], &
       5.0_real64,10.0_real64,0.1_real64,0.1_real64,spool,status)
  call check(status==SOIL_N_OK,'soil pool init')
  call initialize_fmr_b111_soil_n_state(p,spool,soil,status)
  call check(status==FMR_SOIL_N_OK,'soil state init')
  call initialize_b111_crop_n_state(10.0_real64,5.0_real64,4.0_real64,1.0_real64,crop,status)
  call check(status==B111_CROPN_OK,'crop state init')
  call initialize_fmr_b111_soil_crop_n_state(soil,crop,joint,status)
  call check(status==FMR_B111_COUPLED_N_OK,'joint init')
  allocate(committed,source=joint)

  tp%ratecon_fom=spread(0.01_real64,1,8)
  tp%asfa_fom_bio=spread(0.2_real64,1,8)
  tp%asfa_fom_hum=spread(0.3_real64,1,8)
  tp%ratecon_bio=0.01_real64;tp%ratecon_hum=0.003_real64
  tp%asfa_bio=0.1_real64;tp%asfa_hum=0.2_real64

  split%nfrac_fom_min=0.01_real64;split%nfrac_fom_max=0.03_real64
  split%nfrac_humus=0.05_real64;split%asfa_min=0.03_real64;split%asfa_max=0.28_real64

  sf%dt_day=1.0_real64;sf%wfrac_t=0.45_real64;sf%wfrac_t0=0.45_real64
  sf%root_depth_cm=50.0_real64;sf%drybd=1.2_real64;sf%sorpcoef=0.4_real64

  env%temperature_c=20.0_real64;env%temperature_reference_c=20.0_real64
  env%wfrac_sat=0.5_real64;env%wfpscrit2=0.6_real64;env%cdissi_half_kg_m2=0.05_real64
  env%nitrification_ref_per_day=0.0_real64;env%denitrification_ref_per_day=0.0_real64

  cf%delt_day=1.0_real64;cf%dvs=0.5_real64;cf%dvsnlt=1.0_real64;cf%dvsnt=1.2_real64;cf%reltr=1.0_real64
  cf%nfixf=0.0_real64;cf%tcnt_day=2.0_real64;cf%fntrt=0.5_real64
  cf%wlv_kg_ha=100.0_real64;cf%wst_kg_ha=100.0_real64;cf%wrt_kg_ha=100.0_real64;cf%wso_kg_ha=100.0_real64
  cf%nmaxlv=0.10_real64;cf%nmaxst=0.05_real64;cf%nmaxrt=0.04_real64;cf%nmaxso=0.01_real64
  cf%rnflv=0.01_real64;cf%rnfst=0.01_real64;cf%rnfrt=0.01_real64
  cf%drlv_kg_ha_day=5.0_real64;cf%drrt_kg_ha_day=10.0_real64;cf%drst_kg_ha_day=0.0_real64

  call configure_fmr_b111_soil_crop_n_model(tp,[0.45_real64,0.45_real64,0.45_real64,0.45_real64, &
       0.45_real64,0.45_real64,0.45_real64,0.45_real64],0.50_real64,0.55_real64,env,sf,cf,model,status, &
       split,1.27_real64,0.99_real64,0.4_real64)
  call check(status==FMR_B111_COUPLED_N_OK,'model config')

  policy%temporal_mode=TX_TEMPORAL_MODEL_CERTIFICATE;policy%max_retries=0
  policy%mass_tolerance=5.0e-10_real64;policy%temporal_tolerance=1.0e-12_real64

  whole0=spool%nitrogen_total(p)+(crop%anlv_kg_ha+crop%anst_kg_ha+crop%anrt_kg_ha+crop%anso_kg_ha)*1.0e-4_real64
  call execute_reference_interval(model,committed,0.0_real64,1.0_real64,policy,tx)
  call check(tx%status==TX_STATUS_ACCEPTED,'day1 accepted')
  call model%snapshot_receipt(receipt,available)
  call check(available,'day1 receipt')
  call near(receipt%pending_residue_consumed_kg_m2,0.0_real64,'day1 no prior residue')
  call near(receipt%pending_residue_created_kg_m2,1.2e-5_real64,'day1 pending residue N')
  call near(receipt%external_crop_loss_kg_m2,0.0_real64,'day1 retained leaf loss is not external')

  call snapshot_joint(committed,soil_snap,crop_snap,t0,t1,consumed,prd,pnr,pld,pnl,available)
  call check(available.and.consumed,'day1 snapshot')
  call near(prd,10.0_real64,'pending root DM')
  call near(pnr,0.1_real64,'pending root N')
  call near(pld,2.0_real64,'pending leaf DM')
  call near(pnl,0.02_real64,'pending leaf N')
  call soil_snap%snapshot(ps,ssnap,available)
  whole1=ssnap%nitrogen_total(ps)+(crop_snap%anlv_kg_ha+crop_snap%anst_kg_ha+crop_snap%anrt_kg_ha+crop_snap%anso_kg_ha+ &
       crop_snap%nloss_leaf_kg_ha+crop_snap%nloss_stem_kg_ha+crop_snap%nloss_root_kg_ha+pnr+pnl)*1.0e-4_real64
  call near(whole1,whole0+tx%accepted_total_in-tx%accepted_total_out,'day1 whole N closure')

  call initialize_fmr_b111_soil_crop_n_state(soil_snap,crop_snap,restarted,status,t0,t1,consumed,prd,pnr,pld,pnl)
  call check(status==FMR_B111_COUPLED_N_OK,'restart with pending residue')
  deallocate(committed);allocate(committed,source=restarted)

  call execute_reference_interval(model,committed,1.0_real64,2.0_real64,policy,tx)
  call check(tx%status==TX_STATUS_ACCEPTED,'day2 accepted')
  call model%snapshot_receipt(receipt,available)
  call check(available,'day2 receipt')
  call near(receipt%pending_residue_consumed_kg_m2,1.2e-5_real64,'day2 consumes prior residue')
  call near(receipt%pending_residue_created_kg_m2,1.2e-5_real64,'day2 creates next residue')
  call snapshot_joint(committed,soil_snap,crop_snap,t0,t1,consumed,prd,pnr,pld,pnl,available)
  call soil_snap%snapshot(ps,ssnap,available)
  whole2=ssnap%nitrogen_total(ps)+(crop_snap%anlv_kg_ha+crop_snap%anst_kg_ha+crop_snap%anrt_kg_ha+crop_snap%anso_kg_ha+ &
       crop_snap%nloss_leaf_kg_ha+crop_snap%nloss_stem_kg_ha+crop_snap%nloss_root_kg_ha+pnr+pnl)*1.0e-4_real64
  call near(whole2,whole1+tx%accepted_total_in-tx%accepted_total_out,'day2 whole N closure')
  call near(tx%accepted_total_out,0.0_real64,'day2 retained crop dead N is storage')

  print '(A)','FMR_B111_SOIL_CROP_N_RESIDUE_CONTINUATION_PASS'
contains
  subroutine snapshot_joint(state,soil,crop,t0,t1,consumed,prd,pnr,pld,pnl,ok)
    class(transaction_state_t),allocatable,intent(in)::state
    type(fmr_b111_soil_n_state_t),intent(out)::soil
    type(b111_crop_n_state_t),intent(out)::crop
    real(real64),intent(out)::t0,t1,prd,pnr,pld,pnl
    logical,intent(out)::consumed,ok
    ok=.false.;t0=0d0;t1=0d0;prd=0d0;pnr=0d0;pld=0d0;pnl=0d0;consumed=.false.
    select type(state)
    type is(fmr_b111_soil_crop_n_state_t)
      call state%snapshot(soil,crop,t0,t1,consumed,ok,prd,pnr,pld,pnl)
    class default
      soil=fmr_b111_soil_n_state_t();crop=b111_crop_n_state_t()
    end select
  end subroutine
  subroutine near(x,y,label)
    real(real64),intent(in)::x,y
    character(len=*),intent(in)::label
    call check(abs(x-y)<=5.0e-10_real64*max(1.0_real64,abs(x),abs(y)),label)
  end subroutine
  subroutine check(ok,label)
    logical,intent(in)::ok
    character(len=*),intent(in)::label
    if(.not.ok)then
      print '(A)',trim(label)//' failed';error stop 1
    end if
  end subroutine
end program

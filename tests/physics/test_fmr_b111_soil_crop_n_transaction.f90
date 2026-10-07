program test_fmr_b111_soil_crop_n_transaction
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference, only: transaction_state_t,transaction_policy_t,transaction_result_t, &
       execute_reference_interval,TX_STATUS_ACCEPTED,TX_STATUS_RETRY_EXHAUSTED,TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_soil_n_pool_state, only: soil_n_inventory_parameters_t,soil_n_pool_state_t,initialize_soil_n_pool_state,SOIL_N_OK
  use mod_b111_soil_organic_turnover, only: b111_organic_turnover_parameters_t
  use mod_b111_soil_n_daily_exchange, only: b111_soil_n_exchange_forcing_t
  use mod_b111_soil_n_daily_candidate, only: b111_soil_n_rate_environment_t
  use mod_b111_crop_n_owner, only: b111_crop_n_state_t,b111_crop_n_forcing_t,initialize_b111_crop_n_state,B111_CROPN_OK
  use mod_fmr_b111_soil_n_transaction, only: fmr_b111_soil_n_state_t,initialize_fmr_b111_soil_n_state,FMR_SOIL_N_OK
  use mod_fmr_b111_soil_crop_n_transaction
  implicit none

  type(soil_n_inventory_parameters_t)::p,ps
  type(soil_n_pool_state_t)::soil_pool,soil_snap
  type(fmr_b111_soil_n_state_t)::soil_state,soil_restart
  type(b111_crop_n_state_t)::crop_state,crop_snap
  type(b111_organic_turnover_parameters_t)::tp
  type(b111_soil_n_exchange_forcing_t)::sf
  type(b111_soil_n_rate_environment_t)::env
  type(b111_crop_n_forcing_t)::cf
  type(fmr_b111_soil_crop_n_state_t)::coupled,restarted
  type(fmr_b111_soil_crop_n_model_t)::model
  type(fmr_b111_soil_crop_n_receipt_t)::receipt
  class(transaction_state_t),allocatable::committed
  type(transaction_policy_t)::policy
  type(transaction_result_t)::tx
  integer::status
  logical::available,consumed
  real(real64)::t0,t1,whole0,whole1

  p%depth_m=0.5_real64;p%nfrac_fom=[0.02_real64];p%nfrac_biomass=0.04_real64;p%nfrac_humus=0.05_real64
  call initialize_soil_n_pool_state(p,[20.0_real64],5.0_real64,10.0_real64,0.01_real64,0.01_real64,soil_pool,status)
  call check(status==SOIL_N_OK,'soil pool init')
  call initialize_fmr_b111_soil_n_state(p,soil_pool,soil_state,status)
  call check(status==FMR_SOIL_N_OK,'soil tx state init')
  call initialize_b111_crop_n_state(10.0_real64,5.0_real64,4.0_real64,1.0_real64,crop_state,status)
  call check(status==B111_CROPN_OK,'crop state init')
  call initialize_fmr_b111_soil_crop_n_state(soil_state,crop_state,coupled,status)
  call check(status==FMR_B111_COUPLED_N_OK,'coupled state init')
  allocate(committed,source=coupled)

  tp%ratecon_fom=[0.02_real64];tp%asfa_fom_bio=[0.2_real64];tp%asfa_fom_hum=[0.3_real64]
  tp%ratecon_bio=0.01_real64;tp%ratecon_hum=0.003_real64;tp%asfa_bio=0.1_real64;tp%asfa_hum=0.2_real64

  sf%dt_day=1.0_real64;sf%wfrac_t=0.45_real64;sf%wfrac_t0=0.45_real64
  sf%wflux_transp=0.005_real64;sf%wflux_intop=0.005_real64
  sf%tcsf_n=1.0_real64;sf%root_depth_cm=50.0_real64;sf%drybd=1.2_real64;sf%sorpcoef=0.4_real64

  env%temperature_c=20.0_real64;env%temperature_reference_c=20.0_real64;env%wfrac_sat=0.5_real64
  env%wfpscrit2=0.6_real64;env%cdissi_half_kg_m2=0.05_real64
  env%nitrification_ref_per_day=0.05_real64;env%denitrification_ref_per_day=0.0_real64

  cf%delt_day=1.0_real64;cf%dvs=0.5_real64;cf%dvsnlt=1.0_real64;cf%dvsnt=1.2_real64;cf%reltr=1.0_real64
  cf%nfixf=0.25_real64;cf%tcnt_day=2.0_real64;cf%fntrt=0.5_real64
  cf%wlv_kg_ha=100.0_real64;cf%wst_kg_ha=100.0_real64;cf%wrt_kg_ha=100.0_real64;cf%wso_kg_ha=100.0_real64
  cf%nmaxlv=0.2_real64;cf%nmaxst=0.1_real64;cf%nmaxrt=0.08_real64;cf%nmaxso=0.5_real64
  cf%rnflv=0.01_real64;cf%rnfst=0.01_real64;cf%rnfrt=0.01_real64

  call configure_fmr_b111_soil_crop_n_model(tp,[0.45_real64],0.50_real64,0.55_real64,env,sf,cf,model,status)
  call check(status==FMR_B111_COUPLED_N_OK,'model configure')
  policy%temporal_mode=TX_TEMPORAL_MODEL_CERTIFICATE;policy%max_retries=0
  policy%mass_tolerance=2.0e-10_real64;policy%temporal_tolerance=1.0e-12_real64

  whole0=soil_pool%nitrogen_total(p)+(crop_state%anlv_kg_ha+crop_state%anst_kg_ha+crop_state%anrt_kg_ha+crop_state%anso_kg_ha)*1.0e-4_real64
  call execute_reference_interval(model,committed,0.0_real64,1.0_real64,policy,tx)
  call check(tx%status==TX_STATUS_ACCEPTED,'coupled day accepted')
  call model%snapshot_receipt(receipt,available)
  call check(available,'coupled receipt')
  call check(receipt%crop_request%soil_demand_kg_ha>0.0_real64,'positive crop soil demand')
  call check(receipt%crop_process%fixation_kg_ha>0.0_real64,'positive fixation')
  call near(receipt%internal_soil_to_crop_kg_m2,receipt%crop_process%soil_uptake_kg_ha*1.0e-4_real64,'internal uptake identity')
  call snapshot_coupled(committed,soil_restart,crop_snap,t0,t1,consumed,available)
  call check(available.and.consumed,'accepted coupled snapshot')
  call soil_restart%snapshot(ps,soil_snap,available)
  call check(available,'soil restart snapshot')
  whole1=soil_snap%nitrogen_total(ps)+(crop_snap%anlv_kg_ha+crop_snap%anst_kg_ha+crop_snap%anrt_kg_ha+crop_snap%anso_kg_ha)*1.0e-4_real64
  call near(whole1,whole0+tx%accepted_total_in-tx%accepted_total_out,'whole coupled N closure')
  call near(tx%accepted_total_in,receipt%soil_process%owner_receipt%external_n_input_kg_m2+ &
       receipt%external_fixation_input_kg_m2,'external input identity')

  call initialize_fmr_b111_soil_crop_n_state(soil_restart,crop_snap,restarted,status,t0,t1,consumed)
  call check(status==FMR_B111_COUPLED_N_OK,'restart coupled init')
  deallocate(committed);allocate(committed,source=restarted)
  call execute_reference_interval(model,committed,0.0_real64,1.0_real64,policy,tx)
  call check(tx%status==TX_STATUS_RETRY_EXHAUSTED,'restart duplicate day rejected')
  call snapshot_coupled(committed,soil_restart,crop_snap,t0,t1,consumed,available)
  call soil_restart%snapshot(ps,soil_snap,available)
  call check(available,'post-duplicate snapshot')
  call near(soil_snap%nitrogen_total(ps)+(crop_snap%anlv_kg_ha+crop_snap%anst_kg_ha+crop_snap%anrt_kg_ha+crop_snap%anso_kg_ha)*1.0e-4_real64, &
       whole1,'duplicate rollback identity')

  print '(A)','FMR_B111_SOIL_CROP_N_TRANSACTION_PASS'
contains
  subroutine snapshot_coupled(state,soil,crop,t0,t1,consumed,ok)
    class(transaction_state_t),allocatable,intent(in)::state
    type(fmr_b111_soil_n_state_t),intent(out)::soil
    type(b111_crop_n_state_t),intent(out)::crop
    real(real64),intent(out)::t0,t1
    logical,intent(out)::consumed,ok
    ok=.false.;t0=0.0_real64;t1=0.0_real64;consumed=.false.
    select type(state)
    type is(fmr_b111_soil_crop_n_state_t)
      call state%snapshot(soil,crop,t0,t1,consumed,ok)
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

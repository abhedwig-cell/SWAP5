program test_fmr_b111_soil_crop_n_residue_transaction
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference, only: transaction_state_t,transaction_policy_t,transaction_result_t, &
       execute_reference_interval,TX_STATUS_ACCEPTED,TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_soil_n_pool_state, only: soil_n_inventory_parameters_t,soil_n_pool_state_t,initialize_soil_n_pool_state,SOIL_N_OK
  use mod_b111_soil_organic_turnover, only: b111_organic_turnover_parameters_t
  use mod_b111_soil_n_daily_exchange, only: b111_soil_n_exchange_forcing_t
  use mod_b111_soil_n_daily_candidate, only: b111_soil_n_rate_environment_t
  use mod_b111_crop_n_owner, only: b111_crop_n_state_t,b111_crop_n_forcing_t,initialize_b111_crop_n_state,B111_CROPN_OK
  use mod_b111_crop_residue_return, only: b111_crop_residue_return_forcing_t
  use mod_fmr_b111_soil_n_transaction, only: fmr_b111_soil_n_state_t,initialize_fmr_b111_soil_n_state,FMR_SOIL_N_OK
  use mod_fmr_b111_soil_crop_n_transaction
  implicit none

  type(soil_n_inventory_parameters_t)::p,ps
  type(soil_n_pool_state_t)::soil_pool,soil_snap
  type(fmr_b111_soil_n_state_t)::soil_state,soil_snap_state
  type(b111_crop_n_state_t)::crop,crop_snap
  type(b111_organic_turnover_parameters_t)::tp
  type(b111_soil_n_exchange_forcing_t)::sf
  type(b111_soil_n_rate_environment_t)::env
  type(b111_crop_n_forcing_t)::cf
  type(b111_crop_residue_return_forcing_t)::rf
  type(fmr_b111_soil_crop_n_state_t)::initial
  type(fmr_b111_soil_crop_n_model_t)::model
  type(fmr_b111_soil_crop_n_receipt_t)::receipt
  class(transaction_state_t),allocatable::committed
  type(transaction_policy_t)::policy
  type(transaction_result_t)::tx
  real(real64)::fom0(8),n0,n1,t0r,t1r,soiln,cropn
  integer::status
  logical::ok,consumed

  p%depth_m=0.5_real64
  p%nfrac_fom=[0.005_real64,0.03_real64,0.005_real64,0.03_real64, &
               0.005_real64,0.03_real64,0.005_real64,0.03_real64]
  p%nfrac_biomass=0.04_real64
  p%nfrac_humus=0.05_real64
  fom0=1.0_real64
  call initialize_soil_n_pool_state(p,fom0,1.0_real64,2.0_real64,1.0_real64,1.0_real64,soil_pool,status)
  call check(status==SOIL_N_OK,'soil init')
  call initialize_fmr_b111_soil_n_state(p,soil_pool,soil_state,status)
  call check(status==FMR_SOIL_N_OK,'soil owner init')
  call initialize_b111_crop_n_state(10.0_real64,5.0_real64,4.0_real64,1.0_real64,crop,status)
  call check(status==B111_CROPN_OK,'crop init')
  call initialize_fmr_b111_soil_crop_n_state(soil_state,crop,initial,status)
  call check(status==FMR_B111_COUPLED_N_OK,'coupled init')
  allocate(committed,source=initial)

  tp%ratecon_fom=[0.01_real64,0.01_real64,0.01_real64,0.01_real64, &
                  0.01_real64,0.01_real64,0.01_real64,0.01_real64]
  tp%asfa_fom_bio=[0.1_real64,0.1_real64,0.1_real64,0.1_real64, &
                   0.1_real64,0.1_real64,0.1_real64,0.1_real64]
  tp%asfa_fom_hum=[0.2_real64,0.2_real64,0.2_real64,0.2_real64, &
                   0.2_real64,0.2_real64,0.2_real64,0.2_real64]
  tp%ratecon_bio=0.02_real64
  tp%ratecon_hum=0.01_real64
  tp%asfa_bio=0.1_real64
  tp%asfa_hum=0.2_real64

  sf%dt_day=1.0_real64
  sf%wfrac_t=0.4_real64
  sf%wfrac_t0=0.4_real64
  sf%root_depth_cm=50.0_real64
  sf%drybd=1.2_real64
  sf%sorpcoef=0.4_real64

  env%temperature_c=20.0_real64
  env%temperature_reference_c=20.0_real64
  env%wfrac_sat=0.5_real64
  env%wfpscrit2=0.6_real64
  env%cdissi_half_kg_m2=0.05_real64

  cf%delt_day=1.0_real64
  cf%dvs=0.5_real64
  cf%dvsnlt=1.0_real64
  cf%dvsnt=1.2_real64
  cf%reltr=1.0_real64
  cf%nfixf=0.0_real64
  cf%tcnt_day=2.0_real64
  cf%fntrt=0.5_real64
  cf%wlv_kg_ha=100.0_real64
  cf%wst_kg_ha=100.0_real64
  cf%wrt_kg_ha=100.0_real64
  cf%wso_kg_ha=100.0_real64
  cf%nmaxlv=0.10_real64
  cf%nmaxst=0.05_real64
  cf%nmaxrt=0.04_real64
  cf%nmaxso=0.01_real64
  cf%rnflv=0.01_real64
  cf%rnfst=0.01_real64
  cf%rnfrt=0.01_real64
  cf%drlv_kg_ha_day=10.0_real64
  cf%drrt_kg_ha_day=20.0_real64

  rf%leaf_fraction_to_soil=0.5_real64
  rf%root_apparent_age=1.27_real64
  rf%leaf_apparent_age=0.99_real64
  rf%split%nfrac_fom_min=0.005_real64
  rf%split%nfrac_fom_max=0.03_real64
  rf%split%nfrac_humus=0.05_real64
  rf%split%asfa_min=0.03_real64
  rf%split%asfa_max=0.28_real64

  call configure_fmr_b111_soil_crop_n_model(tp,spread(0.45_real64,1,8),0.50_real64,0.55_real64, &
       env,sf,cf,model,status,rf)
  call check(status==FMR_B111_COUPLED_N_OK,'model config')

  call snapshot_coupled(committed,soil_snap_state,crop_snap,t0r,t1r,consumed,ok)
  call soil_snap_state%snapshot(ps,soil_snap,ok)
  soiln=soil_snap%nitrogen_total(ps)
  cropn=(crop_snap%anlv_kg_ha+crop_snap%anst_kg_ha+crop_snap%anrt_kg_ha+crop_snap%anso_kg_ha)*1.0e-4_real64
  n0=soiln+cropn

  policy%temporal_mode=TX_TEMPORAL_MODEL_CERTIFICATE
  policy%max_retries=0
  policy%mass_tolerance=1.0e-10_real64
  policy%temporal_tolerance=1.0e-12_real64
  call execute_reference_interval(model,committed,0.0_real64,1.0_real64,policy,tx)
  call check(tx%status==TX_STATUS_ACCEPTED,'coupled residue transaction accepted')
  call model%snapshot_receipt(receipt,ok)
  call check(ok,'residue receipt')
  call near(receipt%crop_process%root_loss_kg_ha,0.2_real64,'root N loss')
  call near(receipt%crop_process%leaf_loss_kg_ha,0.1_real64,'leaf N loss')
  call near(receipt%internal_crop_residue_return_kg_m2,2.5e-5_real64,'internal residue return')
  call near(receipt%external_crop_loss_kg_m2,5.0e-6_real64,'external non-returned crop loss')

  call snapshot_coupled(committed,soil_snap_state,crop_snap,t0r,t1r,consumed,ok)
  call soil_snap_state%snapshot(ps,soil_snap,ok)
  soiln=soil_snap%nitrogen_total(ps)
  cropn=(crop_snap%anlv_kg_ha+crop_snap%anst_kg_ha+crop_snap%anrt_kg_ha+crop_snap%anso_kg_ha)*1.0e-4_real64
  n1=soiln+cropn
  call near(n1,n0+tx%accepted_total_in-tx%accepted_total_out,'whole-system residue closure')
  call near(tx%accepted_total_out,5.0e-6_real64,'only non-returned leaf N leaves system')
  print '(A)','FMR_B111_SOIL_CROP_N_RESIDUE_TRANSACTION_PASS'
contains
  subroutine snapshot_coupled(state,soil,crop,t0,t1,consumed,available)
    class(transaction_state_t),allocatable,intent(in)::state
    type(fmr_b111_soil_n_state_t),intent(out)::soil
    type(b111_crop_n_state_t),intent(out)::crop
    real(real64),intent(out)::t0,t1
    logical,intent(out)::consumed,available
    available=.false.;consumed=.false.;t0=0.0_real64;t1=0.0_real64
    select type(state)
    type is(fmr_b111_soil_crop_n_state_t)
      call state%snapshot(soil,crop,t0,t1,consumed,available)
    class default
      soil=fmr_b111_soil_n_state_t();crop=b111_crop_n_state_t()
    end select
  end subroutine
  subroutine near(x,y,label)
    real(real64),intent(in)::x,y
    character(len=*),intent(in)::label
    call check(abs(x-y)<=2e-10_real64*max(1.0_real64,abs(x),abs(y)),label)
  end subroutine
  subroutine check(condition,label)
    logical,intent(in)::condition
    character(len=*),intent(in)::label
    if(.not.condition)then
      print '(A)',trim(label)//' failed';error stop 1
    end if
  end subroutine
end program

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
  type(fmr_b111_soil_n_state_t)::soil_state,soil_snap_state
  type(b111_crop_n_state_t)::crop,crop_snap
  type(b111_organic_turnover_parameters_t)::tp
  type(b111_soil_n_exchange_forcing_t)::sf
  type(b111_soil_n_rate_environment_t)::env
  type(b111_crop_n_forcing_t)::cf
  type(fmr_b111_soil_crop_n_state_t)::initial,restarted
  type(fmr_b111_soil_crop_n_model_t)::model
  type(fmr_b111_soil_crop_n_receipt_t)::receipt
  class(transaction_state_t),allocatable::committed
  type(transaction_policy_t)::policy
  type(transaction_result_t)::tx
  integer::status
  logical::available,consumed
  real(real64)::t0r,t1r,n0,n1,soil_before,crop_before,soil_after,crop_after

  p%depth_m=0.5_real64
  p%nfrac_fom=[0.02_real64]
  p%nfrac_biomass=0.04_real64
  p%nfrac_humus=0.05_real64
  call initialize_soil_n_pool_state(p,[20.0_real64],5.0_real64,10.0_real64,1.0_real64,1.0_real64,soil_pool,status)
  call check(status==SOIL_N_OK,'soil init')
  call initialize_fmr_b111_soil_n_state(p,soil_pool,soil_state,status)
  call check(status==FMR_SOIL_N_OK,'soil transaction init')
  call initialize_b111_crop_n_state(10.0_real64,5.0_real64,4.0_real64,1.0_real64,crop,status)
  call check(status==B111_CROPN_OK,'crop init')
  call initialize_fmr_b111_soil_crop_n_state(soil_state,crop,initial,status)
  call check(status==FMR_B111_COUPLED_N_OK,'coupled init')
  allocate(committed,source=initial)

  tp%ratecon_fom=[0.2_real64]
  tp%asfa_fom_bio=[0.2_real64]
  tp%asfa_fom_hum=[0.3_real64]
  tp%ratecon_bio=0.1_real64
  tp%ratecon_hum=0.03_real64
  tp%asfa_bio=0.1_real64
  tp%asfa_hum=0.2_real64

  sf%dt_day=1.0_real64
  sf%wfrac_t=0.45_real64
  sf%wfrac_t0=0.45_real64
  sf%wflux_transp=0.02_real64
  sf%tcsf_n=1.0_real64
  sf%root_depth_cm=50.0_real64
  sf%drybd=1.2_real64
  sf%sorpcoef=0.4_real64

  env%temperature_c=20.0_real64
  env%temperature_reference_c=20.0_real64
  env%wfrac_sat=0.5_real64
  env%wfpscrit2=0.6_real64
  env%cdissi_half_kg_m2=0.05_real64
  env%nitrification_ref_per_day=0.1_real64
  env%denitrification_ref_per_day=0.05_real64

  cf%delt_day=1.0_real64
  cf%dvs=0.5_real64
  cf%dvsnlt=1.0_real64
  cf%dvsnt=1.2_real64
  cf%reltr=1.0_real64
  cf%nfixf=0.25_real64
  cf%tcnt_day=2.0_real64
  cf%fntrt=0.5_real64
  cf%wlv_kg_ha=100.0_real64
  cf%wst_kg_ha=100.0_real64
  cf%wrt_kg_ha=100.0_real64
  cf%wso_kg_ha=100.0_real64
  cf%nmaxlv=0.2_real64
  cf%nmaxst=0.1_real64
  cf%nmaxrt=0.08_real64
  cf%nmaxso=0.5_real64
  cf%rnflv=0.01_real64
  cf%rnfst=0.01_real64
  cf%rnfrt=0.01_real64

  call configure_fmr_b111_soil_crop_n_model(tp,[0.45_real64],0.50_real64,0.55_real64,env,sf,cf,model,status)
  call check(status==FMR_B111_COUPLED_N_OK,'model config')

  call snapshot_coupled(committed,soil_snap_state,crop_snap,t0r,t1r,consumed,available)
  call check(available.and..not.consumed,'pre-transaction snapshot')
  call soil_snap_state%snapshot(ps,soil_snap,available)
  call check(available,'pre soil snapshot')
  soil_before=soil_snap%nitrogen_total(ps)
  crop_before=(crop_snap%anlv_kg_ha+crop_snap%anst_kg_ha+crop_snap%anrt_kg_ha+crop_snap%anso_kg_ha)*1.0e-4_real64
  n0=soil_before+crop_before

  policy%temporal_mode=TX_TEMPORAL_MODEL_CERTIFICATE
  policy%max_retries=0
  policy%mass_tolerance=1.0e-10_real64
  policy%temporal_tolerance=1.0e-12_real64
  call execute_reference_interval(model,committed,0.0_real64,1.0_real64,policy,tx)
  call check(tx%status==TX_STATUS_ACCEPTED,'coupled transaction accepted')
  call model%snapshot_receipt(receipt,available)
  call check(available,'coupled receipt')
  call near(receipt%internal_soil_to_crop_kg_m2,receipt%crop_process%soil_uptake_kg_ha*1.0e-4_real64, &
       'soil crop internal transfer identity')
  call near(receipt%external_fixation_input_kg_m2,receipt%crop_process%fixation_kg_ha*1.0e-4_real64, &
       'fixation external input identity')

  call snapshot_coupled(committed,soil_snap_state,crop_snap,t0r,t1r,consumed,available)
  call check(available.and.consumed,'post commit lineage')
  call near(t0r,0.0_real64,'lineage t0')
  call near(t1r,1.0_real64,'lineage t1')
  call soil_snap_state%snapshot(ps,soil_snap,available)
  call check(available,'post soil snapshot')
  soil_after=soil_snap%nitrogen_total(ps)
  crop_after=(crop_snap%anlv_kg_ha+crop_snap%anst_kg_ha+crop_snap%anrt_kg_ha+crop_snap%anso_kg_ha)*1.0e-4_real64
  n1=soil_after+crop_after
  call near(n1,n0+tx%accepted_total_in-tx%accepted_total_out,'coupled whole-system N closure')

  ! Replay of the same accepted interval is rejected and leaves committed state unchanged.
  n0=n1
  call execute_reference_interval(model,committed,0.0_real64,1.0_real64,policy,tx)
  call check(tx%status==TX_STATUS_RETRY_EXHAUSTED,'duplicate interval rejected')
  call snapshot_coupled(committed,soil_snap_state,crop_snap,t0r,t1r,consumed,available)
  call soil_snap_state%snapshot(ps,soil_snap,available)
  soil_after=soil_snap%nitrogen_total(ps)
  crop_after=(crop_snap%anlv_kg_ha+crop_snap%anst_kg_ha+crop_snap%anrt_kg_ha+crop_snap%anso_kg_ha)*1.0e-4_real64
  call near(soil_after+crop_after,n0,'duplicate rollback identity')

  ! Fresh-state reconstruction must preserve interval lineage as persistent state.
  call initialize_fmr_b111_soil_crop_n_state(soil_snap_state,crop_snap,restarted,status,t0r,t1r,consumed)
  call check(status==FMR_B111_COUPLED_N_OK.and.restarted%ready(),'restart reconstruction')
  deallocate(committed)
  allocate(committed,source=restarted)
  call execute_reference_interval(model,committed,0.0_real64,1.0_real64,policy,tx)
  call check(tx%status==TX_STATUS_RETRY_EXHAUSTED,'restart duplicate interval rejected')
  call snapshot_coupled(committed,soil_snap_state,crop_snap,t0r,t1r,consumed,available)
  call soil_snap_state%snapshot(ps,soil_snap,available)
  soil_after=soil_snap%nitrogen_total(ps)
  crop_after=(crop_snap%anlv_kg_ha+crop_snap%anst_kg_ha+crop_snap%anrt_kg_ha+crop_snap%anso_kg_ha)*1.0e-4_real64
  call near(soil_after+crop_after,n0,'restart duplicate rollback identity')

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
    class default
      soil=fmr_b111_soil_n_state_t();crop=b111_crop_n_state_t()
    end select
  end subroutine

  subroutine near(x,y,label)
    real(real64),intent(in)::x,y
    character(len=*),intent(in)::label
    call check(abs(x-y)<=2.0e-10_real64*max(1.0_real64,abs(x),abs(y)),label)
  end subroutine
  subroutine check(ok,label)
    logical,intent(in)::ok
    character(len=*),intent(in)::label
    if(.not.ok)then
      print '(A)',trim(label)//' failed';error stop 1
    end if
  end subroutine
end program

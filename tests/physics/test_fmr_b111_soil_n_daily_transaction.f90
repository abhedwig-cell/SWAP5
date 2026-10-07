program test_fmr_b111_soil_n_daily_transaction
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference, only: transaction_state_t,transaction_policy_t,transaction_result_t, &
       execute_reference_interval,TX_STATUS_ACCEPTED,TX_STATUS_RETRY_EXHAUSTED,TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_soil_n_pool_state, only: soil_n_inventory_parameters_t,soil_n_pool_state_t,initialize_soil_n_pool_state,SOIL_N_OK
  use mod_b111_soil_organic_turnover, only: b111_organic_turnover_parameters_t
  use mod_b111_soil_n_daily_exchange, only: b111_soil_n_exchange_forcing_t
  use mod_b111_soil_n_daily_candidate, only: b111_soil_n_rate_environment_t,b111_soil_n_daily_candidate_result_t
  use mod_fmr_b111_soil_n_transaction, only: fmr_b111_soil_n_state_t,initialize_fmr_b111_soil_n_state,FMR_SOIL_N_OK
  use mod_fmr_b111_soil_n_daily_transaction
  implicit none

  type(soil_n_inventory_parameters_t)::p,ps
  type(soil_n_pool_state_t)::s,snap
  type(b111_organic_turnover_parameters_t)::tp
  type(b111_soil_n_exchange_forcing_t)::xf
  type(b111_soil_n_rate_environment_t)::env
  type(fmr_b111_soil_n_state_t)::initial
  type(fmr_b111_soil_n_daily_model_t)::model
  type(b111_soil_n_daily_candidate_result_t)::process
  class(transaction_state_t),allocatable::committed
  type(transaction_policy_t)::policy
  type(transaction_result_t)::tx
  integer::status
  logical::available
  real(real64)::n_before,n_after

  p%depth_m=0.5_real64;p%nfrac_fom=[0.02_real64];p%nfrac_biomass=0.04_real64;p%nfrac_humus=0.05_real64
  call initialize_soil_n_pool_state(p,[20.0_real64],5.0_real64,10.0_real64,1.0_real64,1.0_real64,s,status)
  call check(status==SOIL_N_OK,'pool init')
  n_before=s%nitrogen_total(p)
  call initialize_fmr_b111_soil_n_state(p,s,initial,status)
  call check(status==FMR_SOIL_N_OK,'transaction state init')
  allocate(committed,source=initial)

  tp%ratecon_fom=[0.2_real64];tp%asfa_fom_bio=[0.2_real64];tp%asfa_fom_hum=[0.3_real64]
  tp%ratecon_bio=0.1_real64;tp%ratecon_hum=0.03_real64;tp%asfa_bio=0.1_real64;tp%asfa_hum=0.2_real64
  xf%dt_day=1.0_real64;xf%wfrac_t=0.45_real64;xf%wfrac_t0=0.45_real64
  xf%tcsf_n=0.0_real64;xf%root_depth_cm=50.0_real64;xf%drybd=1.2_real64;xf%sorpcoef=0.4_real64
  env%temperature_c=20.0_real64;env%temperature_reference_c=20.0_real64;env%wfrac_sat=0.5_real64
  env%wfpscrit2=0.6_real64;env%cdissi_half_kg_m2=0.05_real64
  env%nitrification_ref_per_day=0.1_real64;env%denitrification_ref_per_day=0.05_real64

  call configure_fmr_b111_soil_n_daily_model(tp,[0.45_real64],0.50_real64,0.55_real64,env,xf,model,status)
  call check(status==FMR_B111_NDAY_OK,'model configure')
  policy%temporal_mode=TX_TEMPORAL_MODEL_CERTIFICATE;policy%max_retries=0
  policy%mass_tolerance=1.0e-11_real64;policy%temporal_tolerance=1.0e-12_real64
  call execute_reference_interval(model,committed,0.0_real64,1.0_real64,policy,tx)
  call check(tx%status==TX_STATUS_ACCEPTED,'daily transaction accepted')
  call check(tx%commits==1.and.tx%accepted_mass_complete,'daily transaction commit')
  call snapshot_state(committed,ps,snap,available)
  call check(available,'accepted snapshot')
  n_after=snap%nitrogen_total(ps)
  call near(n_after,n_before+tx%accepted_total_in-tx%accepted_total_out,'transaction whole N closure')
  call model%snapshot_process_result(process,available)
  call check(available,'process receipt')
  call near(tx%accepted_total_out,process%owner_receipt%external_n_output_kg_m2,'process transaction receipt identity')

  ! An impossible denitrification candidate must not mutate the accepted day-1 state.
  n_before=n_after
  env%denitrification_ref_per_day=1000.0_real64
  call configure_fmr_b111_soil_n_daily_model(tp,[0.45_real64],0.50_real64,0.55_real64,env,xf,model,status)
  call check(status==FMR_B111_NDAY_OK,'reject model configure')
  call execute_reference_interval(model,committed,1.0_real64,2.0_real64,policy,tx)
  call check(tx%status==TX_STATUS_RETRY_EXHAUSTED,'impossible daily candidate rejected')
  call snapshot_state(committed,ps,snap,available)
  call check(available,'post-reject snapshot')
  call near(snap%nitrogen_total(ps),n_before,'rejected trial rollback identity')

  print '(A)','FMR_B111_SOIL_N_DAILY_TRANSACTION_PASS'
contains
  subroutine snapshot_state(state,params,inventory,ok)
    class(transaction_state_t),allocatable,intent(in)::state
    type(soil_n_inventory_parameters_t),intent(out)::params
    type(soil_n_pool_state_t),intent(out)::inventory
    logical,intent(out)::ok
    ok=.false.
    select type(state)
    type is(fmr_b111_soil_n_state_t)
      call state%snapshot(params,inventory,ok)
    class default
      params=soil_n_inventory_parameters_t();inventory=soil_n_pool_state_t()
    end select
  end subroutine
  subroutine near(x,y,label)
    real(real64),intent(in)::x,y
    character(len=*),intent(in)::label
    call check(abs(x-y)<=1.0e-10_real64*max(1.0_real64,abs(x),abs(y)),label)
  end subroutine
  subroutine check(ok,label)
    logical,intent(in)::ok
    character(len=*),intent(in)::label
    if(.not.ok)then
      print '(A)',trim(label)//' failed';error stop 1
    end if
  end subroutine
end program

program test_fmr_b111_reactive_water_carrier
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference, only: transaction_state_t,transaction_policy_t,transaction_result_t, &
       execute_reference_interval,TX_STATUS_ACCEPTED,TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_fmr_serialized_reference_backend, only: fmr_water_flux_substep_trace_t
  use mod_solute_mobile_salt_state, only: mobile_salt_state_t,initialize_mobile_salt_state,SOLUTE_OK
  use mod_solute_compartment_state, only: solute_compartment_state_t,initialize_solute_compartment_state,SOLCOMP_OK
  use mod_fmr_b111_solute_transaction, only: fmr_b111_solute_state_t,initialize_fmr_b111_solute_state,FMR_SOLCOMP_OK
  use mod_fmr_b111_reactive_solute_transaction, only: fmr_b111_reactive_solute_model_t
  use mod_fmr_b111_reactive_water_carrier
  implicit none

  type(fmr_water_flux_substep_trace_t)::trace
  type(fmr_b111_reactive_static_forcing_t)::static
  type(fmr_b111_reactive_solute_model_t)::model
  type(mobile_salt_state_t)::mobile
  type(solute_compartment_state_t)::companion
  type(fmr_b111_solute_state_t)::initial
  class(transaction_state_t),allocatable::committed
  type(transaction_policy_t)::policy
  type(transaction_result_t)::tx
  integer::status

  trace%t0=10.0_real64;trace%t1=11.0_real64
  trace%top_flux=-0.1_real64
  trace%bottom_flux=-0.1_real64
  trace%pond_start=0.5_real64
  trace%pond_end=0.5_real64
  trace%water_start=[0.2_real64]
  trace%water_end=[0.2_real64]
  trace%subsurface_source=[0.0_real64]
  trace%drainage_sink=[0.0_real64]
  allocate(trace%drainage_sink_by_level(1,1));trace%drainage_sink_by_level=0.0_real64
  trace%root_sink=[0.0_real64]
  trace%net_node_source=[0.0_real64]
  trace%macropore_matrix_exchange=[0.0_real64]
  allocate(trace%macropore_matrix_exchange_domain(0,1))

  static%dz_cm=[10.0_real64]
  allocate(static%face_left_weight(0),static%face_right_weight(0),static%face_distance_cm(0), &
       static%theta_sat_left(0),static%dispersivity_cm(0))
  static%cseep_mg_cm3=1.0_real64
  static%cdrain_mg_cm3=0.0_real64
  static%tscf=0.0_real64
  static%rain_rate_cm_day=0.0_real64
  static%irrigation_rate_cm_day=0.0_real64
  static%molecular_diffusion_cm2_day=0.0_real64
  static%temperature_active=.false.
  static%temperature_c=[20.0_real64]
  static%gampar=[0.0_real64]
  static%rtheta=[0.2_real64]
  static%bexp=[1.0_real64]
  static%decpot=[0.0_real64]
  static%fdepth=[1.0_real64]
  static%bulk_density=[0.1_real64]
  static%kf=[1.0_real64]
  static%cref_mg_cm3=1.0_real64
  static%frexp=1.0_real64
  static%drain_age_day=0.0_real64

  call configure_fmr_b111_reactive_model_from_accepted_trace(trace,static,model,status)
  call check(status==FMR_B111_WATER_CARRIER_OK,'accepted trace model configure')

  call initialize_mobile_salt_state([10.0_real64],[0.2_real64],[1.0_real64],mobile,status)
  call check(status==SOLUTE_OK,'mobile init')
  call initialize_solute_compartment_state([1.0_real64],0.0_real64,0.0_real64,[0.0_real64],companion,status, &
       age_pond_previous_concentration=0.0_real64)
  call check(status==SOLCOMP_OK,'companion init')
  call initialize_fmr_b111_solute_state(mobile,companion,initial,status)
  call check(status==FMR_SOLCOMP_OK,'solute state init')
  allocate(committed,source=initial)

  policy%temporal_mode=TX_TEMPORAL_MODEL_CERTIFICATE
  policy%max_retries=0
  policy%mass_tolerance=1.0e-11_real64
  policy%temporal_tolerance=1.0e-12_real64
  call execute_reference_interval(model,committed,trace%t0,trace%t1,policy,tx)
  call check(tx%status==TX_STATUS_ACCEPTED,'accepted-water reactive transaction')
  call near(tx%accepted_total_in,0.0_real64,'no chemical input')
  call near(tx%accepted_total_out,0.1_real64,'accepted downward bottom chemical export')

  print '(A)','FMR_B111_REACTIVE_WATER_CARRIER_PASS'
contains
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

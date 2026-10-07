program test_fmr_b111_reactive_solute_transaction
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference, only: transaction_state_t,transaction_policy_t,transaction_result_t, &
       execute_reference_interval,TX_STATUS_ACCEPTED,TX_STATUS_RETRY_EXHAUSTED,TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_solute_mobile_salt_state, only: mobile_salt_state_t,initialize_mobile_salt_state,SOLUTE_OK
  use mod_solute_compartment_state, only: solute_compartment_state_t,initialize_solute_compartment_state,SOLCOMP_OK
  use mod_b111_reactive_solute_substep, only: b111_reactive_solute_substep_forcing_t
  use mod_b111_age_tracer_substep, only: b111_age_tracer_substep_forcing_t
  use mod_fmr_b111_solute_transaction, only: fmr_b111_solute_state_t,initialize_fmr_b111_solute_state,FMR_SOLCOMP_OK
  use mod_fmr_b111_reactive_solute_transaction
  implicit none

  type(mobile_salt_state_t)::m,ms
  type(solute_compartment_state_t)::c,cs
  type(fmr_b111_solute_state_t)::initial
  type(b111_reactive_solute_substep_forcing_t)::chem
  type(b111_age_tracer_substep_forcing_t)::age
  type(fmr_b111_reactive_solute_model_t)::model
  type(fmr_b111_reactive_solute_receipt_t)::receipt
  class(transaction_state_t),allocatable::committed
  type(transaction_policy_t)::policy
  type(transaction_result_t)::tx
  integer::status
  logical::available
  real(real64)::chemical_before,chemical_after,age_after

  call initialize_mobile_salt_state([10.0_real64],[0.2_real64],[1.0_real64],m,status)
  call check(status==SOLUTE_OK,'mobile init')
  call initialize_solute_compartment_state([1.0_real64],0.5_real64,0.25_real64,[0.0_real64],c,status, &
       age_pond_previous_concentration=0.0_real64)
  call check(status==SOLCOMP_OK,'companion init')
  call initialize_fmr_b111_solute_state(m,c,initial,status)
  call check(status==FMR_SOLCOMP_OK,'transaction state init')
  allocate(committed,source=initial)
  chemical_before=sum(m%mass_mg_cm2)+c%solute_total()

  chem%dt_day=1.0_real64
  chem%theta=[0.2_real64];chem%dz_cm=[10.0_real64]
  chem%q_face_up_cm_day=[0.0_real64,0.0_real64]
  chem%root_sink_cm_day=[0.0_real64]
  allocate(chem%qdra_cm_day(0,1))
  chem%cdrain_mg_cm3=0.0_real64;chem%cseep_mg_cm3=0.0_real64;chem%tscf=0.0_real64
  chem%pond_end_cm=0.5_real64;chem%molecular_diffusion_cm2_day=0.0_real64
  chem%temperature_active=.true.;chem%temperature_c=[20.0_real64];chem%gampar=[0.0_real64]
  chem%rtheta=[0.2_real64];chem%bexp=[1.0_real64];chem%decpot=[0.1_real64];chem%fdepth=[1.0_real64]
  chem%bulk_density=[0.1_real64];chem%kf=[1.0_real64];chem%cref_mg_cm3=1.0_real64;chem%frexp=1.0_real64

  age%dt_day=1.0_real64
  age%theta=[0.2_real64];age%theta_previous=[0.2_real64];age%dz_cm=[10.0_real64]
  age%q_face_up_cm_day=[0.0_real64,0.0_real64]
  age%root_sink_cm_day=[0.0_real64]
  allocate(age%qdra_cm_day(0,1))
  age%pond_previous_cm=0.0_real64;age%pond_end_cm=0.5_real64

  call configure_fmr_b111_reactive_solute_model(chem,age,model,status)
  call check(status==FMR_B111_REACTIVE_OK,'model configure')
  policy%temporal_mode=TX_TEMPORAL_MODEL_CERTIFICATE;policy%max_retries=0
  policy%mass_tolerance=1.0e-11_real64;policy%temporal_tolerance=1.0e-12_real64

  call execute_reference_interval(model,committed,0.0_real64,1.0_real64,policy,tx)
  call check(tx%status==TX_STATUS_ACCEPTED,'reactive transaction accepted')
  call model%snapshot_receipt(receipt,available)
  call check(available,'reactive receipt')
  call near(receipt%chemical%decay_output_mg_cm2,0.3_real64,'chemical decay receipt')
  call near(receipt%age%production_amount_cm_day,2.0_real64,'age production receipt')
  call snapshot_state(committed,ms,cs,available)
  call check(available,'accepted snapshot')
  chemical_after=sum(ms%mass_mg_cm2)+cs%solute_total()
  age_after=sum(cs%age_amount)
  call near(chemical_after,chemical_before-tx%accepted_total_out+tx%accepted_total_in,'chemical transaction closure')
  call near(age_after,2.0_real64,'age committed independently')
  call near(ms%concentration_mg_cm3(1),0.9_real64,'reactive concentration committed')
  call near(cs%age_pond_previous_concentration,0.0_real64,'age pond continuation committed')

  chemical_before=chemical_after
  call execute_reference_interval(model,committed,1.0_real64,1.5_real64,policy,tx)
  call check(tx%status==TX_STATUS_RETRY_EXHAUSTED,'wrong-duration reactive trial rejected')
  call snapshot_state(committed,ms,cs,available)
  call check(available,'post-reject snapshot')
  call near(sum(ms%mass_mg_cm2)+cs%solute_total(),chemical_before,'chemical rollback identity')
  call near(sum(cs%age_amount),age_after,'age rollback identity')

  print '(A)','FMR_B111_REACTIVE_SOLUTE_TRANSACTION_PASS'
contains
  subroutine snapshot_state(state,mobile,companion,ok)
    class(transaction_state_t),allocatable,intent(in)::state
    type(mobile_salt_state_t),intent(out)::mobile
    type(solute_compartment_state_t),intent(out)::companion
    logical,intent(out)::ok
    ok=.false.
    select type(state)
    type is(fmr_b111_solute_state_t)
      call state%snapshot(mobile,companion,ok)
    class default
      mobile=mobile_salt_state_t();companion=solute_compartment_state_t()
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

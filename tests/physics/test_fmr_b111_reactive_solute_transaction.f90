program test_fmr_b111_reactive_solute_transaction
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference, only: transaction_state_t,transaction_policy_t,transaction_result_t, &
       execute_reference_interval,TX_STATUS_ACCEPTED,TX_STATUS_RETRY_EXHAUSTED,TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_solute_mobile_salt_state, only: mobile_salt_state_t,initialize_mobile_salt_state,SOLUTE_OK
  use mod_solute_compartment_state, only: solute_compartment_state_t,initialize_solute_compartment_state,SOLCOMP_OK
  use mod_fmr_b111_solute_transaction, only: fmr_b111_solute_state_t,initialize_fmr_b111_solute_state,FMR_SOLCOMP_OK
  use mod_fmr_b111_reactive_solute_transaction
  implicit none

  type(mobile_salt_state_t)::m,ms
  type(solute_compartment_state_t)::s,ss
  type(fmr_b111_solute_state_t)::initial
  type(fmr_b111_reactive_forcing_t)::f
  type(fmr_b111_reactive_model_t)::model
  class(transaction_state_t),allocatable::committed
  type(transaction_policy_t)::policy
  type(transaction_result_t)::tx
  real(real64)::chem0,chem1,age0
  integer::status
  logical::ok

  call initialize_mobile_salt_state([10.0_real64],[0.2_real64],[1.0_real64],m,status)
  call check(status==SOLUTE_OK,'mobile init')
  call initialize_solute_compartment_state([1.0_real64],0.5_real64,0.0_real64,[2.0_real64],s,status,0.75_real64)
  call check(status==SOLCOMP_OK,'companion init')
  call initialize_fmr_b111_solute_state(m,s,initial,status)
  call check(status==FMR_SOLCOMP_OK,'state init')
  allocate(committed,source=initial)

  f%dz=[10.0_real64]
  f%theta=[0.2_real64]
  f%q=[-0.1_real64,0.0_real64]
  f%root=[0.0_real64]
  allocate(f%qdra(0,1))
  f%pond_end=0.2_real64
  f%temperature_active=.true.
  f%tsoil=[20.0_real64]
  f%gampar=[0.0_real64]
  f%rtheta=[0.2_real64]
  f%bexp=[1.0_real64]
  f%decpot=[0.1_real64]
  f%fdepth=[1.0_real64]
  f%bdens=[0.1_real64]
  f%kf=[1.0_real64]
  f%cref=1.0_real64
  f%frexp=1.0_real64
  f%dt=1.0_real64
  allocate(f%physics%dispersivity_cm(0),f%physics%theta_sat_left(0),f%physics%face_distance_cm(0), &
       f%physics%face_left_weight(0),f%physics%face_right_weight(0))

  call configure_fmr_b111_reactive_model(f,model,status)
  call check(status==FMR_B111_REACTIVE_OK,'model config')
  call snapshot_state(committed,ms,ss,ok)
  call check(ok,'pre snapshot')
  chem0=sum(ms%mass_mg_cm2)+ss%solute_total()
  age0=sum(ss%age_amount)+ss%pond_age_amount

  policy%temporal_mode=TX_TEMPORAL_MODEL_CERTIFICATE
  policy%max_retries=0
  policy%mass_tolerance=1.0e-10_real64
  policy%temporal_tolerance=1.0e-12_real64
  call execute_reference_interval(model,committed,0.0_real64,1.0_real64,policy,tx)
  call check(tx%status==TX_STATUS_ACCEPTED,'reactive transaction accepted')
  call snapshot_state(committed,ms,ss,ok)
  call check(ok,'accepted snapshot')
  chem1=sum(ms%mass_mg_cm2)+ss%solute_total()
  call near(chem1,chem0+tx%accepted_total_in-tx%accepted_total_out,'chemical transaction accounting')
  call near(sum(ss%age_amount)+ss%pond_age_amount,age0,'age stores unchanged')

  chem0=chem1
  call execute_reference_interval(model,committed,1.0_real64,1.5_real64,policy,tx)
  call check(tx%status==TX_STATUS_RETRY_EXHAUSTED,'wrong duration rejected')
  call snapshot_state(committed,ms,ss,ok)
  call near(sum(ms%mass_mg_cm2)+ss%solute_total(),chem0,'reject chemical rollback')
  call near(sum(ss%age_amount)+ss%pond_age_amount,age0,'reject age rollback')

  print '(A)','FMR_B111_REACTIVE_SOLUTE_TRANSACTION_PASS'
contains
  subroutine snapshot_state(state,mobile,companion,available)
    class(transaction_state_t),allocatable,intent(in)::state
    type(mobile_salt_state_t),intent(out)::mobile
    type(solute_compartment_state_t),intent(out)::companion
    logical,intent(out)::available
    available=.false.
    select type(state)
    type is(fmr_b111_solute_state_t)
      call state%snapshot(mobile,companion,available)
    class default
      mobile=mobile_salt_state_t();companion=solute_compartment_state_t()
    end select
  end subroutine
  subroutine near(x,y,label)
    real(real64),intent(in)::x,y
    character(len=*),intent(in)::label
    call check(abs(x-y)<=5e-10_real64*max(1.0_real64,abs(x),abs(y)),label)
  end subroutine
  subroutine check(condition,label)
    logical,intent(in)::condition
    character(len=*),intent(in)::label
    if(.not.condition)then
      print '(A)',trim(label)//' failed';error stop 1
    end if
  end subroutine
end program

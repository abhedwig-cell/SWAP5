program test_fmr_b111_age_tracer_transaction
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference, only: transaction_state_t,transaction_policy_t,transaction_result_t, &
       execute_reference_interval,TX_STATUS_ACCEPTED,TX_STATUS_RETRY_EXHAUSTED,TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_solute_mobile_salt_state, only: mobile_salt_state_t,initialize_mobile_salt_state,SOLUTE_OK
  use mod_solute_compartment_state, only: solute_compartment_state_t,initialize_solute_compartment_state,SOLCOMP_OK
  use mod_fmr_b111_solute_transaction, only: fmr_b111_solute_state_t,initialize_fmr_b111_solute_state,FMR_SOLCOMP_OK
  use mod_fmr_b111_age_tracer_transaction
  implicit none

  type(mobile_salt_state_t)::m,ms
  type(solute_compartment_state_t)::s,ss
  type(fmr_b111_solute_state_t)::initial
  type(fmr_b111_age_forcing_t)::f
  type(fmr_b111_age_model_t)::model
  class(transaction_state_t),allocatable::committed
  type(transaction_policy_t)::policy
  type(transaction_result_t)::tx
  real(real64)::chem0,age0,age1
  integer::status
  logical::ok

  call initialize_mobile_salt_state([10.0_real64,20.0_real64],[0.2_real64,0.3_real64], &
       [1.0_real64,1.0_real64],m,status)
  call check(status==SOLUTE_OK,'mobile init')
  call initialize_solute_compartment_state([1.0_real64,2.0_real64],0.5_real64,0.25_real64, &
       [2.0_real64,3.0_real64],s,status,1.0_real64)
  call check(status==SOLCOMP_OK,'companion init')
  call initialize_fmr_b111_solute_state(m,s,initial,status)
  call check(status==FMR_SOLCOMP_OK,'reactive state init')
  allocate(committed,source=initial)

  f%dz=[10.0_real64,20.0_real64]
  f%theta_start=[0.2_real64,0.3_real64]
  f%theta_end=[0.2_real64,0.3_real64]
  f%q=[-0.1_real64,0.0_real64,0.0_real64]
  f%root=[0.0_real64,0.0_real64]
  allocate(f%qdra(0,2))
  f%pond_end=0.2_real64
  f%dt=0.5_real64
  allocate(f%physics%dispersivity_cm(1),f%physics%theta_sat_left(1),f%physics%face_distance_cm(1), &
       f%physics%face_left_weight(1),f%physics%face_right_weight(1))
  f%physics%molecular_diffusion_cm2_day=0.0_real64
  f%physics%dispersivity_cm=0.0_real64
  f%physics%theta_sat_left=0.45_real64
  f%physics%face_distance_cm=15.0_real64
  f%physics%face_left_weight=0.5_real64
  f%physics%face_right_weight=0.5_real64

  call configure_fmr_b111_age_model(f,model,status)
  call check(status==FMR_B111_AGE_OK,'model config')
  call snapshot_state(committed,ms,ss,ok)
  call check(ok,'pre snapshot')
  chem0=sum(ms%mass_mg_cm2)+ss%solute_total()
  age0=sum(ss%age_amount)+ss%pond_age_amount

  policy%temporal_mode=TX_TEMPORAL_MODEL_CERTIFICATE
  policy%max_retries=0
  policy%mass_tolerance=1.0e-11_real64
  policy%temporal_tolerance=1.0e-12_real64
  call execute_reference_interval(model,committed,0.0_real64,0.5_real64,policy,tx)
  call check(tx%status==TX_STATUS_ACCEPTED,'age transaction accepted')
  call snapshot_state(committed,ms,ss,ok)
  call check(ok,'accepted snapshot')
  age1=sum(ss%age_amount)+ss%pond_age_amount
  call near(age1,age0+tx%accepted_total_in-tx%accepted_total_out,'age transaction accounting')
  call near(sum(ms%mass_mg_cm2)+ss%solute_total(),chem0,'chemical stores unchanged')

  age0=age1
  call execute_reference_interval(model,committed,0.5_real64,0.75_real64,policy,tx)
  call check(tx%status==TX_STATUS_RETRY_EXHAUSTED,'wrong duration rejected')
  call snapshot_state(committed,ms,ss,ok)
  call near(sum(ss%age_amount)+ss%pond_age_amount,age0,'reject age rollback')
  call near(sum(ms%mass_mg_cm2)+ss%solute_total(),chem0,'reject chemical rollback')

  print '(A)','FMR_B111_AGE_TRACER_TRANSACTION_PASS'
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
    call check(abs(x-y)<=3e-11_real64*max(1.0_real64,abs(x),abs(y)),label)
  end subroutine
  subroutine check(condition,label)
    logical,intent(in)::condition
    character(len=*),intent(in)::label
    if(.not.condition)then
      print '(A)',trim(label)//' failed';error stop 1
    end if
  end subroutine
end program

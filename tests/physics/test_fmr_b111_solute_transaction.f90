program test_fmr_b111_solute_transaction
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference, only: transaction_state_t, transaction_policy_t, transaction_result_t, &
       execute_reference_interval, TX_STATUS_ACCEPTED, TX_STATUS_RETRY_EXHAUSTED, TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_solute_mobile_salt_state, only: mobile_salt_state_t, initialize_mobile_salt_state, SOLUTE_OK
  use mod_solute_compartment_state, only: solute_compartment_state_t, initialize_solute_compartment_state, SOLCOMP_OK
  use mod_fmr_b111_solute_transaction, only: fmr_b111_solute_state_t, fmr_b111_solute_model_t, &
       fmr_b111_solute_transfer_rate_t, initialize_fmr_b111_solute_state, configure_fmr_b111_solute_model, &
       FMR_SOLCOMP_OK, FMR_SOLCOMP_AQUIFER_UNAPPROVED
  implicit none

  type(mobile_salt_state_t) :: mobile, mobile_snapshot
  type(solute_compartment_state_t) :: companion, companion_snapshot
  type(fmr_b111_solute_state_t) :: initial
  type(fmr_b111_solute_model_t) :: model
  type(fmr_b111_solute_transfer_rate_t) :: rate
  class(transaction_state_t), allocatable :: committed
  type(transaction_policy_t) :: policy
  type(transaction_result_t) :: result
  real(real64) :: dz(2), theta(2)
  integer :: status
  logical :: available

  dz=[10.0_real64,10.0_real64]
  theta=[0.2_real64,0.2_real64]
  call initialize_mobile_salt_state(dz,theta,[1.0_real64,1.0_real64],mobile,status)
  call check(status==SOLUTE_OK,'mobile init')
  call initialize_solute_compartment_state([1.0_real64,1.0_real64],0.5_real64,0.25_real64, &
       [0.0_real64,0.0_real64],companion,status)
  call check(status==SOLCOMP_OK,'companion init')
  call initialize_fmr_b111_solute_state(mobile,companion,initial,status)
  call check(status==FMR_SOLCOMP_OK,'transaction state init')
  allocate(committed,source=initial)

  allocate(rate%mobile_delta_per_day(2),rate%sorbed_delta_per_day(2),rate%age_delta_per_day(2))
  rate%mobile_delta_per_day=[-0.6_real64,-0.4_real64]
  rate%sorbed_delta_per_day=[0.5_real64,0.5_real64]
  rate%pond_delta_per_day=0.2_real64
  rate%age_delta_per_day=[0.3_real64,0.4_real64]
  rate%external_input_per_day=0.2_real64
  call configure_fmr_b111_solute_model(dz,theta,rate,model,status)
  call check(status==FMR_SOLCOMP_OK,'model config')

  policy%temporal_mode=TX_TEMPORAL_MODEL_CERTIFICATE
  policy%max_retries=0
  policy%mass_tolerance=1.0e-12_real64
  call execute_reference_interval(model,committed,0.0_real64,1.0_real64,policy,result)
  call check(result%status==TX_STATUS_ACCEPTED,'accepted interval')
  call check(abs(result%accepted_total_in-0.2_real64)<1.0e-12_real64,'external receipt')

  call snapshot_committed(committed,mobile_snapshot,companion_snapshot,available)
  call check(available,'accepted snapshot')
  call near(sum(mobile_snapshot%mass_mg_cm2),3.0_real64,'mobile after sorption')
  call near(sum(companion_snapshot%sorbed_matrix_mass),3.0_real64,'sorbed after transfer')
  call near(companion_snapshot%pond_mass,0.7_real64,'pond input')
  call near(sum(companion_snapshot%age_amount),0.7_real64,'age production outside chemical mass')
  call near(companion_snapshot%aquifer_mass,0.25_real64,'aquifer unchanged')

  call initialize_fmr_b111_solute_state(mobile_snapshot,companion_snapshot,initial,status)
  call check(status==FMR_SOLCOMP_OK,'restart reconstruction status')
  call check(initial%ready(),'restart reconstruction')

  rate%aquifer_delta_per_day=0.1_real64
  call configure_fmr_b111_solute_model(dz,theta,rate,model,status)
  call check(status==FMR_SOLCOMP_AQUIFER_UNAPPROVED,'aquifer fail closed')

  rate%aquifer_delta_per_day=0.0_real64
  rate%mobile_delta_per_day=[-100.0_real64,0.0_real64]
  rate%sorbed_delta_per_day=[0.0_real64,0.0_real64]
  rate%pond_delta_per_day=0.0_real64
  rate%age_delta_per_day=0.0_real64
  rate%external_input_per_day=0.0_real64
  rate%external_output_per_day=100.0_real64
  call configure_fmr_b111_solute_model(dz,theta,rate,model,status)
  call check(status==FMR_SOLCOMP_OK,'overdraw model config')
  call execute_reference_interval(model,committed,1.0_real64,2.0_real64,policy,result)
  call check(result%status==TX_STATUS_RETRY_EXHAUSTED,'rejected overdraw')

  call snapshot_committed(committed,mobile_snapshot,companion_snapshot,available)
  call check(available,'post-reject snapshot')
  call near(sum(mobile_snapshot%mass_mg_cm2),3.0_real64,'mobile rollback')
  call near(sum(companion_snapshot%sorbed_matrix_mass),3.0_real64,'sorbed rollback')
  call near(companion_snapshot%pond_mass,0.7_real64,'pond rollback')
  call near(sum(companion_snapshot%age_amount),0.7_real64,'age rollback')

  print '(A)','FMR_B111_SOLUTE_TRANSACTION_PASS'

contains
  subroutine snapshot_committed(state,m,c,ok)
    class(transaction_state_t),allocatable,intent(in)::state
    type(mobile_salt_state_t),intent(out)::m
    type(solute_compartment_state_t),intent(out)::c
    logical,intent(out)::ok
    ok=.false.
    select type(state)
    type is(fmr_b111_solute_state_t)
      call state%snapshot(m,c,ok)
    class default
      m=mobile_salt_state_t();c=solute_compartment_state_t()
    end select
  end subroutine

  subroutine near(x,y,label)
    real(real64),intent(in)::x,y
    character(len=*),intent(in)::label
    call check(abs(x-y)<=1.0e-12_real64*max(1.0_real64,abs(x),abs(y)),label)
  end subroutine

  subroutine check(ok,label)
    logical,intent(in)::ok
    character(len=*),intent(in)::label
    if(.not.ok)then
      print '(A)',trim(label)//' failed'
      error stop 1
    end if
  end subroutine
end program

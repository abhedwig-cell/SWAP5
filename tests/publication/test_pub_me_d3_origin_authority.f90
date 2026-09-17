module pub_me_d3_fixture
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t, trial_outcome_t, &
       TX_MASS_MISSING_NONE, TX_MASS_MISSING_UNSPECIFIED
  use mod_canonical_contracts, only: canonical_state_t, canonical_forcing_t, canonical_interval_t, &
       canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_parameters_t, kernel_model_t
  implicit none
  private

  type, extends(canonical_state_t), public :: d3_state_t
    real(real64) :: storage = 0.0_real64
  contains
    procedure :: clone => d3_clone
  end type d3_state_t

  type, extends(canonical_forcing_t), public :: d3_forcing_t
  end type d3_forcing_t

  type, extends(kernel_parameters_t), public :: d3_parameters_t
  end type d3_parameters_t

  type, extends(kernel_model_t), public :: d3_model_t
  contains
    procedure :: configure_parameters => d3_configure_parameters
    procedure :: execution_admitted => d3_execution_admitted
    procedure :: advance => d3_advance
    procedure :: storage => d3_storage
    procedure :: storage_accounting_status => d3_storage_status
    procedure :: temporal_error => d3_temporal_error
  end type d3_model_t

  public :: new_state, physical_value, assert_true, same_real

contains

  subroutine new_state(state, value)
    class(transaction_state_t), allocatable, intent(out) :: state
    real(real64), intent(in) :: value
    allocate(d3_state_t :: state)
    select type(s => state)
    type is(d3_state_t)
      s%storage = value
    end select
  end subroutine new_state

  subroutine d3_clone(self, copy)
    class(d3_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy
    allocate(d3_state_t :: copy)
    select type(s => copy)
    type is(d3_state_t)
      s%storage = self%storage
    end select
  end subroutine d3_clone

  subroutine d3_configure_parameters(self, parameters)
    class(d3_model_t), intent(inout) :: self
    class(kernel_parameters_t), intent(in) :: parameters
    if (.not. same_type_as(self,self) .or. .not. same_type_as(parameters,parameters)) &
      error stop 'D3 unreachable parameter types'
  end subroutine d3_configure_parameters

  logical function d3_execution_admitted(self, parameters, numerical_config) result(admitted)
    class(d3_model_t), intent(in) :: self
    class(kernel_parameters_t), intent(in) :: parameters
    type(canonical_numerical_config_t), intent(in) :: numerical_config
    admitted = same_type_as(self,self) .and. same_type_as(parameters,parameters) .and. &
         numerical_config%max_committed_substeps > 0
  end function d3_execution_admitted

  subroutine d3_advance(self, state, t0, t1, outcome)
    class(d3_model_t), intent(inout) :: self
    class(transaction_state_t), intent(inout) :: state
    real(real64), intent(in) :: t0, t1
    type(trial_outcome_t), intent(out) :: outcome
    real(real64) :: dt

    outcome = trial_outcome_t()
    dt = t1-t0
    select type(s => state)
    type is(d3_state_t)
      s%storage = s%storage + dt
    class default
      return
    end select
    outcome%solver_ok = .true.
    outcome%mass_in = dt
    outcome%mass_out = 0.0_real64
    outcome%mass_accounting_complete = .true.
    outcome%missing_mass_contribution_mask = TX_MASS_MISSING_NONE
    if (.not. same_type_as(self,self)) error stop 'D3 unreachable model type'
  end subroutine d3_advance

  function d3_storage(self, state) result(value)
    class(d3_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    real(real64) :: value
    value = huge(0.0_real64)
    select type(s => state)
    type is(d3_state_t)
      value = s%storage
    end select
    if (.not. same_type_as(self,self)) error stop 'D3 unreachable storage model'
  end function d3_storage

  subroutine d3_storage_status(self, state, complete, missing_mask)
    class(d3_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    logical, intent(out) :: complete
    integer(int64), intent(out) :: missing_mask

    complete = .false.
    missing_mask = TX_MASS_MISSING_UNSPECIFIED
    select type(s => state)
    type is(d3_state_t)
      complete = .true.
      missing_mask = TX_MASS_MISSING_NONE
    end select
    if (.not. same_type_as(self,self)) error stop 'D3 unreachable storage status model'
  end subroutine d3_storage_status

  function d3_temporal_error(self, full_state, half_state) result(value)
    class(d3_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: full_state, half_state
    real(real64) :: value
    value = 0.0_real64
    if (.not. same_type_as(self,self) .or. .not. same_type_as(full_state,full_state) .or. &
        .not. same_type_as(half_state,half_state)) error stop 'D3 unreachable temporal types'
  end function d3_temporal_error

  real(real64) function physical_value(state) result(value)
    class(transaction_state_t), allocatable, intent(in) :: state
    value = huge(0.0_real64)
    select type(s => state)
    type is(d3_state_t)
      value = s%storage
    class default
      error stop 'D3 unexpected physical state type'
    end select
  end function physical_value

  pure logical function same_real(a,b) result(equal)
    real(real64), intent(in) :: a,b
    integer(int64) :: ia,ib
    ia=transfer(a,ia); ib=transfer(b,ib)
    equal=ia==ib
  end function same_real

  subroutine assert_true(condition,label)
    logical,intent(in)::condition
    character(len=*),intent(in)::label
    if(.not.condition) then
      write(*,'(A,1X,A)') 'PUB_ME_D3_FAIL',trim(label)
      error stop 1
    end if
  end subroutine assert_true
end module pub_me_d3_fixture

program test_pub_me_d3_origin_authority
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t
  use mod_canonical_contracts, only: canonical_numerical_config_t, CANONICAL_STATUS_COMPLETED
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_candidate_state_t, kernel_executor_t, &
       kernel_result_t, kernel_diagnostics_t, kernel_reconstruct_committed_state_trusted, &
       KERNEL_COMMIT_STATUS_COMMITTED, KERNEL_COMMIT_STATUS_LINEAGE_MISMATCH, &
       KERNEL_COMMIT_STATUS_STALE_REVISION, KERNEL_COMMIT_STATUS_TIME_MISMATCH, &
       KERNEL_TRUSTED_RECONSTRUCTION_OK
  use pub_me_d3_fixture, only: d3_model_t,d3_parameters_t,d3_forcing_t,new_state,physical_value,assert_true,same_real
  implicit none

  type(d3_model_t), target :: model
  type(d3_parameters_t) :: parameters
  type(d3_forcing_t) :: forcing
  type(kernel_executor_t) :: executor
  type(canonical_numerical_config_t) :: config

  call setup(executor,model,config)
  call test_clean(executor,parameters,forcing,config)
  call test_lineage(executor,parameters,forcing,config)
  call test_stale_revision(executor,parameters,forcing,config)
  call test_time_origin(executor,parameters,forcing,config)

  write(*,'(A)') 'PUB_ME_D3_CLASSIFICATION=STRUCTURAL_PREVENTION'
  write(*,'(A)') 'PUB_ME_D3_ORIGIN_AUTHORITY_EXPERIMENT=PASS'

contains

  subroutine setup(k,m,c)
    type(kernel_executor_t),intent(out)::k
    type(d3_model_t),target,intent(inout)::m
    type(canonical_numerical_config_t),intent(out)::c
    call k%bind_model(m)
    c=canonical_numerical_config_t()
    c%transaction%mass_tolerance=1.0e-12_real64
    c%transaction%temporal_tolerance=1.0e-12_real64
    c%transaction%max_retries=1
    c%max_committed_substeps=4
  end subroutine setup

  subroutine init_committed(state,lineage,time0)
    type(kernel_committed_state_t),intent(out)::state
    integer(int64),intent(in)::lineage
    real(real64),intent(in)::time0
    class(transaction_state_t),allocatable::initial
    logical::ok
    call new_state(initial,0.0_real64)
    call state%initialize(lineage,initial,ok,time0)
    call assert_true(ok,'committed initialization')
  end subroutine init_committed

  subroutine make_candidate(k,p,f,c,state,t0,t1,candidate,diag)
    type(kernel_executor_t),intent(inout)::k
    type(d3_parameters_t),intent(in)::p
    type(d3_forcing_t),intent(in)::f
    type(canonical_numerical_config_t),intent(in)::c
    type(kernel_committed_state_t),intent(in)::state
    real(real64),intent(in)::t0,t1
    type(kernel_candidate_state_t),intent(out)::candidate
    type(kernel_diagnostics_t),intent(out)::diag
    type(kernel_result_t)::result
    call k%advance_interval(p,state,f,c,t0,t1,result,candidate,diag)
    call assert_true(result%status==CANONICAL_STATUS_COMPLETED .and. result%completed,'candidate execution completed')
    call assert_true(candidate%ready(),'candidate ready')
  end subroutine make_candidate

  subroutine snapshot_value(state,value)
    type(kernel_committed_state_t),intent(in)::state
    real(real64),intent(out)::value
    class(transaction_state_t),allocatable::snap
    logical::ok
    call state%snapshot(snap,ok)
    call assert_true(ok,'committed snapshot available')
    value=physical_value(snap)
  end subroutine snapshot_value

  subroutine committed_time(state,value)
    type(kernel_committed_state_t),intent(in)::state
    real(real64),intent(out)::value
    logical::ok
    call state%current_time(value,ok)
    call assert_true(ok,'committed time available')
  end subroutine committed_time

  subroutine test_clean(k,p,f,c)
    type(kernel_executor_t),intent(inout)::k
    type(d3_parameters_t),intent(in)::p
    type(d3_forcing_t),intent(in)::f
    type(canonical_numerical_config_t),intent(in)::c
    type(kernel_committed_state_t)::state
    type(kernel_candidate_state_t)::candidate
    type(kernel_diagnostics_t)::trial_diag,commit_diag
    logical::did_commit
    integer::status
    real(real64)::v,t

    call init_committed(state,301_int64,0.0_real64)
    call make_candidate(k,p,f,c,state,0.0_real64,1.0_real64,candidate,trial_diag)
    commit_diag=kernel_diagnostics_t()
    call k%commit_candidate(state,candidate,commit_diag,did_commit,status)
    call assert_true(did_commit .and. status==KERNEL_COMMIT_STATUS_COMMITTED,'clean commit succeeds')
    call assert_true(state%current_revision()==1_int64,'clean revision exactly one')
    call committed_time(state,t)
    call snapshot_value(state,v)
    call assert_true(same_real(t,1.0_real64),'clean committed time 1')
    call assert_true(same_real(v,1.0_real64),'clean physical endpoint 1')
    call assert_true(.not.candidate%ready(),'clean candidate consumed')
    call assert_true(commit_diag%committed_state_mutations==1 .and. commit_diag%commit_rejections==0,'clean diagnostics')
    write(*,'(A)') 'PUB_ME_D3_CLEAN_COMMIT=PASS'
  end subroutine test_clean

  subroutine test_lineage(k,p,f,c)
    type(kernel_executor_t),intent(inout)::k
    type(d3_parameters_t),intent(in)::p
    type(d3_forcing_t),intent(in)::f
    type(canonical_numerical_config_t),intent(in)::c
    type(kernel_committed_state_t)::source,target
    type(kernel_candidate_state_t)::candidate
    type(kernel_diagnostics_t)::trial_diag,commit_diag
    logical::did_commit
    integer::status
    real(real64)::before,after,t

    call init_committed(source,301_int64,0.0_real64)
    call make_candidate(k,p,f,c,source,0.0_real64,1.0_real64,candidate,trial_diag)
    call init_committed(target,302_int64,0.0_real64)
    call snapshot_value(target,before)
    commit_diag=kernel_diagnostics_t()
    call k%commit_candidate(target,candidate,commit_diag,did_commit,status)
    call snapshot_value(target,after); call committed_time(target,t)

    call assert_true(.not.did_commit,'lineage commit rejected')
    call assert_true(status==KERNEL_COMMIT_STATUS_LINEAGE_MISMATCH,'lineage status')
    call assert_true(target%current_revision()==0_int64 .and. same_real(t,0.0_real64),'lineage provenance unchanged')
    call assert_true(same_real(before,after),'lineage physical state unchanged')
    call assert_true(candidate%ready(),'lineage rejected candidate retained')
    call assert_true(commit_diag%lineage_mismatch_rejections==1 .and. commit_diag%commit_rejections==1,'lineage diagnostics')
    call assert_true(commit_diag%committed_state_mutations==0,'lineage zero mutation')
    write(*,'(A)') 'PUB_ME_D3_LINEAGE_MISMATCH_STRUCTURAL_PREVENTION=PASS'
  end subroutine test_lineage

  subroutine test_stale_revision(k,p,f,c)
    type(kernel_executor_t),intent(inout)::k
    type(d3_parameters_t),intent(in)::p
    type(d3_forcing_t),intent(in)::f
    type(canonical_numerical_config_t),intent(in)::c
    type(kernel_committed_state_t)::state
    type(kernel_candidate_state_t)::old_candidate,new_candidate
    type(kernel_diagnostics_t)::d1,d2,commit_new,commit_old
    logical::did_commit
    integer::status
    real(real64)::after_new,after_old,t

    call init_committed(state,303_int64,0.0_real64)
    call make_candidate(k,p,f,c,state,0.0_real64,1.0_real64,old_candidate,d1)
    call make_candidate(k,p,f,c,state,0.0_real64,1.0_real64,new_candidate,d2)

    commit_new=kernel_diagnostics_t()
    call k%commit_candidate(state,new_candidate,commit_new,did_commit,status)
    call assert_true(did_commit .and. status==KERNEL_COMMIT_STATUS_COMMITTED,'new candidate commits')
    call snapshot_value(state,after_new)

    commit_old=kernel_diagnostics_t()
    call k%commit_candidate(state,old_candidate,commit_old,did_commit,status)
    call snapshot_value(state,after_old); call committed_time(state,t)

    call assert_true(.not.did_commit,'stale commit rejected')
    call assert_true(status==KERNEL_COMMIT_STATUS_STALE_REVISION,'stale revision status')
    call assert_true(state%current_revision()==1_int64 .and. same_real(t,1.0_real64),'stale provenance unchanged')
    call assert_true(same_real(after_new,after_old),'stale physical state unchanged')
    call assert_true(old_candidate%ready(),'stale candidate retained')
    call assert_true(commit_old%stale_revision_rejections==1 .and. commit_old%commit_rejections==1,'stale diagnostics')
    call assert_true(commit_old%committed_state_mutations==0,'stale zero mutation')
    write(*,'(A)') 'PUB_ME_D3_STALE_REVISION_STRUCTURAL_PREVENTION=PASS'
  end subroutine test_stale_revision

  subroutine test_time_origin(k,p,f,c)
    type(kernel_executor_t),intent(inout)::k
    type(d3_parameters_t),intent(in)::p
    type(d3_forcing_t),intent(in)::f
    type(canonical_numerical_config_t),intent(in)::c
    type(kernel_committed_state_t)::source,target
    type(kernel_candidate_state_t)::candidate
    type(kernel_diagnostics_t)::trial_diag,commit_diag
    class(transaction_state_t),allocatable::physical
    logical::ok,did_commit
    integer::status,reconstruct_status
    real(real64)::before,after,t

    call init_committed(source,304_int64,0.0_real64)
    call make_candidate(k,p,f,c,source,0.0_real64,1.0_real64,candidate,trial_diag)
    call source%snapshot(physical,ok)
    call assert_true(ok,'time-origin source snapshot')
    call kernel_reconstruct_committed_state_trusted(target,304_int64,0_int64,physical,0.25_real64,.true.,ok,reconstruct_status)
    call assert_true(ok .and. reconstruct_status==KERNEL_TRUSTED_RECONSTRUCTION_OK,'time-origin target reconstructed')
    call snapshot_value(target,before)

    commit_diag=kernel_diagnostics_t()
    call k%commit_candidate(target,candidate,commit_diag,did_commit,status)
    call snapshot_value(target,after); call committed_time(target,t)

    call assert_true(.not.did_commit,'time-origin commit rejected')
    call assert_true(status==KERNEL_COMMIT_STATUS_TIME_MISMATCH,'time-origin status')
    call assert_true(target%current_revision()==0_int64 .and. same_real(t,0.25_real64),'time-origin provenance unchanged')
    call assert_true(same_real(before,after),'time-origin physical state unchanged')
    call assert_true(candidate%ready(),'time-origin rejected candidate retained')
    call assert_true(commit_diag%time_origin_rejections==1 .and. commit_diag%commit_rejections==1,'time-origin diagnostics')
    call assert_true(commit_diag%committed_state_mutations==0,'time-origin zero mutation')
    write(*,'(A)') 'PUB_ME_D3_TIME_ORIGIN_STRUCTURAL_PREVENTION=PASS'
  end subroutine test_time_origin

end program test_pub_me_d3_origin_authority

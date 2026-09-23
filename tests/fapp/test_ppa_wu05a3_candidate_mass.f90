program test_ppa_wu05a3_candidate_mass
  use, intrinsic :: iso_fortran_env, only: real64,int64
  use mod_ppa_wu05a2_macropore_state
  use mod_ppa_wu05a3_candidate_mass
  implicit none
  type(ppa_wu05a2_macropore_committed_t) :: state
  type(ppa_wu05a2_macropore_checkpoint_t) :: cp
  type(ppa_wu05a2_macropore_candidate_t) :: trial
  type(candidate_mass_account) :: account
  real(real64) :: exchange(1,2),matrix(2),drain(2)
  logical :: ok
  integer :: status
  call ppa_wu05a2_initialize_payload(1,2,state%payload,ok)
  call require(ok,1)
  state%lineage_id=1_int64; state%revision=0_int64
  state%payload%domain_water_storage=1.0_real64; state%payload%pore_water=0.5_real64
  call ppa_wu05a2_capture_checkpoint(state,cp,ok)
  call require(ok,2)
  call ppa_wu05a2_begin_candidate(cp,trial,ok)
  call require(ok,3)
  trial%payload%domain_water_storage=1.125_real64; trial%payload%pore_water(1,1)=0.625_real64
  exchange(1,:)=[0.125_real64,-0.0625_real64]
  matrix=exchange(1,:); drain=[0.0_real64,0.0625_real64]
  call invoke()
  call require(status==0 .and. account%valid,4)
  call require(abs(account%macropore_internal+account%matrix_internal)<tiny(1.0_real64),5)
  call require(abs(account%storage_change+account%matrix_internal- &
      (account%top_input-account%rapid_output))<tiny(1.0_real64),6)
  ! Same total, wrong cells: a scalar-only check would miss the double booking.
  matrix=matrix+[0.125_real64,-0.125_real64]
  call invoke()
  call require(status==2 .and. .not.account%valid,7)
  matrix=exchange(1,:)
  trial%payload%domain_water_storage=1.25_real64
  call invoke()
  call require(status==3 .and. .not.account%valid,8)
  trial%origin_revision=1_int64
  call invoke()
  call require(status==1 .and. .not.account%valid,9)
  call ppa_wu05a2_discard_candidate(trial)
  call invoke()
  call require(status==1 .and. .not.account%valid,10)
  call require(abs(state%payload%domain_water_storage(1)-1.0_real64)<tiny(1.0_real64),11)
  call check_domain_cancellation()
  print '(A)','PPA_WU05A3_MASS_INTERNAL_CANCELLATION=PASS'
  print '(A)','PPA_WU05A3_MASS_CELL_TRANSFER_GUARD=PASS'
  print '(A)','PPA_WU05A3_MASS_INVALID_CANDIDATE_GUARD=PASS'
  print '(A)','PPA_WU05A3_MASS_DOMAIN_TRANSFER_GUARD=PASS'
contains
  subroutine check_domain_cancellation()
    type(ppa_wu05a2_macropore_committed_t) :: s
    type(ppa_wu05a2_macropore_checkpoint_t) :: checkpoint
    type(ppa_wu05a2_macropore_candidate_t) :: candidate
    real(real64) :: rates(2,2),zero(2)
    call ppa_wu05a2_initialize_payload(2,2,s%payload,ok)
    call require(ok,12)
    s%lineage_id=2_int64; s%revision=0_int64
    s%payload%domain_water_storage=1.0_real64; s%payload%pore_water=0.5_real64
    call ppa_wu05a2_capture_checkpoint(s,checkpoint,ok)
    call require(ok,13)
    call ppa_wu05a2_begin_candidate(checkpoint,candidate,ok)
    call require(ok,14)
    candidate%payload%domain_water_storage=[1.25_real64,0.75_real64]
    candidate%payload%pore_water(1,:)=0.625_real64; candidate%payload%pore_water(2,:)=0.375_real64
    zero=0.0_real64; rates=0.0_real64
    call account_candidate_mass(checkpoint,candidate,1.0_real64,zero,rates,zero,zero,0.0_real64,account,status)
    call require(status==3 .and. .not.account%valid,15)
    call require(abs(account%budget_residual)<tiny(1.0_real64),16)
    rates(1,1)=0.125_real64; rates(2,1)=-0.125_real64
    candidate%payload%domain_water_storage=[0.875_real64,1.125_real64]
    candidate%payload%pore_water(1,:)=0.4375_real64; candidate%payload%pore_water(2,:)=0.5625_real64
    call account_candidate_mass(checkpoint,candidate,1.0_real64,zero,rates,zero,zero,0.0_real64,account,status)
    call require(status==0 .and. account%valid,17)
  end subroutine

  subroutine invoke()
    call account_candidate_mass(cp,trial,1.0_real64,[0.25_real64],exchange,drain,matrix, &
        0.0_real64,account,status)
  end subroutine
  subroutine require(ok,code)
    logical,intent(in) :: ok
    integer,intent(in) :: code
    if(.not.ok) then
      print *, 'CANDIDATE_MASS_FAIL',code
      error stop 1
    end if
  end subroutine
end program

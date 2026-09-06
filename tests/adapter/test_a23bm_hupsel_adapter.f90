program test_a23bm_hupsel_adapter
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference
  use mod_a23bm_hupsel_legacy_adapter
  implicit none

  integer :: failures
  failures = 0
  call test_physical_reference(failures)
  call test_physical_retry_no_leak(failures)
  if (failures /= 0) then
    write(*,'(A,I0)') 'A23BM_PHYSICAL_ADAPTER_GATE FAIL failures=', failures
    error stop 1
  end if
  write(*,'(A)') 'A23BM_PHYSICAL_ADAPTER_GATE PASS'

contains

  subroutine configure_model(model, suffix)
    type(legacy_hupsel_model_t), intent(out) :: model
    character(len=*), intent(in) :: suffix
    character(len=1024) :: value
    call env_required('A23BM_ARCHIVE', value); model%archive=trim(value)
    call env_required('A23BM_EXE', value); model%swap_exe=trim(value)
    call env_required('A23BM_HELPER', value); model%helper_script=trim(value)
    call env_required('A23BM_WORKROOT', value); model%work_root=trim(value)//'/'//trim(suffix)
    call execute_command_line('mkdir -p "'//trim(model%work_root)//'"', wait=.true.)
  end subroutine configure_model

  subroutine load_inputs(seed, direct, seed_fin, seed_fout, seed_bal, direct_fin, direct_fout, direct_bal)
    type(legacy_hupsel_state_t), intent(out) :: seed, direct
    real(real64), intent(out) :: seed_fin, seed_fout, seed_bal, direct_fin, direct_fout, direct_bal
    character(len=1024) :: seed_meta, direct_meta, rf
    character(len=64) :: rs
    real(real64) :: si, sf
    integer :: flag
    logical :: ok
    call env_required('A23BM_SEED_META', seed_meta)
    call env_required('A23BM_DIRECT_META', direct_meta)
    call load_legacy_state_meta(trim(seed_meta), seed, ok); call expect(ok,'seed meta load')
    call load_legacy_state_meta(trim(direct_meta), direct, ok); call expect(ok,'direct meta load')
    call read_legacy_meta(trim(seed_meta),flag,rf,rs,si,sf,seed_bal,seed_fin,seed_fout,ok); call expect(ok,'seed detail load')
    call read_legacy_meta(trim(direct_meta),flag,rf,rs,si,sf,direct_bal,direct_fin,direct_fout,ok); call expect(ok,'direct detail load')
  end subroutine load_inputs

  subroutine test_physical_reference(failures)
    integer, intent(inout) :: failures
    type(legacy_hupsel_state_t) :: seed, direct
    class(transaction_state_t), allocatable :: committed
    type(legacy_hupsel_model_t) :: model
    type(transaction_policy_t) :: policy
    type(transaction_result_t) :: result
    real(real64) :: seed_fin,seed_fout,seed_bal,direct_fin,direct_fout,direct_bal

    call configure_model(model,'normal')
    call load_inputs(seed,direct,seed_fin,seed_fout,seed_bal,direct_fin,direct_fout,direct_bal)
    allocate(committed, source=seed)
    policy%temporal_tolerance=0.0_real64
    policy%mass_tolerance=1.0e-6_real64
    policy%retry_scale=0.5_real64
    policy%max_retries=2
    call execute_reference_interval(model, committed, 0.0_real64, 2.0_real64, policy, result)

    call check(result%status==TX_STATUS_ACCEPTED,'physical reference accepted',failures)
    call check(result%full_trials==1 .and. result%half_trials==2,'always sampled physical route',failures)
    call check(abs(result%temporal_error)<=0.0_real64,'full and two-half restart state byte-identical',failures)
    call check(result%rollbacks==0 .and. result%commits==1,'single physical commit',failures)
    call check(abs(result%full_mass_residual)<=1.0e-6_real64,'full legacy mass gate',failures)
    call check(abs(result%half_mass_residual)<=1.0e-6_real64,'two-half legacy mass gate',failures)
    select type(committed)
    type is(legacy_hupsel_state_t)
      call check(committed%restart_sha256==direct%restart_sha256,'A23BL endpoint equals direct B1.6 endpoint',failures)
      call close(committed%storage_cm,direct%storage_cm,0.0_real64,'physical storage exact',failures)
      call close(committed%cumulative_flux_in_cm,direct_fin-seed_fin,1.0e-12_real64,'accepted input flux sum',failures)
      call close(committed%cumulative_flux_out_cm,direct_fout-seed_fout,1.0e-12_real64,'accepted output flux sum',failures)
      call close(committed%cumulative_legacy_balance_cm,direct_bal-seed_bal,1.0e-12_real64,'legacy balance accumulation',failures)
    class default
      call check(.false.,'physical committed state type',failures)
    end select
  end subroutine test_physical_reference

  subroutine test_physical_retry_no_leak(failures)
    integer, intent(inout) :: failures
    type(legacy_hupsel_state_t) :: seed, direct
    class(transaction_state_t), allocatable :: committed
    type(legacy_hupsel_model_t) :: model
    type(transaction_policy_t) :: policy
    type(transaction_result_t) :: result
    real(real64) :: seed_fin,seed_fout,seed_bal,direct_fin,direct_fout,direct_bal

    call configure_model(model,'retry')
    call load_inputs(seed,direct,seed_fin,seed_fout,seed_bal,direct_fin,direct_fout,direct_bal)
    allocate(committed, source=seed)
    model%fail_on_call=1
    policy%temporal_tolerance=0.0_real64
    policy%mass_tolerance=1.0e-6_real64
    policy%retry_scale=0.5_real64
    policy%max_retries=2
    call execute_reference_interval(model, committed, 0.0_real64, 4.0_real64, policy, result)

    call check(result%status==TX_STATUS_ACCEPTED,'physical retry accepted',failures)
    call check(result%solver_rejections==1,'one injected rejected physical trial',failures)
    call check(result%rollbacks==1 .and. result%retries==1,'physical rollback retry accounting',failures)
    call close(result%accepted_dt,2.0_real64,0.0_real64,'retry accepted shortened interval',failures)
    call check(abs(result%temporal_error)<=0.0_real64,'retry full/two-half exact',failures)
    select type(committed)
    type is(legacy_hupsel_state_t)
      call check(committed%restart_sha256==direct%restart_sha256,'rejected poison cannot alter physical endpoint',failures)
      call close(committed%storage_cm,direct%storage_cm,0.0_real64,'retry physical storage exact',failures)
      call close(committed%cumulative_flux_in_cm,direct_fin-seed_fin,1.0e-12_real64,'retry input flux exact',failures)
      call close(committed%cumulative_flux_out_cm,direct_fout-seed_fout,1.0e-12_real64,'retry output flux exact',failures)
    class default
      call check(.false.,'retry committed state type',failures)
    end select
  end subroutine test_physical_retry_no_leak

  subroutine env_required(name,value)
    character(len=*),intent(in)::name
    character(len=*),intent(out)::value
    integer :: stat
    call get_environment_variable(name,value,status=stat)
    if(stat/=0 .or. len_trim(value)==0) error stop 'A23BM missing environment variable'
  end subroutine env_required

  subroutine check(condition,label,failures)
    logical,intent(in)::condition
    character(len=*),intent(in)::label
    integer,intent(inout),optional::failures
    if(.not.condition) then
      write(*,'(A,A)') 'FAIL ',trim(label)
      if(present(failures)) failures=failures+1
    end if
  end subroutine check

  subroutine expect(condition,label)
    logical,intent(in)::condition
    character(len=*),intent(in)::label
    if(.not.condition) then
      write(*,'(A,A)') 'FATAL ',trim(label)
      error stop 2
    end if
  end subroutine expect

  subroutine close(actual,expected,tol,label,failures)
    real(real64),intent(in)::actual,expected,tol
    character(len=*),intent(in)::label
    integer,intent(inout)::failures
    call check(abs(actual-expected)<=tol,label,failures)
  end subroutine close

end program test_a23bm_hupsel_adapter

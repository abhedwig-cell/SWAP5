module mod_a23bm_hupsel_legacy_adapter
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference
  implicit none
  private

  integer, parameter :: PATHLEN = 1024

  type, extends(transaction_state_t), public :: legacy_hupsel_state_t
    character(len=PATHLEN) :: restart_file = ''
    character(len=64) :: restart_sha256 = ''
    real(real64) :: storage_cm = 0.0_real64
    real(real64) :: cumulative_flux_in_cm = 0.0_real64
    real(real64) :: cumulative_flux_out_cm = 0.0_real64
    real(real64) :: cumulative_legacy_balance_cm = 0.0_real64
  contains
    procedure :: clone => legacy_clone
  end type legacy_hupsel_state_t

  type, extends(transaction_model_t), public :: legacy_hupsel_model_t
    character(len=PATHLEN) :: python_exe = 'python3'
    character(len=PATHLEN) :: helper_script = ''
    character(len=PATHLEN) :: archive = ''
    character(len=PATHLEN) :: swap_exe = ''
    character(len=PATHLEN) :: work_root = ''
    integer :: advance_calls = 0
    integer :: fail_on_call = 0
    integer :: next_job = 0
  contains
    procedure :: advance => legacy_advance
    procedure :: storage => legacy_storage
    procedure :: temporal_error => legacy_temporal_error
  end type legacy_hupsel_model_t

  public :: load_legacy_state_meta, read_legacy_meta

contains

  subroutine legacy_clone(self, copy)
    class(legacy_hupsel_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy
    allocate(legacy_hupsel_state_t :: copy)
    select type(copy)
    type is(legacy_hupsel_state_t)
      copy = self
    end select
  end subroutine legacy_clone

  subroutine legacy_advance(self, state, t0, t1, outcome)
    class(legacy_hupsel_model_t), intent(inout) :: self
    class(transaction_state_t), intent(inout) :: state
    real(real64), intent(in) :: t0, t1
    type(trial_outcome_t), intent(out) :: outcome

    character(len=PATHLEN) :: meta, workdir
    character(len=8192) :: command
    logical :: ok
    real(real64) :: storage_initial, storage_final, balance, flux_in, flux_out, net_mass
    character(len=PATHLEN) :: restart_file
    character(len=64) :: restart_sha
    integer :: solver_flag

    outcome = trial_outcome_t()
    self%advance_calls = self%advance_calls + 1
    self%next_job = self%next_job + 1

    select type(state)
    type is(legacy_hupsel_state_t)
      if (self%fail_on_call == self%advance_calls) then
        ! Deliberately poison only the trial clone. A23BL must discard it.
        state%storage_cm = -999999.0_real64
        state%restart_file = 'POISONED_REJECTED_TRIAL'
        outcome%solver_ok = .false.
        return
      end if

      write(workdir,'(A,"/job_",I0)') trim(self%work_root), self%next_job
      write(meta,'(A,".meta")') trim(workdir)
      command = trim(self%python_exe)//' '//trim(self%helper_script)// &
        ' --archive '//trim(quote(self%archive))//' --exe '//trim(quote(self%swap_exe))// &
        ' --restart '//trim(quote(state%restart_file))//' --t0 '//trim(real_string(t0))// &
        ' --t1 '//trim(real_string(t1))//' --workdir '//trim(quote(workdir))//' --meta '//trim(quote(meta))
      call execute_command_line(trim(command), wait=.true.)
      call read_legacy_meta(meta, solver_flag, restart_file, restart_sha, storage_initial, storage_final, balance, flux_in, flux_out, ok)
      if (.not. ok .or. solver_flag /= 1) then
        outcome%solver_ok = .false.
        return
      end if

      if (abs(storage_initial - state%storage_cm) > 5.0e-5_real64) then
        outcome%solver_ok = .false.
        return
      end if

      net_mass = (storage_final - storage_initial) - balance
      if (net_mass >= 0.0_real64) then
        outcome%mass_in = net_mass
        outcome%mass_out = 0.0_real64
      else
        outcome%mass_in = 0.0_real64
        outcome%mass_out = -net_mass
      end if
      outcome%solver_ok = .true.
      outcome%nonlinear_iterations = 0  ! legacy process does not expose this in A23BM yet

      state%restart_file = restart_file
      state%restart_sha256 = restart_sha
      state%storage_cm = storage_final
      state%cumulative_flux_in_cm = state%cumulative_flux_in_cm + flux_in
      state%cumulative_flux_out_cm = state%cumulative_flux_out_cm + flux_out
      state%cumulative_legacy_balance_cm = state%cumulative_legacy_balance_cm + balance
    class default
      error stop 'A23BM unexpected state type'
    end select
  end subroutine legacy_advance

  function legacy_storage(self, state) result(value)
    class(legacy_hupsel_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    real(real64) :: value
    if (len_trim(self%archive) < 0) error stop 'unreachable'
    select type(state)
    type is(legacy_hupsel_state_t)
      value = state%storage_cm
    class default
      error stop 'A23BM unexpected state in storage'
    end select
  end function legacy_storage

  function legacy_temporal_error(self, full_state, half_state) result(value)
    class(legacy_hupsel_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: full_state, half_state
    real(real64) :: value
    character(len=64) :: a, b
    if (len_trim(self%work_root) < 0) error stop 'unreachable'
    select type(full_state)
    type is(legacy_hupsel_state_t)
      a = full_state%restart_sha256
    class default
      error stop 'A23BM unexpected full state'
    end select
    select type(half_state)
    type is(legacy_hupsel_state_t)
      b = half_state%restart_sha256
    class default
      error stop 'A23BM unexpected half state'
    end select
    if (len_trim(a) == 64 .and. a == b) then
      value = 0.0_real64
    else
      value = 1.0_real64
    end if
  end function legacy_temporal_error

  subroutine load_legacy_state_meta(meta_path, state, ok)
    character(len=*), intent(in) :: meta_path
    type(legacy_hupsel_state_t), intent(out) :: state
    logical, intent(out) :: ok
    integer :: solver_flag
    character(len=PATHLEN) :: restart_file
    character(len=64) :: restart_sha
    real(real64) :: si, sf, bal, fin, fout
    call read_legacy_meta(meta_path, solver_flag, restart_file, restart_sha, si, sf, bal, fin, fout, ok)
    if (.not. ok .or. solver_flag /= 1) then
      ok = .false.; return
    end if
    state%restart_file = restart_file
    state%restart_sha256 = restart_sha
    state%storage_cm = sf
    state%cumulative_flux_in_cm = 0.0_real64
    state%cumulative_flux_out_cm = 0.0_real64
    state%cumulative_legacy_balance_cm = 0.0_real64
  end subroutine load_legacy_state_meta

  subroutine read_legacy_meta(path, solver_flag, restart_file, restart_sha, si, sf, bal, fin, fout, ok)
    character(len=*), intent(in) :: path
    integer, intent(out) :: solver_flag
    character(len=PATHLEN), intent(out) :: restart_file
    character(len=64), intent(out) :: restart_sha
    real(real64), intent(out) :: si, sf, bal, fin, fout
    logical, intent(out) :: ok
    character(len=2048) :: line, key, val
    integer :: u, ios, pos
    solver_flag=0; restart_file=''; restart_sha=''; si=0; sf=0; bal=0; fin=0; fout=0; ok=.false.
    open(newunit=u,file=trim(path),status='old',action='read',iostat=ios)
    if (ios /= 0) return
    do
      read(u,'(A)',iostat=ios) line
      if (ios /= 0) exit
      pos=index(line,'='); if (pos <= 0) cycle
      key=adjustl(line(:pos-1)); val=adjustl(line(pos+1:))
      select case(trim(key))
      case('solver_ok'); read(val,*,iostat=ios) solver_flag
      case('restart_file'); restart_file=trim(val)
      case('restart_sha256'); restart_sha=trim(val)
      case('storage_initial_cm'); read(val,*,iostat=ios) si
      case('storage_final_cm'); read(val,*,iostat=ios) sf
      case('legacy_balance_residual_cm'); read(val,*,iostat=ios) bal
      case('physical_flux_in_cm'); read(val,*,iostat=ios) fin
      case('physical_flux_out_cm'); read(val,*,iostat=ios) fout
      end select
      if (ios /= 0) exit
    end do
    close(u)
    ok = (ios < 0 .or. ios == 0) .and. solver_flag == 1 .and. len_trim(restart_file) > 0 .and. len_trim(restart_sha) == 64
  end subroutine read_legacy_meta

  function quote(s) result(q)
    character(len=*), intent(in) :: s
    character(len=PATHLEN+2) :: q
    q = '"'//trim(s)//'"'
  end function quote

  function real_string(x) result(s)
    real(real64), intent(in) :: x
    character(len=64) :: s
    write(s,'(ES24.16E3)') x
    s=adjustl(s)
  end function real_string

end module mod_a23bm_hupsel_legacy_adapter

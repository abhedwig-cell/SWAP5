module MOD_arrays
  implicit none
  integer, parameter :: fillen=256
end module MOD_arrays

module swap_exchange
  implicit none
  type :: swap_input
    integer :: dummy=0
  end type
  type :: swap_output
    integer :: dummy=0
  end type
end module swap_exchange

module MOD_swap_base
  implicit none
  integer :: swcrop=0, swsnow=0, swmacro=0
end module MOD_swap_base

module fci13_backend_globals
  use, intrinsic :: iso_fortran_env, only: real64
  implicit none
  integer, parameter :: n=3
  real(real64) :: h(n)=0, theta(n)=0, hm1(n)=0, thetm1(n)=0
  real(real64) :: pond=0, pondm1=0, gwl=0, gwlm1=0, volact=0, ldwet=0, spev=0, saev=0
  integer :: failure_mode=0
contains
  subroutine seed_backend()
    h=[1.0_real64,2.0_real64,3.0_real64]
    theta=[0.2_real64,0.3_real64,0.4_real64]
    hm1=h-0.1_real64
    thetm1=theta-0.01_real64
    pond=0.2_real64; pondm1=0.1_real64
    gwl=-100.0_real64; gwlm1=-101.0_real64
    volact=50.0_real64; ldwet=1.0_real64; spev=2.0_real64; saev=3.0_real64
    failure_mode=0
  end subroutine seed_backend
end module fci13_backend_globals

module mod_b1_10_process_checkpoint
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference, only: transaction_state_t
  use fci13_backend_globals
  implicit none
  private
  type :: dummy_optional_state_t
    real(real64) :: marker=0.0_real64
  end type
  type :: dummy_crop_state_t
    real(real64) :: sicact=0.0_real64
  end type
  type, extends(transaction_state_t), public :: b1_10_process_state_t
    real(real64), allocatable :: h(:), theta(:), hm1(:), thetm1(:)
    real(real64) :: pond=0, pondm1=0, gwl=0, gwlm1=0, volact=0, ldwet=0, spev=0, saev=0
    type(dummy_optional_state_t), allocatable :: thermal, solute, irrigation, wofost
    type(dummy_crop_state_t), allocatable :: crop
  contains
    procedure :: clone => clone_state
  end type
  public :: capture_b1_10_process_state, restore_b1_10_process_state
contains
  subroutine capture_b1_10_process_state(state)
    type(b1_10_process_state_t), intent(inout) :: state
    state%h=h; state%theta=theta; state%hm1=hm1; state%thetm1=thetm1
    state%pond=pond; state%pondm1=pondm1; state%gwl=gwl; state%gwlm1=gwlm1
    state%volact=volact; state%ldwet=ldwet; state%spev=spev; state%saev=saev
  end subroutine
  subroutine restore_b1_10_process_state(state)
    type(b1_10_process_state_t), intent(in) :: state
    h=state%h; theta=state%theta; hm1=state%hm1; thetm1=state%thetm1
    pond=state%pond; pondm1=state%pondm1; gwl=state%gwl; gwlm1=state%gwlm1
    volact=state%volact; ldwet=state%ldwet; spev=state%spev; saev=state%saev
  end subroutine
  subroutine clone_state(self, copy)
    class(b1_10_process_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy
    allocate(b1_10_process_state_t :: copy)
    select type(target=>copy)
    type is (b1_10_process_state_t)
      target%h=self%h; target%theta=self%theta; target%hm1=self%hm1; target%thetm1=self%thetm1
      target%pond=self%pond; target%pondm1=self%pondm1; target%gwl=self%gwl; target%gwlm1=self%gwlm1
      target%volact=self%volact; target%ldwet=self%ldwet; target%spev=self%spev; target%saev=self%saev
      if (allocated(self%thermal)) allocate(target%thermal, source=self%thermal)
      if (allocated(self%solute)) allocate(target%solute, source=self%solute)
      if (allocated(self%irrigation)) allocate(target%irrigation, source=self%irrigation)
      if (allocated(self%crop)) allocate(target%crop, source=self%crop)
      if (allocated(self%wofost)) allocate(target%wofost, source=self%wofost)
    class default
      error stop 'clone failure'
    end select
  end subroutine
end module mod_b1_10_process_checkpoint

module mod_b1_10_legacy_trial_capsule
  use mod_transaction_reference, only: transaction_attempt_context_t
  implicit none
  type, public :: b1_10_legacy_trial_capsule_t
    integer :: marker=0
  end type
  public :: capture_b1_10_legacy_trial_capsule, restore_b1_10_legacy_trial_capsule
contains
  subroutine capture_b1_10_legacy_trial_capsule(x)
    type(b1_10_legacy_trial_capsule_t), intent(inout) :: x
    x%marker=1
  end subroutine
  subroutine restore_b1_10_legacy_trial_capsule(x)
    type(b1_10_legacy_trial_capsule_t), intent(in) :: x
    if (x%marker < 0) error stop 'bad capsule'
  end subroutine
end module mod_b1_10_legacy_trial_capsule

subroutine SWAP(iCaller, iTask, tstart_in, tend_in, swp_file, outfile, toswap, fromswap, worker, trial_mass, interval)
  use, intrinsic :: iso_fortran_env, only: real64
  use MOD_arrays, only: fillen
  use swap_exchange, only: swap_input, swap_output
  use mod_a23bu_worker_execution_context, only: a23bu_worker_context_t
  use mod_b1_10_trial_mass, only: b1_10_trial_mass_t, record_b1_10_trial_mass_step, invalidate_b1_10_trial_mass
  use mod_b1_10_interval_seam, only: b1_10_interval_seam_t
  use fci13_backend_globals
  implicit none
  integer, intent(in) :: iCaller, iTask
  real(8), intent(inout) :: tstart_in, tend_in
  character(len=fillen), intent(in), optional :: swp_file
  character(len=fillen), intent(in), optional :: outfile
  type(swap_input), intent(in), optional :: toswap
  type(swap_output), intent(out), optional :: fromswap
  type(a23bu_worker_context_t), intent(inout), optional :: worker
  type(b1_10_trial_mass_t), intent(inout), optional :: trial_mass
  type(b1_10_interval_seam_t), intent(inout), optional :: interval
  real(real64) :: duration

  if (iCaller /= 0) error stop 'FCI13 stub: caller'
  if (present(swp_file) .or. present(outfile) .or. present(toswap) .or. present(fromswap)) error stop 'FCI13 stub: unexpected IO args'
  if (.not. present(worker) .or. .not. present(trial_mass) .or. .not. present(interval)) error stop 'FCI13 stub: missing args'
  if (iTask == 22) then
    if (failure_mode == 2) return
    interval%prepared=.true.
    interval%complete=.false.
    return
  end if
  if (iTask /= 2) error stop 'FCI13 stub: task'

  duration=tend_in-tstart_in
  worker%diagnostics%headcalc_calls=2
  worker%diagnostics%nonlinear_iterations=3
  worker%diagnostics%jacobian_builds=2
  worker%diagnostics%linear_solves=2
  if (failure_mode == 1) then
    h=h+99.0_real64
    worker%history%iwarn=1
    call invalidate_b1_10_trial_mass(trial_mass)
    return
  end if
  h=h+duration
  theta=theta+0.01_real64*duration
  hm1=h-0.05_real64
  thetm1=theta-0.005_real64
  volact=volact+0.7_real64*duration
  pond=pond+0.3_real64*duration
  call record_b1_10_trial_mass_step(trial_mass, 1.25_real64*duration, 0.0_real64, 0.0_real64, 0.0_real64, &
       0.0_real64, 0.0_real64, 0.0_real64, 0.0_real64, 0.0_real64, 0.0_real64, 0.0_real64, 0.25_real64*duration)
  interval%complete=.true.
end subroutine SWAP

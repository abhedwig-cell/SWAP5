program test_b1_10_water_checkpoint
  use, intrinsic :: iso_fortran_env, only: real64
  use MOD_grid, only: numnod
  use variables, only: h, theta, hm1, thetm1, pond, pondm1, gwl, gwlm1, &
                       volact, ldwet, spev, saev
  use mod_transaction_reference, only: transaction_state_t
  use mod_b1_10_water_checkpoint
  implicit none
  type(b1_10_water_state_t) :: state
  class(transaction_state_t), allocatable :: copied
  integer :: i

  numnod = 4
  do i = 1, numnod
    h(i) = -10.0_real64 * i
    theta(i) = 0.1_real64 * i
    hm1(i) = h(i) - 1.0_real64
    thetm1(i) = theta(i) - 0.01_real64
  end do
  pond=1.25_real64; pondm1=1.0_real64; gwl=-75.0_real64; gwlm1=-80.0_real64
  volact=12.5_real64; ldwet=2.5_real64; spev=3.5_real64; saev=1.5_real64
  call capture_b1_10_water_state(state)
  call state%clone(copied)

  h(1:numnod)=999.0_real64; theta(1:numnod)=999.0_real64
  hm1(1:numnod)=999.0_real64; thetm1(1:numnod)=999.0_real64
  pond=999.0_real64; pondm1=999.0_real64; gwl=999.0_real64; gwlm1=999.0_real64
  volact=999.0_real64; ldwet=999.0_real64; spev=999.0_real64; saev=999.0_real64
  call restore_b1_10_water_state(state)

  if (maxval(abs(h(1:numnod)-state%h)) > 0.0_real64) error stop 1
  if (maxval(abs(theta(1:numnod)-state%theta)) > 0.0_real64) error stop 2
  if (maxval(abs(hm1(1:numnod)-state%hm1)) > 0.0_real64) error stop 3
  if (maxval(abs(thetm1(1:numnod)-state%thetm1)) > 0.0_real64) error stop 4
  if (abs(pond-state%pond) > 0.0_real64 .or. abs(gwl-state%gwl) > 0.0_real64 .or. &
      abs(volact-state%volact) > 0.0_real64 .or. abs(ldwet-state%ldwet) > 0.0_real64 .or. &
      abs(spev-state%spev) > 0.0_real64 .or. abs(saev-state%saev) > 0.0_real64) error stop 5
  select type (c => copied)
  type is (b1_10_water_state_t)
    if (maxval(abs(c%h-state%h)) > 0.0_real64 .or. abs(c%pond-state%pond) > 0.0_real64) error stop 6
  class default
    error stop 7
  end select
  print '(A)', 'FCI06_B1_10_WATER_CHECKPOINT PASS'
end program test_b1_10_water_checkpoint

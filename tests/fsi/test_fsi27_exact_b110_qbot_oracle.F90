program test_fsi27_exact_b110_qbot_oracle
  use, intrinsic :: iso_fortran_env, only: int64
  use MOD_grid, only: numnod, dz
  use variables, only: h, theta, thetm1, qbot, numbit, volact, volm1, swbotb, hbot, qtop, dt
  implicit none

  character(len=128) :: arg
  real(8) :: prescribed_qbot
  integer :: i, stat

  if (command_argument_count() /= 1) error stop 'F-SI27 exact B1.10 oracle requires qbot argument'
  call get_command_argument(1, arg)
  read(arg, *, iostat=stat) prescribed_qbot
  if (stat /= 0) error stop 'F-SI27 exact B1.10 oracle bad qbot argument'

  ! Native legacy SWAP convention: positive qbot enters through the lower face.
  ! SWBOTB=2 is prescribed regional/native bottom flux. hbot is deliberately
  ! irrelevant and poisoned with a finite extreme value rather than used as a control.
  swbotb = 2
  qbot = prescribed_qbot
  hbot = 987654.321d0
  qtop = -1.0d0
  dt = 0.25d0
  h = -75.0d0
  theta = 0.30d0
  thetm1 = 0.30d0

  volact = sum(theta*dz)
  volm1 = volact
  call headcalc()
  call watstor()
  call fluxes()

  write(*,'(A,4(1X,Z16.16))') 'H_BITS', (transfer(h(i),0_int64), i=1,numnod)
  write(*,'(A,4(1X,Z16.16))') 'THETA_BITS', (transfer(theta(i),0_int64), i=1,numnod)
  write(*,'(A,1X,Z16.16)') 'QBOT_BITS', transfer(qbot,0_int64)
  write(*,'(A,1X,I0)') 'ITER', numbit
end program test_fsi27_exact_b110_qbot_oracle
program test_fsi16_exact_b110_oracle
  use, intrinsic :: iso_fortran_env, only: int64
  use MOD_grid, only: numnod, dz
  use variables, only: h, theta, thetm1, qbot, numbit, volact, volm1, swbotb, hbot, qtop, dt
  implicit none
  integer :: i

  swbotb = 5
  hbot = -74.0d0
  qtop = -1.0d0
  dt = 0.25d0
  h = -75.0d0
  theta = 0.30d0
  thetm1 = 0.30d0

  ! Exact B1.10 execution order: watstor starts from the already committed
  ! interval-start storage, HeadCalc advances the accepted state, watstor then
  ! moves VOLM1<-VOLACT and evaluates VOLACT=SUM(theta*dz), followed by fluxes.
  volact = sum(theta*dz)
  volm1 = volact
  call headcalc()
  call watstor()
  call fluxes()

  write(*,'(A,4(1X,Z16.16))') 'H_BITS', (transfer(h(i),0_int64), i=1,numnod)
  write(*,'(A,4(1X,Z16.16))') 'THETA_BITS', (transfer(theta(i),0_int64), i=1,numnod)
  write(*,'(A,1X,Z16.16)') 'QBOT_BITS', transfer(qbot,0_int64)
  write(*,'(A,1X,I0)') 'ITER', numbit
end program test_fsi16_exact_b110_oracle

module MOD_sss
  implicit none
contains
  subroutine sss_solver()
  end subroutine sss_solver
  real(8) function sss_solver_gwl()
    sss_solver_gwl = -1.0d0
  end function sss_solver_gwl
end module MOD_sss

module MOD_swap_base
  implicit none
  integer :: swmacro = 0, swinco = 1, swhyst = 0, swsolve = 1
end module MOD_swap_base

module MOD_arrays
  implicit none
  integer, parameter :: mabbc = 4
end module MOD_arrays

module MOD_grid
  implicit none
  integer, parameter :: numnod = 4
  real(8), parameter :: z(numnod) = [-0.25d0, -0.75d0, -1.50d0, -2.50d0]
  real(8), parameter :: dz(numnod) = [0.50d0, 0.50d0, 1.00d0, 1.00d0]
end module MOD_grid

module MOD_macropore
  implicit none
contains
  subroutine macrostatevar(task)
    integer, intent(in) :: task
    if (task < 0) error stop 'invalid task'
  end subroutine macrostatevar
  subroutine macropore(task)
    integer, intent(in) :: task
    if (task < 0) error stop 'invalid task'
  end subroutine macropore
end module MOD_macropore

module MOD_MvG
  implicit none
contains
  real(8) function watcon(node, head)
    integer, intent(in) :: node
    real(8), intent(in) :: head
    if (node < 1 .or. head > huge(head)) error stop 'invalid watcon'
    watcon = 0.3d0
  end function watcon
  real(8) function moiscap(node, head)
    integer, intent(in) :: node
    real(8), intent(in) :: head
    if (node < 1 .or. head > huge(head)) error stop 'invalid moiscap'
    moiscap = 0.01d0
  end function moiscap
  real(8) function hconduc(node, head, theta, frost)
    integer, intent(in) :: node
    real(8), intent(in) :: head, theta, frost
    if (node < 1 .or. head > huge(head) .or. theta < -huge(theta) .or. frost < 0.0d0) error stop 'invalid hconduc'
    hconduc = 1.0d0
  end function hconduc
end module MOD_MvG

module MOD_frost
  use MOD_grid, only: numnod
  implicit none
  real(8) :: rfcp(numnod) = 1.0d0
end module MOD_frost

module MOD_top
  implicit none
contains
  subroutine boundtop(task)
    integer, intent(in) :: task
    if (task < 0) error stop 'invalid task'
  end subroutine boundtop
end module MOD_top

module MOD_gwl
  implicit none
contains
  subroutine calcgwl()
  end subroutine calcgwl
end module MOD_gwl

module MOD_swap_mp
  use MOD_grid, only: numnod
  implicit none
  real(8) :: frarmtrx(numnod) = 1.0d0
end module MOD_swap_mp

module variables
  use MOD_grid, only: numnod
  implicit none
  integer :: swkmean = 1, nhead = 2, swbotb = 7
  real(8), allocatable :: htb(:), gwltab(:)
  real(8) :: gwli = -2.0d0, t1900 = 1000.0d0, dt = 0.25d0
  real(8) :: h(numnod) = -1.0d0, pond = 0.0d0, volact = 0.0d0
  real(8) :: gwl = -2.0d0, theta(numnod) = 0.3d0, dimoca(numnod) = 0.0d0
  real(8) :: k(numnod) = 1.0d0, kmean(numnod+1) = 1.0d0
  real(8) :: ithetabeg(numnod) = 0.3d0
  real(8) :: volini = 0.0d0, pondini = 0.0d0, ivolbeg = 0.0d0, ipondbeg = 0.0d0
  real(8) :: hm1(numnod) = -1.0d0, thetm1(numnod) = 0.3d0
  real(8) :: gwlm1 = -2.0d0, pondm1 = 0.0d0
end module variables

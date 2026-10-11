module MOD_grid
  implicit none
  integer :: numnod = 0
end module MOD_grid

module variables
  use, intrinsic :: iso_fortran_env, only: real64
  implicit none
  integer, parameter :: max_nodes = 16
  real(real64) :: h(max_nodes) = 0.0_real64
  real(real64) :: theta(max_nodes) = 0.0_real64
  real(real64) :: hm1(max_nodes) = 0.0_real64
  real(real64) :: thetm1(max_nodes) = 0.0_real64
  real(real64) :: pond = 0.0_real64
  real(real64) :: pondm1 = 0.0_real64
  real(real64) :: gwl = 0.0_real64
  real(real64) :: gwlm1 = 0.0_real64
  real(real64) :: volact = 0.0_real64
  real(real64) :: ldwet = 0.0_real64
  real(real64) :: spev = 0.0_real64
  real(real64) :: saev = 0.0_real64
end module variables

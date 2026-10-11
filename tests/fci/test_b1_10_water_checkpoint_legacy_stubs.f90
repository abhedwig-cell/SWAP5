module MOD_grid
  implicit none
  integer :: numnod = 0
end module MOD_grid

module variables
  implicit none
  integer, parameter :: macp = 16
  real(8) :: h(macp)=0.0d0, theta(macp)=0.0d0, hm1(macp)=0.0d0, thetm1(macp)=0.0d0
  real(8) :: pond=0.0d0, pondm1=0.0d0, gwl=0.0d0, gwlm1=0.0d0
  real(8) :: volact=0.0d0, ldwet=0.0d0, spev=0.0d0, saev=0.0d0
end module variables

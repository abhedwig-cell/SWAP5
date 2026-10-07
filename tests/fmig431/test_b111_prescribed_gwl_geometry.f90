program test_b111_prescribed_gwl_geometry
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_b111_prescribed_gwl_geometry
  implicit none
  real(real64) :: z(8)
  type(b111_prescribed_gwl_geometry_t) :: r
  integer :: i

  do i=1,8
    z(i)=5.0_real64-10.0_real64*i
  end do

  call classify_b111_prescribed_gwl_geometry(z,-100.0_real64,1.0e-10_real64,r)
  if(.not.r%valid.or.r%status/=B111_GWL_GEOM_BELOW_PROFILE.or.r%unsaturated_nodes/=8.or..not.r%below_profile) error stop 1

  call classify_b111_prescribed_gwl_geometry(z,-42.0_real64,1.0e-10_real64,r)
  if(.not.r%valid.or.r%status/=B111_GWL_GEOM_IN_PROFILE.or.r%unsaturated_nodes/=4.or.r%below_profile) error stop 2

  call classify_b111_prescribed_gwl_geometry(z,-35.0_real64+5.0e-5_real64,1.0e-3_real64,r)
  if(.not.r%valid.or.r%status/=B111_GWL_GEOM_IN_PROFILE.or..not.r%snapped_to_node) error stop 3
  if(abs(r%effective_gwl_cm+35.0_real64)>1.0e-12_real64) error stop 4
  if(r%unsaturated_nodes/=2) error stop 5

  call classify_b111_prescribed_gwl_geometry(z,-4.99995_real64,1.0e-10_real64,r)
  if(.not.r%valid.or.r%status/=B111_GWL_GEOM_HIGH) error stop 6

  print '(a)','LOWGWL01_B111_GEOMETRY=PASS'
end program

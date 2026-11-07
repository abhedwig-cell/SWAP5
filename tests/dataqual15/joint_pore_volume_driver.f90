program joint_pore_volume_driver
  use iso_fortran_env, only: real64
  use mod_b111_profile_groundwater_projection
  implicit none
  real(real64), parameter :: z(5)=[-.5d0,-1.5d0,-2.5d0,-3.5d0,-4.5d0]
  real(real64), parameter :: dz(5)=1d0, dist(5)=1d0, sat(5)=.5d0, pond=.001d0, critical=.1d0
  real(real64) :: head(5),theta(5),single,expected
  type(b111_profile_groundwater_projection_t) :: old,new
  head=[.1d0,-1d-11,.2d0,.3d0,.4d0]
  theta=sat
  call evaluate_b111_profile_groundwater_projection(z,dist,head,pond,old)
  call evaluate_b111_pore_volume_connectivity(z,dist,dz,head,theta,sat,pond,critical,new)
  if(.not.new%valid.or..not.new%level_present.or.new%level_cm/=pond.or.old%level_cm>=0d0)error stop 1
  theta(2)=.45d0
  call evaluate_b111_pore_volume_connectivity(z,dist,dz,head,theta,sat,pond,critical,new)
  expected=pond+((sat(2)-theta(2))/critical)*(old%level_cm-pond)
  if(.not.new%valid.or.abs(new%level_cm-expected)>32*epsilon(1d0))error stop 2
  single=new%level_cm
  head(4)=-1d-11
  call evaluate_b111_pore_volume_connectivity(z,dist,dz,head,theta,sat,pond,critical,new)
  if(.not.new%valid.or.new%level_cm/=single)error stop 3
  theta(4)=.42d0
  call evaluate_b111_pore_volume_connectivity(z,dist,dz,head,theta,sat,pond,critical,new)
  if(.not.new%valid.or.new%level_cm>=single.or.new%level_cm<z(5))error stop 4
  theta(4)=.35d0
  call evaluate_b111_profile_groundwater_projection(z,dist,head,pond,old)
  call evaluate_b111_pore_volume_connectivity(z,dist,dz,head,theta,sat,pond,critical,new)
  if(.not.new%valid.or.new%level_cm/=old%level_cm)error stop 5
  head(1)=-1d0
  call evaluate_b111_profile_groundwater_projection(z,dist,head,pond,old)
  call evaluate_b111_pore_volume_connectivity(z,dist,dz,head,theta,sat,pond,critical,new)
  if(.not.new%valid.or.new%level_cm/=old%level_cm)error stop 6
  head(5)=-1d0
  call evaluate_b111_pore_volume_connectivity(z,dist,dz,head,theta,sat,pond,critical,new)
  if(.not.new%valid.or.new%level_present)error stop 7
  print '(a)','REAL_PORE_VOLUME_CONNECTIVITY_PASS'
end program


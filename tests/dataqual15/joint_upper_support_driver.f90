program joint_upper_support_driver
  use iso_fortran_env, only: real64
  use mod_b111_profile_groundwater_projection
  implicit none
  real(real64), parameter :: z(5)=[-.5d0,-1.5d0,-2.5d0,-3.5d0,-4.5d0]
  real(real64), parameter :: dz(5)=1d0, dist(5)=1d0, sat(5)=.5d0, pond=.001d0, critical=.1d0
  real(real64) :: head(5),theta(5),limit,connected,signed,expected,weight
  type(b111_profile_groundwater_projection_t) :: p
  head=[0d0,-.05d0,-.1d0,.3d0,.4d0]
  theta=[.5d0,.49d0,.47d0,.5d0,.5d0]
  call evaluate_b111_pore_volume_connectivity(z,dist,dz,head,theta,sat,pond,critical,p)
  if(.not.p%valid.or..not.p%level_present)error stop 1
  limit=p%level_cm
  head(1)=1d-12
  call evaluate_b111_pore_volume_connectivity(z,dist,dz,head,theta,sat,pond,critical,p)
  if(p%level_cm<limit.or.p%level_cm-limit>1d-9)error stop 2
  head(1)=.05d0
  call evaluate_b111_profile_groundwater_projection(z,dist,head,pond,p)
  signed=p%level_cm
  connected=pond+((sat(3)-theta(3))/critical)*(signed-pond)+ &
    ((sat(2)-theta(2))/critical)*(z(3)-pond)
  weight=head(1)/(head(1)-head(2))
  expected=signed+weight*(connected-signed)
  call evaluate_b111_pore_volume_connectivity(z,dist,dz,head,theta,sat,pond,critical,p)
  if(.not.p%valid.or.abs(p%level_cm-expected)>32*epsilon(1d0))error stop 3
  theta(3)=.35d0
  call evaluate_b111_pore_volume_connectivity(z,dist,dz,head,theta,sat,pond,critical,p)
  if(p%level_cm/=signed)error stop 4
  print '(a)','REAL_UPPER_SUPPORT_CONNECTIVITY_PASS'
end program


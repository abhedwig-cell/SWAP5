program test_profile
 use iso_fortran_env,only:real64
 use ieee_arithmetic,only:ieee_value,ieee_quiet_nan,ieee_positive_inf
 use mod_soil_n_profile_temperature
 implicit none
 real(real64)::dz(4),t(4),depth,got,selected,want,used
 integer::i,j,code
 dz=[5d0,5d0,10d0,10d0];t=[3d0,9d0,21d0,51d0]
 do i=1,9
  select case(i)
  case(1);depth=.3d0
  case(2);depth=.2d0
  case(3);depth=.1d0
  case(4);depth=.05d0+epsilon(1d0)
  case(5);depth=.3d0-epsilon(1d0)
  case(6);depth=.3d0+epsilon(1d0)
  case(7);depth=.2d0;dz=[5d0,30d0,5d0,5d0]
  case(8);depth=100d0;dz=[5d0,5d0,10d0,10d0];t=-20d0
  case(9);depth=100d0;t=60d0
  end select
  call soil_n_profile_temperature(dz,t,depth,got,selected,code)
  call require(code==N_PROFILE_OK,'valid profile')
  call literal_profile(dz,t,depth,want,used)
  call require(got==want.and.selected==used,'literal original loop equality')
  if(i==1)call require(got==13.5d0.and.selected==.2d0,'exact boundary excludes last layer')
  if(i==7)call require(abs(got-25d0)<1d-13.and.abs(selected-.15d0)<1d-15,'skip thick then include later thin')
 end do
 do j=1,12
  dz=[5d0,5d0,10d0,10d0];t=20d0;depth=.3d0
  select case(j)
  case(1);depth=.05d0
  case(2);depth=0d0
  case(3);depth=-1d0
  case(4);depth=ieee_value(0d0,ieee_quiet_nan)
  case(5);depth=ieee_value(0d0,ieee_positive_inf)
  case(6);dz(1)=0d0
  case(7);dz(1)=-1d0
  case(8);dz(4)=ieee_value(0d0,ieee_quiet_nan)
  case(9);t(4)=ieee_value(0d0,ieee_quiet_nan)
  case(10);t(4)=ieee_value(0d0,ieee_positive_inf)
  case(11);t(1)=1001d0
  case(12);dz(1)=1d7
  end select
  call soil_n_profile_temperature(dz,t,depth,got,selected,code)
  call require(code/=N_PROFILE_OK.and.got==0d0,'invalid or empty fail closed')
 end do
 call soil_n_profile_temperature(dz(:0),t(:0),.3d0,got,selected,code)
 call require(code/=0,'empty arrays')
 call soil_n_profile_temperature(dz,t(:3),.3d0,got,selected,code)
 call require(code/=0,'different lengths')
 print '(A)','NUT_THERMAL_LITERAL_PROFILE=PASS'
contains
 subroutine require(ok,label)
  logical,intent(in)::ok
  character(*),intent(in)::label
  if(.not.ok)then;print *,'FAIL ',label;error stop 1;end if
 end subroutine
 include 'literal_profile.inc'
end program

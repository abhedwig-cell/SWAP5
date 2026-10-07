program test_b111_linear_table_provider
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_b111_linear_table_provider
  implicit none
  type(b111_linear_table_parameters_t), target :: p
  type(b111_linear_table_provider_t) :: provider
  real(real64) :: cofgen(42,1)
  real(real64) :: wci(501,1), wcs(501,1), capi(501,1), caps(501,1), coni(501,1), cons(501,1)
  real(real64) :: h(1), theta(1), conductivity(1), capacity(1), dkdh(1)
  integer :: status, j

  cofgen = 0.0_real64
  cofgen(1,1)=0.05_real64
  cofgen(2,1)=0.45_real64
  cofgen(3,1)=10.0_real64
  cofgen(26,1)=0.449_real64
  cofgen(27,1)=0.1_real64
  do j=1,501
    wci(j,1)=0.4_real64
    wcs(j,1)=-1.0e-5_real64
    capi(j,1)=0.02_real64
    caps(j,1)=1.0e-6_real64
    coni(j,1)=1.0_real64
    cons(j,1)=-1.0e-5_real64
  end do

  call initialize_b111_linear_table_parameters(p,cofgen,wci,wcs,capi,caps,coni,cons,status)
  if(status/=B111_LINEAR_TABLE_OK) error stop 1
  call bind_b111_linear_table_provider(provider,p,0.5_real64,status)
  if(status/=B111_LINEAR_TABLE_OK) error stop 2

  h=0.0_real64
  call provider%evaluate(h,theta,conductivity,capacity,dkdh)
  if(abs(theta(1)-0.45_real64)>1.0e-14_real64 .or. abs(conductivity(1)-10.0_real64)>1.0e-14_real64) error stop 3

  h=-0.005_real64
  call provider%evaluate(h,theta,conductivity,capacity,dkdh)
  if(abs(theta(1)-0.4495_real64)>1.0e-14_real64) error stop 4

  h=-0.5_real64
  call provider%evaluate(h,theta,conductivity,capacity,dkdh)
  if(abs(theta(1)-(0.4_real64-1.0e-5_real64*0.5_real64))>1.0e-14_real64) error stop 5

  h=-1.0e15_real64
  call provider%evaluate(h,theta,conductivity,capacity,dkdh)
  if(conductivity(1)/=1.0e-10_real64) error stop 6

  print '(a)', 'B111_LINEAR_TABLE_PASS'
end program test_b111_linear_table_provider

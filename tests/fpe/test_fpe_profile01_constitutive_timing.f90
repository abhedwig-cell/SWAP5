program test_fpe_profile01_constitutive_timing
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  implicit none

  type(b110_default_mvg_parameters_t), target :: parameters
  type(b110_default_mvg_provider_t) :: provider
  character(len=64) :: arg
  integer :: n, calls, i, j, warmups
  integer(int64) :: c0, c1, rate
  real(real64), allocatable :: cofgen(:,:), h(:), theta(:), k(:), c(:), dkdh(:)
  real(real64) :: seconds, ns_per_call, checksum

  call get_command_argument(1, arg); read(arg,*) n
  call get_command_argument(2, arg); read(arg,*) calls
  if (n <= 0 .or. calls <= 0) error stop 'PROFILE01 constitutive invalid arguments'

  allocate(cofgen(24,n), h(n), theta(n), k(n), c(n), dkdh(n))
  cofgen = 0.0_real64
  do i=1,n
    cofgen(1,i)=0.032_real64
    cofgen(2,i)=0.423_real64
    cofgen(3,i)=4.75_real64
    cofgen(4,i)=0.0135_real64
    cofgen(5,i)=0.365_real64
    cofgen(6,i)=1.455_real64
    cofgen(7,i)=1.0_real64-1.0_real64/cofgen(6,i)
    cofgen(8,i)=cofgen(4,i)
    cofgen(9,i)=0.0_real64
    cofgen(10,i)=cofgen(3,i)
    cofgen(11,i)=0.999_real64
    cofgen(12,i)=0.99_real64*cofgen(3,i)
    cofgen(22,i)=-1.0e6_real64
    cofgen(23,i)=1.0e-12_real64
    h(i)=-20.0_real64-2.5_real64*real(i-1,real64)
  end do

  call initialize_b110_default_mvg_parameters(parameters, cofgen)
  call bind_b110_default_mvg_provider(provider, parameters, 0.25_real64)

  warmups=min(1000,max(100,calls/100))
  do j=1,warmups
    call provider%evaluate(h,theta,k,c,dkdh)
  end do

  call system_clock(c0,rate)
  do j=1,calls
    call provider%evaluate(h,theta,k,c,dkdh)
  end do
  call system_clock(c1)

  seconds=real(c1-c0,real64)/real(rate,real64)
  ns_per_call=1.0e9_real64*seconds/real(calls,real64)
  checksum=sum(theta)+sum(k)+sum(c)+sum(dkdh)
  write(*,'(A,I0,A,I0,A,ES24.16,A,ES24.16,A,ES24.16)') &
       'PROFILE01_CONSTITUTIVE_TIMING,nodes=',n,',calls=',calls,',seconds=',seconds, &
       ',ns_per_call=',ns_per_call,',checksum=',checksum
end program test_fpe_profile01_constitutive_timing

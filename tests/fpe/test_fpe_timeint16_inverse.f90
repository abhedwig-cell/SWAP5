program test_fpe_timeint16_inverse
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  implicit none
  type(b110_default_mvg_parameters_t),target :: hp
  type(b110_default_mvg_provider_t) :: p
  real(real64) :: cof(24,1),h(1),th(1),kk(1),cp(1),dk(1),hinv,err,maxerr,theta0,max_theta_err
  real(real64) :: tr,ts,alpha,nvg,lambda,mm
  integer :: j
  character(len=32)::mid
  call get_command_argument(1,mid)
  call read_real(2,tr); call read_real(3,ts); call read_real(4,alpha); call read_real(5,nvg); call read_real(6,lambda)
  mm=1.0_real64-1.0_real64/nvg
  cof=0.0_real64
  cof(1,1)=tr; cof(2,1)=ts; cof(3,1)=1.0_real64; cof(4,1)=alpha; cof(5,1)=lambda; cof(6,1)=nvg; cof(7,1)=mm
  cof(8,1)=alpha; cof(9,1)=0.0_real64; cof(10,1)=1.0_real64; cof(11,1)=0.999_real64; cof(12,1)=0.99_real64
  cof(22,1)=-1.0e6_real64; cof(23,1)=1.0e-12_real64
  call initialize_b110_default_mvg_parameters(hp,cof)
  call bind_b110_default_mvg_provider(p,hp,1.0_real64)
  maxerr=0.0_real64; max_theta_err=0.0_real64
  do j=0,500
    h(1)=-0.001_real64 * 10.0_real64**(6.0_real64*real(j,real64)/500.0_real64)
    call p%evaluate(h,th,kk,cp,dk)
    theta0=th(1)
    hinv=invert_theta(hp%cofgen(:,1),theta0)
    err=abs(hinv-h(1))
    maxerr=max(maxerr,err)
    h(1)=hinv
    call p%evaluate(h,th,kk,cp,dk)
    max_theta_err=max(max_theta_err,abs(th(1)-theta0))
  end do
  write(*,'(*(g0))') 'F_PE_TIMEINT16_INVERSE_RESULT|MATERIAL=',trim(mid),'|MAX_HEAD_ERR=',maxerr, &
       '|MAX_THETA_ERR=',max_theta_err
  if(max_theta_err>1.0e-12_real64) error stop 'inverse theta roundtrip error'
  write(*,'(A)') 'F_PE_TIMEINT16_INVERSE=PASS'
contains
  subroutine read_real(i,x)
    integer,intent(in)::i; real(real64),intent(out)::x; character(len=64)::s
    call get_command_argument(i,s); read(s,*)x
  end subroutine
  pure real(real64) function invert_theta(c,theta) result(head)
    real(real64),intent(in)::c(:),theta
    real(real64)::se,x
    if(theta>=c(2))then
      head=0.0_real64
    else if(theta>c(26))then
      head=-1.0e-2_real64+(theta-c(26))/c(27)
    else
      se=max(1.0e-15_real64,min(1.0_real64,(theta-c(1))/c(25)))
      x=(se**(-1.0_real64/c(7))-1.0_real64)**(1.0_real64/c(6))
      head=-x/c(4)
    end if
  end function
end program

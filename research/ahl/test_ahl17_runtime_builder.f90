program test_ahl17_runtime_builder
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_ahl17_runtime_builder, only: ahl17_table_t, build_ahl17_table, validate_ahl17_table
  implicit none

  character(len=3),parameter :: ids(4)=['B01','B12','O05','O14']
  real(real64),parameter :: pars(6,4)=reshape([ &
    0.02_real64,0.427494_real64,0.021659_real64,1.734737_real64,31.225016_real64,0.98087_real64, &
    0.01_real64,0.529749_real64,0.016562_real64,1.090671_real64,2.245895_real64,-4.493581_real64, &
    0.01_real64,0.336701_real64,0.030304_real64,2.887502_real64,17.418504_real64,0.0736_real64, &
    0.01_real64,0.393878_real64,0.003288_real64,1.616573_real64,2.495984_real64,0.514012_real64], [6,4])
  integer,parameter :: expected_n(4)=[121,79,122,108]
  integer,parameter :: NBUILD=100
  type(b110_default_mvg_parameters_t),target :: hp
  type(b110_default_mvg_provider_t) :: provider
  type(ahl17_table_t) :: table
  real(real64)::cof(24,1),mt,mc,mk,t0,t1,elapsed
  logical::ok
  integer::j,r

  do j=1,4
    call configure(pars(:,j),cof)
    call initialize_b110_default_mvg_parameters(hp,cof)
    call bind_b110_default_mvg_provider(provider,hp,0.25_real64)

    call build_ahl17_table(provider,pars(1,j),pars(2,j),table,ok)
    call require(ok,'builder completes '//ids(j))
    call require(table%n>=expected_n(j) .and. table%n<=2*expected_n(j), &
         'support count remains bounded near selected Python builder '//ids(j))
    call validate_ahl17_table(provider,pars(1,j),pars(2,j),table,mt,mc,mk,ok)
    call require(ok,'dense validation evaluates '//ids(j))
    call require(mt<=1.0e-5_real64,'dense theta envelope '//ids(j))
    call require(mc<=1.0e-2_real64,'dense capacity envelope '//ids(j))
    write(*,'(A,1X,A,1X,A,I0,1X,A,ES14.6,1X,A,ES14.6,1X,A,ES14.6)') &
      'AHL17_BUILD',ids(j),'POINTS=',table%n,'THETA=',mt,'LOGC=',mc,'LOGK=',mk

    call cpu_time(t0)
    do r=1,NBUILD
      call build_ahl17_table(provider,pars(1,j),pars(2,j),table,ok)
      if(.not.ok)error stop 'repeated build failed'
    end do
    call cpu_time(t1)
    elapsed=(t1-t0)/real(NBUILD,real64)
    write(*,'(A,1X,A,1X,A,ES16.8)') 'AHL17_BUILD_TIME',ids(j),'SECONDS=',elapsed
  end do
  write(*,'(A)') 'AHL17_SELF_BUILD=PASS'

contains
  subroutine configure(p,c)
    real(real64),intent(in)::p(6)
    real(real64),intent(out)::c(24,1)
    real(real64)::tr,ts,a,n,ks,lam
    tr=p(1);ts=p(2);a=p(3);n=p(4);ks=p(5);lam=p(6)
    c=0.0_real64
    c(1,1)=tr;c(2,1)=ts;c(3,1)=ks;c(4,1)=a;c(5,1)=lam;c(6,1)=n
    c(7,1)=1.0_real64-1.0_real64/n;c(8,1)=a
    c(9,1)=0.0_real64;c(10,1)=ks;c(11,1)=0.999_real64;c(12,1)=0.99_real64*ks
    c(22,1)=-1.0e6_real64;c(23,1)=1.0e-12_real64
  end subroutine configure
  subroutine require(cond,msg)
    logical,intent(in)::cond
    character(len=*),intent(in)::msg
    if(.not.cond)then
      write(*,'(A,1X,A)')'AHL17_FAIL',trim(msg)
      error stop 1
    end if
  end subroutine require
end program test_ahl17_runtime_builder

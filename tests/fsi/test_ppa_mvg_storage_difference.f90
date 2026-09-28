program test_ppa_mvg_storage_difference
  use, intrinsic :: iso_fortran_env, only: real64,real128
  use, intrinsic :: ieee_arithmetic, only: ieee_value,ieee_quiet_nan
  use mod_ppa_mvg_storage_difference
  use mod_ppa_mvg_storage_binding
  use mod_b110_default_mvg_provider
  implicit none
  real(real64) :: h,hnew,dtheta,back,expected,naive,alpha,n,m,amplitude
  real(real128) :: qbefore,qafter,qa,qn,qm,qr
  real(real64), parameter :: heads(4)=[-1.0_real64,-75.0_real64,-500.0_real64,-2000.0_real64]
  integer :: i,j,signum,cases,improved,ulp_cases
  logical :: ok
  alpha=.0135_real64; n=1.455_real64; m=1-1/n; amplitude=.423_real64-.032_real64
  qa=real(alpha,real128); qn=real(n,real128); qm=real(m,real128); qr=real(amplitude,real128)
  cases=0; improved=0
  do i=1,size(heads)
    h=heads(i)
    do j=4,13
      do signum=-1,1,2
        hnew=h*(1+real(signum,real64)*10.0_real64**(-j))
        call local_mvg_storage_difference(amplitude,alpha,n,m,h,hnew,dtheta,ok)
        call require(ok,'local difference available')
        qbefore=qr/(1+abs(qa*real(h,real128))**qn)**qm
        qafter=qr/(1+abs(qa*real(hnew,real128))**qn)**qm
        expected=real(qafter-qbefore,real64)
        call require(abs(dtheta-expected)<=2.0e-13_real64*abs(expected),'independent quad precision oracle')
        call local_mvg_storage_difference(amplitude,alpha,n,m,hnew,h,back,ok)
        call require(ok,'reverse available')
        call require(abs(dtheta+back)<=2.0e-13_real64*abs(expected),'antisymmetry')
        naive=(.032_real64+amplitude/(1+abs(alpha*hnew)**n)**m) &
             -(.032_real64+amplitude/(1+abs(alpha*h)**n)**m)
        if(abs(naive-expected)>100*max(abs(dtheta-expected),tiny(dtheta))) improved=improved+1
        cases=cases+1
      end do
    end do
    call local_mvg_storage_difference(amplitude,alpha,n,m,h,h,dtheta,ok)
    call require(ok.and.dtheta==0,'identity')
  end do
  call require(improved>0,'demonstrated cancellation improvement')
  ! Resolve storage changes at adjacent representable heads independently of
  ! the Richards iteration. This does not qualify solver convergence.
  ulp_cases=0
  do i=1,size(heads)
    h=heads(i)
    do signum=-1,1,2
      hnew=h
      do j=1,16
        hnew=nearest(hnew,real(signum,real64))
        call local_mvg_storage_difference(amplitude,alpha,n,m,h,hnew,dtheta,ok)
        call require(ok,'ulp difference available')
        qbefore=qr/(1+abs(qa*real(h,real128))**qn)**qm
        qafter=qr/(1+abs(qa*real(hnew,real128))**qn)**qm
        expected=real(qafter-qbefore,real64)
        call require(abs(dtheta-expected)<=2.0e-13_real64*abs(expected),'ulp quad oracle')
        call require(dtheta*real(signum,real64)>0,'ulp storage direction')
        call local_mvg_storage_difference(amplitude,alpha,n,m,hnew,h,back,ok)
        call require(ok,'ulp reverse available')
        call require(abs(dtheta+back)<=2.0e-13_real64*abs(expected),'ulp antisymmetry')
        ulp_cases=ulp_cases+1
      end do
    end do
  end do
  call local_mvg_storage_difference(amplitude,alpha,n,m,-75.0_real64,-70.0_real64,dtheta,ok)
  call require(.not.ok.and.dtheta==0,'nonlocal difference rejected')
  call local_mvg_storage_difference(amplitude,alpha,n,m,-.02_real64,0.0_real64,dtheta,ok)
  call require(.not.ok,'branch crossing rejected')
  call local_mvg_storage_difference(amplitude,alpha,n,m,ieee_value(h,ieee_quiet_nan),h,dtheta,ok)
  call require(.not.ok,'nonfinite rejected')
  call check_binding()
  write(*,'(a,i0)') 'MVG_STORAGE_CASES=',cases
  write(*,'(a,i0)') 'MVG_STORAGE_IMPROVED=',improved
  write(*,'(a,i0)') 'MVG_STORAGE_ULP_CASES=',ulp_cases
  write(*,'(a)') 'MVG_STORAGE_QUAD_ORACLE=PASS'
contains
  subroutine check_binding()
    type(b110_default_mvg_parameters_t),target::hp
    type(b110_default_mvg_provider_t)::provider,unbound
    real(real64)::raw(24,2),before(2),after(2),water(2),k(2),c(2),dk(2),diff(2),expected
    logical::available
    integer::i
    raw=0
    do i=1,2
      raw(1,i)=.032_real64; raw(2,i)=.423_real64; raw(3,i)=4.75_real64
      raw(4,i)=.0135_real64; raw(5,i)=.365_real64; raw(6,i)=1.455_real64
      raw(7,i)=1-1/raw(6,i); raw(8,i)=raw(4,i); raw(10,i)=raw(3,i)
      raw(11,i)=.999_real64; raw(12,i)=.99_real64*raw(3,i)
      raw(22,i)=-1.0e6_real64; raw(23,i)=1.0e-12_real64
    end do
    call initialize_b110_default_mvg_parameters(hp,raw)
    call bind_b110_default_mvg_provider(provider,hp,0.01_real64)
    before=[-75.0_real64,-500.0_real64]
    after=before+1.0e-8_real64
    call provider%evaluate(before,water,k,c,dk)
    call evaluate_bound_mvg_storage_difference(provider,before,water,after,diff,available)
    call require(available,'provider-bound difference available')
    do i=1,2
      call local_mvg_storage_difference(hp%cofgen(25,i),raw(4,i),raw(6,i),raw(7,i), &
           before(i),after(i),expected,available)
      call require(available.and.diff(i)==expected,'binding preserves local oracle')
    end do
    water(2)=nearest(water(2),1.0_real64)
    call evaluate_bound_mvg_storage_difference(provider,before,water,after,diff,available)
    call require(.not.available.and.all(diff==0),'one-ulp base mismatch rejects atomically')
    call provider%evaluate(before,water,k,c,dk)
    hp%cofgen(9,2)=-1.0_real64
    call evaluate_bound_mvg_storage_difference(provider,before,water,after,diff,available)
    call require(.not.available.and.all(diff==0),'unsupported second-node branch rejects atomically')
    hp%cofgen(9,2)=0
    hp%ksatexm_extension_enabled=.true.
    call evaluate_bound_mvg_storage_difference(provider,before,water,after,diff,available)
    call require(.not.available,'extension rejected')
    call evaluate_bound_mvg_storage_difference(unbound,before,water,after,diff,available)
    call require(.not.available,'unbound provider rejected')
    write(*,'(a)') 'MVG_STORAGE_PROVIDER_BINDING=PASS'
  end subroutine

  subroutine require(condition,message)
    logical,intent(in)::condition
    character(len=*),intent(in)::message
    if(.not.condition) then
      print *,message
      error stop 1
    end if
  end subroutine
end program

program test_fit
  use, intrinsic :: iso_fortran_env,only:real64,int64
  use, intrinsic :: ieee_arithmetic,only:ieee_value,ieee_quiet_nan
  use mod_macropore_dynamic_shrinkage
  implicit none
  type(clay_kim_shrinkage_t)::clay,a_clay
  type(peat_shrinkage_t)::peat,a_peat
  real(real64)::shrink,before,after,mr,void,alpha,beta,nan,p,expected,c1,c2,c3,f
  logical::ok
  integer::i,j
  real(real64),parameter::sat_theta=0.5_real64,transition=0.3_real64
  nan=ieee_value(0.0_real64,ieee_quiet_nan)
  call prepare_clay_kim_option2(sat_theta,0.2_real64,transition,clay,ok)
  call check(ok,'clay points prepare')
  call check(abs(clay%beta_k+3.3333333333333333333_real64)<1.0e-14_real64,'clay analytic beta')
  call check(abs(clay%gamma_k+0.812187885639363490_real64)<1.0e-14_real64,'clay analytic gamma')
  mr=transition
  f=clay%alpha_k*(1.0_real64+mr*clay%beta_k)*exp(-mr*clay%beta_k)
  call check(abs(f)<1.0e-15_real64,'clay independent source fit residual')
  call evaluate_clay_kim_shrinkage_fraction(mr*0.5_real64,sat_theta,clay,shrink,ok)
  call check(ok .and. abs(shrink-0.35_real64)<1.0e-14_real64,'clay transition touches normal line')
  call evaluate_clay_kim_shrinkage_fraction((mr-1.0e-8_real64)*0.5_real64,sat_theta,clay,before,ok)
  call check(ok,'clay left transition')
  call evaluate_clay_kim_shrinkage_fraction((mr+1.0e-8_real64)*0.5_real64,sat_theta,clay,after,ok)
  call check(ok .and. abs(before-after)<2.0e-8_real64,'clay transition continuity')
  ! Legacy allows A=v, but initializes beta=0 and divides by zero derivative.
  call prepare_clay_kim_option2(sat_theta,transition,transition,a_clay,ok)
  call check(ok .and. a_clay%valid(),'clay A=v boundary valid analytically')
  call prepare_clay_kim_option2(sat_theta,0.4_real64,transition,a_clay,ok)
  call check(.not.ok,'clay A>v rejects')
  call prepare_clay_kim_option2(sat_theta,0.0_real64,0.0_real64,a_clay,ok)
  call check(.not.ok,'zero clay point rejects')
  call prepare_clay_kim_option2(sat_theta,nan,transition,a_clay,ok)
  call check(.not.ok,'NaN clay point rejects')
  do j=1,2
    p=0.1_real64;expected=1.251916853523901960917963_real64
    if(j==2)then
      p=-0.3_real64;expected=0.790602559512859127838620_real64
    end if
    call prepare_peat_characteristic_points(0.5_real64,0.2_real64,0.6_real64,0.1_real64,0.3_real64,p,peat,ok)
    call check(ok,'peat points prepare')
    call check(abs(peat%alpha-expected)<2.0e-12_real64,'70-digit independent peat alpha')
    call check(abs(peat%beta-2.0_real64*expected)<4.0e-12_real64,'independent peat beta')
    alpha=peat%alpha;beta=peat%beta;c1=2.0_real64;c2=1.0_real64/3.0_real64
    c3=(0.3_real64/0.28_real64-1.0_real64)/p
    if(j==2)c3=(0.2_real64/0.28_real64-1.0_real64)/p
    ! Direct source residual, independent of the scaled production residual.
    f=c2**alpha*(exp(-alpha*c2)-exp(-alpha*c1))/(exp(-alpha)-exp(-alpha*c1))-c3
    call check(abs(f)<2.0e-12_real64,'independent peat source residual')
    call evaluate_peat_shrinkage_fraction(0.05_real64,0.5_real64,peat,SHRINK_PEAT_DIRECT,shrink,ok)
    void=(0.5_real64-shrink)/0.5_real64
    call check(ok,'peat target evaluates')
    if(j==1)call check(abs(void-0.3_real64)<1.0e-12_real64,'positive P target')
    if(j==2)call check(abs(void-0.2_real64)<1.0e-12_real64,'negative P target')
    do i=0,1000
      call evaluate_peat_shrinkage_fraction(0.5_real64*i/1000,0.5_real64,peat,SHRINK_PEAT_DIRECT,shrink,ok)
      call check(ok,'prepared peat whole moisture domain physical')
    end do
    a_peat=peat
    call prepare_peat_characteristic_points(0.5_real64,0.2_real64,0.6_real64,0.1_real64,0.3_real64,p,peat,ok)
    call check(ok .and. transfer(a_peat%alpha,0_int64)==transfer(peat%alpha,0_int64),'configuration preparation deterministic')
  end do
  call prepare_peat_characteristic_points(0.5_real64,0.2_real64,0.6_real64,0.1_real64,0.1_real64,0.1_real64,peat,ok)
  call check(.not.ok,'nonidentifiable typical=peak')
  call prepare_peat_characteristic_points(0.5_real64,0.2_real64,0.6_real64,0.4_real64,0.3_real64,0.1_real64,peat,ok)
  call check(.not.ok,'potentially ambiguous typical>peak')
  call prepare_peat_characteristic_points(0.5_real64,0.2_real64,0.6_real64,0.1_real64,0.3_real64,0.0_real64,peat,ok)
  call check(.not.ok,'P=0 nonidentifiable')
  call prepare_peat_characteristic_points(0.5_real64,0.2_real64,0.6_real64,0.1_real64,0.3_real64,0.01_real64,peat,ok)
  call check(.not.ok,'out-of-bracket root rejected')
  call prepare_peat_characteristic_points(0.5_real64,0.2_real64,0.6_real64,nan,0.3_real64,0.1_real64,peat,ok)
  call check(.not.ok,'NaN peat point')
  call prepare_peat_characteristic_points(0.5_real64,0.2_real64,0.6_real64,0.3_real64-1.0e-12_real64, &
       0.3_real64,0.1_real64,peat,ok)
  call check(.not.ok,'nearly flat fit rejected as numerically unidentifiable')
  print '(a)','PPA_WU05_MIGMAC04_INDEPENDENT_FIT_ORACLES=PASS'
contains
  subroutine check(condition,label)
    logical,intent(in)::condition
    character(*),intent(in)::label
    if(.not.condition)then
      print '(a)',label
      error stop 1
    end if
  end subroutine
end program

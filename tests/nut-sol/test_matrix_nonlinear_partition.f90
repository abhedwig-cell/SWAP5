program test_matrix_nonlinear_partition
  use iso_fortran_env,only:real64
  use ieee_arithmetic,only:ieee_value,ieee_quiet_nan
  use mod_b111_solute_sorption
  use matrix_nonlinear_oracle
  use b111_historical_inverse,only:historical_inverse
  implicit none
  type(b111_sorption_result_t)::s,t
  real(real64),parameter::exponents(6)=[0.5_real64,0.8_real64,1.0_real64,1.0005_real64,1.5_real64,2.0_real64]
  real(real64)::theta,rho,kf,cref,n,m,c,analytic,b,y,legacy,legacy_residual,err,maxerr
  integer::i,j,k,iterations,status,count
  count=0;maxerr=0.0_real64;rho=1.3_real64;kf=0.2_real64
  do j=1,size(exponents)
    n=exponents(j)
    do k=1,3
      cref=0.0037_real64*10.0_real64**(2*(k-1))
      theta=0.03_real64*k
      do i=0,400
        m=10.0_real64**(-6.0_real64+8.0_real64*i/400)
        c=nonlinear_inverse(theta,rho,kf,cref,n,m)
        call b111_sorption_partition_total(theta,rho,kf,cref,n,m,0.2_real64,s)
        call require(s%status==B111_SORP_OK,'actual production partition')
        call require(s%concentration>=0.0_real64.and.s%dissolved_density>=0.0_real64.and. &
             s%sorbed_density>=0.0_real64,'nonnegative physical amounts')
        err=abs(s%concentration-c)/max(c,1.0e-30_real64);maxerr=max(maxerr,err)
        call require(abs(s%total_density-m)<=32*epsilon(m)*max(1.0_real64,m),'roundoff mass')
        call require(err<1.0e-7_real64,'independent concentration inverse')
        b=rho*kf*cref**(1.0_real64-n)
        if(j==1)then
          y=2*m/(b+sqrt(b*b+4*theta*m));analytic=y*y
          call require(abs(c-analytic)<64*epsilon(c)*max(c,analytic),'quadratic sqrt oracle')
        else if(j==6)then
          analytic=2*m/(theta+sqrt(theta*theta+4*b*m))
          call require(abs(c-analytic)<64*epsilon(c)*max(c,analytic),'quadratic square oracle')
        end if
        ! Forward mapping and cm->mm, mg/cm3->mg/L diagnostic conversion.
        call b111_sorption_storage_from_concentration(theta,rho,kf,cref,n,c,t)
        call require(abs(t%total_density-m)<64*epsilon(m)*max(1.0_real64,m),'forward storage units')
        call require(abs((theta*10)*(c*1000)*0.0001_real64-theta*c)<32*epsilon(c)*max(1.0_real64,c), &
             'water mm and concentration mg/L give mg/cm2 for one cm soil')
        count=count+1
      end do
    end do
  end do
  ! Explicit historical expected differences, not relaxed transport tolerances.
  do j=1,2
    n=2.0_real64
    if(j==2)n=1.0005_real64
    call historical_inverse(0.2_real64,0.1_real64,1.0_real64,n,0.7_real64,2.0_real64,legacy,iterations,status)
    call require(status==0,'literal fixed-point converges for discriminating fixture')
    call b111_sorption_storage_from_concentration(0.2_real64,0.1_real64,1.0_real64,1.0_real64,n,legacy,t)
    legacy_residual=t%total_density-0.7_real64
    call require(abs(legacy_residual)>1.0e-6_real64,'literal historical inverse violates hard mass closure')
    call b111_sorption_partition_total(0.2_real64,0.1_real64,1.0_real64,1.0_real64,n,0.7_real64,2.0_real64,s)
    call require(s%status==0.and.abs(s%total_density-0.7_real64)<1.0e-14_real64,'corrected inverse closes same fixture')
    print '(A,F8.4,A,ES24.16,A,I0)','EXPECTED_HISTORICAL_DIFFERENCE n=',n,' residual=',legacy_residual,' iterations=',iterations
  end do
  call b111_sorption_partition_total(0.3_real64,rho,0.0_real64,0.37_real64,0.5_real64,0.6_real64,0.0_real64,s)
  call require(s%status==0.and.abs(s%concentration-2.0_real64)<1.0e-13_real64,'zero sorption limit')
  call b111_sorption_partition_total(0.3_real64,rho,kf,0.37_real64,2.0_real64,0.0_real64,0.0_real64,s)
  call require(s%status==0.and.abs(s%total_density)<=0.0_real64,'zero mass limit')
  call b111_sorption_partition_total(0.3_real64,rho,kf,0.0_real64,2.0_real64,0.6_real64,0.0_real64,s)
  call require(s%status==B111_SORP_INVALID,'invalid reference concentration')
  call b111_sorption_partition_total(0.3_real64,rho,kf,0.37_real64,-1.0_real64,0.6_real64,0.0_real64,s)
  call require(s%status==B111_SORP_INVALID,'invalid exponent')
  call b111_sorption_partition_total(0.3_real64,rho,kf,0.37_real64,2.0_real64,-0.6_real64,0.0_real64,s)
  call require(s%status==B111_SORP_INVALID,'negative mass')
  call b111_sorption_partition_total(0.3_real64,rho,kf,0.37_real64, &
       ieee_value(0.0_real64,ieee_quiet_nan),0.6_real64,0.0_real64,s)
  call require(s%status==B111_SORP_INVALID,'NaN exponent')
  print '(A,I0)','MATRIX_NONLINEAR_INDEPENDENT_PARTITION_CASES=',count
  print '(A)','MATRIX_NONLINEAR_PARTITION_UNITS_LEGACY_DIFFERENCES=PASS'
contains
  subroutine require(ok,label)
    logical,intent(in)::ok
    character(*),intent(in)::label
    if(.not.ok)then
      print *,'FAIL ',label;error stop 1
    end if
  end subroutine
end program

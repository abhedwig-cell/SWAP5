program test_crop_b111_germination_source_oracle
  use iso_fortran_env, only: real64
  use mod_crop_b111_germination_sum_candidate
  implicit none
  real(real64) :: tav,b,m,opt,sub,old,actual,dvs,oracle,odvs
  logical :: germinated,og
  integer :: status,i,j,k,n
  n=0
  do i=0,30
    tav=-10.0_real64+real(i,real64)*1.5_real64
    do j=1,18
      sub=real(j-4,real64)*0.05_real64
      do k=0,7
        b=2.0_real64;m=20.0_real64;opt=25.0_real64
        old=real(k,real64)*4.0_real64
        call b111_germination_sum_candidate(tav,b,m,opt,sub,old,actual,germinated,dvs,status)
        if (status/=B111_SUM_OK) error stop 1
        ! Independent transcription of B1.11 MOD_cropdevelopment.f90
        ! germination(task=3), lines 755-777. Compare each branch
        ! without calling the production subroutine in the oracle.
        oracle=old
        if (tav>b) then
          if (tav<m) then
            if (sub<0.1_real64) then
              oracle=oracle+(tav-b)
            else
              oracle=oracle+(opt/sub)*(tav-b)
            end if
          else
            if (sub<0.1_real64) then
              oracle=oracle+(m-b)
            else
              oracle=oracle+(opt/sub)*(m-b)
            end if
          end if
        end if
        og=.true.
        if (oracle<opt) then
          odvs=-0.1_real64*max(1.0_real64-(oracle/opt),0.0_real64)
          og=.false.
        else
          odvs=0.0_real64
        end if
        if (transfer(actual,0_8)/=transfer(oracle,0_8)) error stop 2
        if (transfer(dvs,0_8)/=transfer(odvs,0_8)) error stop 3
        if (germinated.neqv.og) error stop 4
        n=n+1
      end do
    end do
  end do
  if (n/=4464) error stop 5
  print '(a,i0)','CROP_B111_GERMINATION_SOURCE_ORACLE=PASS cases=',n
end program

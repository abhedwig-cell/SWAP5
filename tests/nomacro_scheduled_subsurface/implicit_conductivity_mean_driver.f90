program real_original_conductivity_mean_derivative
  use, intrinsic::ieee_arithmetic,only:ieee_is_finite
  implicit none
  interface
    subroutine original_implicit_mean_derivative(kind,left,right,dl,dr,value)
      integer::kind
      real(8)::left,right,dl,dr,value
    end subroutine
  end interface
  real(8),external::hcomean
  real(8)::left,right,dl,dr,value,delta,low,high,finite_difference,scale,largest
  integer::kind,geometry,count,wrong_half
  left=.013d0;right=83.2d0;delta=left*1d-5;count=0;wrong_half=0;largest=0d0
  do kind=1,6
    do geometry=1,3
      dl=1d0;dr=1d0
      if(geometry==2)dr=5d0
      if(geometry==3)dl=5d0
      call original_implicit_mean_derivative(kind,left,right,dl,dr,value)
      low=hcomean(kind,left-delta,right,dl,dr,0,-100d0,0d0)
      high=hcomean(kind,left+delta,right,dl,dr,0,-100d0,0d0)
      finite_difference=(high-low)/(2d0*delta);scale=max(abs(value),abs(finite_difference),1d-8)
      if(.not.all(ieee_is_finite([value,low,high,finite_difference])))error stop 'Nonfinite original mean derivative'
      if(abs(value-finite_difference)>2d-6*scale)error stop 'Actual original dkmean differs from real hcomean derivative'
      largest=max(largest,abs(value-finite_difference)/scale)
      if(abs(value-.5d0)>2d-6*scale)wrong_half=wrong_half+1
      write(*,'(a,2(1x,i0),3(1x,es25.17e3))')'ACTUAL_ORIGINAL_DKMEAN',kind,geometry,value,finite_difference,value-.5d0
      count=count+1
    end do
  end do
  if(count/=18.or.wrong_half<10)error stop 'Original fixed-half boundary Jacobian discrepancy not exposed'
  write(*,'(a,2(1x,i0),1x,es25.17e3)')'REAL_ORIGINAL_MEAN_DERIVATIVE_PASS',count,wrong_half,largest
end program

program original_implicit_conductivity_contract
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use MOD_grid, only: numnod,numlay,layer
  use MOD_swap_base, only: swfrost
  use variables, only: indeks
  use MOD_MvG, only: swsophy,cofgen,iHWCKmodel,sw_use_elas,fl_use_tables,fl_use_kh_power, &
                     set_cofgen_pointers,calc_cofgen_extra,watcon,moiscap,hconduc,dhconduc
  implicit none
  real(8),parameter::heads(6)=[-1d0,-3d0,-10d0,-30d0,-100d0,-300d0]
  real(8)::h,theta,capacity,derivative,delta,left,right,approximation,scale,maximum
  integer::curve,i,count
  ! Real public original module input, with the explicitly unsupported
  ! examined-Ksat interpolation inactive. No conductivity formula is copied.
  numnod=1;numlay=1;layer(1)=1;swfrost=0
  swsophy=0;iHWCKmodel=1;sw_use_elas=0;fl_use_tables=.false.;fl_use_kh_power=.false.
  cofgen=0d0
  cofgen(1:12,1)=[0.02d0,0.43d0,83.2d0,0.02d0,0.5d0,1.5d0, &
                 0.33333333333333337d0,0.04d0,0d0,-999d0,0d0,0d0]
  call set_cofgen_pointers
  count=0;maximum=0d0
  do curve=-1,1,2
    indeks(1)=curve
    call calc_cofgen_extra(1)
    do i=1,size(heads)
      h=heads(i);theta=watcon(1,h);capacity=moiscap(1,h)
      derivative=dhconduc(1,h,theta,capacity,1d0)
      delta=max(1d-6,abs(h)*1d-5)
      left=hconduc(1,h-delta,watcon(1,h-delta),1d0)
      right=hconduc(1,h+delta,watcon(1,h+delta),1d0)
      approximation=(right-left)/(2d0*delta)
      if(.not.all(ieee_is_finite([theta,capacity,derivative,left,right,approximation]))) &
        error stop 'Nonfinite actual original conductivity derivative'
      if(min(theta,capacity,derivative,left,right)<0d0)error stop 'Negative actual original derivative domain'
      scale=max(abs(derivative),abs(approximation),1d-8)
      maximum=max(maximum,abs(derivative-approximation)/scale)
      write(*,'(a,2(1x,i0),4(1x,es25.17e3))')'ACTUAL_ORIGINAL_DKDH',curve,i,h,derivative,approximation,scale
      if(abs(derivative-approximation)>2d-6*scale) &
        error stop 'Actual original derivative differs from actual original conductivity finite difference'
      count=count+1
    end do
  end do
  if(count/=12)error stop 'Original derivative cases omitted'
  write(*,'(a,1x,i0,1x,es25.17e3)')'REAL_ORIGINAL_IMPLICIT_CONDUCTIVITY_DERIVATIVE_PASS',count,maximum
end program

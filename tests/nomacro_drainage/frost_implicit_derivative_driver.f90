program actual_original_frost_constitutive_derivative
  use,intrinsic::ieee_arithmetic,only:ieee_is_finite
  use MOD_grid,only:numnod,numlay,layer
  use MOD_swap_base,only:swfrost,swmacro
  use variables,only:indeks
  use MOD_MvG,only:swsophy,cofgen,iHWCKmodel,sw_use_elas,fl_use_tables,fl_use_kh_power, &
      set_cofgen_pointers,calc_cofgen_extra,watcon,moiscap,hconduc,dhconduc
  implicit none
  real(8),parameter::heads(6)=[-1d0,-3d0,-10d0,-30d0,-100d0,-300d0]
  real(8),parameter::reductions(4)=[0d0,0.01d0,0.5d0,1d0]
  real(8)::h,theta,capacity,derivative,delta,left,right,approximation,scale,maximum,r
  integer::curve,i,j,count
  numnod=1;numlay=1;layer(1)=1;swfrost=1;swmacro=0
  swsophy=0;iHWCKmodel=1;sw_use_elas=0;fl_use_tables=.false.;fl_use_kh_power=.false.
  cofgen=0d0
  cofgen(1:12,1)=[0.02d0,0.43d0,83.2d0,0.02d0,0.5d0,1.5d0, &
      0.33333333333333337d0,0.04d0,0d0,-999d0,0d0,0d0]
  call set_cofgen_pointers
  count=0;maximum=0d0
  do curve=-1,1,2
    indeks(1)=curve
    call calc_cofgen_extra(1)
    do j=1,size(reductions)
      r=reductions(j)
      do i=1,size(heads)
        h=heads(i);theta=watcon(1,h);capacity=moiscap(1,h)
        derivative=dhconduc(1,h,theta,capacity,r)
        delta=max(1d-6,abs(h)*1d-5)
        left=hconduc(1,h-delta,watcon(1,h-delta),r)
        right=hconduc(1,h+delta,watcon(1,h+delta),r)
        approximation=(right-left)/(2d0*delta)
        if(.not.all(ieee_is_finite([theta,capacity,derivative,left,right,approximation]))) &
          error stop 'Nonfinite actual Frost conductivity derivative'
        if(min(theta,capacity,derivative,left,right)<0d0)error stop 'Negative actual Frost constitutive value'
        scale=max(abs(derivative),abs(approximation),1d-8)
        maximum=max(maximum,abs(derivative-approximation)/scale)
        if(abs(derivative-approximation)>2d-6*scale)error stop 'Actual Frost derivative disagrees with actual conductivity'
        if(r==0d0.and.(derivative/=0d0.or.approximation/=0d0))error stop 'Fully reduced actual conductivity has nonzero derivative'
        count=count+1
        write(*,'(a,3(1x,i0),6(1x,es25.17e3))')'ACTUAL_ORIGINAL_FROST_DKDH', &
          count,curve,i,r,h,derivative,approximation,left,right
      end do
    end do
  end do
  if(count/=48)error stop 'Actual Frost constitutive denominator changed'
  write(*,'(a,1x,i0,1x,es25.17e3)')'ACTUAL_FROST_CONSTITUTIVE_48_DERIVATIVES_PASS_NOT_BOUNDARY_JACOBIAN_QUALIFIED',count,maximum
end program

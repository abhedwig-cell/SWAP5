program test_pond_water_temporal_difference
 use iso_fortran_env,only:real64
 use ieee_arithmetic,only:ieee_value,ieee_quiet_nan,ieee_positive_inf
 use mod_pond_water_temporal_difference
 implicit none
 real(real64)::hf(2),hh(2),wf(2),wh(2),pf,ph,gf,gh,value,nan,inf
 logical::ok
 integer::i
 nan=ieee_value(0d0,ieee_quiet_nan);inf=ieee_value(0d0,ieee_positive_inf)
 do i=1,23
  hf=[-2d0,-3d0];hh=hf;wf=.3d0;wh=wf;pf=.5d0;ph=pf;gf=-5d0;gh=gf
  select case(i)
  case(2)
   hh(2)=hh(2)+.125d0
  case(3)
   ph=ph+.125d0
  case(4)
   gh=gh+.125d0
  case(5)
   hf(1)=nan
  case(6)
   hh(1)=inf
  case(7)
   wf(1)=nan
  case(8)
   wh(1)=inf
  case(9)
   pf=nan
  case(10)
   ph=inf
  case(11)
   gf=nan
  case(12)
   gh=inf
  case(13)
   hf(1)=1.01d6
  case(14)
   hh(1)=-1.01d6
  case(15)
   pf=-1d0
  case(16)
   ph=1.01d6
  case(17)
   gf=1.01d6
  case(18)
   gh=-1.01d6
  case(19)
   wf(1)=-.1d0
  case(20)
   wh(1)=1.1d0
  end select
  select case(i)
  case(21)
   call evaluate_pond_water_temporal_difference(hf(:0),hh(:0),wf(:0),wh(:0),pf,ph,gf,gh,value,ok)
  case(22)
   call evaluate_pond_water_temporal_difference(hf,hh(:1),wf,wh,pf,ph,gf,gh,value,ok)
  case(23)
   call evaluate_pond_water_temporal_difference(hf,hh,wf(:1),wh,pf,ph,gf,gh,value,ok)
  case default
   call evaluate_pond_water_temporal_difference(hf,hh,wf,wh,pf,ph,gf,gh,value,ok)
  end select
  if(i==1)then
   if(.not.ok.or.value/=0d0)error stop 'identity'
  else if(i<=4)then
   if(.not.ok.or.value/=.125d0)error stop 'actual head/pond/GWL difference'
  else
   if(ok.or.value/=huge(0d0))error stop 'invalid comparison must fail closed'
  end if
 end do
 print '(A)','POND_WATER_TEMPORAL_23_COMPARISONS=PASS'
end program

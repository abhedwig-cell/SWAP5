program test_water_flux_temporal_policy
  use iso_fortran_env,only:real64
  use ieee_arithmetic,only:ieee_value,ieee_quiet_nan,ieee_positive_inf
  use mod_pond_water_temporal_difference
  implicit none
  type(water_flux_temporal_policy_t)::p
  real(real64)::dz(2),hf(2),hh(2),wf(2),wh(2),u(3),o(3),pf,ph,gf,gh,dt,v,expected,nan,inf
  logical::ok,ua(3)
  integer::i
  nan=ieee_value(0d0,ieee_quiet_nan);inf=ieee_value(0d0,ieee_positive_inf)
  do i=1,33
    p=water_flux_temporal_policy_t();p%enabled=.true.
    dz=[10d0,20d0];hf=-2d0;hh=hf;wf=.3d0;wh=wf
    pf=0d0;ph=pf;gf=-5d0;gh=gf;dt=.5d0;u=[.2d0,.1d0,.1d0];o=u;ua=.true.;expected=0d0
    select case(i)
    case(2) ! Redistribution cancels in total storage, but not L1.
      wh=wf+[1d-4,-1d-4];expected=sum(abs(wf-wh)*dz)/.001d0
    case(3) ! Saturated pressure difference alone consumes no water budget.
      hh=20d0
    case(4)
      ph=.0005d0;expected=.5d0
    case(5)
      gh=gf+.0005d0;expected=abs(gf-gh)/.001d0
    case(6)
      u(1)=u(1)+.00025d0;expected=abs(u(1)-u(2)-u(3))/dt/.001d0
    case(7)
      o(1)=o(1)+.00025d0;expected=abs(o(1)-o(2)-o(3))/dt/.001d0
    case(8) ! Independent rate budget; no dimensional state/dt conversion.
      wh=wf+1d-5;p%uptake_rate_budget_cm_day=.0001d0;dt=.01d0
      u(1)=u(1)+.0000005d0
      expected=max(sum(abs(wf-wh)*dz)/.001d0,abs(u(1)-u(2)-u(3))/dt/.0001d0)
    case(9)
      p%enabled=.false.
    case(10)
      p%state_budget_cm=0d0
    case(11)
      p%groundwater_budget_cm=nan
    case(12)
      p%uptake_rate_budget_cm_day=inf
    case(13)
      p%output_rate_budget_cm_day=.002d0
    case(14)
      ua(2)=.false.
    case(15)
      u(1)=nan
    case(16)
      o(3)=inf
    case(17)
      dt=0d0
    case(18)
      dt=-1d0
    case(19)
      dt=nan
    case(20)
      dt=tiny(1d0)
    case(21)
      dz(1)=0d0
    case(22)
      dz(2)=-1d0
    case(23)
      dz(1)=nan
    case(24)
      wh(1)=1.1d0
    case(25)
      wh(1)=nan
    case(26)
      hh(1)=inf
    case(27)
      ph=-.1d0
    case(28)
      gf=inf
    case(29)
      u(1)=-1d0
    case(30)
      o(2)=huge(1d0)
    case(31)
      p%state_budget_cm=tiny(1d0)
    case(32)
      dz(1)=huge(1d0)
    case(33)
      dt=huge(1d0)
    end select
    call evaluate_water_flux_temporal_difference(p,dz,hf,hh,wf,wh,pf,ph,gf,gh,ua,u,o,dt,v,ok)
    if(i<=8)then
      if(.not.ok.or.abs(v-expected)>1d-12)error stop 'water/flux oracle mismatch'
    else
      if(ok)error stop 'invalid metric accepted'
    end if
  end do
  p=water_flux_temporal_policy_t();p%enabled=.true.
  call evaluate_water_flux_temporal_difference(p,[10d0],hf,hh,wf,wh,pf,ph,gf,gh,ua,u,o,.5d0,v,ok)
  if(ok)error stop 'shape mismatch accepted'
  print '(A)','WATER_FLUX_TEMPORAL_34_CONTRACTS_PASS'
end program

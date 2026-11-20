program actual_frozenbounds_divdra_rates
  use MOD_arrays,only:macp
  use MOD_frost,only:FrozenCond,FrozenBounds,rfcp,tfroststa,tfrostend,nodfrostbot,zfrosttop,zfrostbot
#ifdef GUARDED
  use MOD_frost,only:frost_geometry_valid,frost_geometry_status
#endif
  use MOD_swap_base,only:swfrost,swmacro,swdra
  use MOD_grid,only:numnod,z,disnod,dz,layer,zbotcp
  use MOD_drain,only:nrlevs,swdivd,swdivdinf,swdislay,swnrsrf,swtopnrsrf,swtopdislay, &
      cofani,facdpthinf,Lspacing,zbotdr,drainl,qdra,qdrain,qdrtot,divdra,dramet
  use variables,only:theta,thetas,fluseksatexm,ksatexm,ksatfit,qbot,qbot_nonfrozen,gwl
  use,intrinsic::ieee_arithmetic,only:ieee_is_finite
  implicit none
  real(8)::temperature(macp),conductivity(macp),toptemp
  integer::profile,wet,mode,levels,infiltration,cases,j

  numnod=4;swfrost=1;swmacro=0;swdra=1;swdivd=1
  tfroststa=0d0;tfrostend=-1d0;toptemp=2d0
  z(1:4)=[-5d0,-20d0,-50d0,-100d0]
  dz(1:4)=[10d0,20d0,40d0,60d0]
  disnod(1:4)=[5d0,15d0,30d0,50d0]
  zbotcp(1:4)=[-10d0,-30d0,-70d0,-130d0]
  layer(1:4)=[1,1,2,2]
  thetas(1:4)=0.45d0;fluseksatexm(1:4)=.false.
  ksatfit(1:2)=[1d0,0.2d0];ksatexm(1:2)=ksatfit(1:2)
  conductivity=0d0;conductivity(1:4)=[1d0,1d0,0.2d0,0.2d0]
  cofani(1:2)=[1d0,2d0];gwl=-10d0
  swdislay=0;swnrsrf=0;swtopnrsrf=0;swtopdislay=0
  facdpthinf=0.5d0;dramet=1
  Lspacing(1:2)=[1000d0,2000d0]
  zbotdr(1:2)=[-80d0,-110d0]
  cases=0
  do levels=1,2
    nrlevs=levels
    do profile=1,3
      temperature=2d0
      if(profile==2)temperature(1:4)=[1d0,-2d0,-1d0,2d0]
      if(profile==3)temperature(1:4)=[-0.5d0,-0.25d0,1d0,2d0]
      do wet=0,1
        theta(1:4)=0.45d0
        if(wet==1)theta(1:4)=0.35d0
        do infiltration=0,1
          swdivdinf=infiltration
          do mode=-1,2
            if(mode==2.and.levels==1)cycle
            qdra=0d0;qdrain=0d0
            qdrain(1)=0.03d0*mode
            if(levels==2)qdrain(2)=0.07d0*mode
            qbot_nonfrozen=0.05d0*mode
            if(mode==2)then
              qdrain(1:2)=[0.03d0,-0.03d0];qbot_nonfrozen=0.05d0
            end if
            drainl(1:2)=zbotdr(1:2)
            do j=1,levels
              if(qdrain(j)<0d0)drainl(j)=-5d0
            end do
            qdrtot=sum(qdrain(1:levels));qbot=0.123d0
            ! The actual production caller partitions unfrozen drainage first.
            call divdra(conductivity,gwl)
            call FrozenCond(temperature,toptemp)
#ifdef GUARDED
            if(.not.frost_geometry_valid.or.frost_geometry_status/=0)error stop 'Unexpected invalid original bounded Frost geometry'
#endif
            call FrozenBounds()
            if(.not.all(ieee_is_finite([rfcp(1:4),zfrosttop,zfrostbot,qbot,qdrtot,qdrain(1:levels)]))) &
              error stop 'Nonfinite actual FrozenBounds output'
            if(.not.all(ieee_is_finite(qdra(1:levels,1:4))))error stop 'Nonfinite actual Divdra nodal output'
            if(any(rfcp(1:4)<0d0).or.any(rfcp(1:4)>1d0))error stop 'Invalid actual Frost reduction'
            if(abs(qdrtot-sum(qdrain(1:levels)))>1d-10)error stop 'Actual level total rate differs'
            do j=1,levels
              if(abs(qdrain(j)-sum(qdra(j,1:4)))>1d-10)error stop 'Actual nodal level drainage rate differs'
            end do
            if(mode==0.and.(qbot/=0d0.or.qdrtot/=0d0.or.any(qdra(1:levels,1:4)/=0d0))) &
              error stop 'Zero-rate actual production state changed'
            cases=cases+1
            write(*,'(a,6(1x,i0),*(1x,es25.17e3))')'ACTUAL_FROZENBOUNDS_DIVDRA_RATES', &
              cases,levels,profile,wet,infiltration,mode,rfcp(1:4),zfrosttop,zfrostbot,dble(nodfrostbot), &
              qbot,qdrtot,qdrain(1:levels),qdra(1:levels,1:4)
          end do
        end do
      end do
    end do
  end do
  if(cases/=84)error stop 'Actual Frost Divdra component denominator differs'
  write(*,'(a)')'ACTUAL_FROZENBOUNDS_DIVDRA_84_RATE_INTERFACE_CASES_PASS_NOT_CDE_QUALIFIED'
end program

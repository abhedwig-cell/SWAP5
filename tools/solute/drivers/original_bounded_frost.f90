program original_bounded_frost
use MOD_arrays,only:macp
use MOD_frost,only:FrozenCond,FrozenBounds,rfcp,tfroststa,tfrostend,nodfrostbot,zfrosttop,zfrostbot
#ifdef GUARDED
use MOD_frost,only:frost_geometry_valid,frost_geometry_status
#endif
use MOD_swap_base,only:swfrost,swmacro,swdra
use MOD_grid,only:numnod,z,disnod,dz,layer
use MOD_drain,only:nrlevs,swdivd,zbotdr,qdra,qdrain,qdrtot
use variables,only:theta,thetas,fluseksatexm,ksatexm,ksatfit,qbot,qbot_nonfrozen,gwl
use ieee_arithmetic,only:ieee_value,ieee_quiet_nan
implicit none
real(8)::temperature(macp),toptemp,air,signq
integer::profile,drainage,wet,sgn,cases
character(32)::mode
call get_command_argument(1,mode)
numnod=4;swfrost=1;swmacro=0;tfroststa=0d0;tfrostend=-1d0
z(1:4)=[-5d0,-20d0,-50d0,-100d0];disnod(1:4)=[5d0,15d0,30d0,50d0];dz(1:4)=[10d0,20d0,40d0,60d0];layer(1:4)=1
swdivd=0;nrlevs=1;zbotdr(1)=-80d0;thetas(1:4)=.45d0;fluseksatexm(1:4)=.false.;ksatfit(1)=1d0;ksatexm(1)=1d0;gwl=-10d0
toptemp=2d0;temperature=2d0;temperature(1:4)=[1d0,-2d0,-1d0,2d0]
if(trim(mode)/='valid')then
 if(trim(mode)=='uniform')temperature=-2d0
 if(trim(mode)=='epsilon')temperature(1:4)=[-.9999999d0,2d0,2d0,2d0]
 if(trim(mode)=='nan')temperature(2)=ieee_value(0d0,ieee_quiet_nan)
 if(trim(mode)=='limits')tfroststa=tfrostend
 if(trim(mode)=='grid')z(2)=z(1)
 swdra=1;theta(1:4)=.4d0;qbot_nonfrozen=.05d0;qbot=.123d0;qdra(1,1:4)=[.1d0,.2d0,.3d0,.4d0];qdrain(1)=sum(qdra(1,1:4));qdrtot=qdrain(1)
 call FrozenCond(temperature,toptemp)
#ifdef GUARDED
 print *,'GEOMETRY_STATUS',frost_geometry_valid,frost_geometry_status
#endif
 if(trim(mode)=='drain-index')zbotdr(1)=0d0
 call FrozenBounds()
 print *,'UNEXPECTED_INVALID_PHYSICAL_PUBLICATION',qbot,qdrtot
 stop
end if
cases=0
do profile=1,3
 temperature=2d0
 if(profile==2)temperature(1:4)=[1d0,-2d0,-1d0,2d0]
 if(profile==3)temperature(1:4)=[-.5d0,-.25d0,1d0,2d0]
 do drainage=0,1
  swdra=drainage
  do wet=0,1
   air=.1d0*wet;theta(1:4)=thetas(1:4)-air
   do sgn=-1,1,2
    signq=.05d0*sgn;qbot_nonfrozen=signq;qbot=.123d0;qdra(1,1:4)=[.1d0,.2d0,.3d0,.4d0];qdrain(1)=sum(qdra(1,1:4));qdrtot=qdrain(1)
    call FrozenCond(temperature,toptemp)
#ifdef GUARDED
    if(.not.frost_geometry_valid)error stop 'Unexpected invalid bounded geometry'
#endif
    if(any(rfcp(1:4)<0d0).or.any(rfcp(1:4)>1d0))error stop 'Invalid original frost factors'
    call FrozenBounds()
    if(profile==2.and.wet==0.and.drainage==0.and.qbot/=0d0)error stop 'Original frozen low-air bottom not blocked'
#ifdef GUARDED
    if(swdra==1.and.(qdrain(1)/=sum(qdra(1,1:4)).or.qdrtot/=qdrain(1)))error stop 'Original frost nodal reporting inconsistent'
#endif
    cases=cases+1
    write(*,'(a,i0,12(1x,es25.17e3))')'PHYSICAL ',cases,rfcp(1:4),zfrosttop,zfrostbot,dble(nodfrostbot),qbot,qdra(1,1:4)
    write(*,'(a,i0,2(1x,es25.17e3))')'REPORT ',cases,qdrain(1),qdrtot
   end do
  end do
 end do
end do
if(cases/=24)error stop 'Missing actual original component case'
print *,'ACTUAL_ORIGINAL_FROST_CASES',cases
end program

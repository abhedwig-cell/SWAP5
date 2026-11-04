program matched_micro_driver
 use MOD_grid,only:dz,layer,nod1lay
 use variables,only:ksatfit
 use mod_RWU_micro,only:RWU_micro,UpwPot,M_table,K_table,PP,PL,swDoSatRel,swHydrLift,swO2ECT,swTypeTred, &
  RootRadius,Kroot,Lstem_A0,Lstem_A1,PLhalf,CampA,Tol_2,myTolX,TolConv,factor,Ntrial,iMicro
 use original_micro_attribution,only:original_attribute
 implicit none
 real(8)::x(40,34),tab(6),head(34),density(34),stress(34),upw(34),alpha,tact,tact1,tact2
 real(8)::dry,oxy,salt,drought,stored_m(430,34),stored_k(430,34),dryk(34),satk(34)
 integer::i,j,n,io
 logical::check(3)
 do i=1,34
  read(*,*,iostat=io)x(:,i)
  if(io/=0.or.nint(x(10,i))/=i)error stop 'actual frame node sequence'
  dz(i)=x(34,i);head(i)=x(32,i);density(i)=x(35,i);stress(i)=x(38,i)
  layer(i)=i;nod1lay(i)=i
 end do
 n=nint(x(11,1));if(n<1.or.n>34)error stop 'rooted nodes'
 do i=1,34
  do j=0,430
   read(*,*,iostat=io)tab
   if(io/=0.or.nint(tab(3))/=i.or.nint(tab(4))/=j)error stop 'actual table sequence'
   if(j==0)then
    dryk(i)=tab(5);satk(i)=tab(6)
   else
    stored_m(j,i)=tab(5);stored_k(j,i)=tab(6)
   end if
  end do
 end do
 ! Independent literal attribution on identical actual accepted scalars.
 call original_attribute(n,dz(:n),density(:n),x(36,:n),x(37,:n),x(3,1),x(7,1),nint(x(12,1)), &
  x(26,1),dry,oxy,salt,drought,previous=x(27,1))
 write(*,'(a,4(1x,es25.17e3))')'ATTR',dry,oxy,salt,drought
 if(maxval(abs([dry-x(4,1),oxy-x(5,1),salt-x(6,1),drought-x(28,1)]))>1d-14) &
  error stop 'unchanged literal attribution bound'
 RootRadius=x(16,1);Kroot=x(17,1);Lstem_A0=x(18,1);Lstem_A1=x(19,1)
 PLhalf=1d0/x(20,1);CampA=x(21,1);Tol_2=x(22,1);myTolX=x(23,1);TolConv=x(24,1)
 Ntrial=nint(x(25,1));factor=1.25d0;iMicro=1
 swDoSatRel=0;swHydrLift=0;swO2ECT=nint(x(13,1));swTypeTred=nint(x(14,1))
 allocate(UpwPot(34));ksatfit=satk
 call RWU_micro(1,1,n,dz(:n),head(:n),density(:n),stress(:n),.false.,x(3,1),tact,upw(:n),alpha,tact1,tact2,check)
 ! Init allocates/initializes private source state with the existing fixture.
 ! Replace EVERY consumed lookup entry before Rate; no fixture hydraulic
 ! value participates in the replay of the actual microscopic equations.
 M_table=0d0;K_table=0d0
 M_table(1:430,:)=stored_m;K_table(1:430,:)=stored_k;K_table(431,:)=dryk
 ksatfit=satk
 if(any(M_table(1:430,:)/=stored_m).or.any(K_table(1:430,:)/=stored_k))error stop 'lookup input binding'
 call RWU_micro(2,1,n,dz(:n),head(:n),density(:n),stress(:n),.false.,x(3,1),tact,upw(:n),alpha,tact1,tact2,check)
 write(*,'(a,3(1x,i0),5(1x,es25.17e3))')'CHECK',merge(1,0,check(1)),merge(1,0,check(2)), &
  merge(1,0,check(3)),tact,tact1,tact2,PP,PL
 do i=1,n
  write(*,'(a,1x,i0,3(1x,es25.17e3))')'NODE',i,upw(i),x(40,i),abs(upw(i)-x(40,i))
 end do
end program

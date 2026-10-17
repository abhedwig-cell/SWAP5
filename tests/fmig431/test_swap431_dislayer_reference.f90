program dislayer_reference
 use, intrinsic :: iso_fortran_env,only:real64,int32
 use MOD_grid,only:numnod,dz,zbotcp,layer
 use MOD_drain,only:DIVDRA,nrlevs,qdrain,qdra,cofani,Lspacing,swdivdinf,drainl,FacDpthInf, &
      swdislay,swtopdislay,ztopdislay,ftopdislay,dramet,zbotdr,shape,diffl
 implicit none
 real(real64),parameter::gwls(3)=[0.d0,-.85d0,-1.8d0]
 real(real64)::k(8),base(3,8),expected(3,8),out(3,8),gwl,tops(6),factors(6),rates(3,4),scales(5),depth,retained,part,err
 integer::grid,lev,pat,g,inf,mode,t,mag,i,j,node,u,cases,bad,zero_support,small_nonzero,normal
 integer(int32)::header(10)
 numnod=8;cases=0;bad=0;zero_support=0;small_nonzero=0;normal=0
 rates(:,1)=[.003d0,.002d0,.001d0];rates(:,2)=-rates(:,1)
 rates(:,3)=[.003d0,-.002d0,.001d0];rates(:,4)=[.003d0,-.003d0,0.d0]
 scales=[1.d0,1.d-5,1.d-6,2.d-7,0.d0];factors=[0.d0,.2d0,.5d0,.8d0,1.d0,1.d0]
 open(newunit=u,file='partition.bin',access='stream',form='unformatted',status='replace')
 do grid=1,3
  dz=1;cofani=1;k=1
  if(grid==2)then
   dz=[.25d0,.75d0,1.5d0,.5d0,2.d0,.25d0,1.25d0,1.5d0]
   k=[1.d0,4.d0,.2d0,2.d0,8.d0,.7d0,3.d0,1.3d0];cofani=[.4d0,3.d0]
  else if(grid==3)then
   k(2:8)=1.d-7
  end if
  depth=0
  do i=1,8
   depth=depth+dz(i);zbotcp(i)=-depth
  end do
  tops=[0.d0,-.15d0,zbotcp(1),-1.5d0,-depth,-depth+1.d-9]
  do lev=1,3
  nrlevs=lev;Lspacing=[40000.d0,12000.d0,4000.d0]
  do pat=1,4
  do g=1,3
   gwl=gwls(g)
   do inf=0,1
   do mode=0,3
   do t=1,6
   do mag=1,5
    qdrain=rates(:,pat)*scales(mag);swdivdinf=inf;drainl=min(0.d0,gwl+.6d0);FacDpthInf=.5d0
    swdislay=0;swtopdislay=0;qdra=0
    call DIVDRA(k,gwl)
    base=qdra
    if(any(abs(sum(base(:lev,:),dim=2)-qdrain(:lev))>1.d-14))error stop 'base source mass'
    swdislay=min(mode,2);swtopdislay=[1,0,1];ztopdislay=tops(t)
    if(mode>=2)then
     dramet=2
     if(mode==3)dramet=3
     ftopdislay=factors(t);zbotdr=[-3.d0,-4.d0,-5.d0];shape=1.3d0;diffl=[2.d0,3.d0,1.2d0]
     do i=1,lev
      if(swtopdislay(i)/=1)cycle
      if(dramet==2)then
       ztopdislay(i)=factors(t)*((gwl-zbotdr(i))/shape+zbotdr(i))+(1.d0-factors(t))*zbotdr(i)
      else
       ztopdislay(i)=factors(t)*gwl+(1.d0-factors(t))*(gwl-diffl(i))
      end if
     end do
    end if
    expected=base
    if(mode/=0)then
     do i=1,lev
      if(swtopdislay(i)/=1)cycle
      node=1
      do while(ztopdislay(i)<zbotcp(node))
       node=node+1
       if(node>8)error stop 'top outside profile'
      end do
      part=(ztopdislay(i)-zbotcp(node))/dz(node)
      expected(i,:node-1)=0;expected(i,node)=part*base(i,node)
      retained=sum(expected(i,:))
      if(retained/=0.d0)then
       expected(i,:)=expected(i,:)*(qdrain(i)/retained)
       if(abs(retained)<1.d-8)then
        small_nonzero=small_nonzero+1
       else
        normal=normal+1
       end if
      else
       expected(i,:)=0;expected(i,node)=qdrain(i);zero_support=zero_support+1
      end if
     end do
    end if
    qdra=0;call DIVDRA(k,gwl);out=qdra
    do i=1,lev
     err=maxval(abs(out(i,:)-expected(i,:)))
     if(err>1.d-14.or.abs(sum(out(i,:))-qdrain(i))>1.d-14)bad=bad+1
    end do
    header=[int(grid,int32),int(lev,int32),int(pat,int32),int(g,int32),int(inf,int32),int(mode,int32),int(t,int32),int(mag,int32),0_int32,0_int32]
    write(u)header,qdrain,ztopdislay,base,out,expected
    cases=cases+1
   end do
   end do
   end do
   end do
  end do
  end do
  end do
 end do
 close(u)
 print '(A,5I10)','DISLAYER_REFERENCE_COUNTS ',cases,bad,zero_support,small_nonzero,normal
 print '(A)','DISLAYER_COMPLETE_SOURCE_NATIVE_MATRIX=PASS'
end program

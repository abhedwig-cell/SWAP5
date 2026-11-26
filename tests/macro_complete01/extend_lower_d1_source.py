from pathlib import Path
p=Path('app/hybrid_water/macro_stock_rank2.f90');s=p.read_text()
def sub(a,b):
 global s
 assert s.count(a)==1,(a,s.count(a));s=s.replace(a,b)
s=s.replace('uu(macp,madm),vv(macp,madm)','uu(macp,madm+1),vv(macp,madm+1)')
sub('if(frIn1/=1d0.and.any(cm(16,2:NumDm)/=1d0))return\nif(cm(16,1)/=1d0)return','''meta(10)=cm(16,1)
if(cm(16,1)<0d0.or.cm(16,1)>1d0)return
if(frIn1/=1d0.and.cm(16,1)/=1d0)return''')
sub('contactD1(2),upperIn(macp),dUpperIn(macp),upperValid,frIn1,upperG0,upperG1,upperBase(macp),dUpperOut(macp),upperContact(macp)','contactD1(2),upperIn(macp),dUpperIn(macp),upperValid,frIn1,upperG0,upperG1,upperBase(macp),dUpperOut(macp),upperContact(macp),lowerPS(macp),lowerPU(macp),lowerDL(macp),lowerL,lowerO,lowerF')
sub('integer,save::proof_count=0,proof_unit,upper_count=0,upper_unit','integer,save::proof_count=0,proof_unit,upper_count=0,upper_unit,lower_count=0,lower_unit')
sub(''' call macro_contact_cell_gradient(1,cell,g0,g1,QOutMtxUnsDmCp(1,cell)*dt,du0,du1,nativeU(1),contact_valid)
 if(contact_valid/=1d0)return
 contactD1=[-du0/dt-nativeU(1),-du1/dt]
 vv(upper,NumDm)=contactD1(1);vv(lower,NumDm)=contactD1(2)
 uu(cell,NumDm)=1d0''',''' if(cm(16,1)>0d0)then
  call macro_contact_cell_gradient(1,cell,g0,g1,QOutMtxUnsDmCp(1,cell)*dt/cm(16,1),du0,du1,nativeU(1),contact_valid)
  if(contact_valid/=1d0)return
  contactD1=[-cm(16,1)*du0/dt-nativeU(1),-cm(16,1)*du1/dt]
 end if
 vv(upper,NumDm+1)=contactD1(1);vv(lower,NumDm+1)=contactD1(2)
 uu(cell,NumDm+1)=1d0''')
s=s.replace('vv(upper,NumDm)=vv(upper,NumDm)+ct0(d);vv(lower,NumDm)=vv(lower,NumDm)+ct1(d)','vv(upper,NumDm+1)=vv(upper,NumDm+1)+ct0(d);vv(lower,NumDm+1)=vv(lower,NumDm+1)+ct1(d)')
a=s.index('do k=1,NumDm-1');b=s.index('! D1 upper inventory projector',a);part=s[a:b]
part=part.replace('do k=1,NumDm-1\n d=k+1','do d=2,NumDm\n k=d').replace('pot(1:n,k)','pot(1:n,d-1)').replace('pu(1:n,k)','pu(1:n,d-1)').replace('pot(i,k)','pot(i,d-1)').replace('pu(cell,k)','pu(cell,d-1)').replace('pu(1:cell-1,k)','pu(1:cell-1,d-1)').replace('pu(cell+1:n,k)','pu(cell+1:n,d-1)')
part=part.replace('if(k<=2)meta(2+k)=fr','if(d<=3)meta(d+1)=fr').replace('if(k<=2)meta(4+k)=1d0','if(d<=3)meta(d+3)=1d0').replace('if(cm(4,d)==cm(1,d).and.k<=2)meta(6+k)=1d0','if(cm(4,d)==cm(1,d).and.d<=3)meta(d+5)=1d0')
s=s[:a]+part+s[b:]
s=s.replace('! This uses slot1 only when all D2..N out factors are1 (guard above).','! Slot1 belongs toD1; every other lower constraint has its domain slot.')
new='''! D1 lower inventory projection, including fixed rapid outflow in total O.
lowerF=cm(16,1)
if(frIn1==1d0.and.lowerF>0d0.and.lowerF<1d0)then
 lowerL=cm(2,1);lowerO=cm(6,1)
 if(lowerO<=0d0.or.cm(17,1)/dt<=1d-7.or.lowerO<=cm(17,1))return
 if(cm(11,1)/=0d0.or.any(QInIntSatDmCp(1,1:n)/=0d0))return
 if(abs(cm(5,1)-sum(cm(9:12,1)))>128d0*epsilon(1d0)*max(cm(5,1),tiny(1d0)))return
 if(abs(lowerO-sum(cm(13:15,1)))>128d0*epsilon(1d0)*max(lowerO,tiny(1d0)))return
 if(any(QOutMtxUnsDmCp(1,1:cell-1)/=0d0).or.any(QOutMtxUnsDmCp(1,cell+1:n)/=0d0))return
 if(thetas(cell)-theta(cell)>1d-6)return
 call macro_upper1_data(upperIn,upperValid)
 if(upperValid/=1d0)return
 if(abs(sum(upperIn(1:n))-cm(12,1))>128d0*epsilon(1d0)*max(cm(12,1),tiny(1d0)))return
 dUpperIn=0d0;dUpperOut=0d0;upperBase=0d0;lowerPS=0d0;lowerPU=0d0;lowerDL=0d0;upperContact=0d0
 lowerPS(1:n)=dt*QOutMtxSatDmCp(1,1:n)/lowerF
 lowerPU(1:n)=dt*QOutMtxUnsDmCp(1,1:n)/lowerF
 if(abs(sum(lowerPS(1:n))-cm(13,1))>256d0*epsilon(1d0)*max(cm(13,1),tiny(1d0)))return
 if(abs(sum(lowerPU(1:n))-cm(14,1))>256d0*epsilon(1d0)*max(cm(14,1),tiny(1d0)))return
 if(cm(10,1)>0d0)then
  call macro_top_lateral_gradient(dq,qp,latvalid)
  if(latvalid/=1d0.or.qp<=0d0)return
  dUpperIn(1)=cm(10,1)/qp*dq
 end if
 do i=lower,n
  hm=max(0d0,cm(24,1)-z(i))
  if(hm<1d-8)hm=0d0
  if(upperIn(i)>0d0)then
   delta=h(i)-hm
   if(delta<=0d0)return
   dUpperIn(i)=upperIn(i)/delta
   upperBase(i)=QInMtxSatDmCp(1,i)/delta
  end if
  if(lowerPS(i)>0d0)then
   delta=hm-h(i)
   if(delta<=1d-8)return
   dUpperOut(i)=-lowerPS(i)/delta
   upperBase(i)=upperBase(i)+QOutMtxSatDmCp(1,i)/delta
  end if
 end do
 if(h(cell)>=0d0)then
  dUpperIn(upper)=dUpperIn(upper)+upperIn(cell)/depth*g0
  dUpperIn(lower)=dUpperIn(lower)+upperIn(cell)/depth*g1
 end if
 if(h(cell)<0d0)then
  call macro_contact_cell_gradient(1,cell,g0,g1,lowerPU(cell),du0,du1,nativeU(1),contact_valid)
  if(contact_valid/=1d0)return
  dUpperOut(upper)=dUpperOut(upper)+du0;dUpperOut(lower)=dUpperOut(lower)+du1
  upperBase(cell)=upperBase(cell)+nativeU(1)
  upperContact(upper)=contactD1(1);upperContact(lower)=contactD1(2)
 end if
 if(lowerL==cm(4,1).and.cm(4,1)<=cm(1,1)+128d0*epsilon(1d0)*max(abs(cm(4,1)),abs(cm(1,1)),tiny(1d0)))then
  lowerDL(upper)=cm(18,1)*g0;lowerDL(lower)=cm(18,1)*g1
 else if(lowerL/=cm(1,1).and.lowerL>=min(cm(4,1),cm(1,1)))then
  return
 end if
 uu(1:n,1)=-(lowerPS(1:n)+lowerPU(1:n))/dt
 vv(1:n,1)=(dUpperIn(1:n)-lowerDL(1:n)-lowerF*dUpperOut(1:n))/lowerO
 meta(2)=meta(2)+1d0
 lower_count=lower_count+1
 if(lower_count<=64)then
  if(lower_count==1)open(newunit=lower_unit,file='macro_lower1_inventory_terms.txt',status='replace')
  write(lower_unit,*)n,t1900,dt,numbit,cell,upper,lower,lowerF,cm(5,1),lowerO,cm(1,1),lowerL,cm(4,1),cm(18,1),g0,g1,cm(15,1),depth
  write(lower_unit,*)upperIn(1:n),lowerPS(1:n)+lowerPU(1:n),upperBase(1:n),uu(1:n,1),vv(1:n,1),QInMtxSatDmCp(1,1:n),upperContact(1:n)
 end if
end if
'''
sub('meta(1)=1d0;eligible=.true.',new+'meta(1)=1d0;eligible=.true.')
s=s.replace('write(proof_unit,*)n,NumDm,t1900,dt,numbit','write(proof_unit,*)n,NumDm+1,t1900,dt,numbit')
s=s.replace('zz(n,madm),M(madm,madm),rhs(madm),lam(madm)','zz(n,madm+1),M(madm+1,madm+1),rhs(madm+1),lam(madm+1)')
s=s.replace('aug(madm,madm+1),row(madm+1)','aug(madm+1,madm+2),row(madm+2)')
s=s.replace('res=-1d0;nr=NumDm','res=-1d0;nr=NumDm+1')
p.write_text(s)

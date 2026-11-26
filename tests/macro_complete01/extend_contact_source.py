from pathlib import Path
p=Path('app/hybrid_water/macro_stock_rank2.f90');s=p.read_text()
def sub(a,b):
 global s
 assert s.count(a)==1,(a,s.count(a));s=s.replace(a,b)
sub('real(8)::cm(24,madm),pot(macp,madm)','real(8)::cm(24,madm),pot(macp,madm),pu(macp,madm)')
sub('proof_meta(6)','proof_meta(10),ct0(madm),ct1(madm),nativeU(madm),du0,du1,contact_valid,contactD1(2)')
sub('integer::d,k,i,cell,upper','integer::d,k,i,cell,upper,lower')
sub('call macro_saturated_data(cm,pot,valid)','call macro_saturated_data(cm,pot,pu,valid)')
sub('''if(h(upper)>=0d0.or.any(h(cell:n)<=0d0).or.any(theta(cell:n)/=thetas(cell:n)))return
den=h(cell)-h(upper)
g=z(cell)+h(cell)/den*(z(upper)-z(cell))''','''lower=cell
if(h(cell)<0d0)then
 upper=cell;lower=cell+1
end if
if(lower>n)return
if(h(upper)>=0d0.or.any(h(lower:n)<=0d0).or.any(theta(lower:n)/=thetas(lower:n)))return
den=h(lower)-h(upper)
g=z(lower)+h(lower)/den*(z(upper)-z(lower))''')
sub('g0=(z(upper)-z(cell))*h(cell)/den**2;g1=-(z(upper)-z(cell))*h(upper)/den**2','g0=(z(upper)-z(lower))*h(lower)/den**2;g1=-(z(upper)-z(lower))*h(upper)/den**2')
sub('if(any(QOutMtxUnsDmCp(1:NumDm,cell)/=0d0))return\n','')
sub('bl=cg*g0;bd=cg*g1','''bl=0d0;bd=0d0
if(h(cell)>=0d0)then
 bl=cg*g0;bd=cg*g1
end if''')
sub('! Two existing stock normalizations, with no duplicate internal inflow.','''ct0=0d0;ct1=0d0;nativeU=0d0;contactD1=0d0
! Complete current contact row, including unconstrained domains, exactly once.
if(h(cell)<0d0)then
 call macro_contact_cell_gradient(1,cell,g0,g1,QOutMtxUnsDmCp(1,cell)*dt,du0,du1,nativeU(1),contact_valid)
 if(contact_valid/=1d0)return
 contactD1=[-du0/dt-nativeU(1),-du1/dt]
 vv(upper,NumDm)=contactD1(1);vv(lower,NumDm)=contactD1(2)
 uu(cell,NumDm)=1d0
 do d=2,NumDm
  call macro_contact_cell_gradient(d,cell,g0,g1,pu(cell,d-1),du0,du1,nativeU(d),contact_valid)
  if(contact_valid/=1d0)return
  ct0(d)=-cm(16,d)*du0/dt-nativeU(d);ct1(d)=-cm(16,d)*du1/dt
  vv(upper,NumDm)=vv(upper,NumDm)+ct0(d);vv(lower,NumDm)=vv(lower,NumDm)+ct1(d)
 end do
end if
! One stock normalization per bounded domain, with no duplicate contact derivative.''')
sub('if(cm(6,d)<=0d0.or.any(cm(14:15,d)/=0d0))return','''if(cm(6,d)<=0d0.or.cm(15,d)/=0d0)return
 if(any(pu(1:cell-1,k)/=0d0).or.any(pu(cell+1:n,k)/=0d0))return''')
sub('abs(sum(pot(1:n,k))-cm(6,d))','abs(sum(pot(1:n,k))+sum(pu(1:n,k))-cm(6,d))')
sub('do i=cell,n\n  if(QIn','do i=lower,n\n  if(QIn')
sub('dI(cell)=dI(cell)+dt*QInMtxSatDmCp(d,cell)/depth*g1','dI(lower)=dI(lower)+dt*QInMtxSatDmCp(d,cell)/depth*g1')
sub('vv(1:n,k)=dI(1:n)/cm(6,d)','''if(h(cell)<0d0)then
  call macro_contact_cell_gradient(d,cell,g0,g1,pu(cell,k),du0,du1,nativeU(d),contact_valid)
  if(contact_valid/=1d0)return
  dI(upper)=dI(upper)-fr*du0;dI(lower)=dI(lower)-fr*du1
 end if
 vv(1:n,k)=dI(1:n)/cm(6,d)''')
sub('if(i<cell.or.h(i)<=0d0)return','if(i<lower.or.h(i)<=0d0)return')
sub('doo=-pot(i,k)/delta;uu(i,k)=-pot(i,k)/cm(21,d);vv(i,k)=vv(i,k)-fr*doo/cm(6,d)','doo=-pot(i,k)/delta;vv(i,k)=vv(i,k)-fr*doo/cm(6,d)')
sub('vv(upper,k)=vv(upper,k)-rhoslope*g0/cm(6,d);vv(cell,k)=vv(cell,k)-rhoslope*g1/cm(6,d)','''uu(1:n,k)=-(pot(1:n,k)+pu(1:n,k))/dt
 vv(upper,k)=vv(upper,k)-rhoslope*g0/cm(6,d);vv(lower,k)=vv(lower,k)-rhoslope*g1/cm(6,d)''')
sub("'macro_saturated_all_mass_base.txt'","'macro_saturated_contact_mass_base.txt'")
sub('proof_meta=[dble(cell),h(upper),h(cell),z(upper),z(cell),depth]','proof_meta=[dble(cell),dble(upper),dble(lower),h(upper),h(lower),z(upper),z(lower),depth,contactD1]')
sub('write(proof_unit,*)n,NumDm-1,t1900,dt,numbit','write(proof_unit,*)n,NumDm,t1900,dt,numbit')
sub('QInMtxSatDmCp(d,cell),dq','QInMtxSatDmCp(d,cell),dq,ct0(d),ct1(d)')
sub('write(proof_unit,*)proof_base(1:n)','proof_base(cell)=proof_base(cell)+nativeU(d)\n  write(proof_unit,*)proof_base(1:n)')
sub('res=-1d0;nr=NumDm-1','res=-1d0;nr=NumDm')
sub("'macro_saturated_all_systems.txt'","'macro_saturated_contact_systems.txt'")
p.write_text(s)

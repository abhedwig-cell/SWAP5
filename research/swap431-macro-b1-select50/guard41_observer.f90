! Observation only: no provider evaluations, no changes to eligibility or solve.
subroutine guard41_observe(meta)
use MOD_arrays,only:macp,madm
use MOD_grid,only:numnod,z
use MOD_macropore,only:NumDm,ICpTpSatZon,ICpTpPerZon,ICpBtPerZon,FrReduQ
use MOD_swap_mp,only:swmbf,IcTopMp,IDecMpRat,GwlFlCpZo
use variables,only:h,pegwl
use DIAG19,only:attempts,iter_index
implicit none
real(8),intent(in)::meta(16)
real(8)::cm(24,madm),pot(macp,2),valid,g51,gactual,den
integer::jg,d,ok(5)
logical,save::opened=.false.
integer,save::u,uh,ud
call jac37_get(cm,pot,valid)
jg=numnod
do while(jg>1)
 if(h(jg)<0d0) exit
 jg=jg-1
end do
g51=0d0;gactual=0d0
den=h(51)-h(50)
if(den/=0d0) g51=z(51)+h(51)/den*(z(50)-z(51))
if(jg<numnod) then
 den=h(jg+1)-h(jg)
 if(den/=0d0) gactual=z(jg+1)+h(jg+1)/den*(z(jg)-z(jg+1))
end if
ok(1)=merge(1,0,ICpTpSatZon==51.and.ICpTpPerZon==51.and.ICpBtPerZon==51)
ok(2)=merge(1,0,h(50)<0d0.and.h(51)>0d0.and.h(51)<1d0)
ok(3)=merge(1,0,abs(pegwl-GwlFlCpZo)<=1d-9)
ok(4)=merge(1,0,abs(g51-GwlFlCpZo)<=1d-9)
ok(5)=merge(1,0,numnod>=58.and.NumDm==5.and.swmbf==1.and.IcTopMp==1.and.IDecMpRat==0.and.FrReduQ==1d0)
if(.not.opened) then
 open(newunit=u,file='guard41_trace.txt',status='replace')
 open(newunit=uh,file='guard41_heads.txt',status='replace')
 open(newunit=ud,file='guard41_domains.txt',status='replace')
 opened=.true.
end if
write(u,*) attempts,iter_index,meta(1),valid,numnod,NumDm,swmbf,IcTopMp,IDecMpRat,FrReduQ, &
 ICpTpSatZon,ICpTpPerZon,ICpBtPerZon,pegwl,GwlFlCpZo,h(50),h(51),g51,jg,gactual,ok
write(uh,*) attempts,iter_index,h(1:numnod)
do d=1,NumDm
 write(ud,*) attempts,iter_index,d,cm(:,d)
end do
flush(u);flush(uh);flush(ud)
end subroutine

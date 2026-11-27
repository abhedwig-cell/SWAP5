subroutine observe_geometry_scope(n,cm,pot,pu)
use MOD_arrays,only:macp,madm
use MOD_grid,only:z,dz
use MOD_macropore,only:NumDm,ICpTpSatZon,ICpTpPerZon,ICpBtPerZon, &
 QInMtxSatDmCp,QInIntSatDmCp,QOutMtxSatDmCp,QOutMtxUnsDmCp,VlMpDyCp,SubsidCp
use MOD_swap_mp,only:GwlFlCpZo
use variables,only:h,theta,thetas,pegwl,t1900,dt,numbit
implicit none
integer,intent(in)::n
real(8),intent(in)::cm(24,madm),pot(macp,madm),pu(macp,madm)
integer,save::counter=0,u=0
if(counter>=64)return
if(ICpTpSatZon>=2.and.ICpTpSatZon<=n.and.ICpTpPerZon==ICpTpSatZon.and.ICpBtPerZon==-1.and.pegwl>=990d0)return
counter=counter+1
if(u==0)open(newunit=u,file='macro_geometry_scope.txt',status='replace')
write(u,*)n,NumDm,t1900,dt,numbit,ICpTpSatZon,ICpTpPerZon,ICpBtPerZon,pegwl,GwlFlCpZo
write(u,*)h(1:n),theta(1:n),thetas(1:n),z(1:n),dz(1:n),VlMpDyCp(1:n),SubsidCp(1:n),cm(:,1:NumDm), &
 QInMtxSatDmCp(1:NumDm,1:n),QInIntSatDmCp(1:NumDm,1:n),QOutMtxSatDmCp(1:NumDm,1:n),QOutMtxUnsDmCp(1:NumDm,1:n),pot(1:n,1:NumDm),pu(1:n,1:NumDm)
flush(u)
end subroutine

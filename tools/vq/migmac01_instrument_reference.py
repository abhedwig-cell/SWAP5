from pathlib import Path
import shutil,re,hashlib,json,os
root=Path('reference-run').resolve()
sw=root/'selected'
p=sw/'macropore.f90';s=p.read_text(encoding='cp1252')
hook=r'''
      subroutine migmac01_capture(task)
      use MOD_grid, only: numnod,z,dz,disnod,layer
      use MOD_MvG, only: cofgen
      use MOD_meteo, only: nraidt
      use MOD_irrigation, only: nird,qssdi
      use MOD_snow, only: melt
      use MOD_drain, only: qdra,nrlevs
      use variables, only: h,theta,qrot,dt,t1900,pond,gwl,qtop,qbot,swbotb, &
        k,dimoca,runon,reva,epd,runots
      implicit none
      integer,intent(in)::task
      integer::ic,id,u,j,shift
      real(8),allocatable,save::origin(:,:),scalars(:),domain_config(:,:),node_config(:,:)
      real(8),save::origin_levels(6)
      integer,allocatable,save::bottom(:)
      logical,save::captured=.false.
      if(captured) return
      if(task==1) then
        if(.not.allocated(origin)) allocate(origin(37+8*NumDm,numnod),scalars(12),bottom(NumDm), &
          domain_config(4,NumDm),node_config(7,numnod))
        origin(1,:)=z(1:numnod);origin(2,:)=dz(1:numnod)
        origin(3,:)=h(1:numnod);origin(4,:)=theta(1:numnod)
        origin(5,:)=FrArMtrx(1:numnod);origin(6,:)=qrot(1:numnod)
        origin(7,:)=qssdi(1:numnod);origin(8,:)=sum(qdra(1:nrlevs,1:numnod),dim=1)
        origin(9,:)=k(1:numnod);origin(10,:)=dimoca(1:numnod)
        origin(11,:)=VlMpStCp(1:numnod);origin(12,:)=DiPoCp(1:numnod)
        origin(13:36,:)=cofgen(1:24,1:numnod)
        origin(37,:)=VlMpDyCp(1:numnod)
        do id=1,NumDm
          shift=37+8*(id-1)
          origin(shift+1,:)=SorpDmCp(id,1:numnod)
          origin(shift+2,:)=ThtSrpRefDmCp(id,1:numnod)
          origin(shift+3,:)=TimAbsCumDmCp(id,1:numnod)
          origin(shift+4,:)=VlMpDmCp(id,1:numnod)
          origin(shift+5,:)=WaUnMpDmCp(id,1:numnod)
          origin(shift+6,:)=PpDmCp(id,1:numnod)
          origin(shift+7,:)=FrMpWalWet(id,1:numnod)
          origin(shift+8,:)=FrMpWalWetOld(id,1:numnod)
        end do
        domain_config(1,:)=ICpBtDmPot(1:NumDm)
        domain_config(2,:)=ICpTpWaSrDm(1:NumDm)
        domain_config(3,:)=ZWaLevDm(1:NumDm)
        domain_config(4,:)=ZBtDm(1:NumDm)
        origin_levels=[real(ICpTpSatZon,8),real(ICpTpPerZon,8),real(ICpBtPerZon,8), &
          ShapeFacMp,real(swabs,8),real(swsep,8)]
        do ic=1,numnod
          node_config(:,ic)=[AwlCorFac(ic),SorpMax(layer(ic)),SorpAlfa(layer(ic)), &
            SorpFacParl(layer(ic)),DiMtxSat(layer(ic)),real(SwSorp(layer(ic)),8),real(SwDarcy,8)]
        end do
        bottom=ICpBtDm(1:NumDm)
        scalars=[t1900,dt,pond,gwl,qtop,qbot,nraidt,nird,melt,runon,reva,epd]
      else if(task==2) then
        if(IcTopMp<=1) return
        if(h(IcTopMp-1)<=0.d0) return
        if(sum(QInTopVrtDm(1:NumDm))*dt<=0.d0) return
        open(newunit=u,file='migmac01_authority.csv',status='replace')
        write(u,'(*(g0,:,","))') 'META',t1900,dt,IcTopMp,NumDm,numnod,swbotb,IDecMpRat,FrReduQ
        write(u,'(*(g0,:,","))') 'ORIGIN_SCALARS',scalars
        write(u,'(*(g0,:,","))') 'END_SCALARS',pond,gwl,qtop,qbot,KsatCovLay,DiPoMi,runots
        write(u,'(*(g0,:,","))') 'ORIGIN_LEVELS',origin_levels
        write(u,'(*(g0,:,","))') 'RAPID_CONFIG',RapDraReaExp,KDCrRlRef(1),RapDraResRef(1),ZDrabas
        do id=1,NumDm
          write(u,'(*(g0,:,","))') 'ORIGIN_DOMAIN_CONFIG',id,domain_config(:,id)
        end do
        write(u,'(*(g0,:,","))') 'ORIGIN_BOTTOM',bottom
        write(u,'(*(g0,:,","))') 'END_BOTTOM',ICpBtDm(1:NumDm)
        write(u,'(*(g0,:,","))') 'TOP_AREA',ArMpTp,ArMpTpDm(1:NumDm)
        write(u,'(*(g0,:,","))') 'TOP_COVERED_RATE',QInTopVrtDm(1:NumDm)
        do ic=1,numnod
          write(u,'(*(g0,:,","))') 'ORIGIN_NODE_CONFIG',ic,node_config(:,ic)
          write(u,'(*(g0,:,","))') 'ORIGIN_NODE',ic,origin(:,ic)
          write(u,'(*(g0,:,","))') 'END_NODE',ic,h(ic),theta(ic),FrArMtrx(ic),VlMpDyCp(ic), &
             QExcMpMtx(ic),dFdhMp(ic),QOutDrRapCp(ic)
          do id=1,NumDm
            write(u,'(*(g0,:,","))') 'END_DOMAIN',id,ic,SorpDmCp(id,ic),ThtSrpRefDmCp(id,ic), &
             TimAbsCumDmCp(id,ic),VlMpDmCp(id,ic),WaUnMpDmCp(id,ic),PpDmCp(id,ic), &
             FrMpWalWet(id,ic),FrMpWalWetOld(id,ic),QExcMtxDmCp(id,ic),QInIntSatDmCp(id,ic), &
             QInMtxSatDmCp(id,ic),QOutMtxSatDmCp(id,ic),QOutMtxUnsDmCp(id,ic)
          end do
        end do
        close(u)
        write(*,'(*(g0))') 'MIGMAC01_REFERENCE_CAPTURE|TIME=',t1900,'|DT=',dt, &
          '|TOP=',IcTopMp,'|H=',h(IcTopMp-1),'|COVERED=',sum(QInTopVrtDm(1:NumDm))*dt
        captured=.true.
        stop 0
      end if
      end subroutine migmac01_capture
'''
# Diagnostic subroutine has no writes to physical model fields.
s=s.replace('end module MOD_macropore',hook+'\nend module MOD_macropore')
assert 'subroutine migmac01_capture' in s
p.write_text(s,encoding='cp1252')
p=sw/'soilwater.f90';s=p.read_text(encoding='cp1252')
s=s.replace('only: macrostatevar, macropore','only: macrostatevar, macropore, migmac01_capture')
s=s.replace('if (swmacro == 1) call MacroStateVar(1)','if (swmacro == 1) call MacroStateVar(1)\n         if (swmacro == 1) call migmac01_capture(1)')
s=s.replace('if (swmacro == 1) call macropore(4)','if (swmacro == 1) call macropore(4)\n         if (swmacro == 1) call migmac01_capture(2)')
p.write_text(s,encoding='cp1252')
case=root/'case';shutil.copytree(Path(os.environ['ANDELST_CASE']),case,dirs_exist_ok=True)
p=case/'swap.swp';s=p.read_text()
s,n=re.subn(r'(?m)^(\s*Z_TP\s*=\s*)0\.0',r'\g<1>-2.0',s);assert n==1
p.write_text(s)
print('READ_ONLY_DIAGNOSTICS_AND_FIXED_COVER_INPUT=PREPARED')

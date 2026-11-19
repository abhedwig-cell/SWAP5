! File VersionID:
!   $Id: macrorate.f90 370 2018-02-09 13:29:10Z heine003 $
! ----------------------------------------------------------------------
      SUBROUTINE MACRORATE(ITask)
! ----------------------------------------------------------------------
!     Date               : april 2008                                       
!     Purpose            : 
!     Subroutines called : ABSORPTION, RAPIDDRAIN, SATFLOW                               
!     Functions called   : VOLUNDR
! ----------------------------------------------------------------------
      use MOD_arrays,     only: macp, madm
      use parameters,     only: pi
      use MOD_grid,       only: numnod, dz, z, layer
      use MOD_meteo,      only: nraidt
      use MOD_snow,       only: melt
      use MOD_gwl,        only: calcgwl
      use MOD_irrigation, only: nird
      use variables,      only: t1900, dt, npegwl, h, bpegwl, pegwl, ksatexm, ksatfit
      use MOD_macropore,  only: QMaPo, QRapDra, NumDm, qintopvrtdm, qintoplatdm, qexcmtxdmcp, qinintsatdmcp, qinmtxsatdmcp, qoutmtxsatdmcp,  &
                                qoutmtxunsdmcp, qoutdrrapcp, qexcmpmtx, dfdhmp, ictopmp, qmplatss, armpss, vlmp, wasrmp,                     &
                                flendsrpevt, frreduq, idecmprat, icpbtperzon, icptpperzon, armptpdm, armptp, dipomi,                         &
                                vlmpstcp, vlmpdycp, ksatcovlay, icptpsatzon, gwlflcpzo, zbtdm, vlmpdm,                                       &
                                zdrabas, ppdmcp, icpbtdm, zwalevdm, mpvolume, nodgwlflcpzo, frmpwalwet, icptpwasrdm,swmbf, vlmpdmcp,         &
                                vlmpdmcpm1, waunmpdmcpm1, waunmpdmcp, waunsat,  WaSrMpDm, qtopmpdmcp, icpbtdmm1, nkwt, fldecMPmbf
      use DIAG19,only:target,attempts,iter_index,nvec,limit_u,macro_seq,probe_busy,probe_u,point_id,point_node,point_delta,detail33,apply37
      implicit NONE

      integer::snap23_unit,snap23_mode
      integer::n24,j24,l24
      real(8),save::canonical37(24,madm)=0d0,head37(macp)=0d0,time37=0d0,dt37=0d0
      integer,save::task37=-1,attempt37=-1,iteration37=-1
      logical,save::ready37=.false.
      real(8)::get45_meta(24),get45_pot(2),get45_stamp(7)
      real(8)::get37_meta(24,madm),get37_potential(macp,2),get37_valid

      real(8)::pot35(macp),info35(12)
      real(8),save::obs36_meta(24,madm),obs36_in(macp,madm),obs36_outsat(macp,madm),obs36_outuns(macp,madm),obs36_rapid(macp,madm)
      real(8)::get36_meta(24,madm),get36_in(macp,madm),get36_outsat(macp,madm),get36_outuns(macp,madm),get36_rapid(macp,madm)

      real(8)::u24(macp),v24(macp),d24(macp),meta24(12)
      real(8)::f24,rho24,g24,den24,dh24,hm24


! --- global                                                          In
      integer, intent(in)     :: ITask
      
! ----------------------------------------------------------------------
! --- local
      integer, save                       :: ic, id, jd, SqHlp
      integer, save, dimension(MaDm)      :: Sq
      integer, save                       :: icc, icgwl, icuns, ichlp, iter                                               ! KWT Integers
      real(8), save                       :: CritHtop, FrFlwIn, FrFlwOut, FlwInDmExces 
      real(8), save, dimension(MaDm)      :: FlwInIntSatDmPot,    FlwInMtxSatDmPot,    FlwInTopLatDmPot, FlwInTopVrtDmPot
      real(8), save, dimension(MaDm)      :: FlwOutMtxUnsDmPot,   FlwOutMtxSatDmPot,   FlwOutDmExces,    FlwOutDmTot
      real(8), save, dimension(MaCp)      :: FlwInIntSatCpPot,    FlwInMtxSatCpPot,    FlwOutDrRapCpPot
      real(8), save, dimension(MaDm,MaCp) :: FlwOutMtxUnsDmCpPot, FlwOutMtxSatDmCpPot
      real(8), save                       :: FlwInDmTot, FlwInTopExcesTot, FlwInTopPot, FlwInTopXtr, FlwOutDrRapPot
      real(8), save, dimension(MaDm)      :: SatDefDm, SatDefDmRel
      real(8), save                       :: FrXtr, Pp, PpTot, SatDefTot, VlMpUndrDrL, VlMpUndrGwL
      real(8), save                       :: WaSrMpDmMax, WaSrMpDmMin, WaSrMpDmTmp
      real(8), save                       :: Ld, r0, w_geom, Henpr1  
      real(8),save::lim_min,lim_max,lim_under,lim_in,lim_out,lim_tmp,lim_frin,lim_excess,lim_nodein
      real(8) VOLUNDR
      real(8), save                       :: ThetaExc, FlwInTopExc, FrFlwTopIn, FrFlwSideIn, FlwRed                       ! KWT Flow reduction variables
      real(8), save, dimension(MaCp)      :: FlwTopCp, FlwLatCpPot                                                        ! KWT Flow variables
      real(8), save                       :: FlwLatAbs, FlwSat, FlwSatNew                                                 ! KWT Flow variables
      real(8), save                       :: QInIntSatS, QInMtxSatS, QOutMtxSatS, QOutMtxUnsS, FlwTopS, FlwLatCpS, WaSat  ! KWT Flow variables saturated part of interface cp
      real(8), save                       :: SRel0, SRel1, Srelavg, Vl0, Vl1, FrMpSat, CpFr                               ! KWT State variables at t and t+dt
      real(8), save, dimension(MaCp)      :: MPRelSat, WaUnTmp                                                            ! KWT State variables at t+dt
      real(8), save                       :: dtheta, dthetaold, fdtheta, fdthetadrv                                       ! KWT Calculation variables
      real(8), save                       :: KSatMP, RapDraRes                                                            ! KWT MP variables
      real(8), save                       :: dH_MPOld, dH_MP, zdenom, denommax, zdenommax, denom, numer                   ! KWT Change in MP gwl
      real(8), save                       :: CorFac, cfdry, cfdry2                                                        ! KWT Correction variables
      real(8), save, dimension(MaCp)      :: massbal                                                                      ! KWT Mass balance for debug
      logical, save                       :: kwsat, notconv, MPempty, MPfull                                              ! KWT logical variables
      logical, save, dimension(MaCp)      :: KwSatCp
      character(len=200)         :: message
      character(len=19)          :: datetime

! ----------------------------------------------------------------------
!     for FORCHECK
      macro_seq=macro_seq+1
      call reference48_invalidate()
      t1900 = t1900
!
!> I < ---------- INITIALISE AND CHECK MACROPORE STATUS ---------------
! --- Initialisation Fluxes and Derivatives
      if(apply37) ready37=.false.
      QMaPo                            = 0.d0
      QRapDra                          = 0.d0
      QInTopVrtDm(1:NumDm)             = 0.d0
      QInTopLatDm(1:NumDm)             = 0.d0
      QExcMtxDmCp(1:NumDm,1:NumNod)    = 0.d0 
      QInIntSatDmCp(1:NumDm,1:NumNod)  = 0.d0
      QInMtxSatDmCp(1:NumDm,1:NumNod)  = 0.d0
      QOutMtxSatDmCp(1:NumDm,1:NumNod) = 0.d0
      QOutMtxUnsDmCp(1:NumDm,1:NumNod) = 0.d0
      QOutDrRapCp(1:NumNod)            = 0.d0
      QExcMpMtx(1:NumNod)              = 0.d0
      dFdhMp(1:NumNod)                 = 0.d0  
      
! --- Update groundwater level of matrix based on current h iteration
      call calcgwl()
      
! --- Update compartment numbers related to groundwater and perched groundwater level in matrix
!   - ICpTpSatZon = top compartment of saturated zone (NodGwl deepest unsat. node)
!      ICpTpSatZon  = max(NodGwlFlCpZo+1,IcTopMp) 
!      if (GwlFlCpZo < (Z(NodGwlFlCpZo)-0.5d0*DZ(NodGwlFlCpZo))) then ! This never occurs! NodGwlFlCpZo is the node containing the 
!         ICpSatGWl = ICpTpSatZon
!      else
!         ICpSatGWl = -1
!         if (NodGwlFlCpZo == 1 .AND. GwlFlCpZo > Z(NodGwlFlCpZo)) ICpTpSatZon = 1
!      end if
      
      ICpTpSatZon = NodGwlFlCpZo

!     ICpTpPerZon = top compartment of perched groundwater
      if (NPeGwl > 0) then
!        Perched groundwater exists
         ICpBtPerZon    = BPeGWl
         ICpTpPerZon    = NPeGwl! + 1
!         if (PeGWl < Z(NPeGwl)-0.5d0*DZ(NPeGwl)) then
!            ICpSatPeGWl = ICpTpPerZon
!         else
!            ICpSatPeGWl = -1
!            if (NPeGwl == 1 .AND. PeGWl > Z(NPeGwl)) ICpTpPerZon = 1
!         end if
      else
!        No perched groundwater
         ICpBtPerZon = -1
         ICpTpPerZon = ICpTpSatZon
      end if
      
!     Update macropore volumes based on current h / theta iteration
      call MPVOLUME (1)
      
!     Check whether the macropore status requires the working of this subroutine
      if (IcTopMp == 1) then                                        ! no covering layer on top of macropores
         FlwInTopPot = QMpLatSs + ArMpSs * (NRaiDt+NIrd+Melt) * dt
      else                                                          ! covering layer on top of macropores
         FlwInTopPot = 0.d0
      end if
      if (swmbf == 1) then 
         if (VlMp < 1.d-6 .OR. (WaSrMp < 1.d-6 .AND. FlwInTopPot < 1.d-6     &
             .AND. ICpBtDm(1) <= NodGwLFlCpZo .AND. NPeGwL < IcTopMp) ) then 
            FlEndSrpEvt(1:NumDm,IcTopMP:NumNod)= .TRUE.
            QMpLatSs = 0.d0
!            return
         end if
      end if

      FrReduQ     = 0.1d0**(dble(IDecMpRat))
   

!> II < ----- CALCULATE RATES AND DERIVATIVES PER MACROPORE DOMAIN -----
!
!     General initialisation
      FlwInTopExcesTot = 0.d0
      SatDefTot        = 0.d0
!
      do id = 1, NumDm
         FlwInDmTot                 = 0.d0  
         FlwOutDmTot(id)            = 0.d0
         if (id == 1) FlwOutDrRapCpPot(1:numnod) = 0.d0

! - A. CALCULATE POTENTIAL IN- AND OUTGOING WATER FLOWS    
         
! - 1. CASE 0:   INITIALIZATION
         call SATFLOW(0,id,ICpBtPerZon,ICpTpPerZon,PeGWL,                          &
                      ICpTpWaSrDm(id),FrMpWalWet(id,ICpTpWaSrDm(id)),ZWaLevDm(id), &
                      FlwInIntSatCpPot,FlwInIntSatDmPot,FlwOutMtxSatDmCpPot,FlwOutMtxSatDmPot)

! - 1. CASE 1:   INCOMING WATER FLOWS
!   1.a. INFLoW into macropores at soil surface (FlwInTop...) by infiltration:
!        directly by vertical inflow (Vrt; precipitation Pre or seepage covering layer) 
!        and indirectly by lateral (Lat) overland flow of matrix infiltration excess (runoff)
         FlwInTopLatDmPot(id) = 0.d0

         if (IcTopMp == 1) then                                      
!           No covering layer on top of macropores
            FlwInTopVrtDmPot(id) = ArMpTpDm(id) * (NRaiDt+NIrd+Melt) * dt
            if (ArMpSs > 0.d0) FlwInTopLatDmPot(id)= ArMpTpDm(id)/ArMpTp * QMpLatSs 
         else
!           Covering layer on top of macropores
            ic        = IcTopMp-1
            Henpr1    = 0.d0 ! H_enpr(1) 
            CritHtop  = Henpr1
            if (h(ic) > CritHtop) then  
               Ld     = dipomi
               r0     = 0.5d0 * dipomi * (1.d0 - dsqrt(1.d0-VlMpStCp(IcTopMp)-VlMpDyCp(IcTopMp)))              
               w_geom = 1.d0 / (1.d0 + Ld/(pi*dz(ic)/2.d0)*log((Ld/(pi*r0))) + Ld**2/(6.d0*dz(ic)**2))
!
               FlwInTopVrtDmPot(id) = w_geom * KsatCovLay * ((h(ic)-Henpr1) / (dz(ic)/2.d0) + 1.d0) * dt
               FlwInTopVrtDmPot(id) = ArMpTpDm(id)/ArMpTp * max(0.d0,FlwInTopVrtDmPot(id)) 
            else
               FlwInTopVrtDmPot(id) = 0.d0
            end if
         end if
!
!   1.b. INFLoW into macropores from SATurated top compartments by INTerflow: 
         call SATFLOW(1,id,ICpBtPerZon,ICpTpPerZon,PeGWL,                          &
                      ICpTpWaSrDm(id),FrMpWalWet(id,ICpTpWaSrDm(id)),ZWaLevDm(id), &
                      FlwInIntSatCpPot,FlwInIntSatDmPot,FlwOutMtxSatDmCpPot,FlwOutMtxSatDmPot)

!   1.c. INFLoW into macropores from SATurated MaTriX compartm. (exfiltration): 
         call SATFLOW(1,id,NumNod,ICpTpSatZon,GWlFlCpZo,                          &
                      ICpTpWaSrDm(id),FrMpWalWet(id,ICpTpWaSrDm(id)),ZWaLevDm(id), &
                      FlwInMtxSatCpPot,FlwInMtxSatDmPot,FlwOutMtxSatDmCpPot,FlwOutMtxSatDmPot)

! - 2. CASE 2:   OUTGOING WATER FLOWS 
!   2.a. OUTFLoW out off macrop. into SATurated MaTriX compartm. (infiltrat.): 
         call SATFLOW(2,id,NumNod,ICpTpPerZon,GWlFlCpZo,                           &
                      ICpTpWaSrDm(id),FrMpWalWet(id,ICpTpWaSrDm(id)),ZWaLevDm(id), &
                      FlwInMtxSatCpPot,FlwInMtxSatDmPot,FlwOutMtxSatDmCpPot,FlwOutMtxSatDmPot)

!   2.b. OUTFLoW out off macrop. into UNSaturated MaTriX compart. (absorption): 
         call ABSORPTION(1,id,FlwOutMtxUnsDmCpPot,FlwOutMtxUnsDmPot)

!   2.c. OUTFLoW out off macropores by RAPid DRainage. Only Main Domain (id= 1): 
         call RAPIDDRAIN(id,ICpTpWaSrDm(id),FrMpWalWet(id,ICpTpWaSrDm(id)),        &
              ZWaLevDm(id),RapDraRes,FlwOutDrRapCpPot,FlwOutDrRapPot)       
         
! - B. CALCULATE NEW WATER STORAGE AND CHECK WITH AVAILABLE DOMAIN VOLUME
! -    For Kinematic Wave in MB domain, water is not directly added to bottom
! -    of compartment. Differentiation between two concepts starts.

! B.1. Standard procedure: water added directly to groundwater in MP
         if (swmbf == 1 .OR. (swmbf == 2 .AND. id > 1)) then

            FlwInDmTot      = FlwInTopVrtDmPot(id) + FlwInTopLatDmPot(id) + FlwInIntSatDmPot(id) + FlwInMtxSatDmPot(id)
            FlwOutDmTot(id) = FlwOutMtxSatDmPot(id) + FlwOutMtxUnsDmPot(id)
            if (id == 1) FlwOutDmTot(1) = FlwOutDmTot(1) + FlwOutDrRapPot

!           Temporary storage in mp domain
            WaSrMpDmTmp     = WaSrMpDm(id) + FlwInDmTot - FlwOutDmTot(id)
 
!           Volume of domain below matrix gwl
            VlMpUndrGwL     = 0.d0
            if (ZBtDm(id) < GWlFlCpZo .AND. GWlFlCpZo < 900.d0) then  ! GWL = 999. indicates NO gwl
               VlMpUndrGwL  = VOLUNDR(GWlFlCpZo,ZBtDm(id),ICpBtDm(id),VlMpDmCp(id,1:numnod))
               VlMpUndrGwL  = dmin1(VlMpUndrGwL,VlMpDm(id))
            end if
         
!           If inflow is only from saturated matrix in real (not perched) groundwater then level in domain can not exceed gwl        
            WaSrMpDmMax = VlMpDm(id)      
            if ((FlwInDmTot-FlwInMtxSatDmPot(id)) / dt < 1.d-7 .AND. FlwInMtxSatDmPot(id) / dt > 1.d-7) WaSrMpDmMax = VlMpUndrGwL     

!           In case of inflow excess, decrease incoming fluxes
            FrFlwIn = 1.d0
            if (WaSrMpDmTmp > WaSrMpDmMax+1.d-7 .AND. FlwInDmTot > 0.d0) then
               FlwInDmExces     = WaSrMpDmTmp - WaSrMpDmMax
               FrFlwIn          = dmax1(0.d0,1.d0 - FlwInDmExces/FlwInDmTot)
!              Total inflow excess at top for decreasing top inflow in main SWAP
               FlwInTopExcesTot = FlwInTopExcesTot + (1.d0 - FrFlwIn) * (FlwInTopVrtDmPot(id)+FlwInTopLatDmPot(id))
            end if
            
            if (FlwInDmTot < 0.d0) then ! Should not be possible. If code ends up here, water balance error will occur.
                FrFlwIn = 0.d0
            end if
            
!           Decrease inflow terms of domain
            QInTopVrtDm(id)                  = FrFlwIn * FlwInTopVrtDmPot(id) / dt
            QInTopLatDm(id)                  = FrFlwIn * FlwInTopLatDmPot(id) / dt
            QInIntSatDmCp(id,IcTopMp:NumNod) = FrFlwIn * FlwInIntSatCpPot(IcTopMp:NumNod) / dt
            QInMtxSatDmCp(id,IcTopMp:NumNod) = FrFlwIn * FlwInMtxSatCpPot(IcTopMp:NumNod) / dt

!           Determine minimum water storage in domain
            WaSrMpDmMin = dmin1(VlMpUndrGwL,WaSrMpDm(id))                   

            if (id == 1) then
!              In case of MB domain rapid drainage is possible     
               VlMpUndrDrL = 0.d0
               if (ZBtDm(id) < ZDraBas) VlMpUndrDrL = VOLUNDR(ZDraBas,ZBtDm(id),ICpBtDm(id),VlMpDmCp(id,1:numnod))
               if (VlMpUndrDrL > 1.d-6 .AND. VlMpUndrDrL < WaSrMpDmMin) WaSrMpDmMin = VlMpUndrDrL
            end if

!           Excess outflow; compensated in later sections
            FlwOutDmExces(id) = 0.d0
            if (WaSrMpDmTmp < WaSrMpDmMin) FlwOutDmExces(id) = WaSrMpDmMin - WaSrMpDmTmp
            if(apply37) then
             canonical37(:,id)=0d0
             canonical37(1:15,id)=[WaSrMpDm(id),WaSrMpDmMin,WaSrMpDmMax,VlMpUndrGwL,FlwInDmTot,FlwOutDmTot(id), &
              WaSrMpDmTmp,FrFlwIn,FlwInTopVrtDmPot(id),FlwInTopLatDmPot(id),FlwInIntSatDmPot(id),FlwInMtxSatDmPot(id), &
              FlwOutMtxSatDmPot(id),FlwOutMtxUnsDmPot(id),merge(FlwOutDrRapPot,0d0,id==1)]
             canonical37(18:24,id)=[VlMpDmCp(id,ICpTpSatZon)/dz(ICpTpSatZon),GwlFlCpZo,dble(ICpTpSatZon),dt,0d0,dble(IcTopMp),ZWaLevDm(id)]
            end if
            if(detail33) then
             obs36_meta(:,id)=0d0
             obs36_meta(1:15,id)=[WaSrMpDm(id),WaSrMpDmMin,WaSrMpDmMax,VlMpUndrGwL,FlwInDmTot,FlwOutDmTot(id), &
              WaSrMpDmTmp,FrFlwIn,FlwInTopVrtDmPot(id),FlwInTopLatDmPot(id),FlwInIntSatDmPot(id),FlwInMtxSatDmPot(id), &
              FlwOutMtxSatDmPot(id),FlwOutMtxUnsDmPot(id),merge(FlwOutDrRapPot,0d0,id==1)]
             obs36_meta(18:24,id)=[VlMpDmCp(id,ICpTpSatZon)/dz(ICpTpSatZon),GwlFlCpZo,dble(ICpTpSatZon),dt,0d0,dble(IcTopMp),ZWaLevDm(id)]
             obs36_in(:,id)=FlwInMtxSatCpPot+FlwInIntSatCpPot
             obs36_outsat(:,id)=FlwOutMtxSatDmCpPot(id,:)
             obs36_outuns(:,id)=FlwOutMtxUnsDmCpPot(id,:)
             obs36_rapid(:,id)=0d0
             if(id==1) obs36_rapid(:,id)=FlwOutDrRapCpPot
            end if
            if(target.and.id==3) then
             lim_min=WaSrMpDmMin;lim_max=WaSrMpDmMax;lim_under=VlMpUndrGwL
             lim_in=FlwInDmTot;lim_out=FlwOutDmTot(id);lim_tmp=WaSrMpDmTmp;lim_frin=FrFlwIn
             lim_excess=FlwOutDmExces(id);lim_nodein=FlwInMtxSatCpPot(52)
             call limit21_trace(1)
            end if

   
!           Saturation deficit of domain and of total of domains: for checking available storage for excess from other domains
            SatDefDm(id)    = dmax1(0.d0,(VlMpDm(id)-WaSrMpDmTmp))
            SatDefDmRel(id) = SatDefDm(id) / PpDmCp(id,IcTopMp)
            SatDefTot       = SatDefTot + SatDefDm(id)
                         
             
!  B.2 Kinematic wave requires calculation of water storage and fluxes per compartment
         else
!  B.2.a    Unsaturated part of MP domain with kinematic wave approach       

!           For simplicity, stop contribution of flwoutdrrapcp in cp with interface between sat and unsat
            if (id == 1) FlwOutDrRapCpPot(ICpTpWaSrDm(id)) = 0.d0
          
!           Initialize:
            FlwTopS          = 0.d0    ! Flow at top of saturated part of compartment
            QInIntSatS       = 0.d0    ! Inflow in sat part of cp with interface due to interflow
            QInMtxSatS       = 0.d0    ! Inflow in sat part of cp with interface due to saturated flow
            QOutMtxSatS      = 0.d0    ! Outflow in sat part of cp with interface due to saturated flow 
            QOutMtxUnsS      = 0.d0    ! Outflow in sat part of cp with interface due to unsaturated flow
            FlwInTopExc      = 0.d0    ! Excess inflow in top compartment
            ThetaExc         = 0.d0    ! Excess water storage
            FrFlwTopIn       = 1.d0    ! Reduction fraction top (for FlwInExc)
            FrFlwSideIn      = 1.d0    ! Reduction fraction sides (for ThetaExcTop)
            WaSat            = 0.d0    ! Water content for initially saturated part of cp with interface between sat/unsat
            WaUnsat(id)      = 0.d0    ! Water storage in unsaturated part of cp with interface between sat/unsat
            KwSat            = .FALSE. ! Flag indicating if saturation occurs
            KwSatCp(1:macp)  = .FALSE. ! Saturation of compartments at end of time step
            fldecMPmbf       = .FALSE. ! Flag indicating time step is too large
            cfdry2           = 1.d0    ! Correction factor in case calculated change exceeds available pore space
           
            do ic = IcTopMp,ICpBtDm(id)
                                             
!              Inflow at top of compartment
               if (ic == IcTopMp) FlwTopCp(ic) = FlwInTopVrtDmPot(id) + FlwInTopLatDmPot(id)
              
!              Lateral inflow from (positive) or outflow to (negative) matrix
               FlwLatCpPot(ic) = FlwInIntSatCpPot(ic) + FlwInMtxSatCpPot(ic) - &
                                 FlwOutMtxUnsDmCpPot(id,ic) 
               if (ic /= ICpTpWaSrDm(id)) FlwLatCpPot(ic) = FlwLatCpPot(ic) - FlwOutMtxSatDmCpPot(id,ic) ! Consider only unsaturated part of cp with interface
               FlwLatAbs       = abs(FlwLatCpPot(ic))             
                            
!              Initialization per compartment
               CorFac    = 1.d0 ! Correction factor (multiple uses)
               ksatMP    = (ksatexm(Layer(ic))-ksatfit(Layer(ic))) * PpDmCp(id,ic)
               
               CpFr      = 1.d0 ! Compartment Fraction; at saturated/unsaturated interface, now consider only unsaturated part
               if (FrMpWalWet(id,ic) > 0.99999d0) FrMpWalWet(id,ic) = 1.d0
               if (ic == ICpTpWaSrDm(id) .AND. FrMpWalWet(id,ic) < 1.d0) CpFr = 1.d0-FrMpWalWet(id,ic) 
               ! Note: if ICpTpWaSrDm .AND. completely saturated: CpFr=1:calculations are same as sat calc

               Vl0       = VlMpDmCpM1(id,ic) * CpFr
               Vl1       = VlMpDmCp(id,ic)   * CpFr
               
               Srel0     = 1.d0    ! Relative saturation at start of time step
               if (VlMpDmCpM1(id,ic) > 0.d0) Srel0 = WaUnMpDmCpM1(id,ic) / Vl0
               if (ic == ICpTpWaSrDm(id))    Srel0 = max((WaUnMpDmCpM1(id,ic) - (1.d0-CpFr)*VlMpDmCpM1(id,ic)) / Vl0,0.d0)
               
!              Iterative calculation of potential change in water storage for unsaturated macropore compartments
               dtheta    = 1.d-6
               notconv   = .TRUE.
               iter      = 1
               
               do while (notconv)
                  dthetaold  = dtheta
                  SrelAvg    = 0.5d0*(Srel0*(1.d0+Vl0/Vl1) + dtheta/Vl1)
                  fdtheta    = ksatMP * SrelAvg**nkwt + dtheta/dt +              &
                               FlwLatAbs*CpFr/dt*SrelAvg -                       &
                               (FlwLatAbs + FlwLatCpPot(ic))*CpFr/dt/2.d0 -      &
                               FlwTopCp(ic)/dt
                  if (id == 1) fdtheta = fdtheta + FlwOutDrRapCpPot(ic)/dt
                  fdthetadrv = nkwt/(Vl1*2.d0) * ksatMP * SrelAvg**(nkwt-1.d0) + &
                               FlwLatAbs*CpFr/dt/(Vl1*2.d0) + 1.d0/dt
                  dtheta     = dtheta - fdtheta/fdthetadrv
                  
                  iter       = iter + 1
                  if (abs(dtheta/dt) < 1.d-9) notconv = .FALSE.
                  if (abs(dthetaold - dtheta) < 1.d-10) notconv = .FALSE.
                  if (iter > 1000 .AND. dtheta < -VlMpDmCp(id,ic)) then
                     dtheta  = -VlMpDmCp(id,ic)
                     notconv = .FALSE.
                  end if
                  if (iter > 1000 .AND. srel0 < 1.d-7) then
                     dtheta  = 0.d0
                     notconv = .FALSE.
                  end if
               end do
               
!              Check wether MP compartment is not oversaturated at end of timestep
               Srel1 = (WaUnMpDmCpM1(id,ic) + dtheta) / Vl1 ! Relative saturation at end of time step
               if (ic == ICpTpWaSrDm(id)) Srel1 = ((WaUnMpDmCpM1(id,ic) - (1.d0-CpFr)*VlMpDmCpM1(id,ic)) + dtheta) / Vl1
               
               if (Srel1-1.d0 > 0.d0 .AND. Srel1-1.d0 < 1.d-7) then
                  Srel1  = 1.d0
                  dtheta = Vl1 - WaUnMpDmCpM1(id,ic)
               end if
                              
               if (Srel1 > 1.d0) then
!                 Oversaturation: limit inflow at top by reconsidering layers above

!                 Calculate excess water in cp
                  SrelAvg     = 0.5d0*(Srel0*(1.d0+Vl0/Vl1) + dtheta/Vl1)
                  if (SrelAvg > 1.d0) then
                     ThetaExc = -99.d0 ! To be adjusted later on: closing water balance
                     Srel1    = 1.d0
                     SrelAvg  = (Srel0+Srel1)/2.d0
                  else
                     ThetaExc = (Srel1-1.d0) * Vl1
                     Srel1    = 1.d0
                  end if
                  
!                 Calculate in- and outgoing fluxes and water storage
                  if (ic == ICpTpWaSrDm(id) .AND. FrMpWalWet(id,ic) >= 1.d0) then 
!                    Special case: interface sat/unsat in MP at edge of cp
                     QInIntSatS  = FlwInIntSatCpPot(ic) * (1.d0 - Srelavg) / dt 
                     QInMtxSatS  = FlwInMtxSatCpPot(ic) * (1.d0 - Srelavg) / dt
                     QOutMtxSatS = FlwOutMtxSatDmCpPot(id,ic)   * Srelavg  / dt
                     QOutMtxUnsS = FlwOutMtxUnsDmCpPot(id,ic)   * Srelavg  / dt
                     QInIntSatDmCp(id,ic)  = 0.d0
                     QInMtxSatDmCp(id,ic)  = 0.d0
                     QOutMtxSatDmCp(id,ic) = 0.d0
                     QOutMtxUnsDmCp(id,ic) = 0.d0
                     
                     FlwTopS        = FlwTopCp(ic)
                     FlwTopCp(ic+1) = KsatMP * SrelAvg**nkwt * dt
                  
                     WaSat             = Vl1
                     WaUnMpDmCp(id,ic) = 0.d0
                     
                     if (ThetaExc < -98.d0) then 
                        ThetaExc       = WaUnMpDmCpM1(id,ic) - WaSat + FlwTopCp(ic) - FlwTopCp(ic+1) + & 
                                        (QInIntSatS + QInMtxSatS - QOutMtxUnsS - QOutMtxSatS) * dt                    
                     end if
                     
                     FlwTopCp(ic) = FlwTopCp(ic) - ThetaExc
                     FlwTopS      = FlwTopCp(ic)

                  else 
!                    Normal case
                     QInIntSatDmCp(id,ic)  = FlwInIntSatCpPot(ic) * (1.d0 - Srelavg) / dt
                     QInMtxSatDmCp(id,ic)  = FlwInMtxSatCpPot(ic) * (1.d0 - Srelavg) / dt
                     QOutMtxSatDmCp(id,ic) = FlwOutMtxSatDmCpPot(id,ic)   * Srelavg  / dt
                     QOutMtxUnsDmCp(id,ic) = FlwOutMtxUnsDmCpPot(id,ic)   * Srelavg  / dt
                     if (id == 1) QOutDrRapCp(ic) = FlwOutDrRapCpPot(ic) / dt
                     if (ic == ICpTpWaSrDm(id)) QOutMtxSatDmCp(id,ic) = 0.d0
                                       
                     FlwTopCp(ic+1)    = KsatMP * SrelAvg**nkwt * dt
                     if (ic == ICpTpWaSrDm(id)) FlwTopS = FlwTopCp(ic+1)
                  
                     WaUnMpDmCp(id,ic) = Vl1
                     
                     if (ThetaExc < -98.d0) then 
                        if (ic == ICpTpWaSrDm(id)) then
                           ThetaExc = (WaUnMpDmCpM1(id,ic) - (1.d0-CpFr)*VlMpDmCpM1(id,ic)) - WaUnMpDmCp(id,ic) + FlwTopCp(ic) - FlwTopCp(ic+1) +    & 
                                      (QInIntSatDmCp(id,ic) + QInMtxSatDmCp(id,ic) - QOutMtxUnsDmCp(id,ic)) * CpFr * dt - QOutMtxSatDmCp(id,ic) * dt      
                           if (id == 1) ThetaExc = ThetaExc - QOutDrRapCp(ic) * CpFr * dt
                        else
                           ThetaExc = WaUnMpDmCpM1(id,ic) - WaUnMpDmCp(id,ic) + FlwTopCp(ic) - FlwTopCp(ic+1) +                          & 
                                      (QInIntSatDmCp(id,ic) + QInMtxSatDmCp(id,ic) - QOutMtxUnsDmCp(id,ic) - QOutMtxSatDmCp(id,ic)) * dt       
                           if (id == 1) ThetaExc = ThetaExc - QOutDrRapCp(ic) * dt
                        end if
                     end if
                     
                     FlwTopCp(ic)      = FlwTopCp(ic) - ThetaExc
                  end if
                               
                  ! Mass balance for debugging
                  massbal(ic) = FlwTopCp(ic) - FlwTopCp(ic+1) +                        & ! Top & bot
                                (QInIntSatDmCp (id,ic) + QInMtxSatDmCp(id,ic)) * dt -  & ! Inflow
                                (QOutMtxUnsDmCp(id,ic) + QOutMtxSatDmCp(id,ic)) * dt + & ! Outflow
                                WaUnMpDmCpM1(id,ic) - WaUnMpDmCp(id,ic)                  ! Storage 
                  if (id == 1) massbal(ic) = massbal(ic) - QOutDrRapCp(ic) * dt
                  if (ic == ICpTpWaSrDm(id)) then ! Consider only unsaturated part
                     massbal(ic) = FlwTopCp(ic) - FlwTopCp(ic+1) +                                                              & ! Top & bot
                        (QInIntSatDmCp(id,ic) + QInMtxSatDmCp(id,ic) - QOutMtxUnsDmCp(id,ic)) * dt * (1.d0-FrMpWalWet(id,ic)) + & ! Unsaturated part
                        (WaUnMpDmCpM1(id,ic) - (1.d0-CpFr)*VlMpDmCpM1(id,ic)) - WaUnMpDmCp(id,ic)                                 ! Storage
                  end if                         
                        
                  if (abs(massbal(ic)) > 1.d-7) then
                     continue
                  end if
                  
                  KwSatCp(ic) = .TRUE. ! Compartment saturated
                  icc   = ic - 1
                  kwsat = .TRUE.       ! Flag to indicate saturation 

                  do while (icc > (ICTopMp-1) .AND. kwsat)
!                    Loop over compartments in upward direction to add excess water to these compartments                     
                     if (icc == ICpTpWaSrDm(id)) then 
!                       Consider sat part of cp first
                        CpFr = FrMpWalWet(id,icc)
                        
                        Vl1   = VlMpDmCp(id,icc)   * CpFr
                        Vl0   = VlMpDmCpM1(id,icc) * CpFr

                        Srel0 = 1.d0

                        FlwLatAbs = abs(FlwLatCpS)
                        dtheta    = (FlwTopS/dt - FlwLatAbs/dt * 0.5d0*Srel0*(1.d0+Vl0/Vl1) + &
                                    (FlwLatAbs+FlwLatCpS)/dt/2.d0 - FlwTopCp(icc+1)/dt) /     &
                                    (1.d0/dt + FlwLatAbs/dt/(2.d0*Vl1))

                        Srel1     = (CpFr * VlMpDmCpM1(id,icc) + dtheta) / Vl1                      
                        
                        if (Srel1 <= 1.d0) then 
!                          No longer saturated
                           CorFac = 1.d0 ! Correction factor if Srel1 < 0 (i.e. negative storage at end of ts)
                           if (Srel1 < 0.d0 .AND. Srel0 > 0.d0) CorFac = Srel0*Vl0/(-Srel1*Vl1+Srel0*Vl0)

                           WaSat       = CpFr*VlMpDmCpM1(id,icc) + dtheta * CorFac 

                           SrelAvg     = 0.5d0*(Srel0*(1.d0+Vl0/Vl1) + dtheta/Vl1)

                           QInIntSatS  = FlwInIntSatCpPot(icc) * (1.d0 - Srelavg) / dt * CorFac 
                           QInMtxSatS  = FlwInMtxSatCpPot(icc) * (1.d0 - Srelavg) / dt * CorFac
                           QOutMtxSatS = FlwOutMtxSatDmCpPot(id,icc)   * Srelavg  / dt * CorFac
                           QOutMtxUnsS = FlwOutMtxUnsDmCpPot(id,icc)   * Srelavg  / dt * CorFac
                                                      
                           kwsat  = .FALSE.
                        else 
!                          Remains saturated
                           Srelavg     = 1.d0
                           QInIntSatS  = FlwInIntSatCpPot(icc) * (1.d0 - Srelavg) / dt
                           QInMtxSatS  = FlwInMtxSatCpPot(icc) * (1.d0 - Srelavg) / dt
                           QOutMtxSatS = FlwOutMtxSatDmCpPot(id,icc)   * Srelavg  / dt
                           QOutMtxUnsS = FlwOutMtxUnsDmCpPot(id,icc)   * Srelavg  / dt
                           WaSat       = Vl1
                           ThetaExc    = FlwTopS - FlwTopCp(icc+1) + Vl0 - Vl1 +                                 &
                                         (QInIntSatS + QInMtxSatS - QOutMtxUnsS) * CpFr * dt - QOutMtxSatS * dt 
                           FlwTopS     = FlwTopS - ThetaExc  
                        end if
                     end if
                     
                     if (icc == ICpTpWaSrDm(id) .AND. FrMpWalWet(id,icc) >= 1.d0) then 
!                       Special case: interface sat/unsat at edge of cp
                        FlwTopCp(icc)      = FlwTopS
                        WaUnMpDmCp(id,icc) = 0.d0
                     else if (kwsat) then 
!                       Normal case
                        CpFr  = 1.d0
                        if (icc == ICpTpWaSrDm(id)) CpFr = 1.d0-FrMpWalWet(id,icc)
                        
                        Vl1   = VlMpDmCp(id,icc)   * CpFr
                        Vl0   = VlMpDmCpM1(id,icc) * CpFr

                        Srel0     = 1.d0
                        if (VlMpDmCpM1(id,icc) > 0.d0) Srel0 = WaUnMpDmCpM1(id,icc) / Vl0
                        if (icc == ICpTpWaSrDm(id))    Srel0 = max((WaUnMpDmCpM1(id,icc) - (1.d0-CpFr)*VlMpDmCpM1(id,icc)) / Vl0,0.d0)

                        FlwLatAbs = abs(FlwLatCpPot(icc))
                        if (icc == ICpTpWaSrDm(id)) then 
                           dtheta    = (FlwTopCp(icc)/dt - FlwLatAbs*CpFr/dt * 0.5d0*Srel0*(1.d0+Vl0/Vl1) + &
                                       (FlwLatAbs+FlwLatCpPot(icc))*CpFr/dt/2.d0 - FlwTopS/dt) /            &
                                       (1.d0/dt + FlwLatAbs*CpFr/dt/(2.d0*Vl1))
                        else if (icc == IcTopMp .AND. KwSatCp(icc)) then
                           dtheta    = ((FlwInTopVrtDmPot(id) + FlwInTopLatDmPot(id))/dt - FlwLatAbs*CpFr/dt * 0.5d0*Srel0*(1.d0+Vl0/Vl1) + &
                                       (FlwLatAbs+FlwLatCpPot(icc))*CpFr/dt/2.d0 - FlwTopCp(icc+1)/dt) /                                    &
                                       (1.d0/dt + FlwLatAbs*CpFr/dt/(2.d0*Vl1))
                           if (id == 1) dtheta = dtheta - FlwOutDrRapCpPot(icc)/dt / (1.d0/dt + FlwLatAbs*CpFr/dt/(2.d0*Vl1))
                        else
                           dtheta    = (FlwTopCp(icc)/dt - FlwLatAbs*CpFr/dt * 0.5d0*Srel0*(1.d0+Vl0/Vl1) +                         &
                                       (FlwLatAbs+FlwLatCpPot(icc))*CpFr/dt/2.d0 - FlwTopCp(icc+1)/dt) /                            &
                                       (1.d0/dt + FlwLatAbs*CpFr/dt/(2.d0*Vl1))
                           if (id == 1) dtheta = dtheta - FlwOutDrRapCpPot(icc)/dt / (1.d0/dt + FlwLatAbs*CpFr/dt/(2.d0*Vl1))
                        end if
                        
                        Srel1 = (WaUnMpDmCpM1(id,icc) + dtheta) / Vl1
                        if (icc == ICpTpWaSrDm(id)) Srel1 = ((WaUnMpDmCpM1(id,icc) - (1.d0-CpFr)*VlMpDmCpM1(id,icc)) + dtheta) / Vl1
                        
                        if (Srel1 <= 1.d0) then
!                          No longer saturated                          
                           CorFac = 1.d0 ! Correction factor if Srel1 < 0 (i.e. negative storage at end of ts)
                           if (Srel1 < 0.d0 .AND. Srel0 > 0.d0) CorFac = Srel0*Vl0/(-Srel1*Vl1+Srel0*Vl0)

                           if (icc == ICpTpWaSrDm(id)) then
                              WaUnMpDmCp(id,icc) = (WaUnMpDmCpM1(id,icc) - (1.d0-CpFr)*VlMpDmCpM1(id,icc)) + dtheta * CorFac 
                           else 
                              WaUnMpDmCp(id,icc) = max(WaUnMpDmCpM1(id,icc) + dtheta * CorFac,0.d0)
                           end if
                           
                           SrelAvg = 0.5d0*(Srel0*(1.d0+Vl0/Vl1) + dtheta/Vl1)
                           
                           if (FlwLatAbs > 0.d0 .AND. Srel1 < 0.d0 .AND. Srel0 > 0.d0) CorFac = (-dtheta * CorFac - (FlwTopCp(icc+1)-FlwTopCp(icc))) / (FlwLatAbs*SRelAvg)

                           QInIntSatDmCp(id,icc)  = FlwInIntSatCpPot(icc) * (1.d0 - Srelavg) / dt * CorFac
                           QInMtxSatDmCp(id,icc)  = FlwInMtxSatCpPot(icc) * (1.d0 - Srelavg) / dt * CorFac
                           QOutMtxSatDmCp(id,icc) = FlwOutMtxSatDmCpPot(id,icc)   * Srelavg  / dt * CorFac
                           QOutMtxUnsDmCp(id,icc) = FlwOutMtxUnsDmCpPot(id,icc)   * Srelavg  / dt * CorFac
                           if (id == 1) QOutDrRapCp(icc) = FlwOutDrRapCpPot(icc) / dt * CorFac
                           if (icc == ICpTpWaSrDm(id)) QOutMtxSatDmCp(id,icc) = 0.d0
                           
                           kwsat  = .FALSE.
                           ThetaExc = 0.d0
                        else 
!                          Still saturated
                           SrelAvg = 0.5d0*(Srel0*(1.d0+Vl0/Vl1) + dtheta/Vl1)
                           if (SrelAvg > 1.d0) then
                              ThetaExc = -99.d0
                              Srel1    = 1.d0
                              SrelAvg  = (Srel0+Srel1)/2.d0
                           elseif (Srel1 > 1.d0) then
                              ThetaExc = (Srel1-1.d0) * Vl1
                              Srel1    = 1.d0
                           endif

                           QInIntSatDmCp(id,icc)  = FlwInIntSatCpPot(icc) * (1.d0 - Srelavg) / dt
                           QInMtxSatDmCp(id,icc)  = FlwInMtxSatCpPot(icc) * (1.d0 - Srelavg) / dt
                           QOutMtxSatDmCp(id,icc) = FlwOutMtxSatDmCpPot(id,icc)   * Srelavg  / dt 
                           QOutMtxUnsDmCp(id,icc) = FlwOutMtxUnsDmCpPot(id,icc)   * Srelavg  / dt
                           if (id == 1) QOutDrRapCp(icc) = FlwOutDrRapCpPot(icc) / dt
                           if (icc == ICpTpWaSrDm(id)) QOutMtxSatDmCp(id,icc) = 0.d0
                         
                           WaUnMpDmCp(id,icc) = Vl1
                           
                           KwSatCp(icc)       = .TRUE.
                           
                           if (ThetaExc < -98.d0) then 
                              if (icc == IcTopMp) then
                                 ThetaExc  = WaUnMpDmCpM1(id,icc) - WaUnMpDmCp(id,icc) + FlwInTopVrtDmPot(id) + FlwInTopLatDmPot(id) - FlwTopCp(icc+1) + & 
                                 (QInIntSatDmCp(id,icc) + QInMtxSatDmCp(id,icc) - QOutMtxUnsDmCp(id,icc)) * CpFr * dt - QOutMtxSatDmCp(id,icc) * dt
                                 if (id == 1) ThetaExc = ThetaExc - QOutDrRapCp(icc) * CpFr * dt
                              else if (icc == ICpTpWaSrDm(id)) then
                                 ThetaExc  = WaUnMpDmCpM1(id,icc) - (1.d0-CpFr)*VlMpDmCpM1(id,icc) - WaUnMpDmCp(id,icc) + FlwTopCp(icc) - FlwTopS + & 
                                 (QInIntSatDmCp(id,icc) + QInMtxSatDmCp(id,icc) - QOutMtxUnsDmCp(id,icc)) * CpFr * dt - QOutMtxSatDmCp(id,icc) * dt
                                 if (id == 1) ThetaExc = ThetaExc - QOutDrRapCp(icc) * CpFr * dt
                              else
                                 ThetaExc  = WaUnMpDmCpM1(id,icc) - WaUnMpDmCp(id,icc) + FlwTopCp(icc) - FlwTopCp(icc+1) +                                 & 
                                 (QInIntSatDmCp(id,icc) + QInMtxSatDmCp(id,icc) - QOutMtxUnsDmCp(id,icc) - QOutMtxSatDmCp(id,icc)) * dt
                                 if (id == 1) ThetaExc = ThetaExc - QOutDrRapCp(icc) * dt
                              end if
                           end if
                           
                           FlwTopCp(icc) = FlwTopCp(icc) - ThetaExc  
                        end if
                     end if
                                
                     ! Mass balance for debugging
                     massbal(icc) = FlwTopCp(icc) - FlwTopCp(icc+1) +                       & ! Top & bot
                                   (QInIntSatDmCp (id,icc) + QInMtxSatDmCp(id,icc)) * dt -  & ! Inflow
                                   (QOutMtxUnsDmCp(id,icc) + QOutMtxSatDmCp(id,icc)) * dt + & ! Outflow
                                   WaUnMpDmCpM1(id,icc) - WaUnMpDmCp(id,icc)                  ! Storage 
                     if (id == 1) massbal(icc) = massbal(icc) - QOutDrRapCp(icc) * dt
                     if (icc == ICpTpWaSrDm(id)) then ! Consider only unsaturated part
                        massbal(icc) = FlwTopCp(icc) - FlwTopCp(icc+1) +                                                               & ! Top & bot
                           (QInIntSatDmCp(id,icc) + QInMtxSatDmCp(id,icc) - QOutMtxUnsDmCp(id,icc)) * dt * (1.d0-FrMpWalWet(id,icc)) + & ! Unsaturated part
                           (QInIntSatS + QInMtxSatS - QOutMtxUnsS) * dt * FrMpWalWet(id,icc)  - QOutMtxSatS * dt +                     & ! Saturated part
                           WaUnMpDmCpM1(id,icc) - (WaUnMpDmCp(id,icc) + WaSat)                                                           ! Storage
                     else if (icc == ICTopMp) then
                        massbal(icc) = FlwInTopVrtDmPot(id) + FlwInTopLatDmPot(id) - ThetaExc - FlwTopCp(icc+1) + & ! Top & bot
                           (QInIntSatDmCp (id,icc) + QInMtxSatDmCp (id,icc)) * dt -                               & ! Inflow
                           (QOutMtxUnsDmCp(id,icc) + QOutMtxSatDmCp(id,icc)) * dt +                               & ! Outflow 
                           WaUnMpDmCpM1(id,icc) - WaUnMpDmCp(id,icc)                                                ! Storage
                        if (id == 1) massbal(icc) = massbal(icc) - QOutDrRapCp(icc) * dt
                     end if                   
                        
                     if (abs(massbal(icc)) > 1.d-7) then
                        continue
                     end if
                        
                     icc           = icc - 1
                  end do
                  
                  if (kwsat .AND. icc < IcTopMp) then
                     if (FlwInTopVrtDmPot(id) + FlwInTopLatDmPot(id) >= ThetaExc) then 
!                       If oversaturation occurs at top compartment, limit runoff into macropore (as this is the 'compartment' above)
                        FrFlwTopIn        = max(0.d0,1.d0 - ThetaExc / (FlwInTopVrtDmPot(id) + FlwInTopLatDmPot(id)))
                        FlwInTopExc       = ThetaExc
                        FlwTopCp(ICTopMp) = (FlwInTopVrtDmPot(id) + FlwInTopLatDmPot(id)) * FrFlwTopIn
                     else 
!                       Stop runoff into macropore AND limit inflow fluxes from matrix 
                        FrFlwTopIn        = 0.d0
                        FlwInTopExc       = FlwInTopVrtDmPot(id) + FlwInTopLatDmPot(id)
                        FlwTopCp(ICTopMp) = FlwInTopExc-ThetaExc
                        
!                       Find first unsaturated compartment below ICTopMp
                        ICUns = ICpBtDm(id) + 1
                        ichlp = ICTopMp
                        do while (ICUns > ICpBtDm(id))
                           if (.not. KWSatCp(ichlp)) ICUns = ichlp - 1
                           if (ichlp == ICpBtDm(id)) ICUns = ICpBtDm(id)
                           ichlp = ichlp + 1
                        end do
                        
                        FlwRed = 0.d0
                        FrFlwSideIn    = (sum(QInIntSatDmCp(id,ICTopMp:ICUns)) + sum(QInMtxSatDmCp(id,ICTopMp:ICUns)))*dt
                        if (FrFlwSideIn > 0.d0) then 
!                          Reduce side inflow fluxes
                           FrFlwSideIn = max(0.d0,1.d0- (ThetaExc-FlwInTopExc) / FrFlwSideIn)
                       
                           do icc = ICUns, ICTopMp, -1
                              FlwRed                = (1.d0-FrFlwSideIn) * (QInIntSatDmCp(id,icc)+QInMtxSatDmCp(id,icc))*dt + FlwRed
                              QInIntSatDmCp(id,icc) = FrFlwSideIn * QInIntSatDmCp(id,icc)
                              QInMtxSatDmCp(id,icc) = FrFlwSideIn * QInMtxSatDmCp(id,icc)
                              FlwTopCp(icc)         = FlwTopCp(icc) + FlwRed
                           end do
                        end if
                        
                        if (FlwRed + FlwInTopExc + 1.d-7 < ThetaExc) then 
!                          Excess is also a consequence of MP shrinkage; push water into top cp of matrix
                           QOutMtxUnsDmCp(id,ICTopMP) = QOutMtxUnsDmCp(id,ICTopMp) + (ThetaExc - FlwRed - FlwInTopExc)/dt
                           FrFlwSideIn                = 0.d0
                           FlwTopCp(ICTopMp)          = 0.d0
                        end if
                        
                     end if
                  end if
               else
!                 No oversaturation, store actual fluxes and MP water content
                  
!                 Correction factor if Srel1 < 0 (i.e. negative storage at end of ts)
                  CorFac = 1.d0
                  if (Srel1 < 0.d0 .AND. Srel0 > 0.d0) CorFac = Srel0*Vl0/(-Srel1*Vl1+Srel0*Vl0)

!                 Exchange fluxes and storage change
                  SRelAvg   = 0.5d0*(Srel0*(1.d0+Vl0/Vl1) + dtheta/Vl1)
                  if (ic == ICpTpWaSrDm(id) .AND. FrMpWalWet(id,ic) >= 1.d0) then
                     QInIntSatS  = FlwInIntSatCpPot(ic) * (1.d0 - Srelavg) / dt * CorFac
                     QInMtxSatS  = FlwInMtxSatCpPot(ic) * (1.d0 - Srelavg) / dt * CorFac
                     QOutMtxSatS = FlwOutMtxSatDmCpPot(id,ic)   * Srelavg  / dt * CorFac
                     QOutMtxUnsS = FlwOutMtxUnsDmCpPot(id,ic)   * Srelavg  / dt * CorFac
                     QInIntSatDmCp(id,ic)  = 0.d0
                     QInMtxSatDmCp(id,ic)  = 0.d0
                     QOutMtxSatDmCp(id,ic) = 0.d0
                     QOutMtxUnsDmCp(id,ic) = 0.d0
                  else
                     QInIntSatDmCp(id,ic)  = FlwInIntSatCpPot(ic) * (1.d0 - Srelavg) / dt * CorFac
                     QInMtxSatDmCp(id,ic)  = FlwInMtxSatCpPot(ic) * (1.d0 - Srelavg) / dt * CorFac
                     QOutMtxSatDmCp(id,ic) = FlwOutMtxSatDmCpPot(id,ic)   * Srelavg  / dt * CorFac
                     QOutMtxUnsDmCp(id,ic) = FlwOutMtxUnsDmCpPot(id,ic)   * Srelavg  / dt * CorFac
                     if (id == 1) QOutDrRapCp(ic) = FlwOutDrRapCpPot(ic) / dt * CorFac
                     if (ic == ICpTpWaSrDm(id)) QOutMtxSatDmCp(id,ic) = 0.d0
                  end if
                                                     
                  FlwTopCp(ic+1) = KsatMP * Srelavg**nkwt * DT * CorFac + FlwTopCp(ic) * (1.d0-CorFac) 
                  
                  if (ic == ICpTpWaSrDm(id)) then 
!                    Consider only unsat part
                     if (FrMpWalWet(id,ic) >= 1.d0) then
                        WaUnMpDmCp(id,ic) = 0.d0
                        WaSat             = WaUnMpDmCpM1(id,ic) + dtheta*CorFac
                        FlwTopS           = FlwTopCp(ic)
                     else
                        WaUnMpDmCp(id,ic) = (WaUnMpDmCpM1(id,ic) - FrMpWalWet(id,ic) * VlMpDmCpM1(id,ic)) + dtheta*CorFac
                        FlwTopS           = FlwTopCp(ic+1) ! Flow to top saturated part of cp
                     end if
                  else
                     WaUnMpDmCp(id,ic)    = WaUnMpDmCpM1(id,ic) + dtheta*CorFac
                  end if
               
               end if
               
!              Calculate relative saturation in formerly saturated part of cp with gwl
               if (ic == ICpTpWaSrDm(id) .AND. FrMpWalWet(id,ic) < 1.d0) then 
                  Srel0     = 1.d0
                  CpFr      = FrMpWalWet(id,ic)
                  Vl1       = VlMpDmCp(id,ic)   * CpFr
                  Vl0       = VlMpDmCpM1(id,ic) * CpFr
                  dtheta    = 1.d-6   ! Initial estimate
                  dthetaold = dtheta
                  notconv   = .TRUE.
                  iter      = 1
                  
                  FlwLatCpS = (FlwInIntSatCpPot(ic) + FlwInMtxSatCpPot(ic) - &
                               FlwOutMtxUnsDmCpPot(id,ic))*CpFr - FlwOutMtxSatDmCpPot(id,ic)
                  FlwLatAbs = abs(FlwLatCpS)

                  if (CpFr > 1.d-8) then ! Find change in theta and calculate resulting saturation
                     do while (notconv)
                        dthetaold  = dtheta
                        SRelAvg    = 0.5d0*(Srel0*(1.d0+Vl0/Vl1) + dtheta/Vl1)
                        fdtheta    = ksatMP * SRelAvg**nkwt + dtheta/dt +   &
                                     FlwLatAbs/dt*SRelAvg -                 &
                                    (FlwLatAbs + FlwLatCpS)/dt/2.d0 -       &
                                     FlwTopS/dt
                        fdthetadrv = nkwt/(Vl1*2.d0) * ksatMP * SRelAvg**(nkwt-1.d0) + &
                           FlwLatAbs/dt/(Vl1*2.d0) + 1/dt
                        dtheta = dtheta - fdtheta/fdthetadrv
                        
                        iter   = iter + 1
                        if (abs(dtheta/dt) < 1.d-9) then
                           notconv = .FALSE.
                        end if
                        if (abs(dthetaold - dtheta) < 1.d-10) notconv = .FALSE.
                        if (iter > 1000 .AND. dtheta < -VlMpDmCp(id,ic)) then
                           dtheta  = -VlMpDmCp(id,ic)
                           notconv =.FALSE.
                        end if
                     end do
                     
                     Srel1  = (CpFr * VlMpDmCpM1(id,ic) + dtheta) / Vl1
                     
                     CorFac = 1.d0
                     if (Srel1 < 0.d0 .AND. Srel0 > 0.d0) CorFac = Srel0*Vl0/(-Srel1*Vl1+Srel0*Vl0)

!                    Exchange fluxes and new storage
                     SRelAvg     = 0.5d0*(Srel0*(1.d0+Vl0/Vl1) + dtheta/Vl1)
                     QInIntSatS  = FlwInIntSatCpPot(ic) * (1.d0 - Srelavg) / dt * CorFac
                     QInMtxSatS  = FlwInMtxSatCpPot(ic) * (1.d0 - Srelavg) / dt * CorFac
                     QOutMtxSatS = FlwOutMtxSatDmCpPot(id,ic)   * Srelavg  / dt * CorFac
                     QOutMtxUnsS = FlwOutMtxUnsDmCpPot(id,ic)   * Srelavg  / dt * CorFac
                     
                     FlwTopCp(ic+1) = KsatMP * Srelavg**nkwt * DT * CorFac + FlwTopS * (1.d0-CorFac) 
                     WaSat          = VlMpDmCpM1(id,ic)*CpFr + dtheta*CorFac
                                         
                  else 
!                    No relevant saturated part of interface cp
                     WaSat       = 0.d0
                     QInIntSatS  = 0.d0
                     QInMtxSatS  = 0.d0
                     QOutMtxSatS = 0.d0
                     QOutMtxUnsS = 0.d0
                     FlwLatCpS   = 0.d0
                  end if
               end if

            end do                        
                       
!           Limit inflow at top of domain if excess at top of MP domain based on unsaturated conditions only. 
            QInTopVrtDm(id)   = FrFlwTopIn * FlwInTopVrtDmPot(id) / dt
            QInTopLatDm(id)   = FrFlwTopIn * FlwInTopLatDmPot(id) / dt
            
!           Excess inflow which cannot infiltrate into kinematic wave MP domains may be redistributed to original concept domains if available
            FlwInTopExcesTot  = FlwInTopExcesTot + FlwInTopExc
!           Excess outflow is not possible
            FlwOutDmExces(id) = 0.d0  

!           No saturation deficit calculated for kinematic wave domains, i.e. currently no redistribution to these domains possible
            SatDefDm(id)      = 0.d0
            SatDefDmRel(id)   = 0.d0
            
            ! Mass balance for debugging           
            do ic=ICTopMp,ICpBtDm(id)
               massbal(ic) = FlwTopCp(ic) - FlwTopCp(ic+1) +                        & ! Top & bot
                             (QInIntSatDmCp (id,ic) + QInMtxSatDmCp (id,ic)) * dt - & ! Lateral inflow
                             (QOutMtxUnsDmCp(id,ic) + QOutMtxSatDmCp(id,ic)) * dt + & ! Lateral outflow
                             WaUnMpDmCpM1(id,ic) - WaUnMpDmCp(id,ic)                  ! Storage change
               if (id == 1) massbal(ic) = massbal(ic) - QOutDrRapCp(ic) * dt
               if (ic == ICpTpWaSrDm(id)) then
                  massbal(ic) = FlwTopCp(ic) - FlwTopCp(ic+1) +                                                              & ! Top & bot
                     (QInIntSatDmCp(id,ic) + QInMtxSatDmCp(id,ic) - QOutMtxUnsDmCp(id,ic)) * dt * (1.d0-FrMpWalWet(id,ic)) + & ! Unsaturated part
                     (QInIntSatS + QInMtxSatS - QOutMtxUnsS)*dt*FrMpWalWet(id,ic) - QOutMtxSatS*dt +                         & ! Saturated part
                     WaUnMpDmCpM1(id,ic) - (WaUnMpDmCp(id,ic) + WaSat)                                                         ! Storage change
               end if      
               if (abs(massbal(ic)) > 1.d-7) then
                   continue
               end if
            end do

!  B.2.b    Saturated part of MP domain. 
            
!           Change in MP gwl is a function of inflow, outflow and pore volume change
!           Pore volume change in saturated domain at time t (use numnod as ICpBtDm may change over dt)
            Vl0 = VOLUNDR(ZWaLevDm(id),Z(NumNod)-0.5d0*dz(numnod),NumNod,VlMpDmCpM1(id,1:numnod))
            VL1 = VOLUNDR(ZWaLevDm(id),Z(NumNod)-0.5d0*dz(numnod),NumNod,VlMpDmCp(id,1:numnod))
            
!           Storage change in saturated domain
!           First: determine total in- or outflow in saturated MP domain at time t
            ic     = ICpTpWaSrDm(id)
            FlwSat = FlwTopCp(ic)
            if (ZwaLevDm(id) < 0.d0) FlwSat = FlwTopS
            FlwSat = FlwSat - QOutMtxSatS * dt -            &            ! Per definition already limited to saturated part of MP. For top CP, consider only calculations of sat region.
                     QOutMtxUnsS * FrMPWalWet(id,ic) * dt + &            ! Only consider saturated part of compartment
                     (QInMtxSatS + QInIntSatS) * FrMpWalWet(id,ic) * dt  ! Only consider saturated part of compartment
  
            if (ic < ICpBtDm(id)) then
               do ic = (ICpTpWaSrDm(id)+1), ICpBtDm(id)
                  FlwSat = FlwSat + FlwInMtxSatCpPot(ic) + FlwInIntSatCpPot(ic) - FlwOutMtxSatDmCpPot(id,ic) - FlwOutMtxUnsDmCpPot(id,ic)
                  if (id==1) FlwSat = FlwSat - FlwOutDrRapCpPot(ic)
               end do
            end if

!           Numerator: independent of dH_mp
            numer = FlwSat + (Vl0-Vl1)
            if (-numer > Vl1 .AND. WaSrMpDm(id) > 0.001d0) then
               fldecMPmbf = .TRUE.
            end if
                        
!           Find change in MP gwl
            notconv = .TRUE.
            MPempty = .FALSE.
            MPfull  = .FALSE.

            if (abs(numer) > 1.d-10) then ! Change in MP gwl to be expected
               if (numer > 0.d0) then     
!                 Increase in MP gwl
                  WaUnTmp(1:numnod)  = WaUnMpDmCp(id,1:numnod)
                  MPRelSat(1:numnod) = 0.d0
                  do ic = ICTopMP,ICpBtDm(id)
                     if (VlMpDmCp(id,ic) > 0.d0) MPRelSat(ic) = WaUnTmp(ic)/ VlMpDmCp(id,ic) ! Relative saturation of matrix based on unsat calculations
!                     if (ic == ICpTpWaSrDm(id) .AND. FrMpWalWet(id,ic) < 1.d0)  MPRelSat(ic) = WaUnTmp(ic)/(VlMpDmCp(id,ic)*(1.d0-FrMpWalWet(id,ic)))
!                     if (ic == ICpTpWaSrDm(id) .AND. FrMpWalWet(id,ic) == 1.d0) MPRelSat(ic) = 1.d0
                     if (ic == ICpTpWaSrDm(id)) then
                        if (FrMpWalWet(id,ic) < 1.d0) then
                           MPRelSat(ic) = WaUnTmp(ic)/(VlMpDmCp(id,ic)*(1.d0-FrMpWalWet(id,ic)))
                        else
                           MPRelSat(ic) = 1.d0
                        end if
                     end if

                  end do
                  
                  ic = ICpTpWaSrDm(id)
                  
!                 Simple solution: GWL remains in cp
                  denom  = VlMpDmCp(id,ic)*(1.d0-MPRelSat(ic)) / dz(ic)
                  zdenom = (z(ic) + 0.5d0*dz(ic)-ZWaLevDm(id))
                  
                  dH_mp = 0.d0
                  if (denom > 0.d0) then
                     dH_mp = numer / denom
                  else
                     dH_mp = zdenom + 1.d-5
                  end if

                  if (dH_mp + ZWaLevDm(id) < z(ic) + 0.5d0*dz(ic)) notconv = .FALSE. ! No need for iteration
                  
!                 Alternative: GWL moves to higher cp: requires calculation of average available pore space
                  do while (notconv .AND. ic >= ICTopMp)                    
                     if (dH_mp + ZWaLevDm(id) < z(ic) + 0.5d0*dz(ic)) then 
!                       MP gwl stays in compartment ic: find exact solution
                        dH_mp = (zdenom + zdenommax)/2.d0
                        iter = 1
                        do while (notconv)
                           dH_mpold = dH_mp
                           denommax = (denom*zdenom + VlMpDmCp(id,ic)*(1.d0-MPRelSat(ic))/dz(ic)*(dH_mp-zdenom)) / (dH_mp)
 
                           if (iter < 100000) then
                              dH_mp = numer / denommax * 0.001d0 + dH_mpold * 0.999d0
                           else
                              dH_mp = numer / denommax * 0.000001d0 + dH_mpold * 0.999999d0
                           end if
                                                      
                           if (abs(dH_mpold-dH_mp) < 1.d-9) notconv = .FALSE.
                           iter = iter + 1
                           if (iter > 10000000) then
                              notconv = .FALSE.
                              call dtdpst('year-month-day,hour:minute:seconds',t1900,datetime)
                              message = 'No convergence was reached of the change in macropore water level at '//datetime//' - SWAP did continue!'
                              call swap_warning ('macrorate', message)
                           end if
                           
                        end do
                     else
!                       MP gwl moves to compartment above
                        if (ic < ICpTpWaSrDm(id)) then
                           zdenom = zdenommax
                           denom  = denommax
                        end if
                        ic = ic - 1
                        if (ic < ICTopMP) then 
!                          Water level exceeds top of macropore!
                           dH_mp = - ZwaLevDm(id) + (z(ICTopMp) + 0.5d0*dz(ICTopMp))
                           MPfull = .TRUE.
                        else
                           zdenommax = zdenom + dz(ic)
                           denommax  = (denom*zdenom + VlMpDmCp(id,ic)*(1.d0-MPRelSat(ic))) / (dz(ic)+zdenom)
                           if (denommax > 0.d0) then
                              dH_mp = numer / denommax
                           else
                              dH_mp = zdenommax + 1.d-5
                           end if
                        end if
                     end if
                  end do
                  
               else 
!                 Decrease in MP gwl
                  WaUnTmp(1:numnod)  = WaUnMpDmCp(id,1:numnod)
                  WaUnTmp(ICpTpWaSrDm(id)) = WaSat
                  MPRelSat(1:numnod) = 0.d0
                  do ic = ICTopMP,ICpBtDm(id)
                     if (VlMpDmCp(id,ic) > 0.d0) MPRelSat(ic) = WaUnTmp(ic)/ VlMpDmCp(id,ic) ! Relative saturation of matrix based on unsat calculations
!                     if (ic == ICpTpWaSrDm(id) .AND. FrMpWalWet(id,ic) >  0.d0)  MPRelSat(ic) = WaUnTmp(ic)/(VlMpDmCp(id,ic)*FrMpWalWet(id,ic))
!                     if (ic == ICpTpWaSrDm(id) .AND. FrMpWalWet(id,ic) == 0.d0)  MPRelSat(ic) = 0.d0
                     if (ic == ICpTpWaSrDm(id)) then
                        if (FrMpWalWet(id,ic) > 0.d0) then
                           MPRelSat(ic) = WaUnTmp(ic)/(VlMpDmCp(id,ic)*FrMpWalWet(id,ic))
                        else
                           MPRelSat(ic) = 0.d0
                        end if
                     end if
                  end do
                  
                  ic = ICpTpWaSrDm(id)
                  
!                 Simple solution: GWL remains in cp
                  denom  = VlMpDmCp(id,ic)*(1.d0-MPRelSat(ic)) / dz(ic) 
                  zdenom = (z(ic) - 0.5d0*dz(ic)-ZWaLevDm(id))
                  
                  dH_mp = 0.d0
                  if (denom > 0.d0) then
                     dH_mp = numer / denom 
                  else
                     dH_mp = zdenom - 1.d-5
                  end if
                  
                  if (dH_mp + ZWaLevDm(id) > z(ic) - 0.5d0*dz(ic)) notconv = .FALSE. ! No need for iteration
                                                     
!                 Alternative: GWL moves to lower cp: requires calculation of average available pore space
                  do while (notconv .AND. ic <= ICpBtDm(id)) 
                     if (dH_mp + ZWaLevDm(id) > z(ic) - 0.5d0*dz(ic)) then 
!                       MP gwl stays in compartment ic: find exact solution
                        dH_mp = (zdenom + zdenommax)/2.d0
                        iter = 1
                        do while (notconv)
                           dH_mpold = dH_mp
                           denommax = (-denom*zdenom + VlMpDmCp(id,ic)*(1.d0-MPRelSat(ic))/dz(ic) *(-(dH_mp-zdenom))) / (-dH_mp)

                           if (iter < 100000) then
                              dH_mp = numer / denommax * 0.001d0 + dH_mpold * 0.999d0
                           else
                              dH_mp = numer / denommax * 0.000001d0 + dH_mpold * 0.999999d0
                           end if
                           
                           if (abs(dH_mpold-dH_mp) < 1.d-9) notconv = .FALSE.
                           iter = iter + 1
                           if (iter > 100000000) then ! Water balance errors may arise in bottom cp
                              notconv = .FALSE.
                              call dtdpst('year-month-day,hour:minute:seconds',t1900,datetime)
                              message = 'No convergence was reached of the change in macropore water level at '//datetime//' - SWAP did continue!'
                              call swap_warning ('macrorate', message)
                           end if
                        end do
                     else
!                       MP gwl moves to compartment below
                        if (ic > ICpTpWaSrDm(id)) then
                           zdenom = zdenommax
                           denom  = denommax
                        end if
                        ic = ic + 1
                        zdenommax = zdenom - dz(ic) ! = negative
                        denommax  = (-denom*zdenom + VlMpDmCp(id,ic)*(1.d0-MPRelSat(ic))) / (dz(ic)-zdenom)
                        if (denommax > 0.d0) then
                           dH_mp = numer / denommax
                        else
                           dH_mp = zdenommax - 1.d-5
                        end if
                        if (ic > ICpBtdm(id)) then
!                          Cannot decrease any further: no more water in MP. 
                           dH_mp = zdenommax + dz(ic)
                           MPempty = .TRUE.
                           cfdry2 = dH_mp * denommax / numer
                        end if
                     end if
                  end do
               end if
            else
               dH_mp = 0.d0
            end if
            
!           Find compartment corresponding to new MP gwl
            ic = IcTopMp
            icgwl = ic - 1
            do while (ic <= ICpBtDm(id) .AND. icgwl < ICTopMP)
               if ((Z(ic) - 0.5d0*dz(ic)) < (ZWaLevDm(id) + dH_mp)) icgwl = ic
               if (ic == ICpBtDm(id)) icgwl = ic
               ic = ic + 1
            end do
            
!           Fraction of compartment with new MP gwl which is saturated
            FrMPSat = 1.d0 - ((ZWaLevDm(id) + dH_mp) - (Z(icgwl) + 0.5d0*dz(icgwl))) / (- dz(icgwl)) 
            
!           Calculate (potential) vertical fluxes in saturated domain based on vertical distribution of fluxes.
!           From bottom of MP to top: calculate flux over saturated MP cp, calculate exchange fluxes for use in SWAP,
!           and calculate the new macropore storage. 
!           NOTE: in current approach vertical flow in saturated part is not maximized by ksat! 
            FlwTopCp(ICpBtDm(id)+1:NumNod)      = 0.d0 ! Bottom of MP is impermeable; no seepage face considered at bottom for simplicity as mostly dz >> horizontal crack area of domain
            WaUnMpDmCp(id,ICpBtDm(id)+1:NumNod) = 0.d0 ! No MP water storage below bottom of MP
            
!           Exception for bottom: if macropore has become shallower during time step, then water present in previously deeper cp flows upward through bottom.
!           No lateral exchange fluxes calculated below ICpBtDm
            if (ICpBtDm(id) < ICpBtDmM1(id)) then
               do ic = ICpBtDmM1(id), ICpBtDm(id)+1, -1
                  FlwTopCp(ic) = FlwTopCp(ic+1) - WaUnMpDmCpM1(id,ic) 
                  WaUnMpDmCp(id,ic) = 0.d0
               end do
!              If also groundwater level in previous time step was deeper than new compartment:
               if (ICpBtDm(id) < ICpTpWaSrDm(id)) then
                  WaUnsat(id) = WaUnMpDmCp(id,ic-1)
               end if
            end if          
            
!           Calculate flow and flux rates for standard situation           
            if (ICpBtDm(id) > icgwl) then
               do ic = ICpBtDm(id), (max(ICpTpWaSrDm(id),icgwl)+1), -1
!                 Flow over compartment boundary, positive downward
                  FlwTopCp(ic) = FlwTopCp(ic+1) + FlwOutMtxSatDmCpPot(id,ic) + FlwOutMtxUnsDmCpPot(id,ic) - & ! Out of compartment
                                 FlwInMtxSatCpPot(ic) - FlwInIntSatCpPot(ic) +                              & ! Into compartment
                                 VlMpDmCp(id,ic) - VlMpDmCpM1(id,ic)                                          ! Storage change
                  if (id == 1) FlwTopCp(ic) = FlwTopCp(ic) + FlwOutDrRapCpPot(ic)                             ! Out of compartment
!                 Water storage in compartment (saturated: = MP volume)
                  WaUnMpDmCp(id,ic) = VlMpDmCp(id,ic)
!                 Exchange fluxes with matrix
                  QInIntSatDmCp(id,ic)  = FlwInIntSatCpPot(ic)        / dt
                  QInMtxSatDmCp(id,ic)  = FlwInMtxSatCpPot(ic)        / dt
                  QOutMtxSatDmCp(id,ic) = FlwOutMtxSatDmCpPot(id,ic)  / dt
                  QOutMtxUnsDmCp(id,ic) = FlwOutMtxUnsDmCpPot(id,ic)  / dt
                  if (id == 1) QOutDrRapCp(ic) = FlwOutDrRapCpPot(ic) / dt
               end do
            end if
            
!           Special attention to compartment(s) with interface between saturated and unsaturated. 
            
!           Option 1: MP GWL remains in same cp as previous time step. FlwTop known from unsat calculations
            if (ICpTpWaSrDm(id) == icgwl) then        
               ic = ICpTpWaSrDm(id) 
               
               WaUnsat(id)    = 0.d0
               if (dH_mp < 0.d0) then 
                  WaUnsat(id) = WaUnMpDmCp(id,ic) + WaSat * (-dH_mp) / (dz(ic) * FrMpWalWet(id,ic))
               else if (FrMpWalWet(id,ic) < 1.d0) then
                  WaUnsat(id) = WaUnMpDmCp(id,ic) - WaUnMpDmCp(id,ic) * dH_mp / (dz(ic) * (1.d0-FrMpWalWet(id,ic)))
               end if
                              
               WaUnMpDmCp(id,ic) = VlMpDmCp(id,ic) * FrMpSat + WaUnsat(id)
               
               QOutMtxSatDmCp (id,ic) = QOutMtxSatS                                            ! Saturated zone contribution. OutMtxSat already restricted to sat. part.
               QOutMtxUnsDmCp (id,ic) = QOutMtxUnsDmCp (id,ic) * (1.d0-FrMpWalWet(id,ic)) + &  ! Unsaturated zone contribution
                                        QOutMtxUnsS * FrMpWalWet(id,ic)                        ! Saturated zone contribution
               QInIntSatDmCp (id,ic)  = QInIntSatDmCp (id,ic)  * (1.d0-FrMpWalWet(id,ic)) + &  ! Unsaturated zone contribution
                                        QInIntSatS * FrMpWalWet(id,ic)                         ! Saturated zone contribution
               QInMtxSatDmCp (id,ic)  = QInMtxSatDmCp (id,ic)  * (1.d0-FrMpWalWet(id,ic)) + &  ! Unsaturated zone contribution
                                        QInMtxSatS * FrMpWalWet(id,ic)                         ! Saturated zone contribution
               if (id == 1) QOutDrRapCp (ic) = 0.d0                                            ! Not considered in cp with initial gwl for simplicity

!           Option 2: MP GWL has moved upward in soil
            else if (ICpTpWaSrDm(id) > icgwl) then 
               do ic = ICpTpWaSrDm(id), icgwl, -1
                   
                  if (ic == 55) then
                     continue
                  end if
                  
                  if (ic == ICpTpWaSrDm(id)) then ! Partly saturated to completely saturated
                     QOutMtxSatDmCp(id,ic) = QOutMtxSatS 
                     QOutMtxUnsDmCp(id,ic) = QOutMtxUnsDmCp(id,ic) * (1.d0-FrMpWalWet(id,ic)) + QOutMtxUnsS * FrMpWalWet(id,ic) 
                     QInIntSatDmCp (id,ic) = QInIntSatDmCp (id,ic) * (1.d0-FrMpWalWet(id,ic)) + QInIntSatS  * FrMpWalWet(id,ic) 
                     QInMtxSatDmCp (id,ic) = QInMtxSatDmCp (id,ic) * (1.d0-FrMpWalWet(id,ic)) + QInMtxSatS  * FrMpWalWet(id,ic) 
                     if (id == 1) QOutDrRapCp (ic) = 0.d0
                     
                     FlwTopCp(ic) = FlwTopCp(ic+1) + (QOutMtxSatDmCp(id,ic) + QOutMtxUnsDmCp(id,ic) - & ! Out of compartment
                                    QInIntSatDmCp(id,ic) - QInMtxSatDmCp(id,ic)) * dt +               & ! Into compartment
                                    (VlMpDmCp(id,ic) - WaUnMpDmCpM1(id,ic))                             ! Storage change in saturated AND unsaturated part as compartment becomes saturated
                     
                     WaUnMpDmCp(id,ic) = VlMpDmCp(id,ic) ! CP becomes saturated
                     
                  else if (ic > icgwl) then ! Completely unsaturated to completely saturated. Q known from unsat calculations
                     FlwTopCp(ic) = FlwTopCp(ic+1) + (QOutMtxSatDmCp(id,ic) + QOutMtxUnsDmCp(id,ic) - & ! Out of compartment
                                    QInIntSatDmCp(id,ic) - QInMtxSatDmCp(id,ic)) * dt +               & ! Into compartment
                                    (VlMpDmCp(id,ic) - WaUnMpDmCpM1(id,ic))                             ! Storage change in unsaturated part over time
                     
                     WaUnMpDmCp(id,ic) = VlMpDmCp(id,ic) ! CP becomes saturated
                     
                  else ! Completely unsaturated to partially saturated. FlwTop and Q known from unsat calculations
                     if (ICpBtDm(id) < ICpBtDmM1(id)) then
                        FrMpSat = 0.d0
                     end if
                     WaUnsat(id) = WaUnMpDmCp(id,ic) * (1.d0 - FrMpSat)
                      
                     WaUnMpDmCp(id,ic) = VlMpDmCp(id,ic) * FrMPSat + WaUnsat(id)
                     
                  end if
               end do
               
!           Option 3: MP GWL has moved downward in soil               
            else if (.NOT. MPempty) then
               do ic = ICpTpWaSrDm(id), icgwl 

                  if (ic == ICpTpWaSrDm(id)) then ! Partly saturated to completely unsaturated

                     QOutMtxSatDmCp (id,ic) = QOutMtxSatS
                     QOutMtxUnsDmCp (id,ic) = QOutMtxUnsDmCp (id,ic) * (1.d0-FrMpWalWet(id,ic)) + QOutMtxUnsS * FrMpWalWet(id,ic)
                     QInIntSatDmCp (id,ic)  = QInIntSatDmCp (id,ic)  * (1.d0-FrMpWalWet(id,ic)) + QInIntSatS  * FrMpWalWet(id,ic) 
                     QInMtxSatDmCp (id,ic)  = QInMtxSatDmCp (id,ic)  * (1.d0-FrMpWalWet(id,ic)) + QInMtxSatS  * FrMpWalWet(id,ic)
                     if (id == 1) QOutDrRapCp (ic) = 0.d0
                     
                     WaUnMpDmCp(id,ic) = WaUnMpDmCp(id,ic) + WaSat
                  
                     FlwTopCp(ic+1) = FlwTopCp(ic) + &
                                      (QInIntSatDmCp(id,ic) + QInMtxSatDmCp(id,ic) - QOutMtxSatDmCp(id,ic) - QOutMtxUnsDmCp(id,ic)) * dt + &
                                      WaUnMpDmCpM1(id,ic) - WaUnMpDmCp(id,ic)
                     
                  else if (ic < icgwl) then ! Completely saturated to completely unsaturated
                     QInIntSatDmCp(id,ic)  = FlwInIntSatCpPot(ic)       / dt
                     QInMtxSatDmCp(id,ic)  = FlwInMtxSatCpPot(ic)       / dt
                     QOutMtxSatDmCp(id,ic) = FlwOutMtxSatDmCpPot(id,ic) / dt 
                     QOutMtxUnsDmCp(id,ic) = FlwOutMtxUnsDmCpPot(id,ic) / dt
                     if (id == 1) QOutDrRapCp(ic) = FlwOutDrRapCpPot(ic) / dt
                     
                     ! WaUnMpDmCp(id,ic) = based on unsat calculations, may be altered if too much water in lowest cp (next else). 
                     
                     FlwTopCp(ic+1) = FlwTopCp(ic) + &
                                      (QInIntSatDmCp(id,ic) + QInMtxSatDmCp(id,ic) - QOutMtxSatDmCp(id,ic) - QOutMtxUnsDmCp(id,ic)) * dt + &
                                      WaUnMpDmCpM1(id,ic) - WaUnMpDmCp(id,ic)
                     if (id == 1) FlwTopCp(ic+1) = FlwTopCp(ic+1) - QOutDrRapCp(ic) * dt
                     
                  else ! Completely saturated to partially saturated
                     QInIntSatDmCp(id,ic)  = FlwInIntSatCpPot(ic)       / dt 
                     QInMtxSatDmCp(id,ic)  = FlwInMtxSatCpPot(ic)       / dt 
                     QOutMtxSatDmCp(id,ic) = FlwOutMtxSatDmCpPot(id,ic) / dt 
                     QOutMtxUnsDmCp(id,ic) = FlwOutMtxUnsDmCpPot(id,ic) / dt
                     if (id == 1) QOutDrRapCp(ic) = FlwOutDrRapCpPot(ic) / dt
                     
                     WaUnMpDmCp(id,ic) = FlwTopCp(ic) - FlwTopCp(ic+1) + &
                                         (QInIntSatDmCp(id,ic) + QInMtxSatDmCp(id,ic) - QOutMtxSatDmCp(id,ic) - QOutMtxUnsDmCp(id,ic)) * dt + &
                                         WaUnMpDmCpM1(id,ic)
                     if (id == 1) WaUnMpDmCp(id,ic) = WaUnMpDmCp(id,ic) - QOutDrRapCp(ic) * dt
                     
                     if (WaUnMpDmCp(id,ic) > VlMpDmCp(id,ic)) then ! Debug; can this actually happen? Oversaturation pushed to cp above.
                        WaUnMpDmCp(id,ic-1) = WaUnMpDmCp(id,ic-1) + WaUnMpDmCp(id,ic) - VlMpDmCp(id,ic)
                     end if
                     
                     WaUnsat(id) = WaUnMpDmCp(id,ic) - FrMpSat * VlMpDmCp(id,ic)
                     
                  end if
               end do
            
!           Option 4: MP runs dry
            else if (MPempty) then
               if (ICpTpWaSrDm(id) == ICpBtDm(id)) then ! Remains in cp. DC: Should actually not be necessary I guess.
      
                  ! Correction factor to limit fluxes to ensure non-negative water contents
                  cfdry = min(1.d0,Vl0 / ((QOutMtxSatS*cfdry2 + (QOutMtxUnsS*cfdry2 - QInMtxSatS - QInIntSatS)* FrMpWalWet(id,ic))*dt))
                  
                  WaUnsat(id) = WaUnMpDmCp(id,ic) + WaSat * (-dH_mp) / (dz(ic) * FrMpWalWet(id,ic))
                       
                  QOutMtxSatDmCp (id,ic) = QOutMtxSatDmCp (id,ic) * (1.d0-FrMpWalWet(id,ic)) + QOutMtxSatS * cfdry*cfdry2
                  QOutMtxUnsDmCp (id,ic) = QOutMtxUnsDmCp (id,ic) * (1.d0-FrMpWalWet(id,ic)) + QOutMtxUnsS * FrMpWalWet(id,ic) * cfdry*cfdry2
                  QInIntSatDmCp (id,ic)  = QInIntSatDmCp (id,ic)  * (1.d0-FrMpWalWet(id,ic)) + QInIntSatS  * FrMpWalWet(id,ic) * cfdry
                  QInMtxSatDmCp (id,ic)  = QInMtxSatDmCp (id,ic)  * (1.d0-FrMpWalWet(id,ic)) + QInMtxSatS  * FrMpWalWet(id,ic) * cfdry

                  WaUnMpDmCp(id,ic) = VlMpDmCp(id,ic) * FrMpSat + WaUnsat(id) ! = WaUnsat as FrMpSat = 0
                  
               else ! Moves to lower cp. May occur with dynamic bottom depth.
                  do ic = ICpTpWaSrDm(id), icgwl
                     if (ic == ICpTpWaSrDm(id)) then ! Partly saturated to completely unsaturated
                        FlwSat =  (QOutMtxSatS + (QOutMtxUnsS - QInMtxSatS - QInIntSatS)* FrMpWalWet(id,ic)) * dt
                        
                        cfdry = 0.d0
                        if (FlwSat > 0.d0) cfdry  = min(1.d0,Vl0 / FlwSat)

                        FlwSat = FlwSat * cfdry*cfdry2
                        
                        QOutMtxSatDmCp (id,ic) = QOutMtxSatDmCp (id,ic) * (1.d0-FrMpWalWet(id,ic)) + QOutMtxSatS * cfdry*cfdry2
                        QOutMtxUnsDmCp (id,ic) = QOutMtxUnsDmCp (id,ic) * (1.d0-FrMpWalWet(id,ic)) + QOutMtxUnsS * FrMpWalWet(id,ic) * cfdry*cfdry2
                        QInIntSatDmCp (id,ic)  = QInIntSatDmCp (id,ic)  * (1.d0-FrMpWalWet(id,ic)) + QInIntSatS  * FrMpWalWet(id,ic) * cfdry
                        QInMtxSatDmCp (id,ic)  = QInMtxSatDmCp (id,ic)  * (1.d0-FrMpWalWet(id,ic)) + QInMtxSatS  * FrMpWalWet(id,ic) * cfdry
                        if (id == 1) QOutDrRapCp(ic) = 0.d0

                        WaUnMpDmCp(id,ic) = WaUnMpDmCp(id,ic) + WaSat
                  
                        FlwTopCp(ic+1) = FlwTopCp(ic) + &
                                         (QInIntSatDmCp(id,ic) + QInMtxSatDmCp(id,ic) - QOutMtxSatDmCp(id,ic) - QOutMtxUnsDmCp(id,ic) ) * dt + &
                                         WaUnMpDmCpM1(id,ic) - WaUnMpDmCp(id,ic)
                     
                     else if (ic < icgwl) then ! Completely saturated to completely unsaturated
                        if (cfdry < 1.d0) then
                           cfdry = 0.d0
                        else
                           FlwSatNew = FlwSat - FlwInIntSatCpPot(ic) - FlwInMtxSatCpPot(ic) + FlwOutMtxSatDmCpPot(id,ic) + FlwOutMtxUnsDmCpPot(id,ic)
                           if (FlwSatNew > Vl0) cfdry = (Vl0-FlwSat) / (FlwSatNew-FlwSat)
                           FlwSat = FlwSat + (FlwSatNew-FlwSat)*cfdry*cfdry2
                        end if
                                                
                        QInIntSatDmCp(id,ic)  = FlwInIntSatCpPot(ic)       / dt * cfdry*cfdry2
                        QInMtxSatDmCp(id,ic)  = FlwInMtxSatCpPot(ic)       / dt * cfdry*cfdry2
                        QOutMtxSatDmCp(id,ic) = FlwOutMtxSatDmCpPot(id,ic) / dt * cfdry
                        QOutMtxUnsDmCp(id,ic) = FlwOutMtxUnsDmCpPot(id,ic) / dt * cfdry
                        if (id == 1) QOutDrRapCp(ic) = FlwOutDrRapCpPot(ic) / dt* cfdry*cfdry2
                     
                        ! WaUnMpDmCp(id,ic) = based on unsat calculations, may be altered if too much water in lowest cp (next else). 
                     
                        FlwTopCp(ic+1) = FlwTopCp(ic) + &
                                         (QInIntSatDmCp(id,ic) + QInMtxSatDmCp(id,ic) - QOutMtxSatDmCp(id,ic) - QOutMtxUnsDmCp(id,ic) ) * dt + &
                                         WaUnMpDmCpM1(id,ic) - WaUnMpDmCp(id,ic)
                        if (id == 1) FlwTopCp(ic+1) = FlwTopCp(ic+1) - QOutDrRapCp(ic) * dt
                        
                     else ! Completely saturated to partially saturated
                        if (cfdry < 1.d0) then
                           cfdry = 0.d0
                        else
                           FlwSatNew = FlwSat - FlwInIntSatCpPot(ic) - FlwInMtxSatCpPot(ic) + FlwOutMtxSatDmCpPot(id,ic) + FlwOutMtxUnsDmCpPot(id,ic)
                           if (FlwSatNew > Vl0) cfdry = (Vl0-FlwSat) / (FlwSatNew-FlwSat)
                           FlwSat = FlwSat + (FlwSatNew-FlwSat)*cfdry*cfdry2
                        end if
                        
                        QInIntSatDmCp(id,ic)  = FlwInIntSatCpPot(ic)       / dt * cfdry*cfdry2
                        QInMtxSatDmCp(id,ic)  = FlwInMtxSatCpPot(ic)       / dt * cfdry*cfdry2
                        QOutMtxSatDmCp(id,ic) = FlwOutMtxSatDmCpPot(id,ic) / dt * cfdry
                        QOutMtxUnsDmCp(id,ic) = FlwOutMtxUnsDmCpPot(id,ic) / dt * cfdry
                        if (id == 1) QOutDrRapCp(ic) = FlwOutDrRapCpPot(ic) / dt* cfdry*cfdry2
                     
                        WaUnMpDmCp(id,ic) = FlwTopCp(ic) - FlwTopCp(ic+1) + &
                                            (QInIntSatDmCp(id,ic) + QInMtxSatDmCp(id,ic) - QOutMtxSatDmCp(id,ic) - QOutMtxUnsDmCp(id,ic) ) * dt + &
                                            WaUnMpDmCpM1(id,ic)
                        if (id == 1) WaUnMpDmCp(id,ic) = WaUnMpDmCp(id,ic) - QOutDrRapCp(ic) * dt
                                          
                        WaUnsat(id) = WaUnMpDmCp(id,ic) - FrMpSat * VlMpDmCp(id,ic)
                     end if
                  end do
               end if
            end if 
            
!           If MP is full, limit inflow
            if (MPfull) then
               ThetaExc = FlwTopCp(ICTopMp) - (                                                   & ! Initial inflow top
                          VlMpDmCp(id,ICTopMp) - WaUnMpDmCpM1(id,ICTopMp) + FlwTopCp(ICTopMp+1) - & ! Storage change & bot flux
                          (QInIntSatDmCp(id,ICTopMp) + QInMtxSatDmCp(id,ICTopMp) -                & ! Lat in
                          QOutMtxUnsDmCp(id,ICTopMp) - QOutMtxSatDmCp(id,ICTopMp)) * dt)            ! Lat out
               if (id == 1) ThetaExc = ThetaExc - QOutDrRapCp(ICTopMp) * dt              
               
               if (FlwTopCp(ICTopMp) > ThetaExc) then 
!                 Reduce only top inflow
                  FlwInTopExc = FlwInTopExc + ThetaExc
                  FrFlwTopIn  = dmax1(0.d0,1.d0 - FlwInTopExc / (FlwInTopVrtDmPot(id) + FlwInTopLatDmPot(id)))
            
!                 Excess inflow which cannot infiltrate into kinematic wave MP domains may be redistributed to original concept domains if available
                  FlwInTopExcesTot = FlwInTopExcesTot + ThetaExc
                  FlwInTopExcesTot = (1.d0-FrFlwTopIn) * (FlwInTopVrtDmPot(id) + FlwInTopLatDmPot(id))
               else 
!                 Reduce top inflow AND side inflow
                  FrFlwTopIn     = 0.d0
                  FlwInTopExc    = FlwInTopVrtDmPot(id) + FlwInTopLatDmPot(id)
                  
                  FrFlwSideIn    = (sum(QInIntSatDmCp(id,ICTopMp:ICpBtDm(id))) + sum(QInMtxSatDmCp(id,ICTopMp:ICpBtDm(id))))*dt
                  if (FrFlwSideIn > 0.d0) FrFlwSideIn = max(0.d0,1.d0-(ThetaExc-FlwTopCp(ICTopMp)) / FrFlwSideIn)
                  
                  FlwInTopExcesTot = FlwInTopExc 
               end if
               
               FlwTopCp(ICTopMp) = FrFlwTopIn * (FlwInTopVrtDmPot(id) + FlwInTopLatDmPot(id))
               QInTopVrtDm(id)   = FrFlwTopIn * FlwInTopVrtDmPot(id) / dt
               QInTopLatDm(id)   = FrFlwTopIn * FlwInTopLatDmPot(id) / dt
               FlwRed = 0.d0
               
               if (FrFlwSideIn < 1.d0) then
                  do ic = ICpBtDm(id), ICTopMp, -1
                     FlwRed               = FlwRed + (1.d0-FrFlwSideIn) * (QInIntSatDmCp(id,ic)+QInMtxSatDmCp(id,ic))*dt
                     QInIntSatDmCp(id,ic) = FrFlwSideIn * QInIntSatDmCp(id,ic)
                     QInMtxSatDmCp(id,ic) = FrFlwSideIn * QInMtxSatDmCp(id,ic)
                     FlwTopCp(ic)         = FlwTopCp(ic) + FlwRed
                  end do
                  FlwTopCp(ICTopMp) = 0.d0
               end if
               
               if (FlwRed + FlwInTopExc + 1.d-7 < ThetaExc) then 
!                 Excess is also a consequence of MP shrinkage; push water into top cp of matrix
                  QOutMtxUnsDmCp(id,ICTopMP) = QOutMtxUnsDmCp(id,ICTopMp) + (ThetaExc - FlwRed - FlwInTopExc)/dt
                  FrFlwSideIn                = 0.d0
                  FlwTopCp(ICTopMp)          = 0.d0
               end if
            end if
                       
            ! Mass balance for debugging
            do ic=ICTopMp,ICpBtDm(id)
               massbal(ic) = FlwTopCp(ic) - FlwTopCp(ic+1) +                       & ! Top & bot
                             (QInIntSatDmCp(id,ic) + QInMtxSatDmCp(id,ic) -        & ! Lat in
                             QOutMtxUnsDmCp(id,ic) - QOutMtxSatDmCp(id,ic)) * dt - & ! Lat out
                             WaUnMpDmCp(id,ic) + WaUnMpDmCpM1(id,ic)                 ! Storage change
               if (id == 1) massbal(ic) = massbal(ic) - QOutDrRapCp(ic) * dt
               if (abs(massbal(ic)) > 1.d-6) then
                   continue
               end if
               
            end do
            
!           Calculate top flux rate           
            QTopMpDmCp(id,1:numnod) = FlwTopCp(1:numnod) / dt
            
            ! Make sure to avoid small negative water storage
            do ic = ICTopMp, ICpBtDm(id)
               if (WaUnMpDmCp(id,ic) < 1.d-10) WaUnMpDmCp(id,ic) = 0.d0
            end do
         end if
      end do

!     End of loop domains


!     Redistribute excess over available volume of domains that are not filled up yet
      if (swmbf == 1 .OR. (swmbf == 2 .AND. numdm > 1)) then
         if (FlwInTopExcesTot > 1.d-6 .AND. SatDefTot > 1.d-6) then        ! action is needed and additional storage is available
!           Put relative saturation deficit SatDefDmRel(id) in ascending order
            do id = 1, NumDm
               Sq(id) = id
            end do
            do id = 1, NumDm-1
               do jd = id+1, NumDm
                  if (SatDefDmRel(Sq(id)) > SatDefDmRel(Sq(jd))) then
                     SqHlp  = Sq(id)
                     Sq(id) = SQ(jd)
                     Sq(jd) = SqHlp
                  end if
               end do
            end do

!           Redistribute excess 
            PpTot = 1.d0
            do id = 1, NumDm
               jd = Sq(id)
               if (SatDefDm(jd) > 1.d-7 .AND. FlwInTopVrtDmPot(jd)+FlwInTopLatDmPot(jd) > 1.d-7) then
                  Pp                = PpDmCp(jd,IcTopMp) / PpTot
                  FlwInTopXtr       = dmin1(Pp*FlwInTopExcesTot,SatDefDm(jd))
                  FrXtr             = FlwInTopXtr / (FlwInTopVrtDmPot(jd) + FlwInTopLatDmPot(jd))
                  QInTopVrtDm(jd)   = (1.d0+FrXtr) * FlwInTopVrtDmPot(jd) / dt
                  QInTopLatDm(jd)   = (1.d0+FrXtr) * FlwInTopLatDmPot(jd) / dt

                  FlwInTopExcesTot = FlwInTopExcesTot - FlwInTopXtr
                  FlwOutDmExces(jd) = FlwOutDmExces(jd) - FlwInTopXtr
                  FlwOutDmExces(jd) = dmax1(0.d0,FlwOutDmExces(jd))
                  SatDefDm(jd)      = SatDefDm(jd) - FlwInTopXtr
               else
                  SatDefDm(jd)      = 0.d0
               end if
               PpTot                = PpTot - PpDmCp(jd,IcTopMp)
            end do
         end if
         
!        Calculate actual outgoing fluxes on basis of (possibly) outflow excess
         do id = 1, NumDm
            FrFlwOut       = 1.d0
            if (FlwOutDmExces(id)/DT > 1.d-7) then
                  if (FlwOutDmTot(id) > FlwOutDmExces(id)) then
                  FrFlwOut = 1.d0 - FlwOutDmExces(id)/FlwOutDmTot(id)
                  FrFlwOut = dmax1(0.d0,FrFlwOut)
               else
                  FrFlwOut = 0.d0
               end if
            end if 
            if(target.and.id==3) call limit21_trace(2)
            if (swmbf == 1 .OR. (swmbf == 2 .AND. id > 1)) then
               QOutMtxSatDmCp(id,IcTopMp:NumNod) = FrFlwOut * FlwOutMtxSatDmCpPot(id,IcTopMp:NumNod)  / dt
               QOutMtxUnsDmCp(id,IcTopMp:NumNod) = FrFlwOut * FlwOutMtxUnsDmCpPot(id,IcTopMp:NumNod)  / dt
               if (id == 1) QOutDrRapCp(IcTopMp:NumNod) = FrFlwOut * FlwOutDrRapCpPot(IcTopMp:NumNod) / dt
            end if
            if(target.and.id==3) call limit21_trace(3)
            if(apply37) then
             canonical37(16,id)=FrFlwOut
             canonical37(17,id)=FlwOutDmExces(id)
             canonical37(22,id)=FlwInTopExcesTot
            end if
            if(detail33) then
             obs36_meta(16,id)=FrFlwOut
             obs36_meta(17,id)=FlwOutDmExces(id)
             obs36_meta(22,id)=FlwInTopExcesTot
            end if

         end do
      end if

!     Remaining inflow excess is substracted from lateral inflow into macropores 
!     for use in main SWAP
      if (IcTopMp == 1) then
         QMpLatSs = QMpLatSs - FlwInTopExcesTot 
         if (dabs(QMpLatSs) < 1.0d-7) QMpLatSs = 0.0d0
!            QInTopLatDm(1:NumDm) = QInTopLatDm(1:NumDm) - FlwInTopExcesTot / dt * ArMpTpDm(1:NumDm)/ArMpTp
      else
         if (FlwInTopExcesTot > 1.d-7) then
            call swap_error ('Macrorate', 'FlwInTopExces with top MP below soil surface')
         end if
      end if

! - C. CALCULATE FLUXES FOR USE IN SWAP
!
!     Aggregate fluxes for output
      do id = 1, NumDm
         do ic= IcTopMp, ICpBtDm(id)
            QExcMtxDmCp(id,ic) = QOutMtxSatDmCp(id,ic) + QOutMtxUnsDmCp(id,ic) - &
                                 (QInIntSatDmCp(id,ic) + QInMtxSatDmCp(id,ic))
         end do
 !
         if (IcTopMp > 1) then
            ic = IcTopMp - 1
            QInMtxSatDmCp(id,ic) =  QInTopVrtDm(id) 
            QExcMtxDmCp(id,ic)   = -QInMtxSatDmCp(id,ic)
         end if
      end do

!     Aggregate fluxes for main SWAP
      do ic = 1, NumNod
         QExcMpMtx(ic) = QExcMpMtx(ic) + sum(QExcMtxDmCp(1:NumDm,ic))
         QMapo         = QMapo + QExcMpMtx(ic)
         QRapDra       = QRapDra + QOutDrRapCp(ic)
      end do
!
      if(apply37) then
       head37(1:numnod)=h(1:numnod)
       time37=t1900;dt37=dt;task37=ITask;attempt37=attempts;iteration37=iter_index
       ready37=.true.
      end if
      call reference48_seal(ITask)
      if (ITask == 1) return
!              ------------- END of ITask 1 -------------

!- D. CALCULATE DERIVATIVES FOR USE IN SWAP (Headcalc)
!
!     Exchange with unsaturated matrix
      do id = 1, NumDm
         call ABSORPTION(2,id,FlwOutMtxUnsDmCpPot,FlwOutMtxUnsDmPot)
      end do
!
!     Exchange with saturated matrix
      do id = 1, NumDm
         call SATFLOW(4,id,NumNod,ICpTpSatZon,GwlFlCpZo,                             &
                      ICpTpWaSrDm(id),FrMpWalWet(id,ICpTpWaSrDm(id)),ZWaLevDm(id), &
                      FlwInMtxSatCpPot,FlwInMtxSatDmPot,FlwOutMtxSatDmCpPot,FlwOutMtxSatDmPot)
      end do

      return

      return
      entry jac37_get(get37_meta,get37_potential,get37_valid)
      get37_meta=canonical37
      get37_potential(:,1)=FlwOutMtxSatDmCpPot(2,:)
      get37_potential(:,2)=FlwOutMtxSatDmCpPot(3,:)
      get37_valid=0d0
      if(ready37.and.task37==2.and.time37==t1900.and.dt37==dt.and.attempt37==attempts.and.iteration37==iter_index) then
       if(all(head37(1:numnod)==h(1:numnod))) get37_valid=1d0
      end if
      return
      entry contract42_cache_io(snap23_unit,snap23_mode)
      if(snap23_mode==1) then
       write(snap23_unit) canonical37,head37,time37,dt37,task37,attempt37,iteration37,ready37
       write(snap23_unit) obs36_meta,obs36_in,obs36_outsat,obs36_outuns,obs36_rapid
      else
       read(snap23_unit) canonical37,head37,time37,dt37,task37,attempt37,iteration37,ready37
       read(snap23_unit) obs36_meta,obs36_in,obs36_outsat,obs36_outuns,obs36_rapid
      end if
      return
      entry clock45_rate_get(get45_meta,get45_pot,get45_stamp)
      get45_meta=canonical37(:,3)
      get45_pot=[FlwOutMtxUnsDmCpPot(3,50),FlwOutMtxSatDmCpPot(3,50)]
      get45_stamp=[time37,dt37,dble(task37),dble(attempt37),dble(iteration37), &
       merge(1d0,0d0,ready37),merge(1d0,0d0,all(head37(1:numnod)==h(1:numnod)))]
      return
      entry jac37_invalidate()
      ready37=.false.
      return
      entry diagnose36_get(get36_meta,get36_in,get36_outsat,get36_outuns,get36_rapid)
      get36_meta=obs36_meta
      get36_in=obs36_in
      get36_outsat=obs36_outsat
      get36_outuns=obs36_outuns
      get36_rapid=obs36_rapid
      return
      entry diagnose35_get(pot35,info35)
      pot35=0d0
      pot35(1:numnod)=FlwOutMtxSatDmCpPot(3,1:numnod)
      info35=[lim_in,FlwOutDmTot(3),FlwOutDmExces(3),lim_min,WaSrMpDm(3),GwlFlCpZo, &
       dble(ICpTpSatZon),lim_frin,FlwInTopExcesTot,FlwOutMtxUnsDmPot(3), &
       VlMpDmCp(3,ICpTpSatZon)/dz(ICpTpSatZon),dt]
      return
      entry jac24_terms(n24,u24,v24,d24,meta24)
      u24=0d0;v24=0d0;d24=0d0;meta24=0d0
      if(n24/=numnod.or.swmbf/=1) return
      if(lim_in/=0d0.or.lim_frin/=1d0.or.FlwInTopExcesTot/=0d0) return
      if(FlwOutMtxUnsDmPot(3)/=0d0.or.FlwOutDmTot(3)<=0d0) return
      if(lim_min>=WaSrMpDm(3)) return
      if(FlwOutDmExces(3)/dt<=1d-7.or.FlwOutDmTot(3)<=FlwOutDmExces(3)) return
      j24=numnod
      do while(j24>1)
       if(h(j24)<0d0) exit
       j24=j24-1
      end do
      if(j24/=50.or.h(j24+1)<=0d0.or.ICpTpSatZon/=50) return
      den24=h(j24+1)-h(j24)
      g24=z(j24+1)+h(j24+1)/den24*(z(j24)-z(j24+1))
      if(abs(g24-GwlFlCpZo)>1d-9) error stop 'JAC24 outside selected GWL interpolation'
      f24=max(0d0,1d0-FlwOutDmExces(3)/FlwOutDmTot(3))
      rho24=VlMpDmCp(3,ICpTpSatZon)/dz(ICpTpSatZon)
      do l24=1,numnod
       u24(l24)=-FlwOutMtxSatDmCpPot(3,l24)/dt
       if(FlwOutMtxSatDmCpPot(3,l24)>0d0) then
        hm24=max(0d0,ZWaLevDm(3)-z(l24))
        dh24=hm24-h(l24)
        if(dh24<=0d0) error stop 'JAC24 outgoing potential head contract'
        d24(l24)=-FlwOutMtxSatDmCpPot(3,l24)/dh24
       end if
      end do
      v24=-f24*d24/FlwOutDmTot(3)
      v24(j24)=v24(j24)-rho24/FlwOutDmTot(3)*(z(j24)-z(j24+1))*h(j24+1)/den24**2
      v24(j24+1)=v24(j24+1)+rho24/FlwOutDmTot(3)*(z(j24)-z(j24+1))*h(j24)/den24**2
      d24=f24*d24/dt
      meta24=[1d0,FlwOutDmTot(3),FlwOutDmExces(3),f24,rho24,GwlFlCpZo,lim_min, &
              WaSrMpDm(3),dble(j24),h(j24),h(j24+1),dt]
      return
      entry sense23_rate_io(snap23_unit,snap23_mode)
      if(snap23_mode==1) then
      write(snap23_unit) ic,id,jd,SqHlp,Sq,icc
      write(snap23_unit) icgwl,icuns,ichlp,iter,CritHtop,FrFlwIn
      write(snap23_unit) FrFlwOut,FlwInDmExces,FlwInIntSatDmPot,FlwInMtxSatDmPot,FlwInTopLatDmPot,FlwInTopVrtDmPot
      write(snap23_unit) FlwOutMtxUnsDmPot,FlwOutMtxSatDmPot,FlwOutDmExces,FlwOutDmTot,FlwInIntSatCpPot,FlwInMtxSatCpPot
      write(snap23_unit) FlwOutDrRapCpPot,FlwOutMtxUnsDmCpPot,FlwOutMtxSatDmCpPot,FlwInDmTot,FlwInTopExcesTot,FlwInTopPot
      write(snap23_unit) FlwInTopXtr,FlwOutDrRapPot,SatDefDm,SatDefDmRel,FrXtr,Pp
      write(snap23_unit) PpTot,SatDefTot,VlMpUndrDrL,VlMpUndrGwL,WaSrMpDmMax,WaSrMpDmMin
      write(snap23_unit) WaSrMpDmTmp,Ld,r0,w_geom,Henpr1,lim_min
      write(snap23_unit) lim_max,lim_under,lim_in,lim_out,lim_tmp,lim_frin
      write(snap23_unit) lim_excess,lim_nodein,ThetaExc,FlwInTopExc,FrFlwTopIn,FrFlwSideIn
      write(snap23_unit) FlwRed,FlwTopCp,FlwLatCpPot,FlwLatAbs,FlwSat,FlwSatNew
      write(snap23_unit) QInIntSatS,QInMtxSatS,QOutMtxSatS,QOutMtxUnsS,FlwTopS,FlwLatCpS
      write(snap23_unit) WaSat,SRel0,SRel1,Srelavg,Vl0,Vl1
      write(snap23_unit) FrMpSat,CpFr,MPRelSat,WaUnTmp,dtheta,dthetaold
      write(snap23_unit) fdtheta,fdthetadrv,KSatMP,RapDraRes,dH_MPOld,dH_MP
      write(snap23_unit) zdenom,denommax,zdenommax,denom,numer,CorFac
      write(snap23_unit) cfdry,cfdry2,massbal,kwsat,notconv,MPempty
      write(snap23_unit) MPfull,KwSatCp
      else
      read(snap23_unit) ic,id,jd,SqHlp,Sq,icc
      read(snap23_unit) icgwl,icuns,ichlp,iter,CritHtop,FrFlwIn
      read(snap23_unit) FrFlwOut,FlwInDmExces,FlwInIntSatDmPot,FlwInMtxSatDmPot,FlwInTopLatDmPot,FlwInTopVrtDmPot
      read(snap23_unit) FlwOutMtxUnsDmPot,FlwOutMtxSatDmPot,FlwOutDmExces,FlwOutDmTot,FlwInIntSatCpPot,FlwInMtxSatCpPot
      read(snap23_unit) FlwOutDrRapCpPot,FlwOutMtxUnsDmCpPot,FlwOutMtxSatDmCpPot,FlwInDmTot,FlwInTopExcesTot,FlwInTopPot
      read(snap23_unit) FlwInTopXtr,FlwOutDrRapPot,SatDefDm,SatDefDmRel,FrXtr,Pp
      read(snap23_unit) PpTot,SatDefTot,VlMpUndrDrL,VlMpUndrGwL,WaSrMpDmMax,WaSrMpDmMin
      read(snap23_unit) WaSrMpDmTmp,Ld,r0,w_geom,Henpr1,lim_min
      read(snap23_unit) lim_max,lim_under,lim_in,lim_out,lim_tmp,lim_frin
      read(snap23_unit) lim_excess,lim_nodein,ThetaExc,FlwInTopExc,FrFlwTopIn,FrFlwSideIn
      read(snap23_unit) FlwRed,FlwTopCp,FlwLatCpPot,FlwLatAbs,FlwSat,FlwSatNew
      read(snap23_unit) QInIntSatS,QInMtxSatS,QOutMtxSatS,QOutMtxUnsS,FlwTopS,FlwLatCpS
      read(snap23_unit) WaSat,SRel0,SRel1,Srelavg,Vl0,Vl1
      read(snap23_unit) FrMpSat,CpFr,MPRelSat,WaUnTmp,dtheta,dthetaold
      read(snap23_unit) fdtheta,fdthetadrv,KSatMP,RapDraRes,dH_MPOld,dH_MP
      read(snap23_unit) zdenom,denommax,zdenommax,denom,numer,CorFac
      read(snap23_unit) cfdry,cfdry2,massbal,kwsat,notconv,MPempty
      read(snap23_unit) MPfull,KwSatCp
      end if
      return
      contains
      subroutine limit21_trace(stage)
      integer,intent(in)::stage
      real(8)::outfac
      if(.not.detail33) return
      outfac=-1d0
      if(stage/=1) outfac=FrFlwOut
      if(probe_busy) then
      if(stage==3) then
      write(probe_u,*) point_id,point_node,point_delta,attempts,iter_index,nvec,macro_seq,ITask,stage,dt,FrReduQ,h(52), &
       GwlFlCpZo,ICpTpSatZon,ZWaLevDm(3),WaSrMpDm(3),lim_min,lim_max,lim_under,VlMpDm(3), &
       lim_in,lim_out,lim_tmp,lim_frin,lim_excess,FlwOutDmExces(3),outfac, &
       FlwInTopVrtDmPot(3),FlwInTopLatDmPot(3),FlwInIntSatDmPot(3),FlwInMtxSatDmPot(3), &
       FlwOutMtxSatDmPot(3),FlwOutMtxUnsDmPot(3),FlwOutMtxSatDmCpPot(3,52), &
       QOutMtxSatDmCp(3,52),QInMtxSatDmCp(3,52),QInTopVrtDm(3)+QInTopLatDm(3), &
       FlwOutMtxSatDmCpPot(3,52)/dt,sum(QOutMtxSatDmCp(3,1:numnod))+sum(QOutMtxUnsDmCp(3,1:numnod)), &
       sum(QInMtxSatDmCp(3,1:numnod))+sum(QInIntSatDmCp(3,1:numnod))+QInTopVrtDm(3)+QInTopLatDm(3), &
       FlwInTopExcesTot,SatDefTot,merge(1,0,FlwOutDmExces(3)/dt>1d-7), &
       merge(1,0,FlwOutDmTot(3)>FlwOutDmExces(3)),WaSrMpDm(3)+lim_frin*lim_in-lim_min,lim_nodein
      end if
      return
      end if
      write(limit_u,*) attempts,iter_index,nvec,macro_seq,ITask,stage,dt,FrReduQ,h(52), &
       GwlFlCpZo,ICpTpSatZon,ZWaLevDm(3),WaSrMpDm(3),lim_min,lim_max,lim_under,VlMpDm(3), &
       lim_in,lim_out,lim_tmp,lim_frin,lim_excess,FlwOutDmExces(3),outfac, &
       FlwInTopVrtDmPot(3),FlwInTopLatDmPot(3),FlwInIntSatDmPot(3),FlwInMtxSatDmPot(3), &
       FlwOutMtxSatDmPot(3),FlwOutMtxUnsDmPot(3),FlwOutMtxSatDmCpPot(3,52), &
       QOutMtxSatDmCp(3,52),QInMtxSatDmCp(3,52),QInTopVrtDm(3)+QInTopLatDm(3), &
       FlwOutMtxSatDmCpPot(3,52)/dt,sum(QOutMtxSatDmCp(3,1:numnod))+sum(QOutMtxUnsDmCp(3,1:numnod)), &
       sum(QInMtxSatDmCp(3,1:numnod))+sum(QInIntSatDmCp(3,1:numnod))+QInTopVrtDm(3)+QInTopLatDm(3), &
       FlwInTopExcesTot,SatDefTot,merge(1,0,FlwOutDmExces(3)/dt>1d-7), &
       merge(1,0,FlwOutDmTot(3)>FlwOutDmExces(3)),WaSrMpDm(3)+lim_frin*lim_in-lim_min,lim_nodein
      end subroutine limit21_trace
      end subroutine MacroRate


!=====================================================================
      subroutine SATFLOW(ITask,id,                                                    & ! Basic info
                         CpBtZon,CpTpZon,Lev,                                         & ! Matrix properties
                         CpSatDm,SatFr,RefLev,                                        & ! MP properties
                         FlwInDmCpPot,FlwInDmPot,FlwOutMtxSatDmCpPot,FlwOutMtxSatDmPot) ! Output
! ----------------------------------------------------------------------
!     Date               : April 2008                                        
!     Purpose            : To calculate water exchange between macropores
!                        : and the SATURATED soil matrix
!     Functions called   : -
! ----------------------------------------------------------------------
      use MOD_arrays,    only: macp, madm
      use parameters,    only: pi
      use MOD_grid,      only: numnod, layer, z, dz
      use variables,     only: ksatfit, h, dt
      use MOD_macropore, only: dfdhmp, ICpBtDm, ppdmcp, dipocp, cdarcy, frreduq, qoutmtxsatdmcp, qinmtxsatdmcp, ictopmp, swsep, shapefacmp
                               
      implicit none

      integer::snap23_unit,snap23_mode

! --- global                                                          In
      integer, intent(in)  :: ITask, id
      integer, intent(in)  :: CpBtZon, CpTpZon, CpSatDm
      real(8), intent(in)  :: SatFr, Lev, RefLev
!     -                                                              Out
      real(8), intent(out) :: FlwInDmCpPot(MaCp), FlwInDmPot(MaDm)
      real(8), intent(out) :: FlwOutMtxSatDmCpPot(MaDm,MaCp), FlwOutMtxSatDmPot(MaDm)
! ----------------------------------------------------------------------
! --- local
      integer ic
      real(8)                             :: DelH, HMp, HMa
      real(8)                             :: KSatHor, RecRes, ResHor, ResRad, ResVrt
      real(8)                             :: CritHtop, Henpr1
      real(8), dimension(MaDm,MaCp), save :: DelHDmCp
      real(8), dimension(MaCp),      save :: FlwMtxSatDmCp

      real(8), parameter :: LogRatSeepFace = dlog(10.d0)
      real(8), parameter :: GeomFacSeep    = 16.d0 ! For spherical seepage face. 13.652 for square. Youngs 1980; 1/(0.25R2) = 16/dipocp^2

! ----------------------------------------------------------------------
      select case (itask)

! - 0. INITIALISATION  
      case (0)
! --- Initialisation global flows and contribution derivatives
      FlwMtxSatDmCp(1:NumNod) = 0.d0
      DelHDmCp(id,1:NumNod) = 0.d0

! --- Calculate potential water EXCHANGE between macropores and saturated matrix
!
! - 1. Calculate potential flows INCOMING into macropores   
!
      case (1)
! --- Initialisation local Flows 
      FlwInDmPot(id)         = 0.d0
      FlwInDmCpPot(1:NumNod) = 0.d0

! --- Check whether this subroutine is relevant for this macropore domain
      if (ICpBtDm(id) >= CpTpZon .AND. CpBtZon > 0) then
         continue
      else
         return
      end if
!
!   - CpTpZon = top compartment of relevant saturated zone (matrix)
      do ic = CpTpZon, min0(ICpBtDm(id),CpBtZon)
         ksatHor =  ksatfit(Layer(ic))   
!
!   - First calculation of Heads in Macropores and Matrix, for determing flow direction
         HMp  = RefLev - Z(ic)       ! head in macropore domain, assuming static equilibrium
         if (HMp < 1.d-8) HMp = 0.d0 ! no negative head in macropores
         HMa  = H(ic)                ! absolute comparison, no influence H_enpr
         DelH = HMp - HMa            ! differences between heads determines flow direction
         
         if (HMp < 1.d-8 .AND. DelH > 0.d0) DelH = 0.d0
         if (abs(DelH) < 1.d-8)             DelH = 0.d0
         if (HMa < 0.d0)                    DelH = 0.d0 ! Only saturated exchange if head matrix > 0

! - 3 flow situations:
!    1. DelH = +  -> infiltration of macropore water into matrix; Darcy flow
!    2. and 3. DelH = -  -> exfiltration of matrix water into macropores  
!    2.        HMp > 0   -> Darcy flow
!    3         HMp = 0   -> seepage face; Hooghoudt above drain level
         if (Delh > 0.d0) then 
! - 1. infiltration out of macropores into matrix: = term 2.a. (Darcy)
!           RecRes = reciprocal resistance for calculation of derivative
            RecRes                    = CDarcy(id,ic)
            if (ic == CpSatDm) RecRes = SatFr * RecRes ! MP compartment partially saturated
            FlwMtxSatDmCp(ic)         = - FrReduQ * RecRes * DelH * dt
!
         else if (DelH < 0.d0) then 
!   - exfiltration out of matrix into macropores
            if (HMp > 0.d0) then
! - 2. flow equation according to Darcy 
               RecRes                     = CDarcy(id,ic)
               if (ic == CpTpZon) RecRes = RecRes * (Lev - (Z(ic)-0.5d0*DZ(ic))) / DZ(ic)    ! Matrix compartment partially saturated
               FlwMtxSatDmCp(ic)          = - FrReduQ * RecRes * DelH * dt
            else
! - 3.a flow equation according to seepage face: Ernst with radial resistance 
               if (swsep == 1) then
                  ResHor = DiPoCp(ic)**2 / (8.0d0 * DZ(ic) * ksatHor) 
                  ResVrt = DZ(ic) / ksatHor
                  ResRad = DiPoCp(ic) * LogRatSeepFace / (pi*ksatHor)
                  RecRes = PpDmCp(id,ic) / (ResHor + ResVrt + ResRad) 
                  if (ic == CpTpZon) RecRes = RecRes * (Lev - (Z(ic)-0.5d0*DZ(ic))) / DZ(ic) ! Matrix compartment partially saturated
               else
! - 3.b flow equation according to seepage face: Youngs seepage potential theory
                  RecRes = shapefacmp*GeomFacSeep / DiPoCp(ic)**2 * KSatHor * DZ(ic) !* (Lev - z(ic) - 0.5d0*dz(ic))
                  if (ic == CpTpZon) RecRes = RecRes * (Lev - (Z(ic)-0.5d0*DZ(ic))) / DZ(ic) ! Matrix compartment partially saturated
               end if
               FlwMtxSatDmCp(ic) = - FrReduQ * RecRes * DelH * dt
            end if
         end if
         
         DelHDmCp(id,ic)      = DelH  ! save head difference for calculation of derivative
         
!   - save positive FlwMtxSatDmCp as INCOMING (into macropores) flux
         if (FlwMtxSatDmCp(ic) > 0.d0) then
            FlwInDmCpPot(ic)  = FlwMtxSatDmCp(ic)
            FlwInDmPot(id)    = FlwInDmPot(id) + FlwInDmCpPot(ic)
         end if
      end do 

      return

      case (2)
! - 2. Calculate potential flows OUTGOING out off macropores   
! --- Initialisation Flows
      FlwOutMtxSatDmPot(id)       = 0.d0
      FlwOutMtxSatDmCpPot(id,1:numnod) = 0.d0

! --- Check whether this subroutine is relevant for this macropore domain
      if (ICpBtDm(id) >= CpTpZon) then
         continue
      else
         return
      end if

!   - save negative FlwMtxSatDmCp as OUTGOING (out off macropores) flux
!   - (calculation of FlwMtxSatDmCp(ic) done above, in ITask 1)
      do ic= CpTpZon, ICpBtDm(id)
         if (FlwMtxSatDmCp(ic) < 0.d0) then
            FlwOutMtxSatDmCpPot(id,ic) = - FlwMtxSatDmCp(ic)
            FlwOutMtxSatDmPot(id) = FlwOutMtxSatDmPot(id) + FlwOutMtxSatDmCpPot(id,ic)
         end if
      end do

      return

      case (4)
! - C. Determine derivatives 

      do ic= CpTpZon, ICpBtDm(id)
         if (abs(DelHDmCp(id,ic)) > 1.d-14) then
            dFdhMp(ic)= dFdhMp(ic) -                                    &
                        (QOutMtxSatDmCp(id,ic) - QInMtxSatDmCp(id,ic)) /& 
                        DelHDmCp(id,ic) 
         end if
      end do

!   - derivative for bottom compartiment of covering top layer in case of seepage out of this layer into macropores 
      if (IcTopMp > 1)  then
         ic = IcTopMp-1
         CritHtop = 0.d0   !        Henpr1                      ! Adapted for GEM: test for H_enpr
         Henpr1   = CritHTop
         if (h(ic) > CritHtop) then  
            DelHDmCp(id,ic) = 0.d0 - (h(ic)-Henpr1)  ! Adapted for GEM: test for H_enpr
            dFdhMp(ic)= dFdhMp(ic) + QInMtxSatDmCp(id,ic) / DelHDmCp(id,IcTopMp-1)   
         end if        
      end if
!
      case default
         call swap_error ('satflow', 'Illegal value for TASK')
      end select

      return
      
      return
      entry sense23_sat_io(snap23_unit,snap23_mode)
      if(snap23_mode==1) then
      write(snap23_unit) DelHDmCp,FlwMtxSatDmCp
      else
      read(snap23_unit) DelHDmCp,FlwMtxSatDmCp
      end if
      return
end subroutine


!=====================================================================
      subroutine ABSORPTION(ITask,id,flwoutmtxunsdmcppot,flwoutmtxunsdmpot)
      use CONTRACT06_CONTROL, only:use_patch,trace_on,trace_unit

! ----------------------------------------------------------------------
!     Date               : May 2005                                        
!     Purpose            : To calculate absorption of macropore water into the
!                          unsaturated matrix by sorptivity under dry conditions
!                          and by pressure head gradient with Darcy
!     Functions called   : moiscap
! ----------------------------------------------------------------------
      use MOD_arrays,    only: macp, madm
      use MOD_grid,      only: numnod, layer, dz, z
      use MOD_MvG,       only: moiscap, cofgen
      use variables,     only: thetas, theta, thetar, dt, h, k,t1900
      use MOD_macropore, only: FlEndSrpEvt, ICpBtDm, ICpTpSatZon, icptpwasrdm, icpbtperzon, icptpperzon, timabscumdmcp, thtsrprefdmcp,    &
                               sorpdmcp, sorpmax, sorpalfa, ppdmcp, awlcorfac, dipocp, frmpwalwet, zwalevdm, shapefacmp, sorpfacparl,     &
                               swdarcy, frreduq, qoutmtxunsdmcp, dfdhmp, ictopmp, swmbf, swabs, icpbtdmpot, dimtxsat, vlmpdmcp


      use DIAG19,only:target,attempts,iter_index,nvec,raw_u,detail33,probe_busy,repair43,point_id,macro_seq
      use MOD_swap_mp,only:GwlFlCpZo
      implicit none

      integer::snap23_unit,snap23_mode
      logical::get45_is_sorption
      real(8),save::sample46(24)=0d0
      real(8)::get46(24),pre_contact46
! CONTACT47 scratch; never persistent physical/native state.
      real(8),save::delta48(madm,macp)=0d0,heads48(macp)=0d0,time48=0d0,dt48=0d0
      logical,save::mask48(madm,macp)=.false.,ready48=.false.,dirty48=.false.
      integer,save::attempt48=-1,iteration48=-1,seq48=-1,vec48=-1
      real(8)::get48(madm,macp),wet48
      logical::getmask48(madm,macp)
      real(8)::oldref51,oldsp51
      integer,save::unit51
      logical,save::open51=.false.
      integer::task48
      real(8)::info49(10)
      integer,save::unit49
      logical,save::open49=.false.

! --- global                                                         In
      integer, intent(in)     :: id, ITask
!     -                                                              Out
      real(8), intent(out)    :: flwoutmtxunsdmpot(madm),flwoutmtxunsdmcppot(madm,macp)

! ----------------------------------------------------------------------
! --- local
      integer                             :: ic, icBt, Lay, ICTp
      real(8)                             :: AbsDarc, AbsSorp, DelH, raw_sorp, raw_darcy
      real(8)                             :: Deriv, HMp, RecRes, SatDefMtx
      real(8)                             :: SorpAct, SorpFac, Time
      real(8) :: contact43,wet_top43,wet_span43,overlap43
      integer,save :: contact_unit43
      logical,save :: contact_open43=.false.
      real(8)                             :: alfamg, ksatfit, m, wcsminwcr, s_enpr, oneoverm, lambda_adj, relsat, help, diffus_avg
      real(8), dimension(MaDm,MaCp), save :: DelHDmCp
      real(8), dimension(MaCp),      save :: Diffusivity
      logical,                       save :: FlSorp(MaDm,MaCp)
            
      real(8), parameter      :: CritSatDefMtx = 1.d-8
      real(8), parameter      :: QSorpMax      = 1.d3
      real(8), parameter      :: shape_absorp  = 8.d0  ! Instead of 3.d0 in MACRO; Gerke & van Genuchten, Adv Wat Res, 1996
      real(8), parameter      :: gamma_scale   = 0.4d0 ! Gerke & van Genuchten, WRR, 1993, and ref. above.

! ----------------------------------------------------------------------
! --- Initialization Flows and Flags
      FlwOutMtxUnsDmPot(id)       = 0.d0
      FlwOutMtxUnsDmCpPot(id,1:numnod) = 0.d0
      FlEndSrpEvt(id,1:numnod)    = .TRUE.
      if(ITask==1.and.id==3) sample46=0d0

! --- Bottom domain considered
      icBt = min0(ICpBtDm(id),ICpTpSatZon-1) ! Original whole-cell exclusion.
      if(repair43.and.swmbf==1) icBt=min0(ICpBtDm(id),ICpTpSatZon)

! --- Top domain considered
      if (swmbf == 2 .AND. id == 1) then
         icTp = ICTopMP
      else 
         icTp = ICpTpWaSrDm(id)
      end if

      select case (itask)
          
      case (1)
! --- Calculate diffusivity for all compartments; store per timestep
      if (swabs == 2) then
         if (id == 1) then
            do ic = IcTopMP,ICpBtDmPot(id)
               alfamg = cofgen(4,ic)
               ksatfit = cofgen(3,ic)
               m = cofgen(7,ic)
               wcsMINwcr = cofgen(25,ic)
               s_enpr = cofgen(28,ic)
               oneOVERm = cofgen(32,ic)
               lambda_adj = dmax1(cofgen(5,ic),-oneOVERm)               
               relsat = (theta(ic) - thetar(ic)) / wcsMINwcr
               relsat = dmin1(relsat,s_enpr) ! Maximize to value below 1 based on h_enpr
               help   = 1-relsat ** oneOVERm
                 
               Diffusivity(ic) = (((1-m)*ksatfit) / (alfamg * m * wcsMINwcr)) *        &
                             relsat ** (lambda_adj - oneOVERm) * (help ** (-m) + help ** m - 2.d0) 
            end do
         end if
      end if
          
! --- Calculate potential Absorption
      do ic = icTp, icBt
         if(repair43.and.swmbf==1.and.ic==ICpTpSatZon) then
            if(h(ic)>=0d0) cycle
         end if
         if (ic > ICpBtPerZon .OR. ic < ICpTpPerZon) then ! Perched exclusion retained.
            contact43=1d0
            if(repair43.and.swmbf==1.and.ic==ICpTpSatZon) then
               ! Relative overlap with the ALREADY wetted wall; its original wet fraction is retained below.
               wet_top43=min(z(ic)+.5d0*dz(ic),ZWaLevDm(id))
               wet_span43=max(0d0,wet_top43-(z(ic)-.5d0*dz(ic)))
               if(wet_span43<=0d0) cycle
               overlap43=max(0d0,wet_top43-max(z(ic)-.5d0*dz(ic),GwlFlCpZo))
               contact43=min(1d0,max(0d0,overlap43/wet_span43))
               if(contact43<=0d0) cycle
            end if
            Lay       = Layer(ic)
! I.a By Sorptivity           
            SatDefMtx = dmax1(0.0d0, ThetaS(ic) - Theta(ic))
            if (swabs == 1) then
               Time   = TimAbsCumDmCp(id,ic)
               if (SatDefMtx < CritSatDefMtx) then
!     Matrix too wet: no sorptivity
                  AbsSorp = 0.d0
               else
                  if (Time < 1.d-8) then 
!     Start a new sorptivity event; set ThtSrpRefDmCp(id,ic) and SorpDmCp
!     ThtSrpRefDmCp = Thet_sat + Delta_thet_theor. = Thet_sat + Thet_theor. - Thet_0
!     Delta_thet_theor. = theoretical increase of theta (calculated in MacroState) 
                     oldref51=ThtSrpRefDmCp(id,ic);oldsp51=SorpDmCp(id,ic)
                     ThtSrpRefDmCp(id,ic) = ThetaS(ic)  ! initial, delta_theta = 0
                     SorpDmCp(id,ic)      = SorpMax(Lay) *                 &
                                   (dmax1(0.0d0, (ThetaS(ic)-Theta(ic))) / &
                                   (ThetaS(ic)-ThetaR(ic)))** SorpAlfa(Lay)
                     SorpAct = SorpDmCp(id,ic)
                     if(detail33.and.((id==3.and.ic==50).or.(id==4.and.ic==49))) then
                        if(.not.open51) then
                           open(newunit=unit51,file='inactive51_trace.txt',status='replace');open51=.true.
                        end if
                        write(unit51,*) attempts,iter_index,nvec,macro_seq,id,ic,t1900,dt,Time,oldref51,oldsp51, &
                         ThtSrpRefDmCp(id,ic),SorpDmCp(id,ic),SorpAct,ThetaS(ic),Theta(ic),ThetaR(ic),SorpMax(Lay),SorpAlfa(Lay)
                     end if
                  else if ((ThtSrpRefDmCp(id,ic)-Theta(ic)) > CritSatDefMtx) then 
!     Continue existing sorptivity event; set SorpAct
                     SorpAct = SorpMax(Lay) *                              &
                               ((ThtSrpRefDmCp(id,ic)-Theta(ic)) /         &
                               (ThetaS(ic)-ThetaR(ic)))** SorpAlfa(Lay)
                  else
!     End existing sorptivity event
                     SorpAct = 0.d0
                  end if
                  AbsSorp = SorpAct * PpDmCp(id,ic) * (4.d0 *AwlCorFac(ic)*&
                        DZ(ic) / DiPoCp(ic)) * (dsqrt(Time+dt)-dsqrt(Time))   
                  if ((swmbf == 1 .OR. id > 1) .AND. ic == ICpTpWaSrDm(id)) AbsSorp = FrMpWalWet(id,ic)*AbsSorp
!     Limit peak amount of absorbed water at beginning of sorptiviy event
                  AbsSorp = dmin1(QSorpMax*dt*DZ(ic),AbsSorp)
               end if

! I.b By Diffusion      
            else
               if (SatDefMtx < CritSatDefMtx) then
!     Matrix too wet: no absorption by diffusion
                  AbsSorp = 0.d0
               else
!     Average of saturated (at macropore wall) and matrix (middle of aggregate) diffusivity
                  Diffus_avg = (Diffusivity(ic) + DiMtxSat(Lay))/2.d0 ! Do not multiply with saturation, this is done outside absorption subr.
                  SorpAct = (4.d0 * shape_absorp * Diffus_avg * gamma_scale) /  &
                            (DiPoCp(ic)**2.d0 * (1.d0-VlMpDmCp(id,ic))) * (thetas(ic)-theta(ic))
                  AbsSorp = SorpAct * PpDmCp(id,ic) * DZ(ic) * dt 
               end if
               if ((swmbf == 1 .OR. id > 1) .AND. ic == ICpTpWaSrDm(id)) AbsSorp = FrMpWalWet(id,ic)*AbsSorp
            end if

! II  By Darcy 
            
            AbsDarc = 0.d0
            
            if (SwDarcy > 0) then
               if (ic > ICpTpWaSrDm(id)) then
                  HMp = ZWaLevDm(id) - Z(ic)  ! head in macropore domain, assuming static equilibrium
                  HMp = dmax1(0.d0,HMp)       ! no negative head in macropores
                  if ((use_patch .OR. H(ic) < cofgen(9,lay)-1.d-8) .AND. HMp > 1.d-8) then     ! Adapted for GEM: test for H_enpr        
                     DelH= dmax1(0.d0,HMp - H(ic))
                  else
                     DelH= 0.d0
                  end if
                  DelHDmCp(id,ic)= DelH     ! save head difference for calculation of derivative
                                            ! reciporocal resistance for calculation of derivative
                  RecRes  = ShapeFacMp * 8.0d0 * PpDmCp(id,ic) * DZ(ic) *     &
                            K(ic) / DiPoCp(ic)**2
                  if ((swmbf == 1 .OR. id > 1) .AND. ic == ICpTpWaSrDm(id)) RecRes = FrMpWalWet(id,ic) * RecRes
                  AbsDarc = RecRes * DelH * dt

                  SorpFac = SorpFacParl(lay) + (1.d0-SorpFacParl(lay)) *      &
                            ( 1.d0 -(dmax1((ThetaS(ic)-Theta(ic)),0.d0) /     &
                                     (ThetaS(ic)-ThetaR(ic)))**SorpAlfa(Lay) )
               end if
            end if

            if(id==3.and.ic==50) pre_contact46=AbsSorp
            if(repair43.and.swmbf==1.and.ic==ICpTpSatZon) then
               AbsSorp=contact43*AbsSorp
               AbsDarc=contact43*AbsDarc
            end if
            raw_sorp=AbsSorp
            raw_darcy=AbsDarc
            if (AbsSorp > SorpFac*AbsDarc) then
               FlwOutMtxUnsDmCpPot(id,ic) = FrReduQ * AbsSorp
               FlSorp(id,ic)         = .TRUE.
               AbsDarc               = 0.d0
            else
               FlwOutMtxUnsDmCpPot(id,ic) = FrReduQ * SorpFac*AbsDarc
               AbsSorp               = 0.d0
               FlSorp(id,ic)         = .FALSE.
            end if
    
            if(id==3.and.ic==50) then
               sample46=[dble(attempts),dble(iter_index),dble(nvec),dble(macro_seq),1d0,Time,SorpAct, &
                SorpDmCp(id,ic),ThtSrpRefDmCp(id,ic),theta(ic),thetas(ic),thetar(ic),SorpMax(lay),SorpAlfa(lay), &
                AwlCorFac(ic),PpDmCp(id,ic),dz(ic),DiPoCp(ic),FrMpWalWet(id,ic),contact43,pre_contact46, &
                raw_sorp,FlwOutMtxUnsDmCpPot(id,ic),merge(1d0,0d0,FlSorp(id,ic))]
            end if
            if(trace_on.and.ic==45) then
             write(trace_unit,*) id,ic,lay,H(ic),cofgen(9,lay),cofgen(9,ic),theta(ic),thetas(ic),K(ic), &
             HMp,DelH,RecRes,SorpFac,raw_sorp,raw_darcy,FlwOutMtxUnsDmCpPot(id,ic), &
             merge(1,0,FlSorp(id,ic)),dt,TimAbsCumDmCp(id,ic),ICpTpWaSrDm(id)
            end if
            if(detail33.and.ic==52.and..not.probe_busy) then
             block
             real(8)::hm_log,del_log,rec_log,sf_log
             hm_log=0;del_log=0;rec_log=0;sf_log=0
             if(SwDarcy>0.and.ic>ICpTpWaSrDm(id)) then
              hm_log=HMp;del_log=DelH;rec_log=RecRes;sf_log=SorpFac
             end if
             write(raw_u,*) attempts,iter_index,nvec,id,ic,H(ic),theta(ic),dt,FrReduQ, &
              raw_sorp,raw_darcy,FlwOutMtxUnsDmCpPot(id,ic),merge(1,0,FlSorp(id,ic)), &
              hm_log,del_log,rec_log,sf_log,FrMpWalWet(id,ic),TimAbsCumDmCp(id,ic),ICpTpWaSrDm(id)
             end block
            end if
            if(repair43.and.detail33.and.ic==47) then
               if(.not.contact_open43) then
                  open(newunit=contact_unit43,file='contact43_trace.txt',status='replace');contact_open43=.true.
               end if
               write(contact_unit43,*) attempts,iter_index,nvec,macro_seq,merge(1,0,probe_busy),point_id,id,ic, &
                  ICpTpSatZon,GwlFlCpZo,h(ic),contact43,raw_sorp,raw_darcy,SorpFac,FlwOutMtxUnsDmCpPot(id,ic), &
                  merge(1,0,FlSorp(id,ic)),FrMpWalWet(id,ic),ICpTpWaSrDm(id)
               flush(contact_unit43)
            end if
            FlwOutMtxUnsDmPot(id) = FlwOutMtxUnsDmPot(id) + FlwOutMtxUnsDmCpPot(id,ic)
!
! --- Set Flag to END SoRPtivity EVenT in MACROSTATE
            if (AbsSorp/dt > 1.d-7) then
               FlEndSrpEvt(id,ic) = .FALSE.
               if(repair43.and.swmbf==1.and.swabs==1.and.ic==ICpTpSatZon) then
                  wet48=1d0
                  if(ic==ICpTpWaSrDm(id)) wet48=FrMpWalWet(id,ic)
                  delta48(id,ic)=AwlCorFac(ic)*PpDmCp(id,ic)*(4d0/DiPoCp(ic))*wet48*contact43 &
                   *SorpDmCp(id,ic)*(sqrt(TimAbsCumDmCp(id,ic)+dt)-sqrt(TimAbsCumDmCp(id,ic)))
                  mask48(id,ic)=.true.;dirty48=.true.
               end if
            end if
         end if
      end do
!
      return
!
      case (2)
! --- Determine derivatives 
      do ic = icTp, icBt
         if(repair43.and.swmbf==1.and.ic==ICpTpSatZon) then
            if(h(ic)>=0d0) cycle
         end if
         if (ic > ICpBtPerZon .OR. ic < ICpTpPerZon) then 
!
            if (QOutMtxUnsDmCp(id,ic) > 1.d-7) then
               if (FlSorp(id,ic)) then
                  if (swabs == 1) then
                     Lay   = Layer(ic)
                     Deriv = - QOutMtxUnsDmCp(id,ic) * SorpAlfa(Lay) /     &
                             (ThtSrpRefDmCp(id,ic) - Theta(ic))
                     Deriv = Deriv * moiscap(ic,H(ic))
                  else
                     Deriv = - QOutMtxUnsDmCp(id,ic) * moiscap(ic,H(ic)) / &
                             (thetas(ic) - theta(ic))
                  end if
               else
                  Deriv = 0.d0
                  if (abs(DelHDmCp(id,ic)) > 1.d-14) then
                     Deriv = - QOutMtxUnsDmCp(id,ic) / DelHDmCp(id,ic)
                  end if
               end if
               dFdhMp(ic)= dFdhMp(ic) + Deriv   
            end if
         end if
      end do
!
      case default
         call swap_error ('absorption', 'Illegal value for TASK')
      end select

      return
      return
      entry reference48_invalidate()
      ready48=.false.
      if(dirty48) then
         mask48=.false.;delta48=0d0;dirty48=.false.
      end if
      return
      entry reference48_seal(task48)
      ready48=repair43.and.swmbf==1.and.swabs==1.and.task48==1.and..not.probe_busy
      time48=t1900;dt48=dt;attempt48=attempts;iteration48=iter_index;seq48=macro_seq;vec48=nvec
      heads48(1:numnod)=h(1:numnod)
      if(detail33.and..not.probe_busy) then
       if(.not.open49) then
        open(newunit=unit49,file='provider49_trace.txt',status='replace');open49=.true.
       end if
       write(unit49,*) attempts,iter_index,macro_seq,task48,t1900,dt,nvec,count(mask48),sum(delta48),merge(1,0,ready48)
      end if
      return
      entry reference49_get(info49)
      info49=[merge(1d0,0d0,ready48),dble(count(mask48)),sum(delta48),time48,dt48,dble(attempt48), &
       dble(iteration48),dble(seq48),dble(vec48),merge(1d0,0d0,all(heads48(1:numnod)==h(1:numnod)))]
      return
      entry reference48_take(get48,getmask48)
      if(.not.ready48.or.time48/=t1900.or.dt48/=dt.or.attempt48/=attempts.or.iteration48/=iter_index &
       .or.seq48/=macro_seq.or.vec48/=nvec) error stop 'REFERENCE48 stale or consumed provider'
      if(any(heads48(1:numnod)/=h(1:numnod))) error stop 'REFERENCE48 head mismatch'
      get48=delta48;getmask48=mask48
      ready48=.false.
      return
      entry reference46_abs_get(get46)
      get46=sample46
      return
      entry clock45_abs_get(get45_is_sorption)
      get45_is_sorption=FlSorp(3,50)
      return
      entry sense23_abs_io(snap23_unit,snap23_mode)
      if(snap23_mode==1) then
      write(snap23_unit) DelHDmCp,Diffusivity,FlSorp
      else
      read(snap23_unit) DelHDmCp,Diffusivity,FlSorp
      end if
      return

      end


!=====================================================================
      subroutine RAPIDDRAIN(id,ICpTp,SatFr,ZwaLev,RapDraRes,FlwOutDrRapCpPot,FlwOutDrRapPot)
! ----------------------------------------------------------------------
!     Date               : April 2008                                      
!     Purpose            : To calculate rapid drainage from Main Bypass flow domain
! ----------------------------------------------------------------------
      use MOD_arrays,    only: macp
      use MOD_grid,      only: numnod, dz
      use MOD_drain,     only: swdtyp
      use variables,     only: pond, dt
      use MOD_macropore, only: SwDrRap, zbtdm, zdrabas, icpbtdm, dipocp, vlmpdmcp, rapdrareaexp,    &
                               wasrmpdm, kdcrrlref, rapdraresref, frreduq, numlevrapdra

      implicit none

! --- global                                                          In
      integer, intent(in)  :: id,ICpTp
      real(8), intent(in)  :: SatFr, ZwaLev
!     -                                                              Out
      real(8), intent(out) :: FlwOutDrRapCpPot(macp),FlwOutDrRapPot
      real(8), intent(out) :: RapDraRes
! ----------------------------------------------------------------------
! --- local
      integer ic
      real(8)                  :: DelH, KDCrRl, vlmpundrdrl
      real(8)                  :: WaSrDrainabl, WthCr, FacRes
      real(8), dimension(macp) :: KDCrRlCp
      real(8)                  :: VOLUNDR
! ----------------------------------------------------------------------
!
! --- Check whether this subroutine is relevant for this macropore domain
!     Rapid drainage only in domain 1: Main Bypass flow domain
      if (id == 1) then
!   - Initialization
         FlwOutDrRapPot             = 0.d0
         FlwOutDrRapCpPot(1:numnod) = 0.d0
!
         if (SwDrRap == 1) then
            continue
         else
            return
         end if
      else
         return
      end if
!
! --- for drain tube rapid drainage only possible if ZBtDm <= Zdrabas;
!   - for open drain, rapid drainage also possible when ZBtDm > Zdrabas
      if (ZBtDm(id) < ZDraBas .OR. swdtyp(NumLevRapDra) /= 1) then !+1.0d-1
! transmissivity kD
         KDCrRl= 0.d0
         do ic = ICpTp, ICpBtDm(id)
            WthCr        = DiPoCp(ic) * (1.d0 - dsqrt(1.d0-VlMpDmCp(id,ic) / DZ(ic)))
            KDCrRlCp(ic) = ((WthCr**RapDraReaExp)/DiPoCp(ic)) * DZ(ic)     
            if (ic == ICpTp) KDCrRlCp(ic) = SatFr * KDCrRlCp(ic)
            KDCrRl       = KDCrRl + KDCrRlCp(ic)     
         end do
!
         VlMpUndrDrL     = 0.d0
         if (ZBtDm(id) < ZDraBas) VlMpUndrDrL = VOLUNDR(ZDraBas,ZBtDm(id)-0.5d0*dz(ICpBtDm(id)),ICpBtDm(id),VlMpDmCp(id,1:numnod))
         WaSrDrainabl    = dmax1(0.d0,(WaSrMpDm(id) - VlMpUndrDrL))
!
! for open drain: DelH =  zwalevdm - ditch water level or bottom of MB domain !
         DelH            =  ZWaLev - dmax1(ZDraBas,ZBtDm(id))
         if (ZWaLev > -1.d-7) DelH = DelH + Pond
! ! in this version: no infiltration
         DelH            = dmax1(DelH,0.d0)
         if (KdCrRl > 1.d-10) then
            FacRes         = dmin1(KDCrRlRef(id)/KDCrRl,1.1d0)
            RapDraRes      = RapDraResRef(id) * FacRes
            FlwOutDrRapPot = FrReduQ * (DelH / RapDraRes) * dt
         else
            FlwOutDrRapPot = 0.d0
         end if
         FlwOutDrRapPot    = dmin1(FlwOutDrRapPot,WaSrDrainabl)
! distribute over compartments according to kD
         do ic = ICpTp, ICpBtDm(id)
            if (KDCrRl > 1.d-15) then     
               FlwOutDrRapCpPot(ic) = FlwOutDrRapPot * KDCrRlCp(ic) / KDCrRl  
            else   
               FlwOutDrRapCpPot(ic) = 0.d0
               FlwOutDrRapPot       = 0.d0
            end if    
         end do
      end if

      return
      end subroutine RapidDrain


!=======================================================================
      real(8) function VOLUNDR(Ztp,Zbt,ICZbt,MPVol)
! ----------------------------------------------------------------------
!     Date               : september 2002
!     Purpose            : calculates volume of macropores under drain or 
!                        : groundwater level
! ----------------------------------------------------------------------
      use MOD_arrays,    only: macp
      use MOD_grid,      only: dz
      implicit NONE

! --- global
      integer, intent(in)  :: ICZbt
      real(8), intent(in)  :: Ztp,Zbt,MPVol(macp)
! ----------------------------------------------------------------------
! --- local
      integer :: ic
      real(8) :: ZHlp
! ----------------------------------------------------------------------
      VOLUNDR    = 0.d0
      ic         = ICZbt + 1
      ZHlp       = Zbt
      do while (ZHlp < Ztp .AND. ic > 1)
         ic      = ic - 1
         ZHlp     = ZHlp + DZ(ic)
         VOLUNDR = VOLUNDR + MPVol(ic)
      end do
      if (VOLUNDR > 0.d0) VOLUNDR = VOLUNDR - (ZHlp-Ztp) * MPVol(ic) / DZ(ic)
      
      return
      end function VolUndr

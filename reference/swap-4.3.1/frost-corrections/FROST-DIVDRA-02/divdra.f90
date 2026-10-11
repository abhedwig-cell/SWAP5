submodule (MOD_drain) SMOD_divdra
   
   contains

! ----------------------------------------------------------------------
      module SUBROUTINE DIVDRA(ksatcp, gwlev) 
! ----------------------------------------------------------------------
!     Purpose            : Simulation of lateral waterfluxes in the
!                          saturated zone. 
! ----------------------------------------------------------------------
      use MOD_arrays,    only: macp, madr
      use MOD_grid,      only: numnod, dz, layer, zbotcp
      implicit none

! --- Global
      real(8), dimension(macp), intent(in)   :: ksatcp
      real(8),                  intent(in)   :: gwlev

! --- Local
      integer, dimension(madr)               :: drnseq,icpbotdislay
      integer                                :: idr,iidr,idum,jdr,icpwlev,NumActDrain,NumDrHlp,icp
      integer                                :: icptopdislay,icpslev
      real(8), dimension(madr)               :: zbotdislay, FlowDrDisch, HelpFl,dmaxdislay,dzcpbotdislay,KDdr,FDisInf
      real(8), dimension(macp)               :: Khor,Kver,KD
      real(8)                                :: FacAniso,KhorAv,KverAV, dzhlp
      real(8)                                :: KDhor,KDver,Dum1
      real(8)                                :: KDhlp,dzcpwlevsat,wlev,dzdislay 
      real(8)                                :: CumKD, qdrauns,RQmax, slev
      real(8)                                :: dzcpslevsat, dzcpwlevuns, KDsat, KDtot, KDuns
      real(8)                                :: difztopdislay,ratiodz,ratio,sumqdr
      logical                                :: flNoFlux,flDivInf
      real(8), parameter                     :: Small = 1.0d-10
! ----------------------------------------------------------------------
      
! --- Paragraph 1 
!     Initial calculations

      ! Initialisation and test whether any drainflux exists
      qdra(1:nrlevs,1:numnod) = 0.0d0
      drnseq(1:nrlevs)        = 0
      
      flNoFlux = .TRUE.
      flDivInf = .FALSE.
      do idr=1,nrlevs
         if (abs(qdrain(idr)) > Small) flNoFlux = .FALSE.
         if (Swdivdinf == 1 .AND. qdrain(idr) < -Small) flDivInf = .TRUE.
      end do      
      if (flNoFlux) return
      
      ! Groundwater level converted to cm below surface level 
      wlev = -1.0d0*min(gwlev,0.0d0)

      ! Calculation of Khor and Kver
      Khor(1:numnod) = ksatcp(1:numnod) * cofani(layer(1:numnod))
      Kver(1:numnod) = ksatcp(1:numnod)

! --- Paragraph 2 
!     Search for compartment with groundwaterlevel: icpwlev
!     Thickness of saturated part of compartment with waterlevel: dzcpwlevsat
      call Lev2Comp(wlev,icpwlev,dzcpwlevuns,dzcpwlevsat)

! --- Paragraph 3 
!     In case of adjustment of top layer: the bottom of the highest order drainage system (-Zbotdr(nrlevs)) represents max depth of the top discharge layer and top of all other model discharge layers 
      NumDrHlp = nrlevs

      if (swnrsrf /= 0 .AND. swtopnrsrf == 1) then
         NumDrHlp = nrlevs-1
         idr      = nrlevs
         if (abs(qdrain(idr)) > Small) then
            ! Determine bottom and total transmissivity of the top discharge layer, down to bottom of drainage system
            icp       = icpwlev    
            KDdr(idr) = Khor(icp) * dzcpwlevsat
            dzhlp     = -zbotcp(icp)
            do while (-ZBotDr(idr) > dzhlp) 
               icp      = icp + 1
               dzhlp    = dzhlp + dz(icp)
               KDdr(idr) = KDdr(idr) + Khor(icp) * dz(icp)
            end do
            dzcpbotdislay(idr) = dz(icp) - dzhlp - ZBotDr(idr)
            KDdr(idr)          = KDdr(idr) - Khor(icp) * (dzhlp - (-ZBotDr(idr)))
            if (icp == icpwlev) then
               dzcpwlevsat         = dzcpwlevsat - dzhlp - ZBotDr(idr)
               dzcpbotdislay(idr)  = dzcpwlevsat
            end if
            icpbotdislay(idr) = icp

            ! Distribute interflow fluxes as lateral fluxes over compartments of the interflow discharge layer
            idr = nrlevs
            qdra(idr,icpwlev) = qdrain(idr) * dzcpwlevsat * Khor(icpwlev) / KDdr(idr)
            do icp = icpwlev+1, icpbotdislay(idr)-1
               qdra(idr,icp)  = qdrain(idr) * dz(icp) * Khor(icp) / KDdr(idr)
            end do
            qdra(idr,icpbotdislay(idr)) = qdrain(idr) * dzcpbotdislay(idr) * Khor(icpbotdislay(idr)) / KDdr(idr)

            ! Reset variables for determinig top of all other model discharge layers 
            wlev        = -ZBotDr(nrlevs)
            icpwlev     = icp
            dzcpwlevsat = dzhlp - (-ZBotDr(idr))
         end if
         ! No other drainage levels besides interflow -> leave DIVDRA
         if (NumDrHlp == 0) return
      end if

! --- Paragraph 4
!     Calculate overall anisotropic factor model profile and cumulative transmissivity as a function of depth
      KDhor = dzcpwlevsat * Khor(icpwlev)
      KDver = dzcpwlevsat / Kver(icpwlev)
      dzhlp = dzcpwlevsat

      do icp=icpwlev+1,numnod
         KDhor = KDhor + dz(icp) * Khor(icp)
         KDver = KDver + dz(icp) / Kver(icp)
         dzhlp = dzhlp + dz(icp)
      end do
      
      KhorAv   = KDhor / dzhlp
      KverAv   = dzhlp / KDver
      FacAniso = dsqrt(KverAv / KhorAv)

! --- Paragraph 5      
!     Calculate maximum depth per drainage system and discharge flow rate per drainage system 
      do idr=1,NumDrHlp
         ! In case of infiltration and switch for seperate infiltration flux distribution on: set factor for adapting depth of discharge layer to depth of infiltration layer
         if (flDivInf .AND. qdrain(idr) < -small) then               
            FDisInf(idr) = max(FacDpthInf,dzcpwlevsat / (0.25d0*Lspacing(idr)*FacAniso))
         else
            FDisInf(idr) = 1.d0
         end if

         dmaxdislay(idr) = FDisInf(idr) * 0.25d0*Lspacing(idr)*FacAniso+wlev
         dmaxdislay(idr) = min(dmaxdislay(idr), dzhlp+wlev) ! Maximize to bottom SWAP profile
      end do

! --- Paragraph 6      
!     Determine sequence of order of drainage systems 
      NumActDrain = 0
      do idr=1,NumDrHlp
         if (abs(qdrain(idr)) > small) then
            NumActDrain = NumActDrain+1
            drnseq(NumActDrain) = idr
            HelpFl(NumActDrain) = FDisInf(idr)*Lspacing(idr)
         end if 
      end do
      
      do idr=1,NumActDrain-1
         do iidr = idr+1,NumActDrain
            if (HelpFl(idr) < HelpFl(iidr)) then
             dum1         = HelpFl(iidr)
             HelpFl(iidr) = HelpFl(idr)
             HelpFl(idr)  = dum1
             idum         = drnseq(iidr)
             drnseq(iidr) = drnseq(idr)
             drnseq(idr)  = idum
            end if
         end do
      end do       

      idr = drnseq(NumActDrain)
      FlowDrDisch(idr) = FDisInf(idr)*abs(qdrain(idr))*Lspacing(idr)
      do iidr=NumActDrain-1,1,-1 
         idr = drnseq(iidr)
         jdr = drnseq(iidr+1)
         FlowDrDisch(idr) = FlowDrDisch(jdr) + FDisInf(idr)*abs(qdrain(idr)*Lspacing(idr))
      end do

! --- Paragraph 7
!     Bottom of 1st order model discharge layer
      idr                = drnseq(1)
      KDdr(idr)          = KDhor
      zbotdislay(idr)    = -zbotcp(numnod)
      icpbotdislay(idr)  = numnod
      dzcpbotdislay(idr) = dz(numnod)           
      
      ! Correction of zbotdislay(1) if D1 < 0.25 L \/(kv/kh) 
      if (abs(qdrain(idr)) > Small) then
         if (zbotdislay(idr) > dmaxdislay(idr) ) then
            ! Determine adjusted transmissivity and compartment number which contains bottom of discharge layer
            zbotdislay(idr)   = dmaxdislay(idr)
            icp               = icpwlev
            dzhlp             = dzcpwlevsat
            KDdr(idr)         = dzcpwlevsat * Khor(icpwlev)
            dzdislay          = zbotdislay(idr)-wlev
            do while (dzdislay > dzhlp)      
               icp       = icp + 1       
               dzhlp     = dzhlp + dz(icp)
               KDdr(idr) = KDdr(idr) + dz(icp) * Khor(icp)
            end do
            KDdr(idr)          = KDdr(idr) - (dzhlp - dzdislay) * Khor(icp)
            dzcpbotdislay(idr) = dz(icp)   - (dzhlp - dzdislay)
            icpbotdislay(idr)  = icp
         end if      
      else 
         zbotdislay(idr) = wlev
      end if

! --- Paragraph 8
!     Bottom of 2nd and higher order model_discharge_layers for drainage system of orders 2 to nrlevs (number of drains)         
      do iidr=2,NumActDrain
         idr = drnseq(iidr) 
         jdr = drnseq(iidr-1)
         KDdr(idr) = KDdr(jdr) * FlowDrDisch(idr) / FlowDrDisch(jdr) 

         ! Bottom of discharge layer of order i and thickness of bottom compartment, and number of bottom compartment
         icp    = icpwlev
         KDhlp = dzcpwlevsat * Khor(icp)
         dzhlp = dzcpwlevsat
         do while (KDhlp < KDdr(idr))      
            icp  = icp + 1       
            KDhlp = KDhlp + dz(icp)*Khor(icp)      
            dzhlp = dzhlp + dz(icp)       
         end do
         dzcpbotdislay(idr) = dz(icp) - (KDhlp - KDdr(idr)) / Khor(icp)
         zbotdislay(idr)    = wlev + dzhlp + (KDdr(idr) - KDhlp) / Khor(icp)
         icpbotdislay(idr)  = icp

! --- Paragraph 9
!     Correction of zbotdislay(idr) if D(idr) < 0.25 L(idr) \/(kv/kh) 
         if (zbotdislay(idr) > dmaxdislay(idr)) then
            zbotdislay(idr) = dmaxdislay(idr)

            ! Transmissivity of order i, thickness of bottom compartment, and number of bottom compartment
            icp       = icpwlev
            dzhlp     = dzcpwlevsat
            KDdr(idr) = dzcpwlevsat * Khor(icpwlev)
            dzdislay  = zbotdislay(idr) - wlev
            do while ( dzdislay > dzhlp )      
               icp     = icp + 1       
               dzhlp = dzhlp + dz(icp)       
               KDdr(idr) = KDdr(idr) + dz(icp) * Khor(icp)
            end do
            KDdr(idr)          = KDdr(idr) - (dzhlp - dzdislay) * Khor(icp)
            dzcpbotdislay(idr) = dz(icp)   - (dzhlp - dzdislay)
            icpbotdislay(idr)  = icp
         end if   
      end do

! --- Paragraph 10
!     Distribute drainage fluxes as lateral fluxes over i-th order model discharge layers
      do iidr=1,NumActDrain
         idr = drnseq(iidr)
         if (.NOT.flDivInf .OR. qdrain(idr) > 0.d0) then 
           qdra(idr,icpwlev) = qdrain(idr) * dzcpwlevsat * Khor(icpwlev) / KDdr(idr)
           do icp=icpwlev+1,icpbotdislay(idr)-1
              qdra(idr,icp)  = qdrain(idr) * dz(icp)     * Khor(icp)     / KDdr(idr)
           end do
           qdra(idr,icpbotdislay(idr)) = qdrain(idr) * dzcpbotdislay(idr) * Khor(icpbotdislay(idr)) / KDdr(idr)
           
           if (icpwlev == icpbotdislay(idr)) qdra(idr,icpwlev) = qdrain(idr)
         end if
      end do

! --- Paragraph 11
!     Distribution of infiltration fluxes is separate from distribution discharge fluxes if SWDivdInf == 1
      if (flDivInf) then    
         do iidr = 1, NumActDrain
            idr = drnseq(iidr) 
            if (qdrain(idr) < -small) then                                                
               ! Find surface water level and corresponding compartment: icpslev
               slev = -1.d0*min(drainl(idr),0.d0)
               
               call Lev2Comp(slev,icpslev,dum1,dzcpslevsat)
               
               ! Search for compartment with max depth infiltration layer: NumComDepthInf (part of NumComDepthInf Above DepthInflay)
               call Lev2Comp(dmaxdislay(idr),icpbotdislay(idr),dzcpbotdislay(idr),dum1)

               ! Recalculate dzcpslevuns, may be adjusted due to topnrsrf
               call Lev2Comp(wlev,icpwlev,dzcpwlevuns,dzcpwlevsat)
               
               if (icpbotdislay(idr) == icpwlev) dzcpbotdislay(idr) = dzcpwlevsat

               ! Determine transmissivity of total infiltration zone, of its unsaturated part and saturated part, and of the compartments within
               KD(1:numnod) = 0.d0
               KDtot = dzcpbotdislay(idr) * Khor(icpbotdislay(idr))
               KDsat = KDtot
               KD(icpbotdislay(idr)) = KDtot
               do icp = icpbotdislay(idr)-1, icpslev+1, -1
                  KD(icp) = dz(icp) * Khor(icp)
                  KDtot = KDtot + KD(icp)
                  if (icp > icpwlev) then 
                     KDsat = KDsat + KD(icp)
                  else if (icp == icpwlev) then
                     KDsat = KDsat + Khor(icp) * dzcpwlevsat
                  end if
               end do
               KD(icpslev) = dzcpslevsat * Khor(icpslev)
               KDtot = KDtot + KD(icpslev)
               
               ! Special cases for transmissivity
               if (icpbotdislay(idr) == icpslev) then
                  KD(icpslev) = (dzcpslevsat + dzcpbotdislay(idr) -  dz(icpslev)) * Khor(icpslev)
                  KDtot = KD(icpslev)
                  KDsat = (dzcpwlevsat + dzcpbotdislay(idr) - dz(icpslev)) * Khor(icpslev)
               else if (icpwlev == icpslev) then
                  KDsat = KDsat + Khor(icp) * dzcpwlevsat
               else if (icpbotdislay(idr) == icpwlev) then
                  KDsat = (dzcpwlevsat + dzcpbotdislay(idr) - dz(icpwlev)) * Khor(icpwlev)
               end if
               
               KDuns = KDtot - KDsat

               ! Calculate RQmaxL max flux per unit of transmissivity
               RQmax = qdrain(idr) / KDtot

               ! Distribute infiltration fluxes as lateral fluxes over unsaturated compartments
               if (icpslev == icpwlev) then
                  qdrauns = RQmax * (dzcpslevsat - dzcpwlevsat) * Khor(icpwlev) 
               else
                  if (KDuns > 0.d0) then
                     CumKD = 0.d0
                     do icp = icpslev, icpwlev-1
                        qdra(idr,icp) = RQmax / KDuns * ((CumKD+KD(icp))**2 - CumKD**2)
                        CumKD = CumKD + KD(icp)
                     end do
                     qdrauns = RQmax / KDuns * ((CumKD + dzcpwlevuns*Khor(icpwlev))**2 - CumKD**2)
                  else
                     qdrauns = 0.0d0
                  end if
               end if

               ! Distribute infiltration fluxes as lateral fluxes over saturated compartments
               CumKD = 0.d0
               do icp = icpbotdislay(idr), icpwlev+1, -1
                  qdra(idr,icp) = RQmax / KDsat * ( (CumKD+KD(icp))**2 - CumKD**2 )
                  CumKD = CumKD + KD(icp)
               end do
               ! Add unsaturated flux to infiltration flux of compartment containing groundwater level 
               qdra(idr,icpwlev) = RQmax / KDsat * ((cumKD + dzcpwlevsat*Khor(icpwlev))**2 - CumKD**2)
               qdra(idr,icpwlev) = qdra(idr,icpwlev) + qdrauns

            end if                                                      
         end do
      end if
      
! --- Paragraph 12
!     Redistribute qdrain with new top boundary for discharge layers
      if (swdislay == 2) then
         do idr=1,nrlevs
            if (swtopdislay(idr) == 1)  then
               if (dramet == 2) then
                  zTopDisLay(idr) = fTopDisLay(idr) * ((gwlev-zbotdr(idr))/shape+zbotdr(idr)) + (1.0d0 - fTopDisLay(idr)) * zbotdr(idr)
               else
                  zTopDisLay(idr) = fTopDisLay(idr) * gwlev + (1.0d0 - fTopDisLay(idr)) * (gwlev-diffl(idr))
               end if
            end if
         end do
      end if
      if (swdislay == 1 .OR. swdislay == 2) then
         do idr=1,nrlevs
            if (swtopdislay(idr) == 1)  then
               ! Find node nr of new top of discharge layer
               icpTopDisLay = 1
               dzhlp        = - dz(1)
               do while (zTopDisLay(idr) < dzhlp)
                  icpTopDisLay = icpTopDisLay + 1
                  dzhlp        = dzhlp - dz(icpTopDisLay)
               end do
               ! Saturated part (difzTopDisLay) of compartment containing waterlevel
               difzTopDisLay = zTopDisLay(idr) - dzhlp
               ratiodz       = difzTopDisLay/dz(icpTopDisLay)
               sumqdr        = ratiodz * qdra(idr,icpTopDisLay)
               do icp = icpTopDisLay+1,numnod
                  sumqdr     = sumqdr + qdra(idr,icp)
               end do
               if (abs(sumqdr) < 1.0d-8) then
                  ratio = 1.0d0
               else
                  ratio = qdrain(idr) / sumqdr
               end if
               ! Redistribute drainwater fluxes
               do icp = 1,icpTopDisLay-1
                  qdra(idr,icp) = 0.0d0
               end do           
               qdra(idr,icpTopDisLay) = qdra(idr,icpTopDisLay) * ratio * ratiodz
               do icp = icpTopDisLay+1,numnod
                  qdra(idr,icp) = qdra(idr,icp) * ratio
               end do    
               
               if (abs(sumqdr) < 1.d-8 .AND. abs(qdrain(idr)) > 1.d-8) then
                  qdra(idr,icpTopDisLay) = qdrain(idr)
               end if         
            end if
         end do           
      end if        

contains

! ----------------------------------------------------------------------
      SUBROUTINE Lev2Comp(lev,icplev,dzabvlev,dzblwlev)
! ----------------------------------------------------------------------
!     Purpose            : Find Compartment with Level and its part
!                          Above and Under this Level  
! ----------------------------------------------------------------------
      use MOD_grid,   only: numnod, zbotcp, dz
      IMPLICIT NONE

      integer, intent(out) :: icplev
      real(8), intent(in)  :: lev
      real(8), intent(out) :: dzabvlev, dzblwlev

      ! Find number Compartment containing Level
      icplev = 1
      do while (lev > -zbotcp(icplev)+1.d-10)
         icplev = icplev + 1
         if (icplev > numnod) call swap_error ('lev2comp', 'icplev > numnod')
      end do

      ! Part of compartment below / above level
      dzblwlev = -zbotcp(icplev) - lev
      dzabvlev = dz(icplev) - dzblwlev

      return
      end SUBROUTINE Lev2Comp

      end SUBROUTINE DIVDRA

end submodule SMOD_divdra
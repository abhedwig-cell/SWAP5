module MOD_macropore

   use MOD_arrays, only: maho, madm, madr
   use MOD_swap_mp

   implicit none
   
! --- Macropore input parameters
   integer,                       save :: SwBma           = 0       ! Switch for output file with detailed yearly macropore water balance *.BMA: 0 = no; 1 = yes
!
   integer,                       save :: swabs           = 1       ! Type of absorption considered (1: original, 2: updated)
   integer,                       save :: swsep           = 1       ! Type of seepage considered (1: original, 2:updated)
   integer,                       save :: SwDarcy         = 0       ! Switch for eliminating Darcy flow unsaturated zone: 0 = eliminate; 1 = do not eliminate
   integer,                       save :: SwPowM          = 0       ! Switch for double convex/concave freq. distr. curve: 0 = no; 1 = yes
   integer, dimension(maho),      save :: SwShrInp        = 1       ! Switch for determining shrinkage curve: 1 = parameters given; 2 = typical points given
   integer, dimension(maho),      save :: SwSoilShr       = 0       ! Switch for kind of soil for determining shrinkage curve: 0 = rigid soil, 1 = clay, 2 = peat
   integer, dimension(maho),      save :: SwSorp          = 1       ! Switch for kind of sorptivity function: 1 = Parlange, 2 = empirical
!
   integer,                       save :: NumSbDm         = 0       ! Number of Subdomains in IC domain (-)
!
   real(8),                       save :: DiPoMa          = 0.d0    ! Maximal diameter soil polygones (deep) (L) 
   real(8),                       save :: DiPoMi          = 0.d0    ! Minimal diameter soil polygones (shallow) (L) 
   real(8), dimension(maho),      save :: GeomFac         = 3.d0    ! Geometry factor for (an)isotropic shrinkage (-)
   real(8),                       save :: nkwt            = 0.d0    ! Kinematic exponent, if swmbf == 2 (-)
   real(8),                       save :: PowM            = 1.d0    ! Power M for frequency distribut. curve IC domain (-)   
   real(8),                       save :: PpIcSs          = 0.d0    ! Proportion of IC domain at Soil Surface (-)
   real(8),                       save :: RapDraReaExp    = 0.d0    ! Reaction coefficient for rapid drainage (-)
   real(8), dimension(madr),      save :: RapDraResRef    = 0.d0    ! Reference rapid drainage resistance (T-1)  
   real(8),                       save :: Rzah            = 0.d0    ! Fraction macropores ended at bottom A-horizon (-)
   real(8),                       save :: ShapeFacMp      = 0.d0    ! Shape factor for description of macropore water exchange with matrix (-)
   real(8), dimension(maho),      save :: SorpAlfa        = 0.d0    ! Fitting parameter for emperical sorptivity curve (-)
   real(8), dimension(maho),      save :: SorpMax         = 0.d0    ! Maximal sorptivity at theta residual (L/T^0.5)
   real(8), dimension(maho),      save :: SorpFacParl     = 0.d0    ! Factor for modifying Parlange function (-)
   real(8), dimension(maho),      save :: ShrParA         = 0.d0    ! Parameter 1 for describing shrinkage curve (depending on SWSoilShr and SwShrInp)
   real(8), dimension(maho),      save :: ShrParB         = 0.d0    ! Parameter 2 for describing shrinkage curve (depending on SWSoilShr and SwShrInp)
   real(8), dimension(maho),      save :: ShrParC         = 0.d0    ! Parameter 3 for describing shrinkage curve (depending on SWSoilShr and SwShrInp)
   real(8), dimension(maho),      save :: ShrParD         = 0.d0    ! Parameter 4 for describing shrinkage curve (depending on SWSoilShr and SwShrInp)
   real(8), dimension(maho),      save :: ShrParE         = 0.d0    ! Parameter 5 for describing shrinkage curve (depending on SWSoilShr and SwShrInp)
   real(8),                       save :: Spoint          = 0.d0    ! Symmetry Point for freq. distr. curve (-)
   real(8), dimension(maho),      save :: ThetCrMp        = 0.d0    ! Critical volumetric water content below which cracks are formed (L^3/L^3)
   real(8),                       save :: VlMpStSs        = 0.d0    ! Volume of Static Macropores at Soil Surface (L^3/L^3)
   real(8),                       save :: Z_Ah            = 0.d0    ! Depth bottom A-horizon (L)
   real(8),                       save :: Z_Ic            = 0.d0    ! Depth bottom Internal Catchment (IC) domain (L)
   real(8),                       save :: Z_MB50          = 0.d0    ! Depth where static volume of MB domain has decreased to half of original(L) ! Adaptation 4 for PEARL-MACRO  
   real(8),                       save :: Z_St            = 0.d0    ! Depth bottom Static macropores (L)
   real(8),                       save :: Z_Tp            = 0.d0    ! Depth Top macropores (L)   
   real(8),                       save :: ZDiPoMa         = 0.d0    ! Depth below which diameter of soil polygons is maximum (L)
   real(8),                       save :: ZnCrAr          = 0.d0    ! Depth at which crack area of soil surface is calculated (L)
   
! --- Macropore variables
   logical, dimension(madm,macp), save :: FlEndSrpEvt     = .TRUE.  ! Flag indicating the end of a sorptivity event
   
   integer, dimension(madm),      save :: ICpBtDm         = 0       ! Compartment number containing actual bottom depth of domain (-)
   integer, dimension(madm),      save :: ICpBtDmM1       = 0       ! Compartment number containing bottom depth of domain of previous time step (-)
   integer, dimension(madm),      save :: ICpBtDmPot      = 0       ! Compartment number containing potential bottom depth of domain (-) 
   integer,                       save :: ICpBtPerZon     = 0       ! Bottom compartment of perched groundwater table (-)
  ! integer,                       save :: ICpSatGWl       = 0       ! Top compartment of saturated zone (-)
  ! integer,                       save :: ICpSatPeGWL     = 0       ! Top compartment of perched groundwater table (-)
   integer,                       save :: ICpTpPerZon     = 0       ! Top compartment of perched groundwater table (-)
   integer,                       save :: ICpTpSatZon     = 0       ! Top compartment of saturated zone (-)
   integer, dimension(madm),      save :: ICpTpWaSrDm     = 0       ! Compartment number containing  top of water saturated domain (-)
   integer,                       save :: NnCrAr          = 0       ! Compartment number for calculating crack area at soil surface
   integer,                       save :: NumDm           = 0       ! Number of macropore domains (-)     
   integer,                       save :: bma             = 0       ! Internal number of output file *.BMA with detailed yearly water balance in case of macropores
!
   real(8),                       save :: ArMpTp          = 0.d0    ! Macropore area at top layer macropores (dynamic). (L)
   real(8), dimension(madm),      save :: ArMpTpDm        = 0.d0    ! Area at top of macropores, per domain (L)
   real(8), dimension(macp),      save :: AwlCorFac       = 0.d0    ! Factor for correcting vertical area wall for sorptivity calculations (-)
   real(8), dimension(madm,macp), save :: CDarcy          = 0.d0    ! Constant in MP-matrix exchange for saturated conditions (1/LT)
   real(8), dimension(maho),      save :: DiMtxSat        = 0.d0    ! Maximum diffusivity at saturation corresponding to h_entry (if swabs == 2)
   real(8), dimension(madm,macp), save :: FrMpWalWet      = 0.d0    ! Fraction of macropore wall in contact with water (-)
   real(8), dimension(madm,macp), save :: FrMpWalWetOld   = 0.d0    ! Fraction of macropore wall in contact with water (-), previous timestep
   real(8),                       save :: FrReduQ         = 0.d0    ! Reduction factor in case of non-convergence (-)
   real(8), dimension(madr),      save :: KDCrRlRef       = 0.d0    ! Reference kD for rapid drainage, per drainage level 
   real(8),                       save :: KsatCovLay      = 0.d0    ! Saturated conductivity of bottom compartment of covering layer (L/T)
   real(8), dimension(madm,macp), save :: PpDmCp          = 0.d0    ! Volumetric proportion of macropore domain per compartment (-)
   real(8), dimension(madm,macp), save :: QExcMtxDmCp     = 0.d0    ! Water exchange between matrix and domain, per domain and compartment (L/T)
   real(8), dimension(madm,macp), save :: QInIntSatDmCp   = 0.d0    ! Horizontal inflow flux from perched zone matrix to MP (L/T)
   real(8), dimension(madm,macp), save :: QInMtxSatDmCp   = 0.d0    ! Horizontal inflow flux from saturated zone matrix to MP (L/T)
   real(8), dimension(madm),      save :: QInTopLatDm     = 0.d0    ! Lateral overland flow flux into macropores per domain (L/T)
   real(8),                       save :: QInTopLatDm1    = 0.d0    ! Lateral overland flow flux into macropores of domain 1 (MB) (L/T)
   real(8),                       save :: QInTopLatDm2    = 0.d0    ! Lateral overland flow flux into macropores of domain 2 (IC) (L/T)
   real(8), dimension(madm),      save :: QInTopVrtDm     = 0.d0    ! Vertical inflow flux at top of zone with macropores into macropores per domain (L/T)
   real(8),                       save :: QInTopVrtDm1    = 0.d0    ! Vertical inflow flux at top of zone with macropores into macropores of domain 1 (MB) (L/T)
   real(8),                       save :: QInTopVrtDm2    = 0.d0    ! Vertical inflow flux at top of zone with macropores into macropores of domain 2 (IC) (L/T)
   real(8), dimension(macp),      save :: QOutDrRapCp     = 0.d0    ! Horizontal outflow flux from saturated MP to rapid drainage system (L/T)
   real(8), dimension(madm,macp), save :: QOutMtxSatDmCp  = 0.d0    ! Horizontal outflow flux from saturated MP to saturated matrix (L/T)
   real(8), dimension(madm,macp), save :: QOutMtxUnsDmCp  = 0.d0    ! Water outflow out of domain due to exchange with unsaturated matrix (L/T)
   real(8), dimension(madm,macp), save :: QTopMpDmCp      = 0.d0    ! Flux over top of compartment, per domain (L/T)
   real(8), dimension(madm,macp), save :: SorpDmCp        = 0.d0    ! Philips sorptivity at start of sorption event 
   real(8), dimension(macp),      save :: SubsidCpMin     = 0.d0    ! Minimal subsidence volume per compartment based on ThetCrMp(MaHo) (L)
   real(8), dimension(madm,macp), save :: ThtSrpRefDmCp   = 0.d0    ! Lateral absorption of water from the macropore to the matrix 
   real(8), dimension(madm,macp), save :: TimAbsCumDmCp   = 0.d0    ! Cumulative duration of a sorption event
   real(8),                       save :: VlMp            = 0.d0    ! Total macropore volume (L)
   real(8), dimension(madm),      save :: VlMpDm          = 0.d0    ! Volume of macropores per domain
   real(8), dimension(madm,macp), save :: VlMpDmCp        = 0.d0    ! Total macropore volume per domain, per compartment (L)
   real(8), dimension(madm,macp), save :: VlMpDmCpM1      = 0.d0    ! Total macropore volume per domain, per compartment, of previous time step (L)
   real(8), dimension(macp),      save :: VlMpStCp        = 0.d0    ! Static macropore volume per compartment (L)
   real(8),                       save :: WaSrMp          = 0.d0    ! Water stored in macropores (L)
   real(8), dimension(madm),      save :: WaSrMpDm        = 0.d0    ! Water stored in MP domain (L)
   real(8), dimension(madm),      save :: WaUnsat         = 0.d0    ! Water stored in unsaturated part of compartment with MP gwl (L)
   real(8), dimension(madm),      save :: WaUnMpDm        = 0.d0    ! Water stored in MP domain (L)
   real(8), dimension(madm,macp), save :: WaUnMpDmCp      = 0.d0    ! Water stored in MP domain per compartment (L)
   real(8), dimension(madm,macp), save :: WaUnMpDmCpM1    = 0.d0    ! Water stored in MP domain per compartment, for time t (L)
   real(8), dimension(madm),      save :: ZBtDm           = 0.d0    ! Depth of bottom of domain (L)
   real(8), dimension(madm),      save :: ZWaLevDm        = 0.d0    ! Water level in MP domain (L)

   public 
   
   public :: macrostatevar, macropore
   
   contains
    
!************************************************************************
      subroutine MACROPORE (ITask)
! ----------------------------------------------------------------------
!     Date               : 22/08/02                                        
!     Purpose            : Calculation of macropore volume, vertical flow into 
!                          and through macropores, lateral exchange of water 
!                          between macropores and soil matrix, and 
!                          rapid drainage via macropore (crack) system 
!     Subroutines called : MACROGEOM, MACROINIT, MACROSTATE                            
!     Functions called   : -
!     File usage         : -           
! ----------------------------------------------------------------------
      use MOD_grid,      only: numlay, nod1lay, numnod
      use MOD_MvG,       only: cofgen
      use variables,     only: fluseksatexm, volact, volini, ivolbeg

      implicit NONE
      logical,external :: native09_pending
      integer, intent(in)  :: itask
! ----------------------------------------------------------------------
! --- local
      integer lay, nod

!     save local variables
      save    

! ----------------------------------------------------------------------
      select case (itask)
      case (1)

!  -- Input check
      do lay = 1, NumLay
         if (SwSoilShr(lay) > 0 .AND. ThetCrMp(lay) > CofGen(2,nod1lay(lay))) call swap_error('macropore', 'THETCRMP > THETSAT')
         ! if (fluseksatexm(lay) .AND. cofgen(3,nod1lay(lay)) >= cofgen(10,nod1lay(lay)) ) call swap_error('macropore', 'Ksatexm <= Ksatfit')
         ! if (swabs == 2 .AND. cofgen(5,nod1lay(lay)) < -cofgen(32,nod1lay(lay)) ) call swap_error('macropore', 'Lexp < -1/m') 
      end do
      
      if (swmbf == 2) then
         do nod = 1, numnod
            if (.NOT. fluseksatexm(nod)) call swap_error('macropore', 'Ksatexm <= Ksatfit')
         end do
      end if         
!
!- A. INITIAL CALCULATIONS
!  -- Determine macropore geometry (incl. static macropore volume)
      call MACROGEOM ()

!  -- Initial calculations
      call MACROINIT ()

!  -- Calculate INITIAL dynamic macropore (crack) volume, total macropore volume
!     per domain and per compartment, and area of macropores at soil surface
      ICpTpSatZon = NodGwlFlCpZo
      if (.not.native09_pending()) then
      call MACROSTATE ()
      
      FrMpWalWetOld(1:numdm,IcTopMp:NumNod) = FrMpWalWet(1:numdm,IcTopMp:NumNod)
      end if
      call native09_macro()

!  -- Calculate initial waterstorage in matrix on basis FrArMtrx 
      volact = 0.0d0
      call watstor ()
      volini = volact
      ivolbeg = volact

!  -- Initialisation of intermediate and cumulative values
      call MACRORESET (0)

      return

      case (2)
!- B. DYNAMICAL CALCULATIONS (within TIME STEP LOOP)
!  -- Calculations of Rates: 
      call MACRORATE (1)
      return

      case (3)
!  -- Calculations of derivatives dFdhMp:
      call MACRORATE (2)
      return

      case (4)
!  -- Calculation of States
!     Calculate dynamic macropore (crack) volume, total macropore volume
!     per domain and per compartment, and area of macropores at soil surface, etc.
      call MACROSTATE ()

!  -- integration of Cumulative and Intermediate values
      call MACROINTEGRAL () 
      return

      case (5)
!  -- reset intermediate soil water fluxes
      call MACRORESET (1)
      return

      case (6)
!  -- reset cumulative soil water fluxes
      call MACRORESET (2)

      case default
         call swap_error ('macropore', 'Illegal vsalue for TASK')
      end select
      
      return
      end subroutine Macropore

!=======================================================================
      SUBROUTINE MACROGEOM ()
! ----------------------------------------------------------------------
!     Date               : 26/06/02                                        
!     Purpose            : Geometry of macropore volume. 
!                          Calculation per compartment of:
!                          1. Proportion PpDmCp of macropore volume in Main 
!                             Bypass flow domain and Internal Catchment domains
!                          2. Static macropore volume VlMpStCp
!     Subroutines called : DEFINECOMPART                              
!     Functions called   : -
!     File usage         : -           
! ----------------------------------------------------------------------
      use MOD_arrays,    only: macp
      use MOD_grid,      only: dz, z, layer, numnod
      use variables,     only: ksatfit

      implicit NONE

! ----------------------------------------------------------------------
! --- local
      integer ic, id, IdNx(MaCp+4), jd, Lay, NumCpXtr, NumHlp, NumSbDmCp
      real(8)  Alfa, AlfaSt, Beta, BetaSt, DzAhIc, DzCp,DzIcSt
      real(8)  NmZbot, NmZtop, NnZbot, NnZtop, Pm, PowMb50, PpIcCp(MaCp)
      real(8)  PpMbSs, Sm, RelVlIc(MaCp), RelVlIcSt(MaCp), RelVlIcTo 
      real(8)  RelVlMb(MaCp), RelVlMbSt(MaCp), UnPpIc, Zbot(MaCp+4), Zmid
      real(8)  Ztop(MaCp+4), Z_Sp, ZzTpBt

! ----------------------------------------------------------------------
!
!--- Mb =  Main Bypass flow; Ic = Internal Catchment
!
!- A. INITIAL CALCULATIONS:
!
!   - Check whether macropores start at soil surface or under a covering layer at depth Z_Tp.
!     If covering layer: use Z_Ah to extrapolate values at soil surface to depth Z_Tp where macropores start
      if (Z_Tp < -0.5d0*dz(1)) then    
         Z_Tp = min(Z_Tp,-1.d0)
         Z_Ah = Z_Tp
         Rzah = 0.d0
!     Find top compartment with macropores
         ic = 1
         do while (Z_Tp < z(ic))
            ic = ic + 1
         end do    
         IcTopMp = ic
         Lay     = Layer(ic-1)
         KsatCovLay = ksatfit(Lay)   
      else
         Z_Tp    = 0.d0
         IcTopMp = 1
      end if

!   - limit the value of Rzah (R-value at bottom of A-horizon)
      if (Rzah > 0.99d0) Rzah = 1.d0
      if (Rzah < 1.d-2)  Rzah = 0.d0
!   - SPoint = (nearly) 0 has same function as = 1 and gets value 1 for calculations  
      if (SPoint < 1.0d-2) SPoint= 1.d0

!   - depth Z of top and bottom of each compartment (z = negative; dz= positive)
      Ztop(1) = 0.d0
      Zbot(1) = -DZ(1)
      do ic= 2, NumNod
         Ztop(ic) = Zbot(ic-1)
         Zbot(ic) = Ztop(ic) - Dz(ic)
      end do

!   - Optional exponent PowMb50 for non-linear decline with depth of Mb domain
      if (dabs(Z_MB50-Z_St) < 1.d-12) then
         PowMb50 = 1.0d-12
      else if (dabs(Z_MB50-Z_Ic) < 1.d-12) then
         PowMb50 = 1.0d12
      else
         PowMb50 = dlog(0.5d0) / dlog( (Z_MB50-Z_St)/((Z_IC-Z_St)) )
      end if

!   - define temporary compartments for calculation of macropore geometry
      call DEFINECOMPART(Zbot,Ztop,NumCpXtr,IdNx,Z_Sp)

!- B. CALCULATION OF PpIcCp AND VlMpStCp 
!     PpIcCp= ProPortion of Ic domain; VlMpStCp= STatic VoLume MacroPores                         
!  -- initialize RELative VoLumes
      RelVlMb(1:numnod)   = 0.d0
      RelVlMbSt(1:numnod) = 0.d0
      RelVlIc(1:numnod)   = 0.d0
      RelVlIcSt(1:numnod) = 0.d0

!  -- integration of the relative volume curves over the NEW compartm. thickness
      do ic= 1, NumNod+NumCpXtr

!   - define help Z's for integration(Z= negative!): 
         Zmid      = (Ztop(ic)+Zbot(ic))/2.d0
         DzCp      = Ztop(ic) - Zbot(ic)
         if (Zmid < Z_Ah .AND. Zmid > Z_Ic) then
            DzAhIc = Z_Ah - Z_Ic
!   - NorMalised Ztop and Zbot between Z_Ah and Z_Ic
            NmZtop = dmax1(0.d0,(Z_Ah - Ztop(ic)))/DzAhIc
            NmZbot = (Z_Ah - Zbot(ic))/DzAhIc
         else if (Zmid < Z_Ic .AND. Zmid > Z_St) then
            DzIcSt = Z_Ic - Z_St
!   - NorMalised Ztop and Zbot between Z_Ic and Z_St
            NnZtop = dmax1(0.d0,(Z_Ic - Ztop(ic)))/DzIcSt
            NnZbot = (Z_Ic - Zbot(ic))/DzIcSt
         end if
         ZzTpBt    = Ztop(ic) + Zbot(ic)

!   - integrate relative volume curves of Mb domain over compartment thickness: 
!     Alfa for calculation of PpIcCp, and AlfaSt for Mb domain part of VlMpStCp
         if (Zmid > Z_Ic) then
            Alfa = DzCp
         else if (Zmid > Z_St) then
            Alfa = DzIcSt / (PowMb50+1.d0) * ((1.d0-NnZtop)**(PowMb50+1.d0) - (1.d0-NnZbot)**(PowMb50+1.d0))
!            Alfa= DzCp * (ZzTpBt - 2.d0*Z_St)/(2.d0*(Z_Ic-Z_St))
         else
            Alfa = 0.d0
         end if
         AlfaSt  = Alfa
!   - no static volume below Z_St (also if Z_St > Z_Ic)
!     (criterium: depth Z of ORIGINAL node deeper than Z_St)
         if (Z(IdNx(ic)) < Z_St) AlfaSt = 0.d0

!   - integrate relative volume curves of Ic domain over compartment thickness: 
!     Beta for calculation of PpIcCp, and BetaSt for Ic domain part of VlMpStCp
         if (Zmid > Z_Ah) then
            Beta    = DzCp * (1.d0 - ZzTpBt*Rzah/(2.d0*Z_Ah))
         else if (Zmid > Z_Ic) then
            if (Zmid > Z_Sp) then
               Sm   = (Spoint**(1.d0-PowM))/(PowM+1.d0)
               Beta = (1.d0-Rzah) * (DzCp + DzAhIc*Sm*(NmZtop**(PowM+1.d0) - NmZbot**(PowM+1.d0)))
            else 
               Pm   = PowM
               if (SwPowM == 1) Pm = 1.d0/PowM
               Sm   = ((1.d0-Spoint)**(1.d0-Pm))/(Pm+1.d0)
               Beta = (1.d0-Rzah) * (DzAhIc*Sm*((1.d0-NmZtop)**(Pm+1.d0) -(1.d0-NmZbot)**(Pm+1.d0)))
            end if
         else
            Beta    = 0.d0
         end if
!   - no IC volume below Z_Ic (criterium: depth Z of ORIGINAL node below Z_Ic)
        if (Z(IdNx(ic)) < Z_Ic) Beta = 0.d0
         BetaSt     = Beta
!   - no static volume below Z_St (also if Z_St > Z_Ic) (crit: ORIG Z below Z_St)
         if (Z(IdNx(ic)) < Z_St) BetaSt = 0.d0

!   - calculate for ORIGINAL compartments RELative VoLume of macropores
!     (cm3 per cm2 of unit horizontal area; because of integration over Dz)
!     - Mb domain (PpIcSs= PpIcCp at Soil Surface)
         PpMbSs              = 1.d0 - PpIcSs
         RelVlMb(IdNx(ic))   = RelVlMb(IdNx(ic))   + Alfa  *PpMbSs
         RelVlMbSt(IdNx(ic)) = RelVlMbSt(IdNx(ic)) + AlfaSt*PpMbSs
!     - Ic domain
         RelVlIc(IdNx(ic))   = RelVlIc(IdNx(ic))   + Beta  *PpIcSs
         RelVlIcSt(IdNx(ic)) = RelVlIcSt(IdNx(ic)) + BetaSt*PpIcSs
      end do

!  -- calculation PpIcCp and VlMpStCp for the ORIGINAL compartments
      do ic = 1, NumNod
!   - propotion PpIcCp of Ic domain
         if (RelVlIc(ic) > 0.d0) then
            PpIcCp(ic) = RelVlIc(ic) / (RelVlMb(ic) + RelVlIc(ic))
         else
            PpIcCp(ic) = 0.d0
         end if
!   - static macropore volume VlMpStCp (VlMpStSs= VlMpStCp at Soil Surface)
!     in cm3 per cm2 of unit horizontal area
         VlMpStCp(ic) = VlMpStSs * (RelVlMbSt(ic) + RelVlIcSt(ic)) 
!   - fraction of unit of horizontal area that is left for soil matrix after 
!     substraction of static macropores
         FrArMtrx(ic) = 1.d0 - VlMpStCp(ic)/Dz(ic)
      end do

!- C. CALCULATION OF VOLUMETRIC PROPORTIONS PER COMPARTMENT FOR THE MP DOMAINS 
      if (PpIcSs > 0.d0) then 
         if (Rzah < 0.991d0) then
!   - NumDm (number of domains) = 1 Mb domain + NumSbDm Ic subdom. (+ 1 Ah dom.) 
            NumDm                        = NumSbDm + 1
            if (Rzah > 1.d-3) NumDm      = NumDm + 1
            UnPpIc                       = PpIcSs*(1.d0-Rzah) / dble(NumSbDm)
            do ic = 1, NumNod
               if (PpIcCp(ic) > 1.0d-3) then
                  NumSbDmCp              = idint(RelVlIc(ic)/(UnPpIc*Dz(ic)))
                  NumSbDmCp              = min0(NumSbDm,NumSbDmCp)
!   - PpDmCp: ProPortion per compartment per DoMain ; index 1 = Mb domain 
                  PpDmCp(1,ic)           = 1.d0 - PpIcCp(ic) 
                  do id = 2, NumSbDmCp+1
                     PpDmCp(id,ic)       = PpIcCp(ic)*UnPpIc*Dz(ic)/RelVlIc(ic)
                  end do
                  RelVlIcTo              = dble(NumSbDmCp)*UnPpIc*Dz(ic)
                  PpDmCp(NumSbDmCp+2,ic) = PpIcCp(ic) * (1.d0-RelVlIcTo/RelVlIc(ic))
                  do id= NumSbDmCp+3, NumDm
                     PpDmCp(id,ic)       = 0.d0
                  end do
               else
!   - no IC-domain, no SUBdomains
                  PpDmCp(1,ic)       = 1.d0
                  PpDmCp(2:numdm,ic) = 0.d0
                  if (ic == 1) NumDm = 1
               end if
            end do
         else
!   - only one SUBdomain within the IC-domain: the Ah domain
            NumDm              = 2
            PpDmCp(1,1:numnod) = 1.d0 - PpIcCp(1:numnod)
            PpDmCp(2,1:numnod) = PpIcCp(1:numnod)
         end if
      else
!   - no IC-domain
         NumDm              = 1
         NumSbDm            = 0
         PpDmCp(1,1:numnod) = 1.d0
      end if

!- Only when IC-domains are present 
      ICpBtDmPot(1) = NumNod
      if (NumSbDm > 0) then
!- D. LUMPING OF IC SUBDOMAINS THAT END IN THE SAME COMPARTMENT
!  -- determine for each domain: POTential bottom (= deepest) compartment number 
!     with macropore volume(ICpBtDmPot) 
      do id = 2, NumDm
         ic = 1
         do while(PpDmCp(id,ic) > 0.d0 .AND. ic <= NumNod)
            ic = ic + 1
         end do
         ICpBtDmPot(id) = ic - 1
      end do

!  -- lumping of PpDmCp
      NumHlp = NumDm
      if (Rzah > 1.d-3) NumHlp = NumHlp - 1
      do id = NumHlp, 3, -1
         if (ICpBtDmPot(id) == ICpBtDmPot(id-1)) then
            do ic = 1, ICpBtDmPot(id)
               PpDmCp(id-1,ic) = PpDmCp(id-1,ic) + PpDmCp(id,ic) 
            end do
            do jd = id, NumDm-1
               do ic= 1, ICpBtDmPot(jd)
                  PpDmCp(jd,ic)   = PpDmCp(jd+1,ic)
                  PpDmCp(jd+1,ic) = 0.d0
               end do
               ICpBtDmPot(jd) = ICpBtDmPot(jd+1)
            end do
            NumDm = NumDm - 1
         end if
      end do

!  -- lump Ah domain only when neighbour domain < 0.5 Ah domain
      if (NumDm > 1 .AND. Rzah > 1.d-3 .AND. PpDmCp(NumDm,1) > 2.d0*PpDmCp(NumDm-1,1)) then
         if (ICpBtDmPot(NumDm) == ICpBtDmPot(NumDm-1)) then
            do ic = 1, ICpBtDmPot(NumDm)
               PpDmCp(NumDm-1,ic) = PpDmCp(NumDm-1,ic) + PpDmCp(NumDm,ic)
               PpDmCp(NumDm,ic)   = 0.d0
            end do
            NumDm = NumDm - 1
         end if
      end if
      do id = NumDm+1, NumSbDm+1
         ICpBtDmPot(id) = 0
      end do
!
      end if


!- E. DELETE macropore volumes and proportions of compartments in case of a top layer
!     without macropores  
!     No top layer without macropores: return
      if (IcTopMp > 1) then      
!     Top layer without macropores present:
         do ic = 1, IcTopMp-1
            PpIcCp(ic)         = 0.d0
            VlMpStDm1(ic)      = 0.d0
            VlMpStDm2(ic)      = 0.d0
            VlMpStCp(ic)       = 0.d0
            PpDmCp(1:numdm,ic) = 0.d0
            FrArMtrx(ic)       = 1.d0
         end do
      end if

!- F. DETERMINE DiPoCp, first calculation: DIameter of soil matrix POlygon per  
!     ComPartment as a function of macropore density MpDs with depth
      do ic= IcTopMp, NumNod
         DiPoCp(ic) = DiamPolyg(DiPoMa,DiPoMi,Dz(ic),PpIcCp(ic),PpIcSs,    &
                          VlMpStCp(ic),VlMpStSs,Z(IcTopMp),Z(ic),ZDiPoMa)
      end do

!- G. DETERMINE DiPoCp, final calculation for macropores below Z_ic
      do ic = ICpBtDmPot(2)+1, NumNod
         DiPoCp(ic) = DiamPolyg(DiPoMa,DiPoMi,Dz(ic),PpIcCp(ic),PpIcSs,    &
                          VlMpStCp(ic),VlMpStSs,Z(IcTopMp),Z(ic),ZDiPoMa)
      end do

!- H. DETERMINE VlMpStDm1(ic) and -Dm2(ic): VoLume of STatic MacroPores per
!     compartment for DoMain 1 (Main Bypass) and 2 (Internal Catchment)
      do ic = IcTopMp, NumNod
         VlMpStDm1(ic) = PpDmCp(1,ic) * VlMpStCp(ic)
         VlMpStDm2(ic) = 0.d0
         VlMpStDm2(ic) = VlMpStDm2(ic) + sum(PpDmCp(2:numdm,ic)) * VlMpStCp(ic)
      end do

! ---
      
      return
      end subroutine MacroGeom

!.......................................................................
      SUBROUTINE DEFINECOMPART (Zbot,Ztop,NumCpXtr,IdNx,Z_Sp)
!     Date               : 15/05/02                                        
!     Purpose            : Defining of temporary extra compartments based on the 
!                          depths of Z_Ah, Z_Ic, Z_St and Z_Sp, and temporary
!                          renumbering of the total of compartments            
!     Subroutines called : -                             
!     Functions called   : -
!     File usage         : -                                           
! ----------------------------------------------------------------------
      use MOD_arrays,    only: macp
      use MOD_grid,      only: numnod

      implicit NONE

! --- global                                                         In
      real(8), intent(inout)  :: Zbot(MaCp+4), Ztop(MaCp+4)

!     -                                                              Out
      integer, intent(out) :: IdNx(MaCp+4), NumCpXtr
      real(8), intent(out) :: Z_Sp
! ----------------------------------------------------------------------
! --- local
      integer ic, ix, jx
      real(8) Zhlp, Zz(4)
      logical FlagCpXtr(4)
! ----------------------------------------------------------------------
! --- Initialize. NumCpXtr= NUMber of temporary eXTRa ComPartments (nodes)
      NumCpXtr       = 4
      FlagCpXtr(1:4) = .FALSE.

! --- Set minimal depth of Z_Ah, Z_Ic, Z_St
      Z_Ah = dmin1(Z_Ah,Zbot(1))
      Z_Ic = dmin1(Z_Ah,Z_Ic)
      Z_St = dmin1(Z_Ah,Z_St)

! --- Depth Z_Sp of Spoint
      Z_Sp = Z_Ah - Spoint*(Z_Ah-Z_Ic) 

! --- Merge Z_Ah, Z_Ic and/or Z_Sp if difference in depth < 0.1 cm.
!     if Z is merged: NumCpXtr is decreased
      if (abs(Z_Ah-Z_Ic) < 0.1d0) then
         Z_Ic         = Z_Ah
         Z_Sp         = Z_Ah
         NumCpXtr     = 2
         FlagCpXtr(2) = .TRUE.
         FlagCpXtr(3) = .TRUE.
      else if (abs(Z_Ah-Z_Sp) < 0.1d0) then
         Z_Sp         = Z_Ah
         NumCpXtr     = 3
         FlagCpXtr(2) = .TRUE.
      else if (abs(Z_Ic-Z_Sp) < 0.1d0) then
         Z_Sp         = Z_Ic
         NumCpXtr     = 3
         FlagCpXtr(2) = .TRUE.
      end if

! --- Merge Z_St and Z_Ah, Z_Ic and/or Z_Sp if difference in depth < 0.1 cm
!     if Z_St is merged: NumCpXtr is decreased
      if (abs(Z_St-Z_Ah) < 0.1d0 .OR. abs(Z_St-Z_Sp) < 0.1d0 .OR. abs(Z_St-Z_Ic) < 0.1d0) then
         if (abs(Z_St-Z_Ah) < 0.1d0) Z_St = Z_Ah
         if (abs(Z_St-Z_Sp) < 0.1d0) Z_St = Z_Sp
         if (abs(Z_St-Z_Ic) < 0.1d0) Z_St = Z_Ic
         NumCpXtr     = NumCpXtr - 1
         FlagCpXtr(4) = .TRUE.
      end if

! --- Initialize help array Zz
      Zz(1) = Z_Ah
      Zz(2) = Z_Sp
      Zz(3) = Z_Ic
      Zz(4) = Z_St

! --- Adjust Z_Ah, Z_Ic, Z_Sp and Z_St to Zbot, depth of bottom of existing 
!     compartment, if difference in depth < 0.1 cm.
!     If Z is adjusted: NumCpXtr is decreased (only when Z is not merged before)
!     If Z is adjusted: corresp. Zz is set to extreme value out of normal range
      ic   = 1
      Zhlp = dmin1(Z_Ic,Z_St)
      do while (Ztop(ic)-1.d-6 > Zhlp .AND. ic <= NumNod)
         do ix = 1, 4
            if (abs(Zbot(ic)-Zz(ix)) < 0.1d0) then
               if (ix == 1) Z_Ah = Zbot(ic)
               if (ix == 2) Z_Sp = Zbot(ic)
               if (ix == 3) Z_Ic = Zbot(ic)
               if (ix == 4) Z_St = Zbot(ic)
               Zz(ix)= -1.d6
               if (.NOT.FlagCpXtr(ix)) NumCpXtr = NumCpXtr - 1
            end if
         end do
         ic = ic + 1
      end do

! --- Put Zz(1) to Zz(4) in decreasing order, so that after ordening
!     only the first NumCpXtr values are relevant and unic values 
      do ix = 1, 3
         do jx = ix+1, 4
            if (Zz(ix) < Zz(jx)) then
               Zhlp   = Zz(ix)
               Zz(ix) = Zz(jx)
               Zz(jx) = Zhlp
            else if (abs(Zz(ix)-Zz(jx)) < 1.d-1) then
               Zz(jx) = -1.d6
            end if
         end do
      end do           

! --- Insert NumCpXtr number of temporary extra compartments, shift compartments 
!     and adjust Ztop and Zbot of relevant compartments. Set IdNx= index for all 
!     shifted/adjusted compartments, that represents the corresponding ID-number  
!     of the original compartment
      ic = NumNod
      do ix = NumCpXtr, 1, -1
         do while (Ztop(ic) < Zz(ix))
            Zbot(ic+ix) = Zbot(ic)
            Ztop(ic+ix) = Ztop(ic)
            IdNx(ic+ix) = ic
            ic          = ic - 1
         end do
         Zbot(ic+ix) = Zbot(ic)
         Ztop(ic+ix) = Zz(ix)
         Zbot(ic)    = Zz(ix)
         IdNx(ic+ix) = ic
      end do

! --- Set IdNx for all remaining compartments that are not adjusted
      do ix = 1, ic
         IdNx(ix) = ix
      end do

! --- Recalculate Spoint 
      if ((Z_Ah-Z_Ic) > 1.d0) then
         Spoint = (Z_Ah-Z_Sp) / (Z_Ah-Z_Ic)
      else
         Spoint = 1.d0
      end if       

      return
      end subroutine DefineCompart

!=======================================================================
      real(8) FUNCTION DiamPolyg (DiPoMa,DiPoMi,Dz,PpIcCp,PpIcSs,      &
                                 VlMpStCp,VlMpStSs,Z1,Z,ZDiPoMa)
! ----------------------------------------------------------------------
!     Date               : 15/10/08
!     Purpose            : calculate matrix polygon diameter
! ----------------------------------------------------------------------
      implicit NONE

! --- global
      real(8), intent(in) :: DiPoMa,DiPoMi,Dz,PpIcCp,PpIcSs,VlMpStCp,VlMpStSs
      real(8), intent(in) :: Z1,Z,ZDiPoMa 
! ----------------------------------------------------------------------
! --- local
      real(8) MpDs
! ----------------------------------------------------------------------
!
!     DIameter of soil matrix POlygon per ComPartment as a function of 
!     macropore density MpDs with depth
      if ((DiPoMa-DiPoMi) > 1.d-3) then
         if (VlMpStSs > 1.d-6) then
            MpDs = VlMpStCp / Dz / VlMpStSs
         else if (PpIcSs > 1.d-6) then
            MpDs = PpIcCp / PpIcSs
         else
            MpDs = dmax1(0.d0,1.d0-((Z1-Z)/(Z1-ZDiPoMa))) 
         end if
!
         DiamPolyg = DiPoMi + (DiPoMa-DiPoMi) * (1.0d0-MpDs)
      else
         DiamPolyg = DiPoMi
      end if

      return
      end function DiamPolyg

!=======================================================================
      SUBROUTINE MACROINIT ()
! ----------------------------------------------------------------------
!     Date               : 20/08/02                                        
!     Purpose            : Initialization of parameters for macropore 
!                          calculations 
!     Subroutines called : SHRINKPAR                              
!     Functions called   : watcon, SHRINK
!     File usage         : -           
! ----------------------------------------------------------------------
      use MOD_grid,      only: numnod, dz, z, numlay, layer, botcom, nod1lay
      use MOD_MvG,       only: watcon, paramvg
      use MOD_drain,     only: swdtyp
      use variables,     only: thetas, ksatfit

      implicit NONE
      logical,external :: native09_pending

! --- global                                                       

! ----------------------------------------------------------------------
! --- local
      integer ic, ICpBot, ICpBtMB, ICpHRef, icstart, id, il, ir, Itask
      real(8) DZTot, FrW, FrWet, HHydrStat, KCrRlRef, ThethydrStat
      real(8) VlMpDyRl, VlMpRl, VlShriRl, WdthCr, Zhlp
      real(8) Z_Bot, Zref
      real(8) alfamg, h_entr, m, s_enpr, oneoverm, wcsminwcr, lambda_adj
      real(8) relsat, help
      logical flRigid

! ----------------------------------------------------------------------
!
!- A. INITIALIZING VOLUMES OF MACROPORES AND WATER STORAGE IN MACROPORES
!     of lezen uit file met toestandsvariabelen...................
      if (.not.native09_pending()) then
      ICpBtDm(1:NumDm)     = NumNod
      ICpTpWaSrDm(1:NumDm) = NumNod + 1
      
      do id = 1, NumDm
         VlMpDmCp(id,1:numnod) = PpDmCp(id,1:numnod) * VlMpStCp(1:numnod) ! Note: initialized based on static MP volume only
      end do

! --- water volume in MP based on matrix gwl in case of static MP below matrix gwl
! --- assume no initial water in unsaturated macropore for kwt
      if (VlMpStCp(NodGwlFlCpZo) >= 1.d-7 .OR. NodGwlFlCpZo < IcTopMp) then
         Zhlp  = -sum(DZ(1:NodGwlFlCpZo))
         FrWet = dmax1(0.d0,(GWlFlCpZo-Zhlp)/DZ(NodGwlFlCpZo))
         do id = 1, NumDm
            do ic = ICpBtDmPot(id), NodGwlFlCpZo, -1
               FrW               = 1.d0
               if (ic == NodGwlFlCpZo) FrW = FrWet
               WaSrMpDm(id)      = WaSrMpDm(id) + FrW*VlMpStCp(ic)*PpDmCp(id,ic)
               WaUnMpDmCp(id,ic) = FrW*VlMpDmCp(id,ic)
            end do
            WaUnMpDm(id)      = WaSrMpDm(id)
         end do
         WaUnMpDmCpM1(1:numdm,1:numnod) = WaUnMpDmCp(1:numdm,1:numnod)
         
         WaUnMpDm1Cp(1:numnod) = WaUnMpDmCp(1,1:numnod)
         do id = 2, numdm
            WaUnMpDm2Cp(1:numnod) = WaUnMpDm2Cp(1:numnod) + WaUnMpDmCp(id,1:numnod)
         end do
         
      end if

      end if
!- B. DETERMINING NnCrAr (compartm. number for calcul. crack area at soil surf.)
      if (IcTopMp == 1) then
         ic = 1
         do while ((Z(ic)-0.5d0*Dz(ic)+1.d-2) > ZnCrAr)
            ic = ic + 1
         end do
         NnCrAr = ic
      else
         NnCrAr = IcTopMp
      end if

!- C. CALCULATION OF SHRINKAGE PARAMETERS
      do il = 1, NumLay
         if (SwSoilShr(il) /= 0) then      ! Non rigid soils: clay and peat
            Itask = 2*(SwSoilShr(il)-1) + SwShrInp(il)
         else                              ! Rigid soils
            Itask = 6
         end if

         call SHRINKPAR(itask, il)
!
! --- calculate minimal subsidence on the basis of boundary moisture content
!     for cracking ThetCrMp(il)
         VlShriRl = SHRINK(il,thetcrmp(il))
         icstart  = 1
         if (il > 1) icstart = botcom(il-1) + 1
         do ic = icstart, botcom(il)
            SubsidCpMin(ic) = VlShriRl * Dz(ic)
         end do 
      end do

!- D. CALCULATION OF REFERENCE KD (KDCrRlRef)
!
!      do 70 ir= 1, NrLevs
      do ir = 1, 1 ! Currently only one level
         flRigid = .FALSE.
!
! --- find node with bottom MB domain at depth Z_St
         ICpBtMB = 1
         DZTot   = -DZ(1) - 1.d-2
         do while (Z_St < DZTot)
            ICpBtMB = ICpBtMB + 1
            DZTot   = DZTot - DZ(ICpBtMB)
         end do
!
         if (Z_St > ZDraBas) then   
            ICpBot = 1
            DZTot  = -DZ(1) - 1.d-2
! --- find node with depth ZDraBas 
            Z_Bot = ZDraBas   
            do while (Z_Bot < DZTot)
               ICpBot = ICpBot + 1
               DZTot  = DZTot - DZ(ICpBot)
            end do
!
! --- check whether the soil between Z_ST and ZDraBas is a rigid soil
            if (ICpBot > ICpBtMB) then
               do ic = ICpBtMb, ICpBot
                  il = Layer(ic)
                  if (SwSoilShr(il) == 0) flRigid = .TRUE.
               end do
               if (flRigid) ICpBot = ICpBtMB
            end if
         else
            ICpBot = ICpBtMB
         end if
!
! ---  if rapid drainage is switched on, conduct relevant calculations 
         if (SwDrRap == 1) then
            if (SwDTyp(NumLevRapDra) == 1 .AND. flRigid) then 
! --- in case of drain tube and static macropores above drainage basis ZDraBas, 
!     plus rigid soil between Z_St and ZDraBas: never contact between drain and
!     MB domain, so no rapid drainage possible!
               KDCrRlRef(ir) = 0.d0
            else    
! --- rapid drainage possible!
!
! --- node at depth 75% from traject surface to draindepth
               ICpHRef = 1
               if (flRigid) then
                  Zref = dmin1(0.75d0*Z_St,Z_St+10.d0)
               else
                  Zref = dmin1(0.75d0*ZDraBas,ZDraBas+10.d0)
               end if
               
               DZTot   = -DZ(1) - 1.d-2
               do while (Zref < DZTot)
                  ICpHRef = ICpHRef + 1
                  DZTot   = DZTot - DZ(ICpHRef)
               end do
!
! --- calculate relative reference KD = KDCrRlRef 
               il = 0
               KDCrRlRef(ir) = 0.d0
               do ic = ICpHRef, ICpBot
                  il = Layer(ic)
                  if (SwSoilShr(il) /= 0) then
                     HHydrStat    = ZDraBas - Z(ic)
                     ThetHydrStat = watcon (ic,HHydrStat)
                     if (ic <= ICpBot .AND. Z_St > ZDraBas) then
                        ThetHydrStat = dmin1(0.99d0*Thetas(ic),ThetHydrStat)
                     end if
                     VlShriRl = SHRINK(il,ThetHydrStat)
                     VlMpDyRl = VlShriRl - (1.d0 - (1.d0-VlShriRl)**(1.d0/GeomFac(il)))
                  else
                     VlMpDyRl = 0.d0
                  end if
                  VlMpRl        = PpDmCp(1,ic) * (VlMpDyRl + VlMpStCp(ic)/DZ(ic))
                  WdthCr        = DiPoCp(ic) * (1.d0 - dsqrt(1.d0-VlMpRl))
                  KCrRlRef      = (WdthCr**RapDraReaExp) / DiPoCp(ic)
                  KDCrRlRef(ir) = KDCrRlRef(ir) + KCrRlRef * DZ(ic)     
               end do
            end if
         end if
           
      end do

!- E.1 CALCULATION OF SORPTIVITY PARAMETERS SorpAlfa and SorpMax FROM SOIL
!     HYDRAULIC FUNCTIONS according to PARLANGE FOR swabs == 1
      do il = 1, NumLay
         call PARLANGE (SwSorp(il),il)
      end do
      
!- E.2 CALCULATION OF DIFFUSIVITY FOR theta = theta(h_entry) FOR swabs == 2
      do il =1, NumLay
         alfamg     = paramvg(4,il)
         h_entr     = paramvg(9,il)
         m          = paramvg(7,il)
         s_enpr     = (1.0d0 + (dabs(alfamg*h_entr))**paramvg(6,il))**(-m)
         oneOVERm   = 1/m
         wcsMINwcr  = paramvg(2,il)-paramvg(1,il)
         lambda_adj = dmax1(paramvg(5,il),-oneOVERm)
         relsat     = (watcon(nod1lay(il),h_entr) - paramvg(1,il)) / wcsMINwcr
         relsat     = dmin1(relsat,s_enpr) ! Maximize to value below 1 based on h_enpr
         help       = 1-relsat ** oneOVERm
         DiMtxSat(il) = (((1-m)*paramvg(3,il)) / (alfamg * m * wcsMINwcr)) *        &
                        relsat ** (lambda_adj - oneOVERm) * (help ** (-m) + help ** m - 2)
      end do
      
      
!- F. CALCULATION OF CONSTANT FOR DARCY EXCHANGE BETWEEN MP AND MATRIX
      do id = 1, NumDm
         do ic = ICTopMp, ICpBtDmPot(id)
            CDarcy(id,ic) = ShapeFacMp * 8.0d0 * PpDmCp(id,ic) * DZ(ic) * ksatfit(Layer(ic)) / DiPoCp(ic)**2
         end do
      end do
      
!- G. Initialize macropore volume
      if (.not.native09_pending()) call MPVOLUME (1)
      
      return
      end subroutine MacroInit

!.......................................................................
      SUBROUTINE PARLANGE (SwSrp,il)
! ----------------------------------------------------------------------
!     Date               : 31/08/05                                        
!     Purpose            : calculation of Sorptivity from k(h) and 0(h) according 
!                          to Parlange (1975) and fitting of SorpAlfa and SorpMax
!                          parameters of emperical sorptivity relation to the 
!                          Parlange curve
!     Functions called   : moiscap, hconduc, prhead, watcon 
! ----------------------------------------------------------------------
      use MOD_grid,      only: nod1lay
      use MOD_MvG,       only: watcon, moiscap, hconduc, prhead, cofgen
      use variables,     only: thetas, h, thetar

      implicit NONE

! --- global                                                       In
      integer, intent(in)  :: il, SwSrp
! ----------------------------------------------------------------------
! --- local
      integer in, is, it, itIntv, Node, Nsteps
      real(8) Dum, Diffus_h(1000), difmoiscap
      real(8) Head, Mpow, K_h, S, S0, Shlp
      real(8) SpF4_2, Thet(1000), ThetpF4_2  

      real(8), parameter :: ThetStep = 1.0d-3
      
! ----------------------------------------------------------------------   

!     find first Node of the Layer
      Node = nod1lay(il)
 
!   - dummy for Function hconduc 
      Dum = 0.d0
!
! --- Calculate Theta(h) and Diffusivity(h) for the relevant range: pF4.2 to h = 0 
      ThetpF4_2 = watcon(Node,-1.6d4)
      ThetpF4_2 = ThetStep * dble(idnint(ThetpF4_2/ThetStep))
      NSteps    = idnint((ThetaS(Node)-ThetpF4_2)/ThetStep) + 1
      Thet(1)   = ThetpF4_2
      do it = 1, Nsteps
         if (Thet(it) > ThetaS(Node) .OR. it == Nsteps) then 
            Thet(it) = ThetaS(Node) - 0.5d0*ThetStep
         end if
         Head         = prhead (Node,dum,Thet(it),cofgen,h)
         K_h          = hconduc (Node,Head,Thet(it),Dum)
         Difmoiscap   = moiscap (Node,Head)
         Diffus_h(it) = K_h / difmoiscap
         Thet(it+1)   = Thet(it) + ThetStep
      end do
!
! ---- Calculate Sorptivity according to Parlange for Theta(pF4.2) (SpF4_2) and 
!      for Theta = (ThetaSat+Theta(pF4.2))/2. Exponent Mpow, calculated for this
!      Theta on basis of SpF4_2, is an excellent predictor for the exponent of
!      the curve S(Theta)= S0*(1-Theta/ThetaSat)^M for the range pF4.2 to h = 0       
      itIntv = idnint((ThetaS(Node)-ThetpF4_2) / 2.0d0 / ThetStep)
      it     = 1
      do is = 1, 2
         Shlp  = 0.d0
         do in = it+1, Nsteps
            Shlp = Shlp + (Thet(in)-Thet(it)) * Diffus_h(in) * ThetStep 
         end do
         Shlp  = dmax1(Shlp,0.d0)
         S     = dsqrt(2.d0 * Shlp)
         if (is == 1) then
            SpF4_2 = S
         else
            Mpow   = dlog10(S/SpF4_2) / dlog10(1.d0 -                      &
                           (Thet(it)-ThetpF4_2) / (ThetaS(Node)-ThetpF4_2))
         end if
         it = it + itIntv
      end do
!
! --- Extrapolate SpF4_2 to S0 at ThetaR(esidual)
      S0 = SpF4_2 * (1.d0 - (ThetaR(Node)-ThetpF4_2) / (ThetaS(Node)-ThetpF4_2) )** Mpow
!
      if (SwSrp == 1) then
! --- Assign values to variables of subroutine ABSORPTION
         SorpAlfa(il) = Mpow
         SorpMax(il)  = SorpFacParl(il) * S0
      else
! --- Correction factor when emperical values are input, for use in Darcy option
!     in absorption
         SorpFacParl(il) = dmin1(1.d0,SorpMax(il) / S0)
      end if
!      write(96,'(i5,2f10.5)') il, Mpow,  S0 

      return
      end subroutine Parlange

!.......................................................................
      SUBROUTINE SHRINKPAR (itask, il)
! ----------------------------------------------------------------------
!     Date               : 21/08/02                                        
!     Purpose            : calculation of the parameters of the shrinkage 
!                          characteristics of clay and peat from input parametrs
!     Subroutines called : -                             
!     Functions called   : -
!     File usage         : -           
! ----------------------------------------------------------------------
      use variables, only: thetsl
      
      implicit NONE
      
! --- global                                                       
      integer, intent(in)     :: itask, il
! ----------------------------------------------------------------------
! --- local
!      integer 
      real(8) Alfa, Alfa1, Alfa2, AlfMax, AlfMin, Beta1, Beta2, C1, C2
      real(8) C3, Deriv, e_r, e_t, FA, Funct, GA, HA, MoisR1
      character(len=200) message
! ----------------------------------------------------------------------
!
      select case (itask)
      case(1)
! --- SwSoilShr= 1: Clay; SwShrInp= 1: shrinkage parameters are given
!   - calculate MoisR1= moisture ratio at transition from normal to residual 
!     shrinkage (stored in variable ShrParD)
      ShrParD(il)= -dlog((ShrParC(il)-1.d0)/(ShrParA(il)*ShrParB(il))) / ShrParB(il)
!cc------- FOUTMELDING AANPASSEN
      if (ShrParD(il) > Thetsl(il)/(1.d0-Thetsl(il))-0.01d0) then
         message = ' ShrParD > (ThetaS/(1.d0-ThetaS)-0.01d0'
         call swap_error ('shrinkpar', message)
      end if

      return

      case (2)
! --- SwSoilShr= 1: Clay; SwShrInp= 2: typical points of shrinkage chracteristics
!     are given: void ratio at zero water content (Alfa) and MoisR1. 
!   - calculate parameters shrinkage curve: Beta, Gamma
      if (ShrParA(il) > ShrParB(il)) then
         message = ' inconsistent shrinkage input: ShrParA > ShrParB'//  &
                  ' is not allowed'
         call swap_error ('shrinkpar', message)
      end if
      Alfa   = ShrParA(il)
      MoisR1 = ShrParB(il)
!cc------- ADAPT ERROR MESSAGE
      if (MoisR1 > Thetsl(il)/(1.d0-Thetsl(il))-0.01d0) then
         message = ' MoisR1 > ThetaS/(1.d0-ThetaS)-0.01d0'
         call swap_error ('shrinkpar', message)
      end if
      Beta2 = -1.d0/MoisR1*dlog((MoisR1)/Alfa)      
      Beta1 = Beta2 + 1.d0

!   -iteration loop
      do while (abs(Beta2-Beta1) > 0.001d0)
         Beta1 = Beta2
         Funct = (Alfa+Alfa*MoisR1*Beta1) * dexp(-Beta1*MoisR1)
         Deriv = (-Alfa*MoisR1*MoisR1*Beta1) * dexp(-Beta1*MoisR1)
         Beta2 = Beta1 - Funct/Deriv
      end do

      ShrParB(il) = Beta2
      ShrParC(il) = 1.d0 + Alfa*Beta2*dexp(-Beta2*MoisR1)
      ShrParD(il) = MoisR1

      return
!
      case (3)
      continue
! --- SwSoilShr= 2: Peat; SwShrInp= 1: shrinkage parameters are given
!   - No initial calculations are required
!         VoidR0= ShrParA
!         MoisRa= ShrParB
!         Alfa  = ShrParC
!         Beta  = ShrParD
!         P     = ShrParE
      return

      case (4)
! --- SwSoilShr= 2: Peat; SwShrInp= 2: typical points of shrinkage chracteristics
!     are given. 
!   - calculate parameters shrinkage curve: 
!         ShrParC = Alfa 
!         ShrParD = Beta 
!   - set three help constants

      C1  = 1.d0 / (ShrParD(il) / ShrParB(il)) ! 1 / v_P
      C2  = ShrParC(il)  / ShrParD(il)         ! v_t / v_P 
      e_t = ShrParA(il) + (Thetsl(il)/(1.d0-Thetsl(il)) - ShrParA(il)) * ShrParC(il) /      &
                          (Thetsl(il)/(1.d0-Thetsl(il)))  ! e_0 + (e_s-e_0) * v_r / v_s
      if (ShrParE(il) > 0.d0) then
         e_r = ShrParA(il) + ShrParC(il)
      else
         e_r = 0.5d0*ShrParA(il) + ShrParC(il)
      end if 
      C3 = (e_r/e_t - 1.d0) / ShrParE(il)  ! ((e_r/e_t) - 1) / P

!   - find value of Alfa in equation by iterative root finding
!   -  C2^Alfa * (exp(-Alfa*C2) - exp(-Alfa*C1)) / (exp(-Alfa) - exp(-Alfa*C1)) - C3 = 0
!   - first estimation of Alfa depends on value of P
      if (abs(ShrParE(il)) > 0.33d0) then
         Alfa2 = 0.5d0
      else
         Alfa2 = 0.9d0
      end if
      Alfa1  = Alfa2 + 1.d0
!   -iteration loop
      AlfMax = 10.0d0
      AlfMin = 0.001d0
      do while (abs(Alfa2-Alfa1) > 0.001d0)
         Alfa1 = Alfa2
         FA    = C2**Alfa1
         GA    = dexp((C1-C2)*Alfa1)   - 1.d0
         HA    = dexp((C1-1.d0)*Alfa1) - 1.d0
         Funct = FA * GA / HA - C3 
         Deriv = FA*( GA*(1.d0+log(C2)-C2 - (C1-1.d0)/Ha) + (C1-C2)) / HA
         Alfa2 = Alfa1 - Funct/Deriv

!   - checking for extreem values and correcting by 'interval halfing'
         if (abs(Alfa2-Alfa1) > 1.0d-2) then
            if (Alfa2 > Alfa1) then 
               if (Alfa1 > Alfmin .AND. Alfa1 < AlfMax-1.0d-3) then
                  Alfmin = Alfa1
               else
                  Alfa2  = (AlfMin + dmin1(Alfa2,AlfMax-1.0d-2)) / 2.d0
               end if
               Alfa2 = dmin1(Alfa2,AlfMax)
            else if (Alfa2 < Alfa1) then 
               if (Alfa1 < Alfmax .AND. Alfa1 > AlfMin+1.0d-3) then
                  Alfmax = Alfa1
               else
                  Alfa2  = (AlfMax + dmax1(Alfa2,AlfMin+1.0d-2)) / 2.d0
               end if
               Alfa2 = dmax1(Alfa2,AlfMin)
            end if
         end if 
      end do
!
      ShrParC(il) = Alfa2
      ShrParD(il) = Alfa2 / (ShrParD(il) / ShrParB(il)) ! Beta = Alfa / v_P
!
      return

      case (5)
! --- SwSoilShr= 3: Peat; SwShrInp= 3: shrinkage chracteristics are approximated
!     by 3 straight line-pieces: 
!   - ShrParE is redundant: 
      ShrParE(il) = ShrParE(il)
      return

      case (6)
! --- SwSoilShr= 0: rigid soil. No shrinkage parameters required.
      continue

      case default
         call swap_error ('shrinkpar', 'Illegal value for TASK')
      end select
      
      return
      end subroutine ShrinkPar

!=======================================================================
      SUBROUTINE MACROINTEGRAL () 
! ----------------------------------------------------------------------
!     Date               : 24/08/02                                        
!     Purpose            : calculation of intermediate values and     
!                          cumulative values          
!     Subroutines called :                               
!     Functions called   : -
!     File usage         : -           
! ----------------------------------------------------------------------
      use MOD_arrays,    only: macp, madm
      use MOD_grid,      only: numnod
      use variables,     only: dt

      implicit NONE

! ----------------------------------------------------------------------
! --- local
      integer ic, id
      real(8) AvFrMpWlWtDm1Cp(MaCp), AvFrMpWlWtDm2Cp(MaCp)
      !real(8) DevMasBalDm1, DevMasBalDm2
      real(8) FrMpWalWetOld(MaDm,MaCp) 
      real(8) QInIntSatDm1Cp(MaCp),  QInIntSatDm2Cp(MaCp)
      real(8) QInMtxSatDm1Cp(MaCp),  QInMtxSatDm2Cp(MaCp)
      real(8) QOutMtxSatDm1Cp(MaCp), QOutMtxSatDm2Cp(MaCp) 
      real(8) QOutMtxUnsDm1Cp(MaCp), QOutMtxUnsDm2Cp(MaCp)
      real(8) QTopMpDm1Cp(MaCp),     QTopMpDm2Cp(MaCp)

! ----------------------------------------------------------------------

! --- Assigning fluxes for Domain 1: Main Bypass Flow domain
      QInTopLatDm1 = QInTopLatDm(1)
      QInTopVrtDm1 = QInTopVrtDm(1)
      do ic = max(IcTopMp-1,1), NumNod
         QInIntSatDm1Cp(ic)  = QInIntSatDmCp(1,ic)
         QInMtxSatDm1Cp(ic)  = QInMtxSatDmCp(1,ic)
         QOutMtxSatDm1Cp(ic) = QOutMtxSatDmCp(1,ic)
         QOutMtxUnsDm1Cp(ic) = QOutMtxUnsDmCp(1,ic)
         QTopMPDm1Cp(ic)     = QTopMpDmCp(1,ic)

!     AvFrMpWlWtDm1Cp = fraction of mp.wall in contact with saturated water for Dm1 averaged over dt
         AvFrMpWlWtDm1Cp(ic) = PpDmCp(1,ic) *  (FrMpWalWet(1,ic)+FrMpWalWetOld(1,ic)) / 2.d0
         FrMpWalWetOld(1,ic) = FrMpWalWet(1,ic)
!     Water content         
         WaUnMpDm1Cp(ic) = WaUnMpDmCp(1,ic)
      end do
    
!
! --- Aggregating fluxes for Domain 2: Internal Catchment domain
!   - Initializing 
      QInTopVrtDm2 = 0.d0
      QInTopLatDm2 = 0.d0
      do ic = max(IcTopMp-1,1), NumNod
         QInIntSatDm2Cp(ic)  = 0.d0
         QInMtxSatDm2Cp(ic)  = 0.d0
         QOutMtxSatDm2Cp(ic) = 0.d0
         QOutMtxUnsDm2Cp(ic) = 0.d0
         QTopMpDm2Cp(ic)     = 0.d0
         AvFrMpWlWtDm2Cp(ic) = 0.d0
         WaUnMpDm2cp(ic)     = 0.d0
      end do
!   - Aggregating 
      do id = 2, NumDm
         QInTopVrtDm2 = QInTopVrtDm2 + QInTopVrtDm(id)
         QInTopLatDm2 = QInTopLatDm2 + QInTopLatDm(id)
         do ic= max(IcTopMp-1,1), ICpBtDmPot(2)
            QInIntSatDm2Cp(ic)  = QInIntSatDm2Cp(ic)  + QInIntSatDmCp(id,ic)
            QInMtxSatDm2Cp(ic)  = QInMtxSatDm2Cp(ic)  + QInMtxSatDmCp(id,ic)
            QOutMtxSatDm2Cp(ic) = QOutMtxSatDm2Cp(ic) + QOutMtxSatDmCp(id,ic)
            QOutMtxUnsDm2Cp(ic) = QOutMtxUnsDm2Cp(ic) + QOutMtxUnsDmCp(id,ic)
            QTopMpDm2Cp(ic)     = QTopMpDm2Cp(ic)     + QTopMpDmCp(id,ic)
!   - AvFrMpWlWtDm2Cp = fraction of mp.wall in contact with water for Dm2 averaged over dt
            AvFrMpWlWtDm2Cp(ic)  = AvFrMpWlWtDm2Cp(ic) + PpDmCp(id,ic) *  &
                         (FrMpWalWet(id,ic)+FrMpWalWetOld(id,ic)) / 2.d0
            FrMpWalWetOld(id,ic) = FrMpWalWet(id,ic)
!     Water content
            WaUnMpDm2Cp(ic) = WaUnMpDm2Cp(ic) + WaUnMpDmCp(id,ic)
         end do
      end do
!
! --- Summing up Intermediate values
      IQInTopVrtDm1= IQInTopVrtDm1 + QInTopVrtDm1 * dt
      IQInTopLatDm1= IQInTopLatDm1 + QInTopLatDm1 * dt
      IQInTopVrtDm2= IQInTopVrtDm2 + QInTopVrtDm2 * dt
      IQInTopLatDm2= IQInTopLatDm2 + QInTopLatDm2 * dt
!   - Per compartment
      do ic= max(IcTopMp-1,1), NumNod    
         IQOutMtxSatDm1Cp(ic) = IQOutMtxSatDm1Cp(ic) + QOutMtxSatDm1Cp(ic) * dt
         IQOutMtxSatDm2Cp(ic) = IQOutMtxSatDm2Cp(ic) + QOutMtxSatDm2Cp(ic) * dt
         IQOutMtxUnsDm1Cp(ic) = IQOutMtxUnsDm1Cp(ic) + QOutMtxUnsDm1Cp(ic) * dt
         IQOutMtxUnsDm2Cp(ic) = IQOutMtxUnsDm2Cp(ic) + QOutMtxUnsDm2Cp(ic) * dt
         IQInIntSatDm1Cp(ic)  = IQInIntSatDm1Cp(ic)  + QInIntSatDm1Cp(ic)  * dt
         IQInIntSatDm2Cp(ic)  = IQInIntSatDm2Cp(ic)  + QInIntSatDm2Cp(ic)  * dt
         IQInMtxSatDm1Cp(ic)  = IQInMtxSatDm1Cp(ic)  + QInMtxSatDm1Cp(ic)  * dt
         IQInMtxSatDm2Cp(ic)  = IQInMtxSatDm2Cp(ic)  + QInMtxSatDm2Cp(ic)  * dt
         IQTopMpDm1Cp(ic)     = IQTopMpDm1Cp(ic)     + QTopMpDm1Cp(ic)     * dt
         IQTopMpDm2Cp(ic)     = IQTopMpDm2Cp(ic)     + QTopMpDm2Cp(ic)     * dt
         
         IQExcMtxDm1Cp(ic) = -IQInIntSatDm1Cp(ic) - IQInMtxSatDm1Cp(ic) + IQOutMtxSatDm1Cp(ic) + IQOutMtxUnsDm1Cp(ic) ! Positive = out MP
         IQExcMtxDm2Cp(ic) = -IQInIntSatDm2Cp(ic) - IQInMtxSatDm2Cp(ic) + IQOutMtxSatDm2Cp(ic) + IQOutMtxUnsDm2Cp(ic) ! Positive = out MP
         
         IQOutDrRapCp(ic)  = IQOutDrRapCp(ic)  + QOutDrRapCp(ic)     * dt
         IQMpOutDrRap      = IQMpOutDrRap      + QOutDrRapCp(ic)     * dt
!     IAvFrMpWlWtDm1= sum of average wet mp.wall fraction weighted for time step
         IAvFrMpWlWtDm1(ic)= IAvFrMpWlWtDm1(ic)+ AvFrMpWlWtDm1Cp(ic) * dt
         IAvFrMpWlWtDm2(ic)= IAvFrMpWlWtDm2(ic)+ AvFrMpWlWtDm2Cp(ic) * dt 
      end do
!
! --- summing up Cumulative values
      do ic = max(IcTopMp-1,1), NumNod
         CQMpInIntSatDm1  = CQMpInIntSatDm1  + QInIntSatDm1Cp(ic)  * dt
         CQMpInIntSatDm2  = CQMpInIntSatDm2  + QInIntSatDm2Cp(ic)  * dt
         CQMpInMtxSatDm1  = CQMpInMtxSatDm1  + QInMtxSatDm1Cp(ic)  * dt
         CQMpInMtxSatDm2  = CQMpInMtxSatDm2  + QInMtxSatDm2Cp(ic)  * dt
         CQMpOutMtxSatDm1 = CQMpOutMtxSatDm1 + QOutMtxSatDm1Cp(ic) * dt
         CQMpOutMtxSatDm2 = CQMpOutMtxSatDm2 + QOutMtxSatDm2Cp(ic) * dt
         CQMpOutMtxUnsDm1 = CQMpOutMtxUnsDm1 + QOutMtxUnsDm1Cp(ic) * dt
         CQMpOutMtxUnsDm2 = CQMpOutMtxUnsDm2 + QOutMtxUnsDm2Cp(ic) * dt
         CQMpOutDrRap     = CQMpOutDrRap     + QOutDrRapCp(ic)     * dt
      end do
      
      CQMpInTopVrtDm1 = CQMpInTopVrtDm1 + QInTopVrtDm1 * dt
      CQMpInTopLatDm1 = CQMpInTopLatDm1 + QInTopLatDm1 * dt
      CQMpInTopVrtDm2 = CQMpInTopVrtDm2 + QInTopVrtDm2 * dt
      CQMpInTopLatDm2 = CQMpInTopLatDm2 + QInTopLatDm2 * dt

      return
      end subroutine MacroIntegral

!=======================================================================
      SUBROUTINE MACROSTATE ()
! ----------------------------------------------------------------------
!     Date               : 20/08/02                                        
!     Purpose            : .......state variables at end of timestep
!     Subroutines called : -                             
!     Functions called   : SHRINK
!     File usage         : -           
! ----------------------------------------------------------------------
      use MOD_grid,      only: numnod, dz
      use variables,     only: dt
      implicit NONE

! --- global

! ----------------------------------------------------------------------
! --- local
      integer ic, ICpBtUnsMtxDm, id, icgwl
      real(8) Time, VlHlp, MPWatbal
      
! ----------------------------------------------------------------------

!  -- Update water storage in entire macropore domains
      WaSrMp            = 0.d0

! -- Total water storage per saturated macropore domain (WaSrMpDm) and total macropore domain (WaUnMpDm)
      do id = 1, NumDm
         if (swmbf == 1 .OR. (swmbf == 2 .AND. id > 1)) then
            WaSrMpDm(id) = WaSrMpDm(id) + (QInTopLatDm(id) + QInTopVrtDm(id) - sum(QExcMtxDmCp(id,ICTopMP:ICpBtDm(id)))) * dt
            if (id == 1) WaSrMpDm(id) = WaSrMpDm(id) - sum(QOutDrRapCp(ICTopMP:ICpBtDm(id))) * dt
            WaSrMpDm(id) = dmax1(0.d0,WaSrMpDm(id))
            WaUnMpDm(id) = WaSrMpDm(id)
         else 
            ! The change in water storage of one total macropore domain is given by MPwatbal for debug
            MPwatbal = (QInTopLatDm(id) + QInTopVrtDm(id) - sum(QExcMtxDmCp(id,ICTopMP:ICpBtDm(id)))) * dt
            if (id == 1) MPwatbal = MPwatbal - sum(QOutDrRapCp(ICTopMP:ICpBtDm(id))) * dt
            ! Find deepest node with interface between saturated and unsaturated zone
            icgwl = ICpBtDm(id) + 1
            ic    = ICpBtDm(id)
            do while (icgwl > ICpBtDm(id) .AND. ic >= ICTopMP)
               if (WaUnMpDmCp(id,ic) / VlMpDmCp(id,ic) < 1.d0) icgwl = ic
               ic = ic - 1
            end do
            if (icgwl > ICpBtDm(id)) then
               icgwl = 1
            end if
            
            ! New water storages:
            WaUnMpDm(id) = sum(WaUnMpDmCp(id,ICTopMp:ICpBtDm(id)))
            WaSrMpDm(id) = sum(WaUnMpDmCp(id,icgwl:ICpBtDm(id))) - WaUnsat(id) 
            
            WaSrMpDm(id) = max(0.d0, WaSrMpDm(id))
         end if
         
         WaSrMp       = WaSrMp + WaUnMpDm(id)
      end do

!- A-C.Calculation of dynamic macropore volume and soil surface crack area
      call MPVolume (2)
      
!- D. CALCULATION PER DOMAIN OF SOME OTHER RELEVANT STATE/RATE VARIABLES 
! 
!  -- WAter StoRage per ComPartment (WaSrMpDmCp), FRaction of MacroPore WALl
!     in contact with stored water (FrMpWalWet), ToP ComPartment number with  
!     WAter StoRed in DoMain (ICpTpWaSrDm)
!
      do id = 1, NumDm
!  -- Initialization
         FrMpWalWet(id,IcTopMp:NumNod) = 0.d0 
         if (ICpBtDm(id) > 0) FrMpWalWet(id,ICpBtDm(id):NumNod) = 1.d0
         if (swmbf == 1 .OR. id > 1) WaUnMpDmCp(id,1:numnod) = 0.d0
!
         if (ICpBtDm(id) > 0) then
            ic    = ICpBtDm(id)
            VlHlp = VlMpDmCp(id,ic)
            do while (VlHlp < WaSrMpDm(id)-1.d-12 .AND. ic > IcTopMp) 
               FrMpWalWet(id,ic) = 1.d0
               if (swmbf == 1 .OR. id > 1) WaUnMpDmCp(id,ic) = VlMpDmCp(id,ic)
               ic                = ic - 1
               VlHlp             = VlHlp + VlMpDmCp(id,ic)
            end do
            ICpTpWaSrDm(id)      = ic
            if (VlMpDmCp(id,ic) > 1.d-8) then
               FrMpWalWet(id,ic) = 1.d0 - (VlHlp-WaSrMpDm(id)) / VlMpDmCp(id,ic)
               if (swmbf == 1 .OR. id > 1) WaUnMpDmCp(id,ic) = VlMpDmCp(id,ic)*FrMpWalWet(id,ic)
            else
               FrMpWalWet(id,ic) = 0.d0 
               ICpTpWaSrDm(id)   = ic + 1
            end if

!  -- WAter LEVel in macropore DoMains (ZWaLevDm)
            ZWaLevDm(id)    = ZBtDm(id)
            do ic = ICpBtDm(id), ICpTpWaSrDm(id)+1, -1
               ZWaLevDm(id) = ZWaLevDm(id) + DZ(ic)
            end do
            ZWaLevDm(id)    = ZWaLevDm(id) + FrMpWalWet(id,ICpTpWaSrDm(id)) * DZ(ICpTpWaSrDm(id))
         else
            ICpTpWaSrDm(id) = 1
            ZWaLevDm(id)    = 0.d0
         end if
   
!  -- Internal water flux in macropore
         if (swmbf == 1 .OR. id > 1) then
            ! Unsaturated
            do ic = ICTopMP, icgwl
               if (ic == ICTopMP) then
                  QTopMpDmCp(id,ic) = QInTopLatDm(id) + QInTopVrtDm(id)
               else
                  QTopMpDmCp(id,ic) = QTopMpDmCp(id,ic-1) - QExcMtxDmCp(id,ic-1) - (WaUnMpDmCp(id,ic-1) - WaUnMpDmCpM1(id,ic-1))/dt
               end if
            end do
            
            ! Saturated
            if (icgwl < ICpBtDm(id)) then
               if (ICpBtDm(id) < ICpBtDmM1(id)) then ! Special case if bottom of macropore becomes shallower
                  do ic = ICpBtDmM1(id), ICpBtDm(id)+1, -1
                     QTopMpDmCp(id,ic) = QTopMpDmCp(id,ic+1) - WaUnMpDmCpM1(id,ic)/dt 
                  end do
               end if
               do ic = ICpBtDm(id), icgwl+1, -1
                  QTopMpDmCp(id,ic) = QTopMpDmCp(id,ic+1) + QExcMtxDmCp(id,ic) + (VlMpDmCp(id,ic) - VlMpDmCpM1(id,ic))/dt
               end do
            end if
         end if
      end do
!
! --- Update cumulative absorption times TimAbsCumDmCp and sorptivity variables
      if (swabs == 1) then
         do id = 1, NumDm
           ICpBtUnsMtxDm = min0(ICpBtDm(id),ICpTpSatZon-1)
            do ic = ICpTpWaSrDm(id), ICpBtUnsMtxDm
               if (FlEndSrpEvt(id,ic)) then  ! End present Sorptivity event
                  TimAbsCumDmCp(id,ic) = 0.d0
                  SorpDmCp(id,ic)      = 0.d0
                  ThtSrpRefDmCp(id,ic) = 0.d0
                  AwlCorFac(ic)        = 0.d0
               else                          ! Continue present Sorptivity event
                  Time                 = TimAbsCumDmCp(id,ic)
!   - ThtSrpRefDmCp = Thet_sat + Delta_thet_theor. = Thet_sat + Thet_theor. - Thet_0
!     Delta_thet_theor. = theoretical increase of theta = term calculated here below 
                  ThtSrpRefDmCp(id,ic) = ThtSrpRefDmCp(id,ic) +AwlCorFac(ic)  &
                    * FrMpWalWet(id,ic) * PpDmCp(id,ic) * (4.d0/DiPoCp(ic))   & 
                    * SorpDmCp(id,ic)   * (dsqrt(Time+DT)-dsqrt(Time))              
                  TimAbsCumDmCp(id,ic) = TimAbsCumDmCp(id,ic) + DT
               end if
            end do
            do ic = IcTopMp, ICpTpWaSrDm(id)-1
               TimAbsCumDmCp(id,ic) = 0.d0
               SorpDmCp(id,ic)      = 0.d0
               ThtSrpRefDmCp(id,ic) = 0.d0
            end do
            do ic = ICpBtUnsMtxDm+1, NumNod
               TimAbsCumDmCp(id,ic) = 0.d0
               SorpDmCp(id,ic)      = 0.d0
               ThtSrpRefDmCp(id,ic) = 0.d0
            end do
         end do
      end if
!
! --- Update factor for correcting vertical area wall for sorptivity calculations
      do ic = IcTopMp, NumNod
         AwlCorFac(ic) = dsqrt(1.0d0-VlMpDmCp(1,ic)/PpDmCp(1,ic)/dz(ic))
      end do

!
!- E. AGGREGATE VOLUMES AND WATER STORAGES FOR SWAP AND THE INTERFACES WITH OTHER MODELS (ANIMO & PEARL)

!   - Domain 1: Main Bypass Flow domain
      WaLevDm1 = ZWaLevDm(1)
      VlMpDm1  = VlMpDm(1)
      WaSrDm1  = WaUnMpDm(1)
      VlMpDm1Cp= VlMpDmCp(1,1:numnod)

!   - Domain 2: Internal Catchment domain
      VlMpDm2  = sum(VlMpDm(2:numdm))
      WaSrDm2  = sum(WaUnMpDm(2:numdm))
      VlMpDm2Cp= 0.0d0
      do id = 2, numdm
         VlMpDm2Cp(1:numnod) = VlMpDm2Cp(1:numnod) + VlMpDmCp(id,1:numnod)
      end do
      
      return
      end subroutine MacroState


!=======================================================================
      real(8) FUNCTION SHRINK (il, theta)
! ----------------------------------------------------------------------
!     Date               : 15/7/02
!     Purpose            : calculate relative shrinkage for clay or peat soils
! ----------------------------------------------------------------------
    
      use variables, only: thetsl
      
      implicit NONE

! --- global
      integer, intent(in)  :: il
      real(8), intent(in)  :: theta
! ----------------------------------------------------------------------
! --- local
      real(8) Alfa, Beta, Gamma, MoisR, MoisRa, MoisRP, MoisRS
      real(8) MoisRT, P, VlSolidRel, VoidR, VoidR0, VoidRS, VoidRT,     &
              VrHlp
      real(8) MoisRi, MR1, MR2, VR1, VR2
! ----------------------------------------------------------------------
      VlSolidRel= 1.d0 - Thetsl(il)
      MoisR= Theta / VlSolidRel

! --- calculation of VoidR= actual void ratio
      if (SwSoilShr(il) == 1) then
!  -- clay soil
         Alfa   = ShrParA(il)
         Beta   = ShrParB(il)
         Gamma  = ShrParC(il)
         MoisRa = ShrParD(il)
         if (MoisR > MoisRa) then
            VoidR = MoisR
         else
            VoidR = Alfa*dexp(-Beta*MoisR) + Gamma*MoisR
            VoidR = dmax1(VoidR,Alfa)
         end if

      else if (SwSoilShr(il) == 2) then
!  -- peat soil
!   - according to relation of Hendriks
         VoidR0 = ShrParA(il)
         MoisRa = ShrParB(il)
!    - Moist and Void Ratio at saturation
         MoisRS = Thetsl(il) / VlSolidRel
         VoidRS = MoisRS
!
!         if (SwShrInp == 1) then
         if (SwShrInp(il) /= 3) then
            Alfa   = ShrParC(il)
            Beta   = ShrParD(il)
            P      = ShrParE(il)

!    - NorMalised Moist and Void Ratio
            MoisRP = Alfa / Beta
            MoisRT = MoisR / MoisRa
            VoidRT = VoidR0 + (VoidRS-VoidR0)*MoisR/MoisRS
            VrHlp  = 1.d0 + P *                                          &
                 ((MoisRT**Alfa) * (dexp(-Beta*MoisRT) - dexp(-Beta))) /&
                 ((MoisRP**Alfa) * (dexp(-Alfa)        - dexp(-Beta)))
!
            if (MoisR < MoisRa) then
               VoidR = VoidRT * VrHlp
            else
               VoidR = VoidRT
            end if
!
!   - according to three straight line-pieces
         else
            MoisRi = ShrParC(il)
            if (MoisR > MoisRa) then
               MR1 = MoisRS
               MR2 = MoisRa
               VR1 = VoidRS
               VR2 = VoidR0 + (VoidRS-VoidR0)*MoisRa/MoisRS
            else if (MoisR > MoisRi) then
               MR1 = MoisRa
               MR2 = ShrParC(il)
               VR1 = VoidR0 + (VoidRS-VoidR0)*MoisRa/MoisRS
               VR2 = ShrParD(il)
            else
               MR1 = ShrParC(il)
               MR2 = 0.d0
               VR1 = ShrParD(il)
               VR2 = VoidR0
            end if
            VoidR = VR2 + (VR1-VR2) * (MoisR-MR2) / (MR1-MR2) 
         end if
      end if

! --- calculate relative volume of shrinkage
      SHRINK = Thetsl(il) - VoidR*VlSolidRel

      return
      end function Shrink

!=======================================================================
      SUBROUTINE MACRORESET (Itask)
! ----------------------------------------------------------------------
!     Date               : 24/08/02                                        
!     Purpose            : calculation of intermediate values and     
!                          cumulative values          
!     Subroutines called :                               
!     Functions called   : -
!     File usage         : -           
! ----------------------------------------------------------------------
      use MOD_grid,      only: numnod

      implicit NONE

      integer, intent(in)  :: itask
      integer              :: id
! ----------------------------------------------------------------------

      if (ITask == 0 .OR. ITask == 1) then
! set intermediate values to zero
         IQInTopVrtDm1    = 0.d0
         IQInTopLatDm1    = 0.d0
         IQInTopVrtDm2    = 0.d0
         IQInTopLatDm2    = 0.d0
         IQMpOutDrRap     = 0.d0
         iQInIntSatDm1cp(1:NumNod)  = 0.d0
         iQInIntSatDm2cp(1:NumNod)  = 0.d0
         iQInMtxSatDm1cp(1:NumNod)  = 0.d0
         iQInMtxSatDm2cp(1:NumNod)  = 0.d0
         iQOutMtxSatDm1cp(1:NumNod) = 0.d0
         iQOutMtxSatDm2cp(1:NumNod) = 0.d0
         iQOutMtxUnsDm1cp(1:NumNod) = 0.d0
         iQOutMtxUnsDm2cp(1:NumNod) = 0.d0
         IQExcMtxDm1Cp (1:NumNod)   = 0.d0
         IQExcMtxDm2Cp (1:NumNod)   = 0.d0
         IQTopMpDm1Cp  (1:NumNod)   = 0.d0
         IQTopMpDm2Cp  (1:NumNod)   = 0.d0
         IQOutDrRapCp  (1:NumNod)   = 0.d0 
         IAvFrMpWlWtDm1(1:NumNod)   = 0.d0 
         IAvFrMpWlWtDm2(1:NumNod)   = 0.d0 

! --- reset states for beginning new balance period
         IWaSrDm1Beg = WaSrDm1
         IWaSrDm2Beg = WaSrDm2
         IWaUnDm1CpBeg(1:NumNod) = WaUnMpDmCp(1,1:NumNod)
         do id=2,numdm
            IWaUnDm2CpBeg(1:NumNod) = IWaUnDm2CpBeg(1:NumNod) + WaUnMpDmCp(id,1:NumNod)
         end do
      end if

      if (ITask == 0 .OR. ITask == 2) then
! set cumulative values to zero
         CQMpInIntSatDm1  = 0.0d0
         CQMpInIntSatDm2  = 0.0d0
         CQMpInMtxSatDm1  = 0.0d0
         CQMpInMtxSatDm2  = 0.0d0
         CQMpOutMtxSatDm1 = 0.0d0
         CQMpOutMtxSatDm2 = 0.0d0
         CQMpOutMtxUnsDm1 = 0.0d0
         CQMpOutMtxUnsDm2 = 0.0d0
         CQMpInTopVrtDm1  = 0.0d0
         CQMpInTopVrtDm2  = 0.0d0
         CQMpInTopLatDm1  = 0.0d0
         CQMpInTopLatDm2  = 0.0d0
         CQMpOutDrRap     = 0.0d0    

! --- reset states for beginning new balance period
         WaSrDm1Ini = WaSrDm1
         WaSrDm2Ini = WaSrDm2
      end if

      return
      end subroutine MacroReset
    
!=======================================================================
      SUBROUTINE MACROSTATEVAR (task)
! ----------------------------------------------------------------------
!     Date               : 24/08/02                                        
!     Purpose            : Save and reset state variables of macropores         
!     Subroutines called :                               
!     Functions called   : -
!     File usage         : -           
! ----------------------------------------------------------------------
    
! --- global variables
      use MOD_grid, only: numnod
      
      implicit none
      integer, intent(in) :: task
! --- local variables
      
      select case (task)
          
      case (1)
! ---    save state variables of time = t
         ICpBtDmM1(1:numdm)           = ICpBtDm(1:numdm)
         VlMpDmCpM1(1:numdm,1:numnod) = VlMpDmCp(1:numdm,1:numnod)
         WaUnMpDmCpM1(1:numdm,1:numnod) = WaUnMpDmCp(1:numdm,1:numnod)

      case (2)
! ---    reset state variables
         ICpBtDm(1:numdm)           = ICpBtDmM1(1:numdm)
         VlMpDmCp(1:numdm,1:numnod) = VlMpDmCpM1(1:numdm,1:numnod)
         WaUnMpDmCp(1:numdm,1:numnod) = WaUnMpDmCpM1(1:numdm,1:numnod)

      case default
         call swap_error ('MacroStateVar', 'Illegal value for TASK')
      end select

      return
    end subroutine MacroStateVar
    
    SUBROUTINE MPVOLUME (iTask)
! ----------------------------------------------------------------------
!     Date               : October 2024                                       
!     Purpose            : To calculate macropore volume                       
!     Functions called   : SHRINK
! ----------------------------------------------------------------------

! --- global
      use MOD_arrays,    only: macp
      use MOD_grid,      only: numnod, layer, dz, z
      use variables,     only: theta, thetas, thetm1
      
      implicit NONE
      
      integer, intent(in)  :: itask
! ----------------------------------------------------------------------
! --- local
      integer ic, id, il
      integer ichlp, NodGwlHlp
      real(8) ArMpTpDy, ArMpTpMin, ArMpTpSt, CritThet, DifVlMpDm
      real(8) DifVlMpDmCp(MaCp), VlMpCp(MaCp), VlMpMin, VlShriCp, VlShriRel

      real(8), parameter :: WthMpMin = 10.0d-4

! ----------------------------------------------------------------------
      
      select case (iTask)
         
!     Dynamically update macropore volume during iterations (call to macropore (2))
      case (1) 

! --- A. VlMpDyCp: TOTAL VOLUME DYNAMIC MACROPORES (CRACKS) BASED ON MATRIX THETA     
      NodGwlHlp = NodGwlFlCpZo
      if (NodGwlFlCpZo > NumNod) NodGwlHlp = NumNod
      
      do ic = IcTopMp, NodGwlHlp
         il = Layer(ic)
         if ((SwSoilShr(il) /= 0) .AND. Theta(ic) < ThetaS(ic)-1.d-4) then
            VlShriRel = SHRINK(il,Theta(ic))
            VlShriCp  = VlShriRel * Dz(ic) ! VoLume of SHRInkage per unit hor. area

            if (Theta(ic) > ThetM1(ic)-1.d-8 .AND. (VlMpDyCp(ic) > 0.d0 .OR. &
               (VlMpDyCp(max0(1,ic-1))+VlMpDyCp(min0(ic+1,NumNod)) > 0.d0))) then
!              Increasing moisture content in case of cracked soil compartment:
               CritThet = ThetaS(ic)
            else
!           Decreasing moist. cont., or increasing  moist. cont. in not cracked soil:
               CritThet = ThetCrMp(il)
            end if

!           SUBSIDence (SubsidCp) and VoLume of DYnamic MacroPores (VlMpDyCp) 
!           per ComPartment (cm3 per cm2 hor. area of soil matrix)
            if (Theta(ic) < CritThet) then
               SubsidCp(ic)    = (1.d0-(1.d0-VlShriRel)**(1.d0/GeomFac(il))) * Dz(ic)
!              in case SubsidCpMax > 0.0 when ThetCrMp(il) is active
               SubsidCp(ic)    = max(SubsidCp(ic),SubsidCpMin(ic))
               VlMpDyCp(ic)    = FrArMtrx(ic) * (VlShriCp - SubsidCp(ic)) * Dz(ic) /  &
                                 (Dz(ic) - SubsidCp(ic))
               if (VlMpDyCp(ic) < 0.d0) then
                  SubSidCp(ic) = SubsidCp(ic) + VlMpDyCp(ic)
                  VlMpDyCp(ic) = 0.d0
               end if
            else
               SubsidCp(ic) = VlShriCp
               VlMpDyCp(ic) = 0.d0 
            end if
         else
            VlShriCp     = 0.d0
            SubsidCp(ic) = 0.d0
            VlMpDyCp(ic) = 0.d0 
         end if
!        VlMaSh: VOLume of soil MAtrix after SHrinkage; for solute models 
!         VlMaSh(ic)= FrArMtrx(ic) * (Dz(ic) - VlShriCp)
      end do
      do ic = NodGwlHlp+1, NumNod
         SubsidCp(ic)= 0.d0
         VlMpDyCp(ic)= 0.d0 
!         VlMaSh(ic)  = FrArMtrx(ic) * Dz(ic)
      end do

! --- B. VOLUME MACROPORES PER COMPARTIMENT (VlMpCp) AND PER DOMAIN (VlMpDmCp) 
!     VlMpCp and ICpBtDm(1) (= ACTUAL bottom (= deepest) compartment number with macropore volume of first (= deepest) domain)
      ICpBtDm(1) = 0
      do ic = NumNod, IcTopMp, -1
         VlMpCp(ic) = VlMpDyCp(ic) + VlMpStCp(ic)
!        Minimum TOTAL volume of macropores PER COMPARTMENT depends on minimum width 
!        WthMpMin = 0.01 cm of macropores; below this width, pores are no macropores. 
         if (ICpBtDm(1) == 0) then
            VlMpMin = (1.d0 - (1.d0 - WthMpMin/DiPoCp(ic))**2) * DZ(ic)
            if (VlMpCp(ic) < VlMpMin .AND. VlMpStCp(ic) < 1.d-5) VlMpCp(ic)= 0.d0
            if (VlMpCp(ic) > 0.d0) ICpBtDm(1) = ic
         end if
      end do
      
      ICpBtDm(1) = max0(ICpBtDm(1),ICpBtDmPot(2))  

!     Determine for domain 2-NumDm ICpBtDm (limited by ICpBtDm(1)) 
      do id = 2, NumDm
         ICpBtDm(id) = min0(ICpBtDmPot(id),ICpBtDm(1))
      end do
  
!     Partition of VoLume of MacroPores per ComPartment over the DoMains
      VlMp = 0.d0

      do id = 1, NumDm
!        Calculate MP volumes per domain
         VlMpDm(id) = 0.d0
         do ic = IcTopMp, ICpBtDm(id)
            VlMpDmCp(id,ic) = PpDmCp(id,ic) * VlMpCp(ic)
            VlMpDm(id)      = VlMpDm(id) + VlMpDmCp(id,ic)
         end do
         do ic = ICpBtDm(id)+1, NumNod
            VlMpDmCp(id,ic) = 0.d0
         end do
         
!        Maximum depth of domain ZBtDm
         ZBtDm(id) = Z(ICpBtDm(id)) - 0.5d0 * DZ(ICpBtDm(id))
!        Total macropore volume 
         VlMp      = VlMp + VlMpDm(id)
      end do

      do ic = IcTopMp, numNod
         VlMpDyCp(ic) = dmax1(VlMpDyCp(ic),0.d0)
      end do
      
! ---- C. AREA OF MACROPORES AT SOIL SURFACE
!     ArMpTpDm: ARea at Soil Surface of MacroPores, per DoMain exists of:
!   1 cracks (dynamic macropore volume): because of very thin top compartment 
!     and consequently fast reaction to drying and wetting of this compartment,
!     this calculation is performed for compartment NnCrAr at depth ZnCrAr
      ArMpTpDy = VlMpDyCp(NnCrAr) / (Dz(NnCrAr)-SubsidCp(NnCrAr)) 
      if (IcTopMp > NnCrAr)  ArMpTpDy = VlMpDyCp(IcTopMp) / (Dz(IcTopMp)-SubsidCp(IcTopMp))
!   2 static macropore volume. This and total macropore volume and partition 
!     over Domains: performed for 1th comp. of zone with macropores: IcTopMp
      ArMpTpSt  = VlMpStCp(IcTopMp) / Dz(IcTopMp)
      ArMpTp    = ArMpTpDy + ArMpTpSt
      ArMpTp    = dmin1(0.6d0,ArMpTp)
!     minimum TOTAL area of macropores at soil surface depends on minimum width
!     WthMpMin = 0.01 cm of macropores; below this width, pores are no macropores.  
      ArMpTpMin = 1.d0 - (1.d0 - WthMpMin/DiPoCp(IcTopMp))**2
      if (ArMpTp < ArMpTpMin) ArMpTp = 0.d0
      ArMpTpDm(1:NumDm) = PpDmCp(1:NumDm,IcTopMp) * ArMpTp
      if (IcTopMp == 1) ArMpSs = ArMpTp ! else no need to update; ArMpSs = 0

!     overall capacity for vertical water inflow at surface of zone with macropores: KsMpSs 
      KsMpSs = 2.d0*7.2d+8 * (DiPoCp(IcTopMp)*(1.d0-dsqrt(1.d0-ArMpTp)))**3 / DiPoCp(IcTopMp)
      KsMpSs = dmin1(dmax1(KsMpSs,1.d-14),1.d3)                        !!!!!!!!!!!! Rob Voorlopig ivm Bug
      
      return
      
!     In case too much water is present in macropores, limit shrinkage: 'hysteresis' (call to macrostate)      
!     NOTE: ArMpTp(Dy) is NOT updated according to updates in VlMpDyCp at end of time step.
      case (2)
      
      VlMp = 0.d0
      
!     Temporarily reset VlMpDyCp
      VlMpDyCp(IcTopMp:NumNod) = - VlMpStCp(IcTopMp:NumNod)
      
      do id = 1, numdm
         if (swmbf == 1 .OR. (swmbf == 2 .AND. id > 1)) then
            if (VlMpDm(id)-WaSrMpDm(id) < -1.d-7) then
!              Water storage exceeds volume of macropore domain
               DifVlMpDm = 0.d0
               ic = IcTopMp - 1
               do while (DifVlMpDm < WaSrMpDm(id)-VlMpDm(id)-1.d-8 .AND. ic < ICpBtDmPot(id))
!                 Calculate if and where macropore volume decreased
                  ic              = ic + 1
                  DifVlMpDmCp(ic) = VlMpDmCpM1(id,ic) - VlMpDmCp(id,ic)
                  DifVlMpDmCp(ic) = dmax1(0.d0,DifVlMpDmCp(ic))
                  DifVlMpDm       = DifVlMpDm + DifVlMpDmCp(ic)
               end do
               if (DifVlMpDm > 0.d0) then
!                 Reduce macropore shrinkage to accomodate amount of water in domain
                  ichlp = ic
                  do ic = IcTopMp, ichlp
                     VlMpDmCp(id,ic) = VlMpDmCp(id,ic) + (WaSrMpDm(id)-VlMpDm(id)) * DifVlMpDmCp(ic)/DifVlMpDm
                  end do
                  VlMpDm(id) = WaSrMpDm(id)
               end if
               if (DifVlMpDm < WaSrMpDm(id) - VlMpDm(id) - 1.d-8) then
!                 Excessive water storage is not a result of (only) shrinkage (debug)
                  continue
               end if
            end if
         end if

!        Update macropore volumes
         VlMpDyCp(IcTopMp:NumNod) = VlMpDyCp(IcTopMp:NumNod) + VlMpDmCp(id,IcTopMp:NumNod)
         VlMp = VlMp + VlMpDm(id)
      end do 

      do ic = IcTopMp, numNod
         VlMpDyCp(ic) = dmax1(VlMpDyCp(ic),0.d0)
      end do
            
      return
      
      case default
         call swap_error ('mpvolume', 'Illegal vsalue for TASK')
      end select
      
    end subroutine MPVolume
    
    subroutine read_macropore()

   use MOD_arrays,    only: madm, maho, madr
   use MOD_grid,      only: numlay, zbotcp, dz, numnod
   use MOD_swap_base, only: swsolu
   
   implicit none
!  local
   real(8) :: maxdepth
!  functions
   logical :: rdinqr

   maxdepth = zbotcp(numnod)
   
!- a. SWITCH FOR SIMULATION TYPE
      swabs = 1; if (RDinqr('swabs')) call rdsinr ('swabs',1,2,swabs)
      swsep = 1; if (RDinqr('swsep')) call rdsinr ('swsep',1,2,swsep)
      swmbf = 1; if (RDinqr('swmbf')) call rdsinr ('swmbf',1,2,swmbf)
      if (swmbf == 2) call rdsdor('nkwt',2.d0,4.d0,nkwt)
      
!- b. PARAMETERS FOR GEOMETRY MACROPORES
      call rdsdor('Z_Ic',maxdepth,0.d0,Z_Ic)
      call rdsdor('Z_St',maxdepth,0.d0,Z_St)
      call rdsdor('VlMpStSs',0.0d0,0.5d0,VlMpStSs)
      call rdsinr('NumSbDm',0,(MaDm-2),NumSbDm)
      call rdsdor('DiPoMi',0.1d0,1000.0d0,DiPoMi)
      call rdsdor('DiPoMa',0.1d0,1000.0d0,DiPoMa)
      call rdsdor('ZnCrAr',-100.0d0,0.0d0,ZnCrAr)
!   - conditionally optional:
      if (DiPoMi < DiPoMa .AND. VlMpStSs <= 1.d-6) then 
         if (NumSbDm == 0) call rdsdor('ZDiPoMa',maxdepth,0.d0,ZDiPoMa)
      end if
!   - optional: 
      if (rdinqr('Z_Tp')) call rdsdor('Z_Tp',Z_St,0.d0,Z_Tp) 
      if (Z_Tp < 0.d0 .AND. Z_Tp > -dz(1)) Z_Tp = -dz(1) 
      Z_MB50 = 0.5d0*(Z_Ic+Z_St); if (rdinqr('Z_MB50')) call rdsdor('Z_MB50',Z_St,Z_Ic,Z_MB50)
      
!- c. PARAMETERS FOR GEOMETRY IC DOMAIN
      if (NumSbDm > 0) then
         call rdsdor('PpIcSs',0.0d0,0.99d0,PpIcSs)
!   - optional:
         if (Z_Tp > -dz(1)) then 
            if (rdinqr('Z_ah')) call rdsdor('Z_Ah',maxdepth,0.d0,Z_Ah)
         end if
         if (Z_Ah < -1.d-6) then
            if (rdinqr('Rzah')) call rdsdor('Rzah',0.0d0,1.0d0,Rzah)        ! default 0.0
         end if
         if (rdinqr('PowM')) call rdsdor('PowM',0.0d0,100.0d0,PowM)         ! default 1.0
         if (rdinqr('Spoint')) call rdsdor('Spoint',0.0d0,1.0d0,Spoint)     ! default 1.0
         if (rdinqr('SwPowM')) call rdsinr('SwPowM',0,1,SwPowM)             ! default 0
      end if
         
!- d. PARAMETERS FOR MACROPORE HYDROLOGY
      call rdsdor('PndmxMp',0.0d0,10.0d0,PndmxMp)
      call rdsdor('ShapeFacMp',0.0d0,100.0d0,ShapeFacMp)
      call rdsdor('CritUndSatVol',0.0d0,10.0d0,CritUndSatVol)
      call rdsinr('SwDarcy',0,1,SwDarcy)
      
!- e. PARAMETERS FOR RAPID DRAINAGE      
      call rdsinr('SwDrRap',0,1,SwDrRap)
      if (SwDrRap == 1) then
         call rdsdor ('RapDraResRef',0.d0,1.d10,RapDraResRef(1))
         RapDraResRef(2:madr) = RapDraResRef(1)
         call rdsdor('RapDrareaExp',0.0d0,100.0d0,RapDraReaExp)
         call rdsinr('NumLevRapDra',1,5,NumLevRapDra)
      end if
      
!- f. PARAMETERS FOR SHRINKAGE CHARACTERISTICS
      call rdfinr('SwSoilShr',0,2,SwSoilShr,MaHo,numlay)
      call rdfinr('SwShrInp',1,3,SwShrInp,MaHo,numlay)
      call rdfdor('ThetCrMP',0.0d0,1.0d0,ThetCrMp,MaHo,numlay)
      call rdfdor('GeomFac',0.0d0,10.0d0,GeomFac,MaHo,numlay)
      call rdfdor('ShrParA',0.0d0,10.0d0,ShrParA,MaHo,numlay)
      call rdfdor('ShrParB',-10.0d0,100.0d0,ShrParB,MaHo,numlay)
      call rdfdor('ShrParC',-10.0d0,100.0d0,ShrParC,MaHo,numlay)
      call rdfdor('ShrParD',0.0d0,100.0d0,ShrParD,MaHo,numlay)
      call rdfdor('ShrParE',-10.0d0,10.0d0,ShrParE,MaHo,numlay)
      
!- g. PARAMETERS FOR SORPTIVITY
      call rdfinr('SwSorp',1,2,SwSorp,MaHo,numlay)
      call rdfdor('SorpFacParl',0.0d0,1.0d2,SorpFacParl,MaHo,numlay)
      call rdfdor('SorpMax',0.0d0,100.0d0,SorpMax,MaHo,numlay)
      call rdfdor('SorpAlfa',-10.0d0,10.0d0,SorpAlfa,MaHo,numlay)
         
!- h. OPTIONAL MACROPORE OUTPUT
      if (RDinqr('swbma')) call rdsinr ('swbma',0,1,swbma)

!   Input checks
      if (NumSbDm > 0 .AND. PpIcSs <= 1.d-6) call swap_error ('read_macropore', ' NumSbDm  > 0 .AND. PpIcSs == 0.d0')
      if (DiPoMi > DiPoMa) call swap_error ('read_macropore',' DiPoMi > DiPoMa')      
      if (swsolu > 0) call swap_error ('read_macropore', 'Combination SWSOLU > 0 and SWMACRO = 1 not (yet) allowed')

   end subroutine read_macropore
         
   end module MOD_macropore
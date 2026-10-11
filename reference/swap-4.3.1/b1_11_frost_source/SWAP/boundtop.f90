module MOD_top

   implicit none
   real(8), save  :: theatm = 0.0d0             ! Water content at hatm (cm3/cm3)
   real(8), save  :: katm   = 0.0d0             ! Hydraulic conductivity at hatm (cm/d)
   real(8), save  :: h0max = 0.0d0              ! Maximum value of pond without runoff (cm)
   real(8), save  :: k1max = 0.0d0              ! Maximum conductivity across 0.5*dz(1), based on Ksat at soil surafce ground surface and K(1) (cm/d)
   real(8), save  :: q0    = 0.0d0              ! Net potential flux rate at top of soil surface: nraidt + nird + melt + runon - epd - reva (cm/d)
                                                ! Note: the flux rate across soil surface is q1 equalling q0 corrected for ponding and runoff
   real(8), save  :: hsurf = 0.0d0              ! Soil water pressure head at the soil surface (cm) 
   logical, save  :: FlRunoff = .FALSE.         ! Flag indicating if runoff is potentially possible
   logical, save  :: ftoph = .FALSE.            ! Flag indicating that the pressure head is prescribed at the soil surface

private
public :: pondrunoff, q0, FlRunoff, ftoph, hsurf            ! headcalc only
public :: theatm, katm                                      ! for multiSWAP
public :: boundtop                                          ! headcalc; initialization calls from soilwater and hysteresis

contains

! File VersionID:
!   $Id: boundtop.f90 368 2018-01-11 15:44:15Z heine003 $
! ----------------------------------------------------------------------
      subroutine boundtop(iTask)
! ----------------------------------------------------------------------
!     date               : August 2004 - June 2012
!     purpose            : determine soil profile top boundary condition      
! ----------------------------------------------------------------------
!     IN
      use MOD_swap_base, only: swmacro, swrunon
      use MOD_grid,      only: dz, disnod
      use MOD_MvG,       only: watcon, hconduc, hconode_vsmall
      use MOD_meteo,     only: epond, peva, empreva, nraidt
      use MOD_runon,     only: runonflx, runon_rec
      use MOD_snow,      only: melt
      use MOD_frost,     only: rfcp
      use MOD_irrigation,only: nird
      use variables,     only: k, swkmean, h, swredu, pondm1, dt, fluseksatexm, ksatexm, ksatfit
      use MOD_swap_mp,   only: frarmtrx, pndmxmp, ksmpss, armpss

!     INOUT
      use variables,     only: runon
!     OUT
      use MOD_swap_mp,   only: qmplatss
      use variables,     only: epd, reva, kmean, pond, runots, qtop, pondmx, indeks

      implicit none
!     global
      integer, intent(in)  :: iTask

! --- local variables
      real(8), save        :: hatm
      real(8)              :: emax,ks,ksurf

! ----------------------------------------------------------------------
! --- local variables
      integer              :: indeks_tp
      real(8)              :: h0,hcomean,k1Atm,p1,p2,p2Mp,q1,RsRoMp

! ----------------------------------------------------------------------
! --- Initialisation
      if (iTask == 1) then
        indeks_tp = indeks(1) ! in case of hysteresis calculate watcon and katm for the drying curve
        indeks(1) = -1
        hatm   = -2.75d+05
        TheAtm = watcon(1,hatm)
        katm   = hconduc(1,hatm,TheAtm,1.0d0)
        indeks(1) = indeks_tp
         return
      end if

! --- runon of present day
      if (swrunon > 0) then
         runon = runonflx(runon_rec)
      else
         runon = 0.d0
      end if

      FlRunoff = .FALSE.
      QMpLatSs = 0.0d0
      h0max    = pondmx

!     S O I L   E V A P O R A T I O N

! --- Calculate hydraulic conductivity corresponding with hAtm
      if (hAtm < 0.0d0) Then
         ksurf = katm * rfcp(1) + hconode_vsmall * (1.0d0 - rfcp(1))
         if (swmacro == 1) ksurf = FrArMtrx(1) * ksurf 
      else

! --- This only occurs if RH is 100% in SWAPS, never used for SWAP
         ksurf = k(1)
      end if
      k1Atm = hcomean(swkmean,ksurf,k(1),dz(1),dz(1), 0, hAtm, h(1))

! --- maximum evaporation rate according to Darcy
      Emax = -k1Atm * ((hatm-h(1))/disnod(1)+1.0d0)
      
! --- determine ponding and reduced soil evaporation rate
      if (pondm1 > 1.0d-10) then
         reva = 0.d0
         epd = epond
      else
         if (swredu == 0) then
           reva = min(peva,max(0.0d0,Emax))
         else
           reva = min(empreva,max(0.0d0,Emax))
         end if
         epd = 0.d0
      end if

!     H I G H   A T M O S P H E R I C   D E M A N D
!     flux through ground surface based on precipitation - evaporation 
!     and remaining ponding of previous timestep
      q0 = (nraidt+nird+melt)*(1.0d0-ArMpSs) + runon - reva - epd
      q1 = - q0 - pondm1/dt

!     check whether the atmospheric demand condition applies
      if (q1 >= 0.0d0 .AND. q1 > Emax) then
         ftoph    = .TRUE.
         hsurf    = hAtm
         kmean(1) = k1Atm
         pond     = 0.0d0
         runots   = 0.0d0
         return
      end if             

!     maximum conductivity assuming saturation at ground surface (z=0)
      if (fluseksatexm(1) .AND. swmacro == 0) then
         ks = rfcp(1)*ksatexm(1) + (1.0d0-rfcp(1))*hconode_vsmall
      else
         ks = rfcp(1)*ksatfit(1) + (1.0d0-rfcp(1))*hconode_vsmall
      end if
      k1max = hcomean(swkmean,ks,k(1),dz(1),dz(1), 0, 0.0d0, h(1))
!     check whether application of flux=q1 will yield a pressure head > 0 
!     at ground surface. If not: flux boundary condition is valid
      h0    = h(1) - disnod(1)*(q1/k1max+1.0d0)
      if (h0 <= 1.0d-6) then
         ftoph    = .FALSE.
         kmean(1) = 0.0d0
         hsurf    = 0.0d0
         pond     = 0.0d0
         runots   = 0.0d0
         qtop     = q1
      else                 ! ponding occurs
         ftoph    = .TRUE.
         kmean(1) = k1max
         FlRunoff = .TRUE. ! runoff potential possible

! --- calculate max value of pond without runoff
         p1     = k1max/disnod(1) * dt
         p2     = 1.0d0/(p1+1.0d0)
         h0max  = p2 * ( pondm1 + q0*dt - k1max*dt + p1*h(1) ) 

! --- in case of macropores, calc. potential overland flow into macrop.: QMpLatSs
         if (ArMpSs > 0.d0) then                     ! Adaptation for GEM 
            if (h0max > PndmxMp) then
               RsRoMp  = (h0max + (nraidt+nird+melt)*ArMpSs*dt) / KsMpSs
               p2Mp    = 1.0d0 / (p1 + 1.0d0 + dt/RsRoMp)
               pond    = (h0max - PndmxMp) * p2Mp/p2
               QMpLatSs= pond * dt/RsRoMp
               QMpLatSs= dmin1(QMpLatSs,h0max)
               if (QMpLatSs < 1.0d-7) QMpLatSs = 0.0d0
            else
               QMpLatSs = 0.0d0
            end if
         end if
      end if
!  
      return
      end subroutine boundtop

! ----------------------------------------------------------------------
      SUBROUTINE PONDRUNOFF ()
! ----------------------------------------------------------------------
!     Date               : 4/5/2005
!     Purpose            : determines ponding height and calculates runoff        
!     Formal parameters  :                                             
!     Subroutines called : -                                           
!     Functions called   : runoff                                 
!     File usage         : -                                           
! ----------------------------------------------------------------------
!     IN
      use MOD_arrays,    only: mairg
      use MOD_grid,      only: disnod
      use MOD_swap_base, only: swdra, swmacro, swpondmx
      use variables,     only: dt,t1900,h,pondm1,rsro,rsroexp,pondmxtab
!     INOUT
      use variables,     only: pondmx
      use MOD_swap_mp,   only: QMpLatSs
!     OUT
      use variables,     only: pond,runots

      IMPLICIT NONE

! ----------------------------------------------------------------------
! --- local variables
      INTEGER  :: i
      real(8)  :: h0,h0min,p1,p2,afgen
      real(8)  :: q0hlp

! ----------------------------------------------------------------------
! --  in case of time dependent ponding: determine pondmx
      if (swpondmx == 1) then
         pondmx = afgen (pondmxtab,2*mairg,t1900+dt)
      end if

! --- in case of Macropores: 
      q0hlp = q0
      if (swmacro == 1) then
         if (FlRunoff) then
!   - h0max is reduced with overland flow into Macropores
            q0hlp  = q0 - QMpLatSs/dt
            p1     = k1max/disnod(1) * dt
            p2     = 1.0d0/(p1+1.0d0)
            h0max  = p2 * ( pondm1 + q0hlp*dt - k1max*dt + p1*h(1) )   
            if (h0max < -1.d-9) then
               QMpLatSs =  QMpLatSs + h0max
               h0max = 0.d0
            end if
         else
!   - inflow excess by direct precipitation into macropores is added to ponding
            if (QMpLatSs < 0.d0) then 
               QMpLatSs = 0.d0
            end if
            return
         end if
         q0hlp    = q0 - QMpLatSs/dt
      end if
!
! --- check whether h0max, the max value of pond, yields a runoff

!      if (swdra /= 2 .AND. h0max <= pondmx) then

      if (h0max <= pondmx) then
         runots   = 0.0d0
         pond     = h0max 
         hsurf    = pond
         return
      end if

      runots = runoff()
      if (dabs(runots) < 1.0d-6) then
!        if no runoff occurs: first estimation of pond is OK 
         pond     = h0max 
         hsurf    = pond
         !!!runots   = 0.0d0     ! wanneer dit statement actief, dan ontstaan kleine verschillen in diverse testbank cases  (10-09-2024)
         return
      else if (dabs(runots) >= 1.0d-6 .AND. swdra /= 2 .AND. dabs(rsroexp-1.0d0) < 1.0d-6) then
         p1 = k1max/disnod(1) * dt
         p2 = 1.0d0 / (p1 + 1.0d0 + dt/rsro)

         pond     = p2 * ( pondm1 + q0hlp*dt - k1max*dt + p1*h(1) + dt/rsro * pondmx )
         runots = runoff() 
         hsurf    = pond
         return
      else             

!        if runoff occurs: find values for pond and runots iteratively

         p1 = k1max/disnod(1) * dt
         p2 = 1.0d0/(p1+1.0d0)

!        estimation of maximum ponding: ignore runoff
         h0max = p2 * ( pondm1 + q0hlp*dt - k1max*dt + p1*h(1) )
         h0min = 0.0d0
         do i=1,30
            pond   = 0.5d0 * (h0max + h0min)
            runots = runoff()
            h0     = p2 * ( pondm1 +q0hlp*dt -k1max*dt +p1*h(1) -runots)

            if (dabs(pond-h0) < 1.0d-6) then
               hsurf    = pond
               return
            else
               if (h0 > pond) then
                  h0min = pond
               else
                  h0max = pond
               end if 
            end if
         end do
      end if

!     if convergence has not been reached: proceed with final value
      pond   = 0.5d0 * (h0max + h0min)
      runots = runoff()
      hsurf  = pond

      contains
! ----------------------------------------------------------------------
      function runoff ()
      !use MOD_swap_base, only: swdra
      !use variables,     only: pond, pondmx, rsro, rsroexp, dt
      use MOD_drain,     only: wls, swst
      implicit none
      ! global
      real(8)  :: runoff
      !local
      real(8)  :: inun_max
      ! function
      real(8) :: swstlev

      runoff = 0.0d0
      if (pond-pondmx > 0.0d0 .AND. swdra /= 2) then
         if (rsro < 1.0d-3) then 
            runoff = pond-pondmx
         else         
            runoff = dt/rsro* (pond-pondmx)**rsroexp
         end if
      else if (swdra == 2) then
         if (pond > pondmx .AND. pond > wls) then
            runoff = dt/rsro* (pond-max(pondmx,wls))**rsroexp
         else if (pond < wls) then
            inun_max = swst - swstlev(pond)
            runoff = -min(inun_max,wls-max(pond,pondmx))
         end if
      end if
      return
      end function runoff

      end SUBROUTINE PONDRUNOFF

end module MOD_top
module MOD_integral

   use MOD_arrays, only: madr, macp
   use MOD_integral_global
   
   implicit none

   ! interfaces to main entries of subroutine integral
   !!!interface
   !!!   subroutine integral(iTask)
   !!!      integer, intent(in) :: iTask
   !!!   end subroutine integral
   !!!end interface
    
   real(8), dimension(macp),      save ::   inqrot              ! Array with intermediate amounts of extracted water by roots for each compartment (L)
   real(8), dimension(macp+1),    save ::   inq                 ! Array with intermediate amounts of water flow between current and upper compartment (L)
   real(8), dimension(macp),      save ::   inqssdi             ! Array with intermediate amounts of subsurface drip irrigation for each compartment (L)
   real(8), dimension(macp),      save ::   inqpotrot           ! Array with intermediate amounts of potential extracted water by roots for each compartment (L)
   real(8), dimension(macp),      save ::   inqredrot           ! Array with intermediate amounts of reduction of extracted water by roots for each compartment in case of no compensation (L)
   real(8), dimension(macp+1),    save ::   iqdo, iqup
   
   real(8),                       save ::   iqrot               ! Intermediate amount of extracted water by roots (L)
   real(8),                       save ::   iqssdi              ! Intermediate amount of water input via subsurface drip irrigation (L)
   real(8),                       save ::   iqredwet            ! Intermediate amount of reduced root water extraction due to wet conditions (L)
   real(8),                       save ::   iqreddry            ! Intermediate amount of reduced root water extraction due to dry conditions (L)
   real(8),                       save ::   iqredsol            ! Intermediate amount of reduced root water extraction due to salt conditions (L)
   real(8),                       save ::   iqredfrs            ! Intermediate amount of reduced root water extraction due to frost conditions (L)
   real(8),                       save ::   iintc               ! Intermediate amount of evaporation from canopy (L)
   real(8),                       save ::   isintc              ! Intermediate amount of evaporation from canopy reservoir (L)
   real(8),                       save ::   iepd                ! Intermediate amount of ponding evaporation (L)
   real(8),                       save ::   ipeva               ! Intermediate amount of potential soil evaporation (L)
   real(8),                       save ::   iptra               ! Intermediate amount of potential transpiration (L)
   real(8),                       save ::   ievap               ! Intermediate amount of actual soil evaporation (L)
   real(8),                       save ::   iruno               ! Intermediate amount of runoff (L)
   real(8),                       save ::   irunon              ! Intermediate amount of runon (L)
   real(8),                       save ::   iqbot               ! Intermediate amount of water flow through bottom of simulated soil column (L)
   real(8),                       save ::   iqbdo,iqbup         ! Intermediate amount of water flow through bottom of simulated soil column (L)
   real(8),                       save ::   iqtdo,iqtup         ! Intermediate amount of water flow through top of simulated soil column (L)
   
   real(8),                       save ::   igrai               ! Intermediate amount of gross rainfall (L)
   real(8),                       save ::   inrai               ! Intermediate amount of net precipitation (L)
   real(8),                       save ::   igird               ! Intermediate depth of gross irrigation (L)
   real(8),                       save ::   inird               ! Intermediate depth of net irrigation (L)
  
!  Balance period (e.g. year) cumulative amounts; output, used in outbal, outblc
   
   real(8),                       save ::   cgrai               ! Cumulative amount of gross precipitation (L)
   real(8),                       save ::   cnrai               ! Cumulative amount of net precipitation (L)
   real(8),                       save ::   caintc              ! Cumulative amount of rainfall interception (L)
   real(8),                       save ::   cqrot               ! Cumulative amount of extracted water by roots (L)
   real(8),                       save ::   cqbot               ! Cumulative amount of water flow through bottom of simulated soil column (L)
   real(8),                       save ::   cqbotdo             ! Cumulative amount of water (L) passed through the soil column bottom in downward direction
   real(8),                       save ::   cqbotup             ! Cumulative amount of water (L) passed through the soil column bottom in upward direction
   real(8),                       save ::   cqssdi              ! Cumulative amount of subsurface drip irrigation (L)
   real(8),                       save ::   cqtdo               ! Cumulative amount of water (L) passed through the soil surface in downward direction
   real(8),                       save ::   cqtup               ! Cumulative amount of water (L) passed through the soil surface in upward direction
   real(8),                       save ::   crunoff             ! Cumulative runoff (L)
   real(8),                       save ::   crunon              ! Cumulative amount of runon (L)
   real(8),                       save ::   cevap               ! Cumulative amount of actual soil evaporation (L)
   real(8),                       save ::   cepd                ! Cumulative amount of ponding evaporation (L)
   real(8),                       save ::   cpeva               ! Cumulative amount of potential soil evaporation (L)
   real(8),                       save ::   cptra               ! Cumulative amount of potential transpiration (L)
   real(8),                       save ::   cinund              ! Cumulative amount of inundation (L)
   real(8),                       save ::   cqprai              ! Cumulative amount of net rain (L)
   real(8),                       save ::   cgird               ! Cumulative amount of gross irrigation (L)
   real(8),                       save ::   cnird               ! Cumulative amount of net irrigation (L)

   ! for drainage and/or surfacewater
   real(8),                       save ::   cqdra              ! Cumulative amount of lateral drainage (L)
   real(8), dimension(madr),      save ::   cqdrain            ! Cumulative amount of lateral drainage for each drainage level (L)
   real(8), dimension(madr),      save ::   cqdrainin          ! Cumulative infiltration flux (L) for each drainage level
   real(8), dimension(madr),      save ::   cqdrainout         ! Cumulative drainage flux (L) for each drainage level
   real(8), dimension(madr,macp), save ::   inqdra             ! Array with intermediate amounts of lateral drainage for each level and compartment (L)
   real(8), dimension(madr,macp), save ::   inqdra_in, inqdra_out
   real(8),                       save ::   iqdra              ! Intermediate amount of lateral drainage (L)

   ! snow
   real(8),                       save ::   cgsnow              ! Cumulative amount of gross snow fall (L water)
   real(8),                       save ::   cmelt               ! Cumulative amount of melted snow (L water)
   real(8),                       save ::   csnrai              ! Cumulative amount of net snow fall (L water)
   real(8),                       save ::   csubl               ! Cumulative amount of sublimated snow (L water)
   real(8),                       save ::   isnrai              ! Incremental amount of net snow fall (L water)
   real(8),                       save ::   igsnow              ! Incremental amount of gross snow fall (L water)
   real(8),                       save ::   isubl               ! Incremental amount of sublimated snow (L water)

   public

   contains

! File VersionID:
!   $Id: integral.f90 341 2017-09-29 18:12:25Z kroes006 $
! ----------------------------------------------------------------------
      subroutine integral(iTask)
! ----------------------------------------------------------------------
!     Date:    November 2004
!     Purpose: calculation of intermediate and cumulative fluxes
! ----------------------------------------------------------------------
      use plant_interface, only: noddrz, ipgass, igass, imres, ipgasspot, igasspot, imrespot, sw_inter, sicact, siccap, crsflx_in, crsflx_out, siccaploss
      use MOD_grid,        only: numnod
      use MOD_swap_base,   only: swsnow, swdra, swmacro
      use MOD_meteo,       only: peva, ptra, graidt, nraidt, aintcdt
      use MOD_snow,        only: gsnow, melt, subl, snrai, snowinco, ssnow
      use MOD_drain,       only: qdrtot, nrlevs, qdra, qdrain
      use MOD_irrigation,  only: qssdisum, qssdi, gird, nird
      use MOD_macropore,   only: macropore
      use variables,       only: flzerocumu, flzerointr, fldaystart, dt, epd, reva, qbot, qrot, runots,runon, q, volini, volact, pondini, pond, theta, ivolbeg, ipondbeg, issnowbeg, isicbeg, ithetabeg
      use MOD_re_global,   only: qpotrot, qredwetsum, qreddrysum, qredsolsum, qredfrssum, qrosum, qredwet, qreddry, qredsol, qredfrs, qredrwu, alpwetnoddrz, alpdrynodrtz
      implicit none
!     global
      integer, intent(in) :: iTask

! --- local variables
      integer node,level
      real(8) qrotts,qdrats,ptrats,epdts,pevats,revats,qbotts
! ----------------------------------------------------------------------

   select case(iTask)

   case (1,2)   ! initialization or resets
      
      if (iTask == 1 .OR. fldaystart) then

          iqrot_day = 0.d0
          iqreddry_day = 0.d0
          iqredsol_day = 0.d0
          iptra_day = 0.d0
          do node = 1,numnod 
            inqpotrot_day(node) = 0.d0
            inqredrot_day(node) = 0.d0
          end do
          
          ialpwet_day = 0.d0
          ialpdry_day = 0.d0
      
      end if

      if (iTask == 1 .OR. flzerocumu) then

         cgrai   = 0.0d0
         cnrai   = 0.0d0
         cgird   = 0.0d0
         cnird   = 0.0d0
         caintc  = 0.0d0
         cqrot   = 0.0d0
         cqbot   = 0.0d0
         cqbotdo = 0.0d0
         cqbotup = 0.0d0
         cqtdo   = 0.0d0 
         cqtup   = 0.0d0
         cqssdi  = 0.0d0
         crunoff = 0.0d0
         crunon  = 0.0d0 
         cptra   = 0.0d0
         cepd    = 0.0d0
         cpeva   = 0.0d0
         cevap   = 0.0d0
         cinund  = 0.0d0
         cqprai  = 0.0d0
         if (swdra > 0) then
            cqdra = 0.0d0
            do level = 1, nrlevs
               cqdrain(level)    = 0.0d0
               cqdrainin(level)  = 0.0d0
               cqdrainout(level) = 0.0d0
           end do
         end if
         if (swsnow == 1) then
            cgsnow = 0.0d0
            csubl  = 0.0d0
            csnrai = 0.0d0
            cmelt  = 0.0d0
         end if
         
         volini   = volact
         pondini  = pond
         snowinco = ssnow
!         sicini   = sicact
         
         if (swmacro == 1) call macropore(6)
         
      end if

      if (iTask == 1 .OR. flzerointr) then

         igrai = 0.0d0
         inrai = 0.0d0
         igird = 0.0d0
         inird = 0.0d0
         do node = 1, numnod
            inqrot(node)    = 0.0d0
            inqpotrot(node) = 0.0d0
            inqredrot(node) = 0.0d0
            inqssdi(node)   = 0.0d0
            inq(node)       = 0.0d0
         end do
         inq(numnod+1)    = 0.0d0
         iqrot            = 0.0d0
         iqssdi           = 0.0d0
         iqredwet         = 0.0d0
         iqreddry         = 0.0d0
         iqredsol         = 0.0d0
         iqredfrs         = 0.0d0
         iintc            = 0.0d0
         isintc           = 0.0d0
         iptra            = 0.0d0
         iepd             = 0.0d0
         ipeva            = 0.0d0
         ievap            = 0.0d0
         iruno            = 0.0d0
         iqbot            = 0.0d0
         iqbdo            = 0.0d0
         iqbup            = 0.0d0
         iqtdo            = 0.0d0
         iqtup            = 0.0d0
         irunon           = 0.0d0
         iqdo(1:numnod+1) = 0.0d0
         iqup(1:numnod+1) = 0.0d0
         if (swdra > 0) then
            do node = 1,numnod
               do level = 1,nrlevs
                  inqdra(level,node)     = 0.0d0
                  inqdra_in(level,node)  = 0.0d0
                  inqdra_out(level,node) = 0.0d0
               end do
            end do
            iqdra = 0.0d0
         end if
         if (swsnow == 1) then
            igsnow = 0.0d0
            isubl  = 0.0d0
            isnrai = 0.0d0
         end if
         
         ipgass= 0.d0; ipgasspot= 0.d0
         igass = 0.d0; igasspot = 0.d0
         imres = 0.d0; imrespot = 0.d0
         
         ivolbeg   = volact
         ipondbeg  = pond
         issnowbeg = ssnow
         isicbeg   = sicact
         do node = 1, numnod
            ithetabeg(node) = theta(node)
         end do
         
         if (swmacro == 1) call macropore(5)
         
      end if

   case (3)  ! perform integrations

! --- potential transpiration of this timestep
      ptrats = ptra * dt

! --- ponding evaporation of this timestep
      epdts = epd * dt
      
! --- potential soil evaporation of this timestep
      pevats = peva * dt

! --- reduced soil evaporation of this timestep
      revats = reva * dt

! --- flux lower boundary of this timestep
      qbotts = qbot*dt

! --- total root extraction of this timestep
      qrotts = qrosum * dt

! --- total drainage flux of this timestep
      qdrats = qdrtot * dt

! --- add time step fluxes to intermediate totals
      iqrot = iqrot + qrotts
      do node = 1,noddrz
        inqrot(node)        = inqrot(node) + qrot(node) * dt
        inqpotrot(node)     = inqpotrot(node) + qpotrot(node) * dt
        inqredrot(node)     = inqredrot(node) + (qredwet(node) + qreddry(node) + qredsol(node) + qredfrs(node) + qredrwu(node)) * dt
        inqpotrot_day(node) = inqpotrot_day(node) + qpotrot(node) * dt
        inqredrot_day(node) = inqredrot_day(node) + (qredwet(node) + qreddry(node) + qredsol(node) + qredfrs(node) + qredrwu(node)) * dt
      end do
      do node = 1,numnod
        inqssdi(node) = inqssdi(node) + qssdi(node) * dt
        iqssdi        = iqssdi + qssdi(node) * dt
      end do
      iqredwet     = iqredwet + qredwetsum*dt
      iqreddry     = iqreddry + qreddrysum*dt
      iqredsol     = iqredsol + qredsolsum*dt
      iqredfrs     = iqredfrs + qredfrssum*dt
      iqreddry_day = iqreddry_day + qreddrysum*dt
      iqredsol_day = iqredsol_day + qredsolsum*dt
      iqrot_day    = iqrot_day + qrotts
      iptra_day    = iptra_day + ptra * dt
      
      ialpwet_day = ialpwet_day + alpwetnoddrz * dt
      ialpdry_day = ialpdry_day + alpdrynodrtz * dt

      if (sw_inter /= 3) then
         iintc  = iintc + aintcdt * dt
      else
         iintc  = iintc + crsflx_out * dt
      end if

      iptra  = iptra + ptrats
      iepd   = iepd + epdts
      ipeva  = ipeva + pevats
      ievap  = ievap + revats
      iruno  = iruno + runots
      irunon = irunon + runon*dt
      igrai  = igrai + graidt*dt
      igird  = igird + gird*dt
      inrai  = inrai + nraidt*dt
      inird  = inird + nird*dt
      iqbot  = iqbot + qbotts
      if (qbotts < 0.0d0) then
         iqbdo = iqbdo - qbotts
      else if (qbotts > 0.0d0) then
         iqbup = iqbup + qbotts
      end if
      if (q(1) < 0.0d0) then
         iqtdo = iqtdo - q(1)*dt
      else
         iqtup = iqtup + q(1)*dt
      end if
      do node = 1, numnod+1
         if (q(node) < 0.0d0) then
            iqdo(node) = iqdo(node) - q(node)*dt
         else
            iqup(node) = iqup(node) + q(node)*dt
         end if
      end do

!      iQMaPo = iQMaPo +QMaPo*dt
! --- add time step fluxes to total cumulative values
      cqssdi = cqssdi + qssdisum*dt
      cqrot = cqrot + qrotts
      cqdra = cqdra + qdrats
      cptra = cptra + ptrats
      cepd = cepd + epdts
      cpeva = cpeva + pevats
      cevap = cevap + revats
      if (runots < 0.0d0) then
         cinund = cinund - runots
      else if (runots > 0.0d0) then
         crunoff = crunoff + runots
      end if

      if (sw_inter /= 3) then
         caintc  = caintc + aintcdt * dt
      else
         caintc  = caintc + crsflx_out * dt
      end if

      cgrai  = cgrai + graidt*dt
      cnrai  = cnrai + nraidt*dt
!      cnrai  = cgrai - caintc
      cgird  = cgird + gird*dt
      cnird  = cnird + nird*dt

      if (qbotts < 0.0d0) then
         cqbotdo = cqbotdo - qbotts
      else if (qbotts > 0.0d0) then
         cqbotup = cqbotup + qbotts
      end if
      cqbot = cqbot + qbotts

      ! rain on the ponding surface
      cqprai = cqprai + nraidt*dt    
      crunon = crunon + runon*dt     
      if (q(1) < 0.0d0) then
         cqtdo = cqtdo - q(1)*dt
      else if (q(1) > 0.0d0) then
         cqtup = cqtup + q(1)*dt
      end if

!     drainage
      if (swdra > 0) then
         iqdra = iqdra + qdrats 
         do node = 1, numnod
            do level = 1, nrlevs
               inqdra(level,node) = inqdra(level,node)+qdra(level,node)*dt
               if (qdra(level,node) > 0.0d0) then
                  inqdra_out(level,node) = inqdra_out(level,node) + qdra(level,node)*dt
               else
                  inqdra_in(level,node)  = inqdra_in(level,node) - qdra(level,node)*dt
               end if
            end do
         end do
         do level = 1,nrlevs
            ! infiltration
            if (qdrain(level) < 0.0d0) then
               cqdrainin(level) = cqdrainin(level) - qdrain(level)*dt
            ! drainage
            else if (qdrain(level) > 0.0d0) then
               cqdrainout(level) = cqdrainout(level) + qdrain(level)*dt
            end if      
            cqdrain(level) = cqdrain(level) + qdrain(level)*dt
         end do
      end if

   ! snow
      if (swsnow == 1) then
         cgsnow = cgsnow + gsnow*dt
         csubl  = csubl  + subl*dt
         cmelt  = cmelt  + melt*dt
         csnrai = csnrai + snrai*dt
         igsnow = igsnow + gsnow*dt
         isubl  = isubl  + subl*dt
         isnrai = isnrai + snrai*dt
      end if
      
      ! interception canopy reservoir
      isintc = isintc  + (crsflx_in - crsflx_out) * dt
      sicact = min(max(0.d0, sicact + (crsflx_in - crsflx_out) * dt), siccap)

   case (4)  ! perform integrations after update crop development
      
      ! interception canopy reservoir
      iintc  = iintc + siccaploss
      caintc = caintc + siccaploss
      isintc = isintc - siccaploss
      siccaploss = 0.d0
      
   case default
      call swap_error ('integral', 'Illegal value for ITASK')
   end select

   return
   end subroutine integral

end module MOD_integral
   
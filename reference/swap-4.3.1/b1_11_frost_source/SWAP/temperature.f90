module MOD_SoilTemperature

   use MOD_arrays, only: macp, maho, mabbc

   implicit none

   real(8),                            save :: tebot      = 0.0d0     ! Temperatures (oC) at bottom of soil profile
   real(8),                            save :: tetop      = 0.0d0     ! Temperatures (oC) at top of soil profile (under snow cover)
   real(8), dimension(macp),           save :: tsoil      = 0.0d0     ! Array with soil temperatures (oC) for each compartment
   real(8), dimension(macp),           save :: heacap     = 0.0d0     ! Array with heat capacity for all compartments (J/cm3/K)
   real(8), dimension(macp),           save :: heacon     = 0.0d0     ! Array with heat conductivity for all compartments (J/cm/K/d)

   ! extra for multiple SWAP instances
   integer,                            save :: ntembottab = 0         ! Number of specified bottom temperature (oC) as function of time (T)
   integer,                            save :: ntemtoptab = 0         ! Number of specified soil surface temperature (oC) as function of time (T)
   integer,                            save :: ntgtoptab  = 0         ! Number of specified soil surface heat fluxes (W/m2) as function of time (T)
   integer,                            save :: swbotbhea  = 0         ! Switch for bottom boundary condition: 1 = heat flux is zero; 2 = prescribed temperature
   integer,                            save :: swtopbhea  = 0         ! Switch for top boundary condition: 1 = use air temperatures; 2 = read measured surface temperatures
   integer,                            save :: nheat      = 0         ! Number of initial soil temperatures as provided in the input  (times 2; incl. index)
   real(8), dimension(mabbc),          save :: tembottab              ! Array with specified bottom temperature (oC) as function of time (T)
   real(8), dimension(mabbc),          save :: temtoptab              ! Array with specified soil surface temperature (oC) as function of time (T)
   real(8), dimension(mabbc),          save :: tgtoptab               ! Array with specified soil surface heat fluxes (W/m2) as function of time (T)
   real(8), dimension(maho),           save :: fclay                  ! Array with gravimetric content of clay (g/g mineral parts) of each numerical compartment
   real(8), dimension(maho),           save :: forg                   ! Array with gravimetric organic matter content (g/g mineral parts) of each numerical compartment
   real(8), dimension(maho),           save :: fquartz                ! Array with gravimetric content of sand+silt (g/g mineral parts) of each numerical compartment
   integer,                            save :: ipos_qtop  = 0
   integer,                            save :: ipos_tetop = 0
   integer,                            save :: ipos_tebot = 0
   ! constants
   real(8), dimension(maho),           save :: fkk_QCO_dry, fk_QCO_dry, fkk_QCO_wet, fk_QCO_wet

   ! (iii) Parameter declarations (used in subroutine DeVries, and some are public)
   ! (iii.i) Physical constants
   real(8), parameter :: kaa     = 1.0d0
   real(8), parameter :: kww     = 1.0d0

   ! Specific heats (J/kg/K)
   real(8), parameter :: cQuartz =  800.0d0
   real(8), parameter :: cClay   =  900.0d0
   real(8), parameter :: cWat    = 4180.0d0
   real(8), parameter :: cAir    = 1010.0d0
   real(8), parameter :: cOrg    = 1920.0d0
   
   ! Density (kg/m3)
   real(8), parameter :: dQuartz = 2660.0d0
   real(8), parameter :: dClay   = 2650.0d0
   real(8), parameter :: dWat    = 1000.0d0
   real(8), parameter :: dAir    =    1.2d0
   real(8), parameter :: dOrg    = 1300.0d0
   
   ! Thermal conductivities (W/m/K)
   real(8), parameter :: kQuartz = 8.8d0
   real(8), parameter :: kClay   = 2.92d0
   real(8), parameter :: kWat    = 0.57d0
   real(8), parameter :: kAir    = 0.025d0
   real(8), parameter :: kOrg    = 0.25d0
   !
   real(8) GAir,GAirdry
   real(8), parameter :: GQuartz = 0.14d0
   real(8), parameter :: GClay   = 0.125d0
   real(8), parameter :: GWat    = 0.14d0
   real(8), parameter :: GOrg    = 0.5d0
   ! (iii.ii) theta 0.02, 0.05 and 1.00
   real(8), parameter :: thetaDry = 0.02d0
   real(8), parameter :: thetaWet = 0.05d0
! -------------------------------------------------------------------
   ! (0) Weights for each component in conductivity calculations
   ! (Calculate these but define as parameters in later version)
   real(8), parameter :: kqw = 0.66d0 / (1.0d0 + (kQuartz/kWat - 1.0d0) * GQuartz) + 0.33d0 / (1.0d0 + (kQuartz/kWat - 1.0d0) * (1.0d0 - 2.0d0 * GQuartz))
   real(8), parameter :: kcw = 0.66d0 / (1.0d0 + (kClay/kWat   - 1.0d0) * GClay)   + 0.33d0 / (1.0d0 + (kClay/kWat   - 1.0d0) * (1.0d0 - 2.0d0 * GClay))
   real(8), parameter :: kow = 0.66d0 / (1.0d0 + (kOrg/kWat    - 1.0d0) * GOrg)    + 0.33d0 / (1.0d0 + (kOrg/kWat    - 1.0d0) * (1.0d0 - 2.0d0 * GOrg))
   real(8), parameter :: kwa = 0.66d0 / (1.0d0 + (kWat/kAir    - 1.0d0) * GWat)    + 0.33d0 / (1.0d0 + (kWat/kAir    - 1.0d0) * (1.0d0 - 2.0d0 * GWat))
   real(8), parameter :: kqa = 0.66d0 / (1.0d0 + (kQuartz/kAir - 1.0d0) * GQuartz) + 0.33d0 / (1.0d0 + (kQuartz/kAir - 1.0d0) * (1.0d0 - 2.0d0 * GQuartz))
   real(8), parameter :: kca = 0.66d0 / (1.0d0 + (kClay/kAir   - 1.0d0) * GClay)   + 0.33d0 / (1.0d0 + (kClay/kAir   - 1.0d0) * (1.0d0 - 2.0d0 * GClay))
   real(8), parameter :: koa = 0.66d0 / (1.0d0 + (kOrg/kAir    - 1.0d0) * GOrg)    + 0.33d0 / (1.0d0 + (kOrg/kAir    - 1.0d0) * (1.0d0 - 2.0d0 * GOrg))

   ! additional constants
   real(8), parameter :: kAirDIVkWat = kAir/kWat
   real(8), parameter :: cdQuartz    = dQuartz*cQuartz
   real(8), parameter :: cdClay      = dClay*cClay
   real(8), parameter :: cdWat       = dWat*cWat
   real(8), parameter :: cdAir       = dAir*cAir
   real(8), parameter :: cdOrg       = dOrg*cOrg
   real(8), parameter :: kqaXkQuartz = kqa*kQuartz
   real(8), parameter :: kcaXkClay   = kca*kClay
   real(8), parameter :: kaaXkAir    = kaa*kAir
   real(8), parameter :: koaXkOrg    = koa*kOrg
   real(8), parameter :: kwaXkWat    = kwa*kWat
   real(8), parameter :: kqwXkQuartz = kqw*kQuartz
   real(8), parameter :: kcwXkClay   = kcw*kClay
   real(8), parameter :: kowXkOrg    = kow*kOrg
   real(8), parameter :: kwwXkWat    = kww*kWat

   ! everything is private
   private
   ! except for the following function/subroutine
   public      :: SoilTemperature, temperature_numeric, temperature_analytic
   ! except for the following variables
   public      :: tetop, tebot, tsoil, heacap, heacon
   ! extra for multiple SWAP instances
   public      :: ntembottab, ntemtoptab, ntgtoptab, swbotbhea, swtopbhea, tembottab, temtoptab, tgtoptab, fclay, forg, fquartz, nheat
   public      :: ipos_qtop, ipos_tetop, ipos_tebot
   public      :: fkk_QCO_dry, fk_QCO_dry, fkk_QCO_wet, fk_QCO_wet
   ! for MOD_soil_info
   public      :: kqw, kcw, kow, kqa, kca, koa
   public      :: kqaXkQuartz, kcaXkClay, koaXkOrg, kqwXkQuartz, kcwXkClay, kowXkOrg

   contains

! ----------------------------------------------------------------------
   subroutine SoilTemperature(Task)
! ----------------------------------------------------------------------

      use MOD_swap_base, only: swcalt

      implicit none
      ! global
      integer, intent(in) :: Task

      select case (Task)
      case(1)

         ! heat variables
         if (swcalt == 1) then
            call temperature_analytic(Task)
         else
            call temperature_numeric(Task)
         end if

      case(11)

         ! heat variables
         call temperature_numeric(Task)

      case(2)

         if (swcalt == 1) then
            call temperature_analytic(Task)
         else
            call temperature_numeric(Task)
         end if

      case(3,4,5,6,7,8,9)

         continue

      case default

         call swap_error ('soiltemperature', 'Illegal Task option')

      end select

   end subroutine SoilTemperature

! ----------------------------------------------------------------------
   subroutine temperature_numeric(task)
! ----------------------------------------------------------------------
!     date               : november 2004
!     purpose            : calculate soil temperatures
! ----------------------------------------------------------------------

      use atmosphere_interface, only: tav
      use MOD_swap_base,      only: swinco
      use MOD_snow,           only: ssnow
      use MOD_texture_orgmat, only: orgmat, pclay, psand, psilt

      use variables,          only: theta, thetm1
      use MOD_grid,           only: numnod, z, dz, disnod, numlay
      use variables,          only: t1900, dt, thetsl

      implicit none
      
      ! heat variables (numerical temperature function)
      real(8), dimension(:), allocatable, save  :: tsoiltb                ! Array with initial soil temperatures as function of soil depth

      ! global
      integer, intent(in)                       :: task

      ! local, to be saved
      real(8), dimension(macp),           save  :: tmpold
      real(8), dimension(macp),           save  :: thoma, thomb, thomc, thomf, thomx
      real(8), dimension(macp),           save  :: theave, heacnd

      ! local
      integer                                   :: i, lay, ierror, ipos
      real(8)                                   :: dummy, gmineral
      real(8)                                   :: heaconbot, qhbot, QTtop
      real(8)                                   :: apar, dzsnw, heaconsnw, Rosnw
      character(len=200)                        :: message

! ----------------------------------------------------------------------

      select case (task)
      
      case (1)

         ! === initialization ===
         call read_soiltemperature

         ! determine initial temperature profile
         ! numerical solution, use specified soil temperatures
         if (swinco /= 3) then
            tsoil = 0.0d0; ipos = 0
            do i = 1, numnod
               call afgen_2(tsoiltb, nheat, dabs(z(i)), tsoil(i), ipos)
            end do
            if (allocated(tsoiltb)) deallocate(tsoiltb)
         end if

         ! initialize dry bulk density and volume fractions sand, clay and organic matter
         do lay = 1, numlay
            dummy        = orgmat(lay)/(1.0d0 - orgmat(lay))
            gmineral     = (1.0d0 - thetsl(lay)) / (0.370d0 + 0.714d0*dummy)
            fquartz(lay) = (psand(lay) + psilt(lay))*gmineral/2.7d0
            fclay(lay)   = pclay(lay)*gmineral/2.7d0
            forg(lay)    = dummy*gmineral/1.4d0
         end do

         ! initialize DeVries
         call DeVries(1, theave, heacap, heacnd)

      case (11)

         ! === initialization ===

         ! initialize dry bulk density and volume fractions sand, clay and organic matter
         do lay = 1, numlay
            dummy        = orgmat(lay)/(1.0d0 - orgmat(lay))
            gmineral     = (1.0d0 - thetsl(lay)) / (0.370d0 + 0.714d0*dummy)
            fquartz(lay) = (psand(lay) + psilt(lay))*gmineral/2.7d0
            fclay(lay)   = pclay(lay)*gmineral/2.7d0
            forg(lay)    = dummy*gmineral/1.4d0
         end do

         ! Initialize DeVries
         call DeVries(1, theave, heacap, heacnd)

      case (2)

           ! === soil temperature rate and state variables ===
         
           ! --- numerical solution ---

           if (swtopbhea == 4) then
              call afgen_2(tgtoptab, 2*ntgtoptab, t1900, QTtop, ipos_qtop)
              QTtop = QTtop * 8.64d0
              call afgen_2(temtoptab, 2*ntemtoptab, t1900, TeTop, ipos_tetop)
           else if (swtopbhea == 3) then
              ! use specified soil heat fluxes as top boundary condition
              call afgen_2(tgtoptab, 2*ntgtoptab, t1900, QTtop, ipos_qtop)
              QTtop = QTtop * 8.64d0
           else if (swtopbhea == 2) then
              ! use specified soil surface temperatures as top boundary condition
              call afgen_2(temtoptab, 2*ntemtoptab, t1900, TeTop, ipos_tetop)
           else if (dabs(ssnow) > 1.0d-10) then
              ! air temperature can not be used with a snow layer, calculate temperature on soil- snow interface
              Rosnw     = 170.d0
              heaconsnw = 2.86d-6 * 864.d0 * Rosnw**2
              dzsnw     = ssnow / 0.17d0
              if (heacon(1) < 1.d-10) heacon(1) = 100.d0
              apar = (0.5d0*heaconsnw*dz(1)) / (heacon(1)*dzsnw)
              TeTop = (Tsoil(1) + apar*tav) / (1.d0+apar)
           else
              TeTop = tav
           end if

           if (SwBotbHea == 1) then
              ! no heat flow through bottom of profile assumed
              TeBot = Tsoil(Numnod)
           else if (SwBotbHea == 2) then
              ! bottom temperature is prescribed
              call afgen_2(tembottab, 2*ntembottab, t1900+dt, TeBot, ipos_tebot)
           end if

           ! save old temperature profile
           tmpold = 0.0d0
           tmpold(1:numnod) = tsoil(1:numnod)

           ! compute heat conductivity and capacity
           theave(1:numnod) = 0.5d0 * (theta(1:numnod) + thetm1(1:numnod))

           ! calculate nodal heat capacity and thermal conductivity
           call DeVries(2, theave, heacap, heacnd)
           heacon(1)        = heacnd(1)
           heacon(2:numnod) = 0.5d0 * (heacnd(2:numnod) + heacnd(1:(numnod-1)))

           ! --- calculate new temperature profile ---

           ! calculation of coefficients for node = 1
           i = 1
           ! temperature fixed at soil surface
           if (swtopbhea == 4) then
              thoma(i) = 0.0d0
              thomc(i) = 0.0d0
              thomb(i) = 1.0d0
              thomf(i) = TeTop - disnod(i)/heacon(i) * QTtop
           else if (swtopbhea < 3) then
              thoma(i) = - dt * heacon(i) / (dz(i) * disnod(i))
              thomc(i) = - dt * heacon(i+1) / (dz(i) * disnod(i+1))
              thomb(i) = heacap(i) - thoma(i) - thomc(i)
              thomf(i) = heacap(i) * tmpold(i) - thoma(i) * TeTop
           else
              thomc(i) = - dt * heacon(i+1) / (dz(i) * disnod(i+1))
              thomb(i) = heacap(i) - thomc(i)
              thomf(i) = heacap(i) * tmpold(i) + QTtop * dt/dz(i)
           end if

           ! calculation of coefficients for 2 < node < numnod
           do i = 2, numnod-1
             thoma(i) = - dt * heacon(i) / (dz(i) * disnod(i))
             thomc(i) = - dt * heacon(i+1) / (dz(i) * disnod(i+1))
             thomb(i) = heacap(i) - thoma(i) - thomc(i)
             thomf(i) = heacap(i) * tmpold(i)
           end do

           ! calculation of coefficients for node = numnod
           i = numnod
           if (SwBotbHea == 1) then
              ! no heat flow through bottom of profile assumed
              qhbot    = 0.0d0
              thoma(i) = - dt * heacon(i) / (dz(i) * disnod(i))
              thomb(i) = heacap(i) - thoma(i)
              thomf(i) = heacap(i) * tmpold(i) - (qhbot * dt)/dz(i)
           else if (SwBotbHea == 2) then
              ! bottom temperature is prescribed
              heaconBot = heacnd(i)
              thoma(i)  = - dt * heacon(i) / (dz(i) * disnod(i))
              thomc(i)  = - dt * heaconBot / (dz(i) * 0.5d0 * dz(i))
              thomb(i)  = heacap(i) - thoma(i) - thomc(i)
              thomf(i)  = heacap(i) * tmpold(i) - thomc(i) * TeBot
           end if

           ! solve for vector tsoil a tridiagonal linear set
           call tridag (numnod, thoma, thomb, thomc, thomf, thomx, ierror)
           if (ierror /= 0) then
              message = 'During a call from Temperature an error occured in TriDag'
              call swap_error ('temperature_numeric',message)
           end if
           tsoil(1:numnod) = thomx(1:numnod)
           ! estimate TeTop in case swtopbhea == 3
           if (swtopbhea == 3) TeTop = tsoil(1) + QTtop * 0.5d0 * dz(1) / heacon(1)

      case default
         call swap_error ('temperature_numeric', 'Illegal value for TASK')
      end select

      return

      contains

!***********************************************************************
      subroutine DeVries (iTask, theta, HeaCap, HeaCon)
!***********************************************************************
!* Purpose:    Calculate soil heat capacity and conductivity for each  *
!*             compartment by full de Vries model                      *
!* References:                                                         *
!* Description:                                                        *
!* de Vries model for soil heat capcity and thermal conductivity.      *
!* Heat capacity is calculated as average of heat capacities for each  *
!* soil component. Thermal conductivity is calculated as weighted      *
!* average of conductivities for each component. If theta > 0.05 liquid*
!* water is assumed to be the main transport medium in calculating the *
!* weights. If theta < 0.02 air is assumed to be the main transport    *
!* medium (there is also an empirical adjustment to the conductivity). *
!* For 0.02 < theta < 0.05 conductivity is interpolated.               *
!* See: Heat and water transfer at the bare soil surface, H.F.M Ten    *
!* Berge (pp 48-54 and Appendix 2)                                     *
!***********************************************************************
!* Input:                                                              *
!* NumNod - number of compartments (-)                                 *
!* theta/THETAS - volumetric soil moisture/ saturated vol. s. moist (-)*
!* Fquartz, Fclay and Forg - volume fractions of sand, clay and org.ma.*
!* Output:                                                             *
!* HeaCap - heat capacity (J/m3/K)                                     *
!* HeaCon - thermal conductivity (W/m/K)                               *
!***********************************************************************
         use variables, only: THETAS
         use MOD_grid,  only: numlay, layer
         implicit none

         ! global declarations
         integer,                    intent(in)  :: iTask
         real(8), dimension(numnod), intent(in)  :: theta  ! NOTE: this not the same as theta in VARIABLES, since on input it is some average water content
         real(8), dimension(numnod), intent(out) :: HeaCap, HeaCon

         ! local declarations
         integer Node
         real(8) kaw
         real(8), dimension(:), allocatable, save :: fAir
         real(8)                                  :: HeaConDry, HeaConWet

         select case(iTask)
         case(1)

            ! allocatelocal array
            if (allocated(fAir))        deallocate(fAir);        allocate(fAir(numnod))

            ! we assume that sand, silt and OM contents remain constant in time; storelocal constants
            fkk_QCO_dry(1:numlay) = fQuartz(1:numlay)*kqaXkQuartz + fClay(1:numlay)*kcaXkClay + fOrg(1:numlay)*koaXkOrg
            fk_QCO_dry(1:numlay)  = fQuartz(1:numlay)*kqa         + fClay(1:numlay)*kca       + fOrg(1:numlay)*koa
            fkk_QCO_wet(1:numlay) = fQuartz(1:numlay)*kqwXkQuartz + fClay(1:numlay)*kcwXkClay + fOrg(1:numlay)*kowXkOrg
            fk_QCO_wet(1:numlay)  = fQuartz(1:numlay)*kqw         + fClay(1:numlay)*kcw       + fOrg(1:numlay)*kow

         case(2)

            ! (1) Air fraction and related parameters
            fAir(1:numnod) = dmax1(0.0d0, THETAS(1:numnod) - theta(1:numnod))

            ! (2) Heat capacity (W/m3/K) is average of heat capacities for all components (multiplied by density for correct units); conversion of capacity from J/m3/K to J/cm3/K (*1.0d-6)
            HeaCap(1:numnod) = (fQuartz(layer(1:numnod))*cdQuartz + fClay(layer(1:numnod))*cdClay + fOrg(layer(1:numnod))*cdOrg + theta(1:numnod)*cdWat + fAir(1:numnod)*cdAir) * 1.0d-6

            do Node = 1, NumNod

               ! (1) Determine shape factor of air
               if (theta(node) > thetadry) then
                 GAir    = 0.333d0 - fair(node)/thetas(node)*0.298d0
               else
                 GAirdry = 0.333d0 - fair(node)/thetas(node)*0.298d0
                 GAir    = 0.013d0 + theta(node)/thetaDry*(GAirdry - 0.013d0)
               end if

               ! (2) Determine weighting factor air - water
               kaw = 0.66d0 / (1.0d0 + ((kAirDIVkWat) - 1.0d0) * GAir) + 0.33d0/(1.0d0 + ((kAirDIVkWat) - 1.0d0) * (1.0d0 - 2.0d0 * GAir))

               ! (3) Thermal conductivity (W/m/K) is weighted average of conductivities of all components
               ! ---    conversion of conductivity from W/m/K to J/cm/K/d (*864.0d0)
               ! (3.1) Dry conditions (include empirical correction) (eq. 3.44)
               if (theta(Node) <= thetaDry) then
                  HeaCon(Node) = (fkk_QCO_dry(layer(Node)) + fAir(Node)*kaaXkAir + theta(Node)*kwaXkWat) / (fk_QCO_dry(layer(Node)) + fAir(Node)*kaa + theta(Node)*kwa) * 1.25d0 * 864.0d0

               ! (3.2) Wet conditions  (eq. 3.43)
               else if (theta(Node) >= thetaWet) then
                  HeaCon(Node) = (fkk_QCO_wet(layer(Node)) + fAir(Node)*kaw*kAir + theta(Node)*kwwXkWat) / (fk_QCO_wet(layer(Node)) + fAir(Node)*kaw + theta(Node)*kww) * 864.0d0

               ! (3.3) dry < theta < wet (interpolate)
               else
                  ! (3.3.1) Conductivity for theta = 0.02
                  HeaConDry = (fkk_QCO_dry(layer(Node)) + fAir(Node)*kaaXkAir + thetaDry*kwaXkWat) / (fk_QCO_dry(layer(Node)) + fAir(Node)*kaa + thetaDry*kwa) * 1.25d0
                  ! (3.3.2) Conductivity for theta = 0.05
                  HeaConWet = (fkk_QCO_wet(layer(Node)) + fAir(Node)*kaw*kAir + thetaWet*kwwXkWat) / (fk_QCO_wet(layer(Node)) + fAir(Node)*kaw + thetaWet*kww)
                  ! (3.3.3) Interpolate
                  HeaCon(Node) = (HeaConDry + (theta(Node)-thetaDry) * (HeaConWet - HeaConDry) / (thetaWet - thetaDry)) * 864.0d0
               end if

            end do

         case default
            call swap_error ('DeVries', 'Illegal value for iTASK')
         end select

         return
      end subroutine DeVries

! ----------------------------------------------------------------------
      subroutine read_soiltemperature
! ---------------------------------------------------------------------

         use MOD_swap_base, only: iun_min2, iun_max2, unit_swp, swpfilnam, pathwork, unit_err, fl_initialize
         use variables, only : tstart, tend

         implicit none
         
         ! local, not to save
         integer :: unit_tss
         real(8) :: gc
         real(8), dimension(:), allocatable :: z_ini, t_ini
         character(len=80) :: tsoilfile, TGsoilfile, filnam
         character(len=200) :: message
         logical :: file_exists

         ! functions
         integer :: getun2
         logical :: rdinqr
         
! =================================================================
         ! Section heat flow

         ! switch whether simulation includes heat simulation or not
         call rdinit(unit_swp, unit_err, swpfilnam)

            ! top boundary temperature
            call rdsinr ('swtopbhea', 1, 4, SwTopbHea)
            Tsoilfile = ' '
            if (swtopbhea == 2 .OR. swtopbhea == 4) call rdscha ('tsoilfile', tsoilfile)
            TGsoilfile = ' '
            if (swtopbhea == 3 .OR. swtopbhea == 4) call rdscha ('tgsoilfile', TGsoilfile)

            ! bottom boundary temperature
            call rdsinr ('swbotbhea', 1, 2, SwBotbHea)
            if (swbotbhea == 2) then
               if (.NOT. rdinqr('datet')) call swap_error ('read_soiltemperature', 'Variable DATET not present in file '//trim(swpfilnam))
               call rdinne('datet', ntembottab)
               if (2*ntembottab > mabbc) call swap_error('read_soiltemperature','Number of input data for T bottom BC too large (must be <= mabbc/2)')
               call read_tab_bc('read_soiltemperature swbotbhea=2', 'tbot', tstart, tend, -50.0d0, 50.d0, ntembottab, 1.0d0, tembottab)
            end if

            ! initial soil temperature
            if (.NOT. fl_initialize) then
               
               ! old procedure (deprecated)
               if (rdinqr('tsoil')) then
              
                  message = 'Usage of ZH and TSOIL are deprecated, use TSOILTB instead'
                  call swap_warning('read_soiltemperature', message)
             
                  call rdinne ('tsoil',nheat)
                  allocate(z_ini(nheat)); allocate(t_ini(nheat))
                  if (allocated(tsoiltb)) deallocate(tsoiltb); allocate(tsoiltb(nheat*2)); tsoiltb = 0.d0

                  call rdfdor ('zh',-1.0d5,0.0d0,z_ini,nheat,nheat)
                  call rdfdor ('tsoil',-50.0d0,50.0d0,t_ini,nheat,nheat)
            
                  do i = 1, nheat
                     tsoiltb(i*2) = t_ini(i)
                     tsoiltb(i*2-1) = dabs(z_ini(i))
                  end do
                  nheat = nheat*2
              
                  deallocate(z_ini, t_ini)
            
               ! new procedure
               else
               
                  if (.NOT. rdinqr('tsoiltb')) call swap_error ('read_soiltemperature', 'Variable TSOILTB not present in file '//trim(swpfilnam))
                  call rdinne ('tsoiltb',nheat)
                  if (allocated(tsoiltb)) deallocate(tsoiltb); allocate(tsoiltb(nheat)); tsoiltb = 0.d0
                  call rdadortb('tsoiltb', -1.0d5, 0.d0, -50.d0, 50.d0, tsoiltb, nheat, .TRUE.)
            
               end if
            end if
            
         close(unit_swp)

         ! read soil surface temperatures
         if (swtopbhea == 2 .OR. swtopbhea == 4) then
            filnam = trim(pathwork)//trim(tsoilfile)//'.tss'
            inquire(file = filnam, exist = file_exists)
            if (.NOT. file_exists) then
               message ='File '//trim(filnam)//' does not exists!'
               call swap_error ('read_soiltemperature', message)
            end if
            unit_tss = getun2 (iun_min2, iun_max2, 2)
            call rdinit(unit_tss, unit_err, filnam)
               if (.NOT. rdinqr('datet')) call swap_error ('read_soiltemperature', 'Variable DATET not present in file '//trim(tsoilfile)//'.tss')
               call rdinne('datet', ntemtoptab)
               if (2*ntemtoptab > mabbc) call swap_error('read_soiltemperature','Number of input data for T top BC too large (must be <= mabbc/2)')
               call read_tab_bc('read_soiltemperature swtopbhea=2', 'ttop', tstart, tend, -50.0d0, 50.d0, ntemtoptab, 1.0d0, temtoptab)
            close (unit_tss)
         end if

         ! read soil surface heat fluxes
         if (swtopbhea == 3 .OR. swtopbhea == 4) then
            filnam = trim(pathwork)//trim(tgsoilfile)//'.tgs'
            inquire(file = filnam, exist = file_exists)
            if (.NOT. file_exists) then
               message ='File '//trim(filnam)//' does not exists!'
               call swap_error ('read_soiltemperature', message)
            end if
            unit_tss = getun2 (iun_min2, iun_max2, 2)
            call rdinit(unit_tss, unit_err, filnam)
               gc = 1.0d0
               if (rdinqr('gc')) call rdsdor ('gc', 0.0d0, 1000.0d0, gc)
               if (.NOT. rdinqr('datet')) call swap_error ('read_soiltemperature', 'Variable DATET not present in file '//trim(tgsoilfile)//'.tgs')
               call rdinne('datet', ntgtoptab)
!               if (allocated(tgtoptab)) deallocate(tgtoptab); allocate(tgtoptab(2*ntgtoptab))
               if (2*ntgtoptab > mabbc) call swap_error('read_soiltemperature','Number of input data for T bottom BC too large (must be <= mabbc/2)')
               call read_tab_bc('read_soiltemperature swtopbhea=3', 'TGtop', tstart, tend, -500.0d0, 1500.d0, ntgtoptab, gc, tgtoptab)
            close (unit_tss)
         end if

      end subroutine read_soiltemperature

! ----------------------------------------------------------------------

! ----------------------------------------------------------------------
      subroutine read_tab_bc(description, variable, tstart, tend, minval, maxval, nvals, factor, table)
! ----------------------------------------------------------------------
         implicit none
         ! global
         integer,                     intent(in)  :: nvals
         real(8),                     intent(in)  :: tstart, tend, minval, maxval, factor
         real(8), dimension(2*nvals), intent(out) :: table
         character(len=*),            intent(in)  :: description, variable
         ! local
         integer :: i
         real(8), dimension(:), allocatable       :: dates, bc_vals

         ! NB: file is already open
         allocate(dates(nvals))
         allocate(bc_vals(nvals))
         call rdftim ('datet', dates, nvals, nvals)
         ! at least one date must be within simulation period
         call checkdate(nvals, dates, tend, tstart, 'datet', description)
         call rdfdor(variable, minval, maxval, bc_vals, nvals, nvals)
         do i = 1, nvals
            table(i*2-1) = dates(i)
            table(i*2)   = bc_vals(i) * factor
         end do
         deallocate(dates)
         deallocate(bc_vals)

      end subroutine read_tab_bc
   end subroutine temperature_numeric

   subroutine temperature_analytic(task)
! ----------------------------------------------------------------------
!     date               : november 2004
!     purpose            : calculate soil temperatures; analytic model
! ----------------------------------------------------------------------

      use MOD_grid,      only: numnod, z
      use MOD_swap_base, only: unit_swp, swpfilnam, unit_err
      use variables,     only: daynr
      implicit none

      ! global
      integer, intent(in)                       :: task
      ! local
      integer                                   :: i
      real(8), save                             :: halfpi,omega
      real(8)                                   :: pi
      ! for analytical soil temperature function
      real(8), save                             :: ddamp      = 0.0d0     ! Damping depth (L) of temperature wave in soil
      real(8), save                             :: tampli     = 0.0d0     ! Amplitude of prescribed annual temperature wave (oC) at soil surface
      real(8), save                             :: timref     = 0.0d0     ! Time in the year (T) with top of prescribed sine temperature wave
      real(8), save                             :: tmean      = 0.0d0     ! Prescribed mean annual temperature (oC) at soil surface
! ----------------------------------------------------------------------

      select case (task)
      case (1)

         pi     = 4.0d0*atan(1.0d0)
         halfpi = 0.5d0 * pi
         omega  = 2.0d0 * pi / 365.0d0

         ! === initialization ===
         call rdinit(unit_swp, unit_err, swpfilnam)
            call rdsdor ('tampli',   0.0d0,  50.0d0, tampli)
            call rdsdor ('tmean',  -10.0d0,  30.0d0, tmean)
            call rdsdor ('timref',   0.0d0, 366.0d0, timref)
            call rdsdor ('ddamp',    1.0d0, 500.0d0, ddamp)
         close(unit_swp)

         ! determine initial temperature profile
         
         ! analytical solution
         forall(i = 1:numnod) tsoil(i) = T_anal(daynr, z(i), tmean, tampli, halfpi, omega, timref, ddamp)

      case (2)

         ! === soil temperature rate and state variables ===
         
         ! analytical solution temperature profile
         forall(i = 1:numnod) tsoil(i) = T_anal(daynr, z(i), tmean, tampli, halfpi, omega, timref, ddamp)

      case default
         call swap_error ('temperature_analytic', 'Illegal value for TASK')
      end select

      return
   end subroutine temperature_analytic

   pure function T_anal(daynr, z, tmean, tampli, halfpi, omega, timref, ddamp)
      implicit none
      integer, intent(in)  :: daynr
      real(8), intent(in)  :: z, tmean, tampli, halfpi, omega, timref, ddamp
      real(8)              :: T_anal
      T_anal = tmean + tampli * (dsin(halfpi + omega*(dble(daynr)-timref) + z/ddamp)) * dexp(z/ddamp)
   end function T_anal

end module MOD_SoilTemperature

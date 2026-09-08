module MOD_snow

! --- snow variables
   integer, save  :: snw       = 0        ! Internal number of output file *.SNW with snow pack data
   integer, save  :: swsublim  = 0        ! Switch for suppressing simulation of sublimation of snow: 1 = suppress ! Adaptation 3 for PEARL-MACRO
   real(8), save  :: gsnow     = 0.0D0    ! Gross snow rate (L/T)
   real(8), save  :: melt      = 0.0D0    ! Melting rate (L/T)
   real(8), save  :: slw       = 0.0D0    ! liquid water stored in snow pack           ! RobPearlMacro
   real(8), save  :: snowcoef  = 0.0d0    ! Snow melt factor (-)
   real(8), save  :: snowinco  = 0.0d0    ! Amount of snow (L water) at start of balance period
   real(8), save  :: snrai     = 0.0D0    ! Net rain rate on snow pack (L/T)
   real(8), save  :: ssnow     = 0.0D0    ! Amount of snow (L water)
   real(8), save  :: subl      = 0.0D0    ! Sublimation rate (L/T)
   real(8), save  :: TePrRain  = 0.0D0    ! Temperature above which all precipitation is rain,[ 0.0...5.0 oC, R]
   real(8), save  :: TePrSnow  = 0.0d0    ! Temperature below which all precipitation is snow,[-5.0...0.0 oC, R]

   public

   contains

! File VersionID:
!   $Id: snow.f90 312 2016-12-22 21:18:18Z kroes006 $
! ----------------------------------------------------------------------
      subroutine snow(task, tsoil1, tav, epond, peva, empreva)
! ----------------------------------------------------------------------
!     date               : December 2004
!     purpose            : Simulation snow accumulation and melt
! ----------------------------------------------------------------------
      use MOD_swap_base, only: fl_initialize
      
      implicit none
      ! global (global arguments cannot beimported from modules Temperature and Meteo because of circularity)
      integer, intent(in)    :: task        
      real(8), intent(in)    :: tsoil1, tav
      real(8), intent(inout) :: peva, empreva, epond
      ! local
      real(8)                :: smelt      ! snowmelt by temperature [cm swe]
      real(8)                :: smeltr     ! snowmelt by rain [cm swe]
      real(8)                :: SnDefit
      real(8)                :: SnLoss
      real(8)                :: slw_max    ! max storage of liquid water snow [cm/d]
      real(8)                :: qlw        ! storage of drained flux from snow pack [cm/d]
      
! --- constants
      real(8), parameter     :: cwat =   4180.0d0        ! specific heat of water [j/kg/k]
      real(8), parameter     :: lm   = 333580.0d0        ! latent heat of melting [j/kg] 
      real(8), parameter     :: ts   =      0.0d0        ! snow temperature [0 oc] 

! ----------------------------------------------------------------------
      select case (task)
      case (1)

! === initialization ===================================================
         if (fl_initialize) then
           snowinco = ssnow
         else
           ssnow = snowinco
         end if

         return

      case (2)

! === snow pack rate and state variables ===============================

! --- when there is snowpack calculate the amount of sublimation
      subl = 0.0d0
      if (swsublim == 0) then
         if (ssnow > 0.0d0) then
           subl = peva
           epond = 0.0d0
           empreva = 0.0d0
           peva = 0.0d0
         end if
      end if

! --- when the soil surface is above the freezing point there will be
! --- no accumulation of fresh snow. 
      if (tsoil1 > 0.5d0 .AND. ssnow < 1.0d-6 .AND. gsnow > 0.0d0) then
        ssnow = 0.0d0
        melt = gsnow
        subl = 0.d0
      else   
        
! ---   amount of snowmelt [cm swe] negative values of smelt: see 'melt = ' 
        smelt = snowcoef * (tav-ts) 
        
! ---   extra snowmelt when there falls rain on the snowpack [cm swe]
        if (snrai > 0.0d0) then
          smeltr = snrai * cwat * (tav-ts) / lm  
        else
          smeltr = 0.0d0
        end if

! ---   total snowmelt [cm swe]; negative values of smelt can partly compensate smeltr
        melt = max(0.0d0,(smelt + smeltr))
      
! ---   amount of snow left [cm swe] without storage of liquid water slw
        ssnow = ssnow + gsnow - subl - melt- slw

! ---   potential amount of liquid water storage
        slw = slw + snrai
! ---   maximum retention of liquid water in snow is fraction 0.07 of total water storage
        slw_max = 0.07d0 * (slw + ssnow)
! ---   drainage of liquid water from snow
        qlw = max(0.0d0,slw-slw_max)
! ---   remaining storage of liquid water in snow
        slw = slw - qlw
! ---   reset total snow storage and total melt
        ssnow = ssnow + slw
        melt = melt + qlw

! ---   in case of snow deficit: adapt snow loss terms melt and sublimation
        if (ssnow < 0.0d0) then
          SnDefit = - Ssnow
          SnLoss  = melt + subl
          melt    = (1.d0 - SnDefit/SnLoss) * melt
          subl    = (1.d0 - SnDefit/SnLoss) * subl
          Ssnow   = 0.d0
          slw     = 0.d0
        end if
      end if

      case default
         call swap_error ('snow', 'Illegal value for TASK')
      end select

      return
      end subroutine snow

end module MOD_snow

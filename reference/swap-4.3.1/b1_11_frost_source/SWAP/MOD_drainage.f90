module MOD_drain

   use MOD_arrays, only: madr, maho, macp, mamp, mawlp, mamte, mawls, maowl

   implicit none

   ! Interfaces to main entries of underlying submodules 
   interface
   
      ! Submodule SMOD_drainage_basic
     ! module subroutine drainage()
     ! end subroutine drainage
  
      !module subroutine drainflux_basic()
      !end subroutine drainflux_basic
   
      !module subroutine read_drainage_basic()
      !end subroutine read_drainage_basic

      ! Submodule SMOD_drainage_extended
      !module subroutine surfacewater(itask)
      !   integer, intent(in) :: itask
      !end subroutine surfacewater
   
      !module subroutine drainflux_extended()
      !end subroutine drainflux_extended
   
      !module subroutine read_drainage_extended()
      !end subroutine read_drainage_extended
   
      ! Submodule SMOD_divdra
      module subroutine divdra(ksatcp, gwlev)
         use MOD_arrays, only: macp
         real(8), dimension(macp), intent(in)   :: ksatcp
         real(8),                  intent(in)   :: gwlev
      end subroutine divdra
   
   end interface
   ! all interface entries must be declared public
   ! public :: drainage, drainflux_basic, read_drainage_basic, surfacewater, drainflux_extended, read_drainage_extended, divdra

!  Common drainage parameters
   integer,                         save ::   swdivd          = 0    ! Switch to distribute drainage flux vertically according to transmissivity: 0 = no; 1 = yes
   integer,                         save ::   swdivdinf       = 0    ! Switch to distribute infiltration flux vertically according to transmissivity, separatly from drainage fluxes: 0 = no; 1 = yes
   integer,                         save ::   swdislay        = 0    ! Switch to distribute drainage flux vertically with a given position of the top of the model discharge layers: 0 = no; 1 = yes
   integer, dimension(madr),        save ::   swdtyp          = 0    ! Switch for type of drainage medium: 1 = drain tube, 2 = open channel
   integer,                         save ::   swliminf        = 1    ! Switch for limit of infiltration head to the waterdepth in the channel: 0 = nolimit, 1 = limitation
   integer,                         save ::   swnrsrf         = 0    ! Switch for interflow relations: 0 = no interflow, 1-2 = interflow (differ for basic / extended drainage)
   integer, dimension(madr),        save ::   swtopdislay     = 0    ! Switch, for each drainage level, to distribute drainage flux vertically with a given position of the top of the model discharge layers: 0 = no; 1 = yes
   integer,                         save ::   swtopnrsrf      = 0    ! Switch to enable adjustment of model discharge layer, in case swnrsrf > 0: 0 = no, 1 = yes
   real(8), dimension(maho),        save ::   cofani          = 0.d0 ! Anisotropy coefficient (horizontal / vertical saturated hydraulic conductivity) (-)
   real(8),                         save ::   cofintfl        = 0.d0 ! Coefficient for exponential interflow relation (T-1)
   real(8), dimension(madr),        save ::   diffl           = 0.d0 ! Difference in water level between drain and groundwater (L)
   real(8), dimension(madr),        save ::   drainl          = 0.d0 ! Water level inside the drain (L)
   real(8),                         save ::   expintfl        = 0.d0 ! Exponent for exponential interflow relation (-) 
   real(8),                         save ::   facdpthinf      = 0.d0 ! Factor to reduce depth of infiltration layer as fraction of max depth discharge layer (swdivdinf == 1) (-)
   real(8), dimension(madr),        save ::   ftopdislay      = 0.d0 ! Array with factor for function to determine depth of top of model discharge layer for each drain level, see also swtopdislay (swdislay == 2) (-)
   real(8), dimension(macp),        save ::   ksatcp          = 0.d0 ! Saturated hydraulic conductivity per compartment (L/T)
   real(8), dimension(madr),        save ::   Lspacing        = 0.d0 ! Array with spacing between drains for each drainage level (L)
   real(8), dimension(madr,macp),   save ::   qdra            = 0.d0 ! Array with lateral drainage flux (L/T) for each drainage level and compartment
   real(8), dimension(madr),        save ::   qdrain          = 0.d0 ! Total lateral drainage flux (L/T) for each drainage level
   real(8),                         save ::   qdrtot          = 0.d0 ! Total lateral drainage flux (L/T)
   real(8), dimension(madr),        save ::   zbotdr          = 0.d0 ! Array with depth of drain bottom for each drain level
   real(8), dimension(madr),        save ::   ztopdislay      = 0.d0 ! Array with depth of top of model discharge layer for each drain level, see also swtopdislay (swdislay == 1) (L)
   character(len=16),               save ::   drfil                  ! Name of drainage input file
   
!  Basic drainage
   integer,                         save ::   dramet          = 0    ! Switch for lateral drainage: 1 = table of flux - groundwater level; 2 = Hooghoudt or Ernst; 3 = drainage/infiltration resistance
   integer,                         save ::   nrlevs          = 1    ! Number of drainage levels
   ! dramet == 1
   real(8), dimension(50),          save ::   qdrtab          = 0.d0 ! Array with lateral drainage flux (L/T) as function of groundwater level (L)
   ! dramet == 2
   integer,                         save ::   ipos            = 0    ! Switch for position of drain (see *.DRA input file for overview)
   real(8),                         save ::   basegw          = 0.d0 ! Depth of impervious layer (L) for drainage according to Hooghoudt or Ernst
   real(8),                         save ::   entres          = 0.d0 ! Drain entry resistance (T)
   real(8),                         save ::   geofac          = 0.d0 ! Geometry factor (-) for analytical drainage formula of Ernst
   real(8),                         save ::   khbot           = 0.d0 ! Horizontal hydraulic conductivity of bottom layer (L/T)
   real(8),                         save ::   khtop           = 0.d0 ! Horizontal hydraulic conductivity of top layer (L/T)
   real(8),                         save ::   kvbot           = 0.d0 ! Vertical hydraulic conductivity of bottom layer (L/T)
   real(8),                         save ::   kvtop           = 0.d0 ! Vertical hydraulic conductivity of top layer (L/T)
   real(8),                         save ::   shape           = 0.d0 ! Shape factor: ratio between the mean and the maximum groundwater level elevation above the drainage base (-)
   real(8),                         save ::   wetper          = 0.d0 ! Wet perimeter of drain (L)
   real(8),                         save ::   zintf           = 0.d0 ! Depth (L) at which fine top layer ends and coarse sub layer starts
   ! dramet == 3
   integer, dimension(madr),        save ::   nowltab         = 0    ! Number of input dates in for prescribed drain water levels
   integer, dimension(madr),        save ::   swallo          = 0    ! Switch to allow all (1), only infiltration (2) or only drainage (3) for each drainage level
   real(8), dimension(madr),        save ::   drares          = 0.d0 ! Array with drainage resistance (T) for each drainage level
   real(8), dimension(madr),        save ::   infres          = 0.d0 ! Array with infiltration resistance (T) for each drainage level
   real(8), dimension(madr,2*maowl),save ::   owltab          = 0.d0 ! Table with prescribed drain water levels

!  Extended drainage (surface water)
   integer,                         save ::   swsrf           = 0    ! Switch for interaction with surface water system: 1 = no interaction, 2 = without separate primary system, 3 = with separate primary system
   integer,                         save ::   swqhr           = 0    ! Switch for type of discharge relationship: 1 = exponential, 2 = table
   integer,                         save ::   swsec           = 0    ! Switch for type of surface water level secondary system: 1 = input, 2 = simulated
   integer,                         save ::   nrpri           = 0    ! Number of primary system
   integer,                         save ::   nrsec           = 0    ! Number of secondary system
   integer,                         save ::   nmper           = 0    ! Number of management periods
   integer, dimension(mamp),        save ::   swman           = 0    ! Type of water management: 1 = fixed weir crest, 2 = automatic weir, for each management period
   integer, dimension(mamp),        save ::   nphase          = 0    !
   integer, dimension(mamp),        save ::   nodhd           = 0    !
   integer,                         save ::   numadj          = 0    ! Counter for number of adjustments
   integer, dimension(mamp),        save ::   intwl           = 0    ! Length of water level adjustment period (SWMAN = 2) (T)
   real(8), dimension(madr),        save ::   widthr          = 0.d0 ! Bottom width of channel (L)
   real(8), dimension(madr),        save ::   taludr          = 0.d0 ! Side slope (dh/dw) of channel (-)
   real(8), dimension(madr),        save ::   rdrain          = 0.d0 ! Drainage resistance (T)
   real(8),                         save ::   rsurfdeep       = 0.d0 ! Maximum resistance of rapid surface drainage (T), in case SWNRSRF == 1
   real(8),                         save ::   rsurfshallow    = 0.d0 ! Minimum resistance of rapid surface drainage (T), in case SWNRSRF == 1
   real(8), dimension(madr),        save ::   rinfi           = 0.d0 ! Infiltration resistance (T)
   real(8), dimension(madr),        save ::   rentry          = 0.d0 ! Entrance resistance (T)
   real(8), dimension(madr),        save ::   rexit           = 0.d0 ! Exit resistance (T)
   real(8), dimension(madr),        save ::   gwlinf          = 0.d0 ! Groundwater level for maximum infiltration (T)
   real(8), dimension(2*mawlp),     save ::   wlptab          = 0.d0 ! Water level of primary system (L)
   real(8), dimension(mamp),        save ::   impend          = 0.d0 ! Date that management period ends 
   real(8), dimension(mamp),        save ::   wldip           = 0.d0 ! Allowed dip of surface water level before starting supply (L)
   real(8), dimension(mamp),        save ::   wscap           = 0.d0 ! Surface water supply capacity (L/T)
   real(8), dimension(mamp),        save ::   hbweir          = 0.d0 ! Weir crest, or lowest position in case SWMAN == 2 (L)
   real(8),                         save ::   osswlm          = 0.d0 ! Criterium for warning about oscillation (L)
   real(8),                         save ::   wlstar          = 0.d0 ! Target level (L)
   real(8),                         save ::   wlp             = 0.d0 ! Water level in primary system (L)
   real(8), dimension(mamp),        save ::   alphaw          = 0.d0 ! Alpha coefficient of discharge formula (-)
   real(8), dimension(mamp),        save ::   betaw           = 0.d0 ! Beta coefficient of discharge formula (-)
   real(8), dimension(mamp*mamte),  save ::   dropr           = 0.d0 ! Drop rate
   real(8), dimension(mamp,mamte),  save ::   gwlcrit         = 0.d0 !
   real(8), dimension(mamp,mamte),  save ::   hcrit           = 0.d0 !
   real(8), dimension(mamp,mamte),  save ::   vcrit           = 0.d0 !
   real(8), dimension(mamp,mamte),  save ::   hqhtab          = 0.d0 !
   real(8), dimension(mamp,mamte),  save ::   qqhtab          = 0.d0 !
   real(8), dimension(mamp,mamte),  save ::   wlsman          = 0.d0 !
   real(8), dimension(2*mawls),     save ::   wlstab          = 0.d0 ! Table with water level (L) as function of time, given as input
   real(8), dimension(22,2),        save ::   sttab           = 0.d0 ! Table with relation between water storage (L) and water level (L)
   real(8),                         save ::   swst            = 0.d0 ! Storage in secondary system (L)
   real(8), dimension(4),           save ::   wlsbak          = 0.d0 ! Registration of water levels in secondary system of precious timesteps (L)
   real(8),                         save ::   wls             = 0.d0 ! Water level in secondary system (L)
   real(8),                         save ::   qdrd            = 0.d0 ! Drainage flux to or from secondary system (L)

   ! list of vars that are accessed from outside (fluxes, frozencond, functions, headcalc, intgeral, macropore, solute, output)
   ! Since all vars listed above are public (this MUST be so otherwise the underlying submodules cannot access them), the following two statements are not necessary
   ! public :: dramet, nrlevs, drfil, qdra, qdrtot, qdrain, swdivd, cofani, zbotdr, drares
   ! public :: sttab, hqhtab, qqhtab, imper, swst, wls, owltab, nowltab, swdtyp

contains

! ---------------------------------------------------------------------------
   
   subroutine drain(itask)
! ---------------------------------------------------------------------------
!     Purpose            : Divide drainage tasks between basic and extended
! ---------------------------------------------------------------------------
      use MOD_swap_base, only: swdra
      use variables,     only: fldecdt
      implicit none
      
      integer, intent(in) :: itask
! ---------------------------------------------------------------------------
      
      select case (swdra)
      case(1)         
         if (itask == 1) call read_drainage_basic()
         if (itask == 2) call drainage
      case(2)
         if (itask == 1) call read_drainage_extended()
         if (itask == 2 .OR. itask == 3) then
            if (.NOT.fldecdt) call surfacewater(itask)
         end if
      end select
   end subroutine drain

end module MOD_drain

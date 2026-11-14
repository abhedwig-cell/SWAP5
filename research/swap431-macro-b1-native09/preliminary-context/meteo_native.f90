module MOD_meteo

use atmosphere_interface,  only: tav, rad, grai
use MOD_swap_base,         only: swetr, swrain, swmetdetail

implicit none

! global variables
real(8), allocatable, save :: wet(:)               ! fraction of each day the crop is wet (-)
real(8), allocatable, save :: raintim(:)           ! start of rainfall (t1900) (t)

integer, save :: swdivide                          ! switch: 0 = division ET into E and T according to the traditional way; 1 = division ET into E and T according to PM-direct

real(8), save :: lat                               ! latitude of meteorological station (degrees)

real(8), save :: etr                               ! Reference evapotranspiration (cm d-1)

real(8), save :: tmn                               ! minimum air temperature of current day (oC)
real(8), save :: tmx                               ! maximum air temperature of current day (oC)
real(8), save :: tavd                              ! Average air temperature during day time (oC)
real(8), save :: hum                               ! Vapour pressure [kpa]
real(8), save :: win                               ! Average windspeed (24h or 7-19h) [m/s]

real(8), save :: cfevappond                        ! Parameter equal to the ratio ponding layer evaporation / ETref (-)
real(8), save :: fprecnosnow                       ! Ratio rain (excl. snow and rain on snow) / gross rain flux in case of detailed rainfall data (-)

integer, save :: swevap                            ! 0: force evaporation to zero; 1: use calculated evaporation (default) [optional]
real(8), save :: epond                             ! Ponding evaporation flux (L/T)
real(8), save :: peva                              ! Potential soil evaporation flux (L/T)
real(8), save :: empreva                           ! Reduced soil evaporation flux according to empirical functions (L/T)
real(8), save :: ptra                              ! Potential transpiration flux (L/T)
real(8), save :: ptra_dry                          ! Potential transpiration flux of dry canopy (L/T)
real(8), save :: ptra_wet                          ! Potential transpiration flux of wet canopy (L/T)
real(8), save :: eintc                             ! Interception flux of rain and irrigation (L/T)

real(8), save :: graidt                            ! Gross precipitation flux during iteration timesteps (L/T)
real(8), save :: aintcdt                           ! Interception flux of rain and irrigation during iteration timesteps (L/T)
real(8), save :: nraidt                            ! Net precipitation flux during iteration timesteps (L/T)

integer, save :: n_metdetail                       ! total number of detailed meteo records per day (-)
integer, save :: i_metdetail                       ! active record number of detailed meteo record for specific day; 1:n_metdetail (-)
real(8), save :: dt_meteo                          ! duration timestep detailed meteo input (-)
logical, save :: fl_update_meteo                   ! update of weather records

! local variables
character(len=200), save :: metfil, rainfil        ! name of meteorological input file and rain input file

real(8), allocatable, save :: arad(:)              ! radiation input data (M/T2)
real(8), allocatable, save :: atav(:)              ! air temperature input data (degree C)
real(8), allocatable, save :: atmn(:)              ! minimum air temperature input data (degree C)
real(8), allocatable, save :: atmx(:)              ! maximum air temperature input data (degree C)
real(8), allocatable, save :: ahum(:)              ! humidity input data (M/L/T2)  
real(8), allocatable, save :: awin(:)              ! wind speed input data (L/T)     
real(8), allocatable, save :: aetr(:)              ! ETref input data (L/T)
real(8), allocatable, save :: arai(:)              ! precipitation sum input data (cm/T)

real(8), allocatable, save :: rainflx(:)           ! flux rainfall (L/T)

integer, save :: swmetfilall                       ! switch indicating all meteo data is presence in single file
integer, save :: swrainfilall                      ! switch indicating all rain data is presence in single file
real(8), allocatable, save :: raintb(:)            ! mean rainfall intensity (L/T) as function of daynumber (T)

real(8), save :: etrmax,etrmin,hummax,hummin,radmax,radmin,raimax,raimin
real(8), save :: tmnmax,tmnmin,tmxmax,tmxmin,winmax,winmin

real(8), save :: es0                               ! Potential evaporation rate from a wet bare soil [mm d-1]
real(8), save :: et0                               ! Potential transpiration rate from a dry crop [mm d-1]
real(8), save :: ew0                               ! Potential transpiration rate from a wet crop [mm d-1]
real(8), save :: ep0                               ! Potential evaporation rate from ponding layer [mm d-1]

real(8), save :: wfrac                             ! Fraction of time that there is interception evaporation (wet canopy)
real(8), save :: aintc                             ! Amount of rainfall interception during current day (L) in cm

real(8), save :: long                              ! longitude of measurement site (degrees)
real(8), save :: long_tz                           ! longitude of the centre of the local timezone (degrees)
real(8), save :: alt                               ! altitude of meteorological station (m)
real(8), save :: altw                              ! height of wind speed measurement (m)
real(8), save :: alth                              ! height of temperature and humidity measurement (m)
real(8), save :: fwind                             ! factor for converting 24h averaged windspeed to daytime average windspeed (7-19h) (-)
real(8), save :: angstroma                         ! first  angstrom coefficient (-)
real(8), save :: angstromb                         ! second angstrom coefficient (-)

integer, save :: meteo_rec                         ! meteo record
integer, save :: rain_rec                          ! rainfall record

logical, save :: fl_loadmeteodata                  ! should all meteo data be loaded (SWETR = 0 or CROPTYPE /= 1)

! special: when meteo data are provided from an external source (typically when SWAP is used in mult-SWAP mode
type external_meteo
   real(8) :: rain  = 0.0d0
   real(8) :: rad   = 0.0d0
   real(8) :: tmin  = 0.0d0
   real(8) :: tmax  = 0.0d0
   real(8) :: hum   = 0.0d0
   real(8) :: wind  = 0.0d0
   real(8) :: etref = 0.0d0
   real(8) :: wet   = 0.0d0
end type external_meteo
type (external_meteo), save :: ext_meteo
integer, save :: sw_meteo = 0                      ! switch used during multi-SWAP; contains copy of mult-SWAP variable sw_meteo_type

! everything is private
private

! except for the following function/subroutine
public :: eintc
public :: meteo
public :: interception_daily, penmon, astro, reduceva

! except for the following variables
public :: fl_update_meteo
public :: swdivide, cfevappond, fprecnosnow
public :: alt, lat, altw, alth, angstroma, angstromb
public :: n_metdetail, i_metdetail, dt_meteo
public :: meteo_rec, rain_rec, raintim
public :: etr, tmn, tmx, tavd, hum, win, grai, wet, fwind
public :: swevap, epond, peva, empreva, ptra_dry, ptra, graidt, aintcdt, nraidt, ptra_wet, aintc, wfrac

! for multi-SWAP
public :: arad, atmn, atmx, ahum, awin, aetr, arai, ext_meteo, sw_meteo

contains
    
! ------------------------------------------------------------------------
    
   subroutine meteo(task)
   
      ! ------------------------------------------------------------------
      
      implicit none
      integer, intent(in) :: task
   
      ! ------------------------------------------------------------------

      select case (task)
      
      case (1)

         nraidt = 0.0d0

         ! load all weather values for simulation period
         call ReadMeteo()
      
      case (2)
         
         ! determine daily weather values
         call ProcessMeteoDay() 
          
      case (3)
          
          ! determine timestep weather values
          call ProcessMeteoDT()
          
      case default
         
          call swap_error ('meteo', 'Illegal value for TASK')
      
      end select
   
   end subroutine meteo
   
   ! ---------------------------------------------------------------------
   
   subroutine ReadMeteo

      ! ------------------------------------------------------------------
     
      use MOD_arrays,          only: macrop, fillen
      use MOD_swap_base,       only: unit_swp, swpfilnam, swcalt, unit_err, swsnow, swfrost, sw_multi_swap, swcrop
      use variables,           only: tstart, tend 

      implicit none

      ! local variables
      character(len=800) :: message
      integer :: i, ifnd
      real(8) :: cropend(macrop), cropstart(macrop)
      integer :: croptype(macrop)
      character(len=fillen) :: cropfil(macrop)
      logical :: rdinqr
      
      real(8), allocatable :: rtim(:), rflx(:)
     
      ! ------------------------------------------------------------------

      ! read settings from main input
      call rdinit(unit_swp, unit_err, swpfilnam)
     
      ! filename meteo data
      call rdscha ('metfil',metfil)
     
      ! if METFIL is provided with extension .MET, all meteo data presence in single file
      call lowerc (metfil)
      swmetfilall = 0
      if (index(trim(metfil),".met") > 0) swmetfilall = 1
     
      ! latitude
      if (sw_multi_swap == 0) call rdsdor ('lat',-90.0d0,90.0d0,lat)
     
      ! type of weather data
      call rdsinr ('swetr',0,1,swetr)
     
      fl_loadmeteodata = .FALSE.
      if (swetr == 0) then

         ! basic meteorological data (Penman Monteith)

         fl_loadmeteodata = .TRUE.

         if (sw_multi_swap == 0) call rdsdor ('alt',-400.d0,3000.d0,alt)
         
         altw = 10.d0
         if (rdinqr('altw')) call rdsdor ('altw',0.1d0,99.d0,altw)
         alth = 1.5d0
         if (rdinqr('alth')) call rdsdor ('alth',0.1d0,99.d0,alth)
       
         angstroma = 0.25d0
         if (rdinqr('angstroma')) call rdsdor ('angstroma',0.d0,1.d0,angstroma)
         angstromb = 0.5d0
         if (rdinqr('angstromb')) call rdsdor ('angstromb',0.d0,1.d0,angstromb)
        
         swdivide = 0
         if (rdinqr('swdivide')) call rdsinr ('swdivide',0,1,swdivide)
     
      else

         ! etref data (only daily) 

         swmetdetail = 0
         if (rdinqr('swmetdetail')) then
            call rdsinr ('swmetdetail',0,1,swmetdetail)
            if (swmetdetail == 1) call swap_error ('readmeteo', 'SWMETDETAIL = 1 only available in case of SWETR = 0')
         end if  
       
         swdivide = 0
         if (rdinqr('swdivide')) then
            call rdsinr ('swdivide',0,1,swdivide)
            if (swdivide == 1) call swap_error ('readmeteo', 'SWDIVIDE = 1 only available in case of SWETR = 0')
         end if  
       
      end if 

      ! switch crop simulation
      if (swcrop == 1 .AND. .NOT. fl_loadmeteodata) then
       
         ! crop calendar
         if (sw_multi_swap == 0 .or. sw_meteo == 2) then
            call rdatim ('cropstart',cropstart,macrop,ifnd)
            call rdftim ('cropend',cropend,macrop,ifnd)
            call rdfcha ('cropfil',cropfil,macrop,ifnd)
            call rdfinr ('croptype',1,2,croptype,macrop,ifnd)
            
            ! check combination detailed crop with LAT > 66.5
            do i = 1,ifnd
               if (croptype(i) /= 1 .AND. abs(lat) > 66.5d0) then
                  message = 'Fatal combination for crop '//trim(cropfil(i))//'; detailed crop module within polar circle (LAT>66.5)!'
                  call swap_error ('ReadMeteo', message)
               end if
            end do

         end if
         
         ! check if meteo data should be loaded (dynamic crop growth)
         i = 1
         do while (tend - cropstart(i) > 0.d0)
            if (cropstart(i) < 1.d0) exit
            if (tend + 0.1d0 > cropstart(i) .AND. tstart - 0.1d0 < cropend(i)) then
               if (croptype(i) == 2) fl_loadmeteodata = .TRUE.
            end if
            i = i + 1
         end do
      end if  
     
      ! daily meteo
      if (swmetdetail == 0) then
       
         n_metdetail = 1  
        
         fwind = 1.d0
         if (rdinqr('fwind')) call rdsdor ('fwind',0.5d0,5.d0,fwind)

         call rdsinr ('swrain',0,3,swrain)

      ! detailed meteo
      else  
     
         ! longitude of measurement site and centre of the local timezone
         call rdsdor ('long',-180.d0,180.d0,long)
         call rdsdor ('long_tz',-180.d0,180.d0,long_tz)

         if (swsnow == 1) call swap_error ('readmeteo', 'SWSNOW = 1 only available in case of SWMETDETAIL = 0')
        
         call rdsinr ('nmetdetail',24,96,n_metdetail)
         dt_meteo = 1.d0 / dble(n_metdetail)

         fwind = 1.d0
        
         swrain = 0
         if (rdinqr('swrain')) then
            call rdsinr ('swrain',0,3,swrain)
            if (swrain /= 0) call swap_error ('readmeteo', 'SWRAIN = 1, 2 or 3 only available in case of SWMETDETAIL = 0')
         end if  
       
      end if
     
      ! data for actual rainfall intensity
      if (swrain == 1) then
        
         ! old procedure (deprecated)
         if (rdinqr('time')) then
           
            message = 'Usage of TIME and RAINFLUX are deprecated, use RAINTB instead'
            call swap_warning('readmeteo', message)
          
            call rdinne ('time',ifnd)
            allocate(rtim(ifnd)); allocate(rflx(ifnd))
            if (allocated(raintb)) deallocate(raintb); allocate(raintb(ifnd*2)); raintb = 0.d0

            call rdfdor ('time',0.d0,366.d0,rtim,ifnd,ifnd)
            call rdfdor ('rainflux',0.d0,1000.d0,rflx,ifnd,ifnd)
       
            do i = 1, ifnd
               raintb(i*2) = rflx(i)
               raintb(i*2-1) = rtim(i)
            end do
           
            deallocate(rtim, rflx)
        
         ! new procedure
         else
            
            if (.NOT. rdinqr('raintb')) call swap_error ('readmeteo', 'Variable RAINTB not present in file '//trim(swpfilnam))
            call rdinne ('raintb',ifnd)
            if (allocated(raintb)) deallocate(raintb); allocate(raintb(ifnd)); raintb = 0.d0
            call rdadortb('raintb', 0.d0, 366.d0, 0.d0, 1.d3, raintb, ifnd, .FALSE.)
         
         end if
      end if
     
      swrainfilall = 0
      if (swrain == 3) then
        
         ! filename rain data
         call rdscha ('rainfil',rainfil)
       
         ! if RAINFIL is provided with extension .RAIN, all rain data presence in single file
         call lowerc (rainfil)
         if (index(trim(rainfil),".rain") > 0) then
            swrainfilall = 1
         end if
      end if      
     
      close(unit_swp)
         
      ! --- detection and handling of missing values ---

      ! default ranges of parameter values
      radmin = -1.d5; radmax = 5.d6
      tmnmin = -1.d5; tmnmax = 1.d5
      tmxmin = -1.d5; tmxmax = 1.d5
      hummin = -1.d5; hummax = 1.d5
      winmin = -1.d5; winmax = 1.d5
      raimin =  0.d0; raimax = 1.d3
      etrmin = -1.d5; etrmax = 1.d5

      ! no missing values allowed if penmon must be executed
      if (swetr == 0) then
         radmin =   0.d0
         tmnmin = -50.d0; tmnmax = 35.d0
         tmxmin = -50.d0; tmxmax = 60.d0
         hummin =   0.d0; hummax = 10.d0
         winmin =   0.d0; winmax = 150.d0
      end if

      ! error in case etref missing
      if (swetr == 1) then
         etrmin = -0.00001d0; etrmax = 100.d0
      end if  
     
      ! no missing values for tmn and tmx allowed if
      ! crop development, numerical soil temperatures, snow or frost must be simulated
      if (fl_loadmeteodata .OR. swcalt == 2 .OR. swsnow == 1 .OR. swfrost == 1) then
         tmnmin = -60.d0; tmnmax = 50.d0
         tmxmin = -50.d0; tmxmax = 60.d0
      end if
     
      ! no missing value for rad allowed if detailed crop growth
      if (fl_loadmeteodata) then
         radmin = 0.d0;   radmax = 5.d6
      end if

      ! load all meteo data
      if (sw_multi_swap == 0 .or. sw_meteo == 2) then
         if (swmetdetail == 0) call LoadMeteoData ()
         if (swmetdetail == 1) call LoadDetailMeteoData ()

      ! load all rain data
         if (swrain == 3) call LoadRainData ()
      end if

      return
     
   end subroutine ReadMeteo

   ! ---------------------------------------------------------------------
   
   subroutine LoadMeteoData ()
   
      ! ------------------------------------------------------------------
       
      ! global variables
      use MOD_swap_base, only: iun_min2, iun_max2, pathatm, unit_err
      use variables,     only: tstart, tend

      implicit none

      ! local variables
      integer, allocatable :: all_dd(:), all_mm(:), all_yyyy(:)
      real(8), allocatable :: all_rad(:), all_tmin(:), all_tmax(:), all_hum(:), all_wind(:), all_rain(:), all_etref(:), all_wet(:)
        
      integer              :: unit, getun2, i1, i2, i
      character(len=3)     :: ext
      character(len=80)    :: metf

      integer              :: datea(6)
      integer              :: yr, s_yr, e_yr
      integer              :: rec, s_rec, e_rec, n_rec
      real(4)              :: fsec
        
      real(8)              :: wstart, wend
      real(8)              :: tmeteo, tmeteo_old
      real(8)              :: rtim, rflx, doy
      logical              :: file_exists
      character(len=11)    :: datedum
      character(len=800)   :: message

      ! local variables (ttutil)
      real(8)              :: afgen
      logical              :: rdinqr
      logical              :: dtleap

      ! local parameters
      integer, parameter   :: firstdayofmonth365(12) = [1, 32, 60, 91, 121, 152, 182, 213, 244, 274, 305, 335]
      integer, parameter   :: firstdayofmonth366(12) = [1, 32, 61, 92, 122, 153, 183, 214, 245, 275, 306, 336]
      real(8), parameter   :: vsmall = 1.0d-8
        
      ! ------------------------------------------------------------------
   
      ! determine total number of records to allocate
      if (swmetfilall == 0) then
   
         ! determine start and end of simulation
         call dtdpar (tstart+0.1d0, datea, fsec)
         s_yr = datea(1)
  
         call dtdpar (tend+0.1d0, datea, fsec)
         e_yr = datea(1)
  
         ! determine total number of records to allocate
         n_rec = 0
         do yr = s_yr,e_yr,1
   
            ! open connection
            write (ext,'(i3.3)') mod(yr,1000)
            metf = trim(pathatm)//trim(metfil)//'.'//trim(ext)
            inquire(file = metf, exist = file_exists)
            if (.NOT. file_exists) then
               message ='File '//trim(metf)//' does not exists!'
               call swap_error ('loadmeteodata', message)
            end if
            unit = getun2 (iun_min2, iun_max2, 2)
            call rdinit (unit,unit_err,metf)
   
            ! determine number of records in single file
            if (.NOT. rdinqr('yyyy')) call swap_error ('loadmeteodata', 'Variable YYYY not present in file '//trim(metfil)//'.'//trim(ext))
            call rdinne ('yyyy',rec)
            n_rec = n_rec + rec

            close(unit)
         end do
   
      else
   
         ! open connection
         unit = getun2 (iun_min2, iun_max2, 2)
         metf =  trim(pathatm) // trim(metfil)
         inquire(file = metf, exist = file_exists)
         if (.NOT. file_exists) then
            message ='File '//trim(metf)//' does not exists!'
            call swap_error ('loadmeteodata', message)
         end if
         call rdinit (unit,unit_err,metf)
   
         ! determine number of records
         if (.NOT. rdinqr('yyyy')) call swap_error ('loadmeteodata', 'Variable YYYY not present in file '//trim(metfil))
         call rdinne ('yyyy',n_rec)
   
      end if     
  
      ! allocate variables
      allocate (all_dd(n_rec))
      allocate (all_mm(n_rec))
      allocate (all_yyyy(n_rec))
      allocate (all_tmin(n_rec))
      allocate (all_tmax(n_rec))
      if (fl_loadmeteodata) then
         allocate (all_rad(n_rec))
         allocate (all_hum(n_rec))
         allocate (all_wind(n_rec))
      end if
      if (swetr == 1) then
         allocate (all_etref(n_rec))
      end if
      if (swrain /= 3) allocate (all_rain(n_rec))
      if (swrain == 2) allocate (all_wet(n_rec))
      
      ! load variables
      if (swmetfilall == 0) then
   
         n_rec = 0
         do yr = s_yr,e_yr
   
            ! open connection
            unit = getun2 (iun_min2, iun_max2, 2)
            write (ext,'(i3.3)') mod(yr,1000)
            metf = trim(pathatm)//trim(metfil)//'.'//trim(ext)
            call rdinit (unit,unit_err,metf)
   
            ! determine number of records in single file
            call rdinne ('yyyy',rec)
   
            ! set array to fill
            i1 = n_rec + 1
            i2 = n_rec + rec
   
            ! load variables
            call rdfinr ('dd',1,31,all_dd(i1:i2),rec,rec)
            call rdfinr ('mm',1,12,all_mm(i1:i2),rec,rec)
            call rdfint ('yyyy',all_yyyy(i1:i2),rec,rec)
            call rdfdor ('tmin',tmnmin,tmnmax,all_tmin(i1:i2),rec,rec)
            call rdfdor ('tmax',tmxmin,tmxmax,all_tmax(i1:i2),rec,rec)
            if (fl_loadmeteodata) then
               call rdfdor ('rad',radmin,radmax,all_rad(i1:i2),rec,rec)
               call rdfdor ('hum',hummin,hummax,all_hum(i1:i2),rec,rec)
               call rdfdor ('wind',winmin,winmax,all_wind(i1:i2),rec,rec)
            end if
            if (swetr == 1) then
               call rdfdor ('etref',etrmin,etrmax,all_etref(i1:i2),rec,rec)
            end if   
            if (swrain /= 3) call rdfdor ('rain',raimin,raimax,all_rain(i1:i2),rec,rec)
            if (swrain == 2) call rdfdor ('wet',0.d0,1.d0,all_wet(i1:i2),rec,rec)
   
            n_rec = n_rec + rec

            close(unit)
    
         end do
   
      else
   
         call rdfinr ('dd',1,31,all_dd,n_rec,n_rec)
         call rdfinr ('mm',1,12,all_mm,n_rec,n_rec)
         call rdfint ('yyyy',all_yyyy,n_rec,n_rec)
         call rdfdor ('tmin',tmnmin,tmnmax,all_tmin,n_rec,n_rec)
         call rdfdor ('tmax',tmxmin,tmxmax,all_tmax,n_rec,n_rec)
         if (fl_loadmeteodata) then
            call rdfdor ('rad',radmin,radmax,all_rad,n_rec,n_rec)
            call rdfdor ('hum',hummin,hummax,all_hum,n_rec,n_rec)
            call rdfdor ('wind',winmin,winmax,all_wind,n_rec,n_rec)
         end if
         if (swetr == 1) then
            call rdfdor ('etref',etrmin,etrmax,all_etref,n_rec,n_rec)
         end if   
         if (swrain /= 3) call rdfdor ('rain',raimin,raimax,all_rain,n_rec,n_rec)
         if (swrain == 2) call rdfdor ('wet',0.d0,1.d0,all_wet,n_rec,n_rec)
  
         close (unit)
   
      end if
  
      ! check if start and end time are present in meteofile
      datea = 0
      datea(1) = all_yyyy(1); datea(2) = all_mm(1); datea(3) = all_dd(1)
      call DTARDP (datea, 0.0, wstart)
      datea(1) = all_yyyy(n_rec); datea(2) = all_mm(n_rec); datea(3) = all_dd(n_rec)
      call DTARDP (datea, 0.0, wend)
      if (wstart > tstart .OR. wend < tend) call swap_error ('loadmeteodata', 'incomplete meteofile')
  
      ! check whether dates are in ascending order and if all dates are available
      datea = 0; datea(1) = all_yyyy(1); datea(2) = all_mm(1); datea(3) = all_dd(1)
      call dtardp (datea,0.0,tmeteo)
      do i = 2, n_rec
         tmeteo_old = tmeteo 
         datea(1) = all_yyyy(i); datea(2) = all_mm(i); datea(3) = all_dd(i)
         call dtardp (datea,0.0,tmeteo)
         if (tmeteo - tmeteo_old - 1.d0 > 0.1d0) then
           call dtdpst ('year-month-day',tmeteo_old,datedum)           
           message ='The date after '//datedum//' is not correct! Adapt meteo file!'
           call swap_error ('loadmeteodata', message)
         end if
      end do
       
      ! store records
      n_rec = nint(tend - tstart) + 1
      s_rec = nint(tstart - wstart) + 1
      e_rec = nint(tend - wstart) + 1
   
      ! check if RAIN and WET correspond (SWRAIN = 2)
      if (swrain == 2) then
         do i = s_rec, e_rec
            if ((all_rain(i) > 1.d-10 .AND. all_wet(i) < 1.d-10) .OR. (all_rain(i) < 1.d-10 .AND. all_wet(i) > 1.d-10)) then
               datea = 0; datea(1) = all_yyyy(i); datea(2) = all_mm(i); datea(3) = all_dd(i)
               call dtardp (datea,0.0,tmeteo)
               call dtdpst ('year-month-day',tmeteo,datedum)           
               message = ' In METFIL at '//datedum//' RAIN and WET do not correspond (SWRAIN = 2)! Adapt meteo data!'
               call swap_error ('loadmeteodata', message)
            end if  
         end do
      end if
       
      ! store meteo records within simulation period
   
      if (allocated(atmn)) deallocate(atmn); allocate(atmn(n_rec)); atmn = all_tmin(s_rec:e_rec)
      if (allocated(atmx)) deallocate(atmx);allocate(atmx(n_rec)); atmx = all_tmax(s_rec:e_rec)
      if (fl_loadmeteodata) then
         if (allocated(arad)) deallocate(arad);allocate(arad(n_rec)); arad = all_rad(s_rec:e_rec)
         if (allocated(ahum)) deallocate(ahum);allocate(ahum(n_rec)); ahum = all_hum(s_rec:e_rec)
         if (allocated(awin)) deallocate(awin);allocate(awin(n_rec)); awin = all_wind(s_rec:e_rec)
      end if
      if (swetr == 1) then
         if (allocated(aetr)) deallocate(aetr);allocate(aetr(n_rec)); aetr = all_etref(s_rec:e_rec)
      end if   
      if (swrain /= 3) then 
         if (allocated(arai)) deallocate(arai);allocate(arai(n_rec)); arai = all_rain(s_rec:e_rec)
      end if
      if (swrain == 2) then
         if (allocated(wet)) deallocate(wet);allocate(wet(n_rec)); wet = all_wet(s_rec:e_rec)
      end if   
       
      meteo_rec = 0
  
      ! convert radiation from kJ/m2/d to J/m2/d
      if (fl_loadmeteodata) arad = 1000.d0 * arad

      ! convert precipitation from mm to cm
      if (swrain /= 3) arai = arai * 0.1d0
   
      ! store raintime and rainflux (SWRAIN = 1 or SWRAIN = 2)
      if (swrain == 1 .OR. swrain == 2) then
   
         ! allocate raintime and rainflux
         if (allocated(raintim)) deallocate(raintim);allocate(raintim(n_rec*2 + 1)); raintim = 0.d0
         if (allocated(rainflx)) deallocate(rainflx);allocate(rainflx(n_rec*2 + 1)); rainflx = 0.d0
   
         ! loop over simulation period
         rain_rec = 0
         do i = s_rec, e_rec

            if (all_rain(i) > vsmall) then

               tmeteo = wstart + i - 1.d0
       
               ! closure of previous rain event
               if (rain_rec /= 0) then
                  if (tmeteo - raintim(rain_rec) > vsmall) then
                     rain_rec = rain_rec + 1
                     raintim(rain_rec) = tmeteo
                     rainflx(rain_rec) = 0.d0
                  end if
               else
                  rain_rec = rain_rec + 1
                  raintim(rain_rec) = tmeteo
                  rainflx(rain_rec) = 0.d0
               end if
       
               rain_rec = rain_rec + 1
       
               ! set rainflux at start of day
               if (swrain == 1) then  
          
                  ! mean rainfall intensities
                  if (dtleap(all_yyyy(i))) then 
                     doy = dble(firstdayofmonth366(all_mm(i)) + all_dd(i) - 1)
                  else
                     doy = dble(firstdayofmonth365(all_mm(i)) + all_dd(i) - 1)
                  end if
                  rflx = afgen(raintb, size(raintb), doy)
                  rtim = dmin1(1.d0, all_rain(i) * 0.1d0 / rflx)

               else if (swrain == 2) then

                  ! rainfall durations are specified
                  rtim = all_wet(i)
               end if
       
               ! start of rain event
               raintim(rain_rec) = tmeteo + rtim
               rainflx(rain_rec) = all_rain(i) * 0.1d0 / rtim
       
            end if
         end do
   
         ! closure of previous rain event
         raintim(rain_rec + 1) = tend + 2.d0
         rainflx(rain_rec + 1) = 0.d0
   
         rain_rec = 1
   
      end if      

      ! deallocate temporary data
      deallocate(all_yyyy, all_mm, all_dd, all_tmin, all_tmax)
      if (fl_loadmeteodata) then
          deallocate(all_rad, all_hum, all_wind)
      end if
      if (swetr == 1) then
          deallocate(all_etref)
      end if
      if (swrain /= 3) deallocate(all_rain)
      if (swrain == 2) deallocate(all_wet)
   
      ! data read and stored properly
      write (unit_err,'(A)') ' METFIL: all meteo data read and stored.'

      return

   end subroutine LoadMeteoData

   ! ---------------------------------------------------------------------
   
   subroutine LoadDetailMeteoData ()

      ! ------------------------------------------------------------------
        
      ! global variables
      use MOD_swap_base, only: iun_min2, iun_max2, pathatm, unit_err
      use variables,     only: tstart, tend

      implicit none

      ! local variables
      real(8), allocatable :: all_rad(:), all_tav(:), all_hum(:), all_wind(:), all_rain(:)
      real(8), allocatable :: all_time(:)
      integer, allocatable :: all_record(:)
   
      integer              :: unit, getun2, i1, i2, i, j
      character(len=3)     :: ext
      character(len=80)    :: metf

      integer              :: datea(6)
      integer              :: yr, s_yr, e_yr
      integer              :: rec, s_rec, e_rec, n_rec, i_rec
      real(4)              :: fsec
   
      real(8)              :: tmeteo, tmeteo_old
      character(len=11)    :: datedum
      logical              :: file_exists
      character(len=800)   :: message

      ! local variables (ttutil)
      logical              :: rdinqr

      ! local parameters
      real(8), parameter   :: vsmall = 1.0d-8

      ! ------------------------------------------------------------------
    
      ! determine total number of records to allocate
      if (swmetfilall == 0) then
   
         ! determine start and end of simulation
         call dtdpar (tstart+0.1d0, datea, fsec)
         s_yr = datea(1)
  
         call dtdpar (tend+0.1d0, datea, fsec)
         e_yr = datea(1)
  
         ! determine total number of records to allocate
         n_rec = 0
         do yr = s_yr,e_yr,1
   
            ! open connection
            write (ext,'(i3.3)') mod(yr,1000)
            metf = trim(pathatm)//trim(metfil)//'.'//trim(ext)
            inquire(file = metf, exist = file_exists)
            if (.NOT. file_exists) then
               message ='File '//trim(metf)//' does not exists!'
               call swap_error ('loaddetailedmeteodata', message)
            end if
            unit = getun2 (iun_min2, iun_max2, 2)
            call rdinit (unit,unit_err,metf)
   
            ! determine number of records in single file
            if (.NOT. rdinqr('date')) call swap_error ('loaddetailedmeteodata', 'Variable DATE not present in file '//trim(metfil)//'.'//trim(ext))
            call rdinne ('date',rec)
            n_rec = n_rec + rec

            close(unit)
         end do
   
      else
   
         ! open connection
         metf =  trim(pathatm) // trim(metfil)
         inquire(file = metf, exist = file_exists)
         if (.NOT. file_exists) then
            message ='File '//trim(metf)//' does not exists!'
            call swap_error ('loaddetailedmeteodata', message)
         end if
         unit = getun2 (iun_min2, iun_max2, 2)
         call rdinit (unit,unit_err,metf)
   
         ! determine number of records
         if (.NOT. rdinqr('date')) call swap_error ('loaddetailedmeteodata', 'Variable DATE not present in file '//trim(metfil))
         call rdinne ('date',n_rec)
   
      end if     
  
      ! allocate variables
      allocate (all_time(n_rec))
      allocate (all_record(n_rec))
      allocate (all_rad(n_rec))
      allocate (all_tav(n_rec))
      allocate (all_hum(n_rec))
      allocate (all_wind(n_rec))
      allocate (all_rain(n_rec))
 
      ! load variables
      if (swmetfilall == 0) then
   
         n_rec = 0
         do yr = s_yr,e_yr
   
            ! open connection
            unit = getun2 (iun_min2, iun_max2, 2)
            write (ext,'(i3.3)') mod(yr,1000)
            metf = trim(pathatm)//trim(metfil)//'.'//trim(ext)
            call rdinit (unit,unit_err,metf)
   
            ! determine number of records in single file
            call rdinne ('date',rec)
   
            ! set array to fill
            i1 = n_rec + 1
            i2 = n_rec + rec
   
            ! load variables
            call rdftim ('date',all_time(i1:i2),rec,rec)
            call rdfinr ('record',1,n_metdetail,all_record(i1:i2),rec,rec)
            call rdfdor ('rad',radmin,radmax,all_rad(i1:i2),rec,rec)
            call rdfdor ('temp',tmxmin,tmxmax,all_tav(i1:i2),rec,rec)
            call rdfdor ('hum',hummin,hummax,all_hum(i1:i2),rec,rec)
            call rdfdor ('wind',winmin,winmax,all_wind(i1:i2),rec,rec)
            call rdfdor ('rain',raimin,raimax,all_rain(i1:i2),rec,rec)

            n_rec = n_rec + rec

            close(unit)
    
         end do
   
      else
       
         call rdftim ('date',all_time,n_rec,n_rec)
         call rdfinr ('record',1,n_metdetail,all_record,n_rec,n_rec)
         call rdfdor ('rad',radmin,radmax,all_rad,n_rec,n_rec)
         call rdfdor ('temp',tmnmin,tmxmax,all_tav,n_rec,n_rec)
         call rdfdor ('hum',hummin,hummax,all_hum,n_rec,n_rec)
         call rdfdor ('wind',winmin,winmax,all_wind,n_rec,n_rec)
         call rdfdor ('rain',raimin,raimax,all_rain,n_rec,n_rec)
  
         close (unit)
   
      end if
  
      ! check if start and end time are present in meteofile
      if (all_time(1) > tstart .OR. all_time(n_rec) < tend) call swap_error ('loaddetailmeteodata', 'incomplete meteofile')
  
      ! check whether dates are in ascending order and if all dates are available
      i_rec = 1
      tmeteo = all_time(i_rec)
      do i = 1, (n_rec / n_metdetail)
         tmeteo_old = tmeteo
         do j = 1,n_metdetail
            tmeteo = all_time(i_rec)
            if (dabs(tmeteo - tmeteo_old) > vsmall .OR. j /= all_record(i_rec)) then
              call dtdpst ('year-month-day',tmeteo_old,datedum)           
              message ='Record numbers at date '//datedum//' are not correct! Adapt meteo file!'
              call swap_error ('loaddetailmeteodata', message)
            end if
            i_rec = i_rec + 1
         end do    
         if (i_rec < n_rec) then
            tmeteo = all_time(i_rec)
            if (tmeteo - tmeteo_old - 1.d0 > 0.1d0 .OR. all_record(i_rec) /= 1) then
              call dtdpst ('year-month-day',tmeteo_old,datedum)           
              message ='The date after '//datedum//' is not correct! Adapt meteo file!'
              call swap_error ('loaddetailmeteodata', message)
            end if
         end if
      end do
   
      ! store records
      n_rec = (nint(tend - tstart) + 1) * n_metdetail
      s_rec = (nint(tstart - all_time(1))) * n_metdetail + 1
      e_rec = (nint(tend - all_time(1) + 1)) * n_metdetail
   
      ! store meteo records within simulation period
      if (allocated(arad)) deallocate(arad); allocate(arad(n_rec)); arad = all_rad(s_rec:e_rec)
      if (allocated(atav)) deallocate(atav); allocate(atav(n_rec)); atav = all_tav(s_rec:e_rec)
      if (allocated(ahum)) deallocate(ahum); allocate(ahum(n_rec)); ahum = all_hum(s_rec:e_rec)
      if (allocated(awin)) deallocate(awin);allocate(awin(n_rec)); awin = all_wind(s_rec:e_rec)
      if (allocated(arai)) deallocate(arai);allocate(arai(n_rec)); arai = all_rain(s_rec:e_rec)
   
      meteo_rec = 0
      i_metdetail = 1
  
      ! convert radiation from kj/m2/d to j/m2/d
      arad = 1000.d0 * arad
   
      ! convert precipitation from mm to cm
      arai = arai * 0.1d0

      ! deallocate temporary data
      deallocate(all_rad, all_tav, all_hum, all_wind, all_rain)
      deallocate(all_time)
      deallocate(all_record)
   
      ! data read and stored properly
      write (unit_err,'(A)') ' METFIL: all meteo data read and stored.'

      return

   end subroutine LoadDetailMeteoData      

   ! ---------------------------------------------------------------------
   
   subroutine LoadRainData ()

      ! ------------------------------------------------------------------
       
      ! global variables   
      use MOD_swap_base, only: iun_min2, iun_max2, pathatm, unit_log, unit_err
      use variables,     only: tstart, tend

      implicit none

      ! local variables
      integer :: n_rec, rec

      integer, allocatable :: all_dd(:), all_mm(:), all_yyyy(:)
      real(8), allocatable :: all_raintime(:), all_rainamount(:)
   
      integer              :: unit, getun2, i1, i2, i
      character(len=3)     :: ext
      character(len=80)    :: rainf
   
      integer              :: datea(6)
      integer              :: yr, s_yr, e_yr
      real(4)              :: fsec

      real(8)              :: tmeteo
      real(8)              :: rtim

      character(len=19)    :: datedum
      character(len=800)   :: message
      logical              :: file_exists
   
      ! local variables (ttutil)
      logical              :: rdinqr
   
      ! local parameters
      real(8), parameter   :: vsmall = 1.0d-8

      ! ------------------------------------------------------------------
       
      ! determine total number of records to allocate
      if (swrainfilall == 0) then
   
         ! determine start and end of simulation
         call dtdpar (tstart+0.1d0, datea, fsec)
         s_yr = datea(1)
  
         call dtdpar (tend+0.1d0, datea, fsec)
         e_yr = datea(1)
  
         ! determine total number of records to allocate
         n_rec = 0
         do yr = s_yr,e_yr,1
   
            ! open connection
            write (ext,'(i3.3)') mod(yr,1000)
            rainf = trim(pathatm)//trim(rainfil)//'.'//trim(ext)
            inquire(file = rainf, exist = file_exists)
            if (.NOT. file_exists) then
               message ='File '//trim(rainf)//' does not exists!'
               call swap_error ('loadraindata', message)
            end if
            unit = getun2 (iun_min2, iun_max2, 2)
            call rdinit (unit,unit_err,rainf)
   
            ! determine number of records in single file
            if (.NOT. rdinqr('year')) call swap_error ('loadraindata', 'Variable YEAR not present in file '//trim(rainfil)//'.'//trim(ext))
            call rdinne ('year',rec)
            n_rec = n_rec + rec

            close(unit)
         end do
   
      else
   
         ! open connection
         rainf =  trim(pathatm) // trim(rainfil)
         inquire(file = rainf, exist = file_exists)
         if (.NOT. file_exists) then
            message ='File '//trim(rainf)//' does not exists!'
            call swap_error ('loadraindata', message)
         end if
         unit = getun2 (iun_min2, iun_max2, 2)
         call rdinit (unit,unit_err,rainf)
   
         ! determine number of records
         if (.NOT. rdinqr('year')) call swap_error ('loadraindata', 'Variable YEAR not present in file '//trim(rainfil))
         call rdinne ('year',n_rec)
   
      end if     
  
      ! allocate variables
      allocate (all_dd(n_rec + 1))
      allocate (all_mm(n_rec + 1))
      allocate (all_yyyy(n_rec + 1))
      allocate (all_raintime(n_rec + 1))
      allocate (all_rainamount(n_rec + 1))
 
      ! load variables
      if (swrainfilall == 0) then
   
         n_rec = 0
         do yr = s_yr,e_yr
   
            ! open connection
            unit = getun2 (iun_min2, iun_max2, 2)
            write (ext,'(i3.3)') mod(yr,1000)
            rainf = trim(pathatm)//trim(rainfil)//'.'//trim(ext)
            call rdinit (unit,unit_err,rainf)
   
            ! determine number of records in single file
            if (.NOT. rdinqr('day')) call swap_error ('loadraindata', 'Variable DAY not present in file '//trim(rainfil)//'.'//trim(ext))
            call rdinne ('day',rec)
   
            ! set array to fill
            i1 = n_rec + 1
            i2 = n_rec + rec
   
            ! load variables
            call rdfinr ('day',1,31,all_dd(i1:i2),rec,rec)
            call rdfinr ('month',1,12,all_mm(i1:i2),rec,rec)
            call rdfinr ('year',1,3000,all_yyyy(i1:i2),rec,rec)
            call rdfdor ('time',0.0d0,1.0d0,all_raintime(i1:i2),rec,rec)
            call rdfdor ('amount',0.0d0,10000.0d0,all_rainamount(i1:i2),rec,rec)
    
            n_rec = n_rec + rec

            close(unit)
    
         end do
   
      else

         call rdfinr ('day',1,31,all_dd,n_rec,n_rec)
         call rdfinr ('month',1,12,all_mm,n_rec,n_rec)
         call rdfinr ('year',1,3000,all_yyyy,n_rec,n_rec)
         call rdfdor ('time',0.0d0,1.0d0,all_raintime,n_rec,n_rec)
         call rdfdor ('amount',0.0d0,10000.0d0,all_rainamount,n_rec,n_rec)
  
         close (unit)

      end if
  
      ! convert year, day, month and fraction of day to absolute time
      datea = 0
      do i = 1,n_rec
         datea(1) = all_yyyy(i); datea(2) = all_mm(i); datea(3) = all_dd(i)
         call dtardp (datea,0.0,tmeteo)
         all_raintime(i) = tmeteo + all_raintime(i) 
      end do

      ! check whether dates are in ascending order
      do i = 2,n_rec
         if ( (all_raintime(i)-all_raintime(i-1)) < vsmall) then
            call dtdpst ('year-month-day hour:minute:seconds',all_raintime(i-1),datedum)
            message ='In RAINFIL the date after '//datedum//' is not correct! Adapt rain file!'
            call swap_error ('loadraindata', message)
         end if
      end do        
   
      ! store raintime and rainflux (SWRAIN = 3)
      if (allocated(raintim)) deallocate(raintim); allocate(raintim(n_rec + 1)); raintim = 0.d0
      if (allocated(rainflx)) deallocate(rainflx); allocate(rainflx(n_rec + 1)); rainflx = 0.d0
      rain_rec = 0
      do i = 1,n_rec

         if (all_raintime(i) >= tstart) then

            if (i == 1) then
               if (all_raintime(i) - tstart > vsmall) then
                  rain_rec = rain_rec + 1
                  raintim(rain_rec) = all_raintime(i)
                  rainflx(rain_rec) = all_rainamount(i) * 0.1d0 / (all_raintime(i) - tstart)
               end if
            else               
               rain_rec = rain_rec + 1
               raintim(rain_rec) = all_raintime(i)
               rainflx(rain_rec) = all_rainamount(i) * 0.1d0 / (all_raintime(i) - all_raintime(i-1))
            end if   
       
         end if
      end do
   
      ! closure of previous rain event
      rain_rec = rain_rec + 1
      raintim(rain_rec) = tend + 2.d0
      rainflx(rain_rec) = 0.d0
   
      ! store daily rainfall
      n_rec = nint(tend) - nint(tstart) + 1
      if (allocated(arai)) deallocate(arai); allocate(arai(n_rec)); arai = 0.d0
      tmeteo = tstart; rain_rec = 1
      do i = 1,n_rec
         do while (raintim(rain_rec) < tmeteo + 1.d0)
            if (rain_rec == 1) then
               rtim = raintim(rain_rec) - tstart
            else
               rtim = raintim(rain_rec) - max(tmeteo, raintim(rain_rec - 1))
            end if   
            arai(i) = arai(i) + rtim * rainflx(rain_rec)
            rain_rec = rain_rec + 1
         end do
         if (rain_rec == 1) then
            rtim = min(1.d0, min(raintim(rain_rec), tmeteo + 1.d0) - tstart)
         else
            rtim = min(1.d0, min(raintim(rain_rec), tmeteo + 1.d0) - raintim(rain_rec - 1))
         end if
         arai(i) = arai(i) + rtim * rainflx(rain_rec)
         tmeteo = tmeteo + 1.d0
      end do
   
      rain_rec = 1
   
      ! deallocate temporary data
      deallocate(all_yyyy, all_mm, all_dd)
      deallocate(all_raintime, all_rainamount)
   
      ! data read and stored properly
      write (unit_log,'(A)') 'RAINFIL: all rain data read and stored.'        
   
      return

   end subroutine LoadRainData

   ! ---------------------------------------------------------------------
   
   subroutine ProcessMeteoDay

      ! ------------------------------------------------------------------
      ! Purpose: returns meteorological fluxes of current day
      ! ------------------------------------------------------------------
      use MOD_swap_base, only: swsnow, sw_multi_swap
      use MOD_snow,      only: gsnow, ssnow, snrai, teprrain, teprsnow
     
      implicit none
     
      integer :: i, i_rec
      real(8) :: sumtav

      ! ------------------------------------------------------------------

      ! process daily weather values
      if (swmetdetail == 0) then

         if (sw_multi_swap == 0 .or. sw_meteo == 2) then
            ! pass on weather values of today
            tmn = atmn(meteo_rec)
            tmx = atmx(meteo_rec)
            if (fl_loadmeteodata) then
               rad = arad(meteo_rec)
               hum = ahum(meteo_rec)
               win = awin(meteo_rec)
            else
               rad = -99.d0
               hum = -99.d0
               win = -99.d0
            end if
       
            if (swetr == 0) then
               etr = -99.d0
            else
               etr  = aetr(meteo_rec)
            end if
            grai = arai(meteo_rec)
         else
            tmn  = ext_meteo%tmin
            tmx  = ext_meteo%tmax
            rad  = ext_meteo%rad
            hum  = ext_meteo%hum
            win  = ext_meteo%wind
            grai = ext_meteo%rain
            wet  = ext_meteo%wet
            etr  = ext_meteo%etref
         end if

         ! average temperature (24h)
         tav = (tmx+tmn)*0.5d0
       
         ! daytime average temperature
         tavd = (tmx+tav)*0.5d0

         ! snow: determine whether the precipitations falls as rain or snow
         if (swsnow == 1) then
            ! snow calculations
            if (tav > TePrRain) then
               gsnow = 0.d0
            else if (tav < TePrSnow) then
               gsnow = grai
            else
            ! + distribution over snow and rain according to linear relation between the two transition temperatures TePrRain and TePrSnow
               gsnow = grai * (TePrRain-tav) / (TePrRain-TePrSnow)
            end if
        
            ! rainfall rate on snowpack
            if (ssnow > 1.d-6) then
               snrai = grai - gsnow
            else
               snrai = 0.d0
            end if
        
            ! fraction of precipitation that is not snow nor rain on snowpack
            if (grai > 0.d0) then
               fprecnosnow = 1.d0 - (gsnow + snrai) / grai
            else
               fprecnosnow = 0.d0
            end if
         else
            ! no snow calculations
            fprecnosnow = 1.d0
         end if
        
      else if (swmetdetail == 1) then

         ! daily sum of precipitation, radiation (J/m2/d) and average, minimum and maximum temperature of today
         grai = 0.d0
         rad = 0.d0
         sumtav = 0.d0
         tmx = -50.d0
         tmn = 99.d0
         do i = 1,n_metdetail
            i_rec = ((meteo_rec - 1) * n_metdetail) + i
            grai = grai + arai(i_rec)
            rad = rad + arad(i_rec)
            sumtav = sumtav + atav(i_rec)
            tmx = max(tmx,atav(i_rec))
            tmn = min(tmn,atav(i_rec))
         end do
         tav = sumtav * dt_meteo
         tavd = (tmx+tav)*0.5d0
        
         ! combination of detailed meteo and snow is not included; omit snow and rainfall rate on snowpack
         gsnow = 0.d0
         ssnow = 0.d0
         snrai = 0.d0
      end if

      return
     
   end subroutine ProcessMeteoDay

   ! ---------------------------------------------------------------------
   
   subroutine ProcessMeteoDT
     
      ! ------------------------------------------------------------------
      ! Returns meteorological fluxes of current timestep
      ! ------------------------------------------------------------------
      use MOD_params,      only: small
      use plant_interface, only: sw_inter
      use MOD_irrigation,  only: isua, gird, nird

      implicit none
      integer, save :: i_rec
      
      ! ------------------------------------------------------------------
     
      ! determine ET-potential
      if (fl_update_meteo) then
        
         fl_update_meteo = .false.
         
         ! update weather record
         i_rec = ((meteo_rec - 1) * n_metdetail) + i_metdetail
         
         ! update weather values in case of detailed meteo
         if (swmetdetail == 1) then
            rad = arad(i_rec)
            tav = atav(i_rec)
            hum = ahum(i_rec)
            win = awin(i_rec)
         end if

         call ETpot
     
      end if
     
      ! set precipitation fluxes per time step
      if (swrain == 0) then
        
         if (swmetdetail == 0) then
            graidt = fprecnosnow * grai
         else
            graidt = arai(i_rec) / dt_meteo
         end if    
     
      else
        
         ! set precipitation fluxes for current time step
         graidt = fprecnosnow * rainflx(rain_rec)

      end if 
     
      ! interception storage
      if (sw_inter /= 3) then
     
         ! interception based on daily fluxes
         if (swrain == 0) then
            aintcdt = aintc
         else
            if (isua == 0) then
               if (grai + gird > 0.d0) then
                  aintcdt = (graidt + gird) *  aintc / (grai + gird)
               else
                  aintcdt = 0.d0
               end if   
            else
               if (grai > 0.d0) then
                  aintcdt = graidt * aintc / grai
               else
                  aintcdt = 0.d0
               end if   
            end if
         end if    
     
      else
         
         ! calculate interception, method Rutter
         call Rutter ()

      end if

      ! divide interception into rain part and irrigation part
      ! and calculate net rain and net sprinkling irrigation      
      if (aintcdt < small) then
         nraidt = graidt
         nird = gird
      else
         if (graidt + gird > small) then
            if (isua == 0) then
               nraidt = graidt - aintcdt * (graidt / (graidt + gird))
               nird = gird - aintcdt * (gird / (graidt + gird))
            else
               nraidt = graidt - aintcdt
               nird = gird
            end if
         else
            nraidt = 0.d0
            nird = 0.d0
         end if
      end if
     
      ! soil evaporation rate of current time step
      call reduceva (nraidt)
     
      ! calculate fraction of the day or period the crop is wet
      if (swmetdetail == 0) then
         if (sw_inter == 1 .OR. sw_inter == 2) then
            if (eintc < 0.001d0) then
               wfrac = 0.d0
            else
               wfrac = max(min(aintc / eintc, 1.d0), 0.d0)
            end if
         end if
      end if

      ! reduce transpiration and evaporation according to wfrac, the fraction of time that there is interception transpiration
      ptra = wfrac * ptra_wet + (1 - wfrac) * ptra_dry
     
      return
   end subroutine ProcessMeteoDT
   
   ! ---------------------------------------------------------------------
   
   subroutine ETpot

      ! ------------------------------------------------------------------

      use plant_interface, only: fl_cropemergence, fco2tra, swcf, cf, vcover, dt_interc_event, crsflx_in, crsflx_out
      use variables,       only: swcfbs, cfbs
      use variables,       only: daynr, rsoil
      
      implicit none
     
      ! ------------------------------------------------------------------
     
      ! in case reference evapotranspiration is input
      if (swmetdetail == 0 .AND. swetr == 1) then

         ! evaporation of bare soil
         es0 = etr * (1.d0 - vcover)
         if (swcfbs == 1) es0 = etr * (1.d0 - vcover) * cfbs
       
         ! evaporation of ponding layer
         ep0 = etr * (1.d0 - vcover) * cfevappond
       
         if (fl_cropemergence) then
            et0 = etr * vcover * cf
            ew0 = etr * vcover * cf
         else
            et0 = 0.d0
            ew0 = 0.d0
         end if

      ! in case reference evapotranspiration must be calculated
      else if (swmetdetail == 1 .OR. swetr == 0) then

         ! evapotranspiration using Penman-Monteith: et0, ew0, es0 (mm/d)
         et0 = 0.0d0
         ew0 = 0.0d0
         ep0 = 0.0d0
         es0 = 0.0d0
         call penmon (daynr,swcfbs,rsoil,vcover)

         if (swdivide == 0) then

            ! evaporation of bare soil
            if (swcfbs == 1) es0 = es0 * cfbs

            if (fl_cropemergence) then
               if (swcf == 1) then
                  et0 = et0 * cf
                  ew0 = ew0 * cf
                  ep0 = ep0 * cfevappond
               end if
            else
               et0 = 0.0d0
               ew0 = 0.0d0
            end if

         end if

      end if

      ! ponding evaporation according to PM or ETref
      epond = max(0.d0, ep0 * 0.1d0)
      
      ! potential soil evaporation according to PM or ETref
      peva = max(0.d0, es0 * 0.1d0)
    
      ! potential transpiration according to PM-direct
      ptra_dry = max(et0 * 0.1d0, 0.d0)

      ! correction of potential transpiration as a function of atmospheric CO2 concentration
      if (fl_cropemergence) then
         ptra_dry = fco2tra * ptra_dry
      end if
      
      ! potential transpiration (while wet canopy)
      if (ew0 > 0.d0) then
         ptra_wet = (ptra_dry / (ptra_dry + ew0 * 0.1d0)) * ptra_dry
         eintc = (ew0 * 0.1d0 / (ptra_dry + ew0 * 0.1d0)) * ew0 * 0.1d0
      else
         ptra_wet = 0.d0
         eintc = 0.d0
      end if
 
      dt_interc_event = 1.0d0
      crsflx_in = 0.d0
      crsflx_out = 0.d0
      wfrac = 0.d0

      return

   end subroutine ETpot    
   
   ! ---------------------------------------------------------------------
   ! Reduction of soil evaporation according to method:
   ! - Black (SWREDU=1)
   ! - Boesten and Stroosnijder (SWREDU=2)
   ! ---------------------------------------------------------------------
   
   subroutine reduceva (nrai)
      
      ! ------------------------------------------------------------------
      use MOD_irrigation, only: nird
      use variables,      only: swredu, cofred, dt, ldwet, pond, rsigni, spev, saev
      implicit none

      ! global
      real(8), intent(in)  :: nrai

      ! local
      real(8) :: saevm1
      
      ! ------------------------------------------------------------------

      if (swevap == 0) then

         ! force zero evaporation
         peva = 0.0d0
         empreva = 0.0d0

      else   
      
         ! reduction potential soil evaporation for every time step
         if (pond > 1.0d-10) then
         
            ! in case of ponding no reduction
            empreva = epond
            ldwet = 0.0d0
            spev = 0.0d0
            saev = 0.0d0
      
         else if (swredu == 1) then
      
            ! reduction with black model
            if (nrai+nird > rsigni) ldwet = 0.0d0
            empreva = (cofred * (dsqrt(ldwet + dt) - dsqrt(ldwet))) / dt
            empreva = min(empreva, peva)
            ldwet = ldwet + dt
      
         else if (swredu == 2) then

            ! reduction with boesten and stroosnijder model
            if ((nrai + nird) < peva) then
               spev = spev + (peva - (nrai + nird)) * dt
               saevm1 = saev
               if (spev < cofred**2) then
                 saev = spev
               else
                 saev = cofred * dsqrt(spev)
               end if
               empreva = nrai + nird + (saev - saevm1) / dt
            else
               empreva = peva
               saev = max (0.0d0, saev - (nrai + nird - peva) * dt)
               if (saev < cofred**2) then
                 spev = saev
               else
                 spev = (saev / cofred)**2
               end if
            end if
         end if
         
      end if

      return
   end subroutine reduceva     
         
   ! ---------------------------------------------------------------------

   subroutine astro(iday,atmtr,dayl,daylp,sinld,cosld,difpp,dsinbe)
      !  Calculates astronomic daylength, diurnal radiation characteristics 
      !  such as the atmospheric transmission, diffuse radiation etc. This
      !  routine has been modified so that it uses arrays to hold some input
      !  output variables for faster processing.
      ! 
      !  Global variables (i = input, o = output)
      !   iday    Day number; Jan 1st = 1 (-).........................i
      !   lat     Latitude of the site (degrees C)....................i
      !   rad     Daily shortwave radiation (J m-2 d-1)...............i
      !   dayl    Astronomical daylength; base = 0 degrees (h)........o
      !   daylp   Astronomical daylength; base =-4 degrees (h)........o
      !   sinld   Seasonal offset of sine of solar height (-).........o
      !   cosld   Amplitude of sine of solar height (-)...............o
      !   difpp   Diffuse irradiation perpendicular to direction of
      !            light (J m-2 s-1)..................................o
      !   atmtr   Daily atmospheric transmission (-)..................o
      !   dsinbe  Daily total of effective solar height (s)...........o
      ! ------------------------------------------------------------------

      use parameters, only: pi, radial
     
      implicit none
     
      ! global variables
      integer, intent(in)             :: iday
      real(8), intent(out), optional  :: atmtr,dayl,daylp,sinld,cosld,difpp,dsinbe

      ! local variables
      real(8)    :: dec,sc,aob,aob_corr,angot,dsinb,frdif
      real(8)    :: atmtr_,dayl_,daylp_,sinld_,cosld_,difpp_,dsinbe_
     
      ! local parameters
      real(8), parameter :: angle   = -4.d0

      ! declination and solar constant for this day
      dec = -asin(dsin(23.45d0 * radial) * dcos(2.d0 * pi * dble(iday + 10.d0) / 365.d0))
      sc = 1370.d0*(1.d0 + 0.033d0 * dcos(2.d0 * pi * dble(iday) / 365.d0))

      ! calculation of daylength from intermediate variables (sinld, cosld, aob)
      sinld_ = dsin(radial * lat) * dsin(dec)
      cosld_ = dcos(radial * lat) * dcos(dec)
      aob = sinld_ / cosld_

      ! For very high latitudes and days in summer and winter a limit is
      ! inserted to avoid math errors when daylength reaches 24 hours in
      ! summer or 0 hours in winter.

      ! calculate solution for base=0 degrees
      if (dabs(aob) <= 1.d0) then
        
         dayl_  = 12.d0 * (1.d0 + 2.d0 * asin(aob) / pi)
        
         ! integrals of sine of solar height
         dsinb  = 3600.d0 * (dayl_ * sinld_ + 24.d0 * cosld_ * dsqrt(1.d0 - aob**2) / pi)
         dsinbe_ = 3600.d0 * (dayl_ * (sinld_ + 0.4d0 * (sinld_**2 + cosld_**2 * 0.5d0)) + &
                  12.d0 * cosld_ * (2.d0 + 3.d0 * 0.4d0 * sinld_) * dsqrt(1.d0 - aob**2) / pi)
      else
        
         if (aob > 1.d0)  dayl_ = 24.d0
         if (aob < -1.d0) dayl_ = 0.d0

         ! integrals of sine of solar height      
         dsinb = 3600.d0 * (dayl_ * sinld_)
         dsinbe_ = 3600.d0 * (dayl_ * (sinld_ + 0.4d0 * (sinld_**2 + cosld_**2 * 0.5d0)))
      end if

      ! calculate solution for base=-4 (ANGLE) degrees
      aob_corr = (-dsin(angle * radial) + sinld_) / cosld_
      if (dabs(aob_corr) <= 1.0d0) then 
         daylp_ = 12.d0 * (1.d0 + 2.d0 * asin(aob_corr) / pi)
      else
         if (aob_corr > 1.0d0)  daylp_ = 24.d0
         if (aob_corr < -1.0d0) daylp_ = 0.d0
      end if

      ! extraterrestrial radiation and atmospheric transmission
      angot = sc * dsinb

      ! check for DAYL=0 as in that case the angot radiation is 0 as well
      if (dayl_ > 0.d0) then
         atmtr_ = rad / angot
      else
         atmtr_ = 0.d0
      end if

      ! estimate fraction diffuse irradiation
      if (atmtr_ > 0.75d0) frdif = 0.23d0
      if (atmtr_ <= 0.75d0 .AND. atmtr_ > 0.35d0) frdif = 1.33d0 - 1.46d0 * atmtr_
      if (atmtr_ <= 0.35d0 .AND. atmtr_ > 0.07d0) frdif = 1.d0 - 2.3d0 * (atmtr_ - 0.07d0)**2
      if (atmtr_ <= 0.07d0) frdif = 1.d0

      difpp_ = frdif * atmtr_ * 0.5d0 * sc

      if (present(dayl)) then
         dayl   = dayl_
         daylp  = daylp_
         sinld  = sinld_
         cosld  = cosld_
         difpp  = difpp_
         dsinbe = dsinbe_
      end if
      if (present(atmtr)) then
         atmtr   = atmtr_
      end if

      return
   end subroutine astro
    
   subroutine penmon (daynr,swcfbs,rsoil,vcover)

      ! ------------------------------------------------------------------
      ! Calculation of potential evaporation and transpiration rates from a
      ! bare soil surface, a dry and a wet crop canopy; based on the 
      ! penman - monteith approach.
      !
      ! Global variables (i = input, o = output)
      !   daynr      daynumber (january 1st = 1) [-].........................i
      !   lat        latitude [degr.,dec.degr., n=+,s=-].....................i
      !   long       longitude measurement site [degr.,dec.degr.]............i
      !   long_tz    longitude centre local timezone [degr.,dec.degr.].......i
      !   alt        altitude above mean sea level [m].......................i
      !   altw       height of wind speed measurement [m] ...................i
      !   alth       height of temperature and humidity measurement [m] .....i
      !   fwind      Factor 24h windspeed to daytime windspeed [-] ..........i
      !   angstroma  first  angstrom coefficient [-].........................i
      !   angstromb  second angstrom coefficient [-].........................i
      !   albedo     reflection coefficient crop [-].........................i
      !   rad        incoming short wave radiation [j/m2/d]..................i
      !   tav        average temperature (24 hour) [C].......................i
      !   hum        vapour pressure [kpa]...................................i
      !   win        average windspeed (24h or 7-19h) [m/s]..................i
      !   rsc        minimum canopy resistance of dry crop [s/m].............i
      !   rsoil      soil resistance in PMdirect [s/m].......................i
      !   rsw        canopy resistance of intercepted water [s/m]............i
      !   swcf       switch use crop factor (=1) or crop height (=2).........i
      !   swcfbs     switch use coefficient to convert pot ET into pot E.....i
      !   ch         crop height [cm]........................................i
      !   es0        potential evaporation rate from a wet bare soil [mm/d]..o
      !   et0        potential transpiration rate from a dry crop [mm/d].....o
      !   ew0        potential transpiration rate from a wet crop [mm/d].....o
      !   ep0        potential evaporation rate from ponding layer [mm/d]....o
      !    
      ! Local
      !   zm         height of wind speed measurement [cm]
      !   zh         height of temperature and humidity measurement [cm]
      !   d          zero displacement of wind profile [cm]
      !   zom        roughness parameter for momentum [cm]
      !   Vcover     vegetation cover [-]
      !-------------------------------------------------------------------
      
      use plant_interface, only: fl_cropemergence, swcf, ch, albedo, rsc, rsw, lai
      use MOD_params,      only: vlarge, small
      use parameters,      only: pi, radial
      implicit none

      ! global variables
      integer, intent(in) :: daynr,swcfbs
      real(8), intent(in) :: rsoil,vcover
     
      ! local variables
      real(8) atmtr
      real(8) lambda,delta,ea
      real(8) ed,etaerc,etaers,etaerw,etradc,etrads,etradw
      real(8) gamma,gammoc,gammos,gammow,palt,rac,ras,raw,cp
      real(8) relssd,rho,rss,tavk,rnc,rnl,rns,rnw
      real(8) ud,vpd,tmnk,tmxk,gs,gc,gw
      real(8) dgrass, chplant
      real(8) zm, zh, zomgrass
      real(8) zact, dact, zomact, fact, fmeas
      real(8) laieff
     
      real(8) startrec, endrec
      real(8) dr, sd, sc, b, ws, w, w1, w2, ra, rso
      real(8) con_tmp

      real(8) rnp,gammop,etaerp,etradp
      
      ! local parameters
      real(8), parameter :: chgrass = 12.d0           ! height of reference crop grassland [cm]
      real(8), parameter :: chsoil  = 0.1d0           ! nihil crop height for a wet bare soil [cm]
      real(8), parameter :: albsoil = 0.15d0          ! reflection coefficient soil [-]
      real(8), parameter :: albpond = 0.08d0          ! reflection coefficient ponding layer [-]
     
      ! ------------------------------------------------------------------

      ! conversion to cm
      zm = 100.d0 * altw
      zh = 100.d0 * alth

      ! height of reference crop; avoid zero crop height
      if (fl_cropemergence) then
         if (swcf == 1) then
            chplant = chgrass
         else
            chplant = max(ch, 0.1d0)
         end if
      else
         chplant = chgrass
      end if

      ! conversion of temperature from [C] to [K]
      tavk = tav + 273.15d0
      tmnk = tmn + 273.15d0
      tmxk = tmx + 273.15d0

      ! atmospheric pressure at elevation alt [kpa] from Burman et al (1987)
      palt = 101.3d0 * ((tavk - 0.0065d0 * alt) / tavk)**5.26d0

      ! latent heat of vaporization [mJ/kg] from Harrison (1963)
      lambda = 2.501d0 - 0.002361d0 * tav

      ! saturation vapour pressure [kPa] from Tetens (1930)
      if (swmetdetail == 1) then
        ea = 0.61078d0 * dexp(17.27d0 * tav / (tav + 237.3d0))
      else
        ea = 0.30539d0 * (dexp(17.27d0 * tmn / (tmn + 237.3d0)) + dexp(17.27d0 * tmx / (tmx + 237.3d0)))
      end if

      ! measured vapour pressure not to exceed saturated vapour pressure
      ed = min(hum,ea)
      ! vapour pressure deficit [kPa]
      vpd = ea - ed

      ! slope vapour pressure curve [kPa/C] from Murray(1967)
      delta = 4098.d0 * ea / (tav + 237.3d0)**2

      ! psychrometric constant [kPa/C] from Brunt(1952)
      gamma = (1.013d-3 * palt) / (0.622d0 * lambda)

      ! atmospheric density [kg/m3] from 'Ideal Gas Law'
      rho = 3.486d0 * palt / (tavk / (1.d0 - 0.378d0 * ed / palt))

      ! specific heat moist air [kJ/kg/C]
      cp = 622.d0 * gamma * lambda / palt

      ! convert average windspeed (24h) to average daytime windspeed (7-19h) and avoid zero windspeed (m/s) from Smith(1991)
      ud = max (win * fwind, 0.0001d0)

      ! adjust wind speed to crop height with minimum of 2 m;
      ! assuming equal wind speed at 100 meter above the soil surface
      dgrass = 2.d0/3.d0 * chgrass
      zomgrass = 0.123d0 * chgrass
      fmeas = dlog((1.d4 - dgrass) / zomgrass) / dlog((zm - dgrass) / zomgrass) 
      zact = max(chplant,200.0d0)
      dact = 2.d0/3.d0 * chplant
      zomact = 0.123d0 * chplant
      fact = dlog((zact - dact) / zomact) / dlog((1.d4 - dact) / zomact)
      ud = ud * fact * fmeas

      ! net short wave radiation [mJ/m2/d] - soil, crop, wet crop & pond layer
      rns = (1.d0 - albsoil) * rad / 1000000.d0
      rnc = (1.d0 - albedo) * rad / 1000000.d0
      rnw = (1.d0 - albedo) * rad / 1000000.d0
      rnp = (1.d0 - albpond) * rad / 1000000.d0

      ! procedure to derive extraterrestrial radiation [mJ/m2/d]
      if (swmetdetail == 1) then

         ! start and end of period (-)
         startrec = dble(i_metdetail - 1) / dble(n_metdetail)
         endrec = dble(i_metdetail) / dble(n_metdetail)

         ! inverse relative distance earth-sun (-)         
         dr = 1.d0 + 0.033d0 * dcos(2.d0 * pi * dble(daynr) / 365.d0)
        
         ! solar decimation (rad)
         sd = 0.409d0 * dsin(2.d0 * pi / 365.d0 * dble(daynr) - 1.39d0)
        
         ! seasonal correction for solar time (h)
         b = 2.d0 * pi * dble(daynr - 81)/364.d0
         sc = 0.1645d0 * dsin(2.d0 * b) - 0.1255d0 * dcos(b) - 0.025d0 * dsin(b)
        
         ! sunset hour angle (rad)
         ws = dacos(-1.d0 * dtan(radial * lat) * dtan(sd))
        
         ! solar time angle at midpoint (w)
         w = pi * (startrec + endrec - 1.d0 + (sc + 0.06667d0 * (long_tz - long)) / 12.0)
        
         ! check daytime
         if (w > -1.d0 * ws .AND. w < ws) then

            !solar time angle at beginning (w1) and end (w2) of period (rad)
            w1 = w - pi * (endrec - startrec)
            w2 = w + pi * (endrec - startrec)
        
            ! extraterrestrial radiation (J/m2/hr)
            ra = 5.904d7 / pi * dr * ((w2 - w1) * dsin(radial * lat) * dsin(sd) + dcos(radial * lat) * dcos(sd) * (dsin(w2) - dsin(w1)))

            ! clear-sky solar radiation (J/m2/hr)
            rso = (angstroma + angstromb) * ra
           
            ! relative sunshine duration (-)
            relssd = rad / rso
           
         else
           
            ! nighttime period
            ra = 0.d0
           
            ! assume Rs/Rso = 0.8 during night time 
            relssd = 0.8d0 ! SHOULD BE USER INPUT!
        
         end if
        
         ! net long wave radiation (mJ/m2/hr) from Allen et al (1998)
         rnl = 4.903d-9 / 24.d0 * (tavk**4) * (0.34d0 - 0.14d0 * dsqrt(ed)) * (1.35d0 * relssd - 0.35d0)
        
      else

         ! daily extraterrestrial radiation
         call astro(daynr,atmtr=atmtr)

         ! net long wave radiation (mJ/m2/d) from Allen et al (1998)
         relssd = max(min((atmtr - angstroma) / angstromb, 1.d0), 0.d0)
         rnl = 2.45015d-9 * (tmxk**4 + tmnk**4) * (0.34d0 - 0.14d0 * dsqrt(ed)) * (0.1d0 + 0.9d0 * relssd)

      end if

      ! soil heat flux [mJ/m2/d]
      if (swmetdetail == 1) then
       
         if (w > -1.d0 * ws .AND. w < ws) then
            ! daytime period
            gs = 0.1d0 * (rns - rnl)
            gc = 0.1d0 * (rnc - rnl)
            gw = 0.1d0 * (rnw - rnl)
         else
            ! nighttime period
            gs = 0.5d0 * (rns - rnl)
            gc = 0.5d0 * (rnc - rnl)
            gw = 0.5d0 * (rnw - rnl)
         end if

      else

         ! daily record, net flux negligable
         gs = 0.d0
         gc = 0.d0
         gw = 0.d0
     
      end if
    
      ! aerodynamic resistance for dry and wet crop
      rac = raero(chplant, ud, zact, zh)
      raw = rac

      ! aerodynamic resistance for bare wet soil with a crop height set to 0.1 cm
      ras = raero(chsoil, ud, zact, zh)

      ! surface resistance of wet soil [s/m]
      if (swdivide == 0) then

         rss = 0.d0

         ! modified psychrometric constant [kPa/C] - soil, crop & wet crop 
         gammos = gamma * (1.d0 + rss / ras)
         gammoc = gamma * (1.d0 + rsc / rac)
         gammow = gamma * (1.d0 + rsw / raw)
     
         ! aerodynamic term of the pm equation [mm/d] - soil, crop & wet crop
         con_tmp = (86.4d0 * rho * cp * vpd) / lambda
         etaers = con_tmp / ((delta + gammos) * ras)
         etaerc = con_tmp / ((delta + gammoc) * rac)
         etaerw = con_tmp / ((delta + gammow) * raw)

         ! radiation term of the pm equation [mm/d] - soil, crop & wet crop
         con_tmp = delta * dble(n_metdetail) / lambda
         etrads = con_tmp * (rns - rnl - gs) / (delta + gammos)
         etradc = con_tmp * (rnc - rnl - gc) / (delta + gammoc)
         etradw = con_tmp * (rnw - rnl - gw) / (delta + gammow)

         ! sum of both terms [mm/d] - soil, crop & wet crop
         if (swcf == 1 .AND. swcfbs == 1) then
            es0 = max(0.d0, (etaerc + etradc) * (1.d0 - vcover))
         else   
            es0 = max(0.d0, (etaers + etrads) * (1.d0 - vcover))
         end if
        
         et0 = max(0.d0, (etaerc + etradc) * vcover)
         ew0 = max(0.d0, (etaerw + etradw) * vcover)
         ep0 = max(0.d0, (etaerw + etradw) * (1.d0 - vcover))

      else

         ! PMdirect: potential transpiration Tdirect and potential evaporation Edirect
        
         ! apply specified soil resistance
         rss = rsoil 

         ! adjust aerodynamic resistances
         if (vcover > 1.d-6) then
            rac = rac / vcover
         else
            rac = 1.d12
         end if
         raw = rac

         if ((1.d0 - vcover) > 1.d-6) then
            ras = ras / (1.d0 - vcover)
         else
            ras = 1.d12
         end if

         ! effective leaf area index
         LAIeff = lai / (0.3d0 * lai + 1.2d0)

         ! modified psychrometric constant [kPa/c] - crop, wet crop & pond layer 
         gammos = vlarge
         if (ras > small) gammos = gamma * (1.d0+rss/ras)
         gammoc = vlarge
         if ((rac*LAIeff) > small) gammoc = gamma*(1.d0+rsc/(rac*LAIeff))
         gammow = vlarge
         if ((raw*LAIeff) > small) gammow = gamma*(1.d0+rsw/(raw*LAIeff))
         gammop = vlarge
         if (ras > small) gammop = gamma

         ! aerodynamic term of the pm equation [mm/d] - crop, wet crop & pond layer
         con_tmp = (86.4d0 * rho * cp * vpd / lambda)
         etaers = con_tmp / ((delta+gammos) * ras)
         etaerc = con_tmp / ((delta+gammoc) * rac)
         etaerw = con_tmp / ((delta+gammow) * raw)
         etaerp = con_tmp / ((delta+gammop) * ras)

         ! radiation term of the pm equation [mm/d] - crop, wet crop & pond layer
         con_tmp = delta * dble(n_metdetail) / lambda
         etrads = con_tmp * (rns - rnl - gs) * (1.d0 - vcover) / (delta + gammos)
         etradc = con_tmp * (rnc - rnl - gc) * vcover / (delta + gammoc)
         etradw = con_tmp * (rnw - rnl - gw) * vcover / (delta + gammow)
         etradp = con_tmp * (rnp - rnl - gs) * (1.d0 - vcover) / (delta + gammop)

         ! sum of both terms [mm/d] - crop, wet crop & pond layer
         es0 = max(0.d0, etaers + etrads)
         et0 = max(0.d0, etaerc + etradc)
         ew0 = max(0.d0, etaerw + etradw)
         ep0 = max(0.d0, etaerp + etradp)
      end if

      return
   end subroutine

   ! ---------------------------------------------------------------------
   
   function raero(ch, ud, zm, zh)
      ! ------------------------------------------------------------------
      !  Determines the aerodynamic resistance for use in Penman-Monteith.
      ! 
      !  Global variables (i = input, o = output)
      !    ch      crop height [L]....................................i
      !    ud      windspeed [L/T]....................................i
      !    zm      corrected height of windspeed measurement [L]......i
      !    zh      height of temperaure and humidity measurement [L]..i
      !    raero   aerodynamic resistance in [T/L]....................o
      ! ------------------------------------------------------------------
   
      implicit none

      ! global variables
      real(8), intent(in) :: ch, ud, zm, zh

      ! local variables
      real(8) :: d, zom, zoh
      real(8), parameter :: cKarman = 0.41d0  ! ckarman von karman constant [-]
      real(8), parameter :: check = exp(1.d0)
     
      ! function
      real(8) :: raero

      ! ------------------------------------------------------------------
      
      ! zero displacement of wind profile [L]
      d = (2.d0/3.d0) * ch     

      ! roughness parameter for momentum  [L]
      zom = 0.123d0 * ch    

      ! roughness parameter for heat and vapour [L]
      zoh = 0.1d0 * zom      

      ! aerodynamic resistance for dry and wet crop [T/L]
      raero = dlog((zm - d) / zom) * dlog(max(check,(zh - d) / zoh)) / (cKarman**2 * ud)

      return
   end function

   ! ---------------------------------------------------------------------


   subroutine interception_daily()
      
      ! ------------------------------------------------------------------
      !     Purpose : Interception based on daily rainfall
      !               VonHHBraden (swinter = 1) or Gash (swinter = 2)
      ! ------------------------------------------------------------------
      use plant_interface, only: lai, sw_inter
      use MOD_snow,        only: gsnow, ssnow
      use MOD_irrigation,  only: gird
      
      implicit none
      
      ! interception based on daily rainfall: VonHHBraden and Gash
      
      ! reset wfrac at start of day
      wfrac = 0.d0
      
      !   - Calculation of Interception and Net rain & Net irrigation depth [cm]
      if (lai < 1.d-3 .OR. grai+gird < 1.d-5 .OR. sw_inter == 0 .OR. gsnow > 0.d0 .OR. ssnow > 0.d0) then
          
         ! no vegetation, rainfall/irrigation or interception calculation
         aintc = 0.d0
      
      else if (sw_inter == 1) then
         
         ! calculate interception, method Von Hoyningen-Hune and Braden
         call VonHHBraden ()
      
      else if (sw_inter == 2) then
         
         ! calculate interception, method Gash (1995)
         call Gash ()
      
      end if
        
      return
     
   end subroutine interception_daily
    
   ! ---------------------------------------------------------------------
   ! Calculate interception according to method:
   ! - Von Hoyningen-Hune and Braden (SWINTER=1)
   ! - Gash (SWINTER=2)
   ! - Rutter (SWINTER=3; adapted version)
   ! ---------------------------------------------------------------------
   
   subroutine VonHHBraden ()
      
      ! ---------------------------------------------------------------
      
      use plant_interface, only: lai, vcover, cofab
      use MOD_irrigation,  only: gird, isua
      implicit none

      ! local
      real(8) :: rpd                 ! Amount of precipitation and irrigation by sprinkling in mm/d
      
      ! ------------------------------------------------------------------
      
      ! default
      aintc = 0.d0
    
      ! intercepted precipitation and irrigation in mm
      if (isua == 0) then
         rpd = (grai + gird) * 10.d0
      else
         rpd = grai * 10.d0
      end if

      if (rpd > 0.d0) then

         ! interception: evaporation of intercepted precipitation in cm
         aintc = 0.1d0 / (1.0d0 / (cofab * lai) + 1.0d0 / (rpd * vcover))
      end if

      return
    
   end subroutine VonHHBraden
   
   ! ---------------------------------------------------------------------

   subroutine Gash ()
      
      ! ------------------------------------------------------------------
      
      use MOD_arrays,      only: macroptb
      use plant_interface, only: pfreetb, pstemtb, scanopytb, avevaptb, avprectb
      use MOD_irrigation,  only: gird,isua
      use variables,       only: t
      
      implicit none

      ! local
      real(8) :: avevap              ! average evaporation intensity during shower (-) as function of time (T)
      real(8) :: avprec              ! average rainfall intensity (-) as function of time (T)
      real(8) :: cGash               ! slope of dPi/dPgross before saturation of canopy
      real(8) :: pfree               ! free throughfall coefficient (-) as function of time (T)
      real(8) :: pstem               ! stem flow coefficient (-) as function of time (T)
      real(8) :: psatcan             ! amount of rainfall to saturate canopy
      real(8) :: rpd                 ! amount of precipitation and irrigation by sprinkling in cm/d
      real(8) :: scanopy             ! storage capacity of canopy (-) as function of time (T)
      
      ! functions 
      real(8) :: afgen
      
      ! ------------------------------------------------------------------
      
      ! default
      aintc = 0.d0
    
      ! intercepted precipitation and irrigation in cm
      if (isua == 0) then
         rpd = grai + gird
      else
         rpd = grai
      end if

      if (rpd > 0.d0) then
    
         ! calculate interception for forests according to Gash (1995)
         pfree = afgen(pfreetb, macroptb, t)
         pstem = afgen(pstemtb, macroptb, t)
         cGash = 1.d0 - pfree - pstem
         scanopy = afgen(scanopytb, macroptb, t) / cGash
         avprec = afgen(avprectb, macroptb, t)
         avevap = afgen(avevaptb, macroptb, t) / cGash

         ! amount of rainfall to saturate canopy
         if ( (1.0d0 - avevap / avprec) > 1.0d-4) then
           psatcan = -avprec * scanopy / avevap * dlog(1.0d0 - avevap/avprec)
         else
           psatcan = avprec * scanopy / avevap
         end if

         ! interception: evaporation of intercepted precipitation in cm
         if (rpd < psatcan) then
            aintc = cGash * rpd
         else
            aintc = cGash * ( psatcan + avevap * cGash / avprec * (rpd - psatcan) )
         end if
      end if
    
      return
   end subroutine Gash
   
   ! ---------------------------------------------------------------------
   
   subroutine Rutter ()
      
      ! ---------------------------------------------------------------
      
      use MOD_params,      only: nihil   
      use plant_interface, only: vcover, siccap, sicact, crsflx_in, crsflx_out, dt_interc_event
      use MOD_irrigation,  only: isua, gird
      
      implicit none

      ! local
      real(8) :: rpd                    ! gross rainfall and irrigation [cm/d]
      real(8) :: flux_in                ! incoming flux (rain and irrigation)
      real(8) :: flux_out               ! outgoing flux (evaporation from reservoir)
      
      ! ------------------------------------------------------------------
      
      ! intercepted precipitation and irrigation in mm
      if (isua == 0) then
        rpd = graidt + gird
      else
        rpd = graidt
      end if

      ! default
      dt_interc_event = 1.d0
      
      
      ! incoming flux (first estimation)
      flux_in = rpd * vcover
      
      ! outgoing flux (first estimation)
      flux_out = eintc
      
      ! reset flux in case no incoming or outgoing flux
      if (flux_in + flux_out < nihil) then
      
         ! reset flux canopy reservoir
         crsflx_in = 0.d0
         crsflx_out = 0.d0
         wfrac = 0.d0
         
      else
         
         ! check net flux reservoir
         if (flux_in >= flux_out) then
         
            ! net inflow
            if (siccap - sicact > nihil) then
            
               ! reservoir inflow
               crsflx_in = flux_in
               crsflx_out = flux_out
            
               ! check time at which inflow reaches reservoir capacity
               dt_INTERC_event = (siccap - sicact) / (crsflx_in - crsflx_out)
         
            else
            
               ! maximum level reservoir reached
               crsflx_in = flux_out
               crsflx_out = flux_out
         
            end if
         
            ! wet canopy
            wfrac = 1.d0
      
         else
         
            ! net outflow
            if (sicact > nihil) then
            
               ! reservoir outflow
               crsflx_in = flux_in
               crsflx_out = flux_out

               ! check time at which reservoir is empty
               dt_INTERC_event = sicact / (crsflx_out - crsflx_in)
            
               ! wet canopy
               wfrac = 1.d0
         
            else
            
               ! limited reservoir outflow (empty reservoir)
               crsflx_in = flux_in
               crsflx_out = flux_in
            
               ! assume semi-wet canopy in case of incoming flux
               wfrac = flux_in / flux_out
            
            end if
      
         end if      
      
      end if
      
      ! interception of rainfall and irrigation
      aintcdt = crsflx_in
      
      return
   end subroutine Rutter
   
end module MOD_meteo

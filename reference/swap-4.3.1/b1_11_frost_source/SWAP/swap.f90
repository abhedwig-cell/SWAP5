module swap_exchange

   type :: swap_input

      !sequence

      ! start and finish time; typically a single day is to be considered, which means Tend = Tstart!!!
      ! units: days since 1900-01-01
      real(8)                             :: tstart, tend

      ! weather data
      ! units:                               oC    oC    kPa  m/s   mm/d  -    mm/d   kJ/m2/d
      real(8)                             :: tmin, tmax, hum, wind, rain, wet, etref, rad

      ! crop variables from external crop
      ! cropheight, rooting depth and lai of external crop; overwrites value of dummy crop
      ! units                                cm  cm     m2/m2
      real(8)                             :: ch, zroot, lai

      ! yes (1) or no (0) crop present
      integer(8)                          :: icrop

      ! yes (1) or no (0) use externally provided PTRANS and PEVAP
      integer(8)                          :: ipet

      ! units:                               mm/d    mm/d
      real(8)                             :: ptrans, pevap

      ! irrigation: fixed option; daily amounts
      integer(8)                          :: swirfix        ! 0: no irigation today; 1: irrigation current day
      real(8)                             :: irdate         ! current date in t1900 units
      real(8)                             :: irdepth        ! mm (per day)
      integer(8)                          :: irtype

      ! SSDI irrigation: fixed option; daily amounts
      integer(8)                          :: swssdi         ! 0: no irigation today; 1: irrigation current day
      real(8)                             :: ssdi_date      ! current date in t1900 units
      real(8)                             :: ssdi_rate_f    ! mm/h
      real(8)                             :: ssdi_amount_f  ! mm
      integer(8)                          :: ssdi_node

      !!!character(len = 32)                 :: swapfilename
      
   end type

   type :: swap_output

      !sequence
      real(8)                             :: tstart, tend

      ! actual number of nodes of whole oil profile; also actual length of return arrays
      integer(8)                          :: numnodes

      ! Potential and actual daily transpiration
      real(8)                             :: tpot, tact

      ! Potential and actual daily soil evaporation
      real(8)                             :: epot, eact

      ! for error handling
      integer(8)                          :: ierrorcode

      ! Actual groundwater level
      real(8)                             :: gwl

      ! return arrays: thickness of all soil layers, and per layer:
      ! volumetric water content, root water uptake, soil temperature, water fluxes (integrated), drain fluxes (integrated, alle levels summed)
      real(8), dimension(501)             :: dz
      real(8), dimension(501)             :: h
      real(8), dimension(501)             :: wc
      real(8), dimension(501)             :: rwu
      real(8), dimension(501)             :: tsoil
      real(8), dimension(501)             :: q
      real(8), dimension(501)             :: qdra

      real(8)                             :: igird    ! actual amount of irrigation (cm; per day)
      real(8)                             :: iqssdi   ! actual amount of SSDI irrigation (cm; per day)

   end type
   
end module swap_exchange

subroutine SWAP_4_DFF(iCaller, iTask, toswap, fromswap) 

! This is needed in case a swap.dll is to be constructed
!DEC$ IF (linux==0)
!dec$ attributes dllexport :: SWAP_4_DFF
!DEC$ END IF

use MOD_arrays, only: fillen
use swap_exchange

implicit none

interface
   subroutine SWAP(iCaller, iTask, tstart_in, tend_in, swp_file, outfile, toswap, fromswap)
      use swap_exchange
      use MOD_arrays, only: fillen
      integer,                intent(in)              :: iCaller, iTask
      real(8),                intent(inout)           :: tstart_in, tend_in
      character(len=fillen),  intent(in),    optional :: swp_file
      character(len=fillen),  intent(in),    optional :: outfile
      type(swap_input),       intent(in),    optional :: toswap
      type(swap_output),      intent(out),   optional :: fromswap
   end subroutine SWAP
end interface

! global
integer,                intent(in)              :: iCaller, iTask
type(swap_input),       intent(in),    optional :: toswap
type(swap_output),      intent(out),   optional :: fromswap

! local
real(8)                 :: tstart_in, tend_in
character(len=fillen)   :: swp_file, outfile

! temporaily check
if (iCaller /= 2) then
   write(*,*) 'iCaller must be 2'
   return
end if

! forcing
swp_file  = 'swap.swp'
outfile   = 'swap'
tstart_in = toswap%tstart
tend_in   = toswap%tend

call SWAP(iCaller, iTask, tstart_in, tend_in, swp_file, outfile, toswap, fromswap)
   
end subroutine SWAP_4_DFF
   
! -----------------------------------------------------------------------------------------------------------------------
subroutine SWAP(iCaller, iTask, tstart_in, tend_in, swp_file, outfile, toswap, fromswap) 

! The model swap can perform three major tasks (iTask):
!    1 - initialization
!    2 - dynamic (time loop)
!    3 - closure
! The input variable iCaller determines who is calling the swap model:
!    0 - the swap model is called from swap_main
!    1 - the swap model is called from swap_controller (multi-SWAP)
!    2 - the swap model as DLL is called from elsewhere (typically DFF), and additional actions are performed regarding exhange of data

! -----------------------------------------------------------------------------------------------------------------------

! This is needed in case a swap.dll is to be constructed
!DEC$ IF (linux==0)
!dec$ attributes dllexport :: SWAP
!DEC$ END IF

!     swap modules for data communication
use swap_exchange

!DEC$ IF DEFINED (with_animo)
use MOD_from_swap
use MOD_to_animo
use MOD_swap_base,         only: sw_animo
use wofost_soil_interface, only: NdemandSoil, NsupplySoil
!DEC$ END IF

use MOD_swap_base,       only: pathwork, swcrop, swhea, swsolu, swtill, unit_err, swsnow, swfrost, swdra, swmacro, swcropsnm, fl_initialize, &
                               swinco, sw_end, swsolve, sw_multi_swap
use MOD_swap_base,       only: swap_configuration, swap_invoke                                        ! routines
use MOD_arrays,          only: fillen
use atmosphere_interface,only: tav
use plant_interface,     only: croptype, icrop, fl_cropemergence, fl_cropharvest, fl_cropharvestday
use MOD_cropdevelopment, only: croprotation, cropdevelopment, reset_crop
use MOD_wofost,          only: assimilation
use MOD_meteo,           only: meteo, interception_daily, peva, empreva, epond
use MOD_snow,            only: snow
use MOD_frost,           only: frozencond, frozenbounds, rfcp
use MOD_macropore,       only: macrostatevar, macropore
use MOD_MvG,             only: fill_cofgen, set_cofgen_pointers
use MOD_SoilWater,       only: soilwater, soilwaterstatevar
use MOD_SoilTemperature, only: SoilTemperature, tsoil, tetop
use KVapor,              only: DefaultTemperature
use MOD_Solute,          only: Solute
use MOD_integral,        only: integral
use MOD_swap_mp,         only: fldecmprat
use MOD_drain,           only: drain
use MOD_tillage,         only: DoTillage
use MOD_grid,            only: numnod
use MOD_gwl,             only: calcgwl
use MOD_rootextraction,  only: RootExtraction, reset_rootextraction
use MOD_irrigation,      only: irrigation, flirrigate
use variables,           only: fldaystart, flrunend, fldtreduce, fldecdt, fldayend, flmaxitertime, floutput, floutputshort, flzerointr,      &
                               outfil, tstart, tend, nhead, ioutdat, t, timjan1, daynr, gwl, gwlm1, dt, t1900

implicit none
interface
   subroutine swap_ok(swp_ok)
      character(len=*), intent(in), optional :: swp_ok
   end subroutine swap_ok
end interface

! global
integer,                intent(in)              :: iCaller, iTask
real(8),                intent(inout)           :: tstart_in, tend_in
character(len=fillen),  intent(in),    optional :: swp_file
character(len=fillen),  intent(in),    optional :: outfile
type(swap_input),       intent(in),    optional :: toswap
type(swap_output),      intent(out),   optional :: fromswap

! local
logical :: flError

!DEC$ IF DEFINED (with_animo)
real(8), save :: juda, judami, judama, N_demand, N_actual, N_actual_old
!DEC$ END IF

! check if only version or help info should be written to screen
call swap_invoke()

if (iCaller == 2 .AND. iTask < 3) then
   if (.NOT.(present(toswap)))   call swap_error ('swap', 'Argument toswap missing in DLL call.')
   if (.NOT.(present(fromswap))) call swap_error ('swap', 'Argument fromswap missing in DLL call.')
end if
flError = .FALSE.

!****************************************************************************************************************************
!*****   I N I T I A L I Z A T I O N   *****
!****************************************************************************************************************************
if (iTask == 1) then

!  Initialization of all variables in Module Variables
   ! note: initializtion for multi-SWAP is done externally in swap_controller
   if (iCaller /= 1) call Initialize

!  iteration and timing statistics
   call IterTime(1)

!  Pre-initial: configuration settings, calcgrid
   !pathwork = ".\"
   pathwork = pathwork     ! to prevent warning from ForCheck
   if (present(swp_file)) then
      call swap_configuration(swp_file = swp_file)
   else
      call swap_configuration()
   end if

!  read time independent input .swp file
   call ReadSwap
   if (present(outfile)) outfil = outfile

   tstart_in = tstart
   tend_in   = tend

!  initialize meteo
   call Meteo(1)

!  initialize time variables and switches/flags
   call TimeControl(1)

!  calculate grid parameters
   if (swtill == 1) call DoTillage(1)

!  initialize SSDI irrigation
   !call SSDI_irrigation(1)

!  initialize SoilWater rate/state variables
   if (sw_multi_swap == 0) then
      call fill_cofgen
   else
      call set_cofgen_pointers
   end if
   call SoilWater(1)
   if (sw_multi_swap == 0) call calcgwl()
   
!  initialize SoilTemperature rate/state variables
   if (swhea > 0) call SoilTemperature(1)
   if (swhea == 0) tsoil = dble(DefaultTemperature)

!  initialize drainage variables
   if (swdra > 0) call drain(1)

!  initialize MacroPore rate/state variables
   if (swmacro == 1) call MacroPore(1)

!  initialize Snow rate/state variables
   if (swsnow  == 1) call Snow(1, tsoil(1), tav, epond, peva, empreva)
   if (swfrost == 0) rfcp = 1.0d0

!  initialize Solute rate/state variables
   if (swsolu > 0) call Solute(1)

!  Read and Initialize Soil Management Event
   if (swcropsnm == 1) call Soilmanagement(1)

!  open Output files and write headers
   if (present(outfile)) outfil = outfile
   call SwapOutput(1)
   call SoilWaterOutput(1)
   if (swmacro == 1) call MacroPoreOutput(1)

!  Specific for exchange when called as DLL
   if (iCaller == 2) call handle_exchange(11, flError)

!DEC$ IF DEFINED (with_animo)
   if (sw_animo == 1) call fill_ta(iTask)
   if (sw_animo == 1) call animo(iTask, juda, judami, judama)
   N_actual_old = 0.0d0
!DEC$ END IF

   return
end if

if (iTask == 11) then
   call SoilWater(1)
   if (swhea > 0) call SoilTemperature(1)
   if (present(outfile)) outfil = outfile
!  open Output files and write headers
   call SwapOutput(1)
   call SoilWaterOutput(1)
   return
end if

!****************************************************************************************************************************
!*****   D Y N A M I C   *****
!****************************************************************************************************************************
if (iTask == 21) then
   ! check if tstart_in = t1900???
   tstart = tstart_in
   tend   = tend_in

   t1900 = tstart_in

   ! need to re-initialize
   fldaystart = .TRUE.
   flrunend   = .FALSE.
   fldecdt    = .FALSE.
   flzerointr = .TRUE.
   t          = tstart - timjan1
   daynr      = nint(t)
   ioutdat    = 1
!   call TimeControl(1)
   
   if (swsolve == 2) dt = 1.0d0
   
   ! re-initialize SoilWater
   swinco = 3
   nhead  = numnod * 2
   gwlm1  = gwl         ! to prevent warning from calcgwl (called in SoilWater(1)) in case of multi-SWAP
   call SoilWaterStateVar(1)
   call soilwater(1)
   call calcgwl()
   if (swhea > 0) call SoilTemperature(11)

   ! permanent bare soil: reset RWU vars to zero
   if (swcrop == 0) call reset_rootextraction()

end if

if (iTask == 2) then

!  Specific for exchange when called as DLL
   if (iCaller == 2) call handle_exchange(21, flError); if (flError) return

!  loop with soil water time step during entire simulation period
   do while (.NOT.flrunend)

      if (flDayStart) then

         ! set time at start of day
         call TimeControl(2)

         if (iCaller /= 2) then
!           process weather data for current day
            call Meteo(2)
         else
!           Specific for exchange when called as DLL
            call handle_exchange(22, flError)   ! weather data
         end if

!        check cropping period
         if (swcrop == 1) call croprotation(2)

!        Specific for exchange when called as DLL
         if (iCaller == 2) call handle_exchange(23, flError)   ! LAI, RD

!        calculate Irrigation rate/state variables
         if (sw_multi_swap == 0) then
            if (flIrrigate) call Irrigation(3)
         else
            if (flIrrigate) call Irrigation(4)
            !if (i_instance == 1) write(500+i_core,'(2A,2F15.6)') ' daystart ', date, t1900, gird
         end if

!        check if subsurface irrigation is required and determine if time step needs to be changed due to dt_irr_event
         !call SSDI_irrigation(2)
         call TimeControl(9)

!        set interception based on daily rainfall (typically for sw_inter = 1 or 2)
         call interception_daily()

!        assimilation (dynamic crop growth by WOFOST)
         if (swcrop == 1 .AND. fl_cropemergence) then
            if (croptype(icrop) == 2) call assimilation ()
         end if

!        Specific for exchange when called as DLL
         if (iCaller == 2) call handle_exchange(24, flError)   ! PTRANS, PEVAP, EMPREVA

         if (swtill == 1) call DoTillage(2)

         fl_initialize = .FALSE.

      end if

!     possible reset of time-integrated vars (mainly used for output)
      call integral(2)

      if (iCaller /= 2) then
         ! process weather data for specific time
         call Meteo(3)
         call TimeControl(4)
      else
         call handle_exchange(24, flError)   ! PTRANS, PEVAP, EMPREVA
      end if

!     calculate Snow: MH+MM - probably to be moved within IF-block above, prior to call ProcessMeteoDay ...
      if (swsnow == 1 .AND. flDayStart) call Snow(2, tsoil(1), tav, epond, peva, empreva)

!     calculate reduction for conductivities for frozen conditions
      if (swfrost == 1) call FrozenCond(tsoil, tetop)

!     calculate potential and actual root water extraction profile
      if (swcrop == 1) call RootExtraction(2)

!     determine SoilWater bottom boundary conditions
      call BoundBottom

      fldtreduce = .TRUE.
      do while(fldtreduce)
         fldtreduce = .FALSE.

!        calculate drainage fluxes (note: it is or Drainage or SurfaceWater, but not both)
         if (swdra > 0)    call drain(2)

!        Frozen boundary conditions?
         if (swfrost == 1) call FrozenBounds

!        calculate SoilWater, incl macropores
         if (.NOT.fldecdt) call SoilWater(2)

!        calculate surface water balance
         if (swdra == 2)   call drain(3)

!        update time variables and switches/flags
         if (fldecdt .OR. (swmacro == 1 .AND. FlDecMpRat)) then
            call SoilWaterStateVar(2)
            if (swmacro == 1) call MacroStateVar(2)
            call TimeControl(5)
            fldtreduce = .TRUE.
         end if

      end do

!     calculate SoilWater rate/state variables
      call SoilWater(3)

!     update time-integrated vars (mainly used for output)
      call integral(3)

!     calculate SoilTemperature rate/state variables
      if (swhea > 0) call SoilTemperature(2)

!     calculate Solute rate/state variables
      if (swsolu > 0) call Solute(2)

!     update time variables and switches/flags
      call TimeControl(3)

!     at the end of a day,
      if (flDayEnd) then

         if (swcropsnm == 1) then

            ! update Soil nutrient status variables
            call Soilmanagement(2)

            ! amendent of crop residues from previous day
            call Soilmanagement(5)

            ! amendent of fertilizers of current day
            call Soilmanagement(3)

         end if

         ! calculate crop growth (potential and actual); this is skipped in case called externally
         if (iCaller /= 2 .AND. swcrop == 1 .AND. fl_cropemergence) call cropdevelopment (3)
         
!        Simulate Soil Nutrient processes
         if (swcropsnm == 1) call Soilmanagement(4)
         
!DEC$ IF DEFINED (with_animo)
         ! call ANIMO
         if (sw_animo == 1) then
            call fill_ta(iTask)
            call animo(iTask, juda, judami, judama)
            N_demand = ta%nutr%Ndemand
            N_actual = ta%nutr%Nuptake
            !write(990,'(5F15.5)') t1900, NdemandSoil, NsupplySoil, N_demand * 1.0d4, N_actual * 1.0d4
            NsupplySoil = max(0.0d0, (N_actual - N_actual_old) * 1.0d4)
            N_actual_old = N_actual
         end if
!DEC$ END IF

!        harvest of crop; this is skipped in case called externally
         fl_cropharvestday = .FALSE.
         if (iCaller /= 2 .AND. swcrop == 1 .AND. fl_cropemergence) call cropdevelopment (4)

!        update time-integrated vars depending on crop status (mainly used for output)
         call integral (4)

         
!        timing statistics : prevent (near) endless simulations
         if (flMaxIterTime) call IterTime(2)

      end if

!     output section (write to standard files and to optional files)
      if (flOutput) then
         call SwapOutput(2)
         call SoilWaterOutput(2)
         if (swtill == 1)     call DoTillage(3)
         if (swsolu > 0)      call Solute(3)
         if (swmacro == 1)    call MacroPoreOutput(2)
      else
         if (flOutputShort)   call SoilWaterOutput(2)
      end if
      if (flDayEnd) then
         if (swcropsnm == 1) call Soilmanagement(6)
         if (sw_end == 2) call soilwateroutput(3)
         if (fl_cropharvest) call reset_crop()

!        calculate Irrigation rate/state variables
         if (sw_multi_swap == 1) then
            if (flIrrigate) call Irrigation(3)
            !if (i_instance == 1) write(500+i_core,'(2A,2F15.6)') ' dayend   ', date, t1900, gird
         end if

      end if

   end do

!  Specific for exchange when called as DLL
   if (iCaller == 2) call handle_exchange(29, flError)

   return
end if

!****************************************************************************************************************************
!*****   C L O S U R E   *****
!****************************************************************************************************************************
if (iTask == 3) then

   !  delete temporary files
   !call CloseTempFil


   !  iteration and timing statistics
   !call IterTime(3)

!  close output files
   call SwapOutput(3)
   if (sw_end == 1) call SoilWaterOutput(3)
   call SoilWaterOutput(4)
   if (swsolu > 0)           call Solute(9)
   if (swmacro == 1)         call MacroPoreOutput(3)
   if (swcropsnm == 1)       call Soilmanagement(7)

!DEC$ IF DEFINED (with_animo)
   if (sw_animo == 1) call animo(iTask, juda, judami, judama)
!DEC$ END IF

   ! write okay file for external use
   call swap_ok()

   ! close and delete err-file (becuase it has not been used)
   close(unit_err, status = 'delete')

!  delete temporary files
   !call CloseTempFil

!  Specific for exchange when called as DLL
   if (iCaller == 2) call handle_exchange(31, flError)

   return
end if

contains

!  routine to handle exchange with calling program
   subroutine handle_exchange(task, flError)

   use MOD_swap_base,         only: swetr, swmetdetail, swrain, swirfix, swsnow
   use plant_interface,       only: fl_cropemergence, fl_cropharvest, ch, lai, sw_inter, rd
   use MOD_meteo,             only: swdivide, epond, peva, ptra_dry, ptra, ptra_wet, reduceva, aintc, wfrac
   use MOD_meteo,             only: tmn, tmx, hum, win, etr, graidt, nraidt, tavd, fprecnosnow
   use MOD_cropdevelopment,   only: fl_cropcalendar
   use MOD_irrigation,        only: nod_ssdi, schedule, gird, nirri, irdate, irdepth, irtype, irconc, irrate, dt_irr_event
   use variables,             only: t1900, iyear, tstart, tend
   use atmosphere_interface,  only: rad, tav

   implicit none
   integer, intent(in)   :: task
   logical, intent(out)  :: flError
   ! local
   integer               :: swssdi
   integer, dimension(6) :: datea
   real                  :: fsec
   real(8), save         :: tlast

! NOTE: the optional arguments in argument list of swap cannot be saved automatically with the attribute SAVE.
!       Therefore, each time allocation is needed and basic information must be set again

   if (task < 30) fromswap%ierrorcode = 0

!  use tasks 11-19 to handle initial aspects
   if (task == 11) then
      ! some error checking
      if (swetr /= 0) then
         fromswap%ierrorcode = -1
         call swap_warning ('handle_exchange', 'SWETR /= 0')
      end if
      if (swdivide /= 1) then
         fromswap%ierrorcode = -2
         call swap_warning ('handle_exchange', 'SWDIVIDE /= 1')
      end if
      if (swmetdetail /= 0) then
         fromswap%ierrorcode = -3
         call swap_warning ('handle_exchange', 'SWMETDETAIL /= 0')
      end if
      if (swrain /= 0) then
         fromswap%ierrorcode = -4
         call swap_warning ('handle_exchange', 'SWRAIN /= 0')
      end if
      if (sw_inter /= 0) then
         fromswap%ierrorcode = -5
         call swap_warning ('handle_exchange', 'SWINTER /= 0')
      end if
      if (swsnow /= 0) then
         fromswap%ierrorcode = -6
         call swap_warning ('handle_exchange', 'SWSNOW /= 0')
      end if
!      if (swrain /= 0 .AND. swrain /= 2) then
!         fromswap%ierrorcode = -4
!         call swap_warning ('handle_exchange', 'SWRAIN /= 0 .AND. SWRAIN /= 2')
!      end if

      call fill_out()
      tlast = 0.0d0
   end if

!  use tasks 21-29 to handle dynamic aspects
   if (task == 21) then
      Tstart = toswap%tstart
      Tend   = toswap%tend

      ! check
      if (tlast > 0.0d0 .AND. dabs(tstart - tlast) > 1.0d-8) then
         fromswap%ierrorcode = 1
         call swap_warning ('handle_exchange', 'Unexpected timing error: TSTART /= TLAST')
      end if
      if (dabs(Tend - Tstart) > 1.0d-8) then
         fromswap%ierrorcode = 2
         call swap_warning ('handle_exchange', 'Only single day allowed: TEND must equal TSTART')
      end if

      ! need to re-initialize
      flrunend   = .FALSE.
      flDayStart = .TRUE.

      ! first set iyear for proper use in TimeControl; this allows for start any time, irrespective of tstart in swap.swp
      call dtdpar (Tstart, datea, fsec)
      iyear = datea(1)
      call TimeControl(1)

   end if

   ! set some weather records
   if (task == 22) then
      ! meteo data
      rad  = toswap%rad*1000.0d0               ! Convert radiation from kJ/m2/d to J/m2/d
      tmn  = toswap%tmin                       ! deg. C
      tmx  = toswap%tmax                       ! deg. C
      hum  = toswap%hum                        ! kPa
      win  = toswap%wind                       ! m/s
      graidt = toswap%rain*0.1d0                 ! from mm/d to cm/d
      nraidt = graidt
      etr  = toswap%etref*0.1d0                ! from mm/d to cm/d

      ! extra
      tav  = (tmx+tmn)*0.5d0
      tavd = (tmx+tav)*0.5d0
      ! swsnow mnust be zero (?)
      fprecnosnow = 1.d0

      ! irrigation
      flirrigate = .false.
      schedule = 0                     ! no scheduled irrigation
      swirfix  = int(toswap%swirfix)
      if (swirfix == 0) then
         ! for safety
         gird         = 0.0d0
         nirri        = 1
         dt_irr_event = 1.0d0
      else
         irdate       = toswap%irdate
         irrate       = toswap%irdepth*0.1d0         ! from mm/d to cm/d
         irdepth      = irrate
         irtype       = int(toswap%irtype)
         nirri        = 1
         irconc       = 0.0d0
         flirrigate   = .true.
         dt_irr_event = 1.0d0
      end if

      swssdi = int(toswap%swssdi)
      if (swssdi == 0) then
         ! for safety
         gird         = 0.0d0
         nirri        = 1
         dt_irr_event = 1.0d0
      else
         irdate       = toswap%ssdi_date
         irrate       = toswap%ssdi_rate_f*0.1d0*24.0d0       ! from mm/h to cm/d
         irdepth      = toswap%ssdi_amount_f*0.1d0            ! from mm   to cm
         nod_ssdi     = int(toswap%ssdi_node)
         nirri        = 1
         flirrigate   = .true.
         if (irdepth(1) > irrate(1)) then
            call swap_warning('irrigation', 'irdepth/irrate > 1.0d0; irrate temporarily adapted')
            irrate       = irdepth
            dt_irr_event = 1.0d0
         else
            dt_irr_event = irdepth(1)/irrate(1)
         end if
         call TimeControl(9)
      end if

   end if

   ! set some crop status vars
   if (task == 23) then
      lai = toswap%lai                                ! m2/m2
      ch  = toswap%ch                                 ! cm
      rd  = toswap%zroot                              ! cm

      ! set crop status
      fl_cropcalendar = toswap%icrop /= 0
      fl_cropemergence = toswap%icrop /= 0
      fl_cropharvest = toswap%icrop == 0

   end if

   ! force PTRANS and PEVAP
   if (task == 24) then
      if (toswap%ipet == 1) then
         ptra_dry = 0.1d0 * toswap%ptrans            ! from mm/d to cm/d
         ptra     = ptra_dry
         ptra_wet = 0.0d0
         aintc    = 0.0d0
         wfrac    = 0.0d0
         peva     = 0.1d0 * toswap%pevap             ! from mm/d to cm/d
         ! hoe hier mee om te gaan?
         empreva  = peva
         epond    = peva
         call reduceva(toswap%rain*0.1d0)
      end if
   end if

   if (task == 29) then
      call fill_out()
      tlast = t1900
   end if

!  use tasks 31-39 to handle closure aspects
   if (task == 31) then
   end if

!  set return flerror
   flError = .FALSE.
   if (task < 30) flError = fromswap%iErrorCode /= 0

   end subroutine handle_exchange

   subroutine fill_out()
      use MOD_grid,              only : numnod, dz
      use MOD_integral,          only: inq, inqrot, iptra, iqrot, iepd, ipeva, ievap, inqdra
      use variables,             only: Tstart, Tend, h, theta, gwl
      use MOD_integral,          only: igird, iqssdi
      use MOD_SoilTemperature,   only: tsoil
      
      fromswap%tstart          = Tstart
      fromswap%tend            = Tend
      fromswap%numnodes        = numnod
      fromswap%tpot            = iptra
      fromswap%tact            = iqrot
      fromswap%epot            = ipeva
      fromswap%eact            = ievap+iepd
      fromswap%gwl             = gwl
      fromswap%dz(1:numnod)    = dz(1:numnod)
      fromswap%h(1:numnod)     = h(1:numnod)
      fromswap%wc(1:numnod)    = theta(1:numnod)
      fromswap%rwu(1:numnod)   = inqrot(1:numnod)
      fromswap%tsoil(1:numnod) = tsoil(1:numnod)
      fromswap%q(1:numnod)     = inq(1:numnod)
      fromswap%qdra(1:numnod)  = inqdra(1, 1:numnod) + inqdra(2, 1:numnod) + inqdra(3, 1:numnod) + inqdra(4, 1:numnod) + inqdra(5, 1:numnod)
      !if (.NOT.allocated(fromswap%dz))  allocate(fromswap%dz(numnod));  fromswap%dz(1:numnod)  = dz(1:numnod)
      !if (.NOT.allocated(fromswap%wc))  allocate(fromswap%wc(numnod));  fromswap%wc(1:numnod)  = theta(1:numnod)
      !if (.NOT.allocated(fromswap%rwu)) allocate(fromswap%rwu(numnod)); fromswap%rwu(1:numnod) = 0.0d0
      fromswap%igird           = igird
      fromswap%iqssdi          = iqssdi
   end subroutine fill_out

   end subroutine swap


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
   subroutine SWAP(iCaller, iTask, tstart_in, tend_in, swp_file, outfile, toswap, fromswap, worker)
      use swap_exchange
      use MOD_arrays, only: fillen
      use mod_a23bu_worker_execution_context, only: a23bu_worker_context_t
      integer,                intent(in)              :: iCaller, iTask
      real(8),                intent(inout)           :: tstart_in, tend_in
      character(len=fillen),  intent(in),    optional :: swp_file
      character(len=fillen),  intent(in),    optional :: outfile
      type(swap_input),       intent(in),    optional :: toswap
      type(swap_output),      intent(out),   optional :: fromswap
      type(a23bu_worker_context_t), intent(inout), optional :: worker
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
subroutine SWAP(iCaller, iTask, tstart_in, tend_in, swp_file, outfile, toswap, fromswap, worker) 

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
use mod_a23bu_worker_execution_context, only: a23bu_worker_context_t
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
type(a23bu_worker_context_t), intent(inout), optional :: worker

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

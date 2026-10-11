      use mod_a23bu_worker_execution_context, only: a23bu_worker_context_t
      use mod_b1_10_trial_mass, only: b1_10_trial_mass_t
      use mod_b1_10_interval_seam, only: b1_10_interval_seam_t
      integer,                intent(in)              :: iCaller, iTask
      real(8),                intent(inout)           :: tstart_in, tend_in
      character(len=fillen),  intent(in),    optional :: swp_file
      character(len=fillen),  intent(in),    optional :: outfile
      type(swap_input),       intent(in),    optional :: toswap
      type(swap_output),      intent(out),   optional :: fromswap
      type(a23bu_worker_context_t), intent(inout), optional :: worker
      type(b1_10_trial_mass_t), intent(inout), optional :: trial_mass
      type(b1_10_interval_seam_t), intent(inout), optional :: interval
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
subroutine SWAP(iCaller, iTask, tstart_in, tend_in, swp_file, outfile, toswap, fromswap, worker, trial_mass, interval) 

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
use mod_b1_10_trial_mass, only: b1_10_trial_mass_t
use mod_b1_10_interval_seam, only: b1_10_interval_seam_t, b1_10_interval_valid, B1_10_INTERVAL_TIME_TOL

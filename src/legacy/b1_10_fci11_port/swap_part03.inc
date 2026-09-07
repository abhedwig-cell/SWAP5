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
interface
   subroutine TimeControl(task, interval)
      use mod_b1_10_interval_seam, only: b1_10_interval_seam_t
      integer, intent(in) :: task
      type(b1_10_interval_seam_t), intent(inout), optional :: interval
   end subroutine TimeControl
end interface

! global
integer,                intent(in)              :: iCaller, iTask
real(8),                intent(inout)           :: tstart_in, tend_in
character(len=fillen),  intent(in),    optional :: swp_file
character(len=fillen),  intent(in),    optional :: outfile
type(swap_input),       intent(in),    optional :: toswap
type(swap_output),      intent(out),   optional :: fromswap
type(a23bu_worker_context_t), intent(inout), optional :: worker
type(b1_10_trial_mass_t), intent(inout), optional :: trial_mass
type(b1_10_interval_seam_t), intent(inout), optional :: interval

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
   call call_timecontrol(1)

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
   call SoilWater(1, worker)
   if (sw_multi_swap == 0) call calcgwl()
   
!  initialize SoilTemperature rate/state variables
   if (swhea > 0) call SoilTemperature(1)
   if (swhea == 0) tsoil = dble(DefaultTemperature)

!  initialize drainage variables

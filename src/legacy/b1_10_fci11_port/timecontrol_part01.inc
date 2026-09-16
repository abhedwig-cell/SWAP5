module MOD_timer
! local, must save
   real(8), save :: tcumold
end module MOD_timer

! File VersionID:
!   $Id: timecontrol.f90 374 2018-03-21 13:12:23Z heine003 $
! ----------------------------------------------------------------------
   subroutine TimeControl(task, interval)
! ----------------------------------------------------------------------
!     Date               : Aug 2004   
!     Purpose            : Handles time variables, switches and flags
! ----------------------------------------------------------------------

   use MOD_timer
   use MOD_swap_base,   only: project, swscre, swmacro, swsolve, fl_initialize, swirfix, swinco, swrain, swmetdetail, swrunon
   use MOD_meteo,       only: fl_update_meteo, meteo_rec, i_metdetail, rain_rec, raintim, dt_meteo
   use MOD_runon,       only: runon_rec, runontim
   use MOD_swap_mp,     only: fldecmprat
   use plant_interface, only: sw_inter, dt_interc_event
   use MOD_irrigation,  only: irrigation, flheadirg, flirrigate, nirri, dt_irr_event
   use mod_b1_10_interval_seam, only: b1_10_interval_seam_t, B1_10_INTERVAL_TIME_TOL
   
   use variables,       only: fldecdt, flrunend, fldaystart, fldtmin, flzerointr, flzerocumu, floutput, flheader,                            &
                              flbaloutput, nprintday, flprintdt, flprintshort, period, isteps, ioutdat,                                      &
                              ioutdatint, cntper, outper, nprintcount, t1900, tstart, iyear, t, tcum, daynr, daycum,                         &
                              imonth, date, tend, dt, dtold, msteps, dtmin, dtmax, swheader, swres, fldayend, numbit, maxit,                 &
                              floutputshort, outdatint, outdat,numbit_crit, fact_dt_increase, fact_dt_decrease, fact_dt_fldect, timjan1

   implicit none
! ----------------------------------------------------------------------
!     DAYNR  : = daynumber relative to start of calendar year
!     DAYCUM : = daynumber relative to start of simulation
!     DAYMETEO: = day number for which meteorological data should be read
!     IMONTH : = actual month number
!     IYEAR  : = actual year
!
!     T      : = time relative to start of calendar year
!     TCUM   : = time relative to start of simulation
!     TEND   : = time (relative to 1900) at which simulation ends
!     TSTART : = time (relative to 1900) at which simulation starts
!     t1900  : = time relative to 1900
!
!     flCultivate : = true if crops are grown on the soil profile
!     flDayEnd : = true if time level equals end of day
!     flRunEnd : = true if time level equals TEND
!     flRunStart  : = true if time level equals TSTART
! ----------------------------------------------------------------------

!  global
   integer, intent(in) :: task
   type(b1_10_interval_seam_t), intent(inout), optional :: interval

!  local, need to save

! local
   character(len=200)   :: message
   character(len=11)    :: tmp
   character(len=80)    :: filtext

! local, no need to save
   integer              :: iyear_old
   integer              :: datea(6)
   real(4)              :: fsec
   real(8)              :: dtEvent
   real(8)              :: intervalRemaining
   logical              :: intervalActive
!  critical time-interval 

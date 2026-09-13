            ioutdat     = ioutdat + 1
         end if

! ---    reset flags for next day
         fldtmin = .FALSE.

! ---    reset counters for next day
         isteps = 0

! ---    end of run?
         if (.NOT.intervalActive) then
            if ((nint(tend) - nint(t1900) + 1) == 0) then
               flRunEnd    = .TRUE.
               floutput    = .TRUE.
               flbaloutput = .TRUE.
            end if
         end if
         t1900 = dble(nint(t1900))

      end if

      return

   case (4)

      ! === reduce time step ===
      
      ! special: decrease time step if interception storage reaches maximum level or becomes empty (SWINTER=3)
      if (sw_inter == 3 .AND. dt_interc_event < 1.0d0) dt = min(dt, dt_interc_event)

      return
      
   case (5)

      ! === reduce time step ===

      ! decrease in case of no convergence in headcalc
      if (fldecdt) then
         if (dt > fact_dt_fldect*dtmin) then
            dt = dt / fact_dt_fldect
!           force dt to equal multiple dtmin to prevent very small dt-values at end of day 
!            dt = dtmin * dble(max(1,int(dt/dtmin)))
         else
            dt = dtmin
            fldtmin = .TRUE.
         end if
         fldecdt = .FALSE.
         return
      end if

      ! decrease in case of Macropores
      if (swmacro == 1 .AND. FlDecMpRat) then
         dt = dsqrt(dtmin*dtmax)
         return
      end if

   case (9)
!     special: at end of day, the possible initial time step for next day may be too large: adapt if necessary
      if (dt_irr_event < 1.0d0) dt = min(dt, dt_irr_event)
      
      return

   case default
      call swap_error ('timecontrol', 'Illegal value for TASK')
   end select

   return

   contains

   function get_dtevent()
      
      implicit none
      ! global
      real(8) :: get_dtevent
      ! local
      real(8) :: dtEventEOD, dtEventPrint, dtEventRain, dtEventSSDI, dtEventRunon

      ! 2.7.1  remaining part of a day
      dtEventEOD = dt
      if (tcum+dtCrit < 1.0d0) dtEventEOD = 1.0d0 - tcum

      ! 2.7.2  printing more than one times a day may limit timestep
      dtEventPrint = 1.0d0/dble(nprintday)
      if (flprintshort .AND. .NOT. flprintdt) then
         dtEventPrint = (tstart - t1900) + dble(nprintcount) / dble(nprintday)
         if (dtEventPrint < dtcrit) dtEventPrint = (tstart - t1900) + dble(nprintcount + 1) / dble(nprintday)  !dtmax
      end if
      get_dtEvent = min(dtEventEOD, dtEventPrint)

      ! F-CI11: physical interval end is an independent event boundary.
      if (intervalActive) then
         if (interval%prepared .AND. .NOT.interval%complete) then
            intervalRemaining = interval%t1 - t1900
            if (intervalRemaining <= B1_10_INTERVAL_TIME_TOL) &
               call swap_error('timecontrol', 'generic interval has no positive remaining duration')
            get_dtEvent = min(get_dtEvent, intervalRemaining)
         end if
      end if

      ! 2.7.3  input of detailed meteo may limit timestep
      if (swmetdetail == 1) then
         dtEventRain = dble(int(t + dtCrit)) - t + dble(i_metdetail) * dt_meteo
         if (dtEventRain < dtCrit) then
            ! update actual weather record
            fl_update_meteo = .true.
            i_metdetail = i_metdetail + 1

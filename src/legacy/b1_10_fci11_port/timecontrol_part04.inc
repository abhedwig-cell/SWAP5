            call swap_error('timecontrol(3)', 'generic interval end was overshot')
         if (intervalRemaining <= B1_10_INTERVAL_TIME_TOL) then
            flRunEnd = .TRUE.
            interval%complete = .TRUE.
         else
            flRunEnd = .FALSE.
         end if
      end if

! 2.9 determine next time step, based on numerical performance
      if (swsolve == 1) then
         if (numbit <= numbit_crit) dt = min(dt*fact_dt_increase,dtMax)
         if (numbit >= MaxIt)       dt = max(dt*fact_dt_decrease,dtMin)
         if (dt < dtmin) then
            dt = dtmin
            fldtmin = .TRUE.
         end if
      else
         dt = 1.0d0
      end if

! 2.7  maximum size of time interval (dtEvent)
      dtEvent = get_dtevent()
      if (dt > dtevent) then
         dt = dtevent
         if (swsolve == 2 .AND. dabs(dtevent - 1.0d0) > dtCrit ) call swap_error('timecontrol(3)', 'swsolve = 2: unexpected: dtevent < 1.0d0')
      end if

! 2.11 set flags and variables

! --- in case of output during a day
      if (flprintshort) then
         floutputshort = .FALSE.
         flzerointr    = .FALSE.
! ---    determine whether output is required
         if (flprintdt) then 
            outper  = tcum - tcumold
            tcumold = tcum
            if (abs(outdatint(ioutdatint) - t1900 + 1.d0) < 1.d-3) then
               floutputshort = .TRUE.
               flzerointr    = .TRUE.
            end if
         else
            if (t1900 - tstart + dtCrit > dble(nprintcount)/dble(nprintday)) then
               floutputshort = .TRUE.
               flzerointr    = .TRUE.
               outper        = 1.0d0 / dble(nprintday)
               tcumold       = tcum
               ! update nprint counter
               nprintcount   = nprintcount + 1
            end if
         end if
      end if

!     SSDI: end of subsurface irrigation event reached; reset
      if (tcum - int(tcum) + dtCrit > dt_irr_event) call irrigation(9)

! --- update fldtmin
      if (dt > (1.0d0+dtCrit)*dtmin) fldtmin = .FALSE.

! --- procedure when day is finished ---------------------------------------------- 
      if (flDayEnd) then

! ---    length output period
         if (.NOT.flprintshort) outper = outper + 1.0d0

! ---    write daynumber to screen
         if (swscre == 2) write(*,'("+ ",4x,a11,i6,i8)') date,daynr,daycum

! ---   in case no end of run, determine whether today output should be written 
         if (cntper == period .AND. .NOT.flprintdt) then
            cntper     = 0
            floutput   = .TRUE.
            flzerointr = .TRUE.
         end if

         if (flprintdt) then
            if (abs(outdatint(ioutdatint) - t1900 + dt) < 1.d-3) then
               floutput   = .TRUE.
               flzerointr = .TRUE.
               ioutdatint = ioutdatint + 1
            end if
         else
            if (abs(outdatint(ioutdatint) - t1900 + 1.d0) < 1.d-3) then
               floutput   = .TRUE.
               flzerointr = .TRUE.
               ioutdatint = ioutdatint + 1
            end if
         end if

         if (abs(outdat(ioutdat) - t1900 + 1.d0) < 1.d-3) then
! ---       output of water and solute balances
            floutput    = .TRUE.
            flbaloutput = .TRUE.
            flzerointr  = .TRUE.
            flzerocumu  = .TRUE.

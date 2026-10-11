      ! determine year,month and day number (only during first time step of a day)
      call dtdpar (t1900+0.1d0, datea, fsec)
      iyear_old = iyear
      iyear = datea(1)
      imonth = datea(2)
      ! determine date of current day
      call dtdpst ('year-month-day', t1900+0.1d0, date)

      ! update day numbers
      daynr = daynr  + 1
      daycum = daycum + 1
      cntper = cntper + 1  ! only used in timecontrol

      ! update meteo record
      fl_update_meteo = .true.
      meteo_rec = meteo_rec + 1
      if (swmetdetail == 1) i_metdetail = 1

      ! in case of a new year         
      if (iyear /= iyear_old) then

         ! reset daynumber and time because new calender year has started
         daynr = 1
         t = 0.0d0

         ! update time first of January: timjan1
         datea = 0; datea(1) = iyear; datea(2) = 1; datea(3) = 1
         call dtardp (datea, 0.0, timjan1)
            
         ! in case SWRES = 1 reset counter for periodic output to 1
         if (swres == 1 .AND. period /= 0) cntper = 1
      end if
      
      ! set timestep
      if (swsolve == 1) then
         dt = max(dt, dsqrt(dtmin*dtmax))
      else
         dt = 1.d0
      end if

      ! maximum size of time interval (dtEvent)
      dtEvent = get_dtevent()
      if (dt+dtCrit > dtEvent) then
         dt = dtEvent
         if (swsolve == 2 .AND. dabs(dtevent - 1.0d0) > dtCrit ) call swap_error('timecontrol(1)', 'swsolve = 2: unexpected: dtevent < 1.0d0')
      end if

      return

   ! DYNAMIC
   case (3)
! === next time step ===================================================
! 2.1  check maximum number of time steps during this day
      isteps = isteps + 1
      if (isteps > msteps) then
        write(tmp,'(i11)') daynr
        message ='The maximum number of time steps for a day is exceeded at daynumber '//trim(adjustl(tmp))//'. Check input for numerical solution of Richards equation'
        call swap_error ('timecontrol', message)
      end if

! 2.2 update time variables
      tcum = tcum  + dt
      t1900 = t1900 + dt
      t = t1900 - timjan1

! 2.3  flag assignments after first time step of a day
      if (flDayStart) then

! ---    set flags for reset intermediate and cumulative fluxes
         flZeroCumu = .FALSE.
         if (flZeroIntr) then
            outper = 0.0d0
            flZeroIntr = .FALSE.
         end if

! ---    set flags for output
         if (floutput) then
            floutput = .FALSE.
            flheader = swheader == 1
         end if
         if (flbaloutput) then
            flbaloutput = .FALSE.
            flheader = swheader == 1
            flheadirg = swheader == 1
         end if

      end if

! 2.6  update logicals for indication of start / end of day; retrun at end-of-day
      if (1.d0 - tcum > dtCrit) then 
         flDayEnd = .FALSE.
         flDayStart = .FALSE.
      else
         flDayEnd = .TRUE.
         flDayStart = .TRUE.
      end if

! --- F-CI11 generic execution interval is independent from calendar day boundaries.
      if (intervalActive) then
         if (.NOT.interval%prepared) call swap_error('timecontrol(3)', 'generic interval is not prepared')
         intervalRemaining = interval%t1 - t1900
         if (intervalRemaining < -B1_10_INTERVAL_TIME_TOL) &

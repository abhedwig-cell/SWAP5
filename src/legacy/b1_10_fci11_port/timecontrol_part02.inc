   real(8), parameter   :: dtCrit = 1.0d-8     ! approximately 1 millisecond

   intervalActive = .FALSE.
   if (present(interval)) intervalActive = interval%active

   select case (task)

   case (1)

! === initialization ===================================================

! --- initialize flags ----------------------------
      fldecdt = .FALSE.
      flRunEnd = .FALSE.
      flDayStart = .TRUE.
      fldtmin = .FALSE.
      flZeroIntr = .TRUE.
      flZeroCumu = .TRUE.
      floutput = .FALSE.
      flbaloutput = .FALSE.
      flheader = .FALSE.
      flheadirg = .FALSE.
      flprintshort = .FALSE.
      if (nprintday > 1 .OR. flprintdt) then
         flprintshort = .TRUE.
         period = 1
      end if
      flIrrigate = swirfix == 1

! --- initialize counters ----------------------------
      nirri = 1
      isteps = 0
      ioutdat = 1
      ioutdatint = 1
      cntper = 0
      outper = 0.0d0
      tcumold = 0.0d0
      nprintcount = 1

! --- set main time variable of SWAP ------------------------
      t1900 = tstart

      ! determine time from beginning of calendar year
      call dtdpar (t1900 + 0.1d0, datea, fsec)
      datea = 0; datea(1) = iyear; datea(2) = 1; datea(3) = 1
      call dtardp (datea,0.0,timjan1)

      t = tstart - timjan1
      tcum = 0.d0
      daynr = nint(t)
      daycum = 0

! --- determine year,month and day number of current day
      call dtdpar (t1900+0.1d0, datea, fsec)
      iyear = datea(1)
      imonth = datea(2)

! --- determine date of current day
      call dtdpst ('year-month-day', t1900+0.1d0, date)

! --- output to screen
      if (swscre == 2) then
         filtext = 'Screen output of daynumbers'
         call writehead (5,1,'screen',filtext,project)
         call dtdpst ('year-month-day',tstart,date)
         write (*,'(2x,2a)') 'First day of simulation:  ', date
         call dtdpst ('year-month-day',tend,date)
         write (*,'(2x,2a)') 'Last day of simulation:   ', date
         write (*,'(/,a,/)') '            date  daynr  daycum'
      end if

!     dtmax should not be larger then 1/nprintday or dt_meteo; for safety; dtmin should not be larger than dtmax
      dtmax = min(dtmax, 1.0d0/dble(nprintday))
      if (swmetdetail == 1) dtmax = min(dtmax, dt_meteo)
      dtmin = min(dtmin, 0.1d0*dtmax)                                ! better to have dtmin different from dtmax

! --- initial time step
      if (swsolve == 1) then
         if (fl_initialize) then
            if (dt < dtmin) then
               message = 'Initial dt read from file (SWINCO=3) if absent, then default is assumed'
               call swap_warning ('timecontrol', message)
               dt = dsqrt(dtmin*dtmax)
            end if
         else
            if (swinco /= 3) dt = dsqrt(dtmin*dtmax)
         end if
      else
         dt = 1.0d0
      end if

! --- initialize
      dtEvent = get_dtevent()
      if (dt+dtCrit > dtEvent) then
         dt = dtEvent
         if (swsolve == 2 .AND. dabs(dtevent - 1.0d0) > dtCrit ) call swap_error('timecontrol(1)', 'swsolve = 2: unexpected: dtevent < 1.0d0')
      end if

! --- set value for dtold, used in headcalc for macropore-iteration
      dtold = dt

      return

   ! START OF DAY
   case (2)

      ! start of day; time 00:00:00  
      tcum = 0.d0


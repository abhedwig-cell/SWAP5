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
         call call_timecontrol(9)

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
         call call_timecontrol(4)
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
         if (.NOT.fldecdt) call SoilWater(2, worker)

!        F-CI13: a canonical trial must not continue from the legacy terminal
!        non-converged minimum-dt route. HeadCalc records that route by
!        incrementing worker%history%iwarn. Standalone execution has no worker
!        and therefore retains the qualified legacy continuation behaviour.
         if (present(worker)) then
            if (worker%history%iwarn > 0) then
               call SoilWaterStateVar(2)
               return
            end if
         end if

!        calculate surface water balance
         if (swdra == 2)   call drain(3)

!        update time variables and switches/flags
         if (fldecdt .OR. (swmacro == 1 .AND. FlDecMpRat)) then
            call SoilWaterStateVar(2)
            if (swmacro == 1) call MacroStateVar(2)
            call call_timecontrol(5)
            fldtreduce = .TRUE.
         end if

      end do

!     calculate SoilWater rate/state variables
      call SoilWater(3, worker)

!     update time-integrated vars (mainly used for output)
      call integral(3, trial_mass)

!     calculate SoilTemperature rate/state variables
      if (swhea > 0) call SoilTemperature(2)

!     calculate Solute rate/state variables
      if (swsolu > 0) call Solute(2)

!     update time variables and switches/flags
      call call_timecontrol(3)

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

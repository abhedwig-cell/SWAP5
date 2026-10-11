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
   call SoilWater(1, worker)
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
   if (.NOT.present(worker)) then
      call SwapOutput(1)
      call SoilWaterOutput(1)
      if (swmacro == 1) call MacroPoreOutput(1)
   end if

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
   call SoilWater(1, worker)
   if (swhea > 0) call SoilTemperature(1)
   if (present(outfile)) outfil = outfile
!  open Output files and write headers
   if (.NOT.present(worker)) then
      call SwapOutput(1)
      call SoilWaterOutput(1)
   end if
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
   call SoilWater(1, worker)
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
         if (.NOT.fldecdt) call SoilWater(2, worker)

!        calculate surface water balance
         if (swdra == 2)   call drain(3)

!        update time variables and switches/flags
         if (fldecdt .OR. (swmacro == 1 .AND. FlDecMpRat)) then
            call SoilWaterStateVar(2)
            if (swmacro == 1) call MacroStateVar(2)

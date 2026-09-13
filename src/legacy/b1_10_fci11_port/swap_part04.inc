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
!   call call_timecontrol(1)
   
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

if (iTask == 22) then
   ! F-CI11: prepare a generic physical execution interval without changing
   ! calendar-day continuation state. Used only by the canonical adapter path.
   if (.NOT.present(interval)) call swap_error('swap', 'F-CI11 interval argument missing for task 22')
   if (.NOT.b1_10_interval_valid(interval)) call swap_error('swap', 'F-CI11 invalid generic interval')
   if (dabs(t1900 - interval%t0) > B1_10_INTERVAL_TIME_TOL) &
      call swap_error('swap', 'F-CI11 interval t0 does not match committed physical time')
   interval%prepared = .TRUE.
   interval%complete = .FALSE.
   flrunend = .FALSE.
   tstart_in = interval%t0
   tend_in = interval%t1
   return
end if

if (iTask == 2) then

   if (present(interval)) then
      if (.NOT.interval%prepared) call swap_error('swap', 'F-CI11 generic interval not prepared before dynamic execution')
      if (dabs(t1900 - interval%t0) > B1_10_INTERVAL_TIME_TOL) &
         call swap_error('swap', 'F-CI11 dynamic start does not match interval t0')
   end if

!  Specific for exchange when called as DLL
   if (iCaller == 2) call handle_exchange(21, flError); if (flError) return

!  loop with soil water time step during entire simulation period
   do while (.NOT.flrunend)

      if (flDayStart) then

         ! set time at start of day
         call call_timecontrol(2)

         if (iCaller /= 2) then
!           process weather data for current day
            call Meteo(2)
         else
!           Specific for exchange when called as DLL

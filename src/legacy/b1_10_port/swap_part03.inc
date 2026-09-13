            call TimeControl(5)
            fldtreduce = .TRUE.
         end if

      end do

!     calculate SoilWater rate/state variables
      call SoilWater(3, worker)

!     update time-integrated vars (mainly used for output)
      call integral(3)

!     calculate SoilTemperature rate/state variables
      if (swhea > 0) call SoilTemperature(2)

!     calculate Solute rate/state variables
      if (swsolu > 0) call Solute(2)

!     update time variables and switches/flags
      call TimeControl(3)

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
         if (iCaller /= 2 .AND. swcrop == 1 .AND. fl_cropemergence) call cropdevelopment (3)
         
!        Simulate Soil Nutrient processes
         if (swcropsnm == 1) call Soilmanagement(4)
         
!DEC$ IF DEFINED (with_animo)
         ! call ANIMO
         if (sw_animo == 1) then
            call fill_ta(iTask)
            call animo(iTask, juda, judami, judama)
            N_demand = ta%nutr%Ndemand
            N_actual = ta%nutr%Nuptake
            !write(990,'(5F15.5)') t1900, NdemandSoil, NsupplySoil, N_demand * 1.0d4, N_actual * 1.0d4
            NsupplySoil = max(0.0d0, (N_actual - N_actual_old) * 1.0d4)
            N_actual_old = N_actual
         end if
!DEC$ END IF

!        harvest of crop; this is skipped in case called externally
         fl_cropharvestday = .FALSE.
         if (iCaller /= 2 .AND. swcrop == 1 .AND. fl_cropemergence) call cropdevelopment (4)

!        update time-integrated vars depending on crop status (mainly used for output)
         call integral (4)

         
!        timing statistics : prevent (near) endless simulations
         if (flMaxIterTime) call IterTime(2)

      end if

!     output section (write to standard files and to optional files)
      if (.NOT.present(worker)) then
         if (flOutput) then
            call SwapOutput(2)
            call SoilWaterOutput(2)
            if (swtill == 1)     call DoTillage(3)
            if (swsolu > 0)      call Solute(3)
            if (swmacro == 1)    call MacroPoreOutput(2)
         else
            if (flOutputShort)   call SoilWaterOutput(2)
         end if
      end if
      if (flDayEnd) then
         if (swcropsnm == 1) call Soilmanagement(6)
         if (.NOT.present(worker) .AND. sw_end == 2) call soilwateroutput(3)
         if (fl_cropharvest) call reset_crop()

!        calculate Irrigation rate/state variables
         if (sw_multi_swap == 1) then
            if (flIrrigate) call Irrigation(3)
            !if (i_instance == 1) write(500+i_core,'(2A,2F15.6)') ' dayend   ', date, t1900, gird
         end if

      end if

   end do

!  Specific for exchange when called as DLL
   if (iCaller == 2) call handle_exchange(29, flError)

   return
end if

!****************************************************************************************************************************
!*****   C L O S U R E   *****
!****************************************************************************************************************************
if (iTask == 3) then

   !  delete temporary files
   !call CloseTempFil


   !  iteration and timing statistics
   !call IterTime(3)

!  close output files
   call SwapOutput(3)
   if (sw_end == 1) call SoilWaterOutput(3)
   call SoilWaterOutput(4)
   if (swsolu > 0)           call Solute(9)
   if (swmacro == 1)         call MacroPoreOutput(3)
   if (swcropsnm == 1)       call Soilmanagement(7)

!DEC$ IF DEFINED (with_animo)
   if (sw_animo == 1) call animo(iTask, juda, judami, judama)
!DEC$ END IF

   ! write okay file for external use
   call swap_ok()

   ! close and delete err-file (becuase it has not been used)
   close(unit_err, status = 'delete')

!  delete temporary files
   !call CloseTempFil

!  Specific for exchange when called as DLL
   if (iCaller == 2) call handle_exchange(31, flError)

   return
end if

contains

!  routine to handle exchange with calling program
   subroutine handle_exchange(task, flError)

   use MOD_swap_base,         only: swetr, swmetdetail, swrain, swirfix, swsnow
   use plant_interface,       only: fl_cropemergence, fl_cropharvest, ch, lai, sw_inter, rd
   use MOD_meteo,             only: swdivide, epond, peva, ptra_dry, ptra, ptra_wet, reduceva, aintc, wfrac
   use MOD_meteo,             only: tmn, tmx, hum, win, etr, graidt, nraidt, tavd, fprecnosnow
   use MOD_cropdevelopment,   only: fl_cropcalendar
   use MOD_irrigation,        only: nod_ssdi, schedule, gird, nirri, irdate, irdepth, irtype, irconc, irrate, dt_irr_event
   use variables,             only: t1900, iyear, tstart, tend
   use atmosphere_interface,  only: rad, tav

   implicit none
   integer, intent(in)   :: task
   logical, intent(out)  :: flError
   ! local
   integer               :: swssdi
   integer, dimension(6) :: datea
   real                  :: fsec
   real(8), save         :: tlast

! NOTE: the optional arguments in argument list of swap cannot be saved automatically with the attribute SAVE.
!       Therefore, each time allocation is needed and basic information must be set again

   if (task < 30) fromswap%ierrorcode = 0

!  use tasks 11-19 to handle initial aspects
   if (task == 11) then
      ! some error checking
      if (swetr /= 0) then
         fromswap%ierrorcode = -1
         call swap_warning ('handle_exchange', 'SWETR /= 0')
      end if
      if (swdivide /= 1) then
         fromswap%ierrorcode = -2
         call swap_warning ('handle_exchange', 'SWDIVIDE /= 1')
      end if
      if (swmetdetail /= 0) then
         fromswap%ierrorcode = -3
         call swap_warning ('handle_exchange', 'SWMETDETAIL /= 0')
      end if
      if (swrain /= 0) then
         fromswap%ierrorcode = -4
         call swap_warning ('handle_exchange', 'SWRAIN /= 0')
      end if
      if (sw_inter /= 0) then
         fromswap%ierrorcode = -5
         call swap_warning ('handle_exchange', 'SWINTER /= 0')
      end if
      if (swsnow /= 0) then
         fromswap%ierrorcode = -6
         call swap_warning ('handle_exchange', 'SWSNOW /= 0')
      end if
!      if (swrain /= 0 .AND. swrain /= 2) then
!         fromswap%ierrorcode = -4
!         call swap_warning ('handle_exchange', 'SWRAIN /= 0 .AND. SWRAIN /= 2')
!      end if

      call fill_out()
      tlast = 0.0d0
   end if

!  use tasks 21-29 to handle dynamic aspects
   if (task == 21) then
      Tstart = toswap%tstart
      Tend   = toswap%tend

      ! check
      if (tlast > 0.0d0 .AND. dabs(tstart - tlast) > 1.0d-8) then
         fromswap%ierrorcode = 1
         call swap_warning ('handle_exchange', 'Unexpected timing error: TSTART /= TLAST')
      end if
      if (dabs(Tend - Tstart) > 1.0d-8) then
         fromswap%ierrorcode = 2
         call swap_warning ('handle_exchange', 'Only single day allowed: TEND must equal TSTART')
      end if

      ! need to re-initialize
      flrunend   = .FALSE.
      flDayStart = .TRUE.

      ! first set iyear for proper use in TimeControl; this allows for start any time, irrespective of tstart in swap.swp
      call dtdpar (Tstart, datea, fsec)
      iyear = datea(1)
      call TimeControl(1)

   end if

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
         call integral (4, trial_mass)

         
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

   subroutine call_timecontrol(task)
      integer, intent(in) :: task
      if (present(interval)) then
         call TimeControl(task, interval)
      else
         call TimeControl(task)
      end if
   end subroutine call_timecontrol

!  routine to handle exchange with calling program
   subroutine handle_exchange(task, flError)

   use MOD_swap_base,         only: swetr, swmetdetail, swrain, swirfix, swsnow
   use plant_interface,       only: fl_cropemergence, fl_cropharvest, ch, lai, sw_inter, rd

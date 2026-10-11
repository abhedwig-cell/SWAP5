            dtEventRain = dble(int(t + dtCrit)) - t + dble(i_metdetail) * dt_meteo
         end if
         get_dtEvent = min(get_dtEvent, dtEventRain)
      else

         ! 2.7.4 precipitation event may limit timestep
         if (swmetdetail == 0 .AND. swrain > 0) then
            dtEventRain = raintim(rain_rec) - t1900
            if (dtEventRain < dtcrit) then
               ! new rain event valid
               rain_rec = rain_rec + 1
               dtEventRain = raintim(rain_rec) - t1900
            end if
            get_dtEvent = min(get_dtEvent, dtEventRain)
         end if
      end if

      ! 2.7.5 SSDI: adapt dt as to not pass dt_irr_event
      if (dt_irr_event < 1.0d0) then
         dtEventSSDI = dble(int(tcum) + dt_irr_event) - tcum
         if (dtEventSSDI < dtCrit) dtEventSSDI = dtmax
         get_dtEvent = min(get_dtEvent, dtEventSSDI)
      end if

      ! 2.7.6 RUNON event may limit timestep
      if (swrunon == 1) then
         dtEventRunon = runontim(runon_rec) - t1900
         if (dtEventRunon < dtcrit) then
            ! new runon event valid
            runon_rec = runon_rec + 1
            dtEventRunon = runontim(runon_rec) - t1900
         end if
         get_dtEvent = min(get_dtEvent, dtEventRunon)
      end if
      
   end function get_dtevent

   end subroutine TimeControl

   subroutine IterTime(task)
! ----------------------------------------------------------------------
!     date    : 20080303
!     update  : 20170223: intro part2 - to interrupt (near) endless simulations
!     purpose : statistics of timing and numerical iterations
! ----------------------------------------------------------------------
! --- global variables
      use MOD_swap_base, only: unit_log
      use variables,     only: maxitertime, maxit, itnumb
      implicit none
      integer, intent(in)  :: task
! --- local variables
      integer              :: i, j, timediff
      character(len=400)   :: message
      real(4)              :: tmptimeinterrupt, tmptimeend
      real(4), save        :: tmptimestart

      select case (task)

      case (1)
! --- part1 - initial values
         call cpu_time(tmptimestart)

      case (2)
! --- part2 - calculate intermediate time to be able to interrupt (near) endless simulations
         call cpu_time(tmptimeinterrupt)
         timediff = int(tmptimeinterrupt-tmptimestart) - MaxIterTime
!        fatal error if cpu time exceeds input value MaxIterTime
         if (timediff > 0) then
            write(message,'(a,i10,3a)') 'The maximum cpu time of ',MaxIterTime,' (secs) was exceeded. Therefore simulation was interrupted'
            call swap_error ('IterTime', message)
         end if

      case (3)
! --- part3 - write statistics
         write(unit_log,'(/,a20)')      'Iteration statistics'
         write(unit_log,'(/,a29,i4)')   'Maximum number of iterations:',MaxIt
         write(unit_log,'(/,a35/,a35)') 'It Numb  No of Hits  Tot BTr cycles', '-------  ----------  --------------'
         do i=1,100                                       
            if (itnumb(i,1) > 0) write(unit_log,'(i7,2x,i10,4x,i10)')i,(itnumb(i,j),j=1,2)
         end do

         call cpu_time(tmptimeend)
         write(unit_log,'(/,a12,f20.8,a4)') ' Run-time: ',tmptimeend-tmptimestart,' sec'
         
      case default
         call swap_error ('IterTime', 'Illegal value for TASK')
      end select

      return
   end subroutine IterTime


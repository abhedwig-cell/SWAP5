   call rdfrom (iset,.TRUE.)

!  Initialize swap
   iTask = 1
   tstart_in = 0.0d0
   tend_in = 0.0d0
   if (iCaller == 0) call swap(iCaller, iTask, tstart_in, tend_in)
   !!!if (iCaller /= 0) call dummy(iTask)

!  Dynamic call to swap
   iTask = 2
   if (iCaller == 0) call swap(iCaller, iTask, tstart_in, tend_in)
   !!!if (iCaller /= 0) call dummy(iTask)

!  Close swap
   iTask = 3
   if (iCaller == 0) call swap(iCaller, iTask, tstart_in, tend_in)
   !!!if (iCaller /= 0) call dummy(iTask)

   !  iteration and timing statistics
   call IterTime(3)

end do
close (iun2)


! write message on screen
write(*,'(a)')' Swap normal completion!'

call CloseTempFil
write(unit_log,'(/,a)') ' Swap simulation okay!'
close(unit_log)
close(unit_wrn)

Call Exit(100)

   contains
   !!!subroutine dummy_test(iTask)
   !!!use swap_exchange
   !!!implicit none
   !!!integer, intent(in)  :: iTask
   !!!integer              :: i, itel
   !!!integer, save        :: itstart, itend
   !!!type(swap_input)     :: testin
   !!!type(swap_output)    :: testout
   !!!
   !!!select case (iTask)
   !!!case(1)
   !!!   testin%tstart = 0.0d0; testin%tend = 0.0d0
   !!!   testin%rain = 0.0d0; testin%tmin = 0.0d0; testin%tmax = 0.0d0; testin%rad = 0.0d0; testin%hum = 0.0d0; testin%wind = 0.0d0; testin%etref = 0.0d0; testin%wet = 0.0d0
   !!!   testin%icrop = 0; testin%lai = 0.0d0; testin%ch = 0.0d0; testin%zroot = 0.0d0
   !!!   call swap(iCaller, iTask, toswap = testin, fromswap = testout)
   !!!   if (testout%ierrorcode /= 0) call swap_error ('swap_main', 'error')
   !!!   itstart = nint(testout%tstart + 365.0d0)
   !!!   !itend   = nint(testout%tend   + 365.0d0)
   !!!   itend   = itstart + 365
   !!!
   !!!case(2)
   !!!   itel = 0
   !!!   do i = itstart, itend, 1
   !!!      itel = itel + 1
   !!!      testin%tstart = dble(i)
   !!!      testin%tend   = dble(i)    ! very important: if for example one day is to be considered then Tend must be equal to Tstart, since in TimeControl timing is based on Tend+1
   !!!      testin%rain   =   1.0d0    ! mm/d
   !!!      testin%tmin   =  15.0d0    ! deg. C
   !!!      testin%tmax   =  25.0d0    ! deg. C
   !!!      testin%rad    =   1.0d4    ! kJ/m2/d
   !!!      testin%hum    =   0.75d0   ! kPa
   !!!      testin%wind   =   5.0d0    ! m/s
   !!!      testin%etref  = -99.9d0    ! mm/d
   !!!      testin%wet    =   1.0d-1   ! [0...1]
   !!!
   !!!      testin%ipet   =   0
   !!!
   !!!      if (itel > 100 .AND. itel < 275) then
   !!!         testin%icrop  =   1
   !!!         testin%lai    =   2.0d0
   !!!         testin%ch     =  40.0d0
   !!!         testin%zroot  =  25.0d0

   !!!      call RDfdou('sin_etref',  sin_etref,  mdays, ndays)
   !!!      call RDfdou('sin_rad',    sin_rad,    mdays, ndays)
   !!!      call RDfdou('sin_ch',     sin_ch,     mdays, ndays); sin_ch = 0.0d0
   !!!      call RDfdou('sin_zroot',  sin_zroot,  mdays, ndays)
   !!!      call RDfdou('sin_lai',    sin_lai,    mdays, ndays)
   !!!      call RDfint('sin_icrop',  sin_icrop,  mdays, ndays)
   !!!      call RDfint('sin_ipet',   sin_ipet,   mdays, ndays)
   !!!      call RDfdou('sin_pevap',  sin_pevap,  mdays, ndays)
   !!!      call RDfdou('sin_ptrans', sin_ptrans, mdays, ndays)
   !!!   close(235)
   !!!   itstart = sin_tstart(1)
   !!!   itend   = sin_tend(ndays)
   !!!
   !!!case(2)
   !!!   itel = 0
   !!!   do i = itstart, itend, 1
   !!!      itel = itel + 1
   !!!      testin%tstart = sin_tstart(itel)
   !!!      testin%tend   = sin_tend(itel)  ! very important: if for example one day is to be considered then Tend must be equal to Tstart, since in TimeControl timing is based on Tend+1
   !!!      testin%rain   = sin_rain(itel)  ! mm/d
   !!!      testin%tmin   = sin_tmin(itel)  ! deg. C
   !!!      testin%tmax   = sin_tmax(itel)  ! deg. C
   !!!      testin%rad    = sin_rad(itel)   ! kJ/m2/d
   !!!      testin%hum    = sin_hum(itel)   ! kPa
   !!!      testin%wind   = sin_wind(itel)  ! m/s
   !!!      testin%etref  = sin_etref(itel) ! mm/d
   !!!      testin%wet    = sin_wet(itel)   ! [0...1]
   !!!
   !!!      testin%ipet   = sin_ipet(itel)
   !!!
   !!!      if (itel > 100 .AND. itel < 275) then
   !!!         testin%icrop  =  sin_icrop(itel)
   !!!         testin%lai    =  sin_lai(itel)
   !!!         testin%ch     =  sin_ch(itel)
   !!!         testin%zroot  =  sin_zroot(itel)
   !!!         testin%ptrans =  sin_ptrans(itel)
   !!!         testin%pevap  =  sin_pevap(itel)
   !!!      else
   !!!         testin%icrop  =  sin_icrop(itel)
   !!!         testin%lai    =  sin_lai(itel)
   !!!         testin%ch     =  sin_ch(itel)
   !!!         testin%zroot  =  sin_zroot(itel)
   !!!         testin%ptrans =  sin_ptrans(itel)
   !!!         testin%pevap  =  sin_pevap(itel)
   !!!      end if
   !!!      call swap(iCaller, iTask, toswap = testin, fromswap = testout)
   !!!      if (testout%ierrorcode /= 0) call swap_error ('swap_main', 'error')
   !!!      !write (*,'(i10, f8.3,i10)') i, testout%tact/testout%tpot, testout%ierrorcode
   !!!      !sout_tpot(itel) = testout%tpot
   !!!      !sout_tact(itel) = testout%tact
   !!!      !sout_gwl(itel) = testout%gwl
   !!!   end do
   !!!
   !!!case(3)
   !!!   call swap(iCaller, iTask)
   !!!   !write(345,'(i5,3F15.6)') (i, sout_tpot(i), sout_tact(i), sout_gwl(i), i = 1, ndays)
   !!!end select
   !!!
   !!!end subroutine dummy

end program swap_main


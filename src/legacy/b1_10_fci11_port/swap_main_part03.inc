   !!!         testin%ptrans =   2.0d0
   !!!         testin%pevap  =   1.0d0
   !!!      else
   !!!         testin%icrop  =   0
   !!!         testin%lai    =   0.0d0
   !!!         testin%ch     =   0.0d0
   !!!         testin%zroot  =   0.0d0
   !!!         testin%ptrans =   0.0d0
   !!!         testin%pevap  =   1.0d0
   !!!      end if
   !!!      call swap(iCaller, iTask, toswap = testin, fromswap = testout)
   !!!      if (testout%ierrorcode /= 0) call swap_error ('swap_main', 'error')
   !!!      !write (*,'(i10, f8.3,i10)') i, testout%tact/testout%tpot, testout%ierrorcode
   !!!   end do
   !!!
   !!!case(3)
   !!!   call swap(iCaller, iTask)
   !!!end select
   !!!
   !!!end subroutine dummy_test

   !!!subroutine dummy(iTask)
   !!!use swap_exchange
   !!!implicit none
   !!!integer, intent(in)  :: iTask
   !!!integer              :: i, itel
   !!!integer, save        :: itstart, itend
   !!!type(swap_input)     :: testin
   !!!type(swap_output)    :: testout
   !!!
   !!!! local
   !!!integer, parameter :: mdays = 365
   !!!integer            :: ndays
   !!!integer, dimension(mdays) :: sin_tstart, sin_tend, sin_icrop, sin_ipet
   !!!real(8), dimension(mdays) :: sin_tmin, sin_tmax, sin_hum, sin_wind, sin_rain, sin_wet, sin_etref, sin_rad, sin_ch, sin_zroot, sin_lai, sin_pevap, sin_ptrans
   !!!!real(8), dimension(mdays) :: sout_tpot, sout_tact, sout_gwl
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
   !!!   call RDinit(235, 0, 'sin.csv')
   !!!      call RDaint('sin_tstart', sin_tstart, mdays, ndays)
   !!!      call RDfint('sin_tend',   sin_tend,   mdays, ndays)
   !!!      call RDfdou('sin_tmin',   sin_tmin,   mdays, ndays)
   !!!      call RDfdou('sin_tmax',   sin_tmax,   mdays, ndays)
   !!!      call RDfdou('sin_hum',    sin_hum,    mdays, ndays)
   !!!      call RDfdou('sin_wind',   sin_wind,   mdays, ndays)
   !!!      call RDfdou('sin_rain',   sin_rain,   mdays, ndays)
   !!!      call RDfdou('sin_wet',    sin_wet,    mdays, ndays)

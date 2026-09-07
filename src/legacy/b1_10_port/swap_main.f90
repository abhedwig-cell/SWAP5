! swap_main.f90
! Marius Heinen, March 2021, WENR
!
! As of version 4.1.75, the original main (swap.f90) is split up in a main caller (this file), and
! a subroutine swap (swap.f90), which is the actual model.
! The reason is that all code, except the swap_main, can then also be used for
! preparing a DLL-version of swap, which then can be used by others.
! The model has been split into three tasks:
!    1 - initialization
!    2 - dynamic (time loop)
!    3 - closure
! Therefore, the model will be called three times in a row.

! ----------------------------------------------------------------------
program swap_main
! ----------------------------------------------------------------------

use MOD_swap_base, only: unit_log, unit_wrn, sw_animo
implicit none

! because subroutine swap has optional arguments, we must define the interface
interface
   subroutine SWAP(iCaller, iTask, tstart_in, tend_in, swp_file, outfile, toswap, fromswap, worker)
   !!!subroutine SWAP(iCaller, iTask, tstart_in, tend_in, toswap, fromswap)
      use swap_exchange
      use MOD_arrays, only: fillen
      use mod_a23bu_worker_execution_context, only: a23bu_worker_context_t
      integer,                intent(in)              :: iCaller, iTask
      real(8),                intent(inout)           :: tstart_in, tend_in
      character(len=fillen),  intent(in),    optional :: swp_file
      character(len=fillen),  intent(in),    optional :: outfile
      type(swap_input),       intent(in),    optional :: toswap
      type(swap_output),      intent(out),   optional :: fromswap
      type(a23bu_worker_context_t), intent(inout), optional :: worker
   end subroutine SWAP
end interface

! local
integer              :: iTask
integer, parameter   :: iCaller = 0                   ! Who is calling swap? 0 = swap-main; > 0 external model is calling swap as DLL (iCaller > 0 for testing only)
integer, save        :: iset, insets, iun1, iun2
real(8), save        :: tstart_in, tend_in

! functions
integer              :: getun

sw_animo = 1

! open logfile and read rerun file
iun1 = getun (400,900)
iun2 = getun (iun1+1,900)
call fopens (iun1,'reruns.log','new','del')
call rdsets (iun2,iun1,'reruns.dat',insets)
if (insets == 0) close (iun1, status = 'delete')

! reruns (if supplied; else this loop is performed only once)
do iset = 0, insets

! select rerun set
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

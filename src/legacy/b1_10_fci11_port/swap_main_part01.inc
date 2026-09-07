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
   subroutine SWAP(iCaller, iTask, tstart_in, tend_in, swp_file, outfile, toswap, fromswap, worker, trial_mass, interval)
   !!!subroutine SWAP(iCaller, iTask, tstart_in, tend_in, toswap, fromswap)
      use swap_exchange
      use MOD_arrays, only: fillen
      use mod_a23bu_worker_execution_context, only: a23bu_worker_context_t
      use mod_b1_10_trial_mass, only: b1_10_trial_mass_t
      use mod_b1_10_interval_seam, only: b1_10_interval_seam_t
      integer,                intent(in)              :: iCaller, iTask
      real(8),                intent(inout)           :: tstart_in, tend_in
      character(len=fillen),  intent(in),    optional :: swp_file
      character(len=fillen),  intent(in),    optional :: outfile
      type(swap_input),       intent(in),    optional :: toswap
      type(swap_output),      intent(out),   optional :: fromswap
      type(a23bu_worker_context_t), intent(inout), optional :: worker
      type(b1_10_trial_mass_t), intent(inout), optional :: trial_mass
      type(b1_10_interval_seam_t), intent(inout), optional :: interval
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

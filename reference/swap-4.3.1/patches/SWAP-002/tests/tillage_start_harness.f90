module tillage_start_test_mod
   implicit none
   integer :: Ntill = 0
   integer :: iTill = 0
   integer :: loaded_prev = 0
   real(8) :: t1900 = 0.0d0
   real(8), allocatable :: Date_tillage(:)
   logical :: error_seen = .false.
contains

   subroutine set_iTill
   implicit none
   integer :: i
   ! iTill points to the next tillage event that still has to be executed.
   ! If the simulation starts between events, initialise parameters from the
   ! most recent preceding event so consolidation can continue.
   iTill = Ntill + 1
   do i = 2, Ntill
      if (Date_tillage(i) < Date_tillage(i-1)) call swap_error ('set_itill', 'Dates in tabulated tillage events must be sorted')
   end do
   do i = 1, Ntill
      if (t1900 <= Date_tillage(i)) then
         iTill = i
         exit
      end if
   end do
   if (iTill > 1) call Change_Tillage_Info(iTill-1)
   end subroutine set_iTill

   subroutine Change_Tillage_Info(idx)
      integer, intent(in) :: idx
      loaded_prev = idx
   end subroutine Change_Tillage_Info

   subroutine swap_error(where, msg)
      character(len=*), intent(in) :: where, msg
      error_seen = .true.
      if (len_trim(where) + len_trim(msg) < 0) error stop 'unreachable'
   end subroutine swap_error

   subroutine run_case(label, dates, start, exp_i, exp_load, exp_err, failures)
      character(len=*), intent(in) :: label
      real(8), intent(in) :: dates(:), start
      integer, intent(in) :: exp_i, exp_load
      logical, intent(in) :: exp_err
      integer, intent(inout) :: failures

      if (allocated(Date_tillage)) deallocate(Date_tillage)
      allocate(Date_tillage(size(dates)))
      Date_tillage = dates
      Ntill = size(dates)
      t1900 = start
      iTill = -99
      loaded_prev = 0
      error_seen = .false.

      call set_iTill
      if (iTill /= exp_i .or. loaded_prev /= exp_load .or. error_seen .neqv. exp_err) then
         failures = failures + 1
         write(*,'(A,1X,A,1X,A,I0,1X,A,I0,1X,A,L1)') &
            'FAIL', trim(label), 'iTill=', iTill, 'loaded=', loaded_prev, 'error=', error_seen
      else
         write(*,'(A,1X,A)') 'PASS', trim(label)
      end if
   end subroutine run_case
end module tillage_start_test_mod

program test_swap002_tillage_start
   use tillage_start_test_mod
   implicit none
   integer :: failures

   failures = 0
   call run_case('before_first', (/10d0,20d0,30d0/), 5d0, 1, 0, .false., failures)
   call run_case('exact_first', (/10d0,20d0,30d0/), 10d0, 1, 0, .false., failures)
   call run_case('between_1_2', (/10d0,20d0,30d0/), 15d0, 2, 1, .false., failures)
   call run_case('exact_second', (/10d0,20d0,30d0/), 20d0, 2, 1, .false., failures)
   call run_case('after_last', (/10d0,20d0,30d0/), 35d0, 4, 3, .false., failures)
   call run_case('unsorted', (/10d0,5d0,30d0/), 0d0, 1, 0, .true., failures)

   write(*,'(A,I0,A)') 'SWAP-002_TILLAGE_START_HARNESS PASS ', 6-failures, '/6'
   if (failures /= 0) stop 2
end program test_swap002_tillage_start

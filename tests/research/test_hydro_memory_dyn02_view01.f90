module mod_hydro_memory_dyn02_view01_test_support
  use mod_transaction_reference, only: transaction_state_t
  implicit none
  type, extends(transaction_state_t) :: unrelated_state_t
    integer :: marker=17
  contains
    procedure :: clone => unrelated_clone
  end type unrelated_state_t
contains
  subroutine unrelated_clone(self,copy)
    class(unrelated_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy
    allocate(unrelated_state_t :: copy)
    select type(typed=>copy)
    type is(unrelated_state_t)
      typed%marker=self%marker
    end select
  end subroutine unrelated_clone
end module mod_hydro_memory_dyn02_view01_test_support

program test_hydro_memory_dyn02_view01
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t
  use mod_hydro_memory_dyn02_view01_test_support, only: unrelated_state_t
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, &
       fmr_new_b110_committed_state, fmr_new_b110_temporal_indicator_committed_state
  use mod_fmr_process_hydraulic_view_binding, only: fmr_build_committed_process_hydraulic_view
  implicit none

  integer, parameter :: N=4
  real(real64), parameter :: T0=0.0_real64
  type(fmr_b110_physical_state_t) :: physical
  type(kernel_committed_state_t) :: plain, temporal, unrelated
  type(process_hydraulic_view_t) :: view_plain, view_temporal, view_unrelated
  class(transaction_state_t), allocatable :: unrelated_initial
  real(real64) :: previous_derivative(N)
  integer(int64) :: rev_plain_before, rev_temporal_before
  real(real64) :: time_plain_before, time_temporal_before
  logical :: ok_plain,ok_temporal,ok_unrelated,available

  physical%active_nodes=N
  allocate(physical%pressure_head(N),physical%water_content(N))
  physical%pressure_head=[-75.0_real64,-82.0_real64,-95.0_real64,-120.0_real64]
  physical%water_content=[0.35_real64,0.34_real64,0.32_real64,0.29_real64]
  physical%ponding_depth=0.125_real64
  physical%groundwater_level=-2.25_real64
  previous_derivative=[0.1_real64,0.2_real64,0.3_real64,0.4_real64]

  call fmr_new_b110_committed_state(plain,620001_int64,physical,T0,available)
  call require(available,'plain committed initialization')
  call fmr_new_b110_temporal_indicator_committed_state(temporal,620002_int64,physical,T0,available,previous_derivative)
  call require(available,'temporal committed initialization')

  rev_plain_before=plain%current_revision()
  rev_temporal_before=temporal%current_revision()
  call plain%current_time(time_plain_before,available)
  call require(available,'plain committed time')
  call temporal%current_time(time_temporal_before,available)
  call require(available,'temporal committed time')

  call fmr_build_committed_process_hydraulic_view(plain,view_plain,ok_plain)
  call fmr_build_committed_process_hydraulic_view(temporal,view_temporal,ok_temporal)

  call require(ok_plain,'plain hydraulic view unavailable')
  call require(ok_temporal,'temporal hydraulic view unavailable')
  call require(view_plain%active_nodes==N .and. view_temporal%active_nodes==N,'view node count')
  call require(all_bits_equal(view_plain%pressure_head,view_temporal%pressure_head),'pressure-head view mismatch')
  call require(all_bits_equal(view_plain%water_content,view_temporal%water_content),'water-content view mismatch')
  call require(same_bits(view_plain%ponding_depth,view_temporal%ponding_depth),'ponding view mismatch')
  call require(same_bits(view_plain%groundwater_level,view_temporal%groundwater_level),'groundwater view mismatch')

  call require(plain%current_revision()==rev_plain_before,'plain revision mutation')
  call require(temporal%current_revision()==rev_temporal_before,'temporal revision mutation')
  call plain%current_time(time_plain_before,available)
  call require(available .and. same_bits(time_plain_before,T0),'plain time mutation')
  call temporal%current_time(time_temporal_before,available)
  call require(available .and. same_bits(time_temporal_before,T0),'temporal time mutation')

  allocate(unrelated_state_t :: unrelated_initial)
  call unrelated%initialize(620003_int64,unrelated_initial,available,T0)
  call require(available,'unrelated committed initialization')
  call fmr_build_committed_process_hydraulic_view(unrelated,view_unrelated,ok_unrelated)
  call require(.not.ok_unrelated,'unrelated carrier did not fail closed')

  write(*,'(a)') 'HYDRO_MEMORY_DYN02_VIEW01_PLAIN=PASS'
  write(*,'(a)') 'HYDRO_MEMORY_DYN02_VIEW01_TEMPORAL=PASS'
  write(*,'(a)') 'HYDRO_MEMORY_DYN02_VIEW01_BIT_IDENTITY=PASS'
  write(*,'(a)') 'HYDRO_MEMORY_DYN02_VIEW01_ZERO_MUTATION=PASS'
  write(*,'(a)') 'HYDRO_MEMORY_DYN02_VIEW01_UNRELATED_FAIL_CLOSED=PASS'
  write(*,'(a)') 'HYDRO_MEMORY_DYN02_VIEW01_GATE=PASS'

contains

  subroutine unrelated_clone(self,copy)
    class(unrelated_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy
    allocate(unrelated_state_t :: copy)
    select type(typed=>copy)
    type is(unrelated_state_t)
      typed%marker=self%marker
    end select
  end subroutine unrelated_clone

  logical function same_bits(a,b) result(equal)
    real(real64), intent(in) :: a,b
    integer(int64) :: ia,ib
    ia=transfer(a,ia); ib=transfer(b,ib)
    equal=ia==ib
  end function same_bits

  logical function all_bits_equal(a,b) result(equal)
    real(real64), intent(in) :: a(:),b(:)
    integer :: i
    equal=size(a)==size(b)
    if(.not.equal)return
    do i=1,size(a)
      if(.not.same_bits(a(i),b(i)))then
        equal=.false.
        return
      end if
    end do
  end function all_bits_equal

  subroutine require(condition,message)
    logical,intent(in)::condition
    character(len=*),intent(in)::message
    if(.not.condition)then
      write(*,'(a,1x,a)') 'HYDRO_MEMORY_DYN02_VIEW01_FAIL',trim(message)
      error stop 1
    end if
  end subroutine require

end program test_hydro_memory_dyn02_view01

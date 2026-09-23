module mod_ppa_wu05a3_reset_inventory
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private
  type, public :: balance_start_inventory
    real(real64) :: intermediate(2)=0.0_real64, cumulative(2)=0.0_real64
    real(real64), allocatable :: profile(:,:) ! main/internal group, cell
  end type
  public :: reset_inventory
contains
  subroutine reset_inventory(task,storage,water,previous,candidate,status)
    integer,intent(in) :: task
    real(real64),intent(in) :: storage(:),water(:,:)
    type(balance_start_inventory),intent(in) :: previous
    type(balance_start_inventory),intent(out) :: candidate
    integer,intent(out) :: status
    integer :: n,id
    status=1
    if(task<0 .or. task>2 .or. size(storage)/=2 .or. size(water,1)<1) return
    n=size(water,2)
    if(n<1 .or. .not.allocated(previous%profile)) return
    if(any(shape(previous%profile)/=[2,n])) return
    if(.not.all(ieee_is_finite(storage)) .or. .not.all(ieee_is_finite(water)) .or. &
        .not.all(ieee_is_finite(previous%profile)) .or. &
        .not.all(ieee_is_finite(previous%intermediate)) .or. &
        .not.all(ieee_is_finite(previous%cumulative))) return
    candidate=previous
    if(task==0 .or. task==1) then
      candidate%intermediate=storage
      candidate%profile(1,:)=water(1,:)
      ! Source does not clear the prior internal beginning inventory here.
      do id=2,size(water,1)
        candidate%profile(2,:)=candidate%profile(2,:)+water(id,:)
      end do
    end if
    if(task==0 .or. task==2) candidate%cumulative=storage
    status=0
  end subroutine
end module

program test_ppa_wu05a3_reset_inventory
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_ppa_wu05a3_reset_inventory
  use mod_ppa_wu05a3_macrointegral_accumulation
  implicit none
  type(balance_start_inventory) :: previous,first,second
  type(macrointegral_history) :: counters,reset_counters
  real(real64) :: water(3,2),storage(2)
  integer :: status,task
  allocate(previous%profile(2,2))
  previous%profile(1,:)=9.0_real64; previous%profile(2,:)=[10.0_real64,20.0_real64]
  previous%intermediate=4.0_real64; previous%cumulative=5.0_real64
  storage=[1.0_real64,2.0_real64]
  water(1,:)=[0.5_real64,0.25_real64]
  water(2,:)=[1.0_real64,2.0_real64]; water(3,:)=[3.0_real64,4.0_real64]
  call reset_inventory(1,storage,water,previous,first,status)
  call require(status==0,1)
  call require(maxval(abs(first%intermediate-storage))+maxval(abs(first%cumulative-5.0_real64))<1.e-14_real64,2)
  call require(maxval(abs(first%profile(1,:)-water(1,:)))<1.e-14_real64,3)
  call require(maxval(abs(first%profile(2,:)-[14.0_real64,26.0_real64]))<1.e-14_real64,4)
  call reset_inventory(1,storage,water,first,second,status)
  call require(status==0,5)
  call require(maxval(abs(second%profile(2,:)-[18.0_real64,32.0_real64]))<1.e-14_real64,6)
  call require(maxval(abs(previous%profile(2,:)-[10.0_real64,20.0_real64]))<1.e-14_real64,7)
  call reset_inventory(2,storage,water,previous,first,status)
  call require(status==0,8)
  call require(maxval(abs(first%profile-previous%profile))+maxval(abs(first%intermediate-4.0_real64))+ &
      maxval(abs(first%cumulative-storage))<1.e-14_real64,9)
  call reset_inventory(0,storage,water,previous,first,status)
  call require(status==0,10)
  call require(maxval(abs(first%intermediate-storage))+maxval(abs(first%cumulative-storage))<1.e-14_real64,11)
  call reset_inventory(1,storage,water(1:1,:),previous,first,status)
  call require(status==0,12)
  call require(maxval(abs(first%profile(2,:)-previous%profile(2,:)))<1.e-14_real64,13)
  call reset_inventory(3,storage,water,previous,first,status)
  call require(status==1 .and. .not.allocated(first%profile),14)
  call reset_inventory(1,storage,water(:,1:1),previous,first,status)
  call require(status==1 .and. .not.allocated(first%profile),15)
  allocate(counters%cell(5,2,2),counters%exchange(2,2),counters%rapid(2),counters%wet(2,2))
  counters%cell=3.0_real64; counters%exchange=3.0_real64
  counters%rapid=3.0_real64; counters%wet=3.0_real64
  counters%top=3.0_real64; counters%rapid_total=3.0_real64
  counters%cumulative_cell=7.0_real64; counters%cumulative_top=7.0_real64
  counters%cumulative_rapid=7.0_real64
  do task=0,2
    call reset_macrointegral_counters(task,counters,reset_counters,status)
    call require(status==0,16)
    call reset_inventory(task,storage,water,previous,first,status)
    call require(status==0,17)
    if(task==0 .or. task==1) then
      call require(maxval(abs(reset_counters%cell))+ &
          maxval(abs(first%intermediate-storage))<1.e-14_real64,18)
    else
      call require(maxval(abs(reset_counters%cell-3.0_real64))+ &
          maxval(abs(first%intermediate-previous%intermediate))<1.e-14_real64,19)
    end if
    if(task==0 .or. task==2) then
      call require(maxval(abs(reset_counters%cumulative_cell))+ &
          maxval(abs(first%cumulative-storage))<1.e-14_real64,20)
    else
      call require(maxval(abs(reset_counters%cumulative_cell-7.0_real64))+ &
          maxval(abs(first%cumulative-previous%cumulative))<1.e-14_real64,21)
    end if
  end do
  print '(A)','PPA_WU05A3_RESET_INVENTORY_TASKS=PASS'
  print '(A)','PPA_WU05A3_RESET_INVENTORY_REPEATED_SOURCE_ACCUMULATION=PASS'
  print '(A)','PPA_WU05A3_RESET_INVENTORY_ISOLATION_AND_INVALID=PASS'
  print '(A)','PPA_WU05A3_RESET_COUNTER_INVENTORY_COMPOSITION=PASS'
contains
  subroutine require(ok,code)
    logical,intent(in) :: ok
    integer,intent(in) :: code
    if(.not.ok) then
      print *, 'RESET_INVENTORY_FAIL',code
      error stop 1
    end if
  end subroutine
end program

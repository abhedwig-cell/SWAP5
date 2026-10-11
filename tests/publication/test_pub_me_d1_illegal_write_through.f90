program test_pub_me_d1_illegal_write_through
  use mod_kernel_transactions, only: kernel_committed_state_t
  implicit none

  type(kernel_committed_state_t) :: committed

  ! This source is intentionally invalid under the admitted public contract.
  ! D1 asks whether candidate execution can obtain mutable access to the
  ! authoritative physical state. The physical_state component is private, so
  ! a consumer must not be able to address or mutate it directly.
  if (allocated(committed%physical_state)) then
    deallocate(committed%physical_state)
  end if
end program test_pub_me_d1_illegal_write_through

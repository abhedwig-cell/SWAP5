program test_generic_hybrid_state
  use probe_kernel_donor
  implicit none
  type(state_t) :: a,b
  type(model_t) :: model
  class(transaction_state_t),allocatable :: copy
  integer :: i
  a%column=1; a%ticket=2; a%stock=3d0
  a%component_stock=[1d0,2d0,0d0,0d0,0d0,0d0]
  a%pressure=[(real(i,real64),i=1,113)]
  call a%clone(copy)
  select type(copy)
  type is(state_t)
    if(size(copy%pressure)/=113.or.any(copy%pressure/=a%pressure)) error stop 'clone shape/value'
    copy%pressure(113)=-9d0;copy%stock=-1d0;copy%ticket=99;copy%component_stock=0d0
  class default
    error stop 'clone type'
  end select
  if(a%pressure(113)/=113d0.or.a%stock/=3d0.or.a%ticket/=2) error stop 'shared clone storage'
  if(any(a%component_stock/=[1d0,2d0,0d0,0d0,0d0,0d0])) error stop 'shared components'
  deallocate(copy)
  b%pressure=a%pressure
  if(model%temporal_error(a,b)/=0d0) error stop 'identical pressure metric'
  b%pressure=b%pressure(:112)
  if(model%temporal_error(a,b)/=huge(0d0)) error stop 'foreign grid metric'
  deallocate(b%pressure)
  if(model%temporal_error(a,b)/=huge(0d0)) error stop 'missing grid metric'
  a%pressure=[7d0,8d0,9d0]
  call a%clone(copy)
  select type(copy)
  type is(state_t)
    if(size(copy%pressure)/=3.or.any(copy%pressure/=[7d0,8d0,9d0])) error stop 'resized own clone'
  end select
  print *, 'HYBRID_DYNAMIC_STATE_CLONE_AND_SHAPE_PASS'
end program

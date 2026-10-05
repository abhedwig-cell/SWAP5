program test_mig431_tillage_types
  use mod_fmr_tillage_type_binding
  implicit none
  integer, allocatable :: first(:),last(:)
  integer :: status
  call bind_tillage_type_rows([2,2,4],[4,2,4],[1,2,1],first,last,status)
  if (status /= TILLAGE_TYPE_BIND_OK) error stop 1
  if (any(first /= [3,1,3]) .or. any(last /= [3,2,3])) error stop 2
  call bind_tillage_type_rows([2,4,2],[2],[2],first,last,status)
  if (status /= TILLAGE_TYPE_BIND_INVALID .or. allocated(first)) error stop 3
  call bind_tillage_type_rows([1,1],[2],[1],first,last,status)
  if (status /= TILLAGE_TYPE_BIND_INVALID .or. allocated(first)) error stop 4
  call bind_tillage_type_rows([2,2],[2],[1],first,last,status)
  if (status /= TILLAGE_TYPE_BIND_INVALID .or. allocated(first)) error stop 5
  print '(a)', 'F_MIG431_TILLAGE_TYPE_MAPPING=PASS'
end program

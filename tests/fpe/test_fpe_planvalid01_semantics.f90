program test_fpe_planvalid01_semantics
  use, intrinsic :: iso_fortran_env, only: int64
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, fmr_serialized_execution_plan_t, &
       fmr_build_serialized_execution_plan, FMR_BACKEND_SERIALIZED_REFERENCE
  implicit none
  type(fmr_logical_column_t), allocatable :: c(:), x(:)
  type(fmr_template_t), allocatable :: t(:), y(:)
  type(fmr_serialized_execution_plan_t) :: p
  logical :: ok
  integer :: i

  call make_canonical(c,t,6)
  call fmr_build_serialized_execution_plan(c,t,6,p,ok)
  call require(ok .and. p%ready(),'canonical accepted')
  do i=1,6
    call require(p%order_index(i)==i,'canonical identity order')
    call require(p%template_index(i)==i,'canonical direct template index')
  end do
  call require(p%matches(c,t,6),'canonical plan matches')

  x=c; y=t
  call reverse_columns(x)
  call fmr_build_serialized_execution_plan(x,y,6,p,ok)
  call require(ok .and. p%ready(),'reverse columns generic accepted')
  do i=1,6
    call require(p%order_index(i)==7-i,'reverse columns sorted identically')
    call require(p%template_index(i)==x(i)%template_id-1000_int64,'reverse columns template lookup')
  end do

  x=c; y=t
  call reverse_templates(y)
  call fmr_build_serialized_execution_plan(x,y,6,p,ok)
  call require(ok .and. p%ready(),'reverse templates generic accepted')
  do i=1,6
    call require(p%order_index(i)==i,'reverse templates order unchanged')
    call require(p%template_index(i)==7-i,'reverse templates lookup')
  end do

  x=c; y=t; y(4)%template_id=y(3)%template_id
  call fmr_build_serialized_execution_plan(x,y,6,p,ok)
  call require(.not.ok,'duplicate template rejected')

  x=c; y=t; x(5)%column_id=x(4)%column_id
  call fmr_build_serialized_execution_plan(x,y,6,p,ok)
  call require(.not.ok,'duplicate column rejected')

  x=c; y=t; x(5)%state_handle=x(4)%state_handle
  call fmr_build_serialized_execution_plan(x,y,6,p,ok)
  call require(.not.ok,'duplicate state handle rejected')

  x=c; y=t; x(3)%state_handle=7_int64
  call fmr_build_serialized_execution_plan(x,y,6,p,ok)
  call require(.not.ok,'out of range state handle rejected')

  x=c; y=t; x(2)%column_id=0_int64
  call fmr_build_serialized_execution_plan(x,y,6,p,ok)
  call require(.not.ok,'nonpositive column rejected')

  x=c; y=t; y(2)%template_id=0_int64
  call fmr_build_serialized_execution_plan(x,y,6,p,ok)
  call require(.not.ok,'nonpositive template rejected')

  x=c; y=t; x(3)%template_id=t(4)%template_id
  call fmr_build_serialized_execution_plan(x,y,6,p,ok)
  call require(ok .and. p%ready(),'nonidentity valid mapping stays generic')
  call require(p%template_index(3)==4,'generic mapping preserved')

  write(*,'(A)') 'PLANVALID01_SEMANTICS=PASS'

contains
  subroutine make_canonical(cols,tmpls,n)
    type(fmr_logical_column_t),allocatable,intent(out)::cols(:)
    type(fmr_template_t),allocatable,intent(out)::tmpls(:)
    integer,intent(in)::n
    integer::k
    allocate(cols(n),tmpls(n))
    do k=1,n
      tmpls(k)%template_id=1000_int64+int(k,int64)
      tmpls(k)%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
      cols(k)%column_id=2000_int64+int(k,int64)
      cols(k)%template_id=tmpls(k)%template_id
      cols(k)%state_handle=int(k,int64)
      cols(k)%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    end do
  end subroutine
  subroutine reverse_columns(a)
    type(fmr_logical_column_t),intent(inout)::a(:)
    type(fmr_logical_column_t)::tmp
    integer::k,j
    do k=1,size(a)/2
      j=size(a)+1-k; tmp=a(k); a(k)=a(j); a(j)=tmp
    end do
  end subroutine
  subroutine reverse_templates(a)
    type(fmr_template_t),intent(inout)::a(:)
    type(fmr_template_t)::tmp
    integer::k,j
    do k=1,size(a)/2
      j=size(a)+1-k; tmp=a(k); a(k)=a(j); a(j)=tmp
    end do
  end subroutine
  subroutine require(cond,label)
    logical,intent(in)::cond
    character(len=*),intent(in)::label
    if(.not.cond) then
      write(*,'(A,1X,A)') 'PLANVALID01_FAIL',trim(label)
      error stop 1
    end if
  end subroutine
end program test_fpe_planvalid01_semantics

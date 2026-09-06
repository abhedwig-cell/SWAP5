program swap004_candidate_harness
  implicit none
  integer :: passed
  passed=0
  call test_dense(passed)
  call test_sparse_type_gt_ntill(passed)
  call test_noncontiguous(passed)
  call test_missing_type_record(passed)
  if (passed /= 4) error stop 90
  print '(a,i0,a)', 'SWAP-004_CANDIDATE_HARNESS PASS ',passed,'/4'
contains
  subroutine build_new(ntill, types, ntypes, itypes, ok, first, last)
    integer,intent(in)::ntill,ntypes,types(ntill),itypes(ntypes)
    logical,intent(out)::ok
    integer,allocatable,intent(out)::first(:),last(:)
    integer::tmax,i,j
    tmax=maxval(types)
    if (tmax < 1) then; ok=.false.; allocate(first(1),last(1)); return; end if
    allocate(first(tmax),last(tmax)); first=0; last=0
    do j=1,tmax
      do i=1,ntypes
        if(first(j)==0 .and. itypes(i)==j) first(j)=i
        if(first(j)>0 .and. itypes(i)==j) last(j)=i
      end do
    end do
    ok=.true.
    do i=1,ntill
      j=types(i)
      if(j<1 .or. j>tmax) then; ok=.false.; return; end if
      if(first(j)==0 .or. last(j)==0) then; ok=.false.; return; end if
    end do
  end subroutine

  subroutine build_old_safe(ntill, ntypes, itypes, first, last)
    integer,intent(in)::ntill,ntypes,itypes(ntypes)
    integer,allocatable,intent(out)::first(:),last(:)
    integer::i,j
    allocate(first(ntill),last(ntill)); first=0; last=0
    do j=1,ntill
      do i=1,ntypes
        if(first(j)==0 .and. itypes(i)==j) first(j)=i
        if(first(j)>0 .and. itypes(i)==j) last(j)=i
      end do
    end do
  end subroutine

  subroutine test_dense(passed)
    integer,intent(inout)::passed
    integer,allocatable::a(:),b(:),oa(:),ob(:); logical::ok
    integer::types(3)=[1,2,1], itypes(4)=[1,1,2,2]
    call build_new(3,types,4,itypes,ok,a,b)
    call build_old_safe(3,4,itypes,oa,ob)
    if(.not.ok) error stop 1
    if(any(a(1:2)/=[1,3]) .or. any(b(1:2)/=[2,4])) error stop 2
    if(any(a(1:2)/=oa(1:2)) .or. any(b(1:2)/=ob(1:2))) error stop 3
    passed=passed+1
  end subroutine

  subroutine test_sparse_type_gt_ntill(passed)
    integer,intent(inout)::passed
    integer,allocatable::a(:),b(:); logical::ok
    integer::types(1)=[3],itypes(2)=[3,3]
    call build_new(1,types,2,itypes,ok,a,b)
    if(.not.ok .or. size(a)/=3 .or. a(3)/=1 .or. b(3)/=2) error stop 4
    passed=passed+1
  end subroutine

  subroutine test_noncontiguous(passed)
    integer,intent(inout)::passed
    integer,allocatable::a(:),b(:); logical::ok
    integer::types(2)=[1,3],itypes(2)=[1,3]
    call build_new(2,types,2,itypes,ok,a,b)
    if(.not.ok .or. a(1)/=1 .or. b(1)/=1 .or. a(3)/=2 .or. b(3)/=2) error stop 5
    passed=passed+1
  end subroutine

  subroutine test_missing_type_record(passed)
    integer,intent(inout)::passed
    integer,allocatable::a(:),b(:); logical::ok
    integer::types(2)=[1,2],itypes(1)=[1]
    call build_new(2,types,1,itypes,ok,a,b)
    if(ok) error stop 6
    passed=passed+1
  end subroutine
end program

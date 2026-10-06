program corrected_table_test
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan, ieee_positive_inf
  use mod_root_micro_matric_flux_table
  use literal_micro_table, only: get_MFLP_K
  use MOD_MvG, only: profile, hconduc
  implicit none
  type(micro_matric_flux_table_t) :: table, empty
  real(real64) :: values(430), samples(10), head, dry_k, m, k, mr, kr, before, before_k, bad(430), delta, span, expected
  integer :: i,p,status,ncases
  samples=[-20001d0,-20000d0,-19999.999d0,-19970d0,-19952.6231496888d0,-19900d0,-19000d0,-100d0,-1d0,10d0]
  ncases=0
  call evaluate_micro_matric_flux_table(empty,-100d0,m,k,status)
  call require(status==MICRO_TABLE_INVALID,'unbuilt table rejected')
  do p=1,2
    profile=p
    call get_MFLP_K(1)
    do i=1,430
      head=-10d0**(real(i,real64)/100d0)
      values(i)=hconduc(1,head,0.3d0,10d0)
    end do
    dry_k=hconduc(1,-20000d0,0.3d0,10d0)
    call build_micro_matric_flux_table(values,dry_k,1d0,table,status)
    call require(status==MICRO_TABLE_OK,'valid table built')
    do i=1,430
      head=-10d0**(real(i,real64)/100d0)
      call compare(head)
      call compare(head*(1d0+1d-10))
      call compare(head*(1d0-1d-10))
    end do
    do i=1,size(samples)
      call compare(samples(i))
    end do
    call evaluate_micro_matric_flux_table(table,-19970d0,m,k,status)
    delta=30d0
    span=-10d0**4.3d0+20000d0
    expected=dry_k*delta+0.5d0*(values(430)-dry_k)*delta**2/span
    call close(m,expected,'independent terminal integral')
    if(p==1)call close(m,30d0,'constant K integral from true endpoint')
    call evaluate_micro_matric_flux_table(table,-100d0,before,before_k,status)
    bad=values;bad(400)=ieee_value(0d0,ieee_quiet_nan)
    call build_micro_matric_flux_table(bad,dry_k,1d0,table,status)
    call rejected()
    bad=values;bad(400)=ieee_value(0d0,ieee_positive_inf)
    call build_micro_matric_flux_table(bad,dry_k,1d0,table,status)
    call rejected()
    bad=values;bad(400)=-1d0
    call build_micro_matric_flux_table(bad,dry_k,1d0,table,status)
    call rejected()
    call build_micro_matric_flux_table(values(1:429),dry_k,1d0,table,status)
    call rejected()
    call build_micro_matric_flux_table(values,ieee_value(0d0,ieee_quiet_nan),1d0,table,status)
    call rejected()
    call evaluate_micro_matric_flux_table(table,ieee_value(0d0,ieee_quiet_nan),m,k,status)
    call require(status==MICRO_TABLE_INVALID,'nonfinite head rejected')
  end do
  write(*,'(A,I0)')'MICRO01_CORRECTED_LITERAL_CASES=',ncases
  print '(A)','MICRO01_TERMINAL_INTEGRAL_AND_REJECTED_BUILD_ISOLATION=PASS'
contains
  subroutine require(ok,label)
    logical,intent(in)::ok
    character(*),intent(in)::label
    if(.not.ok)then
      print *,label
      error stop 1
    end if
  end subroutine
  subroutine close(a,b,label)
    real(real64),intent(in)::a,b
    character(*),intent(in)::label
    call require(abs(a-b)<=1d-12*max(abs(a),abs(b),1d-12),label)
  end subroutine
  subroutine compare(h)
    real(real64),intent(in)::h
    call get_MFLP_K(2,h,1,mr,kr)
    call evaluate_micro_matric_flux_table(table,h,m,k,status)
    call require(status==MICRO_TABLE_OK,'evaluate status')
    call close(m,mr,'corrected literal M')
    call close(k,kr,'corrected literal K')
    ncases=ncases+1
  end subroutine
  subroutine rejected()
    call require(status==MICRO_TABLE_INVALID,'invalid build rejected')
    call evaluate_micro_matric_flux_table(table,-100d0,m,k,status)
    call require(status==MICRO_TABLE_OK,'previous table retained')
    call close(m,before,'rejected M isolation')
    call close(k,before_k,'rejected K isolation')
  end subroutine
end program

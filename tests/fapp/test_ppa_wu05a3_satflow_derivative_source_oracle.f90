program test_ppa_wu05a3_satflow_derivative_source_oracle
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use mod_ppa_wu05a3_satflow_derivative
  implicit none

  integer, parameter :: vector_count = 100000
  real(real64) :: h(8), delh(8), qin(8), qout(8), initial(8), expected_h(8), expected_df(8)
  real(real64) :: actual_h(8), actual_df(8)
  integer(int64) :: state
  integer :: i, n, top, bottom, top_mp, status

  state = 20260923_int64
  do i = 1, vector_count
    n = 3+modulo(i, size(h)-2)
    call fill_arrays(state, h(1:n), delh(1:n), qin(1:n), qout(1:n), initial(1:n))
    top = 1+modulo(i,n)
    bottom = top+modulo(i+1,n-top+1)
    top_mp = 1+modulo(i+2,n)
    if (modulo(i, 10) == 0) delh(top) = sign(1.0e-15_real64,delh(top))
    call source_derivative(top,bottom,top_mp,h(1:n),delh(1:n),qin(1:n),qout(1:n),initial(1:n), &
         expected_h(1:n),expected_df(1:n))
    call ppa_wu05a3_satflow_derivative(top,bottom,top_mp,h(1:n),delh(1:n),qin(1:n),qout(1:n), &
         initial(1:n),actual_h(1:n),actual_df(1:n),status)
    call require(status == PPA_WU05A3_SATFLOW_DERIVATIVE_OK,1)
    call require(all(transfer(expected_h(1:n),[0_int64],n) == transfer(actual_h(1:n),[0_int64],n)),2)
    call require(all(transfer(expected_df(1:n),[0_int64],n) == transfer(actual_df(1:n),[0_int64],n)),3)
  end do

  print '(A)','PPA_WU05A3_SATFLOW_DERIVATIVE_SOURCE_ORACLE_100000=PASS'
  print '(A)','PPA_WU05A3_SATFLOW_DERIVATIVE_STRICT_HEAD_THRESHOLD=PASS'
  print '(A)','PPA_WU05A3_SATFLOW_COVERING_TOP_COMPARTMENT_CORRECTION=PASS'

contains

  subroutine fill_arrays(random_state, heads, differences, incoming, outgoing, derivatives)
    integer(int64),intent(inout)::random_state
    real(real64),intent(out)::heads(:),differences(:),incoming(:),outgoing(:),derivatives(:)
    integer::j
    do j=1,size(heads)
      heads(j)=-1.0_real64+4.0_real64*next_unit(random_state)
      differences(j)=-5.0_real64+10.0_real64*next_unit(random_state)
      incoming(j)=4.0_real64*next_unit(random_state)
      outgoing(j)=4.0_real64*next_unit(random_state)
      derivatives(j)=-2.0_real64+4.0_real64*next_unit(random_state)
    end do
  end subroutine fill_arrays

  real(real64) function next_unit(random_state) result(value)
    integer(int64),intent(inout)::random_state
    random_state=modulo(random_state*48271_int64,2147483647_int64)
    value=real(modulo(random_state,1000000_int64),real64)/1000000.0_real64
  end function next_unit

  subroutine source_derivative(first,last,top_mp,heads,differences,incoming,outgoing,derivatives,head_out,df_out)
    integer,intent(in)::first,last,top_mp
    real(real64),intent(in)::heads(:),differences(:),incoming(:),outgoing(:),derivatives(:)
    real(real64),intent(out)::head_out(:),df_out(:)
    real(real64)::critical,reference
    integer::ic
    head_out=differences
    df_out=derivatives
    do ic=first,last
      if(abs(head_out(ic))>1.0e-14_real64) then
        df_out(ic)=df_out(ic)-(outgoing(ic)-incoming(ic))/head_out(ic)
      end if
    end do
    if(top_mp>1) then
      ic=top_mp-1
      critical=0.0_real64
      reference=critical
      if(heads(ic)>critical) then
        head_out(ic)=0.0_real64-(heads(ic)-reference)
        df_out(ic)=df_out(ic)+incoming(ic)/head_out(ic)
      end if
    end if
  end subroutine source_derivative

  subroutine require(condition,code)
    logical,intent(in)::condition
    integer,intent(in)::code
    if(condition)return
    write(*,'(A,I0)')'PPA_WU05A3_SATFLOW_DERIVATIVE_FAIL=',code
    error stop 1
  end subroutine require

end program test_ppa_wu05a3_satflow_derivative_source_oracle

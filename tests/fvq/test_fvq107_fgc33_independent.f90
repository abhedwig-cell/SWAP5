program test_fvq107_fgc33_independent
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_modflow6_multiswap_cell_response, only: modflow6_multiswap_cell_response_t, MODFLOW6_MULTI_CELL_OK
  use mod_modflow6_linear_response_backend, only: modflow6_linear_boundary_term_t, &
       compose_modflow6_linear_boundary_term, evaluate_modflow6_linear_boundary_flux, &
       MODFLOW6_LINEAR_BACKEND_OK, MODFLOW6_LINEAR_BACKEND_INVALID_AREA, &
       MODFLOW6_LINEAR_BACKEND_INVALID_CELL_RESPONSE, MODFLOW6_LINEAR_BACKEND_INVALID_EVALUATION
  implicit none

  real(real64), parameter :: DAY_TO_S=86400.0_real64
  integer :: failures

  failures=0
  call direct_coefficient_oracle(failures)
  call multihead_flux_oracle(failures)
  call equivalent_reference_oracle(failures)
  call area_and_sign_oracle(failures)
  call negative_oracle(failures)

  if(failures/=0) then
    write(*,'(A,I0)') 'FVQ107_FAILURE_COUNT=',failures
    error stop 1
  end if

  write(*,'(A)') 'FVQ107_DIRECT_COEFFICIENT_ORACLE=PASS'
  write(*,'(A)') 'FVQ107_MULTIHEAD_VOLUME_FLUX_ORACLE=PASS'
  write(*,'(A)') 'FVQ107_EQUIVALENT_REFERENCE_ORACLE=PASS'
  write(*,'(A)') 'FVQ107_AREA_AND_SIGN_ORACLE=PASS'
  write(*,'(A)') 'FVQ107_NEGATIVE_INPUT_ORACLE=PASS'
  write(*,'(A)') 'FVQ107_INDEPENDENT_LINEAR_BACKEND_GATE=PASS'

contains

  subroutine direct_coefficient_oracle(f)
    integer,intent(inout)::f
    type(modflow6_multiswap_cell_response_t)::cell
    type(modflow6_linear_boundary_term_t)::term
    real(real64),parameter::area=2500.0_real64
    real(real64)::expected_hcof,expected_rhs
    integer::s

    call make_cell(1.2_real64,3.5e-7_real64,2.0e-5_real64,cell)
    call compose_modflow6_linear_boundary_term(cell,area,term,s)
    call req(s==MODFLOW6_LINEAR_BACKEND_OK.and.term%valid,'valid compose',f)

    expected_hcof=area*DAY_TO_S*cell%dq_u_dh_per_s
    expected_rhs=expected_hcof*cell%reference_head_m-area*DAY_TO_S*cell%q_u_at_reference_m_per_s

    call close(term%hcof_m2_per_day,expected_hcof,1e-10_real64,'direct HCOF',f)
    call close(term%rhs_m3_per_day,expected_rhs,1e-10_real64,'direct RHS',f)
    call close(term%reference_volume_flux_m3_per_day,area*DAY_TO_S*cell%q_u_at_reference_m_per_s, &
         1e-10_real64,'reference volume',f)
    call req(term%groundwater_cell_id==8801_int64,'cell identity preserved',f)
  end subroutine

  subroutine multihead_flux_oracle(f)
    integer,intent(inout)::f
    type(modflow6_multiswap_cell_response_t)::cell
    type(modflow6_linear_boundary_term_t)::term
    real(real64),parameter::area=2500.0_real64
    real(real64),parameter::heads(4)=[0.7_real64,1.0_real64,1.2_real64,1.8_real64]
    real(real64)::actual,expected
    integer::i,s

    call make_cell(1.2_real64,3.5e-7_real64,2.0e-5_real64,cell)
    call compose_modflow6_linear_boundary_term(cell,area,term,s)
    do i=1,size(heads)
      call evaluate_modflow6_linear_boundary_flux(term,heads(i),actual,s)
      call req(s==MODFLOW6_LINEAR_BACKEND_OK,'head evaluation',f)
      expected=area*DAY_TO_S*(cell%q_u_at_reference_m_per_s+ &
           cell%dq_u_dh_per_s*(heads(i)-cell%reference_head_m))
      call close(actual,expected,2e-10_real64,'multihead direct Q',f)
    end do
  end subroutine

  subroutine equivalent_reference_oracle(f)
    integer,intent(inout)::f
    type(modflow6_multiswap_cell_response_t)::a,b
    type(modflow6_linear_boundary_term_t)::ta,tb
    real(real64),parameter::area=1800.0_real64
    real(real64),parameter::slope=-1.5e-5_real64
    real(real64),parameter::ha=0.9_real64,hb=1.4_real64
    real(real64),parameter::qa=8.0e-7_real64
    real(real64)::qb
    integer::sa,sb

    qb=qa+slope*(hb-ha)
    call make_cell(ha,qa,slope,a)
    call make_cell(hb,qb,slope,b)
    call compose_modflow6_linear_boundary_term(a,area,ta,sa)
    call compose_modflow6_linear_boundary_term(b,area,tb,sb)
    call req(sa==MODFLOW6_LINEAR_BACKEND_OK.and.sb==MODFLOW6_LINEAR_BACKEND_OK,'reference compose',f)
    call close(ta%hcof_m2_per_day,tb%hcof_m2_per_day,1e-10_real64,'reference HCOF',f)
    call close(ta%rhs_m3_per_day,tb%rhs_m3_per_day,1e-10_real64,'reference RHS',f)
  end subroutine

  subroutine area_and_sign_oracle(f)
    integer,intent(inout)::f
    type(modflow6_multiswap_cell_response_t)::cell
    type(modflow6_linear_boundary_term_t)::small,large
    real(real64)::qs,ql
    integer::s

    call make_cell(1.0_real64,5e-7_real64,0.0_real64,cell)
    call compose_modflow6_linear_boundary_term(cell,1000.0_real64,small,s)
    call compose_modflow6_linear_boundary_term(cell,4000.0_real64,large,s)
    call evaluate_modflow6_linear_boundary_flux(small,1.0_real64,qs,s)
    call evaluate_modflow6_linear_boundary_flux(large,1.0_real64,ql,s)
    call close(ql,4.0_real64*qs,1e-10_real64,'area ratio',f)
    call req(qs>0.0_real64.and.ql>0.0_real64,'positive infiltration sign',f)
  end subroutine

  subroutine negative_oracle(f)
    integer,intent(inout)::f
    type(modflow6_multiswap_cell_response_t)::cell
    type(modflow6_linear_boundary_term_t)::term
    real(real64)::nanv,q
    integer::s

    call make_cell(1.0_real64,1e-7_real64,1e-6_real64,cell)
    nanv=ieee_value(0.0_real64,ieee_quiet_nan)

    call compose_modflow6_linear_boundary_term(cell,-1.0_real64,term,s)
    call req(s==MODFLOW6_LINEAR_BACKEND_INVALID_AREA.and..not.term%valid,'negative area',f)
    call compose_modflow6_linear_boundary_term(cell,nanv,term,s)
    call req(s==MODFLOW6_LINEAR_BACKEND_INVALID_AREA.and..not.term%valid,'nan area',f)

    cell%valid=.false.
    call compose_modflow6_linear_boundary_term(cell,1000.0_real64,term,s)
    call req(s==MODFLOW6_LINEAR_BACKEND_INVALID_CELL_RESPONSE.and..not.term%valid,'invalid cell',f)

    call make_cell(1.0_real64,1e-7_real64,1e-6_real64,cell)
    call compose_modflow6_linear_boundary_term(cell,1000.0_real64,term,s)
    call evaluate_modflow6_linear_boundary_flux(term,nanv,q,s)
    call req(s==MODFLOW6_LINEAR_BACKEND_INVALID_EVALUATION.and.q==0.0_real64,'nan head',f)
  end subroutine

  subroutine make_cell(href,qref,slope,cell)
    real(real64),intent(in)::href,qref,slope
    type(modflow6_multiswap_cell_response_t),intent(out)::cell
    cell=modflow6_multiswap_cell_response_t()
    cell%status=MODFLOW6_MULTI_CELL_OK
    cell%valid=.true.
    cell%groundwater_cell_id=8801_int64
    cell%window%t0=4.0_real64
    cell%window%t1=4.25_real64
    cell%reference_head_m=href
    cell%coupling_id=7701_int64
    cell%groundwater_service_id=7702_int64
    cell%groundwater_lineage_id=7703_int64
    cell%groundwater_origin_revision=12_int64
    cell%tile_count=3
    cell%fraction_sum=1.0_real64
    cell%q_u_at_reference_m_per_s=qref
    cell%dq_u_dh_per_s=slope
    cell%coupling_storage_coefficient_u=slope*(cell%window%t1-cell%window%t0)*DAY_TO_S
  end subroutine

  subroutine req(ok,msg,f)
    logical,intent(in)::ok
    character(len=*),intent(in)::msg
    integer,intent(inout)::f
    if(.not.ok)then
      f=f+1
      write(*,'(A)') 'FVQ107_FAIL: '//trim(msg)
    end if
  end subroutine

  subroutine close(a,e,t,msg,f)
    real(real64),intent(in)::a,e,t
    character(len=*),intent(in)::msg
    integer,intent(inout)::f
    call req(abs(a-e)<=t,msg,f)
  end subroutine
end program

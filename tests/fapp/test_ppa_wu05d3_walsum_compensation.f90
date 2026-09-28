program test_ppa_wu05d3_walsum_compensation
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_ppa_wu05d3_walsum_compensation
  implicit none

  integer, parameter :: ncase=100000, nnode=5
  integer :: i, status, selector, below_02
  integer(int64) :: state
  real(real64) :: qrot(nnode), expected_qrot(nnode), out_qrot(nnode), a_qrot(nnode), saved_qrot(nnode)
  real(real64) :: ptra, qrosum, expected_sum, out_sum, a_sum, alpha, a_alpha, saved_sum
  real(real64) :: dcrit, rdm, rdnode, a_dcrit, a_rdm, a_rdnode
  real(real64) :: parts(4), expected_parts(4), out_parts(4), a_parts(4), saved_parts(4)
  integer :: a_selector
  logical :: applied, expected_applied

  state=813773_int64
  below_02=0
  do i=1,ncase
    call make_case(state,qrot,qrosum,ptra,dcrit,rdm,rdnode,selector,parts)
    call source_oracle(qrot,qrosum,ptra,dcrit,rdm,rdnode,selector,parts, &
        expected_qrot,expected_sum,expected_parts,alpha,expected_applied)
    if (alpha < 0.2_real64) below_02=below_02+1
    call run_compositor(qrot,qrosum,ptra,dcrit,rdm,rdnode,selector,parts, &
        out_qrot,out_sum,out_parts,alpha,applied,status)
    call require(status==PPA_WU05D3_OK,'valid Walsum source-domain input rejected')
    call require(same_vector_bits(out_qrot,expected_qrot).and.same_bits(out_sum,expected_sum).and. &
        same_vector_bits(out_parts,expected_parts).and.(applied.eqv.expected_applied), &
        'Walsum result differs from source oracle')
  end do
  call require(below_02>0,'test data did not exercise Walsum alpha below Jarvis range')

  call make_case(state,qrot,qrosum,ptra,dcrit,rdm,rdnode,selector,parts)
  call run_compositor(qrot,qrosum,ptra,100.0_real64,100.0_real64,10.0_real64,1,parts, &
      out_qrot,out_sum,out_parts,alpha,applied,status)
  call require(status==PPA_WU05D3_OK.and..not.applied.and.same_vector_bits(qrot,out_qrot).and. &
      same_bits(qrosum,out_sum),'Walsum alpha=1 no-op gate changed candidate')

  call make_case(state,qrot,qrosum,ptra,dcrit,rdm,rdnode,selector,parts)
  call run_compositor(qrot,qrosum,ptra,dcrit,rdm,rdnode,selector,parts, &
      out_qrot,out_sum,out_parts,alpha,applied,status)
  call require(status==PPA_WU05D3_OK.and.applied,'A Walsum replay rejected')
  a_qrot=qrot; a_sum=qrosum; a_dcrit=dcrit; a_rdm=rdm; a_rdnode=rdnode
  a_selector=selector; a_parts=parts; a_alpha=alpha
  saved_qrot=out_qrot; saved_sum=out_sum; saved_parts=out_parts
  call make_case(state,qrot,qrosum,ptra,dcrit,rdm,rdnode,selector,parts)
  call run_compositor(qrot,qrosum,ptra,dcrit,rdm,rdnode,selector,parts, &
      out_qrot,out_sum,out_parts,alpha,applied,status)
  call require(status==PPA_WU05D3_OK,'B Walsum replay rejected')
  call run_compositor(a_qrot,a_sum,ptra,a_dcrit,a_rdm,a_rdnode,a_selector,a_parts, &
      out_qrot,out_sum,out_parts,alpha,applied,status)
  call require(status==PPA_WU05D3_OK.and.same_vector_bits(saved_qrot,out_qrot).and. &
      same_bits(saved_sum,out_sum).and.same_vector_bits(saved_parts,out_parts).and.same_bits(a_alpha,alpha), &
      'Walsum A/B/A replay compounded or retained state')

  call run_compositor(qrot,5.0_real64,10.0_real64,1.0_real64,0.0_real64,0.0_real64, &
      1,parts,out_qrot,out_sum,out_parts,alpha,applied,status)
  call require(status==PPA_WU05D3_INVALID_INPUT.and..not.applied.and.same_bits(out_sum,5.0_real64), &
      'invalid Walsum geometry did not fail closed')
  qrot(1)=ieee_value(0.0_real64,ieee_quiet_nan)
  call run_compositor(qrot,5.0_real64,10.0_real64,1.0_real64,20.0_real64,10.0_real64, &
      1,parts,out_qrot,out_sum,out_parts,alpha,applied,status)
  call require(status==PPA_WU05D3_INVALID_INPUT.and..not.applied.and.same_bits(out_sum,5.0_real64), &
      'non-finite Walsum input did not fail closed')

  write(*,'(a)') 'PPA_WU05D3_WALSUM_SOURCE_ORACLE_100000=PASS'
  write(*,'(a)') 'PPA_WU05D3_ALPHA_BELOW_020_AND_ALL_STRESSORS=PASS'
  write(*,'(a)') 'PPA_WU05D3_NOOP_AND_A_B_A_NONCOMPOUNDING=PASS'
  write(*,'(a)') 'PPA_WU05D3_INVALID_GEOMETRY_NONFINITE_FAIL_CLOSED=PASS'

contains

  real(real64) function next_unit(value)
    integer(int64),intent(inout)::value
    value=modulo(48271_int64*value,2147483647_int64)
    next_unit=real(value,real64)/2147483647.0_real64
  end function next_unit

  subroutine make_case(rng,sink,total,potential,critical_depth,rootmax,rootnode,stressor,reductions)
    integer(int64),intent(inout)::rng
    real(real64),intent(out)::sink(nnode),total,potential,critical_depth,rootmax,rootnode,reductions(4)
    integer,intent(out)::stressor
    real(real64)::weights(4),wanted_total
    integer::k
    potential=10.0_real64
    wanted_total=0.2_real64+0.7_real64*next_unit(rng)
    do k=1,nnode
      sink(k)=wanted_total*potential*(0.1_real64+next_unit(rng))
    end do
    sink=sink*(wanted_total*potential/sum(sink))
    total=sum(sink)
    rootmax=30.0_real64+150.0_real64*next_unit(rng)
    rootnode=rootmax*next_unit(rng)
    critical_depth=0.02_real64+99.98_real64*next_unit(rng)
    reductions(1)=potential-total
    weights=[next_unit(rng),next_unit(rng),next_unit(rng),next_unit(rng)]
    weights=weights/sum(weights)
    reductions=reductions(1)*weights
    stressor=1+int(5.0_real64*next_unit(rng))
    if(stressor>5) stressor=5
  end subroutine make_case

  subroutine run_compositor(sink,total,potential,critical_depth,rootmax,rootnode,stressor,reductions, &
      result_sink,result_total,result_reductions,critical,was_applied,result_status)
    real(real64),intent(in)::sink(:),total,potential,critical_depth,rootmax,rootnode,reductions(4)
    integer,intent(in)::stressor
    real(real64),intent(out)::result_sink(:),result_total,result_reductions(4),critical
    logical,intent(out)::was_applied
    integer,intent(out)::result_status
    call apply_ppa_wu05d3_walsum_compensation(sink,total,potential,critical_depth,rootmax,rootnode, &
      stressor,reductions(1),reductions(2),reductions(3),reductions(4),critical,result_sink,result_total, &
      result_reductions(1),result_reductions(2),result_reductions(3),result_reductions(4), &
      was_applied,result_status)
  end subroutine run_compositor

  subroutine source_oracle(sink,total,potential,critical_depth,rootmax,rootnode,stressor,reductions, &
      result_sink,result_total,result_reductions,critical,was_applied)
    real(real64),intent(in)::sink(:),total,potential,critical_depth,rootmax,rootnode,reductions(4)
    integer,intent(in)::stressor
    real(real64),intent(out)::result_sink(:),result_total,result_reductions(4),critical
    logical,intent(out)::was_applied
    real(real64)::alpha_total,removed,dry,wet,salt,frost,dry_com,wet_com,salt_com,frost_com,total_com,red_total
    integer::k
    critical=min((critical_depth+rootmax-rootnode)/rootmax,1.0_real64)
    result_sink=sink; result_total=total; result_reductions=reductions; was_applied=.false.
    alpha_total=total/potential
    removed=potential-total
    if(.not.(abs(critical-1.0_real64)>=1.0e-14_real64.and.removed>1.0e-14_real64.and. &
        alpha_total>=1.0e-14_real64)) return
    dry=alpha_total**(reductions(2)/removed)
    wet=alpha_total**(reductions(1)/removed)
    salt=alpha_total**(reductions(3)/removed)
    frost=alpha_total**(reductions(4)/removed)
    if(stressor==1) then
      total_com=min(alpha_total/critical,1.0_real64)
      dry_com=dry; wet_com=wet; salt_com=salt; frost_com=frost
    else
      dry_com=dry; wet_com=wet; salt_com=salt; frost_com=frost
      if(stressor==2) then
        dry_com=min(dry/critical,1.0_real64)
      else if(stressor==3) then
        wet_com=min(wet/critical,1.0_real64)
      else if(stressor==4) then
        salt_com=min(salt/critical,1.0_real64)
      else if(stressor==5) then
        frost_com=min(frost/critical,1.0_real64)
      end if
      total_com=wet_com*dry_com*salt_com*frost_com
    end if
    do k=1,size(sink)
      result_sink(k)=sink(k)*total_com/alpha_total
    end do
    result_total=potential*total_com
    removed=potential-result_total
    if(removed<1.0e-14_real64) then
      result_reductions=0.0_real64
    else
      red_total=(1.0_real64-wet_com)+(1.0_real64-dry_com)+(1.0_real64-salt_com)+(1.0_real64-frost_com)
      result_reductions(1)=(1.0_real64-wet_com)/red_total*removed
      result_reductions(2)=(1.0_real64-dry_com)/red_total*removed
      result_reductions(3)=(1.0_real64-salt_com)/red_total*removed
      result_reductions(4)=(1.0_real64-frost_com)/red_total*removed
    end if
    was_applied=.true.
  end subroutine source_oracle

  logical function same_bits(left,right)
    real(real64),intent(in)::left,right
    same_bits=transfer(left,0_int64)==transfer(right,0_int64)
  end function same_bits

  logical function same_vector_bits(left,right)
    real(real64),intent(in)::left(:),right(:)
    integer::k
    same_vector_bits=size(left)==size(right)
    if(size(left)/=size(right)) return
    do k=1,size(left)
      if(.not.same_bits(left(k),right(k))) then
        same_vector_bits=.false.
        return
      end if
    end do
  end function same_vector_bits

  subroutine require(condition,message)
    logical,intent(in)::condition
    character(len=*),intent(in)::message
    if(.not.condition) then
      write(*,'(a)') 'PPA_WU05D3_FAIL='//trim(message)
      error stop 1
    end if
  end subroutine require

end program test_ppa_wu05d3_walsum_compensation

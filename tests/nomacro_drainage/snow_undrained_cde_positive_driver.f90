program actual_original_cde_positive_tail
  use, intrinsic :: ieee_arithmetic,only:ieee_is_finite
  use MOD_solute,only:solute_CDE,cmsy,hybrid_cde_probe_input,hybrid_cde_probe_result
  implicit none
  real(8),parameter::masses(9)=[0d0,1d-30,1d-20,2.5d-16,5d-16,1d-15,2d-15,0.04d0,-1d-18]
  real(8),parameter::exponents(3)=[0.5d0,1d0,2d0]
  integer::i,j,count
  character(40)::mode
  logical::original
  call get_command_argument(1,mode)
  original=trim(mode)=='original'
  if(.not.original.and.trim(mode)/='corrected')error stop 'Foreign actual CDE probe mode'
  count=0
  do j=1,size(exponents)
    do i=1,size(masses)
      hybrid_cde_probe_input=[masses(i),exponents(j)]
      call solute_CDE(98)
      if(.not.all(ieee_is_finite([cmsy(1),hybrid_cde_probe_result])))error stop 'Nonfinite actual CDE cell probe'
      if(original.and.masses(i)>0d0.and.masses(i)<1d-15)then
        if(cmsy(1)/=0d0.or.hybrid_cde_probe_result(1)/=2d0*masses(i))error stop 'Original positive mass deletion differs'
        count=count+1
      else if(masses(i)>0d0)then
        if(cmsy(1)/=masses(i).or.hybrid_cde_probe_result(1)/=0d0)error stop 'Positive CDE mass was not preserved'
        if(hybrid_cde_probe_result(2)<=0d0)error stop 'Positive actual CDE concentration missing'
      else
        if(cmsy(1)/=0d0.or.hybrid_cde_probe_result(1)/=2d0*masses(i))error stop 'Original nonpositive behavior changed'
      end if
      write(*,'(a,2(1x,i0),5(1x,es25.17e3))')'ACTUAL_ORIGINAL_CDE_TINY_CELL',i,j, &
        masses(i),exponents(j),cmsy(1),hybrid_cde_probe_result
    end do
  end do
  if(original)then
    if(count/=12)error stop 'Original positive tail cases omitted'
    write(*,'(a)')'REAL_ORIGINAL_CDE_TWELVE_POSITIVE_TAIL_LOSSES_REPRODUCED'
  else
    write(*,'(a)')'REAL_ORIGINAL_CDE_27_POSITIVE_TAIL_AND_UNCHANGED_NONPOSITIVE_CASES_PASS'
  end if
end program

module hybrid_implicit_snow_root_state
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use MOD_grid, only: numnod
  use variables, only: swsolu,swsnow,swhyst,swbotb,swkimpl,alpwetnoddrz,alpdrynodrtz
  implicit none
  private
  public :: implicit_snow_root_checkpoint
contains
  subroutine implicit_snow_root_checkpoint(unit,restoring,clock)
    integer,intent(in)::unit
    logical,intent(in)::restoring
    real(8),intent(in)::clock
    integer::expected(8),header(8),witness(8),ios
    real(8)::values(2),copy(2)
    if(swsolu/=0.or.swsnow/=1.or.swkimpl/=1.or.(swbotb/=5.and.swbotb/=8)) &
      error stop 'Foreign implicit Snow root diagnostic domain'
    expected=[1,numnod,swsolu,swsnow,swhyst,swbotb,swkimpl,0]
    if(restoring)then
      read(unit,iostat=ios)header,witness
      if(ios/=0)error stop 'Incomplete implicit Snow root diagnostic domain'
      if(any(header/=expected).or.any(witness/=expected))error stop 'Foreign implicit Snow root diagnostic witness'
      read(unit,iostat=ios)values,copy
      if(ios/=0)error stop 'Incomplete implicit Snow root diagnostic values'
      if(any(values/=copy).or..not.all(ieee_is_finite(values))) &
        error stop 'Invalid implicit Snow root diagnostic values'
      alpwetnoddrz=values(1)
      alpdrynodrtz=values(2)
    else
      values=[alpwetnoddrz,alpdrynodrtz]
      if(.not.all(ieee_is_finite(values)))error stop 'Nonfinite implicit Snow root diagnostic values'
      write(unit)expected,expected
      write(unit)values,values
      write(*,'(a,3(1x,es25.17e3))')'HYBRID_SNOW_ROOT_NATIVE',clock,values
    end if
  end subroutine
end module

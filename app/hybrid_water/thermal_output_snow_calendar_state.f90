module hybrid_thermal_output_snow_calendar_state
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use MOD_grid, only: numnod
  use MOD_swap_base, only: swmacro,swsolu,swsnow,swhea,swcalt
  use MOD_integral, only: cgsnow,cmelt,csnrai,csubl,isnrai,igsnow,isubl
  implicit none
  private
  public :: snow_output_calendar_checkpoint,snow_output_calendar_apply
  real(8),save :: pending_values(7)=0d0
  logical,save :: restore_pending=.false.
contains
  subroutine snow_output_calendar_checkpoint(unit,restoring)
    integer,intent(in)::unit
    logical,intent(in)::restoring
    integer::expected(4),header(4),witness(4),ios
    real(8)::values(7)
    if(numnod<1.or.swmacro/=0.or.swsolu/=0.or.swsnow/=1.or.swhea/=1.or.swcalt/=2) &
      error stop 'Invalid original Snow output calendar domain'
    expected=[1,numnod,0,7]
    if(restoring)then
      read(unit,iostat=ios)header,witness
      if(ios/=0)error stop 'Incomplete original Snow output calendar domain'
      if(any(header/=expected).or.any(witness/=expected)) &
        error stop 'Foreign original Snow output calendar domain/witness'
      read(unit,iostat=ios)values
      if(ios/=0)error stop 'Incomplete original Snow output calendar totals'
      if(.not.all(ieee_is_finite(values)))error stop 'Nonfinite original Snow output calendar totals'
      if(any(values<0d0))error stop 'Invalid original Snow output calendar totals'
      pending_values=values;restore_pending=.true.
    else
      if(restore_pending)error stop 'Unapplied original Snow output calendar totals'
      write(unit)expected,expected
      write(unit)cgsnow,cmelt,csnrai,csubl,isnrai,igsnow,isubl
    end if
  end subroutine
  subroutine snow_output_calendar_apply()
    if(.not.restore_pending)return
    cgsnow=pending_values(1);cmelt=pending_values(2)
    csnrai=pending_values(3);csubl=pending_values(4)
    isnrai=pending_values(5);igsnow=pending_values(6);isubl=pending_values(7)
    restore_pending=.false.
  end subroutine
end module

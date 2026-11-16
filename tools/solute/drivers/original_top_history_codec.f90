program original_top_history_codec
use MOD_top,only:theatm,katm,q0,hsurf,FlRunoff,ftoph,hybrid_top_checkpoint,hybrid_apply_top
use variables,only:t1900
use MOD_swap_base,only:swmacro
use ieee_arithmetic,only:ieee_value,ieee_quiet_nan
implicit none
integer::unit
character(32)::mode
call get_command_argument(1,mode)
t1900=37409d0;swmacro=0
if(trim(mode)=='consume')then
  open(newunit=unit,file='state.bin',access='stream',form='unformatted',status='old')
  call hybrid_top_checkpoint(unit,.true.)
  close(unit)
  call hybrid_apply_top()
  stop
end if
theatm=.2d0;katm=.001d0;q0=-.03d0;hsurf=-100d0;FlRunoff=.true.;ftoph=.false.
if(trim(mode)=='writer-nan')katm=ieee_value(0d0,ieee_quiet_nan)
if(trim(mode)=='writer-negative')katm=-1d0
open(newunit=unit,file='state.bin',access='stream',form='unformatted',status='replace')
call hybrid_top_checkpoint(unit,.false.)
close(unit)
theatm=.4d0;katm=.002d0;q0=0d0;hsurf=0d0;FlRunoff=.false.;ftoph=.true.
open(newunit=unit,file='state.bin',access='stream',form='unformatted',status='old')
call hybrid_top_checkpoint(unit,.true.)
close(unit)
if(theatm/=.4d0.or.katm/=.002d0)error stop 'Premature top history assignment'
if(trim(mode)=='stale-apply')t1900=t1900+1d0
call hybrid_apply_top()
if(theatm/=.2d0.or.katm/=.001d0.or.q0/=-.03d0.or.hsurf/=-100d0.or..not.FlRunoff.or.ftoph)error stop 'Top history differs'
open(newunit=unit,file='roundtrip.bin',access='stream',form='unformatted',status='replace')
call hybrid_top_checkpoint(unit,.false.)
close(unit)
print *,'ORIGINAL_TOP_HISTORY_EXACT'
end program

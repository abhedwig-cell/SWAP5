program original_oxygen_lookup_codec
use O2_pars,only:d_soil_term1,d_soil_term2,gfp100,Capac_term,Nmin1,Mplus1,ini,hybrid_oxygen_checkpoint,hybrid_apply_oxygen
use variables,only:t1900
use MOD_swap_base,only:swmacro
use MOD_grid,only:numnod
use ieee_arithmetic,only:ieee_value,ieee_quiet_nan
implicit none
integer::unit,j,bytes
character(32)::mode
call get_command_argument(1,mode)
t1900=37780d0;swmacro=0;numnod=3
if(trim(mode)=='consume')then
  open(newunit=unit,file='state.bin',access='stream',form='unformatted',status='old')
  call hybrid_oxygen_checkpoint(unit,.true.)
  close(unit)
  call hybrid_apply_oxygen()
  stop
end if
ini=trim(mode)=='inactive'
d_soil_term1=-777d0;d_soil_term2=-777d0;gfp100=-777d0
Capac_term=-777d0;Nmin1=-777d0;Mplus1=-777d0
do j=1,numnod
  d_soil_term1(j)=1d0+j*.001d0;d_soil_term2(j)=2d0+j*.001d0;gfp100(j)=3d0+j*.001d0
  Capac_term(j)=4d0+j*.001d0;Nmin1(j)=5d0+j*.001d0;Mplus1(j)=6d0+j*.001d0
end do
if(trim(mode)=='writer-nan')gfp100(1)=ieee_value(0d0,ieee_quiet_nan)
if(trim(mode)=='writer-negative')Capac_term(1)=-1d0
if(trim(mode)=='writer-domain')Mplus1(1)=.5d0
open(newunit=unit,file='state.bin',access='stream',form='unformatted',status='replace')
call hybrid_oxygen_checkpoint(unit,.false.)
close(unit)
inquire(file='state.bin',size=bytes)
if(bytes/=merge(24,168,ini))error stop 'Wrong oxygen history size'
d_soil_term1(1:3)=9d0;d_soil_term2(1:3)=9d0;gfp100(1:3)=9d0
Capac_term(1:3)=9d0;Nmin1(1:3)=9d0;Mplus1(1:3)=9d0
ini=.true.
open(newunit=unit,file='state.bin',access='stream',form='unformatted',status='old')
call hybrid_oxygen_checkpoint(unit,.true.)
close(unit)
if(any(d_soil_term1(1:3)/=9d0).or..not.ini)error stop 'Premature oxygen history assignment'
if(trim(mode)=='stale-apply')t1900=t1900+1d0
if(trim(mode)=='grid-apply')numnod=4
call hybrid_apply_oxygen()
if(trim(mode)=='inactive')then
  if(.not.ini)error stop 'Absent oxygen context changed initialization'
else
  if(ini)error stop 'Oxygen initialization flag differs'
  do j=1,3
    if(d_soil_term1(j)/=1d0+j*.001d0.or.d_soil_term2(j)/=2d0+j*.001d0.or.gfp100(j)/=3d0+j*.001d0.or. &
       Capac_term(j)/=4d0+j*.001d0.or.Nmin1(j)/=5d0+j*.001d0.or.Mplus1(j)/=6d0+j*.001d0)error stop 'Oxygen history differs'
  end do
end if
if(any(d_soil_term1(4:)/=-777d0).or.any(d_soil_term2(4:)/=-777d0).or.any(gfp100(4:)/=-777d0).or. &
   any(Capac_term(4:)/=-777d0).or.any(Nmin1(4:)/=-777d0).or.any(Mplus1(4:)/=-777d0))error stop 'Undefined oxygen tails changed'
open(newunit=unit,file='roundtrip.bin',access='stream',form='unformatted',status='replace')
call hybrid_oxygen_checkpoint(unit,.false.)
close(unit)
print *,'ORIGINAL_OXYGEN_LOOKUP_EXACT',bytes
end program

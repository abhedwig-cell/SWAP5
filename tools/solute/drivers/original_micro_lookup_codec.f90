program original_micro_lookup_codec
use MOD_grid,only:numlay
use MOD_swap_base,only:swmacro
use plant_interface,only:icrop,sw_drought,fl_cropemergence
use variables,only:t1900
use mod_RWU_micro,only:M_table,K_table,iMicro,hybrid_micro_checkpoint,hybrid_apply_micro_lookup
use ieee_arithmetic,only:ieee_value,ieee_quiet_nan
implicit none
integer::unit,i,j,bytes
character(32)::mode
call get_command_argument(1,mode)
swmacro=0;numlay=2;icrop=2;sw_drought=3;iMicro=1;t1900=37786d0;fl_cropemergence=.true.
if(trim(mode)=='inactive')then
  icrop=0;sw_drought=0;iMicro=0;fl_cropemergence=.false.
end if
if(trim(mode)=='consume')then
  allocate(M_table(801,2),K_table(801,2));M_table=2d0;K_table=3d0
  open(newunit=unit,file='lookup.bin',access='stream',form='unformatted',status='old')
  call hybrid_micro_checkpoint(unit,.true.)
  close(unit)
  call hybrid_apply_micro_lookup()
  stop
end if
if(fl_cropemergence)then
  allocate(M_table(801,2),K_table(801,2));M_table=-777d0;K_table=-888d0
  do j=1,2
    do i=1,430
      M_table(i,j)=real(i+j,8)*.01d0
    end do
    do i=1,429
      K_table(i,j)=real(2*i+j,8)*.001d0
    end do
  end do
  if(trim(mode)=='invalid-write-nan')M_table(1,1)=ieee_value(0d0,ieee_quiet_nan)
  if(trim(mode)=='invalid-write-negative')K_table(1,1)=-1d0
  if(trim(mode)=='invalid-write-crop')icrop=0
end if
open(newunit=unit,file='lookup.bin',access='stream',form='unformatted',status='replace')
call hybrid_micro_checkpoint(unit,.false.)
close(unit)
inquire(file='lookup.bin',size=bytes)
if(fl_cropemergence)then
  if(bytes/=13788)error stop 'Wrong active microscopic context size'
  M_table(1:430,:)=2d0;K_table(1:429,:)=3d0
else
  if(bytes/=44)error stop 'Wrong absent microscopic context size'
end if
open(newunit=unit,file='lookup.bin',access='stream',form='unformatted',status='old')
call hybrid_micro_checkpoint(unit,.true.)
close(unit)
! A valid read stages state; it must not overwrite tables before original initialization.
if(fl_cropemergence)then
  if(any(M_table(1:430,:)/=2d0).or.any(K_table(1:429,:)/=3d0))error stop 'Premature microscopic assignment'
end if
if(trim(mode)=='changed-apply-crop')icrop=3
if(trim(mode)=='changed-apply-model')iMicro=2
if(trim(mode)=='changed-apply-clock')t1900=t1900+1d0
if(trim(mode)=='uninitialized-apply')deallocate(M_table,K_table)
call hybrid_apply_micro_lookup()
if(fl_cropemergence)then
  do j=1,2
    do i=1,430
      if(M_table(i,j)/=real(i+j,8)*.01d0)error stop 'Microscopic M context differs'
    end do
    do i=1,429
      if(K_table(i,j)/=real(2*i+j,8)*.001d0)error stop 'Microscopic K context differs'
    end do
  end do
  if(any(M_table(431:801,:)/=-777d0).or.any(K_table(430:801,:)/=-888d0))error stop 'Undefined tails were changed'
end if
open(newunit=unit,file='lookup-roundtrip.bin',access='stream',form='unformatted',status='replace')
call hybrid_micro_checkpoint(unit,.false.)
close(unit)
print *,'ORIGINAL_MICRO_LOOKUP_CODEC_EXACT',bytes
end program

program actual_implicit_frost_root_native
  use, intrinsic::ieee_arithmetic,only:ieee_value,ieee_quiet_nan
  use MOD_grid,only:numnod
  use MOD_swap_base,only:swsolu,swsnow,swhyst,swfrost,swdra
  use variables,only:swbotb,swkimpl
  use MOD_re_global,only:alpwetnoddrz,alpdrynodrtz
  use hybrid_implicit_frost_root_state,only:implicit_frost_root_checkpoint
  implicit none
  integer::unit,kind,ios
  character(len=40)::attack,argument
  character(len=95)::shorter
  real(8)::invalid
  call get_command_argument(1,argument);read(argument,*)kind
  call get_command_argument(2,attack)
  numnod=3;swsolu=kind;swsnow=1;swhyst=2;swfrost=1;swdra=1;swbotb=6;swkimpl=1
  alpwetnoddrz=0.25d0;alpdrynodrtz=0.875d0
  open(newunit=unit,file='root-native.bin',status='replace',access='stream',form='unformatted',action='readwrite')
  call implicit_frost_root_checkpoint(unit,.false.,123d0)
  flush(unit)
  select case(trim(attack))
  case('header')
    write(unit,pos=1)99
    write(unit,pos=33)99
  case('witness')
    write(unit,pos=33)99
  case('value-witness')
    write(unit,pos=81)0.5d0
  case('nonfinite')
    invalid=ieee_value(0d0,ieee_quiet_nan)
    write(unit,pos=65)invalid,0.875d0,invalid,0.875d0
  case('truncated')
    rewind(unit);read(unit)shorter;close(unit)
    open(newunit=unit,file='root-native.bin',status='replace',access='stream',form='unformatted',action='readwrite')
    write(unit)shorter
  case('bad-frost')
    swfrost=0
  case('bad-bottom')
    swbotb=5
  case('roundtrip')
  case default
    error stop 'Unknown native driver input'
  end select
  flush(unit);rewind(unit)
  alpwetnoddrz=-7d0;alpdrynodrtz=-9d0
  call implicit_frost_root_checkpoint(unit,.true.,123d0)
  if(trim(attack)/='roundtrip')error stop 'Invalid native input accepted by actual provider'
  if(alpwetnoddrz/=0.25d0.or.alpdrynodrtz/=0.875d0)error stop 'Original retained diagnostic values not restored'
  read(unit,iostat=ios)argument(1:1)
  if(ios==0)error stop 'Unexpected extra native provider bytes'
  close(unit)
  write(*,'(a,1x,i0,2(1x,es25.17e3))')'ACTUAL_FROST_ROOT_NATIVE_ROUNDTRIP_PASS',kind,alpwetnoddrz,alpdrynodrtz
end program

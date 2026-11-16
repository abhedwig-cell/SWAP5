program original_runon_reader
  use MOD_runon,only: read_runon,runontim,runonflx,runon_rec
  use MOD_swap_base,only: unit_swp,unit_err,unit_log,swpfilnam,pathrunon,swrunon
  use variables,only:tstart,tend
  use,intrinsic::ieee_arithmetic,only:ieee_is_finite
  implicit none
  character(64)::argument
  integer::i
  call get_command_argument(1,argument)
  read(argument,*)tstart
  tend=37263d0
  unit_swp=810;unit_err=21;unit_log=6
  swpfilnam='reader.swp';pathrunon='';swrunon=1
  open(unit_err,file='reader.err',status='replace')
  call read_runon()
  if(runon_rec/=1)error stop 'Invalid original initial runon cursor'
  if(.not.all(ieee_is_finite(runontim)).or..not.all(ieee_is_finite(runonflx)))error stop 'Nonfinite original runon input'
  open(812,file='values.txt',status='replace')
  do i=1,size(runontim)
    if(runontim(i)>0d0)write(812,'(2ES26.17)')runontim(i),runonflx(i)
  end do
  close(812)
end program

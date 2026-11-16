program original_fixed_irrigation_reader
  use MOD_irrigation
  use MOD_swap_base,only:unit_swp,unit_err,unit_log,swpfilnam,pathwork,swsolu,swirfix,swinco
  use MOD_grid,only:numnod,zbotcp
  use variables,only:tstart,tend,t1900
  implicit none
  character(64)::argument
  integer::i,cursor
  call get_command_argument(1,argument);read(argument,*)tstart
  call get_command_argument(2,argument);read(argument,*)swsolu
  call get_command_argument(3,argument);read(argument,*)swinco
  tend=37266d0;unit_swp=810;unit_err=21;unit_log=6;swpfilnam='reader.swp';pathwork=''
  swirfix=1;schedule=0;numnod=4;zbotcp(1:4)=[-5d0,-20d0,-50d0,-100d0]
  call get_command_argument(4,argument)
  if(trim(argument)=='shallow')zbotcp(1:4)=[-5d0,-10d0,-20d0,-30d0]
  irtype=0;irdate=0d0;irrate=0d0;irdepth=0d0;irconc=0d0;nod_ssdi=0;ir_z=0d0
  open(unit_err,file='reader.err',status='replace')
  call rdinit(unit_swp,unit_err,swpfilnam)
  call read_irrigation_fixed()
  cursor=nirri
  t1900=tstart
  if(tstart<=irdate(2))then
    t1900=irdate(1)
    nirri=1
  end if
  call irrigation(3)
  open(812,file='values.txt',status='replace')
  write(812,'(6I8)')cursor,irtype(1),nod_ssdi,swsolu,swinco
  write(812,'(12ES26.17)')irdate(1:2),irdepth(1:2),irrate(1:2),irconc(1:2),gird,qssdisum,cirr,dt_irr_event
  close(812)
end program

program actual_original_divdra_overlap
  use MOD_arrays,only:macp
  use MOD_grid,only:numnod,dz,layer,zbotcp
  use MOD_drain,only:nrlevs,swdivd,swdivdinf,swdislay,swnrsrf,swtopnrsrf,swtopdislay, &
      cofani,facdpthinf,Lspacing,zbotdr,drainl,qdra,qdrain,qdrtot,divdra,dramet
  implicit none
  real(8)::conductivity(macp),water_depth,channel_depth,spacing
  character(32)::argument
  if(command_argument_count()/=3)error stop 'Actual Divdra component requires three input levels'
  call get_command_argument(1,argument);read(argument,*)water_depth
  call get_command_argument(2,argument);read(argument,*)channel_depth
  call get_command_argument(3,argument);read(argument,*)spacing
  if(.not.any(water_depth==[45d0,50d0,55d0]).or..not.any(channel_depth==[5d0,35d0]) &
      .or..not.any(spacing==[40d0,400d0]))error stop 'Foreign actual Divdra component input'
  numnod=4;nrlevs=1;swdivd=1;swdivdinf=1;swdislay=0
  swnrsrf=0;swtopnrsrf=0;swtopdislay=0;facdpthinf=0.5d0;dramet=1
  dz(1:4)=[10d0,20d0,40d0,60d0];zbotcp(1:4)=[-10d0,-30d0,-70d0,-130d0]
  layer(1:4)=1;conductivity=1d0;cofani(1)=1d0
  Lspacing(1)=spacing;zbotdr(1)=-80d0;drainl(1)=-channel_depth
  qdra=0d0;qdrain=0d0;qdrain(1)=-0.03d0;qdrtot=qdrain(1)
  call divdra(conductivity,-water_depth)
  write(*,'(a,*(1x,es25.17e3))')'ACTUAL_DIVDRA_OVERLAP_OUTPUT', &
    water_depth,channel_depth,spacing,qdrain(1),qdra(1,1:4)
end program

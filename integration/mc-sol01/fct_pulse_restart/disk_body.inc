 call get_command_argument(4,mode)
 call get_command_argument(5,input_path)
 call get_command_argument(6,output_path)
 call get_command_argument(7,arg);read(arg,*)stop_window
 model%dz_cm=dz
 if(trim(mode)=='wrong_parameters')model%decpot(1)=model%decpot(1)+.01d0
 if(trim(mode)/='full')then
  call read_research_payload(trim(input_path),column,cfg%tiles(1)%template,cfg%tiles(1)%parameters%parameter_set_id, &
   model,loaded_water,loaded_chem,code)
  if(trim(mode)=='reject'.or.trim(mode)=='wrong_parameters')then
   if(code==0.or.loaded_water%ready().or.allocated(loaded_chem%water))error stop 'invalid disk state published'
   print '(A)','RESTORE_REJECTED_BOTH_TARGETS_EMPTY';stop
  end if
  if(code/=0)error stop 'disk restore'
  water=loaded_water;chem=loaded_chem
 end if
 if(stop_window<1.or.stop_window>4.or.chem%clock>stop_window*.1d0)error stop 'disk window'
 do i=nint(chem%clock/.1d0)+1,stop_window
  call run_research_joint_fct(backend,column,cfg%tiles(1)%template,cfg%tiles(1)%parameters,water, &
   cfg%tiles(1)%base_forcing,cfg%numerical,chem,model,i*.1d0,jr)
  if(jr%status/=RESEARCH_JOINT_OK)error stop 'disk joint'
  print '(A,1X,2(I0,1X),5(ES25.16E3,1X))','WINDOW',i,jr%substeps,jr%ledger
 end do
 call write_research_payload(trim(output_path)//'/payload.bin',column,cfg%tiles(1)%template, &
  cfg%tiles(1)%parameters%parameter_set_id,water,chem,model,code)
 if(code/=0)error stop 'disk export'
 print '(A,1X,I0,1X,ES25.16E3,1X,I0)','DISK_RUN_PASS',nodes,chem%clock,water%current_revision()
end program

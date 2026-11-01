! Same actual accepted inputs through the real original and current owners.
program hupsel_paired_uptake
 use iso_fortran_env,only:real64
 use MOD_grid,only:numnod,numlay,layer,nod1lay,dz
 use MOD_MvG,only:cofgen,iHWCKmodel,swsophy,fl_use_tables,calc_cofgen_extra,set_cofgen_pointers,watcon
 use variables,only:h,theta,indeks,ksatfit
 use MOD_swap_base,only:swhyst,fl_do_not_read_crpfile,unit_log,unit_err
 use atmosphere_interface,only:tav
 use plant_interface,only:c_mroot,f_senes,q10_root,max_resp_factor
 use MOD_cropdevelopment,only:srl,wroot_node_top,q10_microbial,specific_resp_humus, &
   campbell_h100,campbell_h500,gfp_h100,rootradius_m
 use MOD_texture_orgmat,only:orgmat,psand,bdens
 use MOD_SoilTemperature,only:tsoil
 use O2_pars,only:c_top
 use mod_RWU_micro,only:RWU_micro,get_MFLP_K,UpwPot,swDoSatRel,swHydrLift,swO2ECT,swTypeTred, &
   RootRadius,Kroot,Lstem_A0,Lstem_A1,PLhalf,CampA,Tol_2,myTolX,TolConv,factor,Ntrial,iMicro
 use mod_bartholomeus_parameter_contract
 use mod_bartholomeus_runtime_input
 use mod_bartholomeus_factor_provider
 use mod_bartholomeus_waterfilm_provider,only:BARTHOLOMEUS_WATERFILM_REFERENCE
 use mod_b110_default_mvg_provider,only:b110_default_mvg_parameters_t,initialize_b110_default_mvg_parameters
 use mod_root_micro_matric_flux_table,only:micro_matric_flux_table_t
 use mod_fmr_micro_mvg_table_binding,only:fmr_build_micro_mvg_tables
 use mod_root_micro_de_willigen_process
 implicit none
 type(bartholomeus_runtime_view_t)::view
 type(BartholomeusImmutableDataset)::data
 type(BartholomeusCropParameters)::crop
 type(b110_default_mvg_parameters_t)::hydraulics
 type(micro_matric_flux_table_t),allocatable::tables(:)
 type(micro_de_willigen_parameters_t)::parameters,tighter
 type(micro_de_willigen_result_t)::current,tight
 real(real64)::t0,t1,demand,source_alpha,tact,tact1,tact2,potential_node
 real(real64)::w100(34),w500(34),organic(34),sand(34),density(34),lrv(34),oxygen(34),salinity(34)
 real(real64)::observed(34),source_sink(34),original_oxygen(34),wr(34),input(24,34)
 real(real64),allocatable::factors(:)
 real(real64)::oxygen_error,replay_error,nodal_error,total_error,tight_nodal_error,tight_total_error
 integer::unit,node,index,rooted,io,record,first(34),status
 logical::ok,check(3)
 character(4096)::filename
 call get_command_argument(1,filename);open(newunit=unit,file=trim(filename),status='old',action='read')
 record=0;allocate(UpwPot(34));cofgen=0d0
 ! Actual observed parameters replace the original crop-file reader in this
 ! component harness; retain its real mathematical owner unchanged.
 fl_do_not_read_crpfile=.true.;unit_log=6;unit_err=6
 print '(a)','case,t0,t1,demand,observed_uptake,source_uptake,tight_uptake,oxygen_max_error,current_replay_error,source_current_nodal_error,source_current_total_error,source_tight_nodal_error,source_tight_total_error,source_checks,tight_status'
 do
  read(unit,*,iostat=io)t0,t1,numnod,rooted,demand
  if(io<0)exit
  if(io/=0.or.numnod/=34.or.rooted<1.or.rooted>34)error stop 'invalid actual input header'
  record=record+1
  read(unit,*)parameters%root_radius_cm,parameters%root_conductance_cm_per_day,parameters%stem_a0_per_day, &
   parameters%stem_a1_per_cm,parameters%half_leaf_pressure_cm,parameters%campbell_exponent, &
   parameters%pressure_tolerance_cm,parameters%newton_tolerance_cm,parameters%residual_tolerance_cm_per_day, &
   parameters%max_iterations,parameters%oxygen_mode,parameters%reduction_mode
  read(unit,*)crop%c_mroot,crop%f_senes,crop%q10_root,crop%specific_resp_humus,crop%q10_microbial, &
   crop%microbial_shape_m,crop%root_shape_m,crop%root_radius_m,crop%max_resp_factor
  read(unit,*)tav,srl
  do node=1,34
   read(unit,*)index,first(node),dz(node),h(node),theta(node),tsoil(node),input(:,node), &
     lrv(node),oxygen(node),salinity(node),observed(node),potential_node,wroot_node_top(node), &
     organic(node),sand(node),density(node)
   if(index/=node)error stop 'actual node order'
  end do
  numlay=0
  do node=1,34
   if(first(node)==node)then
    numlay=numlay+1;nod1lay(numlay)=node
    orgmat(numlay)=organic(node);psand(numlay)=sand(node);bdens(numlay)=density(node)
    ksatfit(numlay)=input(3,node)
   end if
   if(first(node)/=nod1lay(numlay))error stop 'actual horizon map'
   layer(node)=numlay
  end do
  cofgen(1:24,1:34)=input
  swsophy=0;swhyst=0;iHWCKmodel=1;indeks=-1;fl_use_tables=.false.
  call set_cofgen_pointers();call calc_cofgen_extra(34)
  campbell_h100=-100d0;campbell_h500=-500d0;gfp_h100=-100d0
  do node=1,34
   w100(node)=watcon(node,-100d0);w500(node)=watcon(node,-500d0)
  end do
  call construct_bartholomeus_dataset(input,dz(:34),organic,sand,density,w100,w500,w100,-100d0,-500d0,0,data,ok)
  if(.not.ok)error stop 'paired immutable oxygen dataset'
  c_mroot=crop%c_mroot;f_senes=crop%f_senes;q10_root=crop%q10_root;max_resp_factor=crop%max_resp_factor
  rootradius_m=crop%root_radius_m;q10_microbial=crop%q10_microbial;specific_resp_humus=crop%specific_resp_humus
  view%rooted_nodes=rooted;view%pressure_head_cm=h(:rooted);view%water_content=theta(:rooted)
  view%soil_temperature_k=tsoil(:rooted)+273d0;wr=1d0/srl;c_top=0d0
  do node=1,rooted
   call OxygenStress(node,original_oxygen(node))
  end do
  call evaluate_bartholomeus_factors_from_state(view,data,crop,wr(:rooted),wroot_node_top(:rooted), &
   672d0/(8.314472d0*(tav+273d0)),BARTHOLOMEUS_WATERFILM_REFERENCE,factors,ok)
  if(.not.ok)error stop 'paired typed oxygen rejected'
  oxygen_error=max(maxval(abs(original_oxygen(:rooted)-factors)),maxval(abs(factors-oxygen(:rooted))))
  call initialize_b110_default_mvg_parameters(hydraulics,input)
  call fmr_build_micro_mvg_tables(hydraulics,tables,ok,first)
  if(.not.ok)error stop 'actual microscopic table binding'
  call evaluate_micro_de_willigen(parameters,h(:34),dz(:34),lrv,oxygen*salinity,rooted,demand,tables,current)
  if(current%status/=MICRO_DW_OK)error stop 'actual current replay rejected'
  replay_error=maxval(abs(current%root_extraction_sink-observed))
  if(replay_error>1d-12)error stop 'current same-input replay differs from observed accepted sink'
  RootRadius=parameters%root_radius_cm;Kroot=parameters%root_conductance_cm_per_day
  Lstem_A0=parameters%stem_a0_per_day;Lstem_A1=parameters%stem_a1_per_cm
  PLhalf=1d0/parameters%half_leaf_pressure_cm;CampA=parameters%campbell_exponent
  Tol_2=parameters%pressure_tolerance_cm;myTolX=parameters%newton_tolerance_cm
  TolConv=parameters%residual_tolerance_cm_per_day;factor=1.25d0;Ntrial=parameters%max_iterations
  iMicro=1;swDoSatRel=0;swHydrLift=0;swO2ECT=parameters%oxygen_mode;swTypeTred=parameters%reduction_mode
  call get_MFLP_K(1)
  call RWU_micro(1,1,rooted,dz(:34),h(:34),lrv,oxygen*salinity,.false.,demand,tact,source_sink,source_alpha,tact1,tact2,check)
  call RWU_micro(2,1,rooted,dz(:34),h(:34),lrv,oxygen*salinity,.false.,demand,tact,source_sink,source_alpha,tact1,tact2,check)
  nodal_error=maxval(abs(source_sink(:rooted)-observed(:rooted)))
  total_error=sum(observed)-sum(source_sink(:rooted))
  tighter=parameters;tighter%residual_tolerance_cm_per_day=min(TolConv,Tol_2)
  call evaluate_micro_de_willigen(tighter,h(:34),dz(:34),lrv,oxygen*salinity,rooted,demand,tables,tight)
  tight_nodal_error=-1d0;tight_total_error=-1d0
  if(tight%status==MICRO_DW_OK)then
   tight_nodal_error=maxval(abs(source_sink(:rooted)-tight%root_extraction_sink(:rooted)))
   tight_total_error=tight%actual_uptake_total-sum(source_sink(:rooted))
  end if
  print '(i0,12(a,es25.17e3),a,i0,a,i0)',record,',',t0,',',t1,',',demand,',',sum(observed), &
   ',',sum(source_sink(:rooted)),',',merge(tight%actual_uptake_total,-1d0,tight%status==MICRO_DW_OK), &
   ',',oxygen_error,',',replay_error,',',nodal_error,',',total_error,',',tight_nodal_error,',',tight_total_error, &
   ',',count(check),',',tight%status
  deallocate(tables,factors)
 end do
 close(unit)
 if(record==0)error stop 'no accepted observations'
end program

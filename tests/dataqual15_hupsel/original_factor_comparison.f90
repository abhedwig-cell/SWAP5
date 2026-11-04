program original_factor_comparison
 use iso_fortran_env,only:real64
 use MOD_grid
 use MOD_MvG
 use variables
 use atmosphere_interface
 use plant_interface
 use MOD_cropdevelopment
 use MOD_texture_orgmat
 use MOD_SoilTemperature
 use O2_pars,only:c_top,waterfilm_thickness
 use mod_bartholomeus_parameter_contract
 use mod_bartholomeus_runtime_input
 use mod_bartholomeus_factor_provider
 use mod_bartholomeus_waterfilm_provider,only:BARTHOLOMEUS_WATERFILM_REFERENCE,evaluate_bartholomeus_waterfilm
 implicit none
 type(BartholomeusImmutableDataset)::dataset
 type(BartholomeusCropParameters)::crop
 type(bartholomeus_runtime_view_t)::view
 real(8)::x(41,34),original(34),w100(34),w500(34),wr(34),original_film(34)
 real(8),allocatable::current(:),film(:)
 integer::i,n,io,record,u,status
 logical::ok
 character(4096)::name
 call get_command_argument(1,name);open(newunit=u,file=trim(name),status='old')
 record=0
 do
  read(u,*,iostat=io)x(:,1)
  if(io<0)exit
  if(io/=0)error stop 'invalid first original node'
  do i=2,34
   read(u,*,iostat=io)x(:,i)
   if(io/=0)error stop 'missing original forcing node'
  end do
  record=record+1;n=nint(x(11,1));if(n<1.or.n>34)error stop 'root count'
  do i=1,34
   if(nint(x(10,i))/=i)error stop 'node ordering'
   layer(i)=i;h(i)=x(12,i);theta(i)=x(13,i);tsoil(i)=x(14,i)
   wroot_node_top(i)=x(16,i);cofgen(:,i)=0d0;cofgen(1:7,i)=x(22:28,i);dz(i)=x(29,i)
   orgmat(i)=x(30,i);psand(i)=x(31,i);bdens(i)=x(32,i)
   w100(i)=watcon(i,-100d0);w500(i)=watcon(i,-500d0);wr(i)=x(15,i)
  end do
  srl=1d0/x(15,1);tav=x(21,1);c_mroot=x(33,1);f_senes=x(34,1);q10_root=x(35,1)
  specific_resp_humus=x(36,1);q10_microbial=x(37,1);rootradius_m=x(40,1);max_resp_factor=x(41,1)
  c_top=0d0
  do i=1,n
   call OxygenStress(i,original(i))
   original_film(i)=waterfilm_thickness
  end do
  crop%c_mroot=c_mroot;crop%f_senes=f_senes;crop%q10_root=q10_root
  crop%specific_resp_humus=specific_resp_humus;crop%q10_microbial=q10_microbial
  crop%microbial_shape_m=x(38,1);crop%root_shape_m=x(39,1);crop%root_radius_m=rootradius_m
  crop%max_resp_factor=max_resp_factor
  call construct_bartholomeus_dataset(cofgen,dz,orgmat,psand,bdens,w100,w500,w100,-100d0,-500d0,0,dataset,ok)
  if(.not.ok)error stop 'actual original soil contract'
  view%rooted_nodes=n;view%pressure_head_cm=h(:n);view%water_content=theta(:n);view%soil_temperature_k=tsoil(:n)+273d0
  call evaluate_bartholomeus_factors_from_state(view,dataset,crop,wr(:n),wroot_node_top(:n), &
   x(20,1),BARTHOLOMEUS_WATERFILM_REFERENCE,current,ok)
  if(.not.ok)error stop 'actual original current factor refusal'
  call evaluate_bartholomeus_waterfilm(view,dataset,BARTHOLOMEUS_WATERFILM_REFERENCE,film,status)
  if(status/=0)error stop 'actual original waterfilm refusal'
  do i=1,n
   write(*,'(i0,1x,i0,7(1x,es25.17e3))')record,i,x(1,1),x(2,1),original(i),current(i),x(19,i),original_film(i),film(i)
  end do
  deallocate(current,dataset%soil,film)
 end do
 if(record==0)error stop 'empty original forcing'
end program

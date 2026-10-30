! Read identical observed inputs through both real oxygen implementations.
program grass_stress_oracle
 use iso_fortran_env,only:real64
 use MOD_grid,only:numnod,layer,dz
 use MOD_MvG,only:cofgen,iHWCKmodel,swsophy,fl_use_tables,calc_cofgen_extra,set_cofgen_pointers,watcon
 use variables,only:h,theta,indeks
 use MOD_swap_base,only:swhyst
 use atmosphere_interface,only:tav
 use plant_interface,only:c_mroot,f_senes,q10_root,max_resp_factor
 use MOD_cropdevelopment,only:srl,wroot_node_top,q10_microbial,specific_resp_humus, &
   campbell_h100,campbell_h500,gfp_h100,rootradius_m
 use MOD_texture_orgmat,only:orgmat,psand,bdens
 use MOD_SoilTemperature,only:tsoil
 use O2_pars,only:c_top
 use mod_bartholomeus_runtime_input
 use mod_bartholomeus_parameter_contract
 use mod_bartholomeus_factor_provider
 use mod_bartholomeus_waterfilm_provider,only:BARTHOLOMEUS_WATERFILM_REFERENCE
 implicit none
 type(bartholomeus_runtime_view_t)::view
 type(BartholomeusImmutableDataset)::data
 type(BartholomeusCropParameters)::crop
 real(real64),allocatable::w100(:),w500(:),organic(:),sand(:),density(:),fraction(:),original(:),factors(:),wr(:)
 real(real64)::demand_dry,demand_wet,worst
 integer::unit,node,index,rooted
 logical::ok
 character(2048)::path
 call get_command_argument(1,path)
 open(newunit=unit,file=trim(path),status='old',action='read')
 read(unit,*)numnod,rooted
 if(numnod/=113.or.rooted<1.or.rooted>numnod)error stop 'observed original geometry'
 read(unit,*)crop%c_mroot,crop%f_senes,crop%q10_root,crop%specific_resp_humus,crop%q10_microbial, &
   crop%microbial_shape_m,crop%root_shape_m,crop%root_radius_m,crop%max_resp_factor
 read(unit,*)tav,srl,demand_dry,demand_wet
 allocate(w100(numnod),w500(numnod),organic(numnod),sand(numnod),density(numnod),fraction(numnod))
 do node=1,numnod
  read(unit,*)index,layer(node),dz(node),h(node),theta(node),tsoil(node),cofgen(1:12,node), &
    organic(node),sand(node),density(node),fraction(node),wroot_node_top(node)
  if(index/=node)error stop 'observation order'
  orgmat(layer(node))=organic(node);psand(layer(node))=sand(node);bdens(layer(node))=density(node)
 end do
 close(unit)
 swsophy=0;swhyst=0;iHWCKmodel=1;indeks=-1;fl_use_tables=.false.
 call set_cofgen_pointers();call calc_cofgen_extra(numnod)
 campbell_h100=-100d0;campbell_h500=-500d0;gfp_h100=-100d0
 do node=1,numnod
  w100(node)=watcon(node,-100d0);w500(node)=watcon(node,-500d0)
 end do
 call construct_bartholomeus_dataset(cofgen(:,:numnod),dz(:numnod),organic,sand,density, &
   w100,w500,w100,-100d0,-500d0,0,data,ok)
 if(.not.ok)error stop 'observed immutable dataset'
 c_mroot=crop%c_mroot;f_senes=crop%f_senes;q10_root=crop%q10_root;max_resp_factor=crop%max_resp_factor
 rootradius_m=crop%root_radius_m
 q10_microbial=crop%q10_microbial;specific_resp_humus=crop%specific_resp_humus
 view%rooted_nodes=rooted;view%pressure_head_cm=h(:rooted);view%water_content=theta(:rooted)
 view%soil_temperature_k=tsoil(:rooted)+273d0
 allocate(original(rooted),wr(rooted));wr=1d0/srl;c_top=0d0
 do node=1,rooted
  call OxygenStress(node,original(node))
 end do
 call evaluate_bartholomeus_factors_from_state(view,data,crop,wr,wroot_node_top(:rooted), &
   672d0/(8.314472d0*(tav+273d0)),BARTHOLOMEUS_WATERFILM_REFERENCE,factors,ok)
 if(.not.ok)error stop 'current paired oxygen rejected'
 print '(a)','node,head_cm,theta,temperature_c,root_fraction,root_density_kg_m3,original_factor,current_factor,difference'
 do node=1,rooted
  print '(i0,8(a,es25.17e3))',node,',',h(node),',',theta(node),',',tsoil(node),',',fraction(node), &
   ',',wroot_node_top(node),',',original(node),',',factors(node),',',factors(node)-original(node)
 end do
 worst=maxval(abs(original-factors))
 ! The existing assembled oracle uses 1e-4 to reflect the original SOLVE
 ! accuracy. This bounds the paired oxygen component, not whole crop yield.
 print '(a,es25.17e3)','PAIRED_MAX_FACTOR_DIFFERENCE ',worst
 print '(a,2(es25.17e3,1x))','PAIRED_ROOT_WEIGHTED_FACTORS ', &
   sum(fraction(:rooted)*original),sum(fraction(:rooted)*factors)
 if(worst>1d-4)error stop 'paired oxygen differs beyond existing source SOLVE gate'
 print '(a)','PAIRED_ORIGINAL_CURRENT_OXYGEN_PASS'
end program

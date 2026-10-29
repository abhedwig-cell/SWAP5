program grass_profile_input_driver
 use iso_fortran_env,only:real64
 use mod_column_swp_water
 use mod_b110_default_mvg_provider
 implicit none
 real(real64)::width(256),pond,gwli,start,source_gwl,times(1000),levels(1000),flat(2000),afgen
 real(real64),allocatable::heads(:),cofgen(:,:),theta(:),conductivity(:),capacity(:),derivative(:)
 type(b110_default_mvg_parameters_t),target::parameters
 type(b110_default_mvg_provider_t)::provider
 integer::nodes,n,mode,i
 character(1024)::swp,option
 logical::selected
 call get_command_argument(1,swp);call get_command_argument(2,option)
 selected=trim(option)=='groundwater'
 call rdinit(72,0,trim(swp));call rdstim('tstart',start);close(72)
 call rdinit(72,0,'swap.bbc');call rdsinr('swbotb',1,8,mode)
 if(mode/=1)error stop 'original groundwater table mode'
 call rdatim('date1',times,1000,n);call rdfdor('gwlevel',-10000d0,1000d0,levels,1000,n);close(72)
 if(start+1d0>=times(1))error stop 'source initial epoch fixture domain'
 do i=1,n
  flat(2*i-1)=times(i);flat(2*i)=levels(i)
 end do
 source_gwl=afgen(flat,2*n,start-1d0)
 call import_column_swp_water(trim(swp),nodes,width,heads,cofgen,pond,initial_bottom_mode=1, &
      source_groundwater=gwli,allow_ksatexm=.true.,allow_prescribed_groundwater=selected,initial_groundwater_cm=source_gwl)
 if(gwli/=-88d0.or.sum(width(:nodes))/=600d0.or.pond/=0d0)error stop 'original Grassgrowth identity'
 call initialize_b110_default_mvg_parameters(parameters,cofgen,enable_ksatexm_extension=.true.)
 call bind_b110_default_mvg_provider(provider,parameters,.01d0)
 allocate(theta(nodes),conductivity(nodes),capacity(nodes),derivative(nodes))
 call provider%evaluate(heads,theta,conductivity,capacity,derivative)
 if(abs(sum(theta*width(:nodes))-217.02d0)>.005d0)error stop 'original rounded initial balance'
 write(*,*)'ORIGINAL_GRASS_PROFILE_IMPORTED',nodes,sum(width(:nodes)),gwli,sum(theta*width(:nodes))
end program

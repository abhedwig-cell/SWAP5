program original_potato_owner_input
 use iso_fortran_env,only:real64
 use mod_hupsel_potato
 use mod_hupsel_rotation_restart,only:peek_hupsel_rotation_clock
 use mod_wofost_crop_native_codec,only:serialize_wofost_crop_view
 use mod_fmr_wofost_crop_transaction,only:fmr_wofost_crop_transaction_persistence_t
 use mod_fmr_serialized_reference_backend
 use mod_column_swp_water
 use solute_column_context,only:initialize_column_context
 use MOD_grid,only:z,dz,disnod
 implicit none
 type(potato_crop_t)::crop
 type(fmr_b110_physical_parameters_t)::p
 real(real64)::width(256),pond
 real(real64),allocatable::head(:),cofgen(:,:)
 type(fmr_wofost_crop_transaction_persistence_t)::view,restored
 character(16)::argument
 logical::grass
 integer::nodes,code,u
 call import_column_swp_water('swap.swp',nodes,width,head,cofgen,pond,initial_bottom_mode=6,allow_ksatexm=.true.)
 call initialize_column_context(width(:nodes))
 p%active_nodes=nodes;p%z=z;p%dz=dz;p%node_distance=disnod(:nodes);p%cofgen=cofgen
 p%ksatexm_extension_active=any(cofgen(10,:)>cofgen(3,:))
 call get_command_argument(1,argument);grass=trim(argument)=='grass'
 if(grass)then
  call crop%initialize('swap.swp','grass.crp',p,code,grass_mode=.true.)
 else
  call crop%initialize('swap.swp','potato.crp',p,code)
 end if
 if(code/=0)then;print *,'ORIGINAL_POTATO_INITIALIZATION_REJECTED',code;error stop 1;end if
 if(.not.crop%state%ready().or..not.crop%parameters%ready())error stop 'potato owner not ready'
 call crop%export_state(view,code);if(code/=0)error stop 'native crop export'
 if(grass)then
  if(crop%crop_start/=730d0.or.crop%crop_end/=1095d0.or.crop%next_crop_start/=1096d0)error stop 'original grass calendar'
  if(.not.view%grass_management_present.or..not.view%lifecycle%emerged)error stop 'grass source initialization'
  if(crop%grass_parameters%sequence_length/=20.or.crop%grass_parameters%max_growing_days/=42)error stop 'grass mowing source'
  if(crop%grass_parameters%mowing_residual/=700d0.or.crop%micro%half_leaf_pressure_cm/=16000d0)error stop 'grass physical source'
  call crop%restore_state(view,code);if(code/=0)error stop 'grass typed reconstruction'
  print *,'ORIGINAL_HUPSEL_GRASS_TYPED_SOURCE_OWNER_PASS',nodes,crop%crop_start,crop%crop_end,crop%next_crop_start
 end if
 open(newunit=u,file='potato-owner-v3.bin',access='stream',form='unformatted',status='replace')
 call serialize_wofost_crop_view(u,.false.,view,code,source_clipped_schema=.true.,grass_schema=grass);close(u)
 if(code/=0)error stop 'native crop encode'
 open(newunit=u,file='potato-owner-v3.bin',access='stream',form='unformatted',status='old')
 call serialize_wofost_crop_view(u,.true.,restored,code,source_clipped_schema=.true.,grass_schema=grass);close(u)
 if(code/=0)error stop 'native crop decode'
 call crop%restore_state(restored,code);if(code/=0)error stop 'native crop reconstruction'
 open(newunit=u,file='potato-owner-v3-roundtrip.bin',access='stream',form='unformatted',status='replace')
 call serialize_wofost_crop_view(u,.false.,restored,code,source_clipped_schema=.true.,grass_schema=grass);close(u)
 if(code/=0)error stop 'native crop roundtrip'
 if(restored%grass_management_present.neqv.grass)error stop 'grass native schema presence'
 print *,'ORIGINAL_CROP_OWNER_NATIVE_CODEC_PASS',grass
 print *,'ORIGINAL_HUPSEL_POTATO_TYPED_OWNERS_READY',nodes,crop%crop_start,crop%crop_end,crop%next_crop_start
end program

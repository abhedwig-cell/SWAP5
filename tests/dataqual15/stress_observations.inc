 subroutine write_stress_observation(day)
  integer,intent(in)::day
  class(transaction_state_t),allocatable::state
  type(soil_temperature_field_view_t)::thermal
  logical::ok
  integer::status,unit,node
  real(real64)::fraction,density_root
  character(64)::filename
  if(.not.any(day==[25,72,73,127]))return
  call water%snapshot(state,ok);call require(ok,'stress observation snapshot')
  select type(s=>state)
  type is(fmr_b110_boesten_evaporation_state_t)
   call build_soil_temperature_field_view(s%soil_temperature,thermal,status)
   call require(status==0,'stress observation temperature')
   write(filename,'(a,i0,a)')'stress-input-',day,'.dat'
   open(newunit=unit,file=trim(filename),status='replace',action='write')
   write(unit,*)nodes,rooted
   associate(c=>p%bartholomeus%crop)
    write(unit,*)c%c_mroot,c%f_senes,c%q10_root,c%specific_resp_humus,c%q10_microbial, &
      c%microbial_shape_m,c%root_shape_m,c%root_radius_m,c%max_resp_factor
   end associate
   write(unit,*)forcing%crop_oxygen%air_temperature_c,root_srl,et%potential_transpiration_dry_cm_per_day,et%potential_transpiration_wet_cm_per_day
   do node=1,nodes
    fraction=0d0;density_root=0d0
    if(node<=rooted)then
     fraction=cumulative(node+1)-cumulative(node)
     density_root=forcing%crop_oxygen%root_density_kg_m3(node)
    end if
    write(unit,*)node,node_layer(node),dz(node),s%pressure_head(node),s%water_content(node), &
      thermal%temperature_c(node),cofgen(1:12,node),organic(node_layer(node)),sand(node_layer(node)), &
      density(node_layer(node)),fraction,density_root
   end do
   close(unit)
  class default
   error stop 'stress observation physical type'
  end select
 end subroutine

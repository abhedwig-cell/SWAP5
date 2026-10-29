program root_oxygen_density_driver
 use iso_fortran_env,only:real64
 use ieee_arithmetic,only:ieee_value,ieee_quiet_nan
 use MOD_grid,only:source_dz=>dz
 use MOD_cropdevelopment,only:finalize_wroot_node,cumdens_top,wroot_node,wroot_node_top,lrv_node,srl,swLrvconstant
 use plant_interface,only:wrt,noddrz
 use mod_column_swp_water
 use mod_wofost_rate_table
 use mod_crop_root_profile_static
 use mod_wofost_crop_owner_state
 use mod_crop_bartholomeus_input
 use mod_crop_root_biomass_distribution
 implicit none
 type(wofost_crop_owner_state_t)::owner
 type(wofost_rate_table_t)::table,root_partition
 type(crop_bartholomeus_input_t)::input
 type(crop_root_biomass_distribution_t)::distribution
 real(real64)::width(256),tdwi,initial_depth,maximum_depth,root_srl,flat(2048),part,depth,error,maximum_error,pond
 real(real64),allocatable::heads(:),cofgen(:,:),cumulative(:),bottoms(:),invalid(:)
 integer::nodes,n,code,i,k,rooted
 logical::available,rdinqr
 call rdinit(74,0,'grass.crp')
 call rdsdor('tdwi',0d0,1d4,tdwi);call rdsdor('rdi',0d0,1000d0,initial_depth)
 call rdsdor('rdc',0d0,1000d0,maximum_depth);call rdsdor('srl',1d-3,1d10,root_srl)
 call rdsinr('swoxygen',0,2,k);call require(k==2,'original physical oxygen retained')
 k=0
 if(rdinqr('swlrvconstant'))call rdsinr('swlrvconstant',0,1,k)
 call require(k==0,'original nonconstant root density')
 call rdinne('frtb',n);call rdfdou('frtb',flat,2048,n)
 call construct_wofost_rate_table(flat(1:n:2),flat(2:n:2),root_partition,code)
 call require(code==0,'original root partition table')
 call root_partition%evaluate(0d0,part,code);call require(code==0,'original emergence root allocation')
 call rdinne('rdctb',n);call rdfdou('rdctb',flat,2048,n)
 call construct_wofost_rate_table(flat(1:n:2),flat(2:n:2),table,code)
 call require(code==0,'original root density table');close(74)
 call import_column_swp_water('input.swp',nodes,width,heads,cofgen,source_pond=pond,initial_bottom_mode=1, &
      allow_ksatexm=.true.,allow_prescribed_groundwater=.true.,initial_groundwater_cm=-88d0)
 call require(nodes==113.and.sum(width(:nodes))==600d0,'original Grassgrowth grid')
 allocate(bottoms(nodes));bottoms(1)=-width(1)
 do i=2,nodes
  bottoms(i)=bottoms(i-1)-width(i)
 end do
 owner%crop_emerged=.true.;allocate(owner%biomass)
 owner%biomass%root_biomass=part*tdwi
 source_dz(:nodes)=width(:nodes);srl=root_srl;swLrvconstant=0
 maximum_error=0d0
 do k=1,4
  depth=initial_depth
  if(k==2)depth=maximum_depth
  if(k==3)depth=.5d0*width(1)
  if(k==4)owner%biomass%root_biomass=0d0
  call materialize_static_root_profile(table,bottoms,maximum_depth,depth,rooted,cumulative,code)
  call require(code==0.and.rooted>0,'production root geometry')
  call owner%derive_bartholomeus_root_input(width(:rooted),cumulative,root_srl,10d0,input,distribution,available,code)
  call require(code==0.and.available,'owner-derived oxygen view')
  wrt=owner%biomass%root_biomass;noddrz=rooted
  cumdens_top=0d0;cumdens_top(:rooted+1)=cumulative
  wroot_node=0d0;wroot_node_top=0d0;lrv_node=0d0
  call finalize_wroot_node()
  error=max(maxval(abs(wroot_node(:rooted)-distribution%mass_kg_ha)), &
    maxval(abs(lrv_node(:rooted)-distribution%length_cm_cm3)), &
    maxval(abs(wroot_node_top(:rooted)-input%root_density_kg_m3)))
  maximum_error=max(maximum_error,error)
  call require(error==0d0,'exact original root density and mass')
  call require(abs(sum(distribution%mass_kg_ha)-wrt)<1d-12,'derived biomass conservation')
  write(*,*)'ROOT_OXYGEN_SOURCE',k,rooted,wrt,error
 end do
 owner%biomass%root_biomass=part*tdwi
 invalid=cumulative;invalid(1)=.1d0
 call owner%derive_bartholomeus_root_input(width(:rooted),invalid,root_srl,10d0,input,distribution,available,code)
 call require(code/=0.and..not.available.and..not.allocated(input%root_density_kg_m3),'bad geometry fails closed')
 call require(owner%biomass%root_biomass==part*tdwi,'rejection preserves crop biomass')
 call owner%derive_bartholomeus_root_input(width(:rooted),cumulative,root_srl, &
   ieee_value(0d0,ieee_quiet_nan),input,distribution,available,code)
 call require(code/=0.and..not.available.and..not.allocated(input%root_density_kg_m3),'bad temperature fails closed')
 write(*,*)'ORIGINAL_ROOT_OXYGEN_DENSITY_PASS',maximum_error
contains
 subroutine require(ok,message)
  logical,intent(in)::ok
  character(*),intent(in)::message
  if(.not.ok)then
   print *,message
   error stop 1
  end if
 end subroutine
end program

          ! Generated diagnostic source only: never compiled by production recipes.
          if(t0>=582d0.and.t0<585d0)then
            block
              integer::u,i,root_count
              real(real64)::root_mass_density,org,sand_fraction
              open(newunit=u,file='uptake-trials.dat',status='unknown',position='append',action='write')
              write(u,*)t0,t1,physical%active_nodes,self%micro_rooted_nodes,self%root_potential_transpiration
              associate(p=>self%micro_de_willigen)
                write(u,*)p%root_radius_cm,p%root_conductance_cm_per_day,p%stem_a0_per_day,p%stem_a1_per_cm, &
                  p%half_leaf_pressure_cm,p%campbell_exponent,p%pressure_tolerance_cm,p%newton_tolerance_cm, &
                  p%residual_tolerance_cm_per_day,p%max_iterations,p%oxygen_mode,p%reduction_mode
              end associate
              associate(c=>self%bartholomeus%crop)
                write(u,*)c%c_mroot,c%f_senes,c%q10_root,c%specific_resp_humus,c%q10_microbial, &
                  c%microbial_shape_m,c%root_shape_m,c%root_radius_m,c%max_resp_factor
              end associate
              write(u,*)self%crop_oxygen%air_temperature_c,self%bartholomeus%specific_root_length_m_kg
              do i=1,physical%active_nodes
                root_mass_density=0d0
                if(i<=size(self%crop_oxygen%root_density_kg_m3))root_mass_density=self%crop_oxygen%root_density_kg_m3(i)
                associate(s=>self%bartholomeus%soil%soil(i))
                  org=s%percent_org_mat/100d0;sand_fraction=s%percent_sand/(100d0*(1d0-org))
                  write(u,*)i,self%micro_horizon_first_node(i),self%soil_parameters%dz(i),physical%pressure_head(i), &
                    physical%water_content(i),oxygen_thermal%temperature_c(i),self%hydraulic_parameters%cofgen(1:24,i), &
                    self%micro_root_length_density(i),oxygen(i),salinity(i),coupled%root_extraction_sink(i), &
                    self%root_potential_sink(i),root_mass_density,org,sand_fraction,s%soil_density
                end associate
              end do
              close(u)
            end block
          end if

! Existing native crop serializer, shared by experimental historical adapters.
! Default schema preserves the established weather/soil-N byte representation.
! New clipped-root receipt schema is explicit and owned by the enclosing file.
module mod_wofost_crop_native_codec
  use iso_fortran_env,only:real64,int64
  use mod_fmr_wofost_crop_transaction,only:fmr_wofost_crop_transaction_persistence_t
  use mod_fmr_wofost_accepted_window_lineage,only:fmr_wofost_crop_event_identity_persistence_t, &
       export_wofost_crop_event_identity_persistence,reconstruct_wofost_crop_event_identity_from_persistence
  use mod_wofost_crop_owner_state,only:classic_owner_t=>wofost_crop_owner_state_t
  use mod_wofost_actual_biomass_state,only:classic_biomass_t=>wofost_actual_biomass_state_t
  implicit none
  private
  public::weather_native_event,weather_native_biomass,weather_native_owner,weather_native_crop_view
  public::serialize_wofost_crop_view
  interface serialize_wofost_crop_view
    module procedure weather_native_crop_view
  end interface
contains
  subroutine weather_native_event(u,reading,v,io,source_clipped_schema)
    integer,intent(in)::u
    logical,intent(in)::reading
    type(fmr_wofost_crop_event_identity_persistence_t),intent(inout)::v
    integer,intent(out)::io
    logical,intent(in),optional::source_clipped_schema
    logical::clipped_schema
    logical::present_value
    integer::n,st
    type(fmr_wofost_crop_event_identity_persistence_t)::event
    io=0;clipped_schema=.false.
    if(present(source_clipped_schema))clipped_schema=source_clipped_schema
    if(.not.clipped_schema)then
      if(reading)then
        v%root_layer_reduction_clipped=.false.
      else if(v%root_layer_reduction_clipped)then
        io=1;return
      end if
    else
      if(reading)then
        read(u,iostat=io)v%root_layer_reduction_clipped
      else
        write(u,iostat=io)v%root_layer_reduction_clipped
      end if
      if(io/=0)return
    end if
    if(reading)then
      read(u,iostat=io)v%valid
    else
      write(u,iostat=io)v%valid
    end if
    if(io/=0)return
    if(reading)then
      read(u,iostat=io)v%lineage_id
    else
      write(u,iostat=io)v%lineage_id
    end if
    if(io/=0)return
    if(reading)then
      read(u,iostat=io)v%final_revision
    else
      write(u,iostat=io)v%final_revision
    end if
    if(io/=0)return
    if(reading)then
      read(u,iostat=io)v%t0
    else
      write(u,iostat=io)v%t0
    end if
    if(io/=0)return
    if(reading)then
      read(u,iostat=io)v%t1
    else
      write(u,iostat=io)v%t1
    end if
    if(io/=0)return
    if(reading)then
      read(u,iostat=io)v%actual_root_uptake_integral
    else
      write(u,iostat=io)v%actual_root_uptake_integral
    end if
    if(io/=0)return
    if(reading)then
      read(u,iostat=io)v%potential_transpiration_integral
    else
      write(u,iostat=io)v%potential_transpiration_integral
    end if
    if(io/=0)return
    if(reading)then
      read(u,iostat=io)v%deepest_root_oxygen_factor_available
    else
      write(u,iostat=io)v%deepest_root_oxygen_factor_available
    end if
    if(io/=0)return
    if(reading)then
      read(u,iostat=io)v%deepest_root_oxygen_factor_integral
    else
      write(u,iostat=io)v%deepest_root_oxygen_factor_integral
    end if
    if(io/=0)return
    if(reading)then
      read(u,iostat=io)v%rootzone_drought_uptake_factor_available
    else
      write(u,iostat=io)v%rootzone_drought_uptake_factor_available
    end if
    if(io/=0)return
    if(reading)then
      read(u,iostat=io)v%rootzone_drought_uptake_factor_integral
    else
      write(u,iostat=io)v%rootzone_drought_uptake_factor_integral
    end if
    if(io/=0)return
    present_value=allocated(v%potential_root_sink_integral)
    if(reading)then
      read(u,iostat=io)present_value
    else
      write(u,iostat=io)present_value
    end if
    if(io/=0)return
    if(present_value)then
      n=0
      if(.not.reading)n=size(v%potential_root_sink_integral)
      if(reading)then
        read(u,iostat=io)n
      else
        write(u,iostat=io)n
      end if
      if(io/=0)return
      if(n<0.or.n>10000)then;io=1;return;end if
      if(reading)then
        if(allocated(v%potential_root_sink_integral))deallocate(v%potential_root_sink_integral)
        allocate(v%potential_root_sink_integral(n),stat=io);if(io/=0)return
        read(u,iostat=io)v%potential_root_sink_integral
      else
        write(u,iostat=io)v%potential_root_sink_integral
      end if
      if(io/=0)return
    end if
    present_value=allocated(v%root_sink_reduction_integral)
    if(reading)then
      read(u,iostat=io)present_value
    else
      write(u,iostat=io)present_value
    end if
    if(io/=0)return
    if(present_value)then
      n=0
      if(.not.reading)n=size(v%root_sink_reduction_integral)
      if(reading)then
        read(u,iostat=io)n
      else
        write(u,iostat=io)n
      end if
      if(io/=0)return
      if(n<0.or.n>10000)then;io=1;return;end if
      if(reading)then
        if(allocated(v%root_sink_reduction_integral))deallocate(v%root_sink_reduction_integral)
        allocate(v%root_sink_reduction_integral(n),stat=io);if(io/=0)return
        read(u,iostat=io)v%root_sink_reduction_integral
      else
        write(u,iostat=io)v%root_sink_reduction_integral
      end if
      if(io/=0)return
    end if
  end subroutine
  subroutine weather_native_biomass(u,reading,v,io)
    integer,intent(in)::u
    logical,intent(in)::reading
    type(classic_biomass_t),intent(inout)::v
    integer,intent(out)::io
    logical::present_value
    integer::n,st
    type(fmr_wofost_crop_event_identity_persistence_t)::event
    io=0
    if(reading)then
      read(u,iostat=io)v%root_biomass
    else
      write(u,iostat=io)v%root_biomass
    end if
    if(io/=0)return
    if(reading)then
      read(u,iostat=io)v%stem_biomass
    else
      write(u,iostat=io)v%stem_biomass
    end if
    if(io/=0)return
    if(reading)then
      read(u,iostat=io)v%storage_biomass
    else
      write(u,iostat=io)v%storage_biomass
    end if
    if(io/=0)return
    if(reading)then
      read(u,iostat=io)v%exponential_leaf_area_index
    else
      write(u,iostat=io)v%exponential_leaf_area_index
    end if
    if(io/=0)return
    if(reading)then
      read(u,iostat=io)v%cumulative_dead_root_biomass
    else
      write(u,iostat=io)v%cumulative_dead_root_biomass
    end if
    if(io/=0)return
    if(reading)then
      read(u,iostat=io)v%cumulative_dead_stem_biomass
    else
      write(u,iostat=io)v%cumulative_dead_stem_biomass
    end if
    if(io/=0)return
    if(reading)then
      read(u,iostat=io)v%cumulative_dead_leaf_biomass
    else
      write(u,iostat=io)v%cumulative_dead_leaf_biomass
    end if
    if(io/=0)return
    present_value=allocated(v%leaf_biomass)
    if(reading)then
      read(u,iostat=io)present_value
    else
      write(u,iostat=io)present_value
    end if
    if(io/=0)return
    if(present_value)then
      n=0
      if(.not.reading)n=size(v%leaf_biomass)
      if(reading)then
        read(u,iostat=io)n
      else
        write(u,iostat=io)n
      end if
      if(io/=0)return
      if(n<0.or.n>10000)then;io=1;return;end if
      if(reading)then
        if(allocated(v%leaf_biomass))deallocate(v%leaf_biomass)
        allocate(v%leaf_biomass(n),stat=io);if(io/=0)return
        read(u,iostat=io)v%leaf_biomass
      else
        write(u,iostat=io)v%leaf_biomass
      end if
      if(io/=0)return
    end if
    present_value=allocated(v%specific_leaf_area)
    if(reading)then
      read(u,iostat=io)present_value
    else
      write(u,iostat=io)present_value
    end if
    if(io/=0)return
    if(present_value)then
      n=0
      if(.not.reading)n=size(v%specific_leaf_area)
      if(reading)then
        read(u,iostat=io)n
      else
        write(u,iostat=io)n
      end if
      if(io/=0)return
      if(n<0.or.n>10000)then;io=1;return;end if
      if(reading)then
        if(allocated(v%specific_leaf_area))deallocate(v%specific_leaf_area)
        allocate(v%specific_leaf_area(n),stat=io);if(io/=0)return
        read(u,iostat=io)v%specific_leaf_area
      else
        write(u,iostat=io)v%specific_leaf_area
      end if
      if(io/=0)return
    end if
    present_value=allocated(v%leaf_age)
    if(reading)then
      read(u,iostat=io)present_value
    else
      write(u,iostat=io)present_value
    end if
    if(io/=0)return
    if(present_value)then
      n=0
      if(.not.reading)n=size(v%leaf_age)
      if(reading)then
        read(u,iostat=io)n
      else
        write(u,iostat=io)n
      end if
      if(io/=0)return
      if(n<0.or.n>10000)then;io=1;return;end if
      if(reading)then
        if(allocated(v%leaf_age))deallocate(v%leaf_age)
        allocate(v%leaf_age(n),stat=io);if(io/=0)return
        read(u,iostat=io)v%leaf_age
      else
        write(u,iostat=io)v%leaf_age
      end if
      if(io/=0)return
    end if
  end subroutine
  subroutine weather_native_owner(u,reading,v,io)
    integer,intent(in)::u
    logical,intent(in)::reading
    type(classic_owner_t),intent(inout)::v
    integer,intent(out)::io
    logical::present_value
    integer::n,st
    type(fmr_wofost_crop_event_identity_persistence_t)::event
    io=0
    if(reading)then
      read(u,iostat=io)v%crop_emerged
    else
      write(u,iostat=io)v%crop_emerged
    end if
    if(io/=0)return
    if(reading)then
      read(u,iostat=io)v%development_stage
    else
      write(u,iostat=io)v%development_stage
    end if
    if(io/=0)return
    present_value=allocated(v%biomass)
    if(reading)then
      read(u,iostat=io)present_value
    else
      write(u,iostat=io)present_value
    end if
    if(io/=0)return
    if(present_value)then
      if(reading)allocate(v%biomass,stat=io)
      if(io/=0)return
      call weather_native_biomass(u,reading,v%biomass,io);if(io/=0)return
    end if
    present_value=allocated(v%evolution_continuation)
    if(reading)then
      read(u,iostat=io)present_value
    else
      write(u,iostat=io)present_value
    end if
    if(io/=0)return
    if(present_value)then
      if(reading)then
        allocate(v%evolution_continuation,stat=io);if(io/=0)return
        read(u,iostat=io)v%evolution_continuation
      else
        write(u,iostat=io)v%evolution_continuation
      end if
      if(io/=0)return
    end if
    present_value=allocated(v%b110_reference_compatibility)
    if(reading)then
      read(u,iostat=io)present_value
    else
      write(u,iostat=io)present_value
    end if
    if(io/=0)return
    if(present_value)then
      if(reading)then
        allocate(v%b110_reference_compatibility,stat=io);if(io/=0)return
        read(u,iostat=io)v%b110_reference_compatibility
      else
        write(u,iostat=io)v%b110_reference_compatibility
      end if
      if(io/=0)return
    end if
  end subroutine
  subroutine weather_native_crop_view(u,reading,v,io,source_clipped_schema,grass_schema)
    integer,intent(in)::u
    logical,intent(in)::reading
    type(fmr_wofost_crop_transaction_persistence_t),intent(inout)::v
    integer,intent(out)::io
    logical,intent(in),optional::source_clipped_schema,grass_schema
    logical::clipped_schema,with_grass
    logical::present_value
    integer::n,st
    type(fmr_wofost_crop_event_identity_persistence_t)::event
    io=0;clipped_schema=.false.;with_grass=.false.
    if(present(grass_schema))with_grass=grass_schema
    if(.not.reading.and..not.with_grass.and.v%grass_management_present)then
      io=1;return
    end if
    if(present(source_clipped_schema))clipped_schema=source_clipped_schema
    if(reading)then
      read(u,iostat=io)v%valid
    else
      write(u,iostat=io)v%valid
    end if
    if(io/=0)return
    call weather_native_owner(u,reading,v%owner,io);if(io/=0)return
    if(reading)then
      read(u,iostat=io)v%potential_shadow_present
    else
      write(u,iostat=io)v%potential_shadow_present
    end if
    if(io/=0)return
    if(reading)then
      read(u,iostat=io)v%potential_shadow%active
    else
      write(u,iostat=io)v%potential_shadow%active
    end if
    if(io/=0)return
    present_value=allocated(v%potential_shadow%biomass)
    if(reading)then
      read(u,iostat=io)present_value
    else
      write(u,iostat=io)present_value
    end if
    if(io/=0)return
    if(present_value)then
      if(reading)allocate(v%potential_shadow%biomass,stat=io)
      if(io/=0)return
      call weather_native_biomass(u,reading,v%potential_shadow%biomass,io);if(io/=0)return
    end if
    present_value=allocated(v%potential_shadow%b110_reference_compatibility)
    if(reading)then
      read(u,iostat=io)present_value
    else
      write(u,iostat=io)present_value
    end if
    if(io/=0)return
    if(present_value)then
      if(reading)then
        allocate(v%potential_shadow%b110_reference_compatibility,stat=io);if(io/=0)return
        read(u,iostat=io)v%potential_shadow%b110_reference_compatibility
      else
        write(u,iostat=io)v%potential_shadow%b110_reference_compatibility
      end if
      if(io/=0)return
    end if
    if(reading)then
      read(u,iostat=io)v%root_growth_carrier_present
    else
      write(u,iostat=io)v%root_growth_carrier_present
    end if
    if(io/=0)return
    if(reading)then
      read(u,iostat=io)v%root_growth_carrier
    else
      write(u,iostat=io)v%root_growth_carrier
    end if
    if(io/=0)return
    if(reading)then
      read(u,iostat=io)v%root_depth_present
    else
      write(u,iostat=io)v%root_depth_present
    end if
    if(io/=0)return
    if(reading)then
      read(u,iostat=io)v%root_depth
    else
      write(u,iostat=io)v%root_depth
    end if
    if(io/=0)return
    if(reading)then
      read(u,iostat=io)v%root_profile_present
    else
      write(u,iostat=io)v%root_profile_present
    end if
    if(io/=0)return
    present_value=allocated(v%root_profile%root_biomass_by_node)
    if(reading)then
      read(u,iostat=io)present_value
    else
      write(u,iostat=io)present_value
    end if
    if(io/=0)return
    if(present_value)then
      n=0
      if(.not.reading)n=size(v%root_profile%root_biomass_by_node)
      if(reading)then
        read(u,iostat=io)n
      else
        write(u,iostat=io)n
      end if
      if(io/=0)return
      if(n<0.or.n>10000)then;io=1;return;end if
      if(reading)then
        if(allocated(v%root_profile%root_biomass_by_node))deallocate(v%root_profile%root_biomass_by_node)
        allocate(v%root_profile%root_biomass_by_node(n),stat=io);if(io/=0)return
        read(u,iostat=io)v%root_profile%root_biomass_by_node
      else
        write(u,iostat=io)v%root_profile%root_biomass_by_node
      end if
      if(io/=0)return
    end if
    if(reading)then
      read(u,iostat=io)v%receipt_present
    else
      write(u,iostat=io)v%receipt_present
    end if
    if(io/=0)return
    if(reading)then
      read(u,iostat=io)v%lifecycle_present
    else
      write(u,iostat=io)v%lifecycle_present
    end if
    if(io/=0)return
    if(reading)then
      read(u,iostat=io)v%lifecycle_schema_version
    else
      write(u,iostat=io)v%lifecycle_schema_version
    end if
    if(io/=0)return
    if(reading)then
      read(u,iostat=io)v%lifecycle%valid
    else
      write(u,iostat=io)v%lifecycle%valid
    end if
    if(io/=0)return
    if(reading)then
      read(u,iostat=io)v%lifecycle%revision
    else
      write(u,iostat=io)v%lifecycle%revision
    end if
    if(io/=0)return
    if(reading)then
      read(u,iostat=io)v%lifecycle%crop_identity
    else
      write(u,iostat=io)v%lifecycle%crop_identity
    end if
    if(io/=0)return
    if(.not.reading)call export_wofost_crop_event_identity_persistence(v%lifecycle%last_event_identity,event,present_value)
    call weather_native_event(u,reading,event,io,clipped_schema);if(io/=0)return
    if(reading.and.event%valid)then
      call reconstruct_wofost_crop_event_identity_from_persistence(event,v%lifecycle%last_event_identity,st)
      if(st/=0)then;io=1;return;end if
    end if
    if(reading)then
      read(u,iostat=io)v%lifecycle%prepared
    else
      write(u,iostat=io)v%lifecycle%prepared
    end if
    if(io/=0)return
    if(reading)then
      read(u,iostat=io)v%lifecycle%sown
    else
      write(u,iostat=io)v%lifecycle%sown
    end if
    if(io/=0)return
    if(reading)then
      read(u,iostat=io)v%lifecycle%germinated
    else
      write(u,iostat=io)v%lifecycle%germinated
    end if
    if(io/=0)return
    if(reading)then
      read(u,iostat=io)v%lifecycle%emerged
    else
      write(u,iostat=io)v%lifecycle%emerged
    end if
    if(io/=0)return
    if(reading)then
      read(u,iostat=io)v%lifecycle%harvested
    else
      write(u,iostat=io)v%lifecycle%harvested
    end if
    if(io/=0)return
    if(reading)then
      read(u,iostat=io)v%lifecycle%preparation_delay
    else
      write(u,iostat=io)v%lifecycle%preparation_delay
    end if
    if(io/=0)return
    if(reading)then
      read(u,iostat=io)v%lifecycle%sowing_delay
    else
      write(u,iostat=io)v%lifecycle%sowing_delay
    end if
    if(io/=0)return
    if(reading)then
      read(u,iostat=io)v%lifecycle%germination_temperature_sum
    else
      write(u,iostat=io)v%lifecycle%germination_temperature_sum
    end if
    if(io/=0)return
    if(reading)then
      read(u,iostat=io)v%lifecycle%initialization_profile
    else
      write(u,iostat=io)v%lifecycle%initialization_profile
    end if
    if(io/=0)return
    if(reading)then
      read(u,iostat=io)v%lifecycle%task2_initialized
    else
      write(u,iostat=io)v%lifecycle%task2_initialized
    end if
    if(io/=0)return
    call weather_native_event(u,reading,v%receipt,io,clipped_schema);if(io/=0)return
    ! Explicit opt-in extension: legacy native streams retain their bytes.
    if(present(grass_schema))then
      if(grass_schema)then
        if(reading)then
          read(u,iostat=io)v%grass_management_present
        else
          write(u,iostat=io)v%grass_management_present
        end if
        if(io/=0)return
        if(v%grass_management_present)then
          if(reading)then
            read(u,iostat=io)v%grass_management%cut_index, &
              v%grass_management%potential_cut_index, &
              v%grass_management%actual_cut_age, &
              v%grass_management%potential_cut_age, &
              v%grass_management%warm_days, &
              v%grass_management%regrowth_delay_days, &
              v%grass_management%potential_regrowth_delay_days, &
              v%grass_management%harvested_dry_matter, &
              v%grass_management%potential_harvested_dry_matter
          else
            write(u,iostat=io)v%grass_management%cut_index, &
              v%grass_management%potential_cut_index, &
              v%grass_management%actual_cut_age, &
              v%grass_management%potential_cut_age, &
              v%grass_management%warm_days, &
              v%grass_management%regrowth_delay_days, &
              v%grass_management%potential_regrowth_delay_days, &
              v%grass_management%harvested_dry_matter, &
              v%grass_management%potential_harvested_dry_matter
          end if
          if(io/=0)return
        end if
      end if
    end if
  end subroutine

end module mod_wofost_crop_native_codec

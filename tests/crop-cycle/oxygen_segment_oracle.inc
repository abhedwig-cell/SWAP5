  subroutine oxygen_segment_oracle(app,crop,config,record,rate,unstressed)
    type(fmr_production_application_bootstrap_t),intent(in)::app
    type(kernel_committed_state_t),intent(in)::crop
    type(fmr_production_application_config_t),intent(in)::config
    type(swap_daily_weather_record_t),intent(in)::record
    real(real64),intent(out)::rate,unstressed
    type(kernel_committed_state_t)::soil
    class(transaction_state_t),allocatable::physical
    type(wofost_crop_owner_state_t)::owner
    type(crop_root_uptake_input_t)::roots
    type(crop_et_canopy_state_view_t)::state
    type(crop_et_canopy_forcing_t)::cf
    type(crop_et_canopy_view_t)::cv
    type(crop_et_canopy_diagnostics_t)::cd
    type(reference_et_demand_forcing_t)::ef
    type(reference_et_demand_canopy_view_t)::ec
    type(reference_et_demand_result_t)::er
    type(reference_et_demand_diagnostics_t)::ed
    real(real64)::day,tmn,tmx,rain,et,limits(8),sink(numnod),neutral(numnod)
    integer::s
    logical::ok
    interface
      subroutine b111_root_sink(n,noddrz,upper,enabled,h,ptra,cumdens_top,limits,qrot)
        import real64
        integer,intent(in)::n,noddrz,upper
        logical,intent(in)::enabled
        real(real64),intent(in)::h(n),ptra,cumdens_top(noddrz+1),limits(8)
        real(real64),intent(out)::qrot(n)
      end subroutine
    end interface
    rate=0;unstressed=0
    call crop%snapshot(physical,ok);call require(ok,'oracle committed crop')
    select type(physical)
    type is(fmr_wofost_crop_transaction_state_t)
      call physical%snapshot_owner(owner,ok);call require(ok,'oracle accepted owner')
    class default
      error stop 'oracle crop type'
    end select
    if(.not.owner%crop_emerged)return
    state%crop_emerged=.true.;state%development_stage=owner%development_stage
    call owner%derive_actual_leaf_area_index(config%file_weather_stem_area_coefficient, &
      config%file_weather_storage_area_coefficient,state%leaf_area_index,s)
    call require(s==WOFOST_CROP_OWNER_OK,'oracle production leaf view')
    call evaluate_crop_et_canopy_view(config%file_weather_canopy_parameters,state,cf,cv,cd)
    call require(cd%status==CROP_ET_CANOPY_OK,'oracle canopy view')
    call record%values(day,tmn,tmx,rain,et,ok);call require(ok,'oracle authentic forcing')
    ef%reference_et_mm_per_day=et
    ec%crop_emerged=cv%crop_emerged;ec%vegetation_cover_fraction=cv%vegetation_cover_fraction
    ec%crop_factor=cv%crop_factor;ec%co2_transpiration_factor=cv%co2_transpiration_factor
    call evaluate_restricted_reference_et_demand(forcing_config%reference_et_parameters,ef,ec,er,ed)
    call require(ed%status==REF_ET_DEMAND_OK,'oracle reference ET')
    call owner%derive_dvs_root_uptake_input(config%file_weather_root_depth,config%file_weather_root_density, &
      config%file_weather_maximum_root_depth_cm,config%tiles(1)%parameters%z-config%tiles(1)%parameters%dz*.5_real64,roots,ok,s)
    call require(ok.and.s==WOFOST_CROP_OWNER_OK,'oracle committed root geometry')
    limits=[config%file_weather_root_parameters%hlim3l,config%file_weather_root_parameters%hlim3h, &
      config%file_weather_root_parameters%hlim4,config%file_weather_root_parameters%adcrl, &
      config%file_weather_root_parameters%adcrh,config%file_weather_root_parameters%hlim1, &
      config%file_weather_root_parameters%hlim2u,config%file_weather_root_parameters%hlim2l]
    call app%copy_committed_for_crop(1,soil,s);call require(s==FMR_APP_BOOT_OK,'oracle accepted soil')
    call soil%snapshot(physical,ok);call require(ok,'oracle soil snapshot')
    select type(physical)
    class is(fmr_b110_physical_state_t)
      call b111_root_sink(numnod,roots%rooted_nodes,config%file_weather_root_parameters%upper_layer_bottom_node, &
        .true.,physical%pressure_head,er%potential_transpiration_cm_per_day,roots%cumulative_root_fraction,limits,sink)
      call b111_root_sink(numnod,roots%rooted_nodes,config%file_weather_root_parameters%upper_layer_bottom_node, &
        .false.,physical%pressure_head,er%potential_transpiration_cm_per_day,roots%cumulative_root_fraction,limits,neutral)
    class default
      error stop 'oracle soil type'
    end select
    rate=sum(sink);unstressed=sum(neutral)
  end subroutine

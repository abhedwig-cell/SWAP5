  subroutine configure_crop(p)
    type(crop_n_configuration_t), intent(out) :: p
    p%scalars%development_daylength_mode = 0
    p%scalars%vegetative_temperature_sum_required = 1000.0_real64
    p%scalars%generative_temperature_sum_required = 1000.0_real64
    p%scalars%diffuse_extinction_coefficient = 0.5_real64
    p%scalars%initial_light_use_efficiency = 0.4_real64
    p%scalars%co2_to_dry_matter_fraction = 0.7_real64
    p%scalars%attainable_yield_multiplier = 1.0_real64
    p%scalars%conversion_efficiency_root = 0.7_real64
    p%scalars%conversion_efficiency_stem = 0.7_real64
    p%scalars%conversion_efficiency_leaf = 0.7_real64
    p%scalars%conversion_efficiency_storage = 0.7_real64
    p%scalars%respiration_temperature_q10 = 2.0_real64
    p%scalars%maintenance_respiration_root = 0.01_real64
    p%scalars%maintenance_respiration_leaf = 0.01_real64
    p%scalars%maintenance_respiration_stem = 0.01_real64
    p%scalars%maintenance_respiration_storage = 0.01_real64
    p%scalars%maximum_leaf_relative_death_rate = 0.03_real64
    p%scalars%leaf_age_base_temperature = 0.0_real64
    p%scalars%maximum_relative_lai_growth_rate = 0.008_real64
    call make_table([0.0_real64,40.0_real64],[10.0_real64,10.0_real64],p%tables(1))
    call make_table([0.0_real64,2.0_real64],[35.0_real64,35.0_real64],p%tables(2))
    call make_table([0.0_real64,40.0_real64],[1.0_real64,1.0_real64],p%tables(3))
    call make_table([-10.0_real64,20.0_real64],[1.0_real64,1.0_real64],p%tables(4))
    call make_table([0.0_real64,2.0_real64],[1.0_real64,1.0_real64],p%tables(5))
    call make_table([0.0_real64,2.0_real64],[0.2_real64,0.2_real64],p%tables(6))
    call make_table([0.0_real64,2.0_real64],[0.5_real64,0.5_real64],p%tables(7))
    call make_table([0.0_real64,2.0_real64],[0.5_real64,0.5_real64],p%tables(8))
    call make_table([0.0_real64,2.0_real64],[0.0_real64,0.0_real64],p%tables(9))
    call make_table([0.0_real64,2.0_real64],[0.02_real64,0.02_real64],p%tables(10))
    call make_table([0.0_real64,2.0_real64],[0.01_real64,0.01_real64],p%tables(11))
    call make_table([0.0_real64,2.0_real64],[0.02_real64,0.02_real64],p%tables(12))
    call configure_p81(p)
    p%root_depth_cm=30d0;p%tcsf_n=1d0;p%lai_crit_nupt=3d0
    p%update%development_stage_end=2d0;p%update%leaf_lifespan=100d0
  end subroutine

  subroutine make_table(x,y,table)
    real(real64),intent(in)::x(:),y(:)
    type(crop_n_table_t),intent(out)::table
    table%x=x;table%y=y
  end subroutine

  subroutine configure_p81(p)
    type(crop_n_configuration_t), intent(inout) :: p
    p%base%assimilation%amax_lnb = 0.0_real64
    p%base%assimilation%amax_ref = 35.0_real64
    p%base%assimilation%amax_slp = 3.24_real64
    p%base%assimilation%kn = 0.4_real64
    p%base%nitrogen%nmaxst_fr = 0.5_real64
    p%base%nitrogen%nmaxrt_fr = 0.5_real64
    p%base%nitrogen%nmaxso = 0.0176_real64
    p%base%nitrogen%nresidlv = 0.004_real64
    p%base%nitrogen%nresidst = 0.002_real64
    p%base%nitrogen%nresidrt = 0.002_real64
    p%base%nitrogen%tcnt = 10.0_real64
    p%base%nitrogen%nfix_fr = 0.0_real64
    p%base%nitrogen%rnuptakemax = 100.0_real64
    p%base%nitrogen%dvs_n_transl = 0.8_real64
    p%base%nitrogen%rgrlai_min = 0.004_real64
    call make_table([0.0_real64,40.0_real64],[0.4_real64,0.4_real64],p%tables(13))
    call make_table([0.0_real64,2.0_real64],[0.5_real64,0.5_real64],p%tables(14))
    call make_table([0.0_real64,2.0_real64],[0.04_real64,0.04_real64],p%tables(15))
    call make_table([0.0_real64,3.0_real64],[1.0_real64,1.0_real64],p%tables(16))
  end subroutine

  subroutine configure_owner(owner,p,status)
    type(wofost81_crop_owner_state_t), intent(out) :: owner
    type(crop_n_configuration_t), intent(in) :: p
    integer, intent(out) :: status
    owner%crop%crop_emerged = .true.
    owner%crop%development_stage = 0.5_real64
    allocate(owner%crop%biomass,owner%crop%evolution_continuation)
    owner%crop%biomass%root_biomass = 100.0_real64
    owner%crop%biomass%stem_biomass = 200.0_real64
    owner%crop%biomass%storage_biomass = 50.0_real64
    owner%crop%biomass%leaf_biomass = [100.0_real64,100.0_real64]
    owner%crop%biomass%specific_leaf_area = [0.02_real64,0.02_real64]
    owner%crop%biomass%leaf_age = [1.0_real64,2.0_real64]
    owner%crop%biomass%exponential_leaf_area_index = 4.0_real64
    call initialize_wofost81_n_owner_state(200.0_real64,200.0_real64,100.0_real64,0.04_real64, &
         p%base%nitrogen,owner%nitrogen,status)
  end subroutine

